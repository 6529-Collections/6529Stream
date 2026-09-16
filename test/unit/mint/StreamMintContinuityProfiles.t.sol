// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Only the Manager getters and authorized Ledger-writing boundary are fixtures.
///      Profile selection, registration, consumption, retirement and import use the actual Ledger.
contract MintContinuityProfileWriter {
    StreamMintLedger public immutable mintLedger;
    address public immutable core;
    address public immutable governanceAuthority;
    bytes32 private constant COUNTER = keccak256("profile-recipient-counter");

    constructor(StreamMintLedger ledger_, address core_, address authority_) {
        mintLedger = ledger_;
        core = core_;
        governanceAuthority = authority_;
    }

    function pin(bytes32 phase, bytes32 definitionHash) external {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintLedger.LedgerCounterPolicy[] memory policies =
            new IStreamMintLedger.LedgerCounterPolicy[](1);
        policies[0] = IStreamMintLedger.LedgerCounterPolicy(
            true,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            definitionHash
        );
        mintLedger.registerPhasePolicy(
            address(this), 42, phase, keccak256(abi.encode(phase, definitionHash)), ids, policies, 0
        );
    }

    function consume(bytes32 phase, bytes32 valueKey, bytes32 subject, bytes32 operationRoot)
        external
    {
        IStreamMintLedger.CounterConsumption[] memory rows =
            new IStreamMintLedger.CounterConsumption[](1);
        rows[0].valueKey = valueKey;
        rows[0].collectionId = 42;
        rows[0].phaseId = phase;
        rows[0].counterId = COUNTER;
        rows[0].subjectKey = subject;
        rows[0].recipient = address(0xCAFE);
        rows[0].increment = 1;
        rows[0].cap = 1;
        bytes32 policy = mintLedger.registeredPhasePolicyHash(address(this), 42, phase);
        mintLedger.consume(42, phase, rows, 0, new bytes32[](0), policy, operationRoot);
    }
}

