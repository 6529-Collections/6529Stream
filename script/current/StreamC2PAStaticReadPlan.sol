// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFullV1C2PAProducts.sol";
import {
    IStreamStaticC2PAAttribution
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticC2PAAttribution.sol";
import {
    IStreamC2PAReconciliation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamArtistC2PAReads
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamStaticArtistSource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticArtistSource.sol";
import {
    IStreamArtistStaticFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistStaticFacts.sol";
import {
    IStreamArtistBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamCorePointers
} from "../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamStaticMetadataRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamCollectionMetadataV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @notice Exact observed C2PA serving edges plus the fixed-owner historical head audit read.
/// @dev This semantic inventory is deliberately not a RendererRegistry target-role cast.
/// Root owns profile admission, live-provenance/current-full qualification and STATIC analysis.
library StreamC2PAStaticReadPlan {
    uint8 internal constant SERVING = 1;
    uint8 internal constant AUDIT = 2;

    struct Read {
        address target;
        bytes32 runtimeHash;
        bytes32 semanticRole;
        bytes4 selector;
        uint32 maximumReturnBytes;
        bool exact;
        uint8 use;
    }

    struct Inventory {
        uint256 chainId;
        bytes32 constructionHash;
        bytes32 originalAttributionInventoryHash;
        Read[] reads;
    }

    /// @dev Complete incremental serving call graph at this source, including self STATICCALL
    /// and both fixed Artist owner routes; unchanged AA/Renderer graphs remain supplied evidence.
    /// Historical c2paCredentialRecord is an explicit audit dependency, not a serving call.
    function delta(
        StreamFullV1C2PAProducts.Configuration memory c,
        StreamFullV1C2PAProducts.Products memory p
    ) internal view returns (Read[] memory rows) {
        StreamFullV1C2PAProducts.validate(c, p);
        rows = new Read[](15);
        rows[0] = _row(
            address(p.wrapper),
            "STATIC_C2PA_ATTRIBUTION",
            IStreamStaticC2PAAttribution.attributionWithC2PA.selector,
            33056,
            false,
            SERVING
        );
        rows[1] = _row(
            address(p.original),
            "METADATA_COMPANION",
            p.original.attribution.selector,
            32832,
            false,
            SERVING
        );
        rows[2] = _row(
            address(p.reconciliation),
            "C2PA_RECONCILIATION",
            IStreamC2PAReconciliation.display.selector,
            192,
            true,
            SERVING
        );
        rows[3] = _row(
            address(p.reconciliation),
            "C2PA_RECONCILIATION",
            p.reconciliation.requireCurrent.selector,
            0,
            true,
            SERVING
        );
        rows[4] = _row(
            c.base.core,
            "CORE",
            IStreamCorePointers.getSatellitePointer.selector,
            320,
            true,
            SERVING
        );
        rows[5] = _row(
            c.base.metadata,
            "COLLECTION_METADATA",
            IStreamCollectionMetadataV1.latestCollectionRecordHashFor.selector,
            32,
            true,
            SERVING
        );
        rows[6] = _row(
            c.base.router,
            "METADATA_COMPANION",
            IStreamStaticMetadataRouter.staticRenderSource.selector,
            32768,
            false,
            SERVING
        );
        rows[7] = _row(
            c.base.artist,
            "ARTIST_REGISTRY",
            IStreamStaticArtistSource.staticDisplayRead.selector,
            704,
            false,
            SERVING
        );
        rows[8] = _row(
            p.artistStaticDisplay,
            "ARTIST_STATIC_DISPLAY",
            StreamArtistStaticDisplay.read.selector,
            704,
            false,
            SERVING
        );
        rows[9] = _row(
            p.artistTargets[0],
            "ARTIST_COORDINATOR",
            IStreamArtistSuiteReads.suiteConfiguration.selector,
            544,
            true,
            SERVING
        );
        rows[10] = _row(
            p.artistTargets[1],
            "ARTIST_IDENTITY_OWNER",
            IStreamArtistStaticFacts.staticIdentityMetadata.selector,
            352,
            false,
            SERVING
        );
        rows[11] = _row(
            p.artistTargets[2],
            "ARTIST_BINDING_OWNER",
            IStreamArtistBindingOwner.binding.selector,
            320,
            true,
            SERVING
        );
        rows[12] = _row(
            p.artistTargets[3],
            "ARTIST_ATTRIBUTION_OWNER",
            IStreamArtistC2PAReads.c2paCredentialHead.selector,
            320,
            true,
            SERVING
        );
        rows[13] = _row(
            p.artistTargets[3],
            "ARTIST_ATTRIBUTION_OWNER",
            IStreamArtistC2PAReads.c2paCredentialRecord.selector,
            320,
            true,
            AUDIT
        );
        // Raw ABI string envelope, not just the maximum string payload. The new Prepared
        // tuple's selector comes from this source's Encoding type, never a copied old selector.
        rows[14] = _row(
            p.encoding,
            "METADATA_COMPANION",
            StreamStaticRenderEncoding.render.selector,
            16777280,
            false,
            SERVING
        );
        _sort(rows);
    }

    /// @notice Union with the retained original attribution roster without dropping any row.
    /// @dev savedOriginalHash authenticates retained caller input only. A reviewed complete
    /// original AA closure, the remaining Renderer closure and analysis are external obligations.
    function compose(
        StreamFullV1C2PAProducts.Configuration memory c,
        StreamFullV1C2PAProducts.Products memory p,
        Read[] memory originalAttribution,
        bytes32 savedOriginalHash
    ) internal view returns (Inventory memory inventory) {
        require(
            savedOriginalHash != 0
                && savedOriginalHash == keccak256(abi.encode(originalAttribution)),
            "retained original attribution roster"
        );
        _validateRows(originalAttribution);
        Read[] memory added = delta(c, p);
        bool originalRoot;
        for (uint256 i; i < originalAttribution.length; ++i) {
            if (
                originalAttribution[i].target == address(p.original)
                    && originalAttribution[i].selector == p.original.attribution.selector
                    && originalAttribution[i].use == SERVING
            ) originalRoot = true;
        }
        require(originalRoot, "original attribution root retained");
        Read[] memory work = new Read[](originalAttribution.length + added.length);
        uint256 n;
        for (uint256 i; i < originalAttribution.length; ++i) {
            work[n++] = originalAttribution[i];
        }
        for (uint256 i; i < added.length; ++i) {
            bool found;
            for (uint256 j; j < n; ++j) {
                if (_key(work[j]) != _key(added[i])) continue;
                require(
                    keccak256(abi.encode(work[j])) == keccak256(abi.encode(added[i])),
                    "conflicting original read edge"
                );
                found = true;
                break;
            }
            if (!found) work[n++] = added[i];
        }
        Read[] memory combined = new Read[](n);
        for (uint256 i; i < n; ++i) {
            combined[i] = work[i];
        }
        _sort(combined);
        _validateRows(combined);
        inventory =
            Inventory(block.chainid, keccak256(abi.encode(c, p)), savedOriginalHash, combined);
    }

    function inventoryHash(Inventory memory inventory) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(keccak256("6529STREAM_C2PA_STATIC_SOURCE_INVENTORY_V1"), inventory)
            );
    }

    function requireUnchanged(
        StreamFullV1C2PAProducts.Configuration memory c,
        StreamFullV1C2PAProducts.Products memory p,
        Inventory memory inventory,
        bytes32 savedHash
    ) internal view {
        StreamFullV1C2PAProducts.validate(c, p);
        require(
            savedHash != 0 && inventoryHash(inventory) == savedHash
                && inventory.chainId == block.chainid
                && inventory.constructionHash == keccak256(abi.encode(c, p))
                && inventory.originalAttributionInventoryHash != 0,
            "retained source inventory"
        );
        _validateRows(inventory.reads);
        Read[] memory required = delta(c, p);
        for (uint256 i; i < required.length; ++i) {
            bool found;
            for (uint256 j; j < inventory.reads.length; ++j) {
                if (_key(required[i]) == _key(inventory.reads[j])) {
                    require(
                        keccak256(abi.encode(required[i]))
                            == keccak256(abi.encode(inventory.reads[j])),
                        "original C2PA read bounds"
                    );
                    found = true;
                    break;
                }
            }
            require(found, "missing exact C2PA source edge");
        }
    }

    function _row(
        address target,
        string memory role,
        bytes4 selector,
        uint32 maximum,
        bool exact,
        uint8 use
    ) private view returns (Read memory) {
        return Read(target, target.codehash, keccak256(bytes(role)), selector, maximum, exact, use);
    }

    function _validateRows(Read[] memory rows) private view {
        require(rows.length != 0, "nonempty source roster");
        for (uint256 i; i < rows.length; ++i) {
            Read memory row = rows[i];
            require(
                row.target.code.length != 0 && row.target.codehash == row.runtimeHash
                    && row.semanticRole != 0 && row.selector != 0
                    && (row.use == SERVING || row.use == AUDIT)
                    && (i == 0 || _key(rows[i - 1]) < _key(row)),
                "sorted live source rows"
            );
            for (uint256 j; j < i; ++j) {
                if (rows[j].target == row.target) {
                    require(
                        rows[j].semanticRole == row.semanticRole, "one semantic target identity"
                    );
                }
            }
        }
    }

    function _sort(Read[] memory rows) private pure {
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    function _key(Read memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.target, row.selector, row.use));
    }
}
