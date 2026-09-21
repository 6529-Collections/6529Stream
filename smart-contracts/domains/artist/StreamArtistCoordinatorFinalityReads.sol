// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCurrentFinalityRoute } from "./StreamArtistCurrentFinalityRoute.sol";
import { StreamArtistSanctionCandidate } from "./StreamArtistSanctionCandidate.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as CurrentAuthority
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed coordinator read helpers; admission, operation locking and mutation remain in the host.
library StreamArtistCoordinatorFinalityReads {
    function finalityReadGas(T.SuiteConfiguration storage suite) public view returns (uint256 cap) {
        uint8 failure;
        uint64 revision;
        (cap,, failure, revision) = IStreamGasParameterHost(suite.registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"));
        if (cap == 0 || failure != 2 || revision == 0) revert T.InvalidBinding();
    }

    function currentFinalityRoute(
        T.SuiteConfiguration storage suite,
        uint256 chainId,
        uint256 collectionId
    ) public view returns (CurrentAuthority.Route memory route) {
        bool supported;
        (supported, route) = StreamArtistCurrentFinalityRoute.resolve(
            suite, chainId, collectionId, finalityReadGas(suite)
        );
        if (!supported) revert CurrentAuthority.InvalidCurrentAuthority();
    }

    function sanctionPins(
        T.SuiteConfiguration storage suite,
        uint256 chainId,
        uint256 collectionId,
        address finalityRegistry,
        bytes32 finalityRegistryCodeHash,
        address finalityEvidenceProvider,
        bytes32 finalityEvidenceProviderCodeHash
    ) public view returns (StreamArtistSanctionCandidate.Pins memory) {
        uint256 cap = finalityReadGas(suite);
        (bool supported, CurrentAuthority.Route memory route) =
            StreamArtistCurrentFinalityRoute.resolve(suite, chainId, collectionId, cap);
        if (supported) {
            return StreamArtistSanctionCandidate.Pins(
                route.finalityRegistry,
                route.finalityCodeHash,
                route.provider,
                route.providerCodeHash,
                cap
            );
        }
        return StreamArtistSanctionCandidate.Pins(
            finalityRegistry,
            finalityRegistryCodeHash,
            finalityEvidenceProvider,
            finalityEvidenceProviderCodeHash,
            cap
        );
    }

    /// @notice Exact ABI return bytes for the existing external Coordinator route read.
    function currentFinalityRouteEncoded(
        T.SuiteConfiguration storage suite,
        uint256 chainId,
        uint256 collectionId
    ) public view returns (bytes memory) {
        return abi.encode(currentFinalityRoute(suite, chainId, collectionId));
    }
}
