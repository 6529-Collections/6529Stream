// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorLeaves as Leaves
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorAccountNonces as Accounts
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAccountNonces.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistNonceAvailability as Nonces
} from "../../../smart-contracts/domains/artist/StreamArtistNonceAvailability.sol";

/// @dev Real original nonce-tree producer; typed evidence/provenance around it is explicit.
contract PrimaryCollaboratorNonceProducer {
    using Nonces for Nonces.Index;
    mapping(address => Nonces.Index) private indexes;
    mapping(address => uint256[]) private prefixes;
    address[] private accounts;

    function consume(address account, uint256 nonce) external {
        bool found;
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i] == account) found = true;
        }
        if (!found) accounts.push(account);
        found = false;
        for (uint256 i; i < prefixes[account].length; ++i) {
            if (prefixes[account][i] == nonce >> 8) found = true;
        }
        if (!found) prefixes[account].push(nonce >> 8);
        indexes[account].consumeTagged(nonce, 3, bytes32(uint256(uint160(account))));
    }

    function rows() external view returns (IH.NonceLane[] memory result) {
        result = new IH.NonceLane[](accounts.length);
        for (uint256 i; i < accounts.length; ++i) {
            address account = accounts[i];
            result[i].kind = 3;
            result[i].key = bytes32(uint256(uint160(account)));
            (, result[i].hint) = indexes[account].firstUnused();
            result[i].words = new AH.NonceWord[](prefixes[account].length);
            for (uint256 j; j < prefixes[account].length; ++j) {
                result[i].words[j].prefix = prefixes[account][j];
                (result[i].words[j].words, result[i].words[j].exhausted) =
                    indexes[account].checkpointWords(prefixes[account][j]);
            }
        }
    }
}

/// @notice Fixed canonical leaves/nonce proofs. No full Archive/Registry/Safe migration claim.
interface PrimaryCollaboratorVm {
    function expectRevert(bytes4 selector) external;
}

