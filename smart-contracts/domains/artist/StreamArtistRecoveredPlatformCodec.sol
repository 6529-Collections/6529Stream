// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformValidation as Validation
} from "./StreamArtistRecoveredPlatformValidation.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

library StreamArtistRecoveredPlatformCodec {
    function encode(P.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        internal
        view
        returns (bytes memory raw)
    {
        raw = Parts.encode(b);
        Validation.validateEncoded(raw, q, p);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        internal
        view
        returns (P.Bundle memory b)
    {
        Validation.validateEncoded(raw, q, p);
        b = Parts.decode(raw);
    }
}
