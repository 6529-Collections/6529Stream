// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintArtistConsent.sol";

/// @dev Explicit typed Artist boundary for the Manager consumer, not an Artist implementation.
/// Exact records and current admission are independently controlled. Real delegation/signature
/// authorization belongs to the separate actual Artist/current-stack tests.
contract MintArtistModesBoundary {
    struct Record {
        bool consented;
        bytes32 evidence;
    }

    address public core;
    address public mintManager;
    uint8 private mode;
    mapping(bytes32 => Record) private records;
    bool public denyCurrent;
    bool public forbidPlatformReads;
    bool public platformInterface = true;
    bool private declared;
    bytes32 private declaration;
    uint64 private declaredAt;

    constructor(address core_, address manager_) {
        core = core_;
        mintManager = manager_;
    }

    function setBinding(address core_, address manager_) external {
        core = core_;
        mintManager = manager_;
    }

    function setMode(uint8 value) external {
        mode = value;
    }

    function setCurrentDenied(bool value) external {
        denyCurrent = value;
    }

    function setPlatformReadsForbidden(bool value) external {
        forbidPlatformReads = value;
    }

    function setPlatformInterface(bool value) external {
        platformInterface = value;
    }

    function setRecord(
        uint256 collection,
        bytes32 phase,
        bytes32 policy,
        bool consented,
        bytes32 evidence
    ) external {
        records[keccak256(abi.encode(collection, phase, policy))] = Record(consented, evidence);
    }

    function setDeclaration(bool exists, bytes32 hash, uint64 timestamp) external {
        declared = exists;
        declaration = hash;
        declaredAt = timestamp;
    }

    function consentMode(uint256) external view returns (uint8) {
        return mode;
    }

    function isPolicyConsented(uint256 collection, bytes32 phase, bytes32 policy)
        external
        view
        returns (bool, bytes32)
    {
        Record memory record = records[keccak256(abi.encode(collection, phase, policy))];
        return (record.consented, record.evidence);
    }

    function requireMintConsent(uint256 collection, bytes32 phase, bytes32 policy) external view {
        Record memory record = records[keccak256(abi.encode(collection, phase, policy))];
        require(
            !denyCurrent && record.consented && record.evidence != 0, "current authority denied"
        );
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        require(!forbidPlatformReads, "artist modes must not query platform interface");
        return id == type(IStreamArtistPlatformWorks).interfaceId && platformInterface;
    }

    function platformWorksDeclaration(uint256) external view returns (bool, bytes32, uint64) {
        require(!forbidPlatformReads, "artist modes must not query platform declaration");
        return (declared, declaration, declaredAt);
    }
}

