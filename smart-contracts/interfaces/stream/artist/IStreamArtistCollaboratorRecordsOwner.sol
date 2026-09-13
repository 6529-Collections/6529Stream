// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Collaborator-owned proposals, accepted identity joins and progress; immutable rows remain Binding-owned.
interface IStreamArtistCollaboratorRecordsOwner {
    function identityProposal(address account, bytes32 identityRecordHash)
        external
        view
        returns (C.IdentityProposalState memory);
    function proposeIdentity(T.ActionContext calldata context, C.IdentityProposal calldata proposal)
        external
        returns (bytes32);
    function completeIdentity(
        T.ActionContext calldata context,
        address account,
        bytes32 identityRecordHash,
        bytes32 artistId
    ) external;
    function recordRowAcceptance(
        T.ActionContext calldata context,
        C.BindingAcceptance calldata acceptance,
        bytes32 artistId,
        bytes32 record
    ) external returns (uint32 acceptedCount);
    function acceptedRow(bytes32 bindingHash, address account, bytes32 role, bytes32 shareLabelId)
        external
        view
        returns (C.Join memory);
    function acceptedCount(bytes32 bindingHash) external view returns (uint32);
    function identityLinked(bytes32 artistId, address account) external view returns (bool);
}
