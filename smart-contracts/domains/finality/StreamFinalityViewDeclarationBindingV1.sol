// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as D
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    StreamMetadataRecoveryRoutes as Routes
} from "../metadata/StreamMetadataRecoveryRoutes.sol";
import {
    IStreamCollectionViews as Views
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";

import { StreamViewAdoptionReads as OriginalRead } from "../metadata/StreamViewAdoptionReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Original declaration sources only. Never calls a snapshot, adoption, or finality reader.
/// @dev The original adoption reader calls the provider back, so this leaf cannot validate the
/// preservation snapshot's current source. Binding the roster grants no publication authority.
library StreamFinalityViewDeclarationBindingV1 {
    function validate(
        Native.Config memory original,
        V.Capability memory capability,
        D.Binding memory d
    ) public view {
        if (
            original.chainId != block.chainid
                || capability.originalHash != keccak256(abi.encode(original))
                || d.membership != original.targets[3]
                || d.membershipCodeHash != original.codeHashes[3] || d.readGas < 50000
                || d.readGas > 16777216 || d.sourceGas < d.readGas
        ) revert V.InvalidViewPreservationBinding();
        uint256[6] memory indexes = [uint256(0), 1, 2, 3, 4, 5];
        for (uint256 i; i < indexes.length; ++i) {
            _pin(original.targets[indexes[i]], original.codeHashes[indexes[i]]);
        }
        _pin(d.views, d.viewsCodeHash);
        _pin(capability.authority, capability.authorityCodeHash);
        // COLLECTION_VIEWS is selected by this original binding, not a Core pointer.
        (address modules,) = OriginalRead.selected(
            original.targets[0], keccak256("MODULE_REGISTRY"), original.readGas
        );
        OriginalRead.eligible(
            modules,
            d.views,
            keccak256("COLLECTION_VIEWS"),
            type(Views).interfaceId,
            original.readGas
        );
        if (
            abi.decode(
                    Reads.read(
                        d.views,
                        abi.encodeCall(IERC165.supportsInterface, (type(Views).interfaceId)),
                        32,
                        original.readGas
                    ),
                    (uint256)
                ) != 1
        ) revert V.InvalidViewPreservationBinding();
        Routes.requireCurrentHost(
            original.targets[0],
            keccak256("COLLECTION_METADATA"),
            original.targets[1],
            keccak256("COLLECTION_METADATA"),
            type(Metadata).interfaceId
        );
        Routes.requireCurrentHost(
            original.targets[0],
            keccak256("METADATA_ROUTER"),
            original.targets[2],
            keccak256("METADATA_ROUTER"),
            type(Router).interfaceId
        );
        _address(d.views, "core()", original.targets[0], d.readGas);
        _address(d.views, "metadataHost()", original.targets[1], d.readGas);
        _address(d.views, "schemaRegistry()", original.targets[4], d.readGas);
        _address(d.views, "chunkStore()", original.targets[5], d.readGas);
        _address(d.views, "governanceAuthority()", capability.authority, d.readGas);
        _address(d.membership, "core()", original.targets[0], d.readGas);
        _address(d.membership, "metadataHost()", original.targets[1], d.readGas);
        _address(d.membership, "schemaRegistry()", original.targets[4], d.readGas);
        _address(d.membership, "chunkStore()", original.targets[5], d.readGas);
        _address(d.membership, "governanceAuthority()", capability.authority, d.readGas);
        _address(original.targets[1], "core()", original.targets[0], d.readGas);
        _address(original.targets[1], "schemaRegistry()", original.targets[4], d.readGas);
        _address(original.targets[1], "chunkStore()", original.targets[5], d.readGas);
        _address(original.targets[1], "governanceAuthority()", capability.authority, d.readGas);
        _address(original.targets[2], "core()", original.targets[0], d.readGas);
        _address(original.targets[2], "governanceAuthority()", capability.authority, d.readGas);
        _address(original.targets[4], "chunkStore()", original.targets[5], d.readGas);
        _address(original.targets[4], "governanceAuthority()", capability.authority, d.readGas);
        if (
            _word(original.targets[1], "executorCodeHash()", d.readGas)
                    != capability.authorityCodeHash
                || _word(original.targets[1], "coreCodeHash()", d.readGas) != original.codeHashes[0]
                || _word(original.targets[1], "schemaRegistryCodeHash()", d.readGas)
                    != original.codeHashes[4]
                || _word(original.targets[1], "chunkStoreCodeHash()", d.readGas)
                    != original.codeHashes[5]
        ) revert V.InvalidViewPreservationBinding();
    }

    /// @dev Original consumers independently recheck selected routes, eligibility and reciprocities.
    /// No external calls here: current adoption may call this getter under its scalar read cap.
    function pins(Native.Config memory original, V.Capability memory capability, D.Binding memory d)
        public
        view
    {
        if (
            original.chainId != block.chainid || d.membership != original.targets[3]
                || d.membershipCodeHash != original.codeHashes[3]
        ) revert V.InvalidViewPreservationBinding();
        uint256[6] memory indexes = [uint256(0), 1, 2, 3, 4, 5];
        for (uint256 i; i < indexes.length; ++i) {
            _pin(original.targets[indexes[i]], original.codeHashes[indexes[i]]);
        }
        _pin(d.views, d.viewsCodeHash);
        _pin(capability.authority, capability.authorityCodeHash);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert V.ViewPreservationBindingDependency(target);
        }
    }

    function _address(address target, string memory selector, address expected, uint256 cap)
        private
        view
    {
        if (_word(target, selector, cap) != bytes32(uint256(uint160(expected)))) {
            revert V.InvalidViewPreservationBinding();
        }
    }

    function _word(address target, string memory selector, uint256 cap)
        private
        view
        returns (bytes32)
    {
        return abi.decode(Reads.read(target, abi.encodeWithSignature(selector), 32, cap), (bytes32));
    }
}