/// @dev Actual Manager, Ledger and ModuleRegistry; Core, Artist and governance are typed boundaries.
/// Locks the consumer requirements in ADR0010 D2.4, MPA-CONSENT and AA-CONSENT, including the
/// platform contest stop from ADR0012 T4. No Artist delegation or signature acceptance is simulated.
contract StreamMintArtistConsentModesTest is MintEngineTestBase {
    bytes32 private constant COUNTER = keccak256("consent modes supply");
    bytes32 private constant EVIDENCE = keccak256("exact typed authority consent record");
    MintArtistModesBoundary private modes;

    struct Terms {
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] ids;
        IStreamMintManager.MintCounterConfig[] counters;
    }

    function setUp() public override {
        super.setUp();
        modes = new MintArtistModesBoundary(address(core), address(manager));
        core.initialize(address(registry), address(modes), address(manager));
    }

    function _terms() private pure returns (Terms memory t) {
        t.config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("consent modes phase config"), 0
        );
        t.ids = new bytes32[](1);
        t.ids[0] = COUNTER;
        t.counters = new IStreamMintManager.MintCounterConfig[](1);
        t.counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            keccak256("consent modes counter config")
        );
    }

    function _policy(bool executorEnabled) private view returns (bytes32) {
        Terms memory t = _terms();
        address[] memory enabled = new address[](executorEnabled ? 1 : 0);
        if (executorEnabled) enabled[0] = address(this);
        return
            manager.previewPhasePolicyHash(1, PHASE, t.config, t.gate, t.ids, t.counters, enabled);
    }

    function _configure() private returns (bytes32) {
        Terms memory t = _terms();
        return manager.configurePhase(1, PHASE, t.config, t.gate, t.ids, t.counters);
    }

    function _record(bytes32 hash, bool consented, bytes32 evidence) private {
        modes.setRecord(1, PHASE, hash, consented, evidence);
    }

    function _assertAbsent() private view {
        (bool exists,) = manager.phase(1, PHASE);
        require(
            !exists && !manager.hasRegisteredPhasePolicy(1), "failed registration leaves no history"
        );
        require(
            manager.phasePolicyHash(1, PHASE) == 0
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == 0,
            "both policy stores unchanged"
        );
        require(
            manager.phaseCounterIds(1, PHASE).length == 0
                && !ledger.registeredCounterPolicy(address(manager), 1, PHASE, COUNTER).enabled,
            "counter configuration rolled back"
        );
        require(manager.nextOperationNonce() == 0 && core.minted() == 0, "no mint effects");
    }

    function _expectMissing(bytes32 hash) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistPolicyNotConsented.selector, uint256(1), PHASE, hash
            )
        );
        _configure();
        _assertAbsent();
    }

    function _expectCurrentFailure() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
                address(modes),
                IStreamArtistMintConsent.requireMintConsent.selector
            )
        );
        _configure();
        _assertAbsent();
    }

    function _assertConsent(Vm.Log[] memory logs, bytes32 hash, uint8 mode, bytes32 evidence)
        private
        view
    {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(manager) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "MintPhaseConsentRecorded(uint16,uint256,bytes32,bytes32,uint8,bytes32)"
                        )
            ) continue;
            ++count;
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == PHASE
                    && logs[i].topics[3] == hash,
                "exact consent indexed identity"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), mode, evidence)),
                "exact consent mode and original evidence"
            );
        }
        require(count == 1, "one original Manager consent receipt");
    }

    function _accept(uint8 mode) private returns (bytes32 expected) {
        modes.setMode(mode);
        expected = _policy(false);
        _record(expected, true, EVIDENCE);
        vm.recordLogs();
        require(_configure() == expected, "exact consented policy registered");
        _assertConsent(vm.getRecordedLogs(), expected, mode, EVIDENCE);
        (bool exists,) = manager.phase(1, PHASE);
        require(exists && manager.hasRegisteredPhasePolicy(1), "successful phase history");
        require(
            manager.phasePolicyHash(1, PHASE) == expected
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == expected,
            "Manager and Ledger registered exact policy"
        );
    }

    function testModeOneExactRecordStillRegistersWithoutPlatformOnlyReads() public {
        modes.setPlatformReadsForbidden(true);
        _accept(1);
    }

    function testModeTwoExactRecordRegistersWithoutPlatformOnlyReads() public {
        modes.setPlatformReadsForbidden(true);
        _accept(2);
    }

    function testUnsetAndUnknownModesRejectEvenWhenExactEvidenceExists() public {
        bytes32 hash = _policy(false);
        _record(hash, true, EVIDENCE);
        uint8[3] memory invalid = [uint8(0), uint8(4), uint8(255)];
        for (uint256 i; i < invalid.length; ++i) {
            modes.setMode(invalid[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintArtistConsent.UnsupportedArtistConsentMode.selector,
                    uint256(1),
                    invalid[i]
                )
            );
            _configure();
            _assertAbsent();
        }
    }

    function testModeTwoRequiresExactCollectionPhasePolicyRecord() public {
        modes.setMode(2);
        bytes32 hash = _policy(false);
        _expectMissing(hash);
        modes.setRecord(2, PHASE, hash, true, EVIDENCE);
        modes.setRecord(1, keccak256("different phase"), hash, true, EVIDENCE);
        modes.setRecord(1, PHASE, keccak256("different policy"), true, EVIDENCE);
        _expectMissing(hash);
        _record(hash, false, EVIDENCE);
        _expectMissing(hash);
        _record(hash, true, EVIDENCE);
        require(_configure() == hash, "only exact positive record repairs registration");
    }

    function testModeTwoRejectsZeroEvidenceThenRetriesOriginalConfiguration() public {
        modes.setMode(2);
        bytes32 hash = _policy(false);
        _record(hash, true, 0);
        _expectMissing(hash);
        _record(hash, true, EVIDENCE);
        require(_configure() == hash, "nonzero exact evidence repairs configuration");
    }

    function testModeTwoCurrentAuthorityFailureRollsBackDespiteRecordedConsent() public {
        modes.setMode(2);
        bytes32 hash = _policy(false);
        _record(hash, true, EVIDENCE);
        modes.setCurrentDenied(true);
        _expectCurrentFailure();
        modes.setCurrentDenied(false);
        require(_configure() == hash, "current authority restoration repairs same configuration");
    }

    function testModeTwoMismatchedCoreOrManagerAuthorityBindingRejects() public {
        modes.setMode(2);
        _record(_policy(false), true, EVIDENCE);
        modes.setBinding(address(0xC0DE), address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityUnavailable.selector, address(modes)
            )
        );
        _configure();
        _assertAbsent();
        modes.setBinding(address(core), address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityUnavailable.selector, address(modes)
            )
        );
        _configure();
        _assertAbsent();
        modes.setBinding(address(core), address(manager));
        require(_configure() == _policy(false), "only exact current authority binding accepted");
    }

    function testModeTwoExecutorGraceRefreshNeedsItsOwnExactConsentAndRetainsLiveMintCheck()
        public
    {
        bytes32 previous = _accept(2);
        bytes32 next = _policy(true);
        uint64 deadline = uint64(block.timestamp + 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistPolicyNotConsented.selector, uint256(1), PHASE, next
            )
        );
        manager.setPhaseExecutorWithGrace(1, PHASE, address(this), true, deadline);
        require(
            !manager.phaseExecutor(1, PHASE, address(this))
                && manager.phasePolicyHash(1, PHASE) == previous
                && ledger.registeredPhasePolicyHash(address(manager), 1, PHASE) == previous,
            "initial consent does not authorize changed executor policy"
        );
        _record(next, true, EVIDENCE);
        vm.recordLogs();
        manager.setPhaseExecutorWithGrace(1, PHASE, address(this), true, deadline);
        _assertConsent(vm.getRecordedLogs(), next, 2, EVIDENCE);
        (bytes32 oldHash, uint64 revision, uint64 until) =
            ledger.policyGrace(address(manager), 1, PHASE);
        require(
            oldHash == previous && revision == 1 && until == deadline,
            "real Mode2 predecessor registration"
        );
        IStreamMintManager.MintBatch memory batch =
            _batch(keccak256("mode2 original authorization"));
        batch.expectedPolicyHash = previous;
        (bytes32 root,) = manager.previewSingleStepMintOperation(batch, "");
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONSTANT,
            1,
            PHASE,
            COUNTER,
            signer,
            signer,
            address(this),
            address(0),
            bytes32(0)
        );
        bytes32 valueKey = manager.previewCounterValueKey(1, PHASE, COUNTER, subject);
        modes.setCurrentDenied(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
                address(modes),
                IStreamArtistMintConsent.requireMintConsent.selector
            )
        );
        manager.executeSingleStepMint(batch, "");
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0
                && ledger.counterValue(valueKey) == 0
                && !manager.isAuthorizationUsed(batch.authorizationId)
                && !manager.isOperationRootUsed(root),
            "Mode2 live authority stop preserves accounting"
        );
        modes.setCurrentDenied(false);
        (, bytes32 actual,) = manager.executeSingleStepMint(batch, "");
        require(
            actual == root && core.minted() == 1 && manager.nextOperationNonce() == 1
                && ledger.counterValue(valueKey) == 1
                && manager.isAuthorizationUsed(batch.authorizationId)
                && manager.isOperationRootUsed(root),
            "original predecessor request succeeds after authority repair"
        );
    }

    function testModeThreeExactDeclarationStillRegistersAtInclusiveTimestamp() public {
        modes.setDeclaration(true, EVIDENCE, uint64(block.timestamp));
        _accept(3);
    }

    function testModeThreeStillRequiresPlatformInterfaceAndExactDeclaration() public {
        modes.setMode(3);
        bytes32 hash = _policy(false);
        _record(hash, true, EVIDENCE);
        modes.setDeclaration(true, EVIDENCE, uint64(block.timestamp));
        modes.setPlatformInterface(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintArtistConsent.UnsupportedArtistConsentMode.selector, uint256(1), uint8(3)
            )
        );
        _configure();
        _assertAbsent();
        modes.setPlatformInterface(true);
        modes.setDeclaration(false, EVIDENCE, uint64(block.timestamp));
        _expectMissing(hash);
        modes.setDeclaration(true, keccak256("different declaration"), uint64(block.timestamp));
        _expectMissing(hash);
        modes.setDeclaration(true, EVIDENCE, uint64(block.timestamp + 1));
        _expectMissing(hash);
        modes.setDeclaration(true, EVIDENCE, uint64(block.timestamp));
        require(_configure() == hash, "unchanged declaration rules accept exact tuple");
    }

    function testModeThreeDeclarationNeverBypassesCurrentPlatformStop() public {
        modes.setMode(3);
        bytes32 hash = _policy(false);
        _record(hash, true, EVIDENCE);
        modes.setDeclaration(true, EVIDENCE, uint64(block.timestamp));
        modes.setCurrentDenied(true);
        _expectCurrentFailure();
        modes.setCurrentDenied(false);
        require(_configure() == hash, "same declaration admitted after current stop clears");
    }
}
