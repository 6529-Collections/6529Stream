// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityImportRecords as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityImportRecords.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistPayloadStore as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistPayloadStore.sol";
import {
    StreamArtistIdentityState as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistDelegationState as Delegations
} from "../../../smart-contracts/domains/artist/StreamArtistDelegationState.sol";
import {
    StreamArtistCollaboratorIdentityState as Collaborators
} from "../../../smart-contracts/domains/artist/StreamArtistCollaboratorIdentityState.sol";
import {
    StreamArtistIdentityRevisionState as Revisions
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRevisionState.sol";
import {
    StreamArtistRotationState as Rotations
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistIdentityContestState as Contests
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityContestState.sol";
import {
    StreamArtistSuccessionState as Succession
} from "../../../smart-contracts/domains/artist/StreamArtistSuccessionState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistEstateState as Estate
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistUnavailabilityState as Findings
} from "../../../smart-contracts/domains/artist/StreamArtistUnavailabilityState.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistDormancyState as Dormancy
} from "../../../smart-contracts/domains/artist/StreamArtistDormancyState.sol";
import {
    StreamArtistStewardSanctionState as Sanctions
} from "../../../smart-contracts/domains/artist/StreamArtistStewardSanctionState.sol";
import {
    StreamArtistStewardCapabilityState as Capabilities
} from "../../../smart-contracts/domains/artist/StreamArtistStewardCapabilityState.sol";
import {
    StreamArtistRecoveryAdjudicationState as Adjudication
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryAdjudicationState.sol";
import {
    StreamArtistRecoveryRewindState as Rewinds
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import { SSTORE2 } from "../../../smart-contracts/libraries/SSTORE2.sol";

interface IdentityImportRecordsVm {
    function expectCall(address target, bytes calldata input, uint64 count) external;
}

/// @dev Actual declared typed storage roots, matching X's fixed 17-slot ordering. No root or
/// arbitrary call target is accepted by the host entry point. This harness bypasses admission.
contract IdentityImportRecordsHost {
    Identity.State private identity;
    Delegations.State private delegations;
    Collaborators.State private collaborators;
    Revisions.State private revisions;
    Rotations.State private rotations;
    Contests.State private contests;
    Succession.State private succession;
    Resolutions.State private resolutions;
    Estate.State private estate;
    Findings.State private findings;
    Recovery.State private recovery;
    Dormancy.State private dormancy;
    Sanctions.State private sanctions;
    Capabilities.State private capabilities;
    Adjudication.State private adjudication;
    Rewinds.State private rewinds;
    X.ReplayRoot private replay;

    constructor() {
        identity.nextRegistrationNonce = 901;
        rotations.pending[keccak256("records artist")] = keccak256("untouched rotation");
    }

    function install(bytes calldata canonical) external {
        Records.install(_roots(), canonical);
    }

    function primeIdentical(IH.Bundle calldata b) external {
        for (uint256 i; i < b.documents.length; ++i) {
            identity.documents[b.documents[i].documentHash] = b.documents[i].document;
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            identity.signatures[b.signatures[i].recordHash] = b.signatures[i].signature;
        }
    }

    function seedConflict(uint8 kind, IH.Bundle calldata b) external returns (bytes32 key) {
        if (kind == 0) {
            key = b.documents[0].documentHash;
            identity.documents[key] = hex"bad000";
        } else if (kind == 1) {
            key = b.signatures[0].recordHash;
            identity.signatures[key] = hex"bad001";
        } else if (kind == 2) {
            key = b.revisions[0].record.recordHash;
            revisions.associations[key].windowEndsAt = 99;
        } else if (kind == 3) {
            key = b.delegations[0].recordHash;
            estate.grantEpoch[key] = 99;
        } else if (kind == 4) {
            key = keccak256(abi.encode(b.artistId, b.delegations[0].record.grant.delegate));
            delegations.current[key] = keccak256("conflicting current delegation");
        } else if (kind == 5) {
            key = b.designations[0].record.recordHash;
            rewinds.statuses[key].recoveryRecordHash = keccak256("conflicting status");
        } else if (kind == 6) {
            key = b.directives[0].record.recordHash;
            succession.payloads[key] = hex"bad006";
        } else {
            assert(kind == 7);
            key = b.sanctionGrants[0].record.recordHash;
            sanctions.records[key].nonce = 99;
        }
    }

    function clearLateConflict(uint8 kind, IH.Bundle calldata b) external {
        if (kind == 6) {
            delete succession.payloads[b.directives[0].record.recordHash];
        } else {
            assert(kind == 7);
            delete sanctions.records[b.sanctionGrants[0].record.recordHash];
        }
    }

    function payloadCount() external view returns (uint256) {
        return Payload.count();
    }

    function payloadAt(uint256 index)
        external
        view
        returns (address, bytes32, bytes32, bytes memory)
    {
        (address pointer, bytes32 kind, bytes32 hash) = Payload.at(index);
        return (pointer, kind, hash, SSTORE2.read(pointer));
    }

    function assertStored(IH.Bundle calldata b) external view {
        uint256[17] memory r = _roots();
        for (uint256 i; i < b.documents.length; ++i) {
            _same(X.identity(r).documents[b.documents[i].documentHash], b.documents[i].document);
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            _same(X.identity(r).signatures[b.signatures[i].recordHash], b.signatures[i].signature);
        }
        for (uint256 i; i < b.revisions.length; ++i) {
            IH.RevisionRow calldata row = b.revisions[i];
            bytes32 key = row.record.recordHash;
            _same(
                abi.encode(
                    X.revisions(r).records[key],
                    X.revisions(r).associations[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).revisionRecordContinuations[key]
                ),
                abi.encode(row.record, row.association, row.status, row.rewindContinuation)
            );
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow calldata row = b.delegations[i];
            bytes32 lane = keccak256(abi.encode(b.artistId, row.record.grant.delegate));
            _same(
                abi.encode(
                    X.delegations(r).records[row.recordHash],
                    X.delegations(r).current[lane],
                    X.estate(r).grantEpoch[row.recordHash]
                ),
                abi.encode(row.record, row.current, row.epoch)
            );
        }
        for (uint256 i; i < b.designations.length; ++i) {
            IH.DesignationRow calldata row = b.designations[i];
            bytes32 key = row.record.recordHash;
            _same(
                abi.encode(X.succession(r).designations[key], X.rewinds(r).statuses[key]),
                abi.encode(row.record, row.status)
            );
        }
        for (uint256 i; i < b.directives.length; ++i) {
            IH.DirectiveRow calldata row = b.directives[i];
            bytes32 key = row.record.recordHash;
            _same(
                abi.encode(
                    X.succession(r).directives[key],
                    X.succession(r).payloads[key],
                    X.rewinds(r).statuses[key]
                ),
                abi.encode(row.record, row.payload, row.status)
            );
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            IH.GrantRow calldata row = b.sanctionGrants[i];
            bytes32 key = row.record.recordHash;
            _same(
                abi.encode(X.sanctions(r).records[key], X.rewinds(r).statuses[key]),
                abi.encode(row.record, row.status)
            );
        }
        assert(identity.nextRegistrationNonce == 901);
        assert(rotations.pending[keccak256("records artist")] == keccak256("untouched rotation"));
    }

    /// @dev Every touched map cell and catalog row participates, including seeded conflicts.
    function stateHash(IH.Bundle calldata b) external view returns (bytes32 h) {
        uint256[17] memory r = _roots();
        h = keccak256(abi.encode(identity.nextRegistrationNonce, rotations.pending[b.artistId]));
        for (uint256 i; i < b.documents.length; ++i) {
            h = keccak256(abi.encode(h, X.identity(r).documents[b.documents[i].documentHash]));
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            h = keccak256(abi.encode(h, X.identity(r).signatures[b.signatures[i].recordHash]));
        }
        for (uint256 i; i < b.revisions.length; ++i) {
            bytes32 key = b.revisions[i].record.recordHash;
            h = keccak256(
                abi.encode(
                    h,
                    X.revisions(r).records[key],
                    X.revisions(r).associations[key],
                    X.rewinds(r).statuses[key],
                    X.rewinds(r).revisionRecordContinuations[key]
                )
            );
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            bytes32 key = b.delegations[i].recordHash;
            bytes32 lane = keccak256(abi.encode(b.artistId, b.delegations[i].record.grant.delegate));
            h = keccak256(
                abi.encode(
                    h,
                    X.delegations(r).records[key],
                    X.delegations(r).current[lane],
                    X.estate(r).grantEpoch[key]
                )
            );
        }
        for (uint256 i; i < b.designations.length; ++i) {
            bytes32 key = b.designations[i].record.recordHash;
            h = keccak256(
                abi.encode(h, X.succession(r).designations[key], X.rewinds(r).statuses[key])
            );
        }
        for (uint256 i; i < b.directives.length; ++i) {
            bytes32 key = b.directives[i].record.recordHash;
            h = keccak256(
                abi.encode(
                    h,
                    X.succession(r).directives[key],
                    X.succession(r).payloads[key],
                    X.rewinds(r).statuses[key]
                )
            );
        }
        for (uint256 i; i < b.sanctionGrants.length; ++i) {
            bytes32 key = b.sanctionGrants[i].record.recordHash;
            h = keccak256(abi.encode(h, X.sanctions(r).records[key], X.rewinds(r).statuses[key]));
        }
        uint256 count = Payload.count();
        h = keccak256(abi.encode(h, count));
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) = Payload.at(i);
            h = keccak256(abi.encode(h, pointer, kind, hash, SSTORE2.read(pointer)));
        }
    }

    function _same(bytes memory actual, bytes memory expected) private pure {
        assert(actual.length == expected.length && keccak256(actual) == keccak256(expected));
    }

    function _roots() private pure returns (uint256[17] memory r) {
        assembly ("memory-safe") {
            mstore(r, identity.slot)
            mstore(add(r, 32), delegations.slot)
            mstore(add(r, 64), collaborators.slot)
            mstore(add(r, 96), revisions.slot)
            mstore(add(r, 128), rotations.slot)
            mstore(add(r, 160), contests.slot)
            mstore(add(r, 192), succession.slot)
            mstore(add(r, 224), resolutions.slot)
            mstore(add(r, 256), estate.slot)
            mstore(add(r, 288), findings.slot)
            mstore(add(r, 320), recovery.slot)
            mstore(add(r, 352), dormancy.slot)
            mstore(add(r, 384), sanctions.slot)
            mstore(add(r, 416), capabilities.slot)
            mstore(add(r, 448), adjudication.slot)
            mstore(add(r, 480), rewinds.slot)
            mstore(add(r, 512), replay.slot)
        }
    }
}

