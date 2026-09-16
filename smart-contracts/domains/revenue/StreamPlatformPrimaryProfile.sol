// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrimarySettlementRights.sol";
import "../mint/StreamPlatformSaleTemplate.sol";

/// @notice Verified collection/default fixed profiles under current declared platform authority.
library StreamPlatformPrimaryProfile {
    error InvalidPlatformPrimaryProfile();

    function resolve(
        IStreamRevenueResolver resolver,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 witness) {
        if ((mode != 10 && mode != 11) || collection == 0 || poster == address(0)) {
            revert InvalidPlatformPrimaryProfile();
        }
        bytes32 declaration = StreamPlatformSaleTemplate.declaration(resolver, collection);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.assignmentType != 1 || a.profileId == 0 || a.templateId != 0
                || a.assignmentHash == 0 || a.policyHash != 0 || a.scope != (mode == 10 ? 1 : 0)
                || a.scopeId != (mode == 10 ? collection : 0)
        ) revert InvalidPlatformPrimaryProfile();
        if (
            token != 0
                && keccak256(abi.encode(a))
                    != keccak256(
                        abi.encode(
                            resolver.resolvePrimaryAssignment(
                                collection, 0, keccak256("PRIMARY_SALE")
                            )
                        )
                    )
        ) revert InvalidPlatformPrimaryProfile();
        IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
        selected = StreamSaleTemplate.Selection(
            a.profileId,
            factory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            factory.profileEntriesHash(a.profileId)
        );
        StreamPrimarySettlementRights.requireWallet(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            selected
        );
        if (
            selected.wallet == address(0) || selected.entriesHash == 0
                || StreamPlatformSaleTemplate.declaration(resolver, collection) != declaration
                || keccak256(abi.encode(a))
                    != keccak256(
                        abi.encode(
                            resolver.resolvePrimaryAssignment(
                                collection, token, keccak256("PRIMARY_SALE")
                            )
                        )
                    )
        ) revert InvalidPlatformPrimaryProfile();
        witness = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_PRIMARY_PROFILE_WITNESS_V1"),
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
}
