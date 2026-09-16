// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/metadata/StreamArtistDisplayTypes.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Exact nested AA-DISPLAY serialization, separate from the historical renderer profile.
library StreamArtistDisplayJSON {
    using Strings for uint256;

    function unavailable() internal pure returns (bytes memory) {
        return '{"state":"attribution_unavailable"}';
    }

    function nested(bytes memory object) public pure returns (bytes memory) {
        return abi.encodePacked(',"properties":{"provenance":{"attribution":', object, "}}");
    }

    function render(StreamArtistDisplayTypes.Facts memory f)
        public
        pure
        returns (bytes memory out)
    {
        if (
            f.state < 1 || f.state > 5 || f.collaborators.length > 32
                || (f.claimCount == 0) != (f.latestClaim == 0)
                || (f.contested && (!f.hasPlatformHistory || f.contestRecord == 0))
        ) revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
        out = abi.encodePacked(
            '{"state":"',
            stateName(f.state),
            '","works_class":"',
            f.platform ? "platform_works" : "artist_bound",
            '","consent_mode":"',
            modeName(f.consentMode),
            '"'
        );
        if (!f.platform) {
            if (
                f.artistId == 0 || f.artist == address(0) || f.identityRecord == 0
                    || f.generation == 0 || f.consentMode == 3
            ) revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
            out = abi.encodePacked(
                out,
                ',"artist_id":"',
                hex32(f.artistId),
                '","artist_address":"',
                uint256(uint160(f.artist)).toHexString(20),
                '","artist_display_name":"',
                name(f.name),
                '","identity_record_hash":"',
                hex32(f.identityRecord),
                '","binding_generation":',
                uint256(f.generation).toString(),
                ',"corrected_attribution":',
                boolean(f.corrected)
            );
            if (f.deploymentRecord != 0) {
                out = abi.encodePacked(
                    out, ',"deployment_attestation":"', hex32(f.deploymentRecord), '"'
                );
            }
            out = abi.encodePacked(
                out, ',"attestation_status":"', attestationName(f.attestationStatus), '"'
            );
            if (f.attestationRecord != 0) {
                if (f.attestationStatus == 0) {
                    revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
                }
                out = abi.encodePacked(
                    out,
                    ',"attestation_record":"',
                    hex32(f.attestationRecord),
                    '","attestation_authority_class":"',
                    authority(f.attestationClass),
                    '","attested_state_hash":"',
                    hex32(f.attestedHash),
                    '"'
                );
            } else if (f.attestationStatus != 0 || f.attestedHash != 0 || f.attestationClass != 0) {
                revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
            }
        } else if (f.consentMode != 3 || f.artistId != 0 || f.artist != address(0)) {
            revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
        }
        if (f.collaborators.length != 0) {
            out = abi.encodePacked(out, ',"collaborators":[');
            for (uint256 i; i < f.collaborators.length; ++i) {
                StreamArtistDisplayTypes.Collaborator memory c = f.collaborators[i];
                if (c.account == address(0) || c.artistId == 0 || c.identityRecord == 0) {
                    revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
                }
                out = abi.encodePacked(
                    out,
                    i == 0 ? "" : ",",
                    '{"artist_id":"',
                    hex32(c.artistId),
                    '","account":"',
                    uint256(uint160(c.account)).toHexString(20),
                    '","role":"',
                    hex32(c.role),
                    '","verification_state":"artist_accepted","artist_display_name":"',
                    name(c.name),
                    '","identity_record_hash":"',
                    hex32(c.identityRecord),
                    '"}'
                );
            }
            out = abi.encodePacked(out, "]");
        }
        if (f.sanctionRecord != 0) {
            out = abi.encodePacked(
                out,
                ',"sanction_record":"',
                hex32(f.sanctionRecord),
                '","sanction_authority_class":"',
                authority(f.sanctionClass),
                '"'
            );
        } else if (f.sanctionClass != 0) {
            revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
        }
        if (f.platform || f.corrected) {
            out = abi.encodePacked(out, ',"contested":', boolean(f.contested));
            if (f.contested) {
                out = abi.encodePacked(out, ',"contest_record":"', hex32(f.contestRecord), '"');
            }
        }
        out = abi.encodePacked(out, ',"claim_count":', f.claimCount.toString());
        if (f.claimCount != 0) {
            out = abi.encodePacked(out, ',"latest_claim_record":"', hex32(f.latestClaim), '"');
        }
        return abi.encodePacked(out, "}");
    }

    function name(string memory value) private pure returns (string memory) {
        if (
            bytes(value).length == 0 || bytes(value).length > 256
                || !StreamMetadataRenderer.isValidUtf8(value)
        ) revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
        return StreamMetadataRenderer.escapeJsonString(value);
    }

    function boolean(bool value) private pure returns (string memory) {
        return value ? "true" : "false";
    }

    function hex32(bytes32 value) private pure returns (string memory) {
        return uint256(value).toHexString(32);
    }

    function stateName(uint8 value) private pure returns (string memory) {
        if (value == 1) return "claimed";
        if (value == 2) return "artist_accepted";
        if (value == 3) return "artist_sanctioned";
        if (value == 4) return "disputed";
        if (value == 5) return "revoked";
        revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
    }

    function modeName(uint8 value) private pure returns (string memory) {
        if (value == 1) return "artist_signed_policy";
        if (value == 2) return "artist_delegated";
        if (value == 3) return "platform_works";
        revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
    }

    function authority(uint8 value) private pure returns (string memory) {
        if (value == 1) return "artist";
        if (value == 2) return "delegate";
        if (value == 3) return "successor";
        if (value == 4) return "steward";
        revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
    }

    function attestationName(uint8 value) private pure returns (string memory) {
        if (value == 0) return "none";
        if (value == 1) return "attested_current";
        if (value == 2) return "attested_stale";
        if (value == 3) return "disputed";
        revert StreamArtistDisplayTypes.DisplayFactsUnavailable();
    }
}
