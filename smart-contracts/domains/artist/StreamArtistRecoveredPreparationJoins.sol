// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredDelegationConsentFacts as DelegationFacts
} from "./StreamArtistRecoveredDelegationConsentFacts.sol";
import {
    StreamArtistRecoveredAttestationFacts as AttestationFacts
} from "./StreamArtistRecoveredAttestationFacts.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Fixed original cross-owner validators consuming complete canonical source bundles.
/// @dev Solidity library selectors use nominal types. Constants below are verified against the
/// original compiler methodIdentifiers; no caller supplies a target or selector.
library StreamArtistRecoveredPreparationJoins {
    bytes4 private constant CONTENT = bytes4(
        keccak256(
            "validate(StreamArtistRecoveredIdentityHydrationTypes.Bundle,StreamArtistRecoveredContentConsentHydration.Bundle,StreamArtistAuthorityHydrationTypes.Query,StreamArtistRecoveredHydrationTypes.Provenance,uint8,StreamArtistPublicationHydrationTypes.Row[])"
        )
    );
    bytes4 private constant DELEGATED = bytes4(
        keccak256(
            "validate(StreamArtistRecoveredIdentityHydrationTypes.Bundle,StreamArtistRecoveredDelegatedConsentHydration.Bundle,StreamArtistAuthorityHydrationTypes.Query,StreamArtistRecoveredHydrationTypes.Provenance,uint8)"
        )
    );
    bytes4 private constant DELEGATED_ATTESTATIONS = bytes4(
        keccak256(
            "validate(StreamArtistRecoveredIdentityHydrationTypes.Bundle,StreamArtistRecoveredDelegatedConsentHydration.Bundle,StreamArtistAuthorityHydrationTypes.Query,StreamArtistRecoveredHydrationTypes.Provenance,uint8,StreamArtistPublicationHydrationTypes.Row[])"
        )
    );

    function content(
        bytes memory rawIdentity,
        bytes memory rawConsent,
        AH.Query memory query,
        RH.Provenance memory provenance,
        uint8 mode,
        bytes memory records
    ) public view {
        if (address(DelegationFacts).code.length == 0) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        (bool ok, bytes memory result) = address(DelegationFacts)
            .staticcall(
                bytes.concat(
                    CONTENT,
                    Tuple.fourModeAndRows(
                        rawIdentity,
                        rawConsent,
                        abi.encode(query),
                        abi.encode(provenance),
                        mode,
                        records
                    )
                )
            );
        Tuple.result(ok, result);
    }

    function delegated(
        bytes memory rawIdentity,
        bytes memory rawConsent,
        AH.Query memory query,
        RH.Provenance memory provenance,
        uint8 mode,
        bytes memory records,
        bool hasAttestations
    ) public view {
        if (address(DelegationFacts).code.length == 0) {
            assembly ("memory-safe") { revert(0, 0) }
        }
        bytes memory input = hasAttestations
            ? bytes.concat(
                DELEGATED_ATTESTATIONS,
                Tuple.fourModeAndRows(
                    rawIdentity,
                    rawConsent,
                    abi.encode(query),
                    abi.encode(provenance),
                    mode,
                    records
                )
            )
            : bytes.concat(
                DELEGATED,
                Tuple.fourAndMode(
                    rawIdentity, rawConsent, abi.encode(query), abi.encode(provenance), mode
                )
            );
        (bool ok, bytes memory result) = address(DelegationFacts).staticcall(input);
        Tuple.result(ok, result);
    }

    function attestations(
        bytes memory rawIdentity,
        bytes memory records,
        AH.Query memory query,
        RH.Provenance memory provenance
    ) public view {
        (bool ok, bytes memory result) = address(AttestationFacts)
            .staticcall(
                bytes.concat(
                    AttestationFacts.validate.selector,
                    Tuple.four(rawIdentity, records, abi.encode(query), abi.encode(provenance))
                )
            );
        // The original call returns the complete uses vector even though preparation does not
        // consume it in this branch. Retain its typed return validation.
        abi.decode(Tuple.result(ok, result), (uint256[]));
    }
}
