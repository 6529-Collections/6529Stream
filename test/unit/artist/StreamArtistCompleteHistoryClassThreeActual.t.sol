// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryPayoutContinuationFixture.sol";

/// @notice Rich Class3 histories and V3 Payout continuations through original guarded CT imports.
/// @dev Source-authored integration regressions. Runtime, bytecode size and gas remain pending.
/// Core, documentary, Finality and scheduled governance retain the explicit fixture boundaries.
contract StreamArtistCompleteHistoryClassThreeActualTest is
    ArtistCompleteHistoryPayoutContinuationFixture
{
    bytes32 private chEstateCredentialIdentity;

    function testCompleteHistoryActualClassThreeRetainsRichLivingHistoryAndEstateCredential()
        external
    {
        (CHAdmissionType.Certificate memory source, bytes32 latest) = _chClassThreeRichSource();
        CompleteRun memory run = _chPrepare(source, latest);
        bytes32 before_ = _chClassThreeSourceHash();
        uint256 nonce = artist.nonce();
        _chImport(run);
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        _chAssertClassThree(target);
        _chAssertEstateCredential(target);
        require(
            artist.nonce() == nonce + 1 && _chClassThreeSourceHash() == before_,
            "actual estate Safe imports the full sealed source once"
        );
    }

    function testCompleteHistoryActualRecoveredClassThreePayoutContinuationAcrossTwoImports()
        external
    {
        CompleteRun memory first = _chRecoveredPayoutRun();
        T.SuiteConfiguration memory original = suite;
        bytes32 originalFacts = _chSealedFacts(original);
        _chImport(first);
        T.SuiteConfiguration memory destination = first.next.coordinator.suiteConfiguration();
        _chAssertClassThree(destination);
        _chAssertEstateCredential(destination);
        _chAssertPayoutContinuation(destination);
        bytes32 firstValue = HydrationOwner(first.next.identity).authorityHydrationCommitment();
        _chAdopt(first);
        bytes32 fresh = _chConsumePayoutContinuation(address(0xC303));
        CompleteRun memory second = _chPrepare(first.prepared.admission, first.latest);
        _chAssertRepeatedPayoutEra(first, second, firstValue, fresh);
        bytes32 source = _chRecoveredPayoutSourceHash();
        uint256 nonce = artist.nonce();
        _chImport(second);
        destination = second.next.coordinator.suiteConfiguration();
        _chAssertClassThree(destination);
        _chAssertEstateCredential(destination);
        _chAssertPayoutContinuation(destination);
        require(
            artist.nonce() == nonce + 1 && _chRecoveredPayoutSourceHash() == source
                && _chSealedFacts(original) == originalFacts,
            "repeated actual Safe import leaves both sealed source eras intact"
        );
        require(
            HydrationOwner(second.next.identity).authorityHydrationCommitment() != firstValue
                && CHFPayout(destination.owners[5])
                    .designationRecord(fresh)
                    .previousDesignationRecordHash == chRewindStable
                && CHFPayout(destination.owners[5])
                .designationRecord(chRewindExcluded)
                .previousDesignationRecordHash == chRewindStable,
            "consumed restored branch and excluded original child both survive second CT import"
        );
    }

    function testCompleteHistoryActualRecoveredPayoutFirstArchiveAppendRollbackAndSameSafeRetry()
        external
    {
        CompleteRun memory run = _chRecoveredPayoutRun();
        bytes memory input =
            abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (run.request));
        OfficialSafe account = artist;
        uint256 nonce = account.nonce();
        bytes memory envelope = _chSafeEnvelope(account, address(run.next.registry), input, nonce);
        bytes32 exactEnvelope = keccak256(envelope);
        bytes32 before_ = _chRecoveredPayoutDestinationHash(run);
        bytes32 source = _chRecoveredPayoutSourceHash();
        uint256 originalBlock = block.number;
        // Failure reaches the first exact Archive page after all owner imports. This does
        // not claim a later-page failure after an earlier page has been persisted.
        chVm.expectCall(address(run.next.archive), _chFirstPage(run), 3);
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(run.next.registry)).hydrateRecoveredArtistAuthority(run.request);
        require(
            _chRecoveredPayoutDestinationHash(run) == before_,
            "direct first-append failure restores enumerated imported owner and V3 maps"
        );
        {
            (bool ok, bytes memory reason) = address(account).call(envelope);
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "exact recovered Safe envelope reaches original rollback"
            );
        }
        require(
            account.nonce() == nonce && keccak256(envelope) == exactEnvelope
                && _chRecoveredPayoutDestinationHash(run) == before_
                && _chRecoveredPayoutSourceHash() == source,
            "failed recovered Safe call restores nonce and enumerated chronology state"
        );
        vm.roll(originalBlock);
        {
            (bool ok, bytes memory result) = address(account).call(envelope);
            require(
                ok && result.length == 32 && abi.decode(result, (bool)),
                "identical signed recovered Safe envelope succeeds after block restoration"
            );
        }
        require(
            account.nonce() == nonce + 1 && keccak256(envelope) == exactEnvelope
                && _chRecoveredPayoutSourceHash() == source,
            "only successful import consumes the saved Safe nonce"
        );
        _chAssert(run);
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        _chAssertClassThree(target);
        _chAssertEstateCredential(target);
        _chAssertPayoutContinuation(target);
    }

    function _chClassThreeRichSource()
        private
        returns (CHAdmissionType.Certificate memory source, bytes32 latest)
    {
        (source, latest) = _chRichSource();
        _chClassThreeActivate(513);
        chEstateCredentialIdentity = ingress.operativeIdentityRecord(artistId);
        _chCredential(chAttestations[chAttestations.length - 1], false);
        _chAssertEstateCredential(suite);
    }

    function _chRecoveredPayoutRun() private returns (CompleteRun memory run) {
        (CHAdmissionType.Certificate memory source, bytes32 latest) = _chClassThreeRichSource();
        _chRewindPayoutPair();
        _chClassThreeContest();
        _chRewindPayoutRecover();
        return _chPrepare(source, latest);
    }

    function _chAssertEstateCredential(T.SuiteConfiguration memory target) private view {
        require(chAttestations.length == 3, "two original living credentials and one estate row");
        bytes32 record = chAttestations[2];
        require(
            CHFClasses(target.owners[4]).attestationAuthorityClass(chAttestations[0]) == 2
                && CHFClasses(target.owners[4]).attestationAuthorityClass(chAttestations[1]) == 1
                && CHFClasses(target.owners[4]).attestationAuthorityClass(record) == 3
                && chAttestationInputs[2].terms.subjectStateHash == chEstateCredentialIdentity
                && chEstateCredentialIdentity != 0
                && Attribution(target.owners[4]).attestationRecord(record).signer
                    == address(chClassThreeEstateSafe)
                && CHFCredentials(target.owners[4]).c2paCredentialHead(artistId).recordHash
                    == record,
            "original C2PA chain retains delegate, living principal and actual estate classes"
        );
    }

    function _chAssertRepeatedPayoutEra(
        CompleteRun memory first,
        CompleteRun memory second,
        bytes32 firstValue,
        bytes32 fresh
    ) private pure {
        RH.Provenance memory before_ = first.prepared.admission.provenance;
        RH.Provenance memory after_ = second.prepared.admission.provenance;
        require(
            before_.eras.length == 1 && after_.eras.length == 2
                && after_.eras[1].priorImportCommitment == firstValue
                && second.request.expectedSourceImportCommitment == firstValue
                && keccak256(abi.encode(after_.eras[0])) == keccak256(abi.encode(before_.eras[0])),
            "second CT preserves the original estate and V3 recovery era"
        );
        for (uint8 owner; owner < 7; ++owner) {
            uint256 added = owner == 5 ? 1 : 0;
            require(
                after_.eras[1].nativeCounts[owner] == added
                    && after_.journals[owner].length == before_.journals[owner].length + added,
                "only fresh successor18 adds a native occurrence"
            );
            for (uint256 i; i < before_.journals[owner].length; ++i) {
                require(
                    keccak256(abi.encode(after_.journals[owner][i]))
                        == keccak256(abi.encode(before_.journals[owner][i])),
                    "exact original journal positions retained including paired35"
                );
            }
            (RH.ExportHeader memory header,) =
                Payload.decode(second.prepared.data[owner].typedState, owner);
            require(
                (header.requiredFeatures & (CHType.FEATURE | RH.REPEATED_IMPORT))
                    == (CHType.FEATURE | RH.REPEATED_IMPORT),
                "all owners select repeated complete history"
            );
        }
        RH.JournalEntry memory row = after_.journals[5][after_.journals[5].length - 1];
        require(
            row.receipt.operation == 18 && row.receipt.recordHash == fresh
                && row.position.nativeIndex == 0
                && row.position.point.environmentHash == after_.eras[1].originHash,
            "continuation consumer retains its actual successor native coordinate"
        );
    }

    function _chClassThreeSourceHash() private view returns (bytes32) {
        return keccak256(abi.encode(_chSourceHash(), _chClassThreeHash(suite)));
    }

    function _chRecoveredPayoutSourceHash() private view returns (bytes32) {
        return keccak256(abi.encode(_chClassThreeSourceHash(), _chPayoutContinuationHash(suite)));
    }

    function _chRecoveredPayoutDestinationHash(CompleteRun memory run)
        private
        view
        returns (bytes32)
    {
        T.SuiteConfiguration memory target = run.next.coordinator.suiteConfiguration();
        return keccak256(
            abi.encode(
                _chDestinationHash(run),
                _chClassThreeHash(target),
                _chPayoutContinuationHash(target)
            )
        );
    }

    function _chSealedFacts(T.SuiteConfiguration memory source) private view returns (bytes32 h) {
        for (uint8 i; i < 7; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    CP(source.owners[i]).authorityCheckpoint(),
                    Publications.collect(source.owners[i], i),
                    Native(source.owners[i]).artistNativeReceiptCount()
                )
            );
        }
        StreamArtistArchiveV2 store = StreamArtistArchiveV2(source.archive);
        uint256 count = store.storedPayloadCount();
        h = keccak256(abi.encode(h, count));
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) = store.storedPayloadAt(i);
            h = keccak256(abi.encode(h, pointer, kind, hash));
        }
    }
}
