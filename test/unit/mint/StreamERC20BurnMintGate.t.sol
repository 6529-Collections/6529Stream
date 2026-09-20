// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20BurnMintGate
} from "../../../smart-contracts/domains/mint/StreamERC20BurnMintGate.sol";
import {
    IStreamERC20BurnMintGate,
    IStreamERC20BurnMintContinuation
} from "../../../smart-contracts/interfaces/stream/mint/IStreamERC20BurnMintGate.sol";
import {
    IStreamERC20BurnMintSale
} from "../../../smart-contracts/interfaces/stream/mint/IStreamERC20BurnMintSale.sol";
import {
    IStreamBurnMintGate as B
} from "../../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol";
import {
    IStreamMintGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    IStreamMintManager as M
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    StreamERC20BurnMintTypes as E,
    U,
    S
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20BurnMintTypes.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamPrimarySettlementHash as Hash
} from "../../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import { IERC721Receiver } from "../../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";

interface ERC20BurnGateVm {
    function expectRevert() external;
    function prank(address) external;
    function warp(uint256) external;
    function etch(address, bytes calldata) external;
}

contract ERC20BurnGateAuthority {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, 0, 0, 0, 0, 0);
    }
}

/// @dev Explicit eligibility boundary; does not claim registry governance coverage.
contract ERC20BurnGateRegistry {
    mapping(address => bool) public enabled;
    mapping(address => bytes32) private pinned;

    function set(address target, bool value) external {
        enabled[target] = value;
        pinned[target] = target.codehash;
    }

    function isModuleEligible(address target, bytes32, bytes4) external view returns (bool) {
        return enabled[target] && pinned[target] == target.codehash;
    }
}

/// @dev Minimal original identity/ERC721 authority boundary, including retained burned identities.
contract ERC20BurnGateCore {
    address public registry;
    address public manager;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(uint256 => uint256) private collections;
    mapping(uint256 => bool) private burned;
    uint256 public minted = 100;
    bool public failBurn;
    bool public corruptRetained;
    address public reenter;
    bytes public reentryData;
    bool public reentered;

    function configure(address r, address m) external {
        registry = r;
        manager = m;
    }

    function source(uint256 id, uint256 collection, address holder) external {
        collections[id] = collection;
        ownerOf[id] = holder;
    }

    function approveAll(address holder, address actor, bool yes) external {
        isApprovedForAll[holder][actor] = yes;
    }

    function approveToken(uint256 id, address actor) external {
        getApproved[id] = actor;
    }

    function setBurnFailure(bool fail, bool corrupt) external {
        failBurn = fail;
        corruptRetained = corrupt;
    }

    function callback(address target, bytes calldata data) external {
        reenter = target;
        reentryData = data;
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
            id + (burned[id] && corruptRetained ? 1 : 0),
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
        if (role == keccak256("MINT_MANAGER")) target = manager;
        return (target, target.codehash, false, 0, 0, address(0), 0, 0, 0, 0);
    }

    function burn(uint256 id) external {
        require(
            !failBurn && ownerOf[id] != address(0)
                && (getApproved[id] == msg.sender || isApprovedForAll[ownerOf[id]][msg.sender]),
            "burn denied"
        );
        ownerOf[id] = address(0);
        burned[id] = true;
        if (reenter != address(0)) (reentered,) = reenter.call(reentryData);
    }

    function mint(uint256 collection, address recipient) external returns (uint256 id) {
        require(msg.sender == manager, "manager");
        id = ++minted;
        collections[id] = collection;
        ownerOf[id] = recipient;
        if (recipient.code.length != 0) {
            require(
                IERC721Receiver(recipient).onERC721Received(msg.sender, address(0), id, "")
                    == IERC721Receiver.onERC721Received.selector,
                "receiver"
            );
        }
    }
}

