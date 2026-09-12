// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistSanctionTypes as S } from "./StreamArtistSanctionTypes.sol";
import "../finality/IStreamArtistSanctionArchiveFacts.sol";

interface IStreamArtistSanctionEvents {
    event ArtistSanctionRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed sanctionSubjectHash,
        address indexed signer,
        uint8 scopeType,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 sanctionRecordHash,
        uint8 authorityClass,
        bytes32 statementHash,
        uint256 nonce,
        uint64 signedAt
    );
}

/// @notice Typed callbacks retain each owner's independent snapshot guard and single commit.
interface IStreamArtistIdentitySanctionOwner {
    function consumeSanction(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        S.Terms calldata terms,
        T.Authorization calldata authorization,
        T.SignerApproval calldata approval
    ) external returns (bytes32 recordHash);
}

interface IStreamArtistSanctionOwner is
    IStreamArtistSanctionEvents,
    IStreamArtistSanctionArchiveFacts
{
    function recordSanction(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        S.Record calldata record,
        R.AuthorityFact calldata authority,
        address finalityRegistry,
        bytes calldata ceremony,
        bytes calldata signature
    ) external returns (bytes32 recordHash);

    function sanctionRecord(bytes32 recordHash) external view returns (S.Record memory);
    function sanctionArchiveBytes(bytes32 recordHash) external view returns (bytes memory);
    function sanctionForAssociation(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId
    ) external view returns (bytes32 recordHash);
}
