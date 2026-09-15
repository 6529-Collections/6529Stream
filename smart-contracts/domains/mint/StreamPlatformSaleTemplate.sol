// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamSaleTemplate.sol";
import "../revenue/StreamRoyaltyPlatformAdmission.sol";

/// @notice Artist-less static/SALE_POSTER templates under actual current PLATFORM_WORKS authority.
/// @dev Old Artist template capabilities are never retried through this explicit family.
library StreamPlatformSaleTemplate {
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    error InvalidPlatformPrimaryTemplate();

    function declaration(IStreamRevenueResolver resolver, uint256 collection)
        public
        view
        returns (bytes32 hash)
    {
        if (!StreamRoyaltyPlatformAdmission.requireCurrent(
                resolver.core(),
                IStreamArtistAttribution(resolver.artistRegistry()),
                resolver.artistRegistryCodeHash(),
                collection
            )) revert InvalidPlatformPrimaryTemplate();
        (, hash,) = IStreamArtistPlatformWorks(resolver.artistRegistry())
            .platformWorksDeclaration(collection);
    }

    function resolve(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 witness) {
        if ((mode != 8 && mode != 9) || collection == 0 || poster == address(0)) {
            revert InvalidPlatformPrimaryTemplate();
        }
        bytes32 originalDeclaration = declaration(resolver, collection);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collection, token, CLASS);
        if (
            !a.exists || a.assignmentType != 2 || a.profileId != 0 || a.templateId == 0
                || a.assignmentHash == 0 || a.policyHash != 0 || a.scope != (mode == 8 ? 1 : 0)
                || a.scopeId != (mode == 8 ? collection : 0)
        ) {
            revert InvalidPlatformPrimaryTemplate();
        }
        // Exact actual-token precedence, never skip a token override to recover a source family.
        if (
            token != 0
                && keccak256(abi.encode(a))
                    != keccak256(
                        abi.encode(resolver.resolvePrimaryAssignment(collection, 0, CLASS))
                    )
        ) revert InvalidPlatformPrimaryTemplate();
        _grammar(resolver, a.templateId);
        selected.templateId = a.templateId;
        selected.assignmentHash = a.assignmentHash;
        (selected.profileId, selected.wallet, selected.entriesHash) =
            resolver.previewCollectionPrimaryProfile(a.templateId, collection, poster);
        if (
            selected.profileId == 0 || selected.wallet == address(0) || selected.entriesHash == 0
                || declaration(resolver, collection) != originalDeclaration
                || keccak256(abi.encode(a))
                    != keccak256(
                        abi.encode(resolver.resolvePrimaryAssignment(collection, token, CLASS))
                    )
        ) revert InvalidPlatformPrimaryTemplate();
        witness = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_PRIMARY_TEMPLATE_WITNESS_V1"),
                block.chainid,
                address(resolver),
                collection,
                token,
                mode,
                originalDeclaration,
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
        (bytes32 profile, address wallet, bytes32 entries) = resolver.materializeCollectionPrimaryProfile(
            selected.templateId, collection, poster, false
        );
        if (
            profile != selected.profileId || wallet != selected.wallet
                || entries != selected.entriesHash
        ) {
            revert InvalidPlatformPrimaryTemplate();
        }
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
        if (actual != witness || keccak256(abi.encode(current)) != keccak256(abi.encode(selected)))
        {
            revert InvalidPlatformPrimaryTemplate();
        }
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
