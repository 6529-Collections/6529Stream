// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveredEstateAuthorityActual.t.sol";
import {
    IStreamArtistContentAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamArtistConsentOwner as ConsentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistEconomicsAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import {
    IStreamArtistRecoveredConsentHydration as Extended
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Genuine40/35 then class3 content17/royalty20/content-freeze21 through original Safe.
/// @dev The seven owners, Registry, Coordinator, Archive, Safe and Royalty Resolver are actual.
/// Core/governance and the inherited Metadata host remain explicit unit fixture boundaries.
/// Source-authored cases, not runtime or capacity acceptance.
contract StreamArtistRecoveredEstateContentActualTest is
    StreamArtistRecoveredEstateAuthorityActualTest
{
    ContentOwner.ConsentRecord[] private ecConsents;
    Content.FreezeRecord[] private ecFreezes;
    T.RoyaltyFreeze[] private ecRoyaltyTerms;
    T.RoyaltyFreezeRecord[] private ecRoyalties;
    bytes32[] private ecRecords;
    bytes[] private ecSignatures;
    T.Authorization private ecRoyaltyAuthorization;

    function testRecoveredClassThreeContentAndFreezeHistorySurvivesTwoImportsAndFreshWrites()
        external
    {
        _ecStart(160);
        _ecConsent();
        _ecConsent();
        _ecFreeze();
        _ecFreeze();
        _ecRoyalty();
        address[7] memory aOwners = suite.owners;
        uint256 originalRecords = ecRecords.length;
        Successor memory b = _ecImport();
        bytes32 aBefore = _ecCheckpoint(aOwners);
        _ecAssert(b.coordinator.suiteConfiguration());
        _ehAdopt(b);
        _ecConsent();
        _ecFreeze();
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == 2,
            "B has only two original local writes"
        );
        for (uint256 i; i < originalRecords; ++i) {
            require(
                keccak256(IStreamArtistIdentityOwner(aOwners[2]).signatureBundle(ecRecords[i]))
                    == keccak256(ecSignatures[i]),
                "fresh B does not rewrite original A signatures"
            );
        }
        address[7] memory bOwners = suite.owners;
        Successor memory c = _ecImport();
        bytes32 bBefore = _ecCheckpoint(bOwners);
        _ecAssert(c.coordinator.suiteConfiguration());
        require(
            _ecCheckpoint(aOwners) == aBefore && _ecCheckpoint(bOwners) == bBefore,
            "both source inventories remain immutable"
        );
        _ehAdopt(c);
        _ecFreeze();
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == 1
                && IStreamArtistEstateOwner(suite.owners[2])
                .currentAuthorityCapabilities(artistId)
                .effectiveCapabilities == 160,
            "fresh C21 retains original estate rights and current domain"
        );
        _ecAssert(suite);
        require(
            _ecCheckpoint(aOwners) == aBefore && _ecCheckpoint(bOwners) == bBefore,
            "fresh C leaves both sealed predecessor inventories unchanged"
        );
    }

    function testRecoveredClassThreeZeroRightsStillRejectAllThreeOriginalConsentFamilies()
        external
    {
        _ecStart(0);
        // This intentionally uses the old no-content import shape before testing fresh eligibility.
        Successor memory b = _ecImport();
        _ehAdopt(b);
        for (uint8 kind; kind < 3; ++kind) {
            bytes32 before_ = _ecCheckpoint(suite.owners);
            uint256 safeNonce = artist.nonce();
            vm.expectRevert(
                abi.encodeWithSelector(
                    Estate.EstateCapabilityUnavailable.selector,
                    artistId,
                    kind == 2 ? uint32(32) : uint32(128)
                )
            );
            this.ecDenied(kind);
            require(
                _ecCheckpoint(suite.owners) == before_ && artist.nonce() == safeNonce,
                "fresh permission rejection rolls back all original owners"
            );
        }
    }

    function testRecoveredClassThreeRoyaltyOriginalNonceAndScopeStaySpentInSuccessor() external {
        _ecStart(160);
        _ecRoyalty();
        T.RoyaltyFreeze memory terms = ecRoyaltyTerms[0];
        T.Authorization memory authorization = ecRoyaltyAuthorization;
        Successor memory b = _ecImport();
        _ehAdopt(b);
        bytes32 before_ = _ecCheckpoint(suite.owners);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidSignature.selector));
        ingress.authorizeArtistRoyaltyFreeze(terms, authorization);
        require(_ecCheckpoint(suite.owners) == before_, "old domain20 has no effect");

        authorization.signature = _signature(ingress.royaltyFreezeDigest(terms, authorization));
        bytes32 nonceKey = _ecKey(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, authorization.nonce))
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, nonceKey));
        ingress.authorizeArtistRoyaltyFreeze(terms, authorization);
        require(_ecCheckpoint(suite.owners) == before_, "old principal nonce remains spent");

        authorization = _authorization(false);
        authorization.signature = _signature(ingress.royaltyFreezeDigest(terms, authorization));
        bytes32 scope = keccak256(abi.encode(terms, artistId, uint64(1)));
        bytes32 scopeKey = _ecKey(6, "consent_finality.replay.freeze_key", scope);
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, scopeKey));
        ingress.authorizeArtistRoyaltyFreeze(terms, authorization);
        require(
            _ecCheckpoint(suite.owners) == before_
                && Owner(suite.owners[2])
                .replayCell(
                    _ecKey(
                        2,
                        "identity_authority.replay.nonce_allocator",
                        keccak256(abi.encode(artistId, authorization.nonce))
                    )
                )
                .status == 0,
            "late original20 scope rejection also rolls back the new Identity nonce"
        );
        _ecAssert(suite);
    }

    function ecDenied(uint8 kind) external {
        require(msg.sender == address(this), "fixture caller");
        T.Authorization memory a = _authorization(false);
        if (kind == 0) {
            Content.Consent memory terms = _contentProposal(keccak256("class3 recovered candidate"));
            a.signature = _signature(ingress.contentConsentDigest(terms, a));
            ingress.recordContentConsent(terms, a);
        } else if (kind == 1) {
            Content.Freeze memory terms = _contentFreezeProposal();
            a.signature = _signature(ingress.contentFreezeDigest(terms, a));
            ingress.authorizeArtistContentFreeze(terms, a);
        } else {
            T.RoyaltyFreeze memory terms = _freezePayload();
            a.signature = _signature(ingress.royaltyFreezeDigest(terms, a));
            ingress.authorizeArtistRoyaltyFreeze(terms, a);
        }
    }

    function _ecStart(uint32 capabilities) private {
        _ehBaseline(capabilities);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(ehRecovery).postWindowEndsAt);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass == 3,
            "actual class3 recovery matured"
        );
    }

    function _ecConsent() private {
        Content.Consent memory p = _contentProposal(keccak256("class3 recovered candidate"));
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.metadataContract,
                suite.core,
                p.collectionId,
                p.familyId,
                p.newStateHash,
                artistId,
                address(artist),
                uint8(3),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        _ecExecute(
            17,
            record,
            a,
            digest,
            abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a))
        );
        ContentOwner.ConsentRecord memory actual =
            ContentOwner(suite.owners[6]).contentConsentRecord(record);
        require(
            actual.authorityClass == 3
                && keccak256(abi.encode(actual.terms)) == keccak256(abi.encode(p)),
            "original17 literal preimage and retained terms"
        );
        ecConsents.push(actual);
        _ehCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(p, uint64(1))), record))
        );
    }

    function _ecFreeze() private {
        Content.Freeze memory p = _contentFreezeProposal();
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentFreezeDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.metadataContract,
                suite.core,
                p.collectionId,
                p.lockClasses,
                p.expectedStateHash,
                artistId,
                address(artist),
                uint8(3),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        _ecExecute(
            21,
            record,
            a,
            digest,
            abi.encodeCall(IStreamArtistContentAuthority.authorizeArtistContentFreeze, (p, a))
        );
        Content.FreezeRecord memory actual =
            ContentOwner(suite.owners[6]).contentFreezeRecord(record);
        require(
            actual.authorityClass == 3 && actual.expectedStateHash == p.expectedStateHash
                && keccak256(abi.encode(actual.lockClasses))
                    == keccak256(abi.encode(p.lockClasses)),
            "original21 literal preimage and complete lock set"
        );
        ecFreezes.push(actual);
        _ehCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(keccak256("CONTENT"), uint256(1), uint64(1), record))
        );
    }

    function _ecRoyalty() private {
        T.RoyaltyFreeze memory p = _freezePayload();
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.royaltyFreezeDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                block.chainid,
                address(ingress),
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                address(artist),
                uint8(3),
                a.nonce,
                uint64(block.timestamp)
            )
        );
        _ecExecute(
            20,
            record,
            a,
            digest,
            abi.encodeCall(IStreamArtistEconomicsAuthority.authorizeArtistRoyaltyFreeze, (p, a))
        );
        T.RoyaltyFreezeRecord memory actual =
            ConsentOwner(suite.owners[6]).royaltyFreezeRecord(p, artistId, 1);
        require(
            actual.recordHash == record && actual.artistId == artistId
                && actual.bindingGeneration == 1,
            "original20 literal class3 preimage and exact scope"
        );
        ecRoyaltyTerms.push(p);
        ecRoyalties.push(actual);
        ecRoyaltyAuthorization = a;
        _ehCandidate(
            6, "consent_finality.replay.freeze_key", keccak256(abi.encode(p, artistId, uint64(1)))
        );
    }

    function _ecExecute(
        uint16 operation,
        bytes32 record,
        T.Authorization memory a,
        bytes32 digest,
        bytes memory call_
    ) private {
        uint256 count = Native(suite.owners[6]).artistNativeReceiptCount();
        require(
            executeSafe(artist, keys, address(ingress), 0, call_, 0), "genuine class3 Safe consent"
        );
        HT.Receipt memory actual = Native(suite.owners[6]).artistNativeReceiptAt(count);
        require(
            actual.operation == operation && actual.recordHash == record
                && actual.artistId == artistId && actual.collectionId == 1,
            "original native occurrence joins independent class3 record hash"
        );
        require(
            keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                == keccak256(a.signature),
            "original Identity admitted exact Safe signature bytes"
        );
        ecRecords.push(record);
        ecSignatures.push(a.signature);
        _ehAuthorization(digest, a.nonce);
    }

    function _ecImport() private returns (Successor memory next) {
        next = _ehCutover();
        // Operation57 legitimately mutates the source Identity checkpoint. Freeze the source
        // oracle after that actual cutover, before preparation or any destination import write.
        bytes32 sourceBefore = _ecCheckpoint(suite.owners);
        require(
            next.registry.supportsInterface(type(Extended).interfaceId)
                && next.registry.supportsInterface(type(Recovered).interfaceId),
            "new interface is additive to the original recovered selector"
        );
        RH.Request memory request = _ehRequest();
        T.RoyaltyFreeze[] memory terms = ecRoyaltyTerms;
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request, terms);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bool content = ecConsents.length + ecRoyalties.length + ecFreezes.length != 0;
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(prepared.data[i].typedState, i);
            require(
                ((h.requiredFeatures & RH.CONTENT_CONSENTS) != 0) == content,
                "complete original journals select256 across all owners"
            );
        }
        require(
            executeSafe(
                artist,
                keys,
                address(next.registry),
                0,
                abi.encodeCall(
                    Extended.hydrateRecoveredArtistAuthorityWithConsents, (request, terms)
                ),
                0
            ),
            "actual class3 Safe imports seven owners atomically"
        );
        _ehImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        require(
            _ecCheckpoint(suite.owners) == sourceBefore,
            "import preserves every sealed source owner"
        );
    }

    function _ecAssert(T.SuiteConfiguration memory destination) private view {
        ContentOwner owner = ContentOwner(destination.owners[6]);
        for (uint256 i; i < ecConsents.length; ++i) {
            ContentOwner.ConsentRecord memory original = ecConsents[i];
            require(
                keccak256(abi.encode(owner.contentConsentRecord(original.recordHash)))
                    == keccak256(abi.encode(original)),
                "every17 historical version retained"
            );
            uint256 latest = i;
            for (uint256 j = i + 1; j < ecConsents.length; ++j) {
                if (
                    keccak256(abi.encode(ecConsents[j].terms))
                        == keccak256(abi.encode(original.terms))
                ) latest = j;
            }
            require(
                keccak256(abi.encode(owner.contentConsentAt(original.terms, 1)))
                    == keccak256(abi.encode(ecConsents[latest])),
                "17 latest map follows original order"
            );
        }
        for (uint256 i; i < ecFreezes.length; ++i) {
            Content.FreezeRecord memory original = ecFreezes[i];
            require(
                keccak256(abi.encode(owner.contentFreezeRecord(original.recordHash)))
                    == keccak256(abi.encode(original)),
                "every21 historical version retained"
            );
            for (uint256 k; k < original.lockClasses.length; ++k) {
                uint256 latest = i;
                for (uint256 j = i + 1; j < ecFreezes.length; ++j) {
                    if (ecFreezes[j].metadataContract != original.metadataContract) continue;
                    for (uint256 l; l < ecFreezes[j].lockClasses.length; ++l) {
                        if (ecFreezes[j].lockClasses[l] == original.lockClasses[k]) latest = j;
                    }
                }
                require(
                    keccak256(
                        abi.encode(
                            owner.contentFreezeAt(
                                1, 1, original.metadataContract, original.lockClasses[k]
                            )
                        )
                    ) == keccak256(abi.encode(ecFreezes[latest])),
                    "21 current lock head follows complete history"
                );
            }
        }
        for (uint256 i; i < ecRoyalties.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        ConsentOwner(destination.owners[6])
                            .royaltyFreezeRecord(ecRoyaltyTerms[i], artistId, 1)
                    )
                ) == keccak256(abi.encode(ecRoyalties[i])),
                "exact original20 scope survives import"
            );
        }
        for (uint256 i; i < ecRecords.length; ++i) {
            require(
                keccak256(
                    IStreamArtistIdentityOwner(destination.owners[2]).signatureBundle(ecRecords[i])
                ) == keccak256(ecSignatures[i]),
                "all original signature bytes retained"
            );
        }
    }

    function _ecKey(uint8 owner, string memory surface, bytes32 scope)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                Owner(suite.owners[owner]).domainId(),
                keccak256(bytes(surface)),
                scope
            )
        );
    }

    function _ecCheckpoint(address[7] memory owners) private view returns (bytes32 result) {
        for (uint8 i; i < 7; ++i) {
            result = keccak256(
                abi.encode(
                    result, CP(owners[i]).authorityCheckpoint(), Publications.collect(owners[i], i)
                )
            );
        }
    }
}
