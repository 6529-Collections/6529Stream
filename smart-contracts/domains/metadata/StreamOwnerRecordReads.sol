// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamOwnerRecords as O } from "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../../vendor/openzeppelin/IERC721.sol";

/// @notice Fixed custody and immutable-definition reads independent of operator locks and pointers.
library StreamOwnerRecordReads {
    function owner(address core, bytes32 codeHash, uint256 tokenId, uint256 cap)
        public
        view
        returns (address account)
    {
        requireCode(core, codeHash);
        bytes memory output = bounded(core, abi.encodeCall(IERC721.ownerOf, (tokenId)), 32, cap);
        if (output.length != 32) revert O.OwnerRecordReadFailed(core);
        account = abi.decode(output, (address));
        if (account == address(0)) revert O.OwnerRecordAuthorityRequired(account);
    }

    function definition(
        address registry,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        uint256 cap
    ) public view returns (bytes32) {
        bytes memory output = bounded(
            registry, abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)), 288, cap
        );
        if (output.length != 288) revert O.OwnerRecordReadFailed(registry);
        IStreamSchemaDocumentFacts.DocumentFacts memory d =
            abi.decode(output, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (!d.exists || d.kind != kind || d.contentHash == 0) {
            revert O.OwnerRecordDefinitionUnavailable(id);
        }
        return d.contentHash;
    }

    function requireCode(address target, bytes32 expected) internal view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert O.OwnerRecordDependencyChanged(target);
        }
    }

    function bounded(address target, bytes memory input, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        output = new bytes(maximum);
        uint256 available = gasleft();
        if (
            cap > type(uint256).max / 64 || available <= 10000
                || (available - 10000) / 64 * 63 < cap
        ) {
            revert O.OwnerRecordParentGas(available, cap);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert O.OwnerRecordReadFailed(target);
        assembly ("memory-safe") { mstore(output, size) }
    }
}