contract StreamArtistPrimaryCollaboratorLeavesTest {
    PrimaryCollaboratorVm private constant vm =
        PrimaryCollaboratorVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) private pure {
        require(a == b, "uint mismatch");
    }

    function assertEq(bytes32 a, bytes32 b) private pure {
        require(a == b, "word mismatch");
    }

    function assertEq(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "bytes mismatch");
    }

    function assertTrue(bool a) private pure {
        require(a, "expected true");
    }

    function assertFalse(bool a) private pure {
        require(!a, "expected false");
    }
    address private constant ACCOUNT = address(0xA11CE);
    address private constant OTHER = address(0xB0B);

    function testProposalPreservesLiteralDomainAndAllOriginalFields() public {
        RH.OriginEnvironment memory o = _origin();
        C.IdentityProposal memory p = _proposal();
        H.Envelope memory e = _frames(5, 0x06, 0x02);
        e.actor = OTHER;
        e.value = keccak256(
            abi.encode(
                keccak256("6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"),
                o.chainId,
                o.registry,
                p,
                OTHER
            )
        );
        e.payload = abi.encode(p, bytes32(uint256(34)), uint64(2));
        C.IdentityProposalState memory result = Leaves.proposal(o, e);
        assertEq(abi.encode(result), abi.encode(C.IdentityProposalState(p, OTHER, e.value, 0)));
    }

    function testProposalWrongHashAndTrailingBytesRefuseThenRestore() public {
        RH.OriginEnvironment memory o = _origin();
        C.IdentityProposal memory p = _proposal();
        H.Envelope memory e = _frames(5, 0x06, 0x02);
        e.actor = OTHER;
        e.value = keccak256(
            abi.encode(
                keccak256("6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"),
                o.chainId,
                o.registry,
                p,
                OTHER
            )
        );
        bytes32 expected = e.value;
        e.payload = abi.encode(p, bytes32(uint256(34)), uint64(2));
        e.value = bytes32(uint256(77));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.proposal(o, e);
        e.value = expected;
        e.payload = bytes.concat(e.payload, hex"00");
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.proposal(o, e);
        e.payload = abi.encode(p, bytes32(uint256(34)), uint64(2));
        assertEq(Leaves.proposal(o, e).proposalHash, expected);
    }

    function testIdentityExactAllocationAndCompleteOriginalPayload() public {
        (RH.OriginEnvironment memory o, H.Envelope memory e, PC.IdentityAcceptance memory x) =
            _identity();
        assertEq(
            e.value,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ID_V1"),
                    uint256(6529),
                    address(0xAA),
                    ACCOUNT,
                    keccak256(bytes("complete identity")),
                    uint256(9)
                )
            )
        );
        assertEq(abi.encode(Leaves.identity(o, e)), abi.encode(x));
    }

    function testIdentityAllocationDirectFlagAndDocumentSubstitutionsRefuse() public {
        (RH.OriginEnvironment memory o, H.Envelope memory e, PC.IdentityAcceptance memory x) =
            _identity();
        x.allocationNonce = 10;
        e.payload = _identityBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.identity(o, e);
        x.allocationNonce = 9;
        x.approval.direct = false;
        e.payload = _identityBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.identity(o, e);
        x.approval.direct = true;
        x.document = bytes("substitute");
        e.payload = _identityBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.identity(o, e);
        x.document = bytes("complete identity");
        e.payload = _identityBytes(x);
        assertEq(Leaves.identity(o, e).allocationNonce, 9);
    }

    function testPartialAcceptancePreservesOriginalTenFieldPayload() public {
        (RH.OriginEnvironment memory o, H.Envelope memory e, PC.BindingAcceptance memory x) =
            _row(false);
        assertEq(abi.encode(Leaves.acceptance(o, e)), abi.encode(x));
        assertEq(e.before_[0].revision, e.after_[0].revision);
        assertEq(e.before_[4].revision, e.after_[4].revision);
    }

    function testLastCollaboratorCompletesOnlyWithOriginalPrimaryRecord() public {
        (RH.OriginEnvironment memory o, H.Envelope memory e, PC.BindingAcceptance memory x) =
            _row(true);
        assertTrue(Leaves.acceptance(o, e).complete);
        assertEq(e.after_[0].revision, e.before_[0].revision + 1);
        assertEq(e.after_[4].revision, e.before_[4].revision + 1);
        x.primaryRecord = 0;
        e.payload = _rowBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.acceptance(o, e);
        x.primaryRecord = bytes32(uint256(50));
        e.payload = _rowBytes(x);
        assertTrue(Leaves.acceptance(o, e).complete);
    }

    function testPolicyModesCountAndUnexpectedOwnerWritesRefuse() public {
        (RH.OriginEnvironment memory o, H.Envelope memory e, PC.BindingAcceptance memory x) =
            _row(false);
        x.terms.mode = 1;
        e.payload = _rowBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.acceptance(o, e);
        x.terms.mode = 0;
        x.terms.threshold = 1;
        e.payload = _rowBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.acceptance(o, e);
        x.terms.threshold = 0;
        x.count = 2;
        e.payload = _rowBytes(x);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.acceptance(o, e);
        x.count = 1;
        e.payload = _rowBytes(x);
        e.after_[4].revision++;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Leaves.acceptance(o, e);
        e.after_[4].revision--;
        assertFalse(Leaves.acceptance(o, e).complete);
    }

    function testSparseSignedThenDirectAccountNoncesMatchOriginalTree() public {
        Accounts.Use[] memory uses = _uses();
        PrimaryCollaboratorNonceProducer producer = new PrimaryCollaboratorNonceProducer();
        for (uint256 i; i < uses.length; ++i) {
            producer.consume(uses[i].account, uses[i].nonce);
        }
        IH.NonceLane[] memory rows = producer.rows();
        assertEq(rows.length, 2);
        assertEq(rows[0].hint, 2);
        assertEq(rows[0].words[0].prefix, 1);
        assertEq(rows[0].words[0].words[0], uint256(1) << 44);
        assertEq(rows[0].words[1].words[0], 3);
        Accounts.validate(rows, uses, _provenance(uses));
    }

    function testDuplicateNonceAndSkippedDirectHintRefuseThenRestore() public {
        Accounts.Use[] memory uses = _uses();
        PrimaryCollaboratorNonceProducer producer = new PrimaryCollaboratorNonceProducer();
        for (uint256 i; i < uses.length; ++i) {
            producer.consume(uses[i].account, uses[i].nonce);
        }
        RH.OwnerProvenance memory p = _provenance(uses);
        uses[2].nonce = 300;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(producer.rows(), uses, p);
        uses[2].nonce = 2;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(producer.rows(), uses, p);
        uses[2].nonce = 1;
        Accounts.validate(producer.rows(), uses, p);
    }

    function testExtraConsumedBitAncestorWordAndWrongHintRefuseThenRestore() public {
        Accounts.Use[] memory uses = _uses();
        PrimaryCollaboratorNonceProducer producer = new PrimaryCollaboratorNonceProducer();
        for (uint256 i; i < uses.length; ++i) {
            producer.consume(uses[i].account, uses[i].nonce);
        }
        IH.NonceLane[] memory rows = producer.rows();
        RH.OwnerProvenance memory p = _provenance(uses);
        rows[0].words[0].words[0] |= 1;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(rows, uses, p);
        rows = producer.rows();
        rows[0].words[0].words[1] = 1;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(rows, uses, p);
        rows = producer.rows();
        rows[0].hint = 3;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(rows, uses, p);
        Accounts.validate(producer.rows(), uses, p);
    }

    function testAccountWordNarrowingAndMissingAliasRefuse() public {
        Accounts.Use[] memory uses = _uses();
        PrimaryCollaboratorNonceProducer producer = new PrimaryCollaboratorNonceProducer();
        for (uint256 i; i < uses.length; ++i) {
            producer.consume(uses[i].account, uses[i].nonce);
        }
        IH.NonceLane[] memory rows = producer.rows();
        RH.OwnerProvenance memory p = _provenance(uses);
        rows[0].key |= bytes32(uint256(1) << 160);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(rows, uses, p);
        rows = producer.rows();
        p.aliases[0].cell.commitment = 0;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Accounts.validate(rows, uses, p);
        Accounts.validate(rows, uses, _provenance(uses));
    }

    function testFuzzSparseAccountTreeKeepsExactPrefix(uint256 nonce) public {
        Accounts.Use[] memory uses = new Accounts.Use[](1);
        uses[0] = Accounts.Use(
            ACCOUNT, nonce, bytes32(uint256(90)), RH.Point(_originHash(), 2, 1), false
        );
        PrimaryCollaboratorNonceProducer producer = new PrimaryCollaboratorNonceProducer();
        producer.consume(ACCOUNT, nonce);
        IH.NonceLane[] memory rows = producer.rows();
        assertEq(rows[0].words[0].prefix, nonce >> 8);
        assertEq(rows[0].words[0].words[0], uint256(1) << (nonce & 255));
        assertEq(rows[0].hint, nonce == 0 ? 1 : 0);
        Accounts.validate(rows, uses, _provenance(uses));
    }

    function _proposal() private pure returns (C.IdentityProposal memory) {
        return C.IdentityProposal(
            ACCOUNT,
            keccak256(bytes("complete identity")),
            "ipfs://identity",
            bytes32(uint256(5)),
            "reason:retained"
        );
    }

    function _origin() private pure returns (RH.OriginEnvironment memory o) {
        o.chainId = 6529;
        o.registry = address(0xAA);
        o.core = address(0xBB);
        o.manager = address(0xCC);
    }

    function _originHash() private pure returns (bytes32) {
        return RH.originHash(_origin());
    }

    function _frames(uint16 op, uint256 observed, uint256 changed)
        private
        pure
        returns (H.Envelope memory e)
    {
        e.operation = op;
        e.version = 1;
        e.actor = ACCOUNT;
        for (uint8 i; i < 7; ++i) {
            if (observed & (1 << i) == 0) continue;
            e.before_[i] = T.Snapshot(
                RH.ownerDomain(i),
                uint64(10 + i),
                bytes32(uint256(111 + i)),
                bytes32(uint256(222 + i))
            );
            e.after_[i] = T.Snapshot(
                e.before_[i].domainId,
                e.before_[i].revision,
                e.before_[i].stateRoot,
                e.before_[i].recordChainTip
            );
            if (changed & (1 << i) != 0) e.after_[i].revision++;
        }
    }

    function _typed(RH.OriginEnvironment memory o, bytes32 payload) private pure returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                o.chainId,
                o.registry
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, payload));
    }

    function _identity()
        private
        pure
        returns (RH.OriginEnvironment memory o, H.Envelope memory e, PC.IdentityAcceptance memory x)
    {
        o = _origin();
        e = _frames(6, 0x06, 0x06);
        x.proposal = C.IdentityProposalState(_proposal(), OTHER, bytes32(uint256(23)), 0);
        x.authorization = T.Authorization(7, 2000, "");
        x.approval = T.SignerApproval(
            ACCOUNT,
            _typed(
                o,
                keccak256(
                    abi.encode(
                        keccak256(
                            "StreamCollaboratorIdentityAcceptance(address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"
                        ),
                        ACCOUNT,
                        x.proposal.proposal.identityRecordHash,
                        uint256(7),
                        uint64(2000)
                    )
                )
            ),
            true
        );
        x.document = bytes("complete identity");
        x.displayName = "Independent collaborator";
        x.allocationNonce = 9;
        e.value = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ID_V1"),
                o.chainId,
                o.registry,
                ACCOUNT,
                x.proposal.proposal.identityRecordHash,
                uint256(9)
            )
        );
        e.payload = _identityBytes(x);
    }

    function _identityBytes(PC.IdentityAcceptance memory x) private pure returns (bytes memory) {
        return abi.encode(
            x.proposal, x.authorization, x.approval, x.document, x.displayName, x.allocationNonce
        );
    }

    function _row(bool complete)
        private
        pure
        returns (RH.OriginEnvironment memory o, H.Envelope memory e, PC.BindingAcceptance memory x)
    {
        o = _origin();
        e = _frames(7, 0x1f, complete ? 0x1f : 0x0e);
        x.binding_.bindingHash = bytes32(uint256(40));
        x.binding_.generation = 2;
        x.acceptance = C.BindingAcceptance(
            42, 2, x.binding_.bindingHash, ACCOUNT, bytes32(uint256(43)), bytes32(uint256(44))
        );
        x.artistId = bytes32(uint256(45));
        x.authorization = T.Authorization(5, 3000, "");
        x.approval = T.SignerApproval(
            ACCOUNT,
            _typed(
                o,
                keccak256(
                    abi.encode(
                        keccak256(
                            "StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline)"
                        ),
                        o.core,
                        uint256(42),
                        uint64(2),
                        x.binding_.bindingHash,
                        ACCOUNT,
                        bytes32(uint256(43)),
                        bytes32(uint256(44)),
                        uint256(5),
                        uint64(3000)
                    )
                )
            ),
            true
        );
        T.CapabilityPolicyOverride[] memory empty = new T.CapabilityPolicyOverride[](0);
        x.terms = C.BindingTerms(
            bytes32(uint256(46)),
            keccak256(abi.encode(keccak256("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), empty)),
            0,
            0,
            2
        );
        x.priorCount = complete ? 1 : 0;
        x.count = x.priorCount + 1;
        x.primaryRecord = complete ? bytes32(uint256(50)) : bytes32(0);
        x.complete = complete;
        e.value = bytes32(uint256(51));
        e.payload = _rowBytes(x);
    }

    function _rowBytes(PC.BindingAcceptance memory x) private pure returns (bytes memory) {
        return abi.encode(
            x.binding_,
            x.acceptance,
            x.artistId,
            x.authorization,
            x.approval,
            x.terms,
            x.priorCount,
            x.count,
            x.primaryRecord,
            x.complete
        );
    }

    function _uses() private pure returns (Accounts.Use[] memory uses) {
        uses = new Accounts.Use[](4);
        uses[0] =
            Accounts.Use(ACCOUNT, 300, bytes32(uint256(60)), RH.Point(_originHash(), 2, 1), false);
        uses[1] =
            Accounts.Use(ACCOUNT, 0, bytes32(uint256(61)), RH.Point(_originHash(), 2, 2), true);
        uses[2] =
            Accounts.Use(ACCOUNT, 1, bytes32(uint256(62)), RH.Point(_originHash(), 2, 3), true);
        uses[3] = Accounts.Use(OTHER, 0, bytes32(uint256(63)), RH.Point(_originHash(), 2, 4), true);
    }

    function _provenance(Accounts.Use[] memory uses)
        private
        pure
        returns (RH.OwnerProvenance memory p)
    {
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = _origin();
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = _originHash();
        p.aliases = new RH.ReplayAlias[](uses.length * 2);
        for (uint256 i; i < uses.length; ++i) {
            Accounts.Use memory u = uses[i];
            p.aliases[i * 2] = RH.ReplayAlias(
                _originHash(),
                2,
                keccak256("identity_authority.replay.collaborator_account_nonce"),
                keccak256(abi.encode(u.account, u.nonce)),
                bytes32(uint256(100 + i * 2)),
                T.ReplayCell(u.digest, uint64(i + 1), 1, 2),
                u.point
            );
            p.aliases[i * 2 + 1] = RH.ReplayAlias(
                _originHash(),
                2,
                keccak256("identity_authority.replay.collaborator_account_digest"),
                keccak256(abi.encode(u.account, u.digest)),
                bytes32(uint256(101 + i * 2)),
                T.ReplayCell(u.digest, uint64(i + 1), 1, 2),
                u.point
            );
        }
    }
}
