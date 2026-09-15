// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEstateStandingHistoryActual.t.sol";
import {
    StreamArtistAttestationTypes as Attest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";

/// @notice Real op40 successor capability on the new generic subject route; typed Core/governance.
contract StreamArtistSuccessorSubjectAttestationTest is
    StreamArtistEstateStandingHistoryActualTest
{
    function attestCurrentPrimary() external onlySelf returns (bytes32 record) {
        bytes32 hash =
            primary.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE")).assignmentHash;
        bytes memory statement = abi.encode("successor authorship", hash);
        T.Attestation memory p = T.Attestation(
            1,
            6,
            bytes32(uint256(uint160(address(primary)))),
            hash,
            keccak256("successor statement schema"),
            keccak256(statement),
            "urn:attestation:successor"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        record = ingress.recordArtistAttestation(p, a, statement);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        uint8(6),
                        p.subjectId,
                        hash,
                        p.schemaId,
                        p.statementHash,
                        keccak256(bytes(p.statementURI)),
                        artistId,
                        address(artist),
                        uint8(3),
                        a.nonce,
                        a.time
                    )
                ),
            "original op24 class3 preimage"
        );
    }

    function testSubjectActualSuccessorCapAtTestProducesClassThree() public {
        _accept();
        this.historySetup(0, 1, false);
        bytes32 record = this.attestCurrentPrimary();
        Attest.Association memory a = ingress.attestationAssociation(record);
        require(
            ingress.attestationAuthorityClass(record) == 3 && a.artistId == artistId
                && a.bindingHash == ingress.displayBinding(1).bindingHash && a.delegation == 0,
            "actual op40 CAP_ATTEST authority and current binding"
        );
    }

    function testSubjectActualZeroCapSuccessorCannotAttestGenericSubject() public {
        _accept();
        this.historySetup(0, 0, false);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(Estate.EstateCapabilityUnavailable.selector, artistId, uint32(1))
        );
        this.attestCurrentPrimary();
        require(_roots() == roots, "generic route cannot bypass actual successor capability");
    }
}
