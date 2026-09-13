// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtworkFinalityComponents.sol";

/// @notice A current route identity, without a claim about the component's frozen state.
struct StreamFinalityCurrentComponentRoute {
    bytes32 componentType;
    address component;
    bytes4 interfaceId;
    bytes32 codeHash;
}

/// @notice Optional fixed native artist/ONCHAIN discovery projection.
/// @dev Exactly nine independent families, or ten including ARTIST_SANCTION, sorted by family.
/// Current selection and complete membership are checked; the Registry MUST independently read
/// every component's full frozen state and preserve all seven expectation fields in its hashes.
interface IStreamFinalityCurrentComponentRoutes {
    function requireCurrentRoutes(StreamFinalityScope calldata scope, bool includeSanction)
        external
        view
        returns (StreamFinalityCurrentComponentRoute[] memory);
}

/// @notice Current complete original entropy identity without a second finalityState read.
/// @dev Additive capability: the original factory interface identifier remains unchanged.
interface IStreamFinalityCurrentEntropyRoute {
    function requireCurrentRoute(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityCurrentComponentRoute memory);
}
