// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPlatformPrimaryProfile.sol";

library StreamPlatformTokenPrimary {
    error InvalidPlatformPrimaryTemplate();

    function resolve(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 witness) {
        if ((mode != 12 && mode != 13) || collection == 0 || token == 0 || poster == address(0)) {
            revert InvalidPlatformPrimaryTemplate();
        }
        bytes32 declaration = StreamPlatformSaleTemplate.declaration(resolver, collection);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.scope != 2 || a.scopeId != token || a.assignmentHash == 0
                || a.policyHash != 0
        ) revert InvalidPlatformPrimaryTemplate();
        selected.assignmentHash = a.assignmentHash;
        if (mode == 12) {
            if (a.assignmentType != 1 || a.profileId == 0 || a.templateId != 0) {
                revert InvalidPlatformPrimaryTemplate();
            }
            IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
            selected.profileId = a.profileId;
            selected.wallet = factory.walletFor(a.profileId);
            selected.entriesHash = factory.profileEntriesHash(a.profileId);
            StreamPrimarySettlementRights.requireWallet(
                StreamPrimarySettlementRights.Context(
                    resolver, factory, factory.splitWalletRuntimeCodeHash()
                ),
                selected
            );
        } else {
            if (a.assignmentType != 2 || a.profileId != 0 || a.templateId == 0) {
                revert InvalidPlatformPrimaryTemplate();
            }
            _grammar(resolver, a.templateId);
            selected.templateId = a.templateId;
            (selected.profileId, selected.wallet, selected.entriesHash) =
                resolver.previewCollectionPrimaryProfile(a.templateId, collection, poster);
        }
        if (
            selected.profileId == 0 || selected.wallet == address(0) || selected.entriesHash == 0
                || declaration != StreamPlatformSaleTemplate.declaration(resolver, collection)
                || keccak256(abi.encode(a))
                    != keccak256(
                        abi.encode(
                            resolver.resolvePrimaryAssignment(
                                collection, token, keccak256("PRIMARY_SALE")
                            )
                        )
                    )
        ) revert InvalidPlatformPrimaryTemplate();
        witness = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_TOKEN_PRIMARY_WITNESS_V1"),
                block.chainid,
                address(resolver),
                collection,
                token,
                mode,
                declaration,
                poster,
                a,
                selected
            )
        );
    }

    function materialize(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness
    ) public {
        _same(resolver, collection, token, mode, poster, selected, witness);
        if (mode != 13 || selected.templateId == 0) revert InvalidPlatformPrimaryTemplate();
        (bytes32 profile, address wallet, bytes32 entries) = resolver.materializeCollectionPrimaryProfile(
            selected.templateId, collection, poster, false
        );
        if (
            profile != selected.profileId || wallet != selected.wallet
                || entries != selected.entriesHash
        ) revert InvalidPlatformPrimaryTemplate();
        _same(resolver, collection, token, mode, poster, selected, witness);
    }

    function _same(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness
    ) private view {
        (StreamSaleTemplate.Selection memory current, bytes32 actual) =
            resolve(resolver, collection, token, mode, poster);
        if (actual != witness || keccak256(abi.encode(current)) != keccak256(abi.encode(selected))) revert InvalidPlatformPrimaryTemplate();
    }

    function _grammar(IStreamRevenueResolver resolver, bytes32 templateId) private view {
        (bool exists, bytes32 hash,) = resolver.primaryTemplate(templateId);
        uint256 count = resolver.primaryTemplateEntryCount(templateId);
        if (!exists || count == 0 || count > 64) revert InvalidPlatformPrimaryTemplate();
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](count);
        uint256 total;
        for (uint256 i; i < count; ++i) {
            (address account, bytes32 source, uint32 share, bytes32 label) =
                resolver.primaryTemplateEntry(templateId, i);
            // No implied Artist or paid-collaborator identity in this artist-less family.
            if (
                share == 0 || label == keccak256("artist")
                    || (source == 0
                            ? account == address(0)
                            : (source != keccak256("SALE_POSTER") || account != address(0)))
            ) {
                revert InvalidPlatformPrimaryTemplate();
            }
            entries[i] = IStreamRevenueResolver.PrimaryTemplateEntry(account, source, share, label);
            total += share;
        }
        if (total != 1000000 || hash != keccak256(abi.encode(entries))) {
            revert InvalidPlatformPrimaryTemplate();
        }
    }
}
