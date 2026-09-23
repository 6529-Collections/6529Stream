// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamDistributionFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/mint/StreamBurnMintGate.sol";

interface BurnVm {
    function prank(address) external;
    function deal(address, uint256) external;
    function warp(uint256) external;
    function expectRevert() external;
    function chainId(uint256) external;
    function expectEmit(bool, bool, bool, bool, address) external;
}

/// @dev Canonical registry ABI; registration/revocation are typed fixture inputs.
contract BurnRegistryBoundary is ERC165 {
    address public governanceExecutor;
    mapping(address => StreamModuleRecord) private records;

    constructor() {
        governanceExecutor = address(new DistributionAuthorityBoundary());
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || super.supportsInterface(id);
    }

    function register(StreamBurnMintGate gate) external {
        (string memory uri, bytes32 hash) = gate.streamModuleManifest();
        records[address(gate)] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            gate.streamModuleType(),
            gate.streamModuleVersion(),
            type(IStreamMintGate).interfaceId,
            400000,
            address(gate).codehash,
            gate.streamModuleDeploymentManifestHash(),
            hash,
            uri,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1
        );
    }

    function revoke(address gate) external {
        records[gate].status = ModuleRegistryStatus.INCIDENT_REVOKED;
    }

    function moduleRecord(address gate) external view returns (StreamModuleRecord memory) {
        return records[gate];
    }
}

/// @dev Current Core hook/identity signatures plus real ERC721 behavior; governance/finality are explicit failure inputs.
contract BurnCoreBoundary is ERC721 {
    address public registry;
    address public artists;
    address public entropy;
    address public manager;
    uint256 public minted = 100;
    uint256 private pending;
    mapping(uint256 => uint256) private collections;
    mapping(uint256 => bool) private burned;
    bool public burnBlocked;
    bool public mintBlocked;
    bool public corruptIdentity;
    bool public callbackSucceeded;
    address public callback;
    bytes public callbackData;
    constructor() ERC721("Burn boundary", "BURN") { }

    function configure(address r, address a, address e, address m) external {
        registry = r;
        artists = a;
        entropy = e;
        manager = m;
    }

    function setBlocked(bool burn_, bool mint_) external {
        burnBlocked = burn_;
        mintBlocked = mint_;
    }

    function setCorrupt(bool value) external {
        corruptIdentity = value;
    }

    function setCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function mintSource(address holder, uint256 id, uint256 collection) external {
        collections[id] = collection;
        _mint(holder, id);
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id > 0 && id < 4;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (
            collections[id] != 0,
            collections[id],
            id + (corruptIdentity && burned[id] ? 1 : 0),
            burned[id]
        );
    }

    function getSatellitePointer(bytes32 role)
        external
        view
        returns (
            address target,
            bytes32,
            bool,
            bytes32,
            bytes4,
            address,
            uint8,
            bytes32,
            bytes32,
            uint64
        )
    {
        if (role == keccak256("MODULE_REGISTRY")) target = registry;
        if (role == keccak256("ARTIST_REGISTRY")) target = artists;
        if (role == keccak256("ENTROPY_COORDINATOR")) target = entropy;
        if (role == keccak256("MINT_MANAGER")) target = manager;
        return (target, target.codehash, false, 0, 0, address(0), 0, 0, 0, 0);
    }

    function burn(uint256 id) external {
        require(!burnBlocked && _isApprovedOrOwner(msg.sender, id), "native burn denied");
        _burn(id);
        burned[id] = true;
        if (callback != address(0)) (callbackSucceeded,) = callback.call(callbackData);
    }

    function mintFromManager(uint256 c, address to, bytes calldata, bytes32, bytes32)
        external
        returns (uint256 id, uint256)
    {
        require(msg.sender == manager && !mintBlocked, "native mint denied");
        id = ++minted;
        collections[id] = c;
        _safeMint(to, id);
        return (id, id);
    }

    function prepareMintFromManager(uint256 c, bytes calldata, bytes32, bytes32)
        external
        returns (uint256 id, uint256)
    {
        require(msg.sender == manager && !mintBlocked && pending == 0, "native prepare denied");
        id = ++minted;
        collections[id] = c;
        pending = id;
        return (id, id);
    }

    function completePreparedMintFromManager(uint256 id, address to, bytes32, bytes32) external {
        require(msg.sender == manager && id == pending, "native complete denied");
        pending = 0;
        _safeMint(to, id);
    }
}

