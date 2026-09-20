// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredIdentitySourceCanonical as Canonical
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceCanonical.sol";

/// @notice Differential ABI decoding oracle; does not claim authenticated source admission.
/// @dev Both successful normalized return bytes and exact failing return bytes must agree.
contract StreamArtistRecoveredIdentitySourceCodecParityTest {
    function actual(bytes calldata raw, bool schema) external pure returns (bytes memory) {
        return Canonical.canonical(raw, schema);
    }

    function original(bytes memory raw, bool schema) external pure returns (bytes memory) {
        IH.Bundle memory b;
        if (schema) (, b) = abi.decode(raw, (bytes32, IH.Bundle));
        else b = abi.decode(raw, (IH.Bundle));
        return abi.encode(b);
    }

    function testEveryBundleFieldAndNestedArrayRoundTrips() public view {
        IH.Bundle memory b = _fixture();
        _parity(abi.encode(b), false);
        _parity(abi.encode(IH.SCHEMA, b), true);
    }

    function testEmptyBundleRoundTripsWithAndWithoutSchema() public view {
        IH.Bundle memory b;
        _parity(abi.encode(b), false);
        _parity(abi.encode(IH.SCHEMA, b), true);
    }

    function testTrailingBytesNormalizeLikeOriginalTypedReturn() public view {
        bytes memory raw = abi.encode(_fixture());
        _parity(bytes.concat(raw, hex"010203"), false);
        _parity(bytes.concat(raw, abi.encode(type(uint256).max)), false);
    }

    function testNoncanonicalRootOffsetsNormalizeLikeOriginal() public view {
        bytes memory raw = abi.encode(_fixture());
        _parity(bytes.concat(abi.encode(uint256(64), uint256(93)), _slice(raw, 32)), false);
        _parity(
            bytes.concat(abi.encode(IH.SCHEMA, uint256(96), uint256(93)), _slice(raw, 32)), true
        );
    }

    function testFuzzDirtyScalarNestedOffsetAndArrayLengthParity(uint256 seed, uint256 dirty)
        public
        view
    {
        for (uint8 route; route < 2; ++route) {
            bool schema = route != 0;
            bytes memory raw = schema ? abi.encode(IH.SCHEMA, _fixture()) : abi.encode(_fixture());
            uint256 word = seed % (raw.length / 32);
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(word, 32)), dirty) }
            _parity(raw, schema);
        }
    }

    function testFuzzAllDirtyBitsParity(uint256 seed) public view {
        for (uint8 route; route < 2; ++route) {
            bool schema = route != 0;
            bytes memory raw = schema ? abi.encode(IH.SCHEMA, _fixture()) : abi.encode(_fixture());
            uint256 word = seed % (raw.length / 32);
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(word, 32)), not(0)) }
            _parity(raw, schema);
        }
    }

    function testFuzzTruncatedOwnByteFrameRejectsLikeOriginal(uint256 seed) public view {
        for (uint8 route; route < 2; ++route) {
            bool schema = route != 0;
            bytes memory raw = schema ? abi.encode(IH.SCHEMA, _fixture()) : abi.encode(_fixture());
            uint256 length = seed % raw.length;
            assembly ("memory-safe") { mstore(raw, length) }
            // The wrapper has a second argument after raw. It must not satisfy missing payload data.
            _parity(raw, schema);
        }
    }

    function testFuzzMalformedPayloadParity(bytes memory raw, bool schema) public view {
        _parity(raw, schema);
    }

    function _parity(bytes memory raw, bool schema) private view {
        (bool actualOK, bytes memory actualResult) =
            address(this).staticcall(abi.encodeCall(this.actual, (raw, schema)));
        (bool expectedOK, bytes memory expectedResult) =
            address(this).staticcall(abi.encodeCall(this.original, (raw, schema)));
        assert(actualOK == expectedOK && keccak256(actualResult) == keccak256(expectedResult));
    }

    function _slice(bytes memory raw, uint256 start) private pure returns (bytes memory out) {
        out = new bytes(raw.length - start);
        for (uint256 i; i < out.length; ++i) {
            out[i] = raw[start + i];
        }
    }

    function _fixture() private pure returns (IH.Bundle memory b) {
        b.documents = new IH.DocumentRow[](1);
        b.signatures = new IH.SignatureRow[](1);
        b.nonces = new IH.NonceLane[](1);
        b.revisions = new IH.RevisionRow[](1);
        b.delegations = new IH.DelegationRow[](1);
        b.guardians = new IH.GuardianRow[](1);
        b.memberships = new IH.MembershipRow[](1);
        b.rotations = new IH.RotationRow[](1);
        b.contests = new IH.ContestRow[](1);
        b.causes = new IH.CauseRow[](1);
        b.dismissals = new IH.DismissalRow[](1);
        b.closures = new IH.ClosureRow[](1);
        b.standing = new IH.StandingRow[](1);
        b.standingRecords = new IH.StandingRecordRow[](1);
        b.recoveries = new IH.RecoveryRow[](1);
        b.vestings = new IH.VestingRow[](1);
        b.actions = new IH.ActionRow[](1);
        b.designations = new IH.DesignationRow[](1);
        b.directives = new IH.DirectiveRow[](1);
        b.sanctionGrants = new IH.GrantRow[](1);
        b.estates = new IH.EstateRow[](1);
        b.notices = new IH.NoticeRow[](1);
        b.findings = new IH.FindingRow[](1);
        b.originalContinuations = new IH.OriginalContinuationRow[](1);
        b.revisionContinuations = new IH.RevisionContinuationRow[](1);
        b.standingContinuations = new IH.StandingContinuationRow[](1);
        b.capabilityContinuations = new IH.CapabilityContinuationRow[](1);
        b.artistId = keccak256("complete source codec sentinel");
        b.identity.authorityAddress = address(0x1234);
        b.identity.authorityClass = 3;
        b.identity.status = 1;
        b.identity.identityRecordURI = "ipfs://source";
        b.identity.displayName = "source";
        b.identityDocument = hex"010203";
        b.documents[0].document = hex"040506";
        b.signatures[0].signature = hex"1234567890abcdef";
        b.nonces[0].words = new AH.NonceWord[](1);
        b.nonces[0].words[0].exhausted = true;
        b.guardians[0].record.terms.guardians = new address[](2);
        b.guardians[0].record.terms.guardians[0] = address(0x4567);
        b.memberships[0].indices = new uint64[](2);
        b.rotations[0].approvals = new bool[](2);
        b.rotations[0].approvals[1] = true;
        b.actions[0].excludedMemberships = new uint64[](1);
        b.revisions[0].document = hex"abcdef";
        b.directives[0].payload = hex"fedcba";
    }
}
