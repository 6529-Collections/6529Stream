// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistAuthorityHydrationTypes as AH } from "./IStreamArtistAuthorityHydration.sol";

interface IStreamArtistRecoveredHydration is IERC165 {
    function hydrateRecoveredArtistAuthority(RH.Request calldata request) external returns (bytes32);
}

interface IStreamArtistRecoveredHydrationCoordinator {
    function coordinateHydrateRecoveredArtistAuthority(address actor, RH.Request calldata request)
        external
        returns (bytes32);
}

/// @notice Fixed-owner semantic payload and immutable imported provenance prefix.
/// @dev Current replay preimages are verified witnesses, not inventoried by the old checkpoint.
/// The Coordinator assembles the actual native suffix and wraps the typed payload only after
/// validation. No getter changes a native journal or turns old-domain evidence into a new call.
interface IStreamArtistRecoveredHydrationOwner {
    function recoveredAuthorityHydrationCapability() external view returns (RH.Capability memory);
    /// @dev Returns this owner's tagged typed semantic payload, without a caller-authored header.
    function recoveredAuthorityHydrationState(
        AH.Query calldata query,
        RH.OwnerProvenance calldata local
    ) external view returns (bytes memory);
    function recoveredHydrationImportedPrefix()
        external
        view
        returns (
            RH.OwnerProvenance memory prefix,
            bytes32 importCommitment,
            uint64 importedAtRevision
        );
    /// @dev The actual current key's original mutation point. Copied cells use the saved origin;
    /// later local writes use producer instrumentation. Missing imported points never become local.
    function recoveredHydrationReplayPoint(bytes32 currentKey)
        external
        view
        returns (RH.Point memory);
    function recoveredHydrationOrigin(bytes32 environmentHash)
        external
        view
        returns (RH.OriginEnvironment memory);
    /// @dev Auxiliary original writes are keyed by their actual surface and key. Their source
    /// producer inventory proves existence; a zero point must never imply admission.
    function recoveredHydrationAuxiliaryPoint(bytes32 surface, bytes32 key)
        external
        view
        returns (RH.Point memory);
}

/// @notice Exact producer-admitted local revision parallel to the unmodified native receipt array.
/// @dev A host lacking this capability cannot be inferred complete from old receipt hashes alone.
interface IStreamArtistRecoveredNativeChronology {
    function artistNativeReceiptRevisionAt(uint256 index) external view returns (uint64);
}