contract BurnReceiverBoundary is IERC721Receiver {
    bool public reject;
    address public callback;
    bytes public data;
    bool public callbackSucceeded;

    function configure(bool r, address target, bytes calldata input) external {
        reject = r;
        callback = target;
        data = input;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (callback != address(0)) (callbackSucceeded,) = callback.call(data);
        require(!reject, "recipient rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Manager/Ledger/gate and real Safe1.4.1, with typed Core/Artist/registry/entropy seams.
contract StreamBurnMintGateTest is OfficialSafeFixture {
    event BurnMintExecuted(
        uint16 schemaVersion,
        uint256 indexed sourceTokenId,
        uint256 indexed mintedTokenId,
        uint256 indexed targetCollectionId,
        bytes32 burnNullifier,
        address redeemer
    );
    BurnVm private constant vm = BurnVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    BurnCoreBoundary internal core;
    BurnRegistryBoundary internal registry;
    DistributionArtistBoundary internal artists;
    DistributionEntropyBoundary internal entropy;
    StreamMintManager internal manager;
    StreamMintLedger private ledger;
    StreamBurnMintGate internal gate;
    mapping(uint256 => bytes32) private policies;
    bytes32 private constant PHASE = keccak256("burn phase");
    bytes32 private constant COUNTER = keccak256("burn supply");
    address internal constant HOLDER = address(0xB0B);
    address internal constant RECIPIENT = address(0xCAFE);

    function setUp() public {
        vm.warp(1000);
        vm.deal(address(this), 1 ether);
        core = new BurnCoreBoundary();
        registry = new BurnRegistryBoundary();
        artists = new DistributionArtistBoundary(address(core));
        entropy = new DistributionEntropyBoundary(address(core));
        core.configure(address(registry), address(artists), address(entropy), address(0));
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(IStreamCore(address(core)), ledger, registry);
        core.configure(address(registry), address(artists), address(entropy), address(manager));
        artists.configure(address(manager));
        ledger.setLedgerWriter(address(manager), true);
        gate = new StreamBurnMintGate(
            StreamBurnMintGate.Configuration(
                address(core),
                address(registry),
                registry.governanceExecutor(),
                address(this),
                keccak256("burn deployment"),
                keccak256("burn manifest"),
                "ipfs://burn",
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_DEPENDENCY_READ_GAS", 150000, 100000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig("BURN_EXECUTION_GAS", 400000, 200000, 2),
                IStreamGasParameterHost.GasParameterConfig(
                    "REVEAL_ATTEMPT_GAS_LIMIT", 400000, 100000, 2
                )
            )
        );
        registry.register(gate);
        _configure(2, 2, false, 5);
        core.mintSource(HOLDER, 1, 1);
        core.mintSource(HOLDER, 2, 1);
        vm.prank(HOLDER);
        core.setApprovalForAll(address(gate), true);
    }

    function _configure(uint256 target, uint8 ratio, bool prepared, uint64 cap) internal {
        uint256[] memory sources = new uint256[](1);
        sources[0] = 1;
        bytes32 hash = gate.configureProgram(
            B.ProgramConfig(
                address(manager), target, PHASE, sources, ratio, 1000, 2000, prepared, address(0)
            )
        );
        IStreamMintManager.MintGateConfig memory g;
        g.gate = address(gate);
        g.gateConfigHash = hash;
        g = StreamMintGateValidator.validateConfiguration(g, registry);
        IStreamMintManager.MintPhaseConfig memory p = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 10, keccak256("burn app"), keccak256("published program")
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            cap,
            1,
            keccak256("cap")
        );
        artists.consent(
            manager.previewPhasePolicyHash(target, PHASE, p, g, ids, counters, new address[](0))
        );
        manager.configurePhase(target, PHASE, p, g, ids, counters);
        address[] memory executors = new address[](1);
        executors[0] = address(gate);
        artists.consent(
            manager.previewPhasePolicyHash(target, PHASE, p, g, ids, counters, executors)
        );
        manager.setPhaseExecutor(target, PHASE, address(gate), true);
        policies[target] = manager.phasePolicyHash(target, PHASE);
    }

    function _batch(uint256 target, address recipient, uint256 quantity)
        internal
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = target;
        b.phaseId = PHASE;
        b.initialRecipients = new address[](quantity);
        b.beneficiaries = new address[](quantity);
        b.tokenData = new bytes[](quantity);
        b.mintCommitments = new bytes32[](quantity);
        for (uint256 i; i < quantity; ++i) {
            b.initialRecipients[i] = recipient;
            b.beneficiaries[i] = recipient;
            b.tokenData[i] = abi.encode(i);
            b.mintCommitments[i] = keccak256(abi.encode(i));
        }
        b.expectedPolicyHash = policies[target];
        b.authorizationId = keccak256("burn request");
        b.contextHash = keccak256("context");
    }

    function _sources() internal pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
    }

    function _run(IStreamMintManager.MintBatch memory b, uint256[] memory ids)
        private
        returns (uint256[] memory, bytes32, bytes32[] memory)
    {
        vm.prank(HOLDER);
        return gate.burnAndMint(b, ids);
    }

    function _unchanged() internal view {
        require(
            core.ownerOf(1) == HOLDER && core.ownerOf(2) == HOLDER && core.minted() == 100,
            "all token changes rolled back"
        );
        require(
            manager.nextOperationNonce() == 0 && !manager.isNullifierUsed(gate.burnNullifier(1)),
            "ledger and nonce rolled back"
        );
    }

    function testExactNullifierDomainCurrentManagerConsumptionAndRetainedIdentity() public {
        require(
            gate.burnNullifier(1)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_BURN_NULLIFIER_V1"),
                        block.chainid,
                        address(core),
                        uint256(1)
                    )
                ),
            "exact original domain"
        );
        bytes32 first = gate.burnNullifier(1);
        bytes32 second = gate.burnNullifier(2);
        vm.expectEmit(true, true, true, true, address(gate));
        emit BurnMintExecuted(1, 1, 101, 2, first, HOLDER);
        vm.expectEmit(true, true, true, true, address(gate));
        emit BurnMintExecuted(1, 2, 101, 2, second, HOLDER);
        (uint256[] memory tokens, bytes32 root,) = _run(_batch(2, RECIPIENT, 1), _sources());
        require(
            tokens.length == 1 && core.ownerOf(tokens[0]) == RECIPIENT
                && manager.isOperationRootUsed(root),
            "real manager mint"
        );
        require(
            manager.isNullifierUsed(gate.burnNullifier(1))
                && manager.isNullifierUsed(gate.burnNullifier(2)),
            "both original nullifiers consumed"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(exists && collection == 1 && serial == 1 && burned, "retained source");
        require(
            !ledger.isManagerNullifierUsed(address(0x1234), gate.burnNullifier(1)),
            "manager scoped ledger"
        );
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
    }

    function testGateProofUnavailableBeforeAndAfterExecution() public {
        IStreamMintManager.MintBatch memory b = _batch(2, RECIPIENT, 1);
        vm.expectRevert();
        _validate(b);
        _run(b, _sources());
        vm.expectRevert();
        _validate(b);
    }

    function _validate(IStreamMintManager.MintBatch memory b) private {
        vm.prank(address(manager));
        gate.validateMint(
            address(manager),
            address(gate),
            b.collectionId,
            b.phaseId,
            b.payer,
            b.authorizer,
            b.initialRecipients,
            b.beneficiaries,
            b.contextHash,
            b.expectedPolicyHash,
            ""
        );
    }

    function testPreburnCannotBeReused() public {
        vm.prank(HOLDER);
        core.burn(1);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        require(core.ownerOf(2) == HOLDER, "unburned sibling");
    }

    function testSourceOwnerAndExecutorApprovalAreIndependent() public {
        vm.expectRevert();
        gate.burnAndMint(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
        vm.prank(HOLDER);
        core.setApprovalForAll(address(gate), false);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
    }

    function testApprovedOperatorChoosesExplicitRecipient() public {
        vm.prank(HOLDER);
        core.setApprovalForAll(address(this), true);
        gate.burnAndMint(_batch(2, RECIPIENT, 1), _sources());
        require(core.ownerOf(101) == RECIPIENT, "recipient distinct from owner and operator");
    }

    function testDuplicateUnsortedAndWrongCollectionRejectBeforeBurn() public {
        uint256[] memory ids = _sources();
        ids[1] = 1;
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), ids);
        _unchanged();
        ids[0] = 2;
        ids[1] = 1;
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), ids);
        _unchanged();
        core.mintSource(HOLDER, 3, 3);
        ids[0] = 1;
        ids[1] = 3;
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), ids);
        _unchanged();
    }

    function testWindowBoundsAndPermanentProgramPin() public {
        vm.warp(999);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
        vm.warp(2001);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
        vm.warp(2000);
        _run(_batch(2, RECIPIENT, 1), _sources());
        B.Program memory p = gate.program(2);
        vm.expectRevert();
        gate.configureProgram(p.config);
    }

    function testBurnBlockTargetMintBlockCorruptRetainedIdentityRollback() public {
        core.setBlocked(true, false);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
        core.setBlocked(false, true);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
        core.setBlocked(false, false);
        core.setCorrupt(true);
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
    }

    function testReceiverRejectionRollsBackBurnsLedgerAndByteIdenticalRetry() public {
        BurnReceiverBoundary receiver = new BurnReceiverBoundary();
        receiver.configure(true, address(0), "");
        IStreamMintManager.MintBatch memory b = _batch(2, address(receiver), 1);
        vm.expectRevert();
        _run(b, _sources());
        _unchanged();
        receiver.configure(false, address(0), "");
        _run(b, _sources());
        require(core.ownerOf(101) == address(receiver), "exact request retry");
    }

    function testBurnAndReceiverCallbacksCannotReenter() public {
        IStreamMintManager.MintBatch memory b = _batch(2, RECIPIENT, 1);
        core.setCallback(address(gate), abi.encodeCall(gate.burnAndMint, (b, _sources())));
        _run(b, _sources());
        require(!core.callbackSucceeded(), "burn callback blocked");
    }

    function testChangedPolicyAndRevokedGateRollbackSources() public {
        IStreamMintManager.MintBatch memory b = _batch(2, RECIPIENT, 1);
        b.expectedPolicyHash = keccak256("stale");
        vm.expectRevert();
        _run(b, _sources());
        _unchanged();
        registry.revoke(address(gate));
        vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), _sources());
        _unchanged();
    }

    function testPreparedFreeMintAndLedgerCapRollback() public {
        _configure(3, 2, true, 1);
        core.mintSource(HOLDER, 3, 1);
        core.mintSource(HOLDER, 4, 1);
        uint256[] memory sources = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            sources[i] = i + 1;
        }
        vm.expectRevert();
        _run(_batch(3, RECIPIENT, 2), sources);
        _unchanged();
        _run(_batch(3, RECIPIENT, 1), _sources());
        require(core.ownerOf(101) == RECIPIENT, "prepared current manager join");
    }

    function testCoreManagerReplacementRejectsBeforeBurnAndOriginalSelectionCanRetry() public {
        IStreamMintManager.MintBatch memory batch = _batch(2, RECIPIENT, 1);
        core.configure(address(registry), address(artists), address(entropy), address(0xDEAD));
        vm.expectRevert();
        _run(batch, _sources());
        _unchanged();
        core.configure(address(registry), address(artists), address(entropy), address(manager));
        _run(batch, _sources());
        require(
            core.ownerOf(101) == RECIPIENT, "original current Manager accepts identical request"
        );
    }

    function testRevealFeeRequiredAndFailedFundingRollsBackBurn() public {
        entropy.setFee(10);
        IStreamMintManager.MintBatch memory b = _batch(2, RECIPIENT, 1);
        vm.expectRevert();
        _run(b, _sources());
        _unchanged();
        vm.deal(HOLDER, 100);
        entropy.fail(true, false);
        vm.expectRevert();
        vm.prank(HOLDER);
        gate.burnAndMint{ value: 10 }(b, _sources());
        _unchanged();
        entropy.fail(false, true);
        vm.prank(HOLDER);
        gate.burnAndMint{ value: 10 }(b, _sources());
        require(
            entropy.revealFeeEscrow(2) == 10 && core.ownerOf(101) == RECIPIENT,
            "fee funded despite request outage"
        );
    }

    function testFuzzNullifierChainTokenAndCoreDomain(uint64 chain, uint128 token) public {
        bytes32 before_ = gate.burnNullifier(token);
        uint256 old = block.chainid;
        vm.chainId(chain == old ? old ^ 1 : chain);
        require(gate.burnNullifier(token) != before_, "chain domain");
        require(gate.burnNullifier(token) != gate.burnNullifier(uint256(token) + 1), "token domain");
    }

    function testFuzzRatioAndOriginalNullifierBound(uint8 count) public {
        uint256 n = uint256(count) % 19;
        uint256[] memory sources = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            sources[i] = i + 1;
            if (i >= 2) core.mintSource(HOLDER, i + 1, 1);
        }
        if (n != 2) vm.expectRevert();
        _run(_batch(2, RECIPIENT, 1), sources);
        if (n != 2) _unchanged();
    }

    function testActualSafeOwnerApprovesAndRetriesIdenticalRejectedBurnMint() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 987);
        entropy.setFee(10);
        vm.deal(address(safe), 25);
        vm.prank(HOLDER);
        core.transferFrom(HOLDER, address(safe), 1);
        vm.prank(HOLDER);
        core.transferFrom(HOLDER, address(safe), 2);
        require(
            executeSafe(
                safe,
                keys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (address(gate), true)),
                0
            ),
            "Safe approval"
        );
        BurnReceiverBoundary receiver = new BurnReceiverBoundary();
        receiver.configure(true, address(0), "");
        bytes memory callData =
            abi.encodeCall(gate.burnAndMint, (_batch(2, address(receiver), 1), _sources()));
        bytes32 digest = safe.getTransactionHash(
            address(gate), 25, callData, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        bytes memory signedCall = abi.encodeCall(
            safe.execTransaction,
            (
                address(gate),
                25,
                callData,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        (bool ok,) = address(safe).call(signedCall);
        require(!ok, "failed Safe transaction");
        require(
            core.ownerOf(1) == address(safe) && manager.nextOperationNonce() == 0
                && address(safe).balance == 25 && gate.refundLiability() == 0,
            "Safe inner rollback"
        );
        receiver.configure(false, address(0), "");
        (ok,) = address(safe).call(signedCall);
        require(ok, "byte identical signed Safe retry");
        require(core.ownerOf(101) == address(receiver), "Safe executes actual Manager burn mint");
        bytes32 programHash = gate.program(2).configHash;
        require(
            gate.refundableBalance(programHash, address(safe)) == 15, "Safe owns unused allowance"
        );
        require(gate.refundableBalance(programHash, address(this)) == 0, "relayer has no credit");
        uint256 beforeBalance = HOLDER.balance;
        require(
            executeSafe(
                safe,
                keys,
                address(gate),
                0,
                abi.encodeCall(gate.claimRefund, (programHash, HOLDER)),
                0
            ),
            "Safe refund"
        );
        require(
            HOLDER.balance == beforeBalance + 15 && gate.refundLiability() == 0,
            "Safe directs exact credit"
        );
    }
}
