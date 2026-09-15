// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingCoordinator.sol";

/// @notice Fixed original digest composition, with the facade address retained in every signing domain.
library StreamArtistRegistryDigestEncoding {
    function digest(address host, address coordinator, bytes calldata data, uint8 kind)
        public
        view
        returns (bytes32)
    {
        if (kind == 1) {
            (uint256 collectionId, T.Authorization memory a) =
                abi.decode(data[4:], (uint256, T.Authorization));
            T.SuiteConfiguration memory s =
                StreamArtistOnboardingCoordinator(coordinator).suiteConfiguration();
            return StreamArtistHashes.acceptanceDigest(
                StreamArtistHashes.Environment(block.chainid, host, s.core, s.mintManager),
                collectionId,
                IStreamArtistBindingOwner(s.owners[0]).binding(collectionId),
                a
            );
        }
        T.SuiteConfiguration memory suite =
            StreamArtistOnboardingCoordinator(coordinator).suiteConfiguration();
        StreamArtistHashes.Environment memory e = StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(coordinator).deploymentChainId(),
            host,
            suite.core,
            suite.mintManager
        );
        if (kind == 2) {
            (R.GuardianSet memory p, T.Authorization memory a) =
                abi.decode(data[4:], (R.GuardianSet, T.Authorization));
            return StreamArtistRotationHashes.guardianDigest(e, p, a);
        }
        if (kind == 3) {
            (T.Attestation memory p, T.Authorization memory a) =
                abi.decode(data[4:], (T.Attestation, T.Authorization));
            return StreamArtistHashes.attestationDigest(e, p, a);
        }
        revert T.UnsupportedProfile();
    }
}
