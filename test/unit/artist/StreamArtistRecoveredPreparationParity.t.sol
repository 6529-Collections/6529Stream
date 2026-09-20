// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredPreparation as Preparation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparation.sol";
import {
    StreamArtistRecoveredPreparationSeal as Seal
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationSeal.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredExternalGuards.sol";

interface RecoveredPreparationParityVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function expectCall(address target, bytes calldata input, uint64 count) external;
    function clearMockedCalls() external;
}

/// @notice Frozen pure oracles and entry-guard ordering for the preparation size split.
/// @dev The reference algorithms are from ad707f8569c4a9a712ce6a854847c69c443c560e.
/// Synthetic inputs establish parity only, not authenticated seven-owner source admission.
/// All four typed entry points are compiled here; complete ABI/methodIdentifiers equality is
/// checked separately against the original compiler output, including library nominal types.
contract StreamArtistRecoveredPreparationParityTest {
    RecoveredPreparationParityVm private constant vm =
        RecoveredPreparationParityVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error AdmissionReadReached();

    // A well-shaped request reaches the first destination history read. Invalid shapes must
    // fail earlier, even when expected inventory, capabilities and royalty terms are invalid.
    fallback() external {
        revert AdmissionReadReached();
    }

    function testNominalPureSelectorsRemainOriginal() public pure {
        assert(
            Prepared.requiredFeatures.selector
                == bytes4(
                    keccak256(
                        "requiredFeatures(StreamArtistRecoveredIdentityHydrationTypes.Bundle,StreamArtistRecoveredPayoutTypes.Bundle,uint256)"
                    )
                )
        );
        assert(
            Prepared.inventory.selector
                == bytes4(keccak256("inventory(StreamArtistRecoveredHydrationCommit.Prepared)"))
        );
    }

    function testFuzzFeaturesMatchOriginal(
        bool classThree,
        uint256 historySeed,
        uint8 actionFlags,
        uint8 continuationFlags,
        uint8 eraSeed
    ) public pure {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = classThree ? 3 : 1;
        identity.recoveries = new IH.RecoveryRow[](historySeed % 5);
        for (uint256 i; i < identity.recoveries.length; ++i) {
            identity.recoveries[i].record.fields.vestedAuthorityClass =
                ((historySeed >> (8 + i)) & 1) == 0 ? 1 : 3;
        }
        identity.actions = new IH.ActionRow[](4);
        for (uint256 i; i < identity.actions.length; ++i) {
            if ((uint256(actionFlags) & (1 << (2 * i))) != 0) {
                identity.actions[i].evidenceV2.manifestHash = bytes32(i + 1);
            }
            if ((uint256(actionFlags) & (2 << (2 * i))) != 0) {
                identity.actions[i].evidenceV3.manifestHash = bytes32(i + 2);
            }
        }
        identity.revisionContinuations =
            new IH.RevisionContinuationRow[]((continuationFlags & 1) == 0 ? 0 : 1);
        identity.standingContinuations =
            new IH.StandingContinuationRow[]((continuationFlags & 2) == 0 ? 0 : 1);
        identity.capabilityContinuations =
            new IH.CapabilityContinuationRow[]((continuationFlags & 4) == 0 ? 0 : 1);
        payout.continuations = new P.ContinuationRow[]((continuationFlags & 8) == 0 ? 0 : 1);
        // The original op58 continuation does not itself advertise V2 or V3.
        identity.originalContinuations =
            new IH.OriginalContinuationRow[]((continuationFlags & 16) == 0 ? 0 : 1);
        uint256 eras = 1 + uint256(eraSeed) % 16;
        assert(
            Prepared.requiredFeatures(identity, payout, eras)
                == _originalFeatures(identity, payout, eras)
        );
    }

    function testFuzzFeatureRevertParity(uint8 currentClass, uint8 historicalClass, uint256 eras)
        public
        view
    {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.identity.authorityClass = currentClass;
        identity.recoveries = new IH.RecoveryRow[](1);
        identity.recoveries[0].record.fields.vestedAuthorityClass = historicalClass;
        (bool actualOK, bytes memory actual) =
            address(this).staticcall(abi.encodeCall(this.features, (identity, payout, eras)));
        (bool originalOK, bytes memory original) = address(this)
            .staticcall(abi.encodeCall(this.originalFeatures, (identity, payout, eras)));
        assert(actualOK == originalOK && keccak256(actual) == keccak256(original));
    }

    function testClassFailuresPrecedeInvalidEraCount() public view {
        IH.Bundle memory identity;
        P.Bundle memory payout;
        identity.recoveries = new IH.RecoveryRow[](2);
        identity.recoveries[0].record.fields.vestedAuthorityClass = 1;
        identity.recoveries[1].record.fields.vestedAuthorityClass = 2;
        _featureReject(identity, payout, 0, T.UnsupportedProfile.selector);
        _featureReject(identity, payout, type(uint256).max, T.UnsupportedProfile.selector);
        identity.identity.authorityClass = 3;
        _featureReject(identity, payout, 0, T.UnsupportedProfile.selector);
        _featureReject(identity, payout, type(uint256).max, T.UnsupportedProfile.selector);
        identity.recoveries[1].record.fields.vestedAuthorityClass = 3;
        _featureReject(identity, payout, 0, RH.InvalidRecoveredHydrationProfile.selector);
        _featureReject(identity, payout, 17, RH.InvalidRecoveredHydrationProfile.selector);
    }

    function testFuzzInventoryMatchesOriginalPreimage(uint256 seed, bytes32 salt) public pure {
        Commit.Prepared memory p = _inventory(seed, salt);
        assert(Prepared.inventory(p) == _originalInventory(p));
        bytes32 original = Prepared.inventory(p);
        // These admission fields were never part of the inventory preimage. Moving the
        // preparation implementation must not accidentally hash all of the Prepared tuple.
        p.admission.prior = address(uint160(seed));
        p.admission.sourceCoordinator = address(uint160(seed >> 1));
        p.admission.before_[2].revision = uint64(seed);
        assert(Prepared.inventory(p) == original);
        assert(Prepared.inventory(p) == _originalInventory(p));
    }

    /// @dev Genuine pure worker calls over a synthetic certificate. These prove the final
    /// encoding/inventory boundary only; they do not establish source admission or owner checks.
    function testFuzzSealPrepareReturnsOriginalEncodingRegardlessOfExpected(
        uint256 seed,
        bytes32 salt,
        bytes32 expected
    ) public pure {
        Commit.Prepared memory p = _sealCertificate(seed, salt);
        bytes32 originalEncoding = keccak256(abi.encode(p));
        assert(keccak256(Seal.encode(p, false, expected)) == originalEncoding);
        assert(keccak256(Seal.encode(p, false, bytes32(0))) == originalEncoding);
        assert(keccak256(Seal.encode(p, false, _originalInventory(p))) == originalEncoding);
    }

    function testFuzzSealCollectReturnsOriginalEncodingForExactInventory(
        uint256 seed,
        bytes32 salt
    ) public pure {
        Commit.Prepared memory p = _sealCertificate(seed, salt);
        bytes32 expected = _originalInventory(p);
        assert(expected != 0);
        assert(Prepared.inventory(p) == expected);
        assert(keccak256(Seal.encode(p, true, expected)) == keccak256(abi.encode(p)));
    }

    function testFuzzSealCollectRejectsZeroAndWrongInventory(uint256 seed, bytes32 salt)
        public
        view
    {
        Commit.Prepared memory p = _sealCertificate(seed, salt);
        bytes32 correct = _originalInventory(p);
        bytes32 wrong = correct == bytes32(uint256(1)) ? bytes32(uint256(2)) : bytes32(uint256(1));
        _reject(
            abi.encodeCall(this.seal, (p, true, bytes32(0))),
            RH.InvalidRecoveredHydrationProfile.selector
        );
        _reject(
            abi.encodeCall(this.seal, (p, true, wrong)),
            RH.InvalidRecoveredHydrationProfile.selector
        );
    }

    function testAllEntryPointsRejectZeroAndMultipleSubjectsBeforeAdmission() public view {
        for (uint256 artists; artists < 3; ++artists) {
            for (uint256 collections; collections < 3; ++collections) {
                if (artists == 1 && collections == 1) continue;
                _entryPointsReject(artists, collections, T.UnsupportedProfile.selector);
            }
        }
    }

    function testWellShapedEntryPointsReachAdmissionRead() public view {
        _entryPointsReject(1, 1, AdmissionReadReached.selector);
    }

    /// @dev Only the fixed preparation worker is mocked. This proves the four facade routes
    /// preserve arguments and the full declared return ABI, not source or inventory validation.
    function testMockedVeneerReturnsExactPreparedTupleAcrossEveryOverload() public {
        Commit.Prepared memory expected = _inventory(193, keccak256("veneer tuple sentinel"));
        expected.admission.prior = address(0x101);
        expected.admission.sourceCoordinator = address(0x102);
        expected.admission.source.registry = address(0x103);
        expected.admission.source.owners[2] = address(0x104);
        expected.admission.before_[2].revision = 37;
        expected.admission.artists = new AH.Query[](1);
        expected.admission.artists[0] = expected.query;
        expected.admission.collections = new AH.Query[](1);
        expected.admission.collections[0] = expected.query;
        bytes32 expectedBytes = keccak256(abi.encode(expected, keccak256("facade completed")));
        (T.SuiteConfiguration memory destination, RH.Request memory request) = _veneerInput();
        T.RoyaltyFreeze[] memory terms = _veneerTerms();
        for (uint8 route; route < 4; ++route) {
            bytes memory workerInput = _workerInput(destination, request, terms, route);
            // encode returns bytes containing abi.encode(Prepared), so its own return ABI
            // has an additional bytes envelope which the facade must unwrap exactly once.
            vm.mockCall(address(Preparation), workerInput, abi.encode(abi.encode(expected)));
            vm.expectCall(address(Preparation), workerInput, 1);
            (bool ok, bytes memory actual) = address(this)
                .staticcall(abi.encodeCall(this.veneerResult, (destination, request, terms, route)));
            // The separate caller must append its completion marker after the facade call.
            // An unintended terminal return from that caller cannot skip this assertion.
            assert(ok && keccak256(actual) == expectedBytes);
            vm.clearMockedCalls();
        }
    }

    /// @dev Mocked facade boundary only: no real preparation-stage rejection is claimed here.
    function testMockedVeneerBubblesExactWorkerRevertAcrossEveryOverload() public {
        (T.SuiteConfiguration memory destination, RH.Request memory request) = _veneerInput();
        T.RoyaltyFreeze[] memory terms = _veneerTerms();
        bytes memory expected = abi.encodeWithSelector(
            RH.InvalidRecoveredHydrationPoint.selector,
            keccak256("original rejection"),
            uint8(6),
            uint64(99)
        );
        for (uint8 route; route < 4; ++route) {
            bytes memory workerInput = _workerInput(destination, request, terms, route);
            vm.mockCallRevert(address(Preparation), workerInput, expected);
            vm.expectCall(address(Preparation), workerInput, 1);
            bytes memory input;
            if (route == 0) {
                input = abi.encodeCall(this.prepareTwo, (destination, request));
            } else if (route == 1) {
                input = abi.encodeCall(this.collectTwo, (destination, request));
            } else if (route == 2) {
                input = abi.encodeCall(this.prepareThree, (destination, request, terms));
            } else {
                input = abi.encodeCall(this.collectThree, (destination, request, terms));
            }
            (bool ok, bytes memory reason) = address(this).staticcall(input);
            assert(!ok && keccak256(reason) == keccak256(expected));
            vm.clearMockedCalls();
        }
    }

    function prepareTwo(T.SuiteConfiguration memory destination, RH.Request memory request)
        external
        view
        returns (bytes32)
    {
        return Prepared.inventory(Prepared.prepare(destination, request));
    }

    function veneerResult(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory terms,
        uint8 route
    ) external view returns (Commit.Prepared memory result, bytes32 completion) {
        if (route == 0) result = Prepared.prepare(destination, request);
        else if (route == 1) result = Prepared.collect(destination, request);
        else if (route == 2) result = Prepared.prepare(destination, request, terms);
        else result = Prepared.collect(destination, request, terms);
        completion = keccak256("facade completed");
    }

    function prepareThree(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory terms
    ) external view returns (bytes32) {
        return Prepared.inventory(Prepared.prepare(destination, request, terms));
    }

    function collectTwo(T.SuiteConfiguration memory destination, RH.Request memory request)
        external
        view
        returns (bytes32)
    {
        return Prepared.inventory(Prepared.collect(destination, request));
    }

    function collectThree(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory terms
    ) external view returns (bytes32) {
        return Prepared.inventory(Prepared.collect(destination, request, terms));
    }

    function features(IH.Bundle memory identity, P.Bundle memory payout, uint256 eras)
        external
        pure
        returns (uint256)
    {
        return Prepared.requiredFeatures(identity, payout, eras);
    }

    function seal(Commit.Prepared memory p, bool requireInventory, bytes32 expected)
        external
        pure
        returns (bytes memory)
    {
        return Seal.encode(p, requireInventory, expected);
    }

    function originalFeatures(IH.Bundle memory identity, P.Bundle memory payout, uint256 eras)
        external
        pure
        returns (uint256)
    {
        return _originalFeatures(identity, payout, eras);
    }

    function _entryPointsReject(uint256 artists, uint256 collections, bytes4 expected)
        private
        view
    {
        T.SuiteConfiguration memory destination;
        destination.owners[2] = address(this);
        RH.Request memory request;
        request.records.authority.artistIds = new bytes32[](artists);
        for (uint256 i; i < artists; ++i) {
            request.records.authority.artistIds[i] = bytes32(i + 1);
        }
        request.records.authority.collections = new MH.Collection[](collections);
        for (uint256 i; i < collections; ++i) {
            request.records.authority.collections[i].artistId = bytes32(uint256(1));
            request.records.authority.collections[i].collectionId = i + 1;
        }
        T.RoyaltyFreeze[] memory terms = new T.RoyaltyFreeze[](1);
        terms[0].expectedAssignmentHash = keccak256("invalid royalty witness");
        _reject(abi.encodeCall(this.prepareTwo, (destination, request)), expected);
        _reject(abi.encodeCall(this.collectTwo, (destination, request)), expected);
        _reject(abi.encodeCall(this.prepareThree, (destination, request, terms)), expected);
        _reject(abi.encodeCall(this.collectThree, (destination, request, terms)), expected);
    }

    function _veneerInput()
        private
        pure
        returns (T.SuiteConfiguration memory destination, RH.Request memory request)
    {
        destination.registry = address(0x201);
        destination.archive = address(0x202);
        destination.core = address(0x203);
        destination.primaryResolver = address(0x204);
        destination.royaltyResolver = address(0x205);
        destination.primaryRevenueClass = keccak256("forwarded revenue class");
        for (uint8 i; i < 7; ++i) {
            destination.owners[i] = address(uint160(0x210 + uint256(i)));
            request.expectedCapabilities[i].ownerIndex = i;
            request.expectedCapabilities[i].supportedFeatures = 511;
            request.expectedCapabilities[i].profile = keccak256(abi.encode("capability", i));
            request.records.authority.expectedSource[i].ownerState.revision = uint64(20 + i);
        }
        request.records.authority.bindingIndex = 7;
        request.records.authority.artistIds = new bytes32[](1);
        request.records.authority.artistIds[0] = keccak256("forwarded artist");
        request.records.authority.collections = new MH.Collection[](1);
        request.records.authority.collections[0].artistId = request.records.authority.artistIds[0];
        request.records.authority.collections[0].collectionId = 981;
        request.records.authority.collections[0].policies = new AH.PolicyKey[](1);
        request.records.authority.collections[0].policies[0] =
            AH.PolicyKey(keccak256("phase"), keccak256("policy"));
        request.records.authority.replayOrigins[2] = new AH.Origin[](1);
        request.records.authority.replayOrigins[2][0] =
            AH.Origin(keccak256("surface"), keccak256("scope"));
        request.expectedSourceImportCommitment = keccak256("forwarded import");
        request.expectedSemanticInventory = keccak256("forwarded expected inventory");
    }

    function _veneerTerms() private pure returns (T.RoyaltyFreeze[] memory terms) {
        terms = new T.RoyaltyFreeze[](2);
        for (uint256 i; i < terms.length; ++i) {
            terms[i] = T.RoyaltyFreeze(
                address(uint160(0x301 + i)),
                981 + i,
                keccak256(abi.encode("revenue", i)),
                keccak256(abi.encode("assignment", i))
            );
        }
    }

    function _workerInput(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory terms,
        uint8 route
    ) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            Preparation.encode.selector,
            destination,
            request,
            route < 2 ? new T.RoyaltyFreeze[](0) : terms,
            (route & 1) != 0
        );
    }

    function _featureReject(
        IH.Bundle memory identity,
        P.Bundle memory payout,
        uint256 eras,
        bytes4 expected
    ) private view {
        _reject(abi.encodeCall(this.features, (identity, payout, eras)), expected);
        _reject(abi.encodeCall(this.originalFeatures, (identity, payout, eras)), expected);
    }

    function _reject(bytes memory input, bytes4 expected) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(input);
        assert(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(expected)));
    }

    function _originalFeatures(IH.Bundle memory identity, P.Bundle memory payout, uint256 eras)
        private
        pure
        returns (uint256 result)
    {
        result = _originalClass(identity.identity.authorityClass);
        for (uint256 i; i < identity.recoveries.length; ++i) {
            result |= _originalClass(identity.recoveries[i].record.fields.vestedAuthorityClass);
        }
        for (uint256 i; i < identity.actions.length; ++i) {
            if (identity.actions[i].evidenceV2.manifestHash != 0) result |= 4;
            if (identity.actions[i].evidenceV3.manifestHash != 0) result |= 8;
        }
        if (
            identity.revisionContinuations.length != 0 || identity.standingContinuations.length != 0
                || identity.capabilityContinuations.length != 0 || payout.continuations.length != 0
        ) result |= 8;
        if (eras > 1) result |= 16;
        if (eras == 0 || eras > 16) revert RH.InvalidRecoveredHydrationProfile();
    }

    function _originalClass(uint8 authorityClass) private pure returns (uint256) {
        if (authorityClass == 1) return 1;
        if (authorityClass == 3) return 2;
        revert T.UnsupportedProfile();
    }

    function _originalInventory(Commit.Prepared memory p) private pure returns (bytes32) {
        bytes32 provenance = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"),
                uint16(1),
                p.admission.provenance
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"),
                uint16(1),
                provenance,
                p.query,
                p.data,
                p.timing,
                p.externalGuards
            )
        );
    }

    function _sealCertificate(uint256 seed, bytes32 salt)
        private
        pure
        returns (Commit.Prepared memory p)
    {
        p = _inventory(seed, salt);
        // Include admission fields outside the inventory: the seal must preserve their
        // original tuple encoding too, without confusing them with the inventory preimage.
        p.admission.prior = address(uint160(seed));
        p.admission.sourceCoordinator = address(0x5102);
        p.admission.source.registry = address(0x5103);
        p.admission.source.owners[2] = address(0x5104);
        p.admission.before_[2].stateRoot = salt;
        p.admission.artists = new AH.Query[](1);
        p.admission.artists[0] = p.query;
        p.admission.collections = new AH.Query[](1);
        p.admission.collections[0] = p.query;
    }

    function _inventory(uint256 seed, bytes32 salt)
        private
        pure
        returns (Commit.Prepared memory p)
    {
        p.admission.provenance.origins = new RH.OriginEnvironment[](1);
        p.admission.provenance.origins[0].chainId = seed;
        p.admission.provenance.eras = new RH.Era[](1);
        p.admission.provenance.eras[0].priorImportCommitment = salt;
        p.query.artistId = salt;
        p.query.collectionId = seed;
        p.query.bindingHash = keccak256(abi.encode(seed, salt));
        p.query.policies = new AH.PolicyKey[](1);
        p.query.policies[0] = AH.PolicyKey(salt, p.query.bindingHash);
        p.query.records = new bytes32[](1);
        p.query.records[0] = salt;
        for (uint8 i; i < 7; ++i) {
            p.admission.provenance.journals[i] = new RH.JournalEntry[](1);
            p.admission.provenance.journals[i][0].receipt.recordHash = salt;
            p.admission.provenance.journals[i][0].position.point.ownerRevision = uint64(seed);
            p.admission.provenance.aliases[i] = new RH.ReplayAlias[](1);
            p.admission.provenance.aliases[i][0].originalKey = keccak256(abi.encode(salt, i));
            p.admission.provenance.aliases[i][0].ownerIndex = i;
            p.data[i].typedState = abi.encode(seed, salt, i);
            p.data[i].origins = new AH.Origin[](1);
            p.data[i].origins[0] = AH.Origin(salt, bytes32(uint256(i)));
            p.data[i].sourceKeys = new bytes32[](1);
            p.data[i].sourceKeys[0] = salt;
            p.data[i].cells = new T.ReplayCell[](1);
            p.data[i].cells[0] = T.ReplayCell(salt, uint64(seed), 1, 2);
            p.data[i].nonces = new AH.NonceWord[](1);
            p.data[i].nonces[0].prefix = seed;
            p.data[i].nonces[0].words[seed % 32] = uint256(salt);
            p.data[i].nonces[0].exhausted = ((seed >> i) & 1) != 0;
        }
        p.timing.schema = salt;
        p.timing.version = uint16(seed);
        p.timing.count = uint64(seed);
        p.timing.root = p.query.bindingHash;
        p.timing.configurationHash = salt;
        p.externalGuards.schema = salt;
        p.externalGuards.provenanceCommitment = p.query.bindingHash;
        p.externalGuards.artistId = salt;
        p.externalGuards.actions = new External.ActionGuard[](1);
        p.externalGuards.actions[0].facts.callHash = p.query.bindingHash;
        p.externalGuards.finality = new External.FinalityGuard[](1);
        p.externalGuards.finality[0].findingRecordHash = salt;
        p.externalGuards.entropy = new External.EntropyGuard[](1);
        p.externalGuards.entropy[0].evidence.intentHash = salt;
    }
}
