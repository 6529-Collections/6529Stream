// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";

/// @notice Original observational facade getters; caller-independent fixed suite reads.
library StreamArtistRegistryAuxiliaryEncoding {
    function read(address coordinator, bytes calldata data) public view returns (bytes memory) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(coordinator).suiteConfiguration();
        bytes4 selector = bytes4(data[:4]);
        if (selector == bytes4(keccak256("collaboratorRegistrationNonceState(address,uint256)"))) {
            (address account, uint256 nonce) = abi.decode(data[4:], (address, uint256));
            (bool used, uint256 next) = IStreamArtistCollaboratorIdentityOwner(s.owners[2])
                .collaboratorRegistrationNonceState(account, nonce);
            return abi.encode(used, next);
        }
        if (selector == bytes4(keccak256("collaboratorCount(uint256,uint64)"))) {
            (uint256 collectionId, uint64 generation) = abi.decode(data[4:], (uint256, uint64));
            return abi.encode(
                IStreamArtistCollaboratorBindingOwner(s.owners[0])
                .bindingTerms(collectionId, generation)
                .count
            );
        }
        if (selector == bytes4(keccak256("delegatedNonceState(bytes32,address,uint256)"))) {
            (bytes32 artistId, address delegate, uint256 nonce) =
                abi.decode(data[4:], (bytes32, address, uint256));
            (bool used, uint256 next) = IStreamArtistDelegationOwner(s.owners[2])
                .delegatedNonceState(artistId, delegate, nonce);
            return abi.encode(used, next);
        }
        if (selector == bytes4(keccak256("payoutDesignationProvisionalAssociation(bytes32)"))) {
            bytes32 recordHash = abi.decode(data[4:], (bytes32));
            return abi.encode(
                IStreamArtistPayoutTransitionOwner(s.owners[5])
                    .payoutDesignationProvisionalAssociation(recordHash)
            );
        }
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
