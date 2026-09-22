// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryHydrationFixture.sol";

/// @notice Two original guarded Complete History imports retain nonempty family history.
/// @dev Source-authored regression. Runtime, deployment size and transaction gas remain pending.
contract StreamArtistCompleteHistoryMixedRepeatedActualTest is
    ArtistCompleteHistoryHydrationFixture
{
    function testCompleteHistoryActualSecondImportRetainsMixedFamiliesAndFreshPayout() external {
        CompleteRun memory first = _chRun();
        T.SuiteConfiguration memory original = suite;
        bytes32 originalFacts = _sealedFacts(original);
        _chImport(first);
        bytes32 firstValue = HydrationOwner(first.next.identity).authorityHydrationCommitment();
        _chAdopt(first);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        bytes32 priorPayout = chPayouts[chPayouts.length - 1];
        bytes32 freshPayout = _chPayout(address(0xC103));
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[5]).artistNativeReceiptCount() == 1
                && CHFPayout(suite.owners[5])
                .designationRecord(freshPayout)
                .previousDesignationRecordHash == priorPayout,
            "actual successor18 extends payout without inventing Identity native history"
        );
        CompleteRun memory second = _chPrepare(first.prepared.admission, first.latest);
        RH.Provenance memory before_ = first.prepared.admission.provenance;
        RH.Provenance memory after_ = second.prepared.admission.provenance;
        require(
            before_.eras.length == 1 && after_.eras.length == 2
                && after_.eras[1].priorImportCommitment == firstValue
                && second.request.expectedSourceImportCommitment == firstValue
                && keccak256(abi.encode(after_.eras[0])) == keccak256(abi.encode(before_.eras[0])),
            "second real CT cutover retains exact first era and actual import commitment"
        );
        for (uint8 owner; owner < 7; ++owner) {
            uint256 fresh = owner == 5 ? 1 : 0;
            require(
                after_.eras[1].nativeCounts[owner] == fresh
                    && after_.journals[owner].length == before_.journals[owner].length + fresh,
                "only actual successor payout creates a new native occurrence"
            );
            for (uint256 i; i < before_.journals[owner].length; ++i) {
                require(
                    keccak256(abi.encode(after_.journals[owner][i]))
                        == keccak256(abi.encode(before_.journals[owner][i])),
                    "every original native index and admission point survives second import"
                );
            }
            (RH.ExportHeader memory header,) =
                Payload.decode(second.prepared.data[owner].typedState, owner);
            require(
                (header.requiredFeatures & (CHType.FEATURE | RH.REPEATED_IMPORT))
                    == (CHType.FEATURE | RH.REPEATED_IMPORT),
                "all seven owners select repeated complete history"
            );
        }
        RH.JournalEntry memory freshEntry = after_.journals[5][after_.journals[5].length - 1];
        require(
            freshEntry.receipt.operation == 18 && freshEntry.receipt.recordHash == freshPayout
                && freshEntry.position.nativeIndex == 0
                && freshEntry.position.point.environmentHash == after_.eras[1].originHash,
            "new18 preserves its actual original successor coordinate"
        );
        bytes32 sourceFacts = _chSourceHash();
        uint256 nonce = artist.nonce();
        _chImport(second);
        require(
            artist.nonce() == nonce + 1 && _chSourceHash() == sourceFacts
                && _sealedFacts(original) == originalFacts,
            "second actual Safe import leaves both sealed source eras untouched"
        );
        require(
            HydrationOwner(second.next.identity).authorityHydrationCommitment() != firstValue,
            "second complete import has its own original commitment"
        );
        T.SuiteConfiguration memory destination = second.next.coordinator.suiteConfiguration();
        require(
            CHFPayout(destination.owners[5]).designationRecord(priorPayout).payoutAccount
                    == address(0xC102)
                && CHFPayout(destination.owners[5]).designationRecord(freshPayout).payoutAccount
                == address(0xC103),
            "historical and new payout bodies coexist after second actual CT import"
        );
        require(
            CHFDelegations(destination.owners[2]).delegationRecord(chGrant).uses == 4,
            "repeated import cannot consume grant uses again"
        );
    }

    function _sealedFacts(T.SuiteConfiguration memory source) private view returns (bytes32 h) {
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
