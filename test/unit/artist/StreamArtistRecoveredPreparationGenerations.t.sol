// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPreparationGenerations as Stage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationGenerations.sol";
import {
    StreamArtistRecoveredPreparationGenerationFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationGenerationFacts.sol";
import {
    StreamArtistRecoveredBindingGenerationFactRows as Rows
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerationFactRows.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredPreparationSelection as Selection
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPreparationSelection.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";

interface PreparationGenerationsVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function expectCall(address target, bytes calldata input, uint64 count) external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Only these two real, controlled getter surfaces are available to the stage.
contract PreparationGenerationSource {
    uint256 private immutable collection;
    bool private immutable bindingSurface;
    T.Binding private current;
    uint8 private state;
    uint64 private attributionGeneration;
    bool private rejectAttribution;

    error UnexpectedSourceRead();

    constructor(uint256 collection_, uint64 generation_, uint8 mode_, bool bindingSurface_) {
        collection = collection_;
        bindingSurface = bindingSurface_;
        current.generation = generation_;
        current.consentMode = mode_;
        state = 2;
        attributionGeneration = generation_;
    }

    function setAttribution(uint8 state_, uint64 generation_, bool reject_) external {
        state = state_;
        attributionGeneration = generation_;
        rejectAttribution = reject_;
    }

    function binding(uint256 collectionId) external view returns (T.Binding memory) {
        if (collectionId != collection || !bindingSurface) revert UnexpectedSourceRead();
        return current;
    }

    function attributionState(uint256 collectionId) external view returns (uint8, uint64) {
        if (collectionId != collection || bindingSurface || rejectAttribution) {
            revert UnexpectedSourceRead();
        }
        return (state, attributionGeneration);
    }

    fallback() external {
        revert UnexpectedSourceRead();
    }
}

/// @notice Component guards, fixed worker transport, projections and cached mode selection.
/// @dev All proof-worker boundaries are explicitly synthetic mocks. These tests execute the
/// real stage and controlled source getters; they do not establish authenticated history,
/// Guards admission, complete Prepared owner ordering, or seven-owner hydration acceptance.
contract StreamArtistRecoveredPreparationGenerationsTest {
    PreparationGenerationsVm private constant vm =
        PreparationGenerationsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Fixture {
        T.SuiteConfiguration source;
        AH.Query query;
        RH.Provenance provenance;
        bytes identity;
        Generations.Bundle generations;
    }

    error UnexpectedCollector();
    error UnexpectedFacts();
    error UnexpectedRows();
    error SyntheticWorkerFailure(uint256 marker);

    function testFuzzGenerationZeroAndOneReturnBeforeAllGuards(bool one, uint8 mode) public {
        Fixture memory f = _fixture(one ? 1 : 0, mode);
        // Deliberately malformed identity and disallowed later inputs must remain unread.
        f.identity = hex"ff";
        f.provenance.journals[6][0].receipt.operation = 21;
        _blockWorkers(f);
        vm.expectCall(
            f.source.owners[0], abi.encodeCall(Binding.binding, (f.query.collectionId)), 1
        );
        (bytes memory encoded, uint8 actualMode, bool hasGenerations) =
            Stage.collect(f.source, f.query, f.provenance, f.identity, true, 1, 1);
        assert(encoded.length == 0 && actualMode == mode && !hasGenerations);
    }

    function testFuzzGenerationRejectsWrongModeBeforeCollector(uint8 mode) public {
        if (mode == 1) mode = 0;
        Fixture memory f = _fixture(2, mode);
        _blockWorkers(f);
        _reject(f, false, 0, 0, abi.encodeWithSelector(T.UnsupportedProfile.selector));
    }

    function testGenerationRejectsDelegationsBeforeCollector() public {
        Fixture memory f = _fixture(2, 1);
        _blockWorkers(f);
        _reject(f, true, 0, 0, abi.encodeWithSelector(T.UnsupportedProfile.selector));
    }

    function testFuzzGenerationRejectsWitnessesBeforeCollector(uint256 count) public {
        if (count == 0) count = 1;
        Fixture memory f = _fixture(2, 1);
        _blockWorkers(f);
        _reject(f, false, count, 0, abi.encodeWithSelector(T.UnsupportedProfile.selector));
    }

    function testFuzzGenerationRejectsRoyaltyTermsBeforeCollector(uint256 count) public {
        if (count == 0) count = 1;
        Fixture memory f = _fixture(2, 1);
        _blockWorkers(f);
        _reject(f, false, 0, count, abi.encodeWithSelector(T.UnsupportedProfile.selector));
    }

    function testFuzzGenerationRejectsEveryNonPolicyOperationBeforeCollector(
        uint16 operation,
        uint8 position
    ) public {
        if (operation == 14) operation = 15;
        Fixture memory f = _fixture(2, 1);
        f.provenance.journals[6] = new RH.JournalEntry[](4);
        for (uint256 i; i < 4; ++i) {
            f.provenance.journals[6][i].receipt.operation = 14;
        }
        f.provenance.journals[6][position % 4].receipt.operation = operation;
        _blockWorkers(f);
        _reject(f, false, 0, 0, abi.encodeWithSelector(T.UnsupportedProfile.selector));
    }

    function testGenerationSuccessTransportsCompleteTypedArguments() public {
        Fixture memory f = _fixture(2, 1);
        _mockProofWorkers(f);
        _assertSuccess(f);
    }

    function testGenerationSuccessAllowsEmptyOwnerSixJournal() public {
        Fixture memory f = _fixture(2, 1);
        f.provenance.journals[6] = new RH.JournalEntry[](0);
        _mockProofWorkers(f);
        _assertSuccess(f);
    }

    function testGenerationCollectorRevertPrecedesFactsAndAttribution() public {
        Fixture memory f = _fixture(2, 1);
        _blockWorkers(f);
        bytes memory reason = abi.encodeWithSelector(SyntheticWorkerFailure.selector, 10);
        bytes memory input = _collectInput(f);
        vm.mockCallRevert(address(Generations), input, reason);
        vm.expectCall(address(Generations), input, 1);
        _reject(f, false, 0, 0, reason);
    }

    function testGenerationFactsRevertPrecedesAttribution() public {
        Fixture memory f = _fixture(2, 1);
        _mockProofWorkers(f);
        PreparationGenerationSource(f.source.owners[4]).setAttribution(2, 2, true);
        bytes memory reason = abi.encodeWithSelector(SyntheticWorkerFailure.selector, 20);
        vm.mockCallRevert(address(Facts), _factsInput(f), reason);
        _reject(f, false, 0, 0, reason);
    }

    function testFuzzGenerationRejectsWrongAttributionState(uint8 state) public {
        if (state == 2) state = 0;
        Fixture memory f = _fixture(2, 1);
        _mockProofWorkers(f);
        PreparationGenerationSource(f.source.owners[4]).setAttribution(state, 2, false);
        _reject(
            f, false, 0, 0, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
        );
    }

    function testFuzzGenerationRejectsWrongAttributionGeneration(uint64 generation) public {
        if (generation == 2) generation = 0;
        Fixture memory f = _fixture(2, 1);
        _mockProofWorkers(f);
        PreparationGenerationSource(f.source.owners[4]).setAttribution(2, generation, false);
        _reject(
            f, false, 0, 0, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
        );
    }

    function testGenerationAttributionUsesCollectedCurrentGeneration() public {
        Fixture memory f = _fixture(2, 1);
        // Deliberately inconsistent mocked history isolates the comparison operand. Real
        // source admission is the original collector's responsibility and is mocked here.
        f.generations.current.generation = 7;
        PreparationGenerationSource(f.source.owners[4]).setAttribution(2, 7, false);
        _mockProofWorkers(f);
        _assertSuccess(f);
    }

    function testGenerationMissingFactsCodeRejectsBeforeAttribution() public {
        Fixture memory f = _fixture(2, 1);
        vm.mockCall(address(Generations), _collectInput(f), abi.encode(f.generations));
        vm.expectCall(address(Generations), _collectInput(f), 1);
        // The real code-length guard must stop before the Facts staticcall.
        vm.etch(address(Facts), hex"");
        PreparationGenerationSource(f.source.owners[4]).setAttribution(2, 2, true);
        _reject(f, false, 0, 0, hex"");
    }

    function testOwnerZeroEncodeForwardsExactBundleQueryAndProvenance() public {
        Fixture memory f = _fixture(2, 1);
        RH.OwnerProvenance memory owner = _ownerZero(f.provenance);
        bytes memory input =
            abi.encodeWithSelector(Generations.encode.selector, f.generations, f.query, owner);
        bytes memory expected = hex"005529ff001122334455";
        vm.mockCallRevert(
            address(Generations),
            abi.encodePacked(Generations.encode.selector),
            abi.encodeWithSelector(UnexpectedCollector.selector)
        );
        vm.mockCall(address(Generations), input, abi.encode(expected));
        vm.expectCall(address(Generations), input, 1);
        _same(Stage.encode(abi.encode(f.generations), f.query, owner), expected);
    }

    function testOwnerZeroEncodeBubblesOriginalEncoderFailure() public {
        Fixture memory f = _fixture(2, 1);
        RH.OwnerProvenance memory owner = _ownerZero(f.provenance);
        bytes memory input =
            abi.encodeWithSelector(Generations.encode.selector, f.generations, f.query, owner);
        bytes memory reason = abi.encodeWithSelector(SyntheticWorkerFailure.selector, 30);
        vm.mockCallRevert(address(Generations), input, reason);
        vm.expectCall(address(Generations), input, 1);
        (bool ok, bytes memory result) = address(this)
            .staticcall(abi.encodeCall(this.encode, (abi.encode(f.generations), f.query, owner)));
        assert(!ok);
        _same(result, reason);
    }

    function testGenerationFactsProjectsAllConsumedIdentityAndScopeFields() public {
        Fixture memory f = _fixture(2, 1);
        IH.Bundle memory identity = _identity();
        bytes memory input = _rowsInput(f, identity);
        vm.mockCallRevert(
            address(Rows),
            abi.encodePacked(Rows.validateRows.selector),
            abi.encodeWithSelector(UnexpectedRows.selector)
        );
        vm.mockCall(address(Rows), input, hex"");
        vm.expectCall(address(Rows), input, 1);
        Facts.validate(identity, f.generations, f.query, f.provenance);
    }

    function testGenerationFactsBubblesProjectedWorkerFailure() public {
        Fixture memory f = _fixture(2, 1);
        bytes memory reason = abi.encodeWithSelector(SyntheticWorkerFailure.selector, 40);
        bytes memory input = _rowsInput(f, _identity());
        vm.mockCallRevert(address(Rows), input, reason);
        vm.expectCall(address(Rows), input, 1);
        (bool ok, bytes memory result) = address(Facts).staticcall(_factsInput(f));
        assert(!ok);
        _same(result, reason);
    }

    function testFuzzCachedModeSelectionMatchesGetterSelection(
        uint8 mode,
        bool delegated,
        uint16 operation
    ) public {
        Fixture memory f = _fixture(1, mode);
        f.provenance.journals[6][0].receipt.operation = operation;
        vm.expectCall(
            f.source.owners[0], abi.encodeCall(Binding.binding, (f.query.collectionId)), 1
        );
        (uint8 readMode, bool readDelegated, bool readContent) = Selection.flags(
            f.source.owners[0], f.query.collectionId, delegated, f.provenance.journals[6]
        );
        (bool cachedDelegated, bool cachedContent) =
            Selection.flagsForMode(mode, delegated, f.provenance.journals[6]);
        assert(readMode == mode && readDelegated == cachedDelegated && readContent == cachedContent);
        assert(cachedDelegated == (delegated || mode == 2 || operation == 16));
        assert(cachedContent == (operation == 17 || operation == 20 || operation == 21));
    }

    function collect(Fixture memory f, bool delegated, uint256 witnesses, uint256 royalties)
        external
        view
        returns (bytes memory, uint8, bool)
    {
        return Stage.collect(
            f.source, f.query, f.provenance, f.identity, delegated, witnesses, royalties
        );
    }

    function encode(bytes memory encoded, AH.Query memory query, RH.OwnerProvenance memory owner)
        external
        pure
        returns (bytes memory)
    {
        return Stage.encode(encoded, query, owner);
    }

    function _reject(
        Fixture memory f,
        bool delegated,
        uint256 witnesses,
        uint256 royalties,
        bytes memory reason
    ) private view {
        (bool ok, bytes memory result) = address(this)
            .staticcall(abi.encodeCall(this.collect, (f, delegated, witnesses, royalties)));
        assert(!ok);
        _same(result, reason);
    }

    function _assertSuccess(Fixture memory f) private {
        vm.expectCall(
            f.source.owners[4],
            abi.encodeCall(Attribution.attributionState, (f.query.collectionId)),
            1
        );
        (bytes memory encoded, uint8 mode, bool selected) =
            Stage.collect(f.source, f.query, f.provenance, f.identity, false, 0, 0);
        assert(mode == 1 && selected);
        _same(encoded, abi.encode(f.generations));
    }

    function _blockWorkers(Fixture memory f) private {
        vm.mockCallRevert(
            address(Generations),
            abi.encodePacked(Generations.collect.selector),
            abi.encodeWithSelector(UnexpectedCollector.selector)
        );
        vm.mockCallRevert(
            address(Facts),
            abi.encodePacked(Facts.validate.selector),
            abi.encodeWithSelector(UnexpectedFacts.selector)
        );
        PreparationGenerationSource(f.source.owners[4]).setAttribution(2, 2, true);
    }

    function _mockProofWorkers(Fixture memory f) private {
        vm.mockCallRevert(
            address(Generations),
            abi.encodePacked(Generations.collect.selector),
            abi.encodeWithSelector(UnexpectedCollector.selector)
        );
        bytes memory input = _collectInput(f);
        vm.mockCall(address(Generations), input, abi.encode(f.generations));
        vm.expectCall(address(Generations), input, 1);
        vm.mockCallRevert(
            address(Facts),
            abi.encodePacked(Facts.validate.selector),
            abi.encodeWithSelector(UnexpectedFacts.selector)
        );
        input = _factsInput(f);
        vm.mockCall(address(Facts), input, hex"");
        vm.expectCall(address(Facts), input, 1);
    }

    function _collectInput(Fixture memory f) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            Generations.collect.selector, f.source.owners[0], f.query, _ownerZero(f.provenance)
        );
    }

    function _factsInput(Fixture memory f) private pure returns (bytes memory) {
        // Independent typed encoding is the oracle for the stage's raw four-tuple bridge.
        return abi.encodeWithSelector(
            Facts.validate.selector, _identity(), f.generations, f.query, f.provenance
        );
    }

    function _rowsInput(Fixture memory f, IH.Bundle memory identity)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            Rows.validateRows.selector,
            Rows.IdentityRows(identity.artistId, identity.documents, identity.signatures),
            f.generations,
            Rows.Scope(f.query.artistId, f.query.collectionId, f.query.bindingHash),
            f.provenance
        );
    }

    function _ownerZero(RH.Provenance memory p)
        private
        pure
        returns (RH.OwnerProvenance memory owner)
    {
        // Spell out the projection independently of the production ownerProvenance helper.
        owner.origins = p.origins;
        owner.eras = new RH.OwnerEra[](p.eras.length);
        for (uint256 i; i < p.eras.length; ++i) {
            owner.eras[i].originHash = p.eras[i].originHash;
            owner.eras[i].checkpoint = p.eras[i].checkpoints[0];
            owner.eras[i].nativeCount = p.eras[i].nativeCounts[0];
            owner.eras[i].lowerRevision = p.eras[i].lowerRevisions[0];
            owner.eras[i].priorImportCommitment = p.eras[i].priorImportCommitment;
        }
        owner.journal = p.journals[0];
        owner.aliases = p.aliases[0];
    }

    function _fixture(uint64 generation, uint8 mode) private returns (Fixture memory f) {
        f.query.artistId = bytes32(uint256(101));
        f.query.collectionId = 202;
        f.query.bindingHash = bytes32(uint256(303));
        f.query.policies = new AH.PolicyKey[](2);
        f.query.policies[0] = AH.PolicyKey(bytes32(uint256(401)), bytes32(uint256(402)));
        f.query.policies[1] = AH.PolicyKey(bytes32(uint256(403)), bytes32(uint256(404)));
        f.query.records = new bytes32[](2);
        f.query.records[0] = bytes32(uint256(501));
        f.query.records[1] = bytes32(uint256(502));
        for (uint256 i; i < 7; ++i) {
            f.source.owners[i] = address(uint160(0xa000 + i));
        }
        f.source.owners[0] = address(new PreparationGenerationSource(202, generation, mode, true));
        f.source.owners[4] = address(new PreparationGenerationSource(202, generation, mode, false));
        f.provenance = _provenance();
        f.identity = abi.encode(_identity());
        f.generations.artistId = f.query.artistId;
        f.generations.collectionId = f.query.collectionId;
        f.generations.bindingHash = f.query.bindingHash;
        f.generations.provenanceCommitment = bytes32(uint256(601));
        f.generations.current = T.Binding(
            f.query.artistId,
            address(0x701),
            bytes32(uint256(702)),
            f.query.bindingHash,
            generation,
            mode,
            2,
            1,
            address(0x703),
            true
        );
        f.generations.rows = new Generations.Row[](2);
        for (uint256 i; i < 2; ++i) {
            f.generations.rows[i].item = T.Binding(
                f.query.artistId,
                address(0x701),
                bytes32(uint256(702)),
                f.query.bindingHash,
                uint64(i + 1),
                mode,
                2,
                1,
                address(0x703),
                true
            );
            f.generations.rows[i].terms.collaboratorSetHash = bytes32(uint256(801 + i));
            f.generations.rows[i].terms.capabilityPolicySetHash = bytes32(uint256(811 + i));
            f.generations.rows[i].terms.mode = uint8(i + 1);
            f.generations.rows[i].terms.threshold = uint32(i + 2);
            f.generations.rows[i].terms.count = uint32(i + 3);
            f.generations.rows[i].terminal.kind = uint8(i + 1);
            f.generations.rows[i].terminal.reasonHash = bytes32(uint256(821 + i));
            f.generations.rows[i].terminal.recordHash = bytes32(uint256(831 + i));
        }
    }

    function _identity() private pure returns (IH.Bundle memory identity) {
        identity.artistId = bytes32(uint256(101));
        identity.identity.authorityAddress = address(0x901);
        identity.identity.authorityClass = 1;
        identity.identity.status = 1;
        identity.identity.identityRecordURI = "synthetic identity URI";
        identity.identity.displayName = "synthetic source";
        identity.heads.latestTransition = bytes32(uint256(902));
        identity.documents = new IH.DocumentRow[](2);
        identity.documents[0] = IH.DocumentRow(bytes32(uint256(903)), hex"00010203ff");
        identity.documents[1] = IH.DocumentRow(
            bytes32(uint256(904)), bytes("different document with a tail longer than one ABI word")
        );
        identity.signatures = new IH.SignatureRow[](2);
        identity.signatures[0] = IH.SignatureRow(bytes32(uint256(905)), hex"");
        identity.signatures[1] = IH.SignatureRow(bytes32(uint256(906)), hex"deadbeef005529");
    }

    function _provenance() private pure returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 e; e < 2; ++e) {
            p.origins[e].chainId = 1000 + e;
            p.origins[e].registry = address(uint160(1100 + e));
            p.origins[e].coordinator = address(uint160(1200 + e));
            p.origins[e].archive = address(uint160(1300 + e));
            p.origins[e].core = address(uint160(1400 + e));
            p.origins[e].manager = address(uint160(1500 + e));
            p.origins[e].suiteConfigurationHash = bytes32(uint256(1600 + e));
            p.eras[e].originHash = bytes32(uint256(1700 + e));
            p.eras[e].priorImportCommitment = bytes32(uint256(1800 + e));
            for (uint256 i; i < 7; ++i) {
                uint256 marker = 2000 + e * 100 + i * 10;
                p.origins[e].owners[i] = address(uint160(marker));
                p.origins[e].ownerCodeHashes[i] = bytes32(marker + 1);
                p.eras[e].nativeCounts[i] = marker + 2;
                p.eras[e].lowerRevisions[i] = uint64(marker + 3);
                p.eras[e].checkpoints[i].schema = bytes32(marker + 4);
                p.eras[e].checkpoints[i].ownerState = T.Snapshot(
                    bytes32(marker + 5),
                    uint64(marker + 6),
                    bytes32(marker + 7),
                    bytes32(marker + 8)
                );
                p.eras[e].checkpoints[i].replayRoot = bytes32(marker + 9);
                p.eras[e].checkpoints[i].replayCount = marker + 10;
                p.eras[e].checkpoints[i].nonceRoot = bytes32(marker + 11);
                p.eras[e].checkpoints[i].nonceIndexCount = marker + 12;
            }
        }
        for (uint256 i; i < 7; ++i) {
            p.journals[i] = new RH.JournalEntry[](2);
            p.aliases[i] = new RH.ReplayAlias[](1);
            for (uint256 j; j < 2; ++j) {
                p.journals[i][j].position.point =
                    RH.Point(bytes32(uint256(3000 + j)), uint8(i), uint64(3100 + i + j));
                p.journals[i][j].position.nativeIndex = 3200 + i + j;
                p.journals[i][j].receipt.operation = i == 6 ? 14 : uint16(i + j + 1);
                p.journals[i][j].receipt.artistId = bytes32(uint256(101));
                p.journals[i][j].receipt.collectionId = 202;
                p.journals[i][j].receipt.recordHash = bytes32(uint256(3300 + i + j));
            }
            p.aliases[i][0].originHash = bytes32(uint256(3400 + i));
            p.aliases[i][0].ownerIndex = uint8(i);
            p.aliases[i][0].surface = bytes32(uint256(3500 + i));
            p.aliases[i][0].scope = bytes32(uint256(3600 + i));
            p.aliases[i][0].originalKey = bytes32(uint256(3700 + i));
            p.aliases[i][0].cell = T.ReplayCell(bytes32(uint256(3800 + i)), uint64(3900 + i), 1, 2);
            p.aliases[i][0].admittedAt =
                RH.Point(bytes32(uint256(4000 + i)), uint8(i), uint64(4100 + i));
        }
    }

    function _same(bytes memory actual, bytes memory expected) private pure {
        assert(actual.length == expected.length && keccak256(actual) == keccak256(expected));
    }
}