contract StreamMintContinuityProfilesTest is CharacterizationTestBase {
    bytes32 private constant PHASE = keccak256("profile-phase");
    bytes32 private constant COUNTER = keccak256("profile-recipient-counter");
    bytes32 private constant MANIFEST = keccak256("profile-continuity-manifest");
    StreamMintLedger private ledger;
    MintContinuityProfileWriter private predecessor;
    MockGovernedParameterAuthority private authority;

    function setUp() public {
        vm.roll(100);
        authority = new MockGovernedParameterAuthority(true);
        ledger = new StreamMintLedger();
        predecessor = _writer(ledger);
    }

    function _writer(StreamMintLedger target) private returns (MintContinuityProfileWriter writer) {
        writer = new MintContinuityProfileWriter(target, address(this), address(authority));
        address admin = target.owner();
        vm.prank(admin);
        target.setLedgerWriter(address(writer), true);
    }

    function _definition(IStreamMintCounterPolicy.CounterScope scope, uint256 salt)
        private
        pure
        returns (IStreamMintCounterPolicy.Definition memory)
    {
        return IStreamMintCounterPolicy.Definition(
            scope, IStreamMintManager.CounterKeyMode.RECIPIENT, 0, bytes32(salt)
        );
    }

    function _definitionHash(IStreamMintCounterPolicy.Definition memory definition)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
    }

    function _retire(StreamMintLedger target, MintContinuityProfileWriter writer) private {
        address admin = target.owner();
        vm.prank(admin);
        target.retireLedgerWriter(address(writer));
    }

    function _descriptor(
        StreamMintLedger source,
        MintContinuityProfileWriter oldWriter,
        StreamMintLedger destination,
        MintContinuityProfileWriter newWriter,
        uint64 counters
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(destination),
                        address(source),
                        address(oldWriter),
                        address(newWriter),
                        uint64(block.number),
                        MANIFEST,
                        counters,
                        uint64(0)
                    )
                )
            )
        );
    }

    function _authorize(
        StreamMintLedger source,
        MintContinuityProfileWriter oldWriter,
        StreamMintLedger destination,
        MintContinuityProfileWriter newWriter,
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
                address(newWriter)
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(source),
                address(oldWriter),
                address(newWriter),
                uint64(block.number),
                root,
                MANIFEST
            )
        );
        authority.setCurrentAction(
            true, keccak256("profile-import-governance-action"), 1, scope, 0, value
        );
    }

    function _commitRoot(
        StreamMintLedger source,
        MintContinuityProfileWriter oldWriter,
        StreamMintLedger destination,
        MintContinuityProfileWriter newWriter,
        bytes32 root
    ) private {
        _authorize(source, oldWriter, destination, newWriter, root);
        vm.prank(address(authority));
        destination.commitCounterImportRoot(
            address(source),
            address(oldWriter),
            address(newWriter),
            uint64(block.number),
            root,
            MANIFEST
        );
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    /// @dev These roots contain no counter/nullifier leaves because their tests have no consumption.
    function _commitProfiles(
        StreamMintLedger source,
        MintContinuityProfileWriter oldWriter,
        StreamMintLedger destination,
        MintContinuityProfileWriter newWriter
    ) private returns (bytes32 root) {
        _retire(source, oldWriter);
        root = _descriptor(source, oldWriter, destination, newWriter, 0);
        _commitRoot(source, oldWriter, destination, newWriter, root);
    }

    function _sealProfiles(StreamMintLedger target, bytes32 root) private {
        target.completeCounterImport(root, 0, 0, new bytes32[](0));
    }

    function _assertProgress(
        StreamMintLedger target,
        bytes32 root,
        uint256 imported,
        uint256 required
    ) private view {
        (uint256 actualImported, uint256 actualRequired) = target.mintImportDefinitionProgress(root);
        require(actualImported == imported && actualRequired == required, "exact profile progress");
    }

    function _assertProfile(
        StreamMintLedger target,
        MintContinuityProfileWriter writer,
        uint256 index,
        bytes32 expectedHash,
        bool expectedDefined,
        IStreamMintCounterPolicy.Definition memory expectedDefinition
    ) private view {
        (bytes32 hash, bool defined, IStreamMintCounterPolicy.Definition memory definition) =
            target.managerDefinitionAt(address(writer), index);
        require(hash == expectedHash && defined == expectedDefined, "exact selected profile");
        if (defined) {
            require(
                keccak256(abi.encode(definition)) == keccak256(abi.encode(expectedDefinition)),
                "definition preimage"
            );
        } else {
            require(
                definition.scope == IStreamMintCounterPolicy.CounterScope.PHASE,
                "explicit legacy phase scope"
            );
        }
    }

    function testLateRegistrationSameLedgerRejectsConflictingSuccessorSelection() public {
        IStreamMintCounterPolicy.Definition memory definition =
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 1);
        bytes32 hash = _definitionHash(definition);
        predecessor.pin(PHASE, hash);
        ledger.registerCounterDefinition(definition);
        MintContinuityProfileWriter next = _writer(ledger);
        next.pin(PHASE, hash);
        _assertProfile(ledger, predecessor, 0, hash, false, definition);
        _assertProfile(ledger, next, 0, hash, true, definition);
        bytes32 root = _commitProfiles(ledger, predecessor, ledger, next);

        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importCounterDefinitions(root, 32);
        _assertProgress(ledger, root, 0, 1);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.completeCounterImport(root, 0, 0, new bytes32[](0));
        require(
            !ledger.isMintSuccessorReady(address(ledger), address(predecessor), address(next)),
            "conflict cannot activate"
        );
    }

    function testLateRegistrationSameLedgerCopiesExplicitLegacySelection() public {
        IStreamMintCounterPolicy.Definition memory definition =
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 2);
        bytes32 hash = _definitionHash(definition);
        predecessor.pin(PHASE, hash);
        ledger.registerCounterDefinition(definition);
        MintContinuityProfileWriter next = _writer(ledger);
        bytes32 root = _commitProfiles(ledger, predecessor, ledger, next);
        ledger.importCounterDefinitions(root, 32);
        next.pin(PHASE, hash);
        _assertProfile(ledger, next, 0, hash, false, definition);
        require(
            ledger.managerDefinitionCount(address(next)) == 1, "pin after copy adds no duplicate"
        );
        _sealProfiles(ledger, root);
        require(
            ledger.isMintSuccessorReady(address(ledger), address(predecessor), address(next)),
            "legacy successor ready"
        );
    }

    function _subject(StreamMintLedger target) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(target),
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                address(0xCAFE)
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _newLedgerFloor(IStreamMintCounterPolicy.CounterScope scope) private {
        IStreamMintCounterPolicy.Definition memory definition = _definition(scope, 3);
        bytes32 hash = ledger.registerCounterDefinition(definition);
        predecessor.pin(PHASE, hash);
        uint256 scopeCollection = scope == IStreamMintCounterPolicy.CounterScope.GLOBAL ? 0 : 42;
        bytes32 oldSubject = _subject(ledger);
        bytes32 oldKey = ledger.deriveCounterValueKey(
            address(predecessor), scopeCollection, 0, COUNTER, oldSubject
        );
        predecessor.consume(PHASE, oldKey, oldSubject, keccak256("old-consumption"));

        StreamMintLedger destination = new StreamMintLedger();
        MintContinuityProfileWriter next = _writer(destination);
        (bool exists, IStreamMintCounterPolicy.Definition memory absent) =
            destination.counterDefinitionForManager(address(next), hash);
        require(
            !exists && absent.scope == IStreamMintCounterPolicy.CounterScope.PHASE,
            "definition initially missing"
        );
        _retire(ledger, predecessor);
        IStreamMintLedgerImport.CounterImportLeaf memory leaf =
            IStreamMintLedgerImport.CounterImportLeaf(
                scopeCollection,
                0,
                COUNTER,
                uint8(IStreamMintManager.CounterKeyMode.RECIPIENT),
                bytes32(uint256(uint160(address(0xCAFE)))),
                oldSubject,
                1
            );
        bytes32 leafHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(predecessor),
                        leaf
                    )
                )
            )
        );
        bytes32 descriptor = _descriptor(ledger, predecessor, destination, next, 1);
        bytes32 root = _pair(leafHash, descriptor);
        _commitRoot(ledger, predecessor, destination, next, root);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = descriptor;
        bytes32 newSubject = _subject(destination);
        vm.prank(address(next));
        destination.importCounterValue(root, leaf, newSubject, proof);
        proof[0] = leafHash;
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.completeCounterImport(root, 1, 0, proof);

        destination.importCounterDefinitions(root, 32);
        next.pin(PHASE, hash);
        _assertProfile(destination, next, 0, hash, true, definition);
        destination.completeCounterImport(root, 1, 0, proof);
        bytes32 newKey = destination.deriveCounterValueKey(
            address(next), scopeCollection, 0, COUNTER, newSubject
        );
        require(destination.counterValue(newKey) == 1, "scoped floor imported");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, newKey, uint256(2), uint256(1)
            )
        );
        next.consume(PHASE, newKey, newSubject, keccak256("successor-over-cap"));
        bytes32 wrongKey =
            destination.deriveCounterValueKey(address(next), 42, PHASE, COUNTER, newSubject);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterValueKeyMismatch.selector, wrongKey, newKey
            )
        );
        next.consume(PHASE, wrongKey, newSubject, keccak256("successor-wrong-scope"));
        require(
            destination.counterValue(newKey) == 1 && destination.counterValue(wrongKey) == 0,
            "failed attempts leave no reset"
        );
    }

    function testNewLedgerStaticCollectionProfileCopiesBeforePinAndPreservesFloor() public {
        _newLedgerFloor(IStreamMintCounterPolicy.CounterScope.COLLECTION);
    }

    function testNewLedgerStaticGlobalProfileCopiesBeforePinAndPreservesFloor() public {
        _newLedgerFloor(IStreamMintCounterPolicy.CounterScope.GLOBAL);
    }

    function testDefinitionCopyRequiresPaginationAndBlocksPrematureCompletion() public {
        bytes32[] memory hashes = new bytes32[](33);
        for (uint256 i; i < hashes.length; ++i) {
            hashes[i] = ledger.registerCounterDefinition(
                _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, i + 1)
            );
            predecessor.pin(bytes32(i + 1), hashes[i]);
        }
        StreamMintLedger destination = new StreamMintLedger();
        MintContinuityProfileWriter next = _writer(destination);
        bytes32 root = _commitProfiles(ledger, predecessor, destination, next);
        _assertProgress(destination, root, 0, 33);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importCounterDefinitions(root, 0);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importCounterDefinitions(root, 33);
        vm.prank(address(0xBEEF));
        destination.importCounterDefinitions(root, 32);
        _assertProgress(destination, root, 32, 33);
        require(destination.managerDefinitionCount(address(next)) == 32, "first bounded page");
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.completeCounterImport(root, 0, 0, new bytes32[](0));
        destination.importCounterDefinitions(root, 32);
        _assertProgress(destination, root, 33, 33);
        require(
            destination.managerDefinitionCount(address(next)) == 33,
            "last page imports only remainder"
        );
        _assertProfile(
            destination,
            next,
            0,
            hashes[0],
            true,
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 1)
        );
        _assertProfile(
            destination,
            next,
            32,
            hashes[32],
            true,
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 33)
        );
        _sealProfiles(destination, root);
    }

    function testMatchingLegacyAndDefinedPinsNeverDuplicate() public {
        IStreamMintCounterPolicy.Definition memory definition =
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 4);
        bytes32 definedHash = ledger.registerCounterDefinition(definition);
        bytes32 legacyHash = keccak256("unregistered-profile");
        MintContinuityProfileWriter next = _writer(ledger);
        predecessor.pin(PHASE, definedHash);
        predecessor.pin(bytes32(uint256(2)), legacyHash);
        predecessor.pin(bytes32(uint256(3)), definedHash);
        next.pin(PHASE, definedHash);
        next.pin(bytes32(uint256(2)), legacyHash);
        require(ledger.managerDefinitionCount(address(predecessor)) == 2, "source hashes unique");
        bytes32 root = _commitProfiles(ledger, predecessor, ledger, next);
        ledger.importCounterDefinitions(root, 32);
        ledger.importCounterDefinitions(root, 32);
        next.pin(bytes32(uint256(4)), definedHash);
        next.pin(bytes32(uint256(5)), legacyHash);
        _assertProgress(ledger, root, 2, 2);
        require(ledger.managerDefinitionCount(address(next)) == 2, "equal pins copied idempotently");
        _assertProfile(ledger, next, 0, definedHash, true, definition);
        _assertProfile(ledger, next, 1, legacyHash, false, definition);
        _sealProfiles(ledger, root);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importCounterDefinitions(root, 1);
    }

    function testThreeGenerationsPreserveUnusedInheritedProfiles() public {
        IStreamMintCounterPolicy.Definition memory legacyDefinition =
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 5);
        bytes32 legacyHash = _definitionHash(legacyDefinition);
        predecessor.pin(PHASE, legacyHash);
        ledger.registerCounterDefinition(legacyDefinition);
        IStreamMintCounterPolicy.Definition memory definedDefinition =
            _definition(IStreamMintCounterPolicy.CounterScope.GLOBAL, 6);
        bytes32 definedHash = ledger.registerCounterDefinition(definedDefinition);
        predecessor.pin(bytes32(uint256(2)), definedHash);

        StreamMintLedger middleLedger = new StreamMintLedger();
        MintContinuityProfileWriter middle = _writer(middleLedger);
        bytes32 firstRoot = _commitProfiles(ledger, predecessor, middleLedger, middle);
        middleLedger.importCounterDefinitions(firstRoot, 32);
        _sealProfiles(middleLedger, firstRoot);
        require(
            middleLedger.managerDefinitionCount(address(middle)) == 2,
            "imported profiles enumerable without phase use"
        );

        StreamMintLedger lastLedger = new StreamMintLedger();
        MintContinuityProfileWriter last = _writer(lastLedger);
        bytes32 secondRoot = _commitProfiles(middleLedger, middle, lastLedger, last);
        _assertProgress(lastLedger, secondRoot, 0, 2);
        lastLedger.importCounterDefinitions(secondRoot, 32);
        lastLedger.registerCounterDefinition(legacyDefinition);
        last.pin(PHASE, legacyHash);
        last.pin(bytes32(uint256(2)), definedHash);
        _assertProfile(lastLedger, last, 0, legacyHash, false, legacyDefinition);
        _assertProfile(lastLedger, last, 1, definedHash, true, definedDefinition);
        require(
            lastLedger.managerDefinitionCount(address(last)) == 2,
            "third generation preserves exact unique profiles"
        );
        _sealProfiles(lastLedger, secondRoot);
        require(
            lastLedger.isMintSuccessorReady(address(middleLedger), address(middle), address(last)),
            "third generation ready"
        );
    }

    function testPendingImportBlocksRetirementEvenAfterWriterDisable() public {
        bytes32 hash = ledger.registerCounterDefinition(
            _definition(IStreamMintCounterPolicy.CounterScope.COLLECTION, 7)
        );
        predecessor.pin(PHASE, hash);
        StreamMintLedger destination = new StreamMintLedger();
        MintContinuityProfileWriter next = _writer(destination);
        bytes32 root = _commitProfiles(ledger, predecessor, destination, next);
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerImport.MintImportNotReady.selector, address(next)
            )
        );
        destination.retireLedgerWriter(address(next));
        vm.prank(address(authority));
        destination.setLedgerWriter(address(next), false);
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerImport.MintImportNotReady.selector, address(next)
            )
        );
        destination.retireLedgerWriter(address(next));
        require(
            destination.ledgerWriterRetiredAt(address(next)) == 0,
            "pending writer cannot become frozen source"
        );
        destination.importCounterDefinitions(root, 32);
        _sealProfiles(destination, root);
        _retire(destination, next);
        require(
            destination.ledgerWriterRetiredAt(address(next)) == block.number,
            "completed import can retire"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importCounterDefinitions(root, 1);
    }

    function testAlreadyRetiredSuccessorCannotReceiveCommitment() public {
        StreamMintLedger destination = new StreamMintLedger();
        MintContinuityProfileWriter next = _writer(destination);
        _retire(ledger, predecessor);
        _retire(destination, next);
        bytes32 root = _descriptor(ledger, predecessor, destination, next, 0);
        _authorize(ledger, predecessor, destination, next, root);
        vm.prank(address(authority));
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.commitCounterImportRoot(
            address(ledger),
            address(predecessor),
            address(next),
            uint64(block.number),
            root,
            MANIFEST
        );
        require(
            destination.mintImportCommitment(root).successorManager == address(0),
            "rejected commitment leaves no state"
        );
    }
}
