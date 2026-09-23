// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttributionStateTypes as AS
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { PrimaryPhaseValues } from "./StreamArtistPrimaryCollaboratorPhaseTransport.t.sol";
import { PrimaryTransportValues } from "./StreamArtistPrimaryCollaboratorTransport.t.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyCollection as Collection
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyCollection.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyFinish as Finish
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyFinish.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyFinalization as Finalization
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyFinalization.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorFamilyValidation.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorComposition.sol";
import {
    StreamArtistPrimaryCollaboratorEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorEncoding.sol";
import {
    StreamArtistPrimaryCollaboratorIdentityFacts as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorIdentityFacts.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionRows as Rows
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionRows.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionPrelude as Prelude
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorAttributionPrelude.sol";
import {
    StreamArtistPrimaryCollaboratorCurrentClocks as CurrentClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorCurrentClocks.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionIdentityFacts as SanctionIdentity
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionIdentityFacts.sol";
import {
    StreamArtistRecoveredAggregateRatificationFacts as RatificationFacts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationConservation.sol";
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as Local
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionLocalProof.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as Attribution
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "../../../smart-contracts/domains/artist/StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface PrimarySupplementVm {
    function etch(address, bytes calldata) external;
}

library PrimarySupplementValues {
    function history() internal pure returns (H.Inventory memory h) {
        h.catalogues = new H.Catalogue[](1);
        h.catalogues[0].originHash = keccak256("whole original sanction catalogue");
        h.operations = new H.OperationEvidence[](1);
        h.operations[0].originHash = h.catalogues[0].originHash;
        h.operations[0].operation = 12;
        h.operations[0].evidence.pointer = address(0x6529);
        h.sanctions = new H.SanctionRow[](1);
        h.sanctions[0].point = RH.Point(h.catalogues[0].originHash, 6, 71);
        h.confirmations = new H.ConfirmationRow[](1);
        h.confirmations[0].attributionPoint = RH.Point(h.catalogues[0].originHash, 4, 83);
        h.confirmations[0].consentPoint = RH.Point(h.catalogues[0].originHash, 6, 72);
    }

    function ratifications() internal pure returns (T.RatificationRecord[][] memory r) {
        r = new T.RatificationRecord[][](1);
        r[0] = new T.RatificationRecord[](1);
        r[0][0] = T.RatificationRecord(
            keccak256("original52"), keccak256("complete content state"), address(0x1234)
        );
    }

    function context()
        internal
        pure
        returns (Family.Context memory c, Collection.Result memory rows)
    {
        (c, rows) = PrimaryPhaseValues.family();
        rows.ratifications = ratifications();
    }

    function encoding(Family.Context memory c, Collection.Result memory rows)
        internal
        pure
        returns (Encoding.Context memory)
    {
        return Encoding.Context(
            1,
            c.source.features,
            c.proof,
            c.proof.accepted,
            rows.consents,
            rows.attestations,
            c.history
        );
    }
}

/// @dev Explicit typed boundaries. Every full calldata word and same-host phase order is checked.
contract PrimarySupplementStep {
    bytes32 immutable expected;
    uint256 immutable before_;
    uint256 immutable after_;
    uint256 immutable phase;
    error ForcedSupplementPhase(uint256 phase);

    constructor(bytes32 expected_, uint256 beforeValue, uint256 afterValue, uint256 phase_) {
        expected = expected_;
        before_ = beforeValue;
        after_ = afterValue;
        phase = phase_;
    }

    fallback(bytes calldata raw) external returns (bytes memory) {
        require(keccak256(raw) == expected, "complete original calldata");
        bytes32 step = keccak256("primary.current.test.step");
        bytes32 fail = keccak256("primary.current.test.fail");
        uint256 n;
        uint256 refused;
        assembly ("memory-safe") {
            n := sload(step)
            refused := sload(fail)
        }
        require(n == before_, "original phase order");
        if (refused == phase) revert ForcedSupplementPhase(phase);
        n = after_;
        assembly ("memory-safe") { sstore(step, n) }
        // This boundary returns void. Dynamic return boundaries below own immutable code-only results.
        return bytes("");
    }
}

contract PrimarySupplementCollection {
    bytes32 immutable historyHash;

    constructor(bytes32 h) {
        historyHash = h;
    }

    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Collection.collect.selector, "collection selector");
        (bytes memory context, bytes memory history) = abi.decode(raw[4:], (bytes, bytes));
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        require(
            keccak256(context) == keccak256(abi.encode(c)) && keccak256(history) == historyHash,
            "entire original Context and Inventory"
        );
        return abi.encode(abi.encode(rows));
    }
}

contract PrimarySupplementFinish {
    bytes32 immutable historyHash;

    constructor(bytes32 h) {
        historyHash = h;
    }

    fallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sig == Finish.finish.selector, "finish selector");
        (bytes memory context, bytes memory observed, bytes memory history) =
            abi.decode(raw[4:], (bytes, bytes, bytes));
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        require(
            keccak256(context) == keccak256(abi.encode(c))
                && keccak256(observed) == keccak256(abi.encode(rows))
                && keccak256(history) == historyHash,
            "full collected matrix and sanction carrier"
        );
        Composition.Result memory r;
        r.inventory = history;
        r.features = 6529;
        return abi.encode(abi.encode(r));
    }
}

