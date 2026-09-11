// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Two-sided collaborator identities and exact generation-bound individual acceptance.
interface IStreamArtistCollaboratorLifecycle {
    function proposeCollaboratorIdentity(C.IdentityProposal calldata proposal)
        external
        returns (bytes32);
    function acceptCollaboratorIdentity(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata authorization,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
    function acceptCollaborator(
        C.BindingAcceptance calldata acceptance,
        T.Authorization calldata authorization
    ) external returns (bytes32);
    function collaboratorIdentityDigest(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
    function collaboratorAcceptanceDigest(
        C.BindingAcceptance calldata acceptance,
        T.Authorization calldata authorization
    ) external view returns (bytes32);
    function collaboratorIdentityProposal(address account, bytes32 identityRecordHash)
        external
        view
        returns (C.IdentityProposalState memory);
    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool used, uint256 firstUnused);
    function collaboratorCount(uint256 collectionId, uint64 generation)
        external
        view
        returns (uint256);
    function collaboratorAt(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        returns (C.Row memory);
    /// @notice Uses the collaborator identity ID and its acceptance-ratified account; absent pairs return zeros.
    function collaboratorPayoutAccount(bytes32 collaboratorArtistId, address collaborator)
        external
        view
        returns (address, bytes32);
}
