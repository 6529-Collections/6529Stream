// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Aggregate
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredIdentityHydrationRecords as Records
} from "./StreamArtistRecoveredIdentityHydrationRecords.sol";
import {
    StreamArtistRecoveredDelegationHydration as Delegations
} from "./StreamArtistRecoveredDelegationHydration.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

import {
    StreamArtistRecoveredMultipleIdentityValidation as Validation
} from "./StreamArtistRecoveredMultipleIdentityValidation.sol";
import {
    StreamArtistRecoveredMultipleIdentityCodec as Codec
} from "./StreamArtistRecoveredMultipleIdentityCodec.sol";
import {
    StreamArtistRecoveredIdentitySourceReads as Reads
} from "./StreamArtistRecoveredIdentitySourceReads.sol";
import {
    StreamArtistRecoveredIdentitySourceAuxiliary as Auxiliary
} from "./StreamArtistRecoveredIdentitySourceAuxiliary.sol";
import {
    StreamArtistRecoveredIdentitySourceTuple as Tuple
} from "./StreamArtistRecoveredIdentitySourceTuple.sol";

/// @notice Exact Identity transport with unchanged complete source checks and canonical codecs.
/// @dev Each fixed worker owns one original validation phase. No caller chooses a target or method.
library StreamArtistRecoveredMultipleIdentitySource {
    /// @notice Every original preparation alias must resolve to one selected authentic principal.
    function preparationOwners(address source, M.State memory scopes, RH.OwnerProvenance memory p)
        public
        view
    {
        for (uint256 i; i < p.aliases.length; ++i) {
            if (p.aliases[i].surface != keccak256("identity_authority.replay.recovery_preparation"))
            {
                continue;
            }
            Aggregate.artist(
                scopes, Raw(source).recoveredIdentityHydrationActionArtist(p.aliases[i].scope)
            );
        }
    }

    function collect(address source, AH.Query memory query, RH.OwnerProvenance memory provenance)
        public
        view
        returns (IH.Bundle memory bundle)
    {
        Provenance.validateOwnerSource(provenance, 2, source);
        uint256 last = provenance.eras.length - 1;
        if (
            query.artistId == 0 || provenance.origins[last].owners[2] != source
                || source.codehash != provenance.origins[last].ownerCodeHashes[2]
        ) {
            revert IH.InvalidRecoveredIdentity(query.artistId);
        }
        (bool ok, bytes memory raw) = source.staticcall(
            abi.encodeWithSelector(Raw.recoveredIdentityHydrationRaw.selector, query, provenance)
        );
        raw = Tuple.result(ok, raw);
        raw = Codec.transport(raw);
        if (
            address(Reads).code.length == 0 || address(Records).code.length == 0
                || address(Auxiliary).code.length == 0
        ) assembly ("memory-safe") { revert(0, 0) }
        _readChecks(source, query, raw);
        bytes memory checked;
        (ok, checked) = address(Validation)
            .staticcall(
                bytes.concat(Validation.validate.selector, Tuple.two(raw, abi.encode(provenance)))
            );
        abi.decode(Tuple.result(ok, checked), (bytes32));
        (ok, checked) = address(Auxiliary)
            .staticcall(
                bytes.concat(
                    Auxiliary.validate.selector,
                    Tuple.wordAndTwo(source, raw, abi.encode(provenance))
                )
            );
        Tuple.result(ok, checked);
        _return(raw);
    }

    function _readChecks(address source, AH.Query memory query, bytes memory raw) private view {
        (bool ok, bytes memory result) = address(Reads)
            .staticcall(
                bytes.concat(
                    Reads.validate.selector, Tuple.wordAndTwo(source, raw, abi.encode(query))
                )
            );
        Tuple.result(ok, result);
        (ok, result) = address(Records)
            .staticcall(bytes.concat(Records.validate.selector, Tuple.wordAndOne(source, raw)));
        Tuple.result(ok, result);
    }

    function _return(bytes memory encoded) private pure {
        assembly ("memory-safe") { return(add(encoded, 0x20), mload(encoded)) }
    }
}