/// @dev Same gate request and replay selectors, with operation derivation intentionally a fixture.
contract ERC20BurnGateManager {
    address public core;
    address public moduleRegistry;
    M.MintGateConfig private config;
    mapping(bytes32 => bool) public isOperationRootUsed;
    mapping(bytes32 => bool) public isAuthorizationUsed;
    mapping(bytes32 => bool) public isNullifierUsed;
    uint256 public nonce;
    bool public omitReplay;

    constructor(address c, address r) {
        core = c;
        moduleRegistry = r;
    }

    function install(address gate, bytes32 hash) external {
        config = M.MintGateConfig(gate, hash, gate.codehash, 0, 0, 500000);
    }

    function phaseGate(uint256, bytes32) external view returns (M.MintGateConfig memory) {
        return config;
    }

    function setOmitReplay(bool value) external {
        omitReplay = value;
    }

    function setNullifier(bytes32 id, bool value) external {
        isNullifierUsed[id] = value;
    }

    function validate(M.MintBatch memory b, address executor, bytes memory gateData)
        public
        view
        returns (IStreamMintGate.GateResult memory)
    {
        return IStreamMintGate(config.gate)
            .validateMint(
                address(this),
                executor,
                b.collectionId,
                b.phaseId,
                b.payer,
                b.authorizer,
                b.initialRecipients,
                b.beneficiaries,
                b.contextHash,
                b.expectedPolicyHash,
                gateData
            );
    }

    function preview(M.MintBatch memory b, address executor)
        public
        view
        returns (bytes32 root, bytes32 id)
    {
        IStreamMintGate.GateResult memory g = validate(b, executor, "");
        root = keccak256(abi.encode(nonce, b, g));
        id = keccak256(abi.encode(root, uint256(0)));
    }

    function execute(M.MintBatch memory b)
        external
        returns (uint256 token, bytes32 root, bytes32 id)
    {
        IStreamMintGate.GateResult memory g = validate(b, msg.sender, "");
        (root, id) = preview(b, msg.sender);
        if (!omitReplay) {
            isOperationRootUsed[root] = true;
            isAuthorizationUsed[b.authorizationId] = true;
            for (uint256 i; i < g.nullifiers.length; ++i) {
                require(!isNullifierUsed[g.nullifiers[i]], "replay");
                isNullifierUsed[g.nullifiers[i]] = true;
            }
        }
        ++nonce;
        token = ERC20BurnGateCore(core).mint(b.collectionId, b.initialRecipients[0]);
    }
}

