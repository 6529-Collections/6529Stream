// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";

/// @dev Explicit current-Core/artist seams. Manager, Ledger and ModuleRegistry are actual products.
contract MintRevocationCoreMock {
    address public registry;
    address public artist;
    address public manager;
    uint256 public minted;
    bool public unavailable;

    function initialize(address r, address a, address m) external {
        registry = r;
        artist = a;
        manager = m;
    }

    function setUnavailable(bool b) external {
        unavailable = b;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(!unavailable, "core unavailable");
        address selected = kind == keccak256("MODULE_REGISTRY") ? registry : artist;
        return (selected, selected.codehash, false, kind, 0, selected, 1, 0, 0, 1);
    }

    function prepareMintFromManager(uint256, bytes calldata, bytes32, bytes32)
        external
        returns (uint256, uint256)
    {
        require(msg.sender == manager, "manager");
        ++minted;
        return (minted, minted);
    }

    function completePreparedMintFromManager(uint256, address, bytes32, bytes32) external view {
        require(msg.sender == manager, "manager");
    }

    function mintFromManager(uint256, address, bytes calldata, bytes32, bytes32)
        external
        returns (uint256, uint256)
    {
        require(msg.sender == manager, "manager");
        ++minted;
        return (minted, minted);
    }
}

contract MintRevocationArtistMock {
    address public core;
    address public mintManager;

    constructor(address c) {
        core = c;
    }

    function setManager(address m) external {
        mintManager = m;
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32) external pure returns (bool, bytes32) {
        return (true, keccak256("fixture consent"));
    }
    function requireMintConsent(uint256, bytes32, bytes32) external pure { }
}

abstract contract MintRevocationTestBase is CharacterizationTestBase {
    uint256 internal constant SIGNER_KEY = 0x12345;
    bytes32 internal constant PHASE = keccak256("revocation-phase");
    address internal signer;
    address internal constant GATE = address(0x9876);
    address internal constant ADAPTER = address(0x8765);
    MockGovernedParameterAuthority internal authority;
    StreamModuleRegistry internal registry;
    MintRevocationCoreMock internal core;
    MintRevocationArtistMock internal artist;
    StreamMintLedger internal ledger;
    StreamMintManager internal manager;

    function setUp() public virtual {
        vm.warp(1000);
        signer = vm.addr(SIGNER_KEY);
        authority = new MockGovernedParameterAuthority(true);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), keccak256("registry"), "ipfs://registry"
        );
        core = new MintRevocationCoreMock();
        artist = new MintRevocationArtistMock(address(core));
        core.initialize(address(registry), address(artist), address(0));
        ledger = new StreamMintLedger();
        manager = _manager(address(ledger));
        ledger.setLedgerWriter(address(manager), true);
        artist.setManager(address(manager));
        core.initialize(address(registry), address(artist), address(manager));
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 10, keccak256("config"), keccak256("metadata")
        );
        IStreamMintManager.MintGateConfig memory gate;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            100,
            1,
            keccak256("counter config")
        );
        manager.configurePhase(1, PHASE, config, gate, ids, counters);
        manager.setPhaseExecutor(1, PHASE, address(this), true);
    }

    function _manager(address l) internal returns (StreamMintManager) {
        return new StreamMintManager(
            IStreamCore(address(core)), IStreamMintLedger(l), IERC165(address(registry))
        );
    }

    function _ticket(uint256 nonce)
        internal
        view
        returns (StreamMintTicketTypes.MintTicket memory t)
    {
        t.chainId = block.chainid;
        t.manager = address(manager);
        t.ledger = address(ledger);
        t.collectionId = 1;
        t.phaseId = PHASE;
        t.executor = address(this);
        t.payer = signer;
        t.authorizer = signer;
        t.authorizerKind = 1;
        t.initialRecipientsHash = keccak256("recipients");
        t.beneficiariesHash = keccak256("beneficiaries");
        t.tokenDataArrayHash = keccak256("data");
        t.mintCommitmentsHash = keccak256("commitments");
        t.quantity = 1;
        t.contextHash = keccak256("context");
        t.policyHash = manager.phasePolicyHash(1, PHASE);
        t.nonce = bytes32(nonce);
        t.deadline = 1001;
    }

    function _offer(uint256 nonce) internal view returns (StreamPrivateSaleTypes.SaleOffer memory) {
        return StreamPrivateSaleTypes.SaleOffer(
            block.chainid,
            ADAPTER,
            address(core),
            1,
            0,
            0,
            signer,
            address(0),
            100,
            bytes32(nonce),
            1001,
            0
        );
    }

    function _signature(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _revokeDigest(bytes32 domain, bytes32 id) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)"
                        ),
                        block.chainid,
                        address(manager),
                        address(ledger),
                        id
                    )
                )
            )
        );
    }

    function _batch(bytes32 id) internal view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = signer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = signer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = signer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = hex"1234";
        b.mintCommitments = new bytes32[](1);
        b.expectedPolicyHash = manager.phasePolicyHash(1, PHASE);
        b.authorizationId = id;
    }

    function _raise(bytes32 id, uint256 next) internal {
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            manager.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(manager),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        authority.setCurrentAction(
            true,
            keccak256(abi.encode("target-side cap witness", id, next)),
            1,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failure, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1))
        );
        vm.prank(address(authority));
        manager.raiseGasParameter(id, next);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
