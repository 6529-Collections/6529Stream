// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PreservationActualInventoryFixture.sol";
import "./PreservationSafeCallProbe.sol";

/// @dev Actual eight-source inventory/Metadata/Schema/Store/Router/ArchiveV2 and
/// two-owner Safe. The inherited Core, Artist semantic owners, Executor and seed
/// boundaries remain explicit. This is selector behavior, not a new capacity claim.
contract StreamPreservationSafeSurfaceTest is PreservationActualInventoryFixture {
    PreservationSafeCallProbe private probe;

    function setUp() public override {
        super.setUp();
        probe = new PreservationSafeCallProbe();
    }

    function safeSurfaceExecute(address target, bytes memory data) external returns (bool) {
        require(msg.sender == address(this), "test entry only");
        return executeSafe(archiveAgentSafe, archiveAgentKeys, target, 0, data, 0);
    }

    function _call(bytes memory data) private {
        uint256 nonce = archiveAgentSafe.nonce();
        require(this.safeSurfaceExecute(address(renderInventory), data), "direct Safe CALL");
        require(archiveAgentSafe.nonce() == nonce + 1, "one committed Safe nonce");
    }

    function _reject(bytes memory data, bytes32 id) private {
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 before_ = keccak256(abi.encode(renderInventory.plan(id)));
        (bool ok,) = address(this)
            .call(abi.encodeCall(this.safeSurfaceExecute, (address(renderInventory), data)));
        require(
            !ok && archiveAgentSafe.nonce() == nonce, "failed zero-gas Safe call rolls nonce back"
        );
        require(
            keccak256(abi.encode(renderInventory.plan(id))) == before_, "all plan fields roll back"
        );
    }

    function _read(bytes memory data, bytes memory expected) private {
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 owners = keccak256(abi.encode(archiveAgentSafe.getOwners()));
        uint256 threshold = archiveAgentSafe.getThreshold();
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(probe),
                0,
                abi.encodeCall(
                    probe.check,
                    (address(archiveAgentSafe), address(renderInventory), data, expected)
                ),
                1
            ),
            "Safe-context exact target CALL return"
        );
        require(archiveAgentSafe.nonce() == nonce + 1, "one checked read nonce");
        require(
            archiveAgentSafe.getThreshold() == threshold
                && keccak256(abi.encode(archiveAgentSafe.getOwners())) == owners,
            "stateless probe preserves Safe authority"
        );
    }

    function _completeSelectedStages() private returns (bytes32 id) {
        _call(abi.encodeCall(renderInventory.beginInventory, (uint256(1))));
        id = renderInventory.beginInventory(1);
        _call(abi.encodeCall(renderInventory.appendNative, (id)));
        // The exact 479-row Safe transaction envelope is retained in accepted31.
        // This new test exercises the previously uncovered selected stages only.
        renderInventory.appendReference(id);
        _call(abi.encodeCall(renderInventory.appendWork, (id, selectedWork, address(0))));
        _call(abi.encodeCall(renderInventory.appendRights, (id, selectedRights)));
        _call(
            abi.encodeCall(renderInventory.appendIntentWaiver, (id, selectedWaiver, address(this)))
        );
        _call(abi.encodeCall(renderInventory.appendInterviewWaiver, (id)));
        _call(
            abi.encodeCall(
                renderInventory.appendRootAuthorization, (id, address(this), uint64(1000))
            )
        );
        for (uint256 i; i < 31; ++i) {
            _call(abi.encodeCall(renderInventory.appendDefinition, (id)));
        }
        _call(abi.encodeCall(renderInventory.appendToken, (id, _originalTokenPayload(1))));
        _call(abi.encodeCall(renderInventory.appendToken, (id, _originalTokenPayload(2))));
        _call(abi.encodeCall(renderInventory.sealInventory, (id)));
    }

    function testSafeAllDeclaredInventoryReadsAndSelectedStageAttribution() public {
        bytes32 id = _completeSelectedStages();
        InventoryT.Evidence memory e = renderInventory.inventoryEvidence(id);
        require(
            e.itemCount == 547 && e.segmentCount == 40 && e.tokenCount == 2,
            "complete actual inventory"
        );
        _read(abi.encodeCall(renderInventory.core, ()), abi.encode(address(core)));
        _read(abi.encodeCall(renderInventory.metadataHost, ()), abi.encode(address(metadata)));
        _read(abi.encodeCall(renderInventory.metadataRouter, ()), abi.encode(address(router)));
        _read(abi.encodeCall(renderInventory.snapshots, ()), abi.encode(address(snapshots)));
        _read(
            abi.encodeCall(renderInventory.referencePublisher, ()),
            abi.encode(address(referenceHost))
        );
        _read(abi.encodeCall(renderInventory.artifactCoverage, ()), abi.encode(artifactTarget));
        _read(
            abi.encodeCall(renderInventory.externalCoverage, ()), abi.encode(address(archiveHost))
        );
        _read(abi.encodeCall(renderInventory.deploymentChainId, ()), abi.encode(block.chainid));
        _read(abi.encodeCall(renderInventory.coreCodeHash, ()), abi.encode(address(core).codehash));
        _read(
            abi.encodeCall(renderInventory.metadataCodeHash, ()),
            abi.encode(address(metadata).codehash)
        );
        _read(abi.encodeCall(renderInventory.inventoryEvidence, (id)), abi.encode(e));
        _read(abi.encodeCall(renderInventory.requireCurrent, (uint256(1))), abi.encode(e));
        InventoryT.Segment memory last = renderInventory.inventorySegment(id, 39);
        require(last.itemCount == 4 && last.sourceWitnessHash != 0, "last original token segment");
        _read(abi.encodeCall(renderInventory.inventorySegment, (id, uint64(39))), abi.encode(last));
        _read(abi.encodeCall(renderInventory.dependencies, ()), abi.encode(inventoryDependencies));
        _read(
            abi.encodeCall(renderInventory.dependencyHash, ()),
            abi.encode(keccak256(abi.encode(inventoryDependencies)))
        );
        _read(abi.encodeCall(renderInventory.plan, (id)), abi.encode(renderInventory.plan(id)));
        SourcesT.Context memory c = renderInventory.sourceContext(id);
        _read(abi.encodeCall(renderInventory.sourceContext, (id)), abi.encode(c));
        _read(abi.encodeCall(renderInventory.requireFullDefinitionBytes, (id)), bytes(""));
        require(
            c.conservation.record.recorder == address(this)
                && c.referenceRender.recorder == address(this)
                && c.snapshot.publisher == address(this),
            "permissionless Safe never becomes original author"
        );
        require(
            e.originals.intentRecordHash == 0 && e.originals.intentWaiverRecordHash == waiverRecord,
            "explicit selected intent waiver preserved"
        );
        _reject(abi.encodeCall(renderInventory.appendDefinition, (id)), id);
    }

    function testSafeCanonicalWitnessFailureAndOriginalActorRetry() public {
        bytes32 id = renderInventory.beginInventory(1);
        _reject(abi.encodeCall(renderInventory.appendWork, (id, selectedWork, address(0))), id);
        renderInventory.appendNative(id);
        renderInventory.appendReference(id);
        StreamWorkRecordTypes.Description memory wrong = selectedWork;
        wrong.full.title = "not the original signed record";
        _reject(abi.encodeCall(renderInventory.appendWork, (id, wrong, address(0))), id);
        _call(abi.encodeCall(renderInventory.appendWork, (id, selectedWork, address(0))));
        _call(abi.encodeCall(renderInventory.appendRights, (id, selectedRights)));
        StreamConservationRecordTypes.Intent memory inactiveIntent;
        _reject(
            abi.encodeCall(renderInventory.appendIntent, (id, inactiveIntent, address(this))), id
        );
        _reject(
            abi.encodeCall(
                renderInventory.appendIntentWaiver, (id, selectedWaiver, address(archiveAgentSafe))
            ),
            id
        );
        _call(
            abi.encodeCall(renderInventory.appendIntentWaiver, (id, selectedWaiver, address(this)))
        );
        StreamConservationRecordTypes.Interview memory inactiveInterview;
        _reject(
            abi.encodeCall(renderInventory.appendInterview, (id, inactiveInterview, address(this))),
            id
        );
        _call(abi.encodeCall(renderInventory.appendInterviewWaiver, (id)));
        _reject(
            abi.encodeCall(
                renderInventory.appendRootAuthorization, (id, address(this), uint64(999))
            ),
            id
        );
        _call(
            abi.encodeCall(
                renderInventory.appendRootAuthorization, (id, address(this), uint64(1000))
            )
        );
        require(
            renderInventory.plan(id).completedStages == 7, "original source retry advanced exactly"
        );
    }

    function testSafeCurrentFailureKeepsHistoricalEvidenceAndExactSignedRetry() public {
        bytes32 id = _completeSelectedStages();
        InventoryT.Evidence memory e = renderInventory.inventoryEvidence(id);
        bytes memory data = abi.encodeCall(renderInventory.requireCurrent, (uint256(1)));
        uint256 nonce = archiveAgentSafe.nonce();
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(renderInventory), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(archiveAgentKeys, digest);
        bytes memory transaction = abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(renderInventory),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        _extRecordFixity(originalFirstReceipts[0], 2, false);
        (bool ok,) = address(archiveAgentSafe).call(transaction);
        require(!ok && archiveAgentSafe.nonce() == nonce, "stale Safe current leaves nonce unused");
        _extRecordFixity(originalFirstReceipts[0], 1, true);
        bytes memory result;
        (ok, result) = address(archiveAgentSafe).call(transaction);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)),
            "identical signed retry succeeds"
        );
        require(archiveAgentSafe.nonce() == nonce + 1, "identical retry commits once");
        _read(abi.encodeCall(renderInventory.inventoryEvidence, (id)), abi.encode(e));
        _read(abi.encodeCall(renderInventory.requireCurrent, (uint256(1))), abi.encode(e));
    }

    function testFuzzSafeOutOfBoundsSegmentReadCannotConsumeNonce(uint64 extra) public {
        bytes32 id = renderInventory.beginInventory(1);
        renderInventory.appendNative(id);
        uint64 index = extra == 0 ? 1 : extra;
        _reject(abi.encodeCall(renderInventory.inventorySegment, (id, index)), id);
        _reject(abi.encodeCall(renderInventory.inventoryEvidence, (id)), id);
        require(
            renderInventory.plan(id).segmentCount == 1, "unsealed original native segment retained"
        );
    }

    function testSafeReturnProbeRejectsWrongContextAndReturnBytes() public {
        bytes memory input = abi.encodeCall(renderInventory.core, ());
        (bool ok,) = address(probe)
            .call(
                abi.encodeCall(
                    probe.check,
                    (
                        address(archiveAgentSafe),
                        address(renderInventory),
                        input,
                        abi.encode(address(core))
                    )
                )
            );
        require(!ok, "ordinary relay is not a Safe-context proof");
        uint256 nonce = archiveAgentSafe.nonce();
        bytes memory data = abi.encodeCall(
            probe.check,
            (
                address(archiveAgentSafe),
                address(renderInventory),
                input,
                abi.encode(address(metadata))
            )
        );
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(probe), 0, data, 1, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory transaction = abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(probe),
                0,
                data,
                1,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(archiveAgentKeys, digest)
            )
        );
        (ok,) = address(archiveAgentSafe).call(transaction);
        require(
            !ok && archiveAgentSafe.nonce() == nonce, "incorrect return assertion rolls back Safe"
        );
        _read(input, abi.encode(address(core)));
    }
}
