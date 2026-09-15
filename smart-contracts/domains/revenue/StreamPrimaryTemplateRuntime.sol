// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPrimaryResolverState as S } from "./StreamPrimaryResolverState.sol";
import {
    IStreamRevenueResolver as R
} from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamDynamicPrimaryTemplates as D
} from "../../interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import { IStreamSplitWallet } from "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import { IStreamSplitFactory } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamPrimaryTemplateRules } from "./StreamPrimaryTemplateRules.sol";
import {
    StreamDynamicPrimaryTemplateRules as DynamicRules
} from "./StreamDynamicPrimaryTemplateRules.sol";
import {
    StreamDynamicPrimaryBeneficiaries as DynamicBeneficiaries
} from "./StreamDynamicPrimaryBeneficiaries.sol";
import {
    StreamPrimaryTemplateMaterialization as Materialization
} from "./StreamPrimaryTemplateMaterialization.sol";

/// @notice Fixed registration and concrete template cache worker in the actual Resolver context.
/// @dev Host guards run before entry. Context contains only immutable pins; cap reads remain live.
library StreamPrimaryTemplateRuntime {
    struct Context {
        IStreamSplitFactory factory;
        address artist;
    }

    struct MaterializationContext {
        uint256 collectionId;
        address salePoster;
        bool deploy;
        bytes32 artistId;
        address payout;
        bytes32 designation;
        bytes32 beneficiaryHash;
        bool dynamicTemplate;
    }

    uint16 private constant SCHEMA_VERSION = 1;
    uint16 private constant TEMPLATE_VERSION = 1;
    bytes32 private constant _PRIMARY_TEMPLATE_DOMAIN = keccak256("6529STREAM_PRIMARY_TEMPLATE_V1");
    bytes32 private constant _MATERIALIZED_PROFILE_METADATA_DOMAIN =
        keccak256("6529STREAM_MATERIALIZED_PRIMARY_PROFILE_METADATA_V1");
    bytes32 private constant ACCOUNT_SOURCE_COLLECTION_ARTIST = keccak256("COLLECTION_ARTIST");
    bytes32 private constant ARTIST_BENEFICIARY_READ_GAS =
        keccak256("6529STREAM_GGP_ARTIST_BENEFICIARY_READ_GAS");
    event PrimaryTemplateCreated(
        bytes32 indexed templateId,
        bytes32 indexed entriesHash,
        bytes32 indexed metadataURIHash,
        uint16 schemaVersion,
        uint16 templateVersion
    );
    event PrimaryTemplateEntryRecorded(
        bytes32 indexed templateId,
        uint16 indexed index,
        address indexed account,
        bytes32 accountSource,
        uint32 sharePpm,
        bytes32 labelId
    );
    event PrimaryTemplateMaterialized(
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        address indexed wallet,
        bytes32 entriesHash,
        bytes32 metadataURIHash,
        address salePoster
    );
    event CollectionTemplateMaterialized(
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        uint256 indexed collectionId,
        uint16 schemaVersion,
        bytes32 artistId,
        address payoutAccount,
        bytes32 designationRecordHash,
        address wallet,
        bytes32 entriesHash,
        bool walletDeployed
    );
    event DynamicCollectionTemplateMaterialized(
        uint16 schemaVersion,
        bytes32 indexed templateId,
        bytes32 indexed profileId,
        uint256 indexed collectionId,
        bytes32 beneficiaryHash,
        address salePoster
    );

    function registerTemplate(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        R.PrimaryTemplateEntry[] calldata entries,
        bytes32 metadataURIHash,
        D.CollaboratorReference[] memory references,
        bool dynamicTemplate
    ) public returns (bytes32) {
        R.PrimaryTemplateEntry[] memory canonicalEntries;
        bytes32 entriesHash;
        if (dynamicTemplate) {
            (canonicalEntries, entriesHash) = DynamicRules.canonicalize(entries, references);
        } else {
            (canonicalEntries, entriesHash) = StreamPrimaryTemplateRules.canonicalize(entries);
        }
        return _registerTemplate(templates, canonicalEntries, entriesHash, metadataURIHash);
    }

    function isDynamic(S.PrimaryTemplate storage template) public view returns (bool) {
        return DynamicRules.isDynamic(template.entries);
    }

    function artistShare(S.PrimaryTemplate storage template, bytes32 templateId, uint32 minimum)
        public
        view
        returns (uint32)
    {
        return StreamPrimaryTemplateRules.artistShare(template.entries, templateId, minimum);
    }

    function _registerTemplate(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        R.PrimaryTemplateEntry[] memory canonicalEntries,
        bytes32 entriesHash,
        bytes32 metadataURIHash
    ) private returns (bytes32 templateId) {
        templateId = keccak256(
            abi.encode(
                _PRIMARY_TEMPLATE_DOMAIN,
                uint256(block.chainid),
                address(this),
                SCHEMA_VERSION,
                TEMPLATE_VERSION,
                entriesHash,
                metadataURIHash
            )
        );

        S.PrimaryTemplate storage template = templates[templateId];
        if (template.exists) {
            return templateId;
        }
        template.exists = true;
        template.entriesHash = entriesHash;
        template.metadataURIHash = metadataURIHash;
        for (uint256 i = 0; i < canonicalEntries.length; i++) {
            template.entries.push(canonicalEntries[i]);
        }

        emit PrimaryTemplateCreated(
            templateId, entriesHash, metadataURIHash, SCHEMA_VERSION, TEMPLATE_VERSION
        );
        for (uint256 i = 0; i < canonicalEntries.length; i++) {
            R.PrimaryTemplateEntry memory entry = canonicalEntries[i];
            emit PrimaryTemplateEntryRecorded(
                templateId,
                // Safe because MAX_TEMPLATE_ENTRIES is 64.
                // forge-lint: disable-next-line(unsafe-typecast)
                uint16(i),
                entry.account,
                entry.accountSource,
                entry.sharePpm,
                entry.labelId
            );
        }
    }

    function dynamicFacts(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        Context memory x,
        uint256 collectionId,
        bytes32 templateId
    )
        public
        view
        returns (
            bytes32 entriesHash,
            bytes32 metadataURIHash,
            uint32 artistSharePpm,
            bytes32 beneficiaryHash
        )
    {
        S.PrimaryTemplate storage t = templates[templateId];
        if (!t.exists) revert R.UnknownPrimaryTemplate(templateId);
        (artistSharePpm, beneficiaryHash,) = DynamicBeneficiaries.facts(
            t.entries,
            DynamicBeneficiaries.Context(
                x.artist,
                collectionId,
                IStreamGasParameterHost(address(this)).gasParameter(ARTIST_BENEFICIARY_READ_GAS)
            )
        );
        return (t.entriesHash, t.metadataURIHash, artistSharePpm, beneficiaryHash);
    }

    function materialize(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        Context memory x,
        bytes32 templateId,
        MaterializationContext memory context
    )
        public
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash)
    {
        IStreamSplitWallet.SplitEntry[] memory concreteEntries;
        bytes32 metadataURIHash;
        (concreteEntries, entriesHash, metadataURIHash) =
            _concreteProfile(templates, x, templateId, context);
        (profileId, wallet) = x.factory.registerProfile(concreteEntries, metadataURIHash);
        // Even the deferred path must not produce a usable receipt for an occupied wrong-code address.
        if (wallet.code.length != 0 && !x.factory.splitWalletExists(profileId)) {
            revert R.UnverifiedSplitProfile(profileId);
        }
        if (context.deploy) wallet = x.factory.deployWallet(profileId);
        emit PrimaryTemplateMaterialized(
            templateId, profileId, wallet, entriesHash, metadataURIHash, context.salePoster
        );
        if (context.collectionId != 0) {
            _emitCollectionMaterialization(x, templateId, profileId, wallet, entriesHash, context);
        }
        if (context.beneficiaryHash != 0) {
            emit DynamicCollectionTemplateMaterialized(
                SCHEMA_VERSION,
                templateId,
                profileId,
                context.collectionId,
                context.beneficiaryHash,
                context.salePoster
            );
        }

        beneficiaryHash = context.beneficiaryHash;
    }

    function preview(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        Context memory x,
        bytes32 templateId,
        MaterializationContext memory context
    )
        public
        view
        returns (bytes32 profileId, address wallet, bytes32 entriesHash, bytes32 beneficiaryHash)
    {
        IStreamSplitWallet.SplitEntry[] memory entries;
        bytes32 metadata;
        (entries, entriesHash, metadata) = _concreteProfile(templates, x, templateId, context);
        profileId = x.factory.profileIdFor(entries, metadata);
        wallet = x.factory.walletFor(profileId);
        if (wallet.code.length != 0 && !x.factory.splitWalletExists(profileId)) {
            revert R.UnverifiedSplitProfile(profileId);
        }
        return (profileId, wallet, entriesHash, context.beneficiaryHash);
    }

    function _concreteProfile(
        mapping(bytes32 => S.PrimaryTemplate) storage templates,
        Context memory x,
        bytes32 templateId,
        MaterializationContext memory context
    )
        private
        view
        returns (
            IStreamSplitWallet.SplitEntry[] memory concreteEntries,
            bytes32 entriesHash,
            bytes32 metadataURIHash
        )
    {
        S.PrimaryTemplate storage t = templates[templateId];
        if (!t.exists) revert R.UnknownPrimaryTemplate(templateId);
        if (context.dynamicTemplate) {
            DynamicBeneficiaries.Witness memory w;
            (concreteEntries, context.beneficiaryHash, w) = DynamicBeneficiaries.concrete(
                t.entries,
                DynamicBeneficiaries.Context(
                    x.artist,
                    context.collectionId,
                    IStreamGasParameterHost(address(this)).gasParameter(ARTIST_BENEFICIARY_READ_GAS)
                ),
                context.salePoster
            );
            context.artistId = w.artistId;
            context.payout = w.payout;
            context.designation = w.designation;
            concreteEntries = Materialization.canonical(concreteEntries);
            entriesHash = keccak256(abi.encode(concreteEntries));
            metadataURIHash = keccak256(
                abi.encode(
                    _MATERIALIZED_PROFILE_METADATA_DOMAIN,
                    uint256(block.chainid),
                    address(this),
                    templateId,
                    entriesHash
                )
            );
        } else {
            uint256 cap;
            for (uint256 i; i < t.entries.length; ++i) {
                if (t.entries[i].accountSource == ACCOUNT_SOURCE_COLLECTION_ARTIST) {
                    if (context.collectionId == 0) revert R.MissingArtistMaterializationContext();
                    cap = IStreamGasParameterHost(address(this))
                        .gasParameter(ARTIST_BENEFICIARY_READ_GAS);
                    break;
                }
            }
            Materialization.Context memory c = Materialization.Context(
                x.artist,
                cap,
                context.collectionId,
                context.salePoster,
                bytes32(0),
                address(0),
                bytes32(0)
            );
            (concreteEntries, entriesHash, metadataURIHash, c) =
                Materialization.legacy(t.entries, templateId, c);
            context.artistId = c.artistId;
            context.payout = c.payout;
            context.designation = c.designation;
        }
    }

    function _emitCollectionMaterialization(
        Context memory x,
        bytes32 templateId,
        bytes32 profileId,
        address wallet,
        bytes32 entriesHash,
        MaterializationContext memory context
    ) private {
        emit CollectionTemplateMaterialized(
            templateId,
            profileId,
            context.collectionId,
            SCHEMA_VERSION,
            context.artistId,
            context.payout,
            context.designation,
            wallet,
            entriesHash,
            x.factory.splitWalletExists(profileId)
        );
    }
}
