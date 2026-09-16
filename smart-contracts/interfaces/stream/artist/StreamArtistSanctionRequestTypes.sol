// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionTypes.sol";
import "../finality/StreamArtworkFinalityTypes.sol";

library StreamArtistSanctionRequestTypes {
    struct Request {
        StreamArtistSanctionTypes.Terms terms;
        StreamFinalityComponentExpectation[] nonSanctionComponents;
        StreamFinalityManifestRef manifest;
        string statement;
        string signingToolName;
        string signingToolVersion;
    }

    struct Prepared {
        StreamArtistSanctionTypes.Subject subject;
        bytes ceremony;
        bytes32 scopeInputsHash;
        bytes32 reviewFactsHash;
    }
}
