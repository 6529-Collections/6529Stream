// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentAuthorityScopedPreservationPolicyFinalityTestFixture.sol";

/// @notice Actual TOKEN/RELEASE/SEASON C-authority sanction, archive and terminal Finality calls.
/// @dev Offchain PNG/package observations and checkpoint observers are explicitly synthetic
/// fixture evidence. No browser is executed, no capture acceptance is claimed, and no case skips
/// when external files are absent. Runtime/gas/size validation of this composition remains pending.
contract StreamCurrentAuthorityScopedPreservationFinalityTest is
    StreamCurrentAuthorityScopedPreservationPolicyFinalityTestFixture
{
    uint8 private negativeScenario;
    bytes32 private rejectedArchiveAction;
    bytes32 private retriedSanctionRecord;
    bytes32 private retriedSanctionArchiveHash;
    uint256 private archiveRejections;
    uint256 private sanctionRejections;

    function testActualTokenCArtistSanctionArchiveAndScopedFinality() public {
        AuthorityScopedFinality memory result =
            _runScopedFinalityComposition(StreamFinalityScopeType.TOKEN);
        _requireFinalScope(result, StreamFinalityScopeType.TOKEN);
    }

    function testActualReleaseCArtistSanctionArchiveAndScopedFinality() public {
        AuthorityScopedFinality memory result =
            _runScopedFinalityComposition(StreamFinalityScopeType.RELEASE);
        _requireFinalScope(result, StreamFinalityScopeType.RELEASE);
    }

    function testActualSeasonCArtistSanctionArchiveAndScopedFinality() public {
        AuthorityScopedFinality memory result =
            _runScopedFinalityComposition(StreamFinalityScopeType.SEASON);
        _requireFinalScope(result, StreamFinalityScopeType.SEASON);
    }

    function testActualGovernedMissingArchiveRollsBackThenCanonicalTokenActionFinalizes() public {
        negativeScenario = 1;
        AuthorityScopedFinality memory result =
            _runScopedFinalityComposition(StreamFinalityScopeType.TOKEN);
        _requireFinalScope(result, StreamFinalityScopeType.TOKEN);
        require(
            archiveRejections == 1 && rejectedArchiveAction != 0
                && rejectedArchiveAction != result.actionId,
            "separate canonical action; rejected calldata was not rewritten"
        );
        require(
            assemblyExecutor.governanceAction(rejectedArchiveAction).status
                    == GovernanceActionStatus.SCHEDULED
                && assemblyExecutor.governanceAction(result.actionId).status
                    == GovernanceActionStatus.EXECUTED,
            "failed proposal remains scheduled; exact canonical proposal executed"
        );
    }

    function testActualMismatchedSeasonSanctionPreservesNonceAndExactValidProofRetries() public {
        negativeScenario = 2;
        AuthorityScopedFinality memory result =
            _runScopedFinalityComposition(StreamFinalityScopeType.SEASON);
        _requireFinalScope(result, StreamFinalityScopeType.SEASON);
        require(
            sanctionRejections == 1 && retriedSanctionRecord != 0
                && retriedSanctionRecord != result.sanctionRecord,
            "retried earlier sanction is distinct retained history"
        );
        require(
            assemblyArtists.sanctionRecord(retriedSanctionRecord).recordHash
                    == retriedSanctionRecord
                && keccak256(assemblyArtists.sanctionArchiveBytes(retriedSanctionRecord))
                == retriedSanctionArchiveHash,
            "exact successful retry record and archive remain historical after canonical final sanction"
        );
        require(
            ScopedCeremonyDisplay(address(assemblyArtists)).displaySanction(result.scope).recordHash
                == result.sanctionRecord,
            "terminal Finality uses the later exact current sanction"
        );
    }

    function _beforeCompositionSanction(StreamFinalityScope memory scope) internal override {
        if (negativeScenario != 2) return;
        bytes memory raw = assemblyProvider.inputManifestBytes(scope);
        bytes32[] memory chunks = _assemblyUpload(raw);
        require(chunks.length == 1 && chunks[0] == keccak256(raw));
        require(assemblyFinality.stageFinalityManifest(raw) == chunks[0]);
        string memory uri = "urn:fixture:current-authority:scoped-preservation-finality";
        AssemblySanctionRequest.Request memory request;
        request.manifest = StreamFinalityManifestRef(
            uri,
            keccak256(bytes(uri)),
            chunks[0],
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_V1"),
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_ABI_V1")
        );
        (uint256 count,) = assemblyDiscovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9);
        request.nonSanctionComponents = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            request.nonSanctionComponents[i] = assemblyDiscovery.nonSanctionComponentAt(scope, i);
        }
        request.terms.scopeType = uint8(scope.scopeType);
        request.terms.collectionId = scope.collectionId;
        request.terms.tokenId = scope.tokenId;
        request.terms.scopeId = scope.scopeId;
        request.statement =
            "Exact valid C-artist proof retry after a deliberately mismatched subject in this composition fixture.";
        request.signingToolName = "Current C Safe fixture";
        request.signingToolVersion = "1";
        AssemblySanctionRequest.Prepared memory prepared =
            assemblyArtists.prepareArtistSanction(request);
        request.terms.sanctionSubjectHash = StreamArtistSanctionHashes.subject(prepared.subject);
        request.terms.statementHash = keccak256(prepared.ceremony);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        bytes32 digest = assemblyArtists.sanctionDigest(request.terms, authorization);
        authorization.signature = _assemblyArtistProof(digest, authorization.nonce);
        bytes32 requestHash = keccak256(abi.encode(request));
        bytes32 authorizationHash = keccak256(abi.encode(authorization));
        bytes32 ownersBefore = _compositionOwnerStateHash();
        bytes32 replayBefore = keccak256(
            abi.encode(
                assemblyArtists.artistAuthorizationState(
                    assemblyArtistId, digest, authorization.nonce
                )
            )
        );
        bytes32 displayBefore = keccak256(
            abi.encode(ScopedCeremonyDisplay(address(assemblyArtists)).displaySanction(scope))
        );
        // Deep-copy the request; the unchanged signature is valid for the intended canonical
        // request, never for this deliberately malformed subject. No memory alias is repaired.
        AssemblySanctionRequest.Request memory wrong =
            abi.decode(abi.encode(request), (AssemblySanctionRequest.Request));
        wrong.terms.sanctionSubjectHash ^= bytes32(uint256(1));
        require(
            wrong.terms.sanctionSubjectHash != 0 && keccak256(abi.encode(request)) == requestHash
        );
        (bool accepted, bytes memory reason) = address(assemblyArtists)
            .call(abi.encodeCall(assemblyArtists.recordArtistSanction, (wrong, authorization)));
        require(
            !accepted
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(AssemblySanction.InvalidSanction.selector)),
            "real operation12 rejects subject mismatch before consuming current authority"
        );
        ++sanctionRejections;
        require(
            _compositionOwnerStateHash() == ownersBefore
                && keccak256(
                    abi.encode(
                        assemblyArtists.artistAuthorizationState(
                            assemblyArtistId, digest, authorization.nonce
                        )
                    )
                ) == replayBefore
                && keccak256(
                    abi.encode(
                        ScopedCeremonyDisplay(address(assemblyArtists)).displaySanction(scope)
                    )
                ) == displayBefore,
            "all seven owner snapshots, actual authorization state and sanction head roll back"
        );
        require(
            keccak256(abi.encode(request)) == requestHash
                && keccak256(abi.encode(authorization)) == authorizationHash
                && assemblyArtists.sanctionDigest(request.terms, authorization) == digest,
            "byte-identical intended request, nonce, deadline and current Safe proof retry"
        );
        retriedSanctionRecord = assemblyArtists.recordArtistSanction(request, authorization);
        AssemblySanction.Record memory saved = assemblyArtists.sanctionRecord(retriedSanctionRecord);
        require(
            saved.recordHash == retriedSanctionRecord && saved.digest == digest
                && saved.nonce == authorization.nonce && saved.deadline == authorization.time
                && saved.signer == address(assemblyArtist) && saved.authorityClass == 1
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request.terms)),
            "same genuine C Safe authorization succeeds for its exact intended terms"
        );
        require(
            _compositionOwnerStateHash() != ownersBefore
                && keccak256(
                    abi.encode(
                        assemblyArtists.artistAuthorizationState(
                            assemblyArtistId, digest, authorization.nonce
                        )
                    )
                ) != replayBefore,
            "successful exact retry consumes actual owner and authorization state"
        );
        retriedSanctionArchiveHash =
            keccak256(assemblyArtists.sanctionArchiveBytes(retriedSanctionRecord));
    }

    function _beforeScopedCeremonyFinalize(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components,
        bytes32 finalityRecord,
        StreamFinalityManifestRef memory manifest,
        StreamFinalitySanctionArchiveProof memory proof,
        StreamFinalityExecutionContext memory execution
    ) internal override {
        if (negativeScenario != 1) return;
        bytes32 canonical =
            keccak256(abi.encode(scope, components, finalityRecord, manifest, proof, execution));
        StreamFinalitySanctionArchiveProof memory wrong =
            abi.decode(abi.encode(proof), (StreamFinalitySanctionArchiveProof));
        wrong.completionHash = 0;
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(
            assemblyFinality.finalizeArtworkScopeWithArchive,
            (scope, components, finalityRecord, manifest, wrong)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyFinality),
            batch.callDatas[0],
            execution.scopeHash,
            execution.oldValueHash,
            execution.newValueHash
        );
        _admitAssemblyBatch(batch);
        rejectedArchiveAction = _assemblyScheduleGovernance(
            batch, "https://fixtures.example.invalid/current-authority/negative-scoped-archive"
        );
        GovernanceAction memory action = assemblyExecutor.governanceAction(rejectedArchiveAction);
        require(
            action.status == GovernanceActionStatus.SCHEDULED
                && action.proposer == address(assemblyRoot)
        );
        assemblyVm.warp(action.notBefore);
        bytes32 before_ = _compositionFinalityState(scope, finalityRecord, proof.sanctionRecordHash);
        bytes32 actionBefore = keccak256(abi.encode(action));
        (bool accepted, bytes memory reason) = address(assemblyExecutor)
            .call(
                abi.encodeCall(
                    assemblyExecutor.executeGovernanceBatch,
                    (rejectedArchiveAction, batch.calls, batch.callDatas)
                )
            );
        require(
            !accepted
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            ScopedCeremonyArchiveAPI.FinalitySanctionArchiveInvalid.selector
                        )
                    ),
            "actual class2 callback rejects zero archive completion"
        );
        ++archiveRejections;
        require(
            _compositionFinalityState(scope, finalityRecord, proof.sanctionRecordHash) == before_
                && keccak256(abi.encode(assemblyExecutor.governanceAction(rejectedArchiveAction)))
                    == actionBefore,
            "failed callback rolls back complete current records, owner states and scheduled action"
        );
        (bool executing,,,,,) = assemblyExecutor.currentAction();
        require(!executing, "failed call leaves no active governance context");
        require(
            keccak256(abi.encode(scope, components, finalityRecord, manifest, proof, execution))
                == canonical,
            "negative deep copy leaves canonical positive arguments untouched"
        );
        // Parent fixture next schedules a separate action for the exact canonical original
        // calldata. The invalid proposal remains immutable and scheduled, never rewritten.
    }

    function _compositionOwnerStateHash() private view returns (bytes32 chain) {
        for (uint256 i; i < 7; ++i) {
            chain = keccak256(
                abi.encode(
                    chain, IStreamArtistOwner(assemblySuite.owners[i]).ownerStateSnapshotV2()
                )
            );
        }
    }

    function _compositionFinalityState(
        StreamFinalityScope memory scope,
        bytes32 record,
        bytes32 sanction
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _compositionOwnerStateHash(),
                assemblyAuthorityResolver.currentSelection(),
                assemblyArtists.sanctionRecord(sanction),
                keccak256(assemblyArtists.sanctionArchiveBytes(sanction)),
                assemblyFinality.artworkScopeFinalityRecord(scope),
                assemblyFinality.collectionFinalityRecord(scope.collectionId),
                assemblyFinality.finalityExecutionWitness(record),
                assemblyFinality.finalitySanctionArchiveWitness(record),
                assemblyFinality.artworkFreezeMode(scope),
                assemblyArtist.nonce(),
                assemblyRoot.nonce(),
                keccak256(assemblyProvider.inputManifestBytes(scope))
            )
        );
    }

    function _requireFinalScope(AuthorityScopedFinality memory result, StreamFinalityScopeType kind)
        private
        view
    {
        require(
            result.scope.scopeType == kind && authorityEra == 2
                && result.artistRegistry == authorityRegistries[2]
                && result.artistRegistry == address(assemblyArtists)
        );
        require(
            assemblyFinality.artworkScopeFinalityRecord(result.scope).finalityRecordHash
                    == result.finalityRecord
                && assemblyFinality.artworkFreezeMode(result.scope) == StreamArtworkFreezeMode.EXACT
                && !assemblyFinality.collectionFinalityRecord(result.scope.collectionId).finalized,
            "exact scoped terminal record without invented collection completion"
        );
        AssemblySanction.Record memory saved = assemblyArtists.sanctionRecord(result.sanctionRecord);
        require(
            saved.recordHash == result.sanctionRecord && saved.signer == address(assemblyArtist)
                && saved.authorityClass == 1 && saved.terms.scopeType == uint8(kind)
                && saved.terms.collectionId == result.scope.collectionId
                && saved.terms.tokenId == result.scope.tokenId
                && saved.terms.scopeId == result.scope.scopeId
        );
        require(
            assemblyMetadata.artistRegistry() == authorityRegistries[0]
                && address(assemblyFinality.sanctionReads()) == authorityRegistries[0]
                && assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider),
            "original Metadata/Finality/provider anchors retained while C supplies sanction"
        );
    }
}
