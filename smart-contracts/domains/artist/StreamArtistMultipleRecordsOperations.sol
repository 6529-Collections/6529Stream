// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleRecordsSource.sol";

library StreamArtistMultipleRecordsOperations {
    event MultipleArtistAuthorityHydrated(
        address indexed predecessor,
        bytes32 indexed commitment,
        bytes32[] artistIds,
        uint256[] collectionIds
    );

    function hydrate(D.CoordinatorContext memory x, address actor, MR.Request memory request)
        public
        returns (bytes32 value)
    {
        MH.Request memory p = request.authority;
        StreamArtistMultipleHydrationOperations._selectors(p);
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        if (history.importedHistoryBindingCount() != 1) revert T.InvalidBinding();
        (address prior,,,) = history.importedHistoryBinding(0);
        (, bytes32 pin,) = history.artistHistoryPredecessorBinding(prior);
        StreamArtistHistoryProof.predecessor(
            x.suite.core,
            x.suite.registry,
            prior,
            pin,
            StreamArtistHistoryProof.cap(x.suite.registry)
        );
        (bool sealed_, address successor,) = IStreamArtistHistory(prior).artistRegistryCutover();
        if (
            !sealed_ || successor != x.suite.registry
                || IStreamArtistHistory(prior).importedHistoryBindingCount() != 0
        ) revert T.InvalidBinding();
        address coordinator = IStreamArtistIngressBinding(prior).operationCoordinator();
        T.SuiteConfiguration memory source =
            IStreamArtistAuthorityHydrationCoordinator(coordinator).authorityHydrationSuite();
        StreamArtistHydrationSourceGuards._suite(x.suite, source, prior, coordinator);
        StreamArtistHydrationPrepared.Bundle memory h =
            StreamArtistMultipleRecordsSource.prepare(x, request, source, prior, coordinator);
        AH.Request memory base;
        base.artistId = h.q.artistId;
        base.collectionId = h.q.collectionId;
        base.policies = h.q.policies;
        base.expectedSource = p.expectedSource;
        base.replayOrigins = p.replayOrigins;
        value = StreamArtistHydrationCommit.execute(x, actor, base, h);
        uint256[] memory ids = new uint256[](p.collections.length);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = p.collections[i].collectionId;
        }
        emit MultipleArtistAuthorityHydrated(prior, value, p.artistIds, ids);
    }
}
