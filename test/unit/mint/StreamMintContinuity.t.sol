// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";

/// @dev Actual Manager/Ledger and Safe1.4.1; Core/Artist/governance context are explicit typed fixtures.
contract StreamMintContinuityTest is MintEngineTestBase, OfficialSafeFixture {
    bytes32 private constant COUNTER = keccak256("continuity-recipient");
    bytes32 private constant NULLIFIER = keccak256("spent-burn-proof");
    bytes32 private constant MANIFEST = keccak256("full-snapshot-artifact");
    StreamMintLedger private nextLedger;
    StreamMintManager private successor;
    IStreamMintLedgerImport.CounterImportLeaf private leaf;
    bytes32 private counterHash;
    bytes32 private nullifierHash;
    bytes32 private descriptorHash;
    bytes32 private root;
    uint64 private snapshot;
    uint256 private nonce;

    function _configure(StreamMintManager m, StreamMintLedger l) private {
        bytes32 hash = l.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.GLOBAL,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                0,
                keccak256("scope")
            )
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            hash
        );
        IStreamMintManager.MintGateConfig memory gate;
        m.configurePhase(
            1,
            PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 10, keccak256("config"), 0),
            gate,
            ids,
            counters
        );
        m.setPhaseExecutor(1, PHASE, address(this), true);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        require(
            m.phasePolicyHash(1, PHASE)
                == m.previewPhasePolicyHash(
                    1,
                    PHASE,
                    IStreamMintManager.MintPhaseConfig(false, 0, 0, 10, keccak256("config"), 0),
                    gate,
                    ids,
                    counters,
                    executors
                ),
            "retained preview matches configured hash"
        );
    }

    function _request(StreamMintManager m) private returns (IStreamMintManager.MintBatch memory b) {
        b = _batch(bytes32(++nonce));
        b.expectedPolicyHash = m.phasePolicyHash(1, PHASE);
    }

    function _subject(address l) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                l,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                signer
            )
        );
    }

    function _key(address m, bytes32 subject) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                m,
                uint256(0),
                bytes32(0),
                COUNTER,
                subject
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _setupSuccession(bool replaceLedger, bool retire) private {
        _configure(manager, ledger);
        manager.executeSingleStepMint(_request(manager), "");
        // The already-consumed gate nullifier is seeded at the explicit manager-writer boundary;
        // concrete-gate production joins have their own StandardGateIntegration suite.
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = NULLIFIER;
        bytes32 activePolicy = manager.phasePolicyHash(1, PHASE);
        vm.prank(address(manager));
        ledger.consume(
            1,
            PHASE,
            new IStreamMintLedger.CounterConsumption[](0),
            0,
            nullifiers,
            activePolicy,
            keccak256("nullifier-root")
        );
        nextLedger = replaceLedger ? new StreamMintLedger() : ledger;
        successor = _manager(address(nextLedger));
        nextLedger.setLedgerWriter(address(successor), true);
        artist.setManager(address(successor));
        _configure(successor, nextLedger);
        vm.roll(20);
        if (retire) ledger.retireLedgerWriter(address(manager));
        snapshot = uint64(block.number);
        leaf = IStreamMintLedgerImport.CounterImportLeaf(
            0,
            0,
            COUNTER,
            uint8(IStreamMintManager.CounterKeyMode.RECIPIENT),
            bytes32(uint256(uint160(signer))),
            _subject(address(ledger)),
            1
        );
        _tree();
        nextLedger.transferOwnership(address(authority));
    }

    function _tree() private {
        counterHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(manager),
                        leaf
                    )
                )
            )
        );
        nullifierHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(manager),
                        NULLIFIER
                    )
                )
            )
        );
        descriptorHash = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(nextLedger),
                        address(ledger),
                        address(manager),
                        address(successor),
                        snapshot,
                        MANIFEST,
                        uint64(1),
                        uint64(1)
                    )
                )
            )
        );
        root = _pair(_pair(counterHash, nullifierHash), descriptorHash);
    }

    function _context(uint8 cls, bytes32 overrideNew) private {
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(nextLedger),
                address(successor)
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(ledger),
                address(manager),
                address(successor),
                snapshot,
                root,
                MANIFEST
            )
        );
        authority.setCurrentAction(
            true,
            keccak256("scheduled governance action"),
            cls,
            scope,
            0,
            overrideNew == 0 ? value : overrideNew
        );
    }

    function _commit() private {
        _context(1, 0);
        vm.prank(address(authority));
        nextLedger.commitCounterImportRoot(
            address(ledger), address(manager), address(successor), snapshot, root, MANIFEST
        );
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
        nextLedger.importCounterDefinitions(root, 32);
    }

    function _counterProof() private view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = nullifierHash;
        p[1] = descriptorHash;
    }

    function _nullifierProof() private view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = counterHash;
        p[1] = descriptorHash;
    }

    function _descriptorProof() private view returns (bytes32[] memory p) {
        p = new bytes32[](1);
        p[0] = _pair(counterHash, nullifierHash);
    }

    function _batchImport() private view returns (bytes memory) {
        IStreamMintManagerImport.ImportBatch memory b;
        b.importRoot = root;
        b.counters = new IStreamMintLedgerImport.CounterImportLeaf[](1);
        b.counters[0] = leaf;
        b.counterProofs = new bytes32[][](1);
        b.counterProofs[0] = _counterProof();
        b.nullifiers = new bytes32[](1);
        b.nullifiers[0] = NULLIFIER;
        b.nullifierProofs = new bytes32[][](1);
        b.nullifierProofs[0] = _nullifierProof();
        return abi.encode(b);
    }

    function _seal() private {
        nextLedger.completeCounterImport(root, 1, 1, _descriptorProof());
    }

    function testSameLedgerActualSafeOwnerImportPreservesFloorAndReplay() public {
        _setupSuccession(false, true);
        _commit();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7);
        successor.transferOwnership(address(account));
        bytes memory encoded = _batchImport();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        successor.importMintState(encoded);
        require(
            executeSafe(
                account,
                keys,
                address(successor),
                0,
                abi.encodeCall(IStreamMintManagerImport.importMintState, (encoded)),
                0
            ),
            "Safe CALL import"
        );
        require(
            nextLedger.counterValue(_key(address(successor), _subject(address(nextLedger)))) == 1,
            "floor imported"
        );
        _seal();
        require(
            nextLedger.isMintSuccessorReady(address(ledger), address(manager), address(successor)),
            "exact pair ready"
        );
        require(
            !nextLedger.isMintSuccessorReady(
                address(nextLedger), address(0xBAD), address(successor)
            ),
            "wrong pair blocked"
        );
        core.initialize(address(registry), address(artist), address(successor));
        successor.executeSingleStepMint(_request(successor), "");
        IStreamMintManager.MintBatch memory b = _request(successor);
        vm.expectRevert();
        successor.executeSingleStepMint(b, "");
        require(core.minted() == 2, "allowance never reset");
        require(
            nextLedger.isManagerNullifierUsed(address(successor), NULLIFIER), "nullifier survives"
        );
        bytes32[] memory nullifiers = new bytes32[](1);
        nullifiers[0] = NULLIFIER;
        bytes32 policy = successor.phasePolicyHash(1, PHASE);
        vm.prank(address(successor));
        vm.expectRevert();
        nextLedger.consume(
            1,
            PHASE,
            new IStreamMintLedger.CounterConsumption[](0),
            0,
            nullifiers,
            policy,
            keccak256("replay-root")
        );
    }

    function testNewLedgerRederivesSubjectAndPreservesGlobalFloor() public {
        _setupSuccession(true, true);
        _commit();
        require(
            _subject(address(ledger)) != _subject(address(nextLedger)),
            "ledger subject domains differ"
        );
        successor.importMintState(_batchImport());
        _seal();
        require(
            nextLedger.counterValue(_key(address(successor), _subject(address(nextLedger)))) == 1,
            "new subject floor"
        );
        require(
            ledger.counterValue(_key(address(manager), _subject(address(ledger)))) == 1,
            "predecessor unchanged"
        );
        core.initialize(address(registry), address(artist), address(successor));
        successor.executeSingleStepMint(_request(successor), "");
        IStreamMintManager.MintBatch memory b = _request(successor);
        vm.expectRevert();
        successor.executeSingleStepMint(b, "");
    }

    function testNormativeImportEventFieldsAndTopics() public {
        _setupSuccession(true, true);
        vm.recordLogs();
        _commit();
        successor.importMintState(_batchImport());
        _seal();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool commitment;
        bool counter;
        bool nullifier;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(nextLedger)) continue;
            bytes32 eventId = logs[i].topics[0];
            if (
                eventId
                    == keccak256(
                        "MintLedgerImportRootCommitted(uint16,bytes32,address,address,address,uint64,bytes32)"
                    )
            ) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == root
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(manager))))
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(successor)))),
                    "root topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(abi.encode(uint16(1), address(ledger), snapshot, MANIFEST)),
                    "root data"
                );
                commitment = true;
            } else if (
                eventId
                    == keccak256(
                        "MintLedgerCounterImported(uint16,bytes32,bytes32,bytes32,uint256,bytes32,bytes32,uint64,uint64)"
                    )
            ) {
                bytes32 subject = _subject(address(nextLedger));
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == root
                        && logs[i].topics[2] == _key(address(successor), subject)
                        && logs[i].topics[3] == subject,
                    "counter topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1), uint256(0), bytes32(0), COUNTER, uint64(1), uint64(1)
                            )
                        ),
                    "counter data"
                );
                counter = true;
            } else if (
                eventId == keccak256("MintLedgerNullifierImported(uint16,bytes32,bytes32,address)")
            ) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == root
                        && logs[i].topics[2] == NULLIFIER
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(successor)))),
                    "nullifier topics"
                );
                require(
                    keccak256(logs[i].data) == keccak256(abi.encode(uint16(1))), "nullifier schema"
                );
                nullifier = true;
            }
        }
        require(commitment && counter && nullifier, "all normative import events");
    }

    function testPendingRootRejectsMintAndPrematureCompletion() public {
        _setupSuccession(true, true);
        _commit();
        IStreamMintManager.MintBatch memory b = _request(successor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerImport.MintImportNotReady.selector, address(successor)
            )
        );
        successor.executeSingleStepMint(b, "");
        require(
            !successor.isAuthorizationUsed(b.authorizationId)
                && successor.nextOperationNonce() == 0,
            "blocked without writes"
        );
        bytes32[] memory proof = _descriptorProof();
        vm.expectRevert();
        nextLedger.completeCounterImport(root, 1, 1, proof);
        vm.expectRevert();
        nextLedger.completeCounterImport(root, 0, 0, proof);
        require(
            !nextLedger.isMintSuccessorReady(address(ledger), address(manager), address(successor)),
            "incomplete root not ready"
        );
    }

    function testRetirementIsPermanentAndSnapshotCannotPrecedeIt() public {
        _setupSuccession(true, true);
        vm.expectRevert();
        ledger.setLedgerWriter(address(manager), true);
        snapshot = 19;
        _tree();
        _context(1, 0);
        vm.prank(address(authority));
        vm.expectRevert();
        nextLedger.commitCounterImportRoot(
            address(ledger), address(manager), address(successor), snapshot, root, MANIFEST
        );
    }

    function testLiveWriterSnapshotRejected() public {
        _setupSuccession(true, false);
        _context(1, 0);
        vm.prank(address(authority));
        vm.expectRevert();
        nextLedger.commitCounterImportRoot(
            address(ledger), address(manager), address(successor), snapshot, root, MANIFEST
        );
    }

    function testGovernanceClassAndTransitionAreAuthenticated() public {
        _setupSuccession(true, true);
        _context(0, 0);
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedgerImport.MintImportGovernanceInvalid.selector)
        );
        nextLedger.commitCounterImportRoot(
            address(ledger), address(manager), address(successor), snapshot, root, MANIFEST
        );
        _context(1, keccak256("wrong transition"));
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedgerImport.MintImportGovernanceInvalid.selector)
        );
        nextLedger.commitCounterImportRoot(
            address(ledger), address(manager), address(successor), snapshot, root, MANIFEST
        );
        _commit();
    }

    function testWrongProofAndSuccessorSubjectFailWithoutImportResidue() public {
        _setupSuccession(true, true);
        _commit();
        bytes32[] memory proof = _counterProof();
        vm.prank(address(successor));
        vm.expectRevert();
        nextLedger.importCounterValue(root, leaf, _subject(address(ledger)), proof);
        proof[0] = keccak256("bad proof");
        vm.prank(address(successor));
        vm.expectRevert();
        nextLedger.importCounterValue(root, leaf, _subject(address(nextLedger)), proof);
        require(
            nextLedger.mintImportCommitment(root).importedCounters == 0, "no failed import count"
        );
    }

    function testCommittedUndercountCannotContradictRetiredLedger() public {
        _setupSuccession(true, true);
        leaf.value = 0;
        _tree();
        _commit();
        bytes memory encoded = _batchImport();
        vm.expectRevert();
        successor.importMintState(encoded);
        require(
            nextLedger.mintImportCommitment(root).importedCounters == 0,
            "understated floor rejected"
        );
    }

    function testLeavesAreSingleUseAndWrongWriterCannotImport() public {
        _setupSuccession(true, true);
        _commit();
        bytes32[] memory proof = _counterProof();
        vm.prank(address(manager));
        vm.expectRevert();
        nextLedger.importCounterValue(root, leaf, _subject(address(nextLedger)), proof);
        bytes memory encoded = _batchImport();
        successor.importMintState(encoded);
        vm.expectRevert();
        successor.importMintState(encoded);
        require(
            nextLedger.mintImportCommitment(root).importedCounters == 1,
            "no duplicate counter count"
        );
        _seal();
        vm.expectRevert();
        nextLedger.completeCounterImport(root, 1, 1, _descriptorProof());
    }

    function testImportMergesByMaximum() public {
        _setupSuccession(true, true);
        core.initialize(address(registry), address(artist), address(successor));
        successor.executeSingleStepMint(_request(successor), "");
        successor.executeSingleStepMint(_request(successor), "");
        _commit();
        successor.importMintState(_batchImport());
        _seal();
        require(
            nextLedger.counterValue(_key(address(successor), _subject(address(nextLedger)))) == 2,
            "higher successor value retained"
        );
    }

    function testPredecessorTicketCannotBeReissuedByChangingExecutionManager() public {
        _setupSuccession(true, true);
        _commit();
        successor.importMintState(_batchImport());
        _seal();
        StreamMintTicketGate gate = new StreamMintTicketGate(address(authority), signer, 1);
        StreamMintTicketTypes.MintTicket memory ticket = _ticket(10);
        IStreamMintManager.MintBatch memory b = _request(successor);
        b.authorizer = signer;
        bytes memory data = abi.encode(
            ticket,
            _signature(
                SIGNER_KEY, StreamMintTicketHash.digest(block.chainid, address(gate), ticket)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamMintTicketGate.MintTicketBindingMismatch.selector)
        );
        gate.validateMintBatch(address(successor), address(this), b, data);
    }
}
