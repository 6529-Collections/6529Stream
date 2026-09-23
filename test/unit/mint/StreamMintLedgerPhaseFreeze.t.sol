// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Intentionally mutable typed Manager boundary. Every write reaches the actual Ledger
/// from this contract; no prank impersonates a production Manager. This isolates the Ledger's
/// independent restrictions from the production Manager's initial-only phase configuration.
contract PhaseFreezeLedgerWriterBoundary {
    StreamMintLedger public immutable mintLedger;
    address public core;
    address public moduleRegistry;
    address public immutable governanceAuthority;
    bytes32 public constant FIRST = keccak256("freeze first counter");
    bytes32 public constant SECOND = keccak256("freeze second counter");

    struct Phase {
        bool exists;
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] ids;
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) counters;
        address[] executors;
        bytes32 policy;
        IStreamMintRoyaltyPolicy.Policy royalty;
    }
    mapping(bytes32 => Phase) private phases;
    uint256 private royaltyReadMode;

    constructor(StreamMintLedger ledger_, address core_, address registry_, address authority_) {
        mintLedger = ledger_;
        core = core_;
        moduleRegistry = registry_;
        governanceAuthority = authority_;
    }

    function configure(bytes32 phaseId, address[] memory enabled, bytes32 firstDefinition)
        external
    {
        _configure(phaseId, enabled, firstDefinition);
        _register(phaseId, 0);
    }

    function configureRoyalty(
        bytes32 phaseId,
        address[] memory enabled,
        bytes32 firstDefinition,
        IStreamMintRoyaltyPolicy.Policy calldata royalty,
        bytes32 wrapper
    ) external {
        _configure(phaseId, enabled, firstDefinition);
        phases[phaseId].royalty = royalty;
        phases[phaseId].config.configHash = wrapper;
        _register(phaseId, 0);
    }

    function setRoyalty(
        bytes32 phaseId,
        IStreamMintRoyaltyPolicy.Policy calldata royalty,
        bytes32 wrapper
    ) external {
        phases[phaseId].royalty = royalty;
        phases[phaseId].config.configHash = wrapper;
        _register(phaseId, 0);
    }

    function setRoyaltyReadMode(uint256 mode) external {
        royaltyReadMode = mode;
    }

    function _configure(bytes32 phaseId, address[] memory enabled, bytes32 firstDefinition)
        private
    {
        Phase storage p = phases[phaseId];
        p.exists = true;
        p.config = IStreamMintManager.MintPhaseConfig(
            false, 100, 0, 4, keccak256("published config"), keccak256("phase metadata")
        );
        p.gate = IStreamMintManager.MintGateConfig(address(0), 0, 0, 0, 0, 0);
        delete p.ids;
        p.ids.push(FIRST);
        p.ids.push(SECOND);
        p.counters[FIRST] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            firstDefinition
        );
        p.counters[SECOND] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("second legacy definition")
        );
        p.executors = enabled;
        delete p.royalty;
    }

    function setExecutors(bytes32 phaseId, address[] memory enabled, uint64 graceUntil) external {
        phases[phaseId].executors = enabled;
        _register(phaseId, graceUntil);
    }

    function mutate(bytes32 phaseId, uint256 kind) external {
        Phase storage p = phases[phaseId];
        if (kind == 0) p.config.paused = !p.config.paused;
        else if (kind == 1) p.config.maxBatchQuantity++;
        else if (kind == 2) p.counters[FIRST].staticCap++;
        else if (kind == 3) (p.ids[0], p.ids[1]) = (p.ids[1], p.ids[0]);
        else if (kind == 4) p.gate.gateConfigHash = keccak256("changed gate");
        else if (kind == 5) core = address(mintLedger);
        else if (kind == 6) moduleRegistry = address(mintLedger);
        else if (kind == 7) p.config.endTime = 50000;
        else if (kind == 8) p.config.metadataHash = keccak256("changed metadata");
        _register(phaseId, 0);
    }

    function inconsistentLedgerRow(bytes32 phaseId) external {
        Phase storage p = phases[phaseId];
        IStreamMintLedger.LedgerCounterPolicy[] memory policies = _policies(p);
        policies[0].staticCap++;
        mintLedger.registerPhasePolicy(address(this), 1, phaseId, p.policy, p.ids, policies, 0);
    }

    function freeze(bytes32 phaseId) external {
        mintLedger.freezePhase(1, phaseId, phases[phaseId].policy);
    }

    function freezeAs(bytes32 phaseId, bytes32 policy) external {
        mintLedger.freezePhase(1, phaseId, policy);
    }

    function consume(bytes32 phaseId, bytes32 root) external {
        mintLedger.consume(
            1,
            phaseId,
            new IStreamMintLedger.CounterConsumption[](0),
            root,
            new bytes32[](0),
            phases[phaseId].policy,
            root
        );
    }

    function phase(uint256, bytes32 phaseId)
        external
        view
        returns (bool, IStreamMintManager.MintPhaseConfig memory)
    {
        return (phases[phaseId].exists, phases[phaseId].config);
    }

    function phaseGate(uint256, bytes32 phaseId)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return phases[phaseId].gate;
    }

    function phasePolicyHash(uint256, bytes32 phaseId) external view returns (bytes32) {
        return phases[phaseId].policy;
    }

    function phaseCounterIds(uint256, bytes32 phaseId) external view returns (bytes32[] memory) {
        return phases[phaseId].ids;
    }

    function counterConfig(uint256, bytes32 phaseId, bytes32 id)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        return phases[phaseId].counters[id];
    }

    function phaseExecutors(uint256, bytes32 phaseId) external view returns (address[] memory) {
        return phases[phaseId].executors;
    }

    function phaseRoyaltyPolicy(uint256, bytes32 phaseId)
        external
        view
        returns (IStreamMintRoyaltyPolicy.Policy memory p)
    {
        p = phases[phaseId].royalty;
        uint256 mode = royaltyReadMode;
        if (mode == 0) return p;
        if (mode == 1) revert("typed royalty getter failure");
        bytes memory raw = abi.encode(p);
        if (mode == 2) assembly { return(add(raw, 32), 223) }
        if (mode == 3) assembly { return(add(raw, 32), 256) }
        // Exact width with noncanonical bool, rejected by the original strict struct decode.
        assembly {
            mstore(add(raw, 32), 2)
            return(add(raw, 32), 224)
        }
    }

    function _register(bytes32 phaseId, uint64 graceUntil) private {
        Phase storage p = phases[phaseId];
        IStreamMintManager.MintPhaseConfig memory config = p.config;
        config.paused = false;
        p.policy = keccak256(
            abi.encode(
                address(this),
                address(mintLedger),
                core,
                moduleRegistry,
                phaseId,
                config,
                p.gate,
                p.ids,
                p.counters[FIRST],
                p.counters[SECOND],
                p.executors,
                p.royalty
            )
        );
        mintLedger.registerPhasePolicy(
            address(this), 1, phaseId, p.policy, p.ids, _policies(p), graceUntil
        );
    }

    function _policies(Phase storage p)
        private
        view
        returns (IStreamMintLedger.LedgerCounterPolicy[] memory policies)
    {
        policies = new IStreamMintLedger.LedgerCounterPolicy[](p.ids.length);
        for (uint256 i; i < p.ids.length; ++i) {
            IStreamMintManager.MintCounterConfig memory c = p.counters[p.ids[i]];
            policies[i] = IStreamMintLedger.LedgerCounterPolicy(
                c.enabled,
                c.capMode,
                c.deltaMode,
                c.staticCap,
                c.staticIncrement,
                c.counterConfigHash
            );
        }
    }
}