/// @notice Genuine Records/PayloadStore storage and transaction rollback with canonical tuples.
/// @dev Synthetic fixtures bypass SourceCodec, principal checks, provenance, authorization and
/// all later importer stages. No full recovered-source or operation60 admission is claimed.
contract StreamArtistRecoveredIdentityImportRecordsTest {
    IdentityImportRecordsVm private constant vm =
        IdentityImportRecordsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant DOCUMENT = keccak256("ARTIST_IDENTITY_DOCUMENT");
    bytes32 private constant SIGNATURE = keccak256("ARTIST_SIGNATURE_BUNDLE");
    bytes32 private constant DIRECTIVE = keccak256("ARTIST_DIRECTIVE_PAYLOAD");

    function testInstallPreservesEveryRecordFieldAndOwnerContext() public {
        IH.Bundle memory b = _fixture();
        IdentityImportRecordsHost host = new IdentityImportRecordsHost();
        IdentityImportRecordsHost other = new IdentityImportRecordsHost();
        bytes32 emptyOther = other.stateHash(b);
        host.install(abi.encode(b));
        host.assertStored(b);
        _assertCatalog(host, b, true);
        assert(other.stateHash(b) == emptyOther && other.payloadCount() == 0);
    }

    function testDocumentAndSignatureConflictsReturnOriginalKey() public {
        IH.Bundle memory b = _fixture();
        for (uint8 kind; kind < 2; ++kind) {
            IdentityImportRecordsHost host = new IdentityImportRecordsHost();
            bytes32 key = host.seedConflict(kind, b);
            bytes32 before_ = host.stateHash(b);
            _reject(host, abi.encode(b), key);
            assert(host.stateHash(b) == before_ && host.payloadCount() == 0);
        }
    }

    function testCompoundRecordAndDelegationLaneConflictsRollbackEarlierWrites() public {
        IH.Bundle memory b = _fixture();
        for (uint8 kind = 2; kind < 6; ++kind) {
            IdentityImportRecordsHost host = new IdentityImportRecordsHost();
            bytes32 key = host.seedConflict(kind, b);
            bytes32 before_ = host.stateHash(b);
            _reject(host, abi.encode(b), key);
            assert(host.stateHash(b) == before_ && host.payloadCount() == 0);
        }
    }

    function testLateDirectivePayloadCollisionRollsBackAndIdenticalRetrySucceeds() public {
        _lateCollision(6);
    }

    function testLateGrantCollisionRollsBackDirectiveCatalogAndIdenticalRetrySucceeds() public {
        _lateCollision(7);
    }

    function testIdenticalExistingDocumentsAndSignaturesStillStoreAndDeduplicate() public {
        IH.Bundle memory full = _fixture();
        IH.Bundle memory b;
        b.artistId = full.artistId;
        b.documents = full.documents;
        b.signatures = full.signatures;
        IdentityImportRecordsHost host = new IdentityImportRecordsHost();
        host.primeIdentical(b);
        assert(host.payloadCount() == 0);
        bytes memory canonical = abi.encode(b);
        _expectStores(b, 2, false);
        host.install(canonical);
        host.assertStored(b);
        _assertCatalog(host, b, false);
        bytes32 first = host.stateHash(b);
        host.install(canonical);
        host.assertStored(b);
        assert(host.stateHash(b) == first);
        _assertCatalog(host, b, false);
    }

    function _lateCollision(uint8 kind) private {
        IH.Bundle memory b = _fixture();
        IdentityImportRecordsHost host = new IdentityImportRecordsHost();
        bytes32 empty = host.stateHash(b);
        bytes32 key = host.seedConflict(kind, b);
        bytes32 before_ = host.stateHash(b);
        bytes memory canonical = abi.encode(b);
        // No mock replaces these calls: both attempts execute actual Payload.store/SSTORE2.
        _expectStores(b, 2, kind == 7);
        _reject(host, canonical, key);
        assert(host.stateHash(b) == before_ && host.payloadCount() == 0);
        host.clearLateConflict(kind, b);
        assert(host.stateHash(b) == empty);
        host.install(canonical);
        host.assertStored(b);
        _assertCatalog(host, b, true);
    }

    function _expectStores(IH.Bundle memory b, uint64 count, bool directive) private {
        for (uint256 i; i < b.documents.length; ++i) {
            vm.expectCall(
                address(Payload),
                abi.encodeWithSelector(Payload.store.selector, DOCUMENT, b.documents[i].document),
                count
            );
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            vm.expectCall(
                address(Payload),
                abi.encodeWithSelector(
                    Payload.store.selector, SIGNATURE, b.signatures[i].signature
                ),
                count
            );
        }
        if (directive) {
            vm.expectCall(
                address(Payload),
                abi.encodeWithSelector(Payload.store.selector, DIRECTIVE, b.directives[0].payload),
                count
            );
        }
    }

    function _assertCatalog(IdentityImportRecordsHost host, IH.Bundle memory b, bool directive)
        private
        view
    {
        uint256 count = b.documents.length + b.signatures.length + (directive ? 1 : 0);
        assert(host.payloadCount() == count);
        uint256 index;
        for (uint256 i; i < b.documents.length; ++i) {
            _payload(host, index++, DOCUMENT, b.documents[i].document);
        }
        for (uint256 i; i < b.signatures.length; ++i) {
            _payload(host, index++, SIGNATURE, b.signatures[i].signature);
        }
        if (directive) _payload(host, index, DIRECTIVE, b.directives[0].payload);
    }

    function _payload(
        IdentityImportRecordsHost host,
        uint256 index,
        bytes32 expectedKind,
        bytes memory expected
    ) private view {
        (address pointer, bytes32 kind, bytes32 hash, bytes memory payload) = host.payloadAt(index);
        assert(pointer != address(0) && pointer.code.length == expected.length + 1);
        assert(kind == expectedKind && hash == keccak256(expected));
        assert(payload.length == expected.length && keccak256(payload) == keccak256(expected));
    }

    function _reject(IdentityImportRecordsHost host, bytes memory canonical, bytes32 key) private {
        (bool ok, bytes memory reason) =
            address(host).call(abi.encodeCall(host.install, (canonical)));
        bytes memory expected = abi.encodeWithSelector(IH.InvalidRecoveredIdentity.selector, key);
        assert(!ok && reason.length == expected.length && keccak256(reason) == keccak256(expected));
    }

    function _fixture() private pure returns (IH.Bundle memory b) {
        b.artistId = keccak256("records artist");
        b.identity.displayName = "not installed by this kernel";
        b.identity.identityRecordURI = "synthetic complete Bundle";
        b.documents = new IH.DocumentRow[](2);
        b.documents[0].document = bytes("first document with more than one ABI word of content");
        b.documents[1].document = hex"0025ff";
        for (uint256 i; i < 2; ++i) {
            b.documents[i].documentHash = keccak256(b.documents[i].document);
        }
        b.signatures = new IH.SignatureRow[](2);
        b.signatures[0] = IH.SignatureRow(keccak256("signature record zero"), hex"00deadbeef6529ff");
        b.signatures[1] = IH.SignatureRow(keccak256("signature record one"), hex"");
        b.revisions = new IH.RevisionRow[](1);
        IH.RevisionRow memory revision = b.revisions[0];
        revision.record.recordHash = keccak256("revision record");
        revision.record.artistId = b.artistId;
        revision.record.previousRecordHash = b.documents[0].documentHash;
        revision.record.revisedRecordHash = b.documents[1].documentHash;
        revision.record.previousRevisionRecord = keccak256("prior revision");
        revision.record.signer = address(0x1234);
        revision.record.authorityClass = 3;
        revision.record.nonce = 101;
        revision.record.signedAt = 102;
        revision.record.identityRecordURI = "revision://synthetic";
        revision.record.displayName = "revision display";
        revision.association = R.ProvisionalAssociation(keccak256("revision transition"), 103);
        revision.status = _status(b.artistId, W.RecordKind.IDENTITY_REVISION, 1);
        revision.rewindContinuation = keccak256("revision continuation");
        b.delegations = new IH.DelegationRow[](1);
        IH.DelegationRow memory delegation = b.delegations[0];
        delegation.recordHash = keccak256("delegation record");
        delegation.record.grant.artistId = b.artistId;
        delegation.record.grant.delegate = address(0x2345);
        delegation.record.grant.collectionId = 104;
        delegation.record.grant.capabilities = 105;
        delegation.record.grant.notBefore = 106;
        delegation.record.grant.expiresAt = 107;
        delegation.record.grant.maxUses = 108;
        delegation.record.grant.constraintsHash = keccak256("delegation constraints");
        delegation.record.grantor = address(0x3456);
        delegation.record.nonce = 109;
        delegation.record.uses = 110;
        delegation.record.revoked = true;
        delegation.record.revocationRecordHash = keccak256("delegation revocation");
        delegation.current = keccak256("current delegation");
        delegation.epoch = 111;
        b.designations = new IH.DesignationRow[](1);
        IH.DesignationRow memory designation = b.designations[0];
        designation.record.recordHash = keccak256("designation record");
        designation.record.terms.artistId = b.artistId;
        designation.record.terms.successor = address(0x4567);
        designation.record.terms.successorKind = 2;
        designation.record.terms.grantedCapabilities = 112;
        designation.record.terms.conditionsHash = keccak256("designation conditions");
        designation.record.terms.directiveHash = keccak256("designation directive");
        designation.record.signer = address(0x5678);
        designation.record.authorityClass = 1;
        designation.record.nonce = 113;
        designation.record.signedAt = 114;
        designation.record.provisional =
            R.ProvisionalAssociation(keccak256("designation transition"), 115);
        designation.status = _status(b.artistId, W.RecordKind.SUCCESSOR_DESIGNATION, 2);
        b.directives = new IH.DirectiveRow[](1);
        IH.DirectiveRow memory directive = b.directives[0];
        directive.record.recordHash = keccak256("directive record");
        directive.record.terms.artistId = b.artistId;
        directive.record.terms.grantedCapabilities = 116;
        directive.record.terms.forbiddenCapabilities = 117;
        directive.payload = bytes("actual directive payload stored by the original Payload library");
        directive.record.terms.directivePayloadHash = keccak256(directive.payload);
        directive.record.signer = address(0x6789);
        directive.record.authorityClass = 3;
        directive.record.nonce = 118;
        directive.record.signedAt = 119;
        directive.record.provisional =
            R.ProvisionalAssociation(keccak256("directive transition"), 120);
        directive.status = _status(b.artistId, W.RecordKind.ESTATE_DIRECTIVE, 3);
        b.sanctionGrants = new IH.GrantRow[](1);
        IH.GrantRow memory grant = b.sanctionGrants[0];
        grant.record.recordHash = keccak256("grant record");
        grant.record.terms.artistId = b.artistId;
        grant.record.terms.granted = true;
        grant.record.terms.statementHash = keccak256("grant statement");
        grant.record.signer = address(0x789a);
        grant.record.authorityClass = 1;
        grant.record.nonce = 121;
        grant.record.signedAt = 122;
        grant.record.provisional = R.ProvisionalAssociation(keccak256("grant transition"), 123);
        grant.status = _status(b.artistId, W.RecordKind.STEWARD_SANCTION_GRANT, 4);
    }

    function _status(bytes32 artistId, W.RecordKind kind, uint256 seed)
        private
        pure
        returns (W.StatusV3 memory)
    {
        return W.StatusV3(
            artistId,
            kind,
            keccak256(abi.encode("recovery", seed)),
            keccak256(abi.encode("action", seed)),
            keccak256(abi.encode("plan", seed))
        );
    }
}