contract PrimarySupplementClock {
    bytes32 immutable expected;

    constructor(bytes32 h) {
        expected = h;
    }

    fallback(bytes calldata raw) external returns (bytes memory) {
        require(keccak256(raw) == expected, "whole original scope and proof");
        bytes32 step = keccak256("primary.current.test.step");
        uint256 n;
        assembly ("memory-safe") { n := sload(step) }
        require(n == 1, "local before source");
        assembly ("memory-safe") { sstore(step, 2) }
        return abi.encode(PrimaryTransportValues.result().clocks);
    }
}

/// @notice Real current fixed workers with explicit typed authority/source/semantic boundaries.
/// These are transport/order regressions, not an actual sanction ceremony or operation60 import.
contract StreamArtistPrimaryCollaboratorSupplementsTest {
    PrimarySupplementVm private constant vm =
        PrimarySupplementVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _set(uint256 n, uint256 fail) private {
        bytes32 a = keccak256("primary.current.test.step");
        bytes32 b = keccak256("primary.current.test.fail");
        assembly ("memory-safe") {
            sstore(a, n)
            sstore(b, fail)
        }
    }

    function _step() private view returns (uint256 n) {
        bytes32 a = keccak256("primary.current.test.step");
        assembly ("memory-safe") { n := sload(a) }
    }

    function _call(address target, bytes memory input) private returns (bytes memory raw) {
        bool ok;
        (ok, raw) = target.delegatecall(input);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
    }

    function _refusal(address target, bytes memory input, uint256 phase) private {
        (bool ok, bytes memory reason) = target.delegatecall(input);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            PrimarySupplementStep.ForcedSupplementPhase.selector, phase
                        )
                    ),
            "exact forced phase refusal"
        );
        require(_step() == 0, "all earlier phase effects roll back");
    }

    function _install(
        address target,
        bytes memory input,
        uint256 before_,
        uint256 after_,
        uint256 phase
    ) private {
        vm.etch(
            target,
            address(new PrimarySupplementStep(keccak256(input), before_, after_, phase)).code
        );
    }

    function testRatifiedEncodingRetainsLiteralOriginalAndSupplementBytes() public {
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        Encoding.Context memory x = PrimarySupplementValues.encoding(c, rows);
        Composition.Result memory plain = Encoding.encode(x);
        require(
            keccak256(plain.consents[0]) == keccak256(abi.encode(rows.consents[0])),
            "empty supplement retains exact original"
        );
        Composition.Result memory expected = abi.decode(abi.encode(plain), (Composition.Result));
        expected.consents[0] = abi.encode(
            keccak256("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1"),
            uint16(1),
            Supplement.Bundle(rows.consents[0], rows.ratifications[0], new bytes(0))
        );
        expected.features |= RH.RATIFICATIONS;
        Composition.Result memory actual = Encoding.encodeRatified(x, rows.ratifications);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)),
            "complete independently assembled result"
        );
        T.RatificationRecord[][] memory wrong = new T.RatificationRecord[][](0);
        (bool ok, bytes memory reason) = address(Encoding)
            .delegatecall(abi.encodeWithSelector(Encoding.encodeRatified.selector, x, wrong));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "exact outer matrix bound"
        );
        require(
            keccak256(abi.encode(Encoding.encodeRatified(x, rows.ratifications)))
                == keccak256(abi.encode(expected)),
            "identical matrix restored"
        );
    }

    function testBothFamilyOverloadsRetainWholeSanctionsAndEmptySanctionsRatifications() public {
        bytes memory oldCollection = address(Collection).code;
        bytes memory oldFinish = address(Finish).code;
        (Family.Context memory c,) = PrimarySupplementValues.context();
        H.Inventory memory h;
        for (uint256 i; i < 2; ++i) {
            if (i == 1) h = PrimarySupplementValues.history();
            bytes memory encoded = abi.encode(h);
            vm.etch(
                address(Collection),
                address(new PrimarySupplementCollection(keccak256(encoded))).code
            );
            vm.etch(address(Finish), address(new PrimarySupplementFinish(keccak256(encoded))).code);
            Composition.Result memory actual = i == 0 ? Family.collect(c) : Family.collect(c, h);
            require(
                actual.features == 6529 && keccak256(actual.inventory) == keccak256(encoded),
                "both original nominal overloads retain complete arguments"
            );
            require(
                keccak256(Family.encodedSupplemented(abi.encode(c, h)))
                    == keccak256(abi.encode(actual)),
                "encoded call matches original overload"
            );
        }
        vm.etch(address(Collection), oldCollection);
        vm.etch(address(Finish), oldFinish);
    }

    /// @dev Independent original eager H.Inventory decoder, including otherwise unused narrow fields.
    function historicalInventoryHash(bytes calldata pair) external pure returns (bytes32) {
        uint256 at;
        assembly ("memory-safe") { at := calldataload(add(pair.offset, 32)) }
        H.Inventory memory value =
            abi.decode(bytes.concat(bytes32(uint256(32)), pair[at:]), (H.Inventory));
        return keccak256(abi.encode(value));
    }

    function testSecondInventoryEagerDomainPaddedEncodingAndRestoredRetry() public {
        bytes memory oldCollection = address(Collection).code;
        bytes memory oldFinish = address(Finish).code;
        (Family.Context memory c,) = PrimarySupplementValues.context();
        H.Inventory memory h = PrimarySupplementValues.history();
        bytes32 expected = keccak256(abi.encode(h));
        vm.etch(address(Collection), address(new PrimarySupplementCollection(expected)).code);
        vm.etch(address(Finish), address(new PrimarySupplementFinish(expected)).code);
        bytes memory healthy = abi.encode(c, h);
        bytes memory output = Family.encodedSupplemented(healthy);
        require(
            this.historicalInventoryHash(healthy) == expected, "original typed Inventory control"
        );
        bytes memory dirty = abi.encode(c, h);
        // Inventory.operations[0].evidence.pointer: four dynamic Inventory fields,
        // then an array length and the original six-word OperationEvidence element.
        assembly ("memory-safe") {
            let data := add(dirty, 32)
            let history := add(data, mload(add(data, 32)))
            let operations := add(history, mload(add(history, 32)))
            let pointer := add(operations, 128)
            mstore(pointer, or(mload(pointer), shl(160, 1)))
        }
        (bool original, bytes memory originalError) =
            address(this).call(abi.encodeWithSelector(this.historicalInventoryHash.selector, dirty));
        require(
            !original && originalError.length == 0,
            "original narrow address decoder rejects dirty high bits"
        );
        (bool accepted, bytes memory actualError) = address(Family)
            .delegatecall(abi.encodeWithSelector(Family.encodedSupplemented.selector, dirty));
        require(
            !accepted && actualError.length == 0,
            "whole second Inventory rejects before typed phase errors"
        );
        bytes memory padded = new bytes(healthy.length + 32);
        assembly ("memory-safe") {
            mstore(add(padded, 32), add(mload(add(healthy, 32)), 32))
            mstore(add(padded, 64), add(mload(add(healthy, 64)), 32))
        }
        for (uint256 i = 64; i < healthy.length; ++i) {
            padded[i + 32] = healthy[i];
        }
        require(this.historicalInventoryHash(padded) == expected, "original accepts tuple padding");
        require(
            keccak256(Family.encodedSupplemented(padded)) == keccak256(output),
            "both original arguments normalize padding"
        );
        require(
            keccak256(Family.encodedSupplemented(healthy)) == keccak256(output),
            "identical healthy request restored"
        );
        vm.etch(address(Collection), oldCollection);
        vm.etch(address(Finish), oldFinish);
    }

    function testValidationPreservesIdentityOrderAndSupplementedConservationPrecedence() public {
        address[4] memory targets = [
            address(Identity),
            address(SanctionIdentity),
            address(RatificationFacts),
            address(Conservation)
        ];
        bytes[4] memory old;
        for (uint256 i; i < 4; ++i) {
            old[i] = targets[i].code;
        }
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        Validation.Context memory x = Validation.Context(
            c.source.identities,
            c.source.scope,
            c.proof.bindings,
            c.proof.archive,
            c.observed.clocks.primary,
            c.source.provenance,
            c.observed.generations,
            rows.consents,
            rows.attestations
        );
        Identity.Context memory identity =
            Identity.Context(x.identities, x.scope, x.bindings, x.archive, x.primary, x.provenance);
        Conservation.Context memory conservation = Conservation.Context(
            x.identities, x.scope, x.consents, x.attestations, x.generations, x.provenance
        );
        for (uint256 mode; mode < 3; ++mode) {
            H.Inventory memory h;
            if (mode == 2) h = PrimarySupplementValues.history();
            T.RatificationRecord[][] memory rats = rows.ratifications;
            if (mode == 0) {
                rats = new T.RatificationRecord[][](1);
                rats[0] = new T.RatificationRecord[](0);
            }
            _install(
                targets[0], abi.encodeWithSelector(Identity.validate.selector, identity), 0, 1, 1
            );
            uint256 next = 1;
            if (mode == 2) {
                _install(
                    targets[1],
                    abi.encodeWithSelector(
                        SanctionIdentity.validate.selector, x.identities, x.scope, h, x.provenance
                    ),
                    next,
                    next + 1,
                    2
                );
                ++next;
            }
            if (mode != 0) {
                _install(
                    targets[2],
                    abi.encodeWithSelector(
                        RatificationFacts.validate.selector,
                        x.identities,
                        x.scope,
                        x.provenance,
                        rats
                    ),
                    next,
                    next + 1,
                    3
                );
                ++next;
            }
            bytes4 selected = mode == 2
                ? Conservation.validateSupplemented.selector
                : mode == 1
                    ? Conservation.validateRatified.selector
                    : Conservation.validate.selector;
            _install(targets[3], abi.encodeWithSelector(selected, conservation), next, next + 1, 4);
            bytes memory call_ = abi.encodeWithSelector(Validation.validate.selector, x, h, rats);
            _set(0, 0);
            _call(address(Validation), call_);
            require(_step() == next + 1, "complete required branch and ordered phases");
            _set(0, 4);
            _refusal(address(Validation), call_, 4);
            _set(0, 0);
            _call(address(Validation), call_);
            require(_step() == next + 1, "same complete request retry");
        }
        for (uint256 i; i < 4; ++i) {
            vm.etch(targets[i], old[i]);
        }
    }

    function testLateCatalogueRefusalAndRestoredFullSanctionRatificationCarriers() public {
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        H.Inventory memory h = PrimarySupplementValues.history();
        Composition.Result memory plain =
            Encoding.encodeRatified(PrimarySupplementValues.encoding(c, rows), rows.ratifications);
        Composition.Result memory expected = abi.decode(abi.encode(plain), (Composition.Result));
        expected.consents[0] = abi.encode(
            keccak256("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1"),
            uint16(1),
            Supplement.Bundle(rows.consents[0], rows.ratifications[0], abi.encode(h))
        );
        expected.attribution[0] = abi.encode(
            keccak256("6529STREAM_ARTIST_AGGREGATE_SANCTION_ATTRIBUTION_V1"),
            uint16(1),
            plain.attribution[0],
            h
        );
        expected.features |= RH.SANCTION_HISTORY;
        bytes memory old = address(Catalogue).code;
        _install(
            address(Catalogue),
            abi.encodeWithSelector(
                Catalogue.requireCurrent.selector, c.source.provenance, h.catalogues, h.operations
            ),
            0,
            1,
            7
        );
        bytes memory input = abi.encodeWithSelector(
            Finalization.finish.selector, abi.encode(c), abi.encode(plain), abi.encode(h)
        );
        _set(0, 7);
        _refusal(address(Finalization), input, 7);
        _set(0, 0);
        bytes memory raw = abi.decode(_call(address(Finalization), input), (bytes));
        require(
            _step() == 1 && keccak256(raw) == keccak256(abi.encode(expected)),
            "late catalogue and both assigned original carriers"
        );
        require(
            expected.features & RH.RATIFICATIONS != 0
                && expected.features & RH.SANCTION_HISTORY != 0,
            "both explicit feature bits"
        );
        vm.etch(address(Catalogue), old);
    }

    function historicalAcceptedHash(bytes calldata raw) external pure returns (bytes32) {
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        bytes calldata body = raw[at:];
        uint256 rows;
        assembly ("memory-safe") { rows := calldataload(add(body.offset, 96)) }
        return keccak256(
            abi.encode(
                abi.decode(bytes.concat(bytes32(uint256(32)), body[rows:]), (A.AcceptanceBundle[]))
            )
        );
    }

    function _dirtyUnconsumedAccepted(bytes memory raw, uint256 index) private pure {
        // Context.accepted points to a dynamic array. Element offsets are relative
        // to the position after its length; Bundle.rows is original field4.
        assembly ("memory-safe") {
            let data := add(raw, 32)
            let context := add(data, mload(data))
            let accepted := add(context, mload(add(context, 96)))
            let base := add(accepted, 32)
            let item := add(base, mload(add(base, mul(index, 32))))
            let rows := add(item, mload(add(item, 128)))
            let generation := add(rows, 64)
            mstore(generation, or(mload(generation), shl(64, 1)))
        }
    }

    function _padArguments(bytes memory raw, uint256 heads)
        private
        pure
        returns (bytes memory padded)
    {
        padded = new bytes(raw.length + 32);
        for (uint256 i; i < heads; ++i) {
            assembly ("memory-safe") {
                mstore(
                    add(add(padded, 32), mul(i, 32)),
                    add(mload(add(add(raw, 32), mul(i, 32))), 32)
                )
            }
        }
        for (uint256 i = heads * 32; i < raw.length; ++i) {
            padded[i + 32] = raw[i];
        }
    }

    function testBothPublicEncodersEagerlyRejectUnusedRowsAndNormalizePadding() public {
        (Family.Context memory c, Collection.Result memory rows) = PrimarySupplementValues.context();
        for (uint256 count; count < 2; ++count) {
            Encoding.Context memory x = PrimarySupplementValues.encoding(c, rows);
            x.collectionCount = count;
            x.accepted = new A.AcceptanceBundle[](count + 1);
            x.accepted[count].rows = new A.Acceptance[](1);
            x.accepted[count].rows[0].generation = 17;
            T.RatificationRecord[][] memory empty = new T.RatificationRecord[][](count);
            if (count != 0) empty[0] = new T.RatificationRecord[](0);
            Composition.Result memory expected = Encoding.encode(x);
            bytes32 expectedHash = keccak256(abi.encode(expected));
            for (uint256 mode; mode < 2; ++mode) {
                bytes4 selector =
                    mode == 0 ? Encoding.encode.selector : Encoding.encodeRatified.selector;
                bytes memory healthy = mode == 0 ? abi.encode(x) : abi.encode(x, empty);
                require(
                    this.historicalAcceptedHash(healthy) == keccak256(abi.encode(x.accepted)),
                    "complete original accepted-array control"
                );
                bytes memory dirty = mode == 0 ? abi.encode(x) : abi.encode(x, empty);
                _dirtyUnconsumedAccepted(dirty, count);
                (bool original,) = address(this)
                    .call(abi.encodeWithSelector(this.historicalAcceptedHash.selector, dirty));
                require(!original, "original eager uint64 decoder refuses unused row");
                (bool accepted,) = address(Encoding).delegatecall(bytes.concat(selector, dirty));
                require(!accepted, "both public encoders retain complete original domain");
                bytes memory padded = _padArguments(healthy, mode + 1);
                require(
                    this.historicalAcceptedHash(padded) == keccak256(abi.encode(x.accepted)),
                    "original typed decoder accepts padding"
                );
                require(
                    keccak256(_call(address(Encoding), bytes.concat(selector, padded)))
                        == expectedHash,
                    "padded original nominal call parity"
                );
                require(
                    keccak256(_call(address(Encoding), bytes.concat(selector, healthy)))
                        == expectedHash,
                    "same healthy public request restored"
                );
            }
        }
    }

    function testAttributionCurrentAndRecordItemMustMatchThenRestore() public {
        M.State memory scope;
        scope.rows = new bytes[](1);
        G.Attribution memory row;
        row.history.current.state = 2;
        row.history.current.generation = 9;
        row.records.item = abi.decode(abi.encode(row.history.current), (AS.Attribution));
        scope.rows[0] = abi.encode(row);
        Rows.project(scope);
        row.records.item.generation = 8;
        require(row.history.current.generation == 9, "independent original current retained");
        scope.rows[0] = abi.encode(row);
        (bool ok, bytes memory reason) =
            address(Rows).delegatecall(abi.encodeWithSelector(Rows.project.selector, scope));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "exact history/current equality"
        );
        row.records.item.generation = 9;
        scope.rows[0] = abi.encode(row);
        Rows.Result memory restored = Rows.project(scope);
        require(
            keccak256(restored.rows[0]) == keccak256(abi.encode(row.records)), "full record restore"
        );
    }

    function testAttributionSanctionLocalProofPrecedesCompleteSourceReobservation() public {
        PC.Proof memory p = PrimaryTransportValues.proof();
        RH.OwnerProvenance memory local = RH.ownerProvenance(p.provenance, 4);
        M.State memory scope = PrimaryTransportValues.scope();
        scope.rows = new bytes[](1);
        G.Attribution memory row;
        scope.rows[0] = abi.encode(row);
        H.Inventory memory h = PrimarySupplementValues.history();
        M.State memory wrapped = abi.decode(abi.encode(scope), (M.State));
        wrapped.rows = Attribution.encode(wrapped.rows, h);
        bytes memory oldLocal = address(Local).code;
        bytes memory oldSource = address(CurrentClocks).code;
        _install(
            address(Local),
            abi.encodeWithSelector(Local.validate.selector, local, uint8(4), scope.collections, h),
            0,
            1,
            9
        );
        vm.etch(
            address(CurrentClocks),
            address(
                new PrimarySupplementClock(
                    keccak256(
                        abi.encodeWithSelector(
                            CurrentClocks.requireEncoded.selector, scope, abi.encode(p)
                        )
                    )
                )
            )
            .code
        );
        bytes memory input =
            abi.encodeWithSelector(Prelude.prepare.selector, abi.encode(wrapped, local, p));
        _set(0, 9);
        _refusal(address(Prelude), input, 9);
        _set(0, 0);
        Prelude.Result memory actual =
            abi.decode(abi.decode(_call(address(Prelude), input), (bytes)), (Prelude.Result));
        require(
            _step() == 2 && keccak256(abi.encode(actual.scope)) == keccak256(abi.encode(scope))
                && keccak256(abi.encode(actual.sanctions)) == keccak256(abi.encode(h)),
            "unwrapped original scope and full certificate"
        );
        require(
            keccak256(abi.encode(actual.source.clocks))
                == keccak256(abi.encode(PrimaryTransportValues.result().clocks)),
            "whole source clocks retained"
        );
        vm.etch(address(Local), oldLocal);
        vm.etch(address(CurrentClocks), oldSource);
    }
}