/// @dev Historical capability/ABI boundary only. Real freeze inheritance uses actual Ledgers.
contract PhaseFreezeLegacyLedgerBoundary {
    uint256 private immutable mode;

    constructor(uint256 mode_) {
        mode = mode_;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (id != type(IStreamMintLedgerPhaseFreeze).interfaceId) return true;
        if (mode == 0) return false;
        if (mode == 1) revert("legacy capability unavailable");
        if (mode == 2) assembly { return(0, 31) }
        if (mode == 3) {
            assembly {
                mstore(0, 1)
                return(0, 64)
            }
        }
        if (mode == 4) {
            assembly {
                mstore(0, 2)
                return(0, 32)
            }
        }
        return true;
    }

    function frozenPhaseCount(address) external pure returns (uint256) {
        revert("missing freeze state");
    }

    function ledgerWriterRetiredAt(address) external view returns (uint64) {
        return uint64(block.number);
    }

    function ledgerWriter(address) external pure returns (bool) {
        return false;
    }

    function managerDefinitionCount(address) external pure returns (uint256) {
        return 0;
    }

    function mintAncestorCount(address) external pure returns (uint256) {
        return 0;
    }
}

/// @notice Actual Ledger freeze, registration, retirement, import and completion restrictions.
/// @dev Typed mutable Manager and governance context boundaries; actual Manager/Artist/Safe
/// authorization and executor bootstrap belong to the separate current-stack tests.
contract StreamMintLedgerPhaseFreezeTest is CharacterizationTestBase {
    bytes32 private constant PHASE = keccak256("frozen phase");
    bytes32 private constant OTHER = keccak256("other frozen phase");
    bytes32 private constant DEFINITION = keccak256("first legacy definition");
    bytes32 private constant MANIFEST = keccak256("complete zero-consumption freeze inventory");
    address private constant A = address(0xA11CE);
    address private constant B = address(0xB0B);
    address private constant C = address(0xCAFE);
    StreamMintLedger private ledger;
    MockGovernedParameterAuthority private authority;
    PhaseFreezeLedgerWriterBoundary private first;

    function setUp() public {
        vm.roll(100);
        vm.warp(1000);
        authority = new MockGovernedParameterAuthority(true);
        ledger = new StreamMintLedger();
        first = _writer(ledger);
        first.configure(PHASE, _executors(2), DEFINITION);
    }

    function _executors(uint256 n) private pure returns (address[] memory list) {
        list = new address[](n);
        if (n > 0) list[0] = A;
        if (n > 1) list[1] = B;
        if (n > 2) list[2] = C;
    }

    function _writer(StreamMintLedger target)
        private
        returns (PhaseFreezeLedgerWriterBoundary writer)
    {
        writer = new PhaseFreezeLedgerWriterBoundary(
            target, address(this), address(authority), address(authority)
        );
        address admin = target.owner();
        vm.prank(admin);
        target.setLedgerWriter(address(writer), true);
    }

    function _freeze() private returns (IStreamMintLedgerPhaseFreeze.PhaseFreeze memory fact) {
        first.freeze(PHASE);
        return ledger.phaseFreeze(address(first), 1, PHASE);
    }

    function _retire(StreamMintLedger target, address writer) private {
        address admin = target.owner();
        vm.prank(admin);
        target.retireLedgerWriter(writer);
    }

    function _root(address source, address prior, StreamMintLedger destination, address next)
        private
        view
        returns (bytes32)
    {
        // No operation consumed counters/nullifiers in these migration scenarios. The genuine
        // descriptor is the sole leaf; definitions and freeze inventory have separate cursors.
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(destination),
                        source,
                        prior,
                        next,
                        uint64(block.number),
                        MANIFEST,
                        uint64(0),
                        uint64(0)
                    )
                )
            )
        );
    }

    function _authorize(
        address source,
        address prior,
        StreamMintLedger destination,
        address next,
        bytes32 root
    ) private {
        if (destination.owner() == address(this)) {
            destination.transferOwnership(address(authority));
        }
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(destination),
                next
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                source,
                prior,
                next,
                uint64(block.number),
                root,
                MANIFEST
            )
        );
        authority.setCurrentAction(
            true, keccak256(abi.encode("freeze import", root)), 1, scope, 0, value
        );
    }

    function _commit(address source, address prior, StreamMintLedger destination, address next)
        private
        returns (bytes32 root)
    {
        root = _root(source, prior, destination, next);
        _authorize(source, prior, destination, next, root);
        vm.prank(address(authority));
        destination.commitCounterImportRoot(
            source, prior, next, uint64(block.number), root, MANIFEST
        );
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _begin(PhaseFreezeLedgerWriterBoundary prior, PhaseFreezeLedgerWriterBoundary next)
        private
        returns (bytes32 root)
    {
        _retire(ledger, address(prior));
        root = _commit(address(ledger), address(prior), ledger, address(next));
        ledger.importCounterDefinitions(root, 32);
        ledger.importMintAncestors(root, 32);
    }

    function _complete(bytes32 root) private {
        ledger.completeCounterImport(root, 0, 0, new bytes32[](0));
    }

    function _mismatch(address manager) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerPhaseFreeze.MintPhaseFreezePolicyMismatch.selector,
                manager,
                uint256(1),
                PHASE
            )
        );
    }

    function _constraintHash(PhaseFreezeLedgerWriterBoundary writer)
        private
        view
        returns (bytes32)
    {
        (, IStreamMintManager.MintPhaseConfig memory config) = writer.phase(1, PHASE);
        config.paused = false;
        IStreamMintRoyaltyPolicy.Policy memory royalty = writer.phaseRoyaltyPolicy(1, PHASE);
        bytes32 royaltyBranch = keccak256("6529STREAM_MINT_PHASE_FREEZE_ROYALTY_UNCONFIGURED_V1");
        if (royalty.configured) {
            require(
                config.configHash == _royaltyWrapper(address(writer), royalty), "original wrapper"
            );
            config.configHash = royalty.applicationConfigHash;
            royaltyBranch = keccak256("6529STREAM_MINT_PHASE_FREEZE_ROYALTY_CONFIGURED_V1");
        }
        bytes32[] memory ids = writer.phaseCounterIds(1, PHASE);
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](ids.length);
        bool[] memory defined = new bool[](ids.length);
        IStreamMintCounterPolicy.Definition[] memory definitions =
            new IStreamMintCounterPolicy.Definition[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            counters[i] = writer.counterConfig(1, PHASE, ids[i]);
            definitions[i].scope = IStreamMintCounterPolicy.CounterScope.PHASE;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_FREEZE_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                address(authority),
                address(ledger),
                uint256(1),
                PHASE,
                config,
                writer.phaseGate(1, PHASE),
                ids,
                counters,
                defined,
                definitions,
                royaltyBranch,
                royalty.applicationConfigHash,
                royalty
            )
        );
    }

    function _royaltyPolicy() private view returns (IStreamMintRoyaltyPolicy.Policy memory) {
        return IStreamMintRoyaltyPolicy.Policy(
            true,
            keccak256("original royalty application config"),
            address(authority),
            address(authority).codehash,
            keccak256("original collection election"),
            keccak256("original mode assignment"),
            keccak256("original royalty source")
        );
    }

    function _royaltyWrapper(address manager, IStreamMintRoyaltyPolicy.Policy memory p)
        private
        view
        returns (bytes32)
    {
        // Independent literal preimage from StreamMintRoyaltyPolicy.configHash. This typed
        // Ledger fixture does not claim actual resolver/Artist royalty registration authority.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"),
                block.chainid,
                manager,
                uint256(1),
                PHASE,
                p.applicationConfigHash,
                p.resolver,
                p.resolverRuntimeHash,
                uint8(2),
                p.electionHash,
                p.expectedModeAssignmentHash,
                p.expectedSourceRoyaltyPolicyHash
            )
        );
    }

    function testOriginalFreezeCommitsExactConfigurationInventoryExecutorsAndEvent() public {
        bytes32 expected = _constraintHash(first);
        bytes32 policy = first.phasePolicyHash(1, PHASE);
        vm.recordLogs();
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory fact = _freeze();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            fact.policyHash == policy && fact.configurationHash == expected,
            "exact first freeze record"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(ledger) && logs[0].topics.length == 4,
            "one Ledger freeze receipt"
        );
        require(
            logs[0].topics[0]
                    == keccak256(
                        "MintLedgerPhaseFrozen(uint16,address,uint256,bytes32,bytes32,bytes32)"
                    ) && logs[0].topics[1] == bytes32(uint256(uint160(address(first))))
                && logs[0].topics[2] == bytes32(uint256(1)) && logs[0].topics[3] == PHASE,
            "exact freeze indexed fields"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(uint16(1), policy, expected)),
            "exact freeze receipt data"
        );
        (uint256 collection, bytes32 phaseId) = ledger.frozenPhaseAt(address(first), 0);
        require(
            collection == 1 && phaseId == PHASE && ledger.frozenPhaseCount(address(first)) == 1,
            "enumerable canonical identity"
        );
        require(
            keccak256(abi.encode(ledger.frozenPhaseExecutors(address(first), 1, PHASE)))
                == keccak256(abi.encode(_executors(2))),
            "original executor ceiling"
        );
        require(
            ledger.supportsInterface(type(IStreamMintLedgerPhaseFreeze).interfaceId)
                && ledger.supportsInterface(type(IStreamMintLedger).interfaceId),
            "additive capability retains original"
        );
    }

    function testUnauthorizedWrongPolicyUnconfiguredAndRepeatedFreezeReject() public {
        bytes32 policy = first.phasePolicyHash(1, PHASE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.UnauthorizedLedgerWriter.selector, address(this)
            )
        );
        ledger.freezePhase(1, PHASE, policy);
        _mismatch(address(first));
        first.freezeAs(PHASE, bytes32(uint256(1)));
        vm.expectRevert();
        first.freezeAs(OTHER, policy);
        _freeze();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerPhaseFreeze.MintPhaseFreezeInvalid.selector,
                address(first),
                uint256(1),
                PHASE
            )
        );
        first.freeze(PHASE);
        require(ledger.frozenPhaseCount(address(first)) == 1, "failure adds no freeze identity");
    }

    function testRemovalShrinksForeverWhilePauseAndOriginalGraceRemainOperational() public {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        first.mutate(PHASE, 0);
        require(
            first.phasePolicyHash(1, PHASE) == original.policyHash,
            "pause excluded from policy and freeze"
        );
        uint64 deadline = uint64(block.timestamp + 100);
        first.setExecutors(PHASE, _executors(1), deadline);
        (bytes32 previous, uint64 revision, uint64 until) =
            ledger.policyGrace(address(first), 1, PHASE);
        require(
            previous == original.policyHash && revision == 1 && until == deadline,
            "original policy grace remains exact"
        );
        bytes32 policy = first.phasePolicyHash(1, PHASE);
        _mismatch(address(first));
        first.setExecutors(PHASE, _executors(2), 0);
        require(
            first.phasePolicyHash(1, PHASE) == policy
                && ledger.registeredPhasePolicyHash(address(first), 1, PHASE) == policy,
            "failed re-add rolls back both stores"
        );
        require(
            ledger.frozenPhaseExecutors(address(first), 1, PHASE).length == 1
                && ledger.phaseFreeze(address(first), 1, PHASE).policyHash == original.policyHash,
            "first provenance and smaller ceiling retained"
        );
    }

    function testEveryFrozenRegistrationRejectsChangedTermsAndCounterProjection() public {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        for (uint256 kind = 1; kind <= 8; ++kind) {
            _mismatch(address(first));
            first.mutate(PHASE, kind);
            require(
                first.phasePolicyHash(1, PHASE) == original.policyHash
                    && ledger.registeredPhasePolicyHash(address(first), 1, PHASE)
                        == original.policyHash,
                "term mutation atomic rollback"
            );
        }
        _mismatch(address(first));
        first.inconsistentLedgerRow(PHASE);
        require(
            ledger.registeredCounterPolicy(address(first), 1, PHASE, first.FIRST()).staticCap == 10,
            "Ledger cannot silently loosen Manager snapshot"
        );
    }

    function testImportMustCopyEveryFreezeBeforeCompletionAndBlocksPendingConsumption() public {
        first.configure(OTHER, _executors(1), DEFINITION);
        _freeze();
        first.freeze(OTHER);
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        (uint256 imported, uint256 required) = ledger.mintImportFreezeProgress(root);
        require(imported == 0 && required == 2, "retired source inventory captured");
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        _complete(root);
        ledger.importPhaseFreezes(root, 1);
        next.configure(PHASE, ledger.frozenPhaseExecutors(address(next), 1, PHASE), DEFINITION);
        bytes32 operation = keccak256("pending import operation");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerImport.MintImportNotReady.selector, address(next)
            )
        );
        next.consume(PHASE, operation);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        _complete(root);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        require(
            ledger.isMintSuccessorReady(address(ledger), address(first), address(next)),
            "all freeze restrictions imported"
        );
        require(
            !ledger.isManagerOperationRootUsed(address(next), operation),
            "pending consumption rolls back"
        );
    }

    function testUnconfiguredSuccessorCompletesThenFirstRegistrationEnforcesInheritedCeiling()
        public
    {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        vm.recordLogs();
        ledger.importPhaseFreezes(root, 32);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1
                && keccak256(logs[0].data)
                    == keccak256(
                        abi.encode(
                            uint256(1),
                            PHASE,
                            original.policyHash,
                            bytes32(0),
                            original.configurationHash
                        )
                    ),
            "unconfigured import records zero successor policy honestly"
        );
        _complete(root);
        require(
            ledger.registeredPhasePolicyHash(address(next), 1, PHASE) == 0,
            "no synthetic successor policy"
        );
        _mismatch(address(next));
        next.configure(PHASE, _executors(3), DEFINITION);
        require(
            ledger.registeredPhasePolicyHash(address(next), 1, PHASE) == 0,
            "bad first registration rolls back"
        );
        next.configure(PHASE, ledger.frozenPhaseExecutors(address(next), 1, PHASE), DEFINITION);
        next.setExecutors(PHASE, _executors(1), 0);
        _mismatch(address(next));
        next.setExecutors(PHASE, _executors(2), 0);
        require(
            ledger.phaseFreeze(address(next), 1, PHASE).policyHash == original.policyHash,
            "original freeze provenance survives new Manager policy"
        );
    }

    function testPreconfiguredSuccessorCannotRestoreRemovedExecutorAndCanRetryCompatibleSubset()
        public
    {
        _freeze();
        first.setExecutors(PHASE, _executors(1), 0);
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        next.configure(PHASE, _executors(2), DEFINITION);
        bytes32 root = _begin(first, next);
        _mismatch(address(next));
        ledger.importPhaseFreezes(root, 32);
        require(
            ledger.frozenPhaseCount(address(next)) == 0, "failed copy leaves no inherited record"
        );
        next.setExecutors(PHASE, _executors(1), 0);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        _mismatch(address(next));
        next.setExecutors(PHASE, _executors(2), 0);
    }

    function testPreexistingCompatibleSuccessorFreezeRetainsItsFirstRecord() public {
        _freeze();
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        next.configure(PHASE, _executors(1), DEFINITION);
        next.freeze(PHASE);
        bytes32 firstNextPolicy = ledger.phaseFreeze(address(next), 1, PHASE).policyHash;
        bytes32 root = _begin(first, next);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        require(
            ledger.frozenPhaseCount(address(next)) == 1
                && ledger.phaseFreeze(address(next), 1, PHASE).policyHash == firstNextPolicy,
            "existing tighter freeze is not overwritten or duplicated"
        );
    }

    function testCrossLedgerCommitCannotEscapeFrozenRestrictions() public {
        _freeze();
        StreamMintLedger destination = new StreamMintLedger();
        PhaseFreezeLedgerWriterBoundary next = _writer(destination);
        _retire(ledger, address(first));
        bytes32 root = _root(address(ledger), address(first), destination, address(next));
        _authorize(address(ledger), address(first), destination, address(next), root);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerPhaseFreeze.MintPhaseFreezeLedgerMismatch.selector,
                address(ledger),
                address(destination)
            )
        );
        vm.prank(address(authority));
        destination.commitCounterImportRoot(
            address(ledger), address(first), address(next), uint64(block.number), root, MANIFEST
        );
        require(
            destination.mintImportCommitment(root).successorManager == address(0),
            "forbidden migration stores no commitment"
        );
    }

    function testMultipleGenerationsPreserveUnconfiguredFrozenPhaseAndOriginalLedger() public {
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        PhaseFreezeLedgerWriterBoundary middle = _writer(ledger);
        bytes32 firstRoot = _begin(first, middle);
        ledger.importPhaseFreezes(firstRoot, 32);
        _complete(firstRoot);
        PhaseFreezeLedgerWriterBoundary last = _writer(ledger);
        bytes32 secondRoot = _begin(middle, last);
        ledger.importPhaseFreezes(secondRoot, 32);
        _complete(secondRoot);
        require(
            ledger.phaseFreeze(address(last), 1, PHASE).policyHash == original.policyHash
                && ledger.phaseFreeze(address(last), 1, PHASE).configurationHash
                    == original.configurationHash,
            "inherited unconfigured phase is never omitted"
        );
        last.configure(PHASE, ledger.frozenPhaseExecutors(address(last), 1, PHASE), DEFINITION);
        _mismatch(address(last));
        last.setExecutors(PHASE, _executors(3), 0);
    }

    function testEffectiveLegacyDefinitionCannotBeReinterpretedBySuccessorFreeze() public {
        IStreamMintCounterPolicy.Definition memory definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            bytes32(0),
            keccak256("late published same-hash definition")
        );
        bytes32 definitionHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
        PhaseFreezeLedgerWriterBoundary prior = _writer(ledger);
        prior.configure(PHASE, _executors(2), definitionHash);
        prior.freeze(PHASE);
        ledger.registerCounterDefinition(definition);
        prior.setExecutors(PHASE, _executors(1), 0);
        (bool sourceDefined,) = ledger.counterDefinitionForManager(address(prior), definitionHash);
        require(!sourceDefined, "original freeze retains effective legacy selection");

        PhaseFreezeLedgerWriterBoundary incompatible = _writer(ledger);
        incompatible.configure(PHASE, _executors(1), definitionHash);
        (bool successorDefined,) =
            ledger.counterDefinitionForManager(address(incompatible), definitionHash);
        require(
            successorDefined, "same config hash can have different effective first-use selection"
        );
        _retire(ledger, address(prior));
        bytes32 rejected = _commit(address(ledger), address(prior), ledger, address(incompatible));
        _mismatch(address(incompatible));
        ledger.importPhaseFreezes(rejected, 32);
        require(
            ledger.frozenPhaseCount(address(incompatible)) == 0,
            "definition mismatch creates no freeze"
        );

        PhaseFreezeLedgerWriterBoundary compatible = _writer(ledger);
        bytes32 accepted = _commit(address(ledger), address(prior), ledger, address(compatible));
        ledger.importCounterDefinitions(accepted, 32);
        ledger.importMintAncestors(accepted, 32);
        ledger.importPhaseFreezes(accepted, 32);
        _complete(accepted);
        compatible.configure(
            PHASE, ledger.frozenPhaseExecutors(address(compatible), 1, PHASE), definitionHash
        );
        (bool inheritedDefined,) =
            ledger.counterDefinitionForManager(address(compatible), definitionHash);
        require(
            !inheritedDefined,
            "actual copied selection remains legacy despite later global definition"
        );
    }

    function testFreezeImportBatchBoundsAndRetiredWriterRemainClosed() public {
        _freeze();
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importPhaseFreezes(root, 0);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importPhaseFreezes(root, 33);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerImport.MintImportNotReady.selector, address(next)
            )
        );
        next.freezeAs(PHASE, bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.UnauthorizedLedgerWriter.selector, address(first)
            )
        );
        first.freeze(PHASE);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importPhaseFreezes(root, 1);
    }

    function testRoyaltySuccessionNormalizesOnlyExactManagerDomainAndRetainsOriginalFacts() public {
        IStreamMintRoyaltyPolicy.Policy memory royalty = _royaltyPolicy();
        bytes32 oldWrapper = _royaltyWrapper(address(first), royalty);
        first.setRoyalty(PHASE, royalty, oldWrapper);
        bytes32 expected = _constraintHash(first);
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        require(original.configurationHash == expected, "exact configured branch preimage");
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        bytes32 nextWrapper = _royaltyWrapper(address(next), royalty);
        require(oldWrapper != nextWrapper, "only original Manager wrapper domain changes");
        next.configureRoyalty(PHASE, _executors(2), DEFINITION, royalty, nextWrapper);
        require(
            _constraintHash(next) == expected
                && ledger.phaseFreeze(address(next), 1, PHASE).configurationHash == expected
                && ledger.phaseFreeze(address(next), 1, PHASE).policyHash == original.policyHash,
            "same exact economic commitment and first policy provenance"
        );
        (, IStreamMintManager.MintPhaseConfig memory config) = next.phase(1, PHASE);
        require(
            config.configHash == nextWrapper
                && next.phasePolicyHash(1, PHASE) != original.policyHash
                && ledger.registeredPhasePolicyHash(address(next), 1, PHASE)
                    == next.phasePolicyHash(1, PHASE)
                && keccak256(abi.encode(next.phaseRoyaltyPolicy(1, PHASE)))
                    == keccak256(abi.encode(royalty)),
            "fresh successor policy preserves full original royalty tuple"
        );
    }

    function testRoyaltySuccessionRejectsEveryIndividualEconomicFieldEvenWithValidNewWrapper()
        public
    {
        IStreamMintRoyaltyPolicy.Policy memory royalty = _royaltyPolicy();
        first.setRoyalty(PHASE, royalty, _royaltyWrapper(address(first), royalty));
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory original = _freeze();
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        for (uint256 field; field < 6; ++field) {
            IStreamMintRoyaltyPolicy.Policy memory changed = _royaltyPolicy();
            if (field == 0) {
                changed.applicationConfigHash = keccak256("different application");
            } else if (field == 1) {
                changed.resolver = address(ledger);
            } else if (field == 2) {
                changed.resolverRuntimeHash = keccak256("different resolver runtime");
            } else if (field == 3) {
                changed.electionHash = keccak256("different election");
            } else if (field == 4) {
                changed.expectedModeAssignmentHash = keccak256("different mode");
            } else {
                changed.expectedSourceRoyaltyPolicyHash = keccak256("different source");
            }
            bytes32 wrapper = _royaltyWrapper(address(next), changed);
            _mismatch(address(next));
            next.configureRoyalty(PHASE, _executors(2), DEFINITION, changed, wrapper);
            (bool exists,) = next.phase(1, PHASE);
            require(
                !exists && next.phasePolicyHash(1, PHASE) == 0
                    && ledger.registeredPhasePolicyHash(address(next), 1, PHASE) == 0
                    && !ledger.registeredCounterPolicy(address(next), 1, PHASE, first.FIRST())
                    .enabled
                    && ledger.phaseFreeze(address(next), 1, PHASE).configurationHash
                        == original.configurationHash,
                "economic substitution rolls back Manager and Ledger registration"
            );
        }
        next.configureRoyalty(
            PHASE, _executors(2), DEFINITION, royalty, _royaltyWrapper(address(next), royalty)
        );
    }

    function testRoyaltyConfiguredRawBranchSpoofsAndStaleManagerWrapperCannotCrossFreeze() public {
        IStreamMintRoyaltyPolicy.Policy memory royalty = _royaltyPolicy();
        bytes32 oldWrapper = _royaltyWrapper(address(first), royalty);
        first.setRoyalty(PHASE, royalty, oldWrapper);
        _freeze();
        IStreamMintRoyaltyPolicy.Policy memory raw = _royaltyPolicy();
        raw.configured = false;
        _mismatch(address(first));
        first.setRoyalty(PHASE, raw, raw.applicationConfigHash);
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        _mismatch(address(next));
        next.configureRoyalty(PHASE, _executors(2), DEFINITION, raw, raw.applicationConfigHash);
        IStreamMintRoyaltyPolicy.Policy memory empty;
        _mismatch(address(next));
        next.configureRoyalty(
            PHASE, _executors(2), DEFINITION, empty, royalty.applicationConfigHash
        );
        _mismatch(address(next));
        next.configureRoyalty(PHASE, _executors(2), DEFINITION, royalty, oldWrapper);
        require(
            ledger.registeredPhasePolicyHash(address(next), 1, PHASE) == 0,
            "branch swaps and stale domain never register"
        );
        next.configureRoyalty(
            PHASE, _executors(2), DEFINITION, royalty, _royaltyWrapper(address(next), royalty)
        );

        // Reverse direction: even a raw branch retaining every other identical tuple field
        // cannot become the configured branch with the same normalized application config.
        PhaseFreezeLedgerWriterBoundary rawPrior = _writer(ledger);
        rawPrior.configureRoyalty(PHASE, _executors(2), DEFINITION, raw, raw.applicationConfigHash);
        rawPrior.freeze(PHASE);
        PhaseFreezeLedgerWriterBoundary rawNext = _writer(ledger);
        bytes32 rawRoot = _begin(rawPrior, rawNext);
        ledger.importPhaseFreezes(rawRoot, 32);
        _complete(rawRoot);
        bytes32 newWrapper = _royaltyWrapper(address(rawNext), royalty);
        _mismatch(address(rawNext));
        rawNext.configureRoyalty(PHASE, _executors(2), DEFINITION, royalty, newWrapper);
        rawNext.configureRoyalty(PHASE, _executors(2), DEFINITION, raw, raw.applicationConfigHash);
    }

    function testRoyaltyGetterFailureShortOversizedAndNoncanonicalBoolFailClosed() public {
        IStreamMintRoyaltyPolicy.Policy memory royalty = _royaltyPolicy();
        first.setRoyalty(PHASE, royalty, _royaltyWrapper(address(first), royalty));
        for (uint256 mode = 1; mode <= 4; ++mode) {
            first.setRoyaltyReadMode(mode);
            _expectRoyaltyReadFailure(address(first), mode);
            first.freeze(PHASE);
            require(ledger.frozenPhaseCount(address(first)) == 0, "malformed source never freezes");
        }
        first.setRoyaltyReadMode(0);
        _freeze();
        PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
        bytes32 root = _begin(first, next);
        ledger.importPhaseFreezes(root, 32);
        _complete(root);
        bytes32 wrapper = _royaltyWrapper(address(next), royalty);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            next.setRoyaltyReadMode(mode);
            _expectRoyaltyReadFailure(address(next), mode);
            next.configureRoyalty(PHASE, _executors(2), DEFINITION, royalty, wrapper);
            require(
                next.phasePolicyHash(1, PHASE) == 0
                    && ledger.registeredPhasePolicyHash(address(next), 1, PHASE) == 0,
                "malformed successor registration rolls back both stores"
            );
        }
        next.setRoyaltyReadMode(0);
        next.configureRoyalty(PHASE, _executors(2), DEFINITION, royalty, wrapper);
    }

    function _expectRoyaltyReadFailure(address writer, uint256 mode) private {
        if (mode == 4) {
            vm.expectRevert();
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed.selector, writer
                )
            );
        }
    }

    function testOnlyCanonicalUnsupportedLegacyCapabilityMayHaveZeroFreezeInventory() public {
        for (uint256 mode; mode < 6; ++mode) {
            PhaseFreezeLegacyLedgerBoundary source = new PhaseFreezeLegacyLedgerBoundary(mode);
            PhaseFreezeLedgerWriterBoundary prior = new PhaseFreezeLedgerWriterBoundary(
                StreamMintLedger(address(source)),
                address(this),
                address(authority),
                address(authority)
            );
            PhaseFreezeLedgerWriterBoundary next = _writer(ledger);
            bytes32 root = _root(address(source), address(prior), ledger, address(next));
            _authorize(address(source), address(prior), ledger, address(next), root);
            if (mode != 0) vm.expectRevert();
            vm.prank(address(authority));
            ledger.commitCounterImportRoot(
                address(source), address(prior), address(next), uint64(block.number), root, MANIFEST
            );
            if (mode == 0) {
                (uint256 imported, uint256 required) = ledger.mintImportFreezeProgress(root);
                require(imported == 0 && required == 0, "honest absent historical capability");
                _complete(root);
            } else {
                require(
                    ledger.mintImportCommitment(root).successorManager == address(0),
                    "malformed or unavailable source rolls back"
                );
            }
        }
    }
}