/// @dev Deliberately hostile immutable carrier fixture. Actual payment/signatures live in current tests.
contract ERC20BurnGateCarrier is IStreamERC20BurnMintContinuation {
    address public immutable core;
    address public immutable moduleRegistry;
    ERC20BurnGateManager public immutable mintManager;
    address public constant primarySaleSettlement = address(0x9999);
    StreamERC20BurnMintGate public gate;
    U.SaleRecord private sale;
    uint256 public attack;
    uint256 public corruption;
    uint256 public mode;
    uint256 public writes;
    bytes32 private request;

    constructor(address c, address r, ERC20BurnGateManager m) {
        core = c;
        moduleRegistry = r;
        mintManager = m;
    }

    function configure(StreamERC20BurnMintGate g, U.SaleRecord memory s) external {
        gate = g;
        sale = s;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamERC20BurnMintSale).interfaceId;
    }

    function saleRecord(bytes32) external view returns (U.SaleRecord memory) {
        return sale;
    }

    function authorizationDigest(U.SaleAuthorization memory a) public pure returns (bytes32) {
        return keccak256(abi.encode(a));
    }

    function setAttack(uint256 a, uint256 c) external {
        attack = a;
        corruption = c;
    }

    function attemptWrite() external returns (uint256) {
        return ++writes;
    }

    function batch(E.Execution memory e) public view returns (M.MintBatch memory b) {
        b.collectionId = sale.config.collectionId;
        b.phaseId = sale.config.phaseId;
        b.payer = e.sale.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = e.sale.authorization.recipient;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.sale.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.sale.authorization.mintCommitment;
        b.expectedPolicyHash = sale.config.mintPolicyHash;
        b.contextHash = authorizationDigest(e.sale.authorization);
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), b.contextHash)
        );
    }

    function preview(E.Execution memory e) external returns (S.ERC20SettlementCandidate memory) {
        return previewWithBatch(batch(e), e);
    }

    function previewWithBatch(M.MintBatch memory b, E.Execution memory e)
        public
        returns (S.ERC20SettlementCandidate memory c)
    {
        require(mode == 0, "busy");
        mode = 1;
        request = keccak256(abi.encode(e));
        c = gate.previewERC20Burn(b, e);
        mode = 0;
        request = 0;
    }

    function run(E.Execution memory e) external returns (E.Result memory r) {
        require(mode == 0, "busy");
        mode = 2;
        request = keccak256(abi.encode(e));
        r = gate.executeERC20Burn(batch(e), e);
        require(mode == 3, "callback missing");
        mode = 0;
        request = 0;
    }

    function previewBurnExecution(E.Execution calldata e)
        external
        view
        override
        returns (S.ERC20SettlementCandidate memory c)
    {
        require(
            msg.sender == address(gate) && (mode == 1 || mode == 2)
                && request == keccak256(abi.encode(e)),
            "fixed callback"
        );
        M.MintBatch memory b = batch(e);
        if (attack == 1) {
            (bool ok,) = address(gate).staticcall{ gas: 500000 }(
                abi.encodeCall(gate.previewERC20Burn, (b, e))
            );
            require(!ok, "preview reentered");
        }
        if (attack == 2) {
            // Manager sees the admitted carrier and a valid proof, but STATICCALL forbids replay writes.
            (bool ok,) = address(mintManager).staticcall{ gas: 500000 }(
                abi.encodeCall(mintManager.execute, (b))
            );
            require(!ok, "preview minted");
        }
        if (attack == 3) {
            (bool ok,) =
                address(this).staticcall{ gas: 500000 }(abi.encodeCall(this.attemptWrite, ()));
            require(!ok, "preview mutated");
        }
        if (attack == 4) {
            b.initialRecipients[0] = address(0xBAD);
            mintManager.preview(b, address(this));
        }
        if (attack == 5) mintManager.validate(b, address(this), "nonempty");
        c = _candidate(e, b);
        if (corruption == 1) c.saleExecutionHash = keccak256("wrong full input");
        if (corruption == 2) c.executor = address(0xBAD);
        if (corruption == 3) c.sale.beneficiary = address(0xBAD);
        if (corruption == 4) c.sale.saleNonce++;
        if (corruption == 5) c.asset = address(0xBAD);
        if (corruption == 6) c.lifecycleBinding.paymentAdapter = address(0xBAD);
        if (corruption == 7) c.operationId = 0;
        if (corruption == 8) c.rights.templateId = bytes32(uint256(1));
    }

    function _candidate(E.Execution memory e, M.MintBatch memory b)
        private
        view
        returns (S.ERC20SettlementCandidate memory c)
    {
        c.saleAdapter = address(this);
        c.executor = e.sale.authorization.executor;
        c.sale = S.PrimarySale(
            e.sale.authorization.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            b.collectionId,
            0,
            sale.saleNonce,
            b.payer,
            address(0),
            b.beneficiaries[0],
            sale.config.price,
            sale.config.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = sale.lifecycle;
        c.executionBinding =
            S.SaleExecutionBinding(0, e.sale.authorization.executionNonce, 1, b.contextHash);
        c.asset = sale.config.asset;
        c.orchestrationOrder = 1;
        c.mintManager = address(mintManager);
        (c.operationIdentityCommitment, c.operationId) = mintManager.preview(b, address(this));
        c.currentPolicyHash = b.expectedPolicyHash;
        c.boundPolicyHash = b.expectedPolicyHash;
        c.rights = S.PrimaryRights(
            keccak256("PROFILE"), address(0x7777), 0, keccak256("assignment"), keccak256("entries")
        );
        c.saleExecutionHash = keccak256(abi.encode(e));
        c.executionBinding.executionId = Hash.executionId(c);
    }

    function executeBurnMint(E.Execution calldata e) external override returns (E.Result memory r) {
        require(
            msg.sender == address(gate) && mode == 2 && request == keccak256(abi.encode(e)),
            "actual proof only"
        );
        mode = 3;
        M.MintBatch memory b = batch(e);
        if (attack == 6) b.initialRecipients[0] = address(0xBAD);
        S.ERC20SettlementCandidate memory c = _candidate(e, b);
        (r.tokenId, r.operationRoot, r.operationId) = mintManager.execute(b);
        r.settlement = S.PrimarySettlementResult(
            Hash.candidateCommitment(c.lifecycleBinding.paymentAdapter, primarySaleSettlement, c),
            Hash.settlementKey(
                primarySaleSettlement, address(this), c.executionBinding.executionId
            ),
            c.rights.profileId,
            c.rights.wallet,
            c.asset,
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            false,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        if (corruption == 9) r.operationRoot = bytes32(uint256(1));
        if (corruption == 10) r.settlement.candidateCommitment = bytes32(uint256(1));
        if (corruption == 11) r.tokenId = 1;
        if (corruption == 12) r.settlement.amount++;
        if (corruption == 13) r.settlement.escrowed = true;
        if (attack == 7) ERC20BurnGateRegistry(moduleRegistry).set(address(gate), false);
    }
}

contract ERC20BurnGateReceiver is IERC721Receiver {
    bool public reject = true;

    function allow() external {
        reject = false;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(!reject, "late receiver rejection");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Focused gate tests with explicit Core/Manager/carrier boundary fixtures.
contract StreamERC20BurnMintGateTest {
    ERC20BurnGateVm private constant vm =
        ERC20BurnGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant HOLDER = address(0xB0B);
    address private constant RECIPIENT = address(0xCAFE);
    bytes32 private constant PHASE = keccak256("erc20 burn phase");
    ERC20BurnGateCore private core;
    ERC20BurnGateRegistry private registry;
    ERC20BurnGateManager private manager;
    ERC20BurnGateCarrier private carrier;
    StreamERC20BurnMintGate private gate;
    bytes32 private configHash;

    function setUp() public {
        vm.warp(1000);
        core = new ERC20BurnGateCore();
        registry = new ERC20BurnGateRegistry();
        manager = new ERC20BurnGateManager(address(core), address(registry));
        core.configure(address(registry), address(manager));
        carrier = new ERC20BurnGateCarrier(address(core), address(registry), manager);
        gate = new StreamERC20BurnMintGate(
            StreamERC20BurnMintGate.Configuration(
                address(core),
                address(registry),
                address(carrier),
                address(new ERC20BurnGateAuthority()),
                address(this),
                keccak256("deployment"),
                keccak256("manifest"),
                "ipfs://erc20-burn",
                G.GasParameterConfig("BURN_DEPENDENCY_READ_GAS", 150000, 100000, 2),
                G.GasParameterConfig("BURN_EXECUTION_GAS", 400000, 200000, 2)
            )
        );
        registry.set(address(gate), true);
        registry.set(address(carrier), true);
        uint256[] memory sources = new uint256[](1);
        sources[0] = 1;
        configHash = gate.configureProgram(
            B.ProgramConfig(address(manager), 2, PHASE, sources, 2, 1000, 2000, false, address(0))
        );
        manager.install(address(gate), configHash);
        U.SaleRecord memory sale;
        sale.config = U.SaleConfig(
            address(0x2020),
            2,
            PHASE,
            address(0xE20),
            100,
            1000,
            2000,
            keccak256("mint policy"),
            keccak256("primary policy")
        );
        sale.saleNonce = 1;
        sale.configHash = keccak256("sale config");
        sale.lifecycle = S.SaleLifecycleBinding(address(0x2020), 1000, 1, 1);
        carrier.configure(gate, sale);
        core.source(1, 1, HOLDER);
        core.source(2, 1, HOLDER);
        core.approveAll(HOLDER, address(gate), true);
    }

    function _execution() private pure returns (E.Execution memory e) {
        e.sale.authorization = U.SaleAuthorization(
            keccak256("sale id"),
            keccak256("sale config"),
            HOLDER,
            HOLDER,
            RECIPIENT,
            address(0xA11),
            keccak256("art bytes"),
            keccak256("commitment"),
            1,
            keccak256("nonce"),
            2000
        );
        e.sale.tokenData = "art bytes";
        e.sourceTokenIds = new uint256[](2);
        e.sourceTokenIds[0] = 1;
        e.sourceTokenIds[1] = 2;
    }

    function _unchanged() private view {
        require(
            core.ownerOf(1) == HOLDER && core.ownerOf(2) == HOLDER && core.minted() == 100,
            "burn/mint rollback"
        );
        require(
            manager.nonce() == 0 && !manager.isNullifierUsed(gate.burnNullifier(1))
                && carrier.mode() == 0,
            "replay/frame rollback"
        );
    }

    function _proofUnavailable(E.Execution memory e) private {
        M.MintBatch memory b = carrier.batch(e);
        vm.expectRevert();
        manager.validate(b, address(carrier), "");
    }

    function testPreviewEqualsActualCandidateAndLeavesNoProof() public {
        E.Execution memory e = _execution();
        _proofUnavailable(e);
        S.ERC20SettlementCandidate memory c = carrier.preview(e);
        require(c.operationIdentityCommitment == _originalProofRoot(e), "original result preimage");
        _unchanged();
        _proofUnavailable(e);
        E.Result memory r = carrier.run(e);
        require(
            r.operationRoot == c.operationIdentityCommitment && r.operationId == c.operationId,
            "same prospective burn facts"
        );
        require(
            r.settlement.candidateCommitment
                == Hash.candidateCommitment(
                    c.lifecycleBinding.paymentAdapter, carrier.primarySaleSettlement(), c
                ),
            "exact candidate"
        );
        require(
            core.ownerOf(101) == RECIPIENT && manager.isNullifierUsed(gate.burnNullifier(1))
                && manager.isNullifierUsed(gate.burnNullifier(2)),
            "actual proof consumed"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(exists && collection == 1 && serial == 1 && burned, "retained identity");
        _proofUnavailable(e);
    }

    function _originalProofRoot(E.Execution memory e) private view returns (bytes32) {
        M.MintBatch memory b = carrier.batch(e);
        address[] memory owners = new address[](2);
        owners[0] = HOLDER;
        owners[1] = HOLDER;
        uint256[] memory collections = new uint256[](2);
        collections[0] = 1;
        collections[1] = 1;
        uint256[] memory serials = new uint256[](2);
        serials[0] = 1;
        serials[1] = 2;
        bytes32[] memory nullifiers = new bytes32[](2);
        nullifiers[0] = gate.burnNullifier(1);
        nullifiers[1] = gate.burnNullifier(2);
        bytes32 gateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_BURN_MINT_RESULT_V1"),
                block.chainid,
                address(gate),
                address(core),
                configHash,
                HOLDER,
                b,
                e.sourceTokenIds,
                owners,
                collections,
                serials,
                nullifiers
            )
        );
        IStreamMintGate.GateResult memory g =
            IStreamMintGate.GateResult(b.authorizationId, nullifiers, address(0), 0, 1, gateHash);
        return keccak256(abi.encode(uint256(0), b, g));
    }

    function testOriginalProgramAndNullifierDomainsAndNoFreeInterface() public view {
        B.Program memory p = gate.program(2);
        require(
            p.configHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_BURN_MINT_CONFIG_V1"),
                        block.chainid,
                        address(gate),
                        address(core),
                        address(registry),
                        p.config
                    )
                ),
            "original program hash"
        );
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
            "original nullifier"
        );
        require(
            !gate.supportsInterface(type(B).interfaceId)
                && gate.supportsInterface(type(IStreamERC20BurnMintGate).interfaceId),
            "dedicated capability only"
        );
        require(
            gate.erc20SaleAdapter() == address(carrier)
                && gate.erc20SaleCodeHash() == address(carrier).codehash,
            "immutable carrier identity"
        );
    }

    function testPreviewGuardBlocksReentrancyMutableCallbackAndStorageWrite() public {
        E.Execution memory e = _execution();
        for (uint256 i = 1; i <= 3; ++i) {
            carrier.setAttack(i, 0);
            carrier.preview(e);
            _unchanged();
            _proofUnavailable(e);
            require(carrier.writes() == 0, "static descendants");
        }
    }

    function testPreviewFailureClearsProofAndIdenticalRequestRetries() public {
        E.Execution memory e = _execution();
        carrier.setAttack(4, 0);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        _proofUnavailable(e);
        carrier.setAttack(0, 0);
        carrier.preview(e);
        _unchanged();
        _proofUnavailable(e);
    }

    function testNonemptyGateDataFailsAndProofCannotBeUsedByAnotherExecutor() public {
        E.Execution memory e = _execution();
        carrier.setAttack(5, 0);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        _proofUnavailable(e);
        carrier.setAttack(0, 0);
        M.MintBatch memory b = carrier.batch(e);
        vm.expectRevert();
        gate.previewERC20Burn(b, e);
        vm.expectRevert();
        gate.executeERC20Burn(b, e);
        _unchanged();
    }

    function testSourceActorAndGateApprovalsAreIndependent() public {
        E.Execution memory e = _execution();
        e.sale.authorization.executor = address(0xA7);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        core.approveAll(HOLDER, address(0xA7), true);
        core.approveAll(HOLDER, address(gate), false);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        core.approveAll(HOLDER, address(gate), true);
        carrier.run(e);
        require(core.ownerOf(101) == RECIPIENT, "independent operator authority");
    }

    function testTokenSpecificGateApprovalAndSeparateActorApproval() public {
        core.approveAll(HOLDER, address(gate), false);
        core.approveToken(1, address(gate));
        core.approveToken(2, address(gate));
        carrier.run(_execution());
        require(core.ownerOf(101) == RECIPIENT, "token approvals");
    }

    function testSourcesSortedDistinctAllowedUnburnedAndExactRatio() public {
        E.Execution memory e = _execution();
        e.sourceTokenIds[1] = 1;
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        e.sourceTokenIds[0] = 2;
        e.sourceTokenIds[1] = 1;
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        core.source(3, 3, HOLDER);
        e.sourceTokenIds[0] = 1;
        e.sourceTokenIds[1] = 3;
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        e.sourceTokenIds = new uint256[](17);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        e.sourceTokenIds = new uint256[](1);
        e.sourceTokenIds[0] = 1;
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
    }

    function testBatchRecipientExecutorPayerTokenAndPolicyBinding() public {
        E.Execution memory e = _execution();
        M.MintBatch memory b = carrier.batch(e);
        b.initialRecipients[0] = address(0xBAD);
        vm.expectRevert();
        carrier.previewWithBatch(b, e);
        _unchanged();
        b = carrier.batch(e);
        b.payer = address(0xBAD);
        vm.expectRevert();
        carrier.previewWithBatch(b, e);
        _unchanged();
        b = carrier.batch(e);
        b.tokenData[0] = "different";
        vm.expectRevert();
        carrier.previewWithBatch(b, e);
        _unchanged();
        b = carrier.batch(e);
        b.expectedPolicyHash = keccak256("wrong");
        vm.expectRevert();
        carrier.previewWithBatch(b, e);
        _unchanged();
        b = carrier.batch(e);
        e.sale.authorization.executor = address(0xBAD);
        vm.expectRevert();
        carrier.previewWithBatch(b, e);
        _unchanged();
    }

    function testEveryCandidateMismatchRejectsBeforeMintAndClearsProof() public {
        E.Execution memory e = _execution();
        for (uint256 i = 1; i <= 8; ++i) {
            carrier.setAttack(0, i);
            vm.expectRevert();
            carrier.preview(e);
            _unchanged();
            _proofUnavailable(e);
        }
    }

    function testLateResultMismatchRollsBackBurnAndReplayWithExactRetry() public {
        E.Execution memory e = _execution();
        for (uint256 i = 9; i <= 12; ++i) {
            carrier.setAttack(0, i);
            vm.expectRevert();
            carrier.run(e);
            _unchanged();
            _proofUnavailable(e);
        }
        carrier.setAttack(0, 0);
        carrier.run(e);
        require(core.ownerOf(101) == RECIPIENT, "identical retry");
    }

    function testOfficialRevenueEscrowFlagRemainsSupported() public {
        carrier.setAttack(0, 13);
        E.Result memory r = carrier.run(_execution());
        require(
            r.settlement.escrowed && core.ownerOf(101) == RECIPIENT,
            "existing escrow result supported"
        );
    }

    function testChangedCallbackRecipientAndMissingLedgerConsumptionRollback() public {
        E.Execution memory e = _execution();
        carrier.setAttack(6, 0);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        carrier.setAttack(0, 0);
        manager.setOmitReplay(true);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        manager.setOmitReplay(false);
        carrier.run(e);
    }

    function testLateReceiverFailureRollsBackAndIdenticalExecutionRetries() public {
        E.Execution memory e = _execution();
        ERC20BurnGateReceiver recipient = new ERC20BurnGateReceiver();
        e.sale.authorization.recipient = address(recipient);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        _proofUnavailable(e);
        recipient.allow();
        carrier.run(e);
        require(core.ownerOf(101) == address(recipient), "exact retry");
    }

    function testBurnFailureAndCorruptRetainedIdentityRollback() public {
        E.Execution memory e = _execution();
        core.setBurnFailure(true, false);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        core.setBurnFailure(false, true);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        core.setBurnFailure(false, false);
        carrier.run(e);
    }

    function testModuleAdmissionAndLateRevocationRollback() public {
        E.Execution memory e = _execution();
        registry.set(address(gate), false);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        registry.set(address(gate), true);
        registry.set(address(carrier), false);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        registry.set(address(carrier), true);
        carrier.setAttack(7, 0);
        vm.expectRevert();
        carrier.run(e);
        _unchanged();
        require(registry.enabled(address(gate)), "late registry write rolled back");
    }

    function testPinnedPhaseAndCurrentCorePointers() public {
        E.Execution memory e = _execution();
        manager.install(address(gate), keccak256("wrong config"));
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        manager.install(address(gate), configHash);
        core.configure(address(registry), address(0xBAD));
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        core.configure(address(registry), address(manager));
        carrier.run(e);
    }

    function testWindowBoundsAndImmutableProgram() public {
        E.Execution memory e = _execution();
        vm.warp(999);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        vm.warp(2001);
        vm.expectRevert();
        carrier.preview(e);
        _unchanged();
        vm.warp(2000);
        carrier.preview(e);
        B.Program memory p = gate.program(2);
        vm.expectRevert();
        gate.configureProgram(p.config);
    }

    function testPreparedNativeAndUnsortedProgramSourceConfigurationReject() public {
        B.Program memory p = gate.program(2);
        p.config.targetCollectionId = 3;
        p.config.prepared = true;
        vm.expectRevert();
        gate.configureProgram(p.config);
        p.config.prepared = false;
        p.config.nativeSaleAdapter = address(carrier);
        vm.expectRevert();
        gate.configureProgram(p.config);
        p.config.nativeSaleAdapter = address(0);
        p.config.sourceCollectionIds = new uint256[](2);
        p.config.sourceCollectionIds[0] = 2;
        p.config.sourceCollectionIds[1] = 1;
        vm.expectRevert();
        gate.configureProgram(p.config);
    }

    function testBurnCallbackCannotReenterPreviewOrExecution() public {
        E.Execution memory e = _execution();
        core.callback(address(gate), abi.encodeCall(gate.previewERC20Burn, (carrier.batch(e), e)));
        carrier.run(e);
        require(!core.reentered(), "burn callback guard");
    }

    function testConsumedNullifierRejectsPreviewAndChangedCarrierCodeFailsClosed() public {
        E.Execution memory e = _execution();
        manager.setNullifier(gate.burnNullifier(1), true);
        vm.expectRevert();
        carrier.preview(e);
        manager.setNullifier(gate.burnNullifier(1), false);
        _unchanged();
        M.MintBatch memory b = carrier.batch(e);
        vm.etch(address(carrier), hex"60006000fd");
        vm.expectRevert();
        vm.prank(address(carrier));
        gate.previewERC20Burn(b, e);
    }
}
