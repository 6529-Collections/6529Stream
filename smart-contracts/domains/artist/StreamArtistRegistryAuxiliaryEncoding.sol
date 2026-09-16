// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";

/// @notice Original observational facade getters; caller-independent fixed suite reads.
library StreamArtistRegistryAuxiliaryEncoding {
    function read(address coordinator, bytes calldata data) public view returns (bytes memory) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(coordinator).suiteConfiguration();
        bytes4 selector = bytes4(data[:4]);
        bytes32 record = abi.decode(data[4:], (bytes32));
        if (selector == bytes4(keccak256("saleConsentRecord(bytes32)"))) {
            return abi.encode(IStreamArtistSaleConsentOwner(s.owners[6]).saleConsentRecord(record));
        }
        if (selector == bytes4(keccak256("attestationAssociation(bytes32)"))) {
            return abi.encode(
                IStreamArtistAuthenticatedAttestationOwner(s.owners[4])
                    .attestationAssociation(record)
            );
        }
        if (selector == bytes4(keccak256("recordDelegation(bytes32)"))) {
            bytes32 grant = IStreamArtistDelegatedConsentOwner(s.owners[6]).recordDelegation(record);
            return abi.encode(
                grant != 0
                    ? grant
                    : IStreamArtistAuthenticatedAttestationOwner(s.owners[4])
                    .attestationAssociation(record)
                    .delegation
            );
        }
        revert T.InvalidRecord();
    }
}
