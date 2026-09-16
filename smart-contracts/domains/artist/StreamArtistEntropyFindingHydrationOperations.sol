// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEntropyFindingHydration.sol";
import "./StreamArtistHydrationSource.sol";
import "./StreamArtistPublicationHydrationFacts.sol";
import "./StreamArtistHydrationCommit.sol";

library StreamArtistEntropyFindingHydrationOperations {
    function hydrate(D.CoordinatorContext memory x, address actor, FH.Request memory p)
        public
        returns (bytes32)
    {
        if (
            p.economics.length > 128 || p.attestations.length > 128
                || (p.economics.length != 0 && !p.includePayout)
                || (p.attestations.length != 0 && p.economics.length == 0)
                || (p.publications && p.attestations.length == 0)
        ) revert T.UnsupportedProfile();
        StreamArtistHydrationPrepared.Bundle memory h =
            StreamArtistHydrationSource.prepareWithEntropyFindings(x, p);
        bytes memory original = h.data[2].typedState;
        FH.Bundle memory b = StreamArtistEntropyFindingHydration.decode(original);
        _findings(h, b);
        h.data[2].typedState = b.identityState;
        if (p.publications) {
            StreamArtistPublicationHydrationFacts.check(
                h.q, h.data, h.source, p.economics, p.attestations
            );
        } else {
            StreamArtistHydrationRecordFacts.check(
                h.q, h.data, h.source, p.includePayout, p.economics, p.attestations
            );
        }
        h.data[2].typedState = original;
        return StreamArtistHydrationCommit.execute(x, actor, p.authority, h);
    }

    function _findings(StreamArtistHydrationPrepared.Bundle memory h, FH.Bundle memory b)
        private
        view
    {
        if (
            b.sourceRegistry != h.prior
                || keccak256(b.identityState)
                    != keccak256(
                        IStreamArtistAuthorityHydrationOwner(h.source.owners[2])
                            .authorityHydrationState(h.q)
                    )
        ) revert T.InvalidRecord();
        StreamArtistEntropyFindingHydration.validateHead(b);
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            block.chainid, h.prior, h.source.core, h.source.mintManager
        );
        uint256 used;
        address owner = h.source.owners[2];
        uint256 count = IStreamArtistNativeReceipts(owner).artistNativeReceiptCount();
        for (uint256 j; j < count; ++j) {
            H.Receipt memory n = IStreamArtistNativeReceipts(owner).artistNativeReceiptAt(j);
            if (n.operation != 23) continue;
            if (used >= b.records.length) revert T.InvalidRecord();
            FH.Row memory row = b.records[used++];
            StreamArtistEntropyFindingHydration.validate(e, h.q, row);
            (Recovery.FindingRecord memory r, EU.Admission memory a) = IStreamArtistEntropyUnavailabilityOwner(
                    owner
                ).entropyUnavailabilityFindingRecord(n.recordHash);
            if (
                row.record.recordHash != n.recordHash
                    || keccak256(abi.encode(row.record, row.admission))
                        != keccak256(abi.encode(r, a))
                    || IStreamArtistEntropyFindingHydrationOwner(owner)
                            .entropyUnavailabilityFindingOrigin(n.recordHash) != h.prior
            ) revert T.InvalidRecord();
            _guard(
                h.data[2],
                keccak256("identity_authority.replay.governance_action_id"),
                keccak256(abi.encode(r.governanceActionId)),
                r.recordHash
            );
            _guard(
                h.data[2],
                keccak256("identity_authority.replay.finding_key"),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                        EU.PROFILE,
                        h.q.artistId,
                        r.bindingGeneration,
                        r.bindingHash,
                        a.target
                    )
                ),
                r.recordHash
            );
        }
        if (
            used != b.records.length
                || IStreamArtistUnavailabilityOwner(owner)
                        .latestUnavailabilityFinding(h.q.artistId, h.q.collectionId) != b.latest
        ) revert T.InvalidRecord();
    }

    function _guard(AH.OwnerData memory data, bytes32 surface, bytes32 scope, bytes32 record)
        private
        pure
    {
        uint256 found;
        for (uint256 j; j < data.origins.length; ++j) {
            if (data.origins[j].surface == surface && data.origins[j].scope == scope) {
                if (
                    data.cells[j].kind != 1 || data.cells[j].status != 2
                        || data.cells[j].commitment != record
                ) revert T.InvalidRecord();
                ++found;
            }
        }
        if (found != 1) revert T.InvalidRecord();
    }
}
