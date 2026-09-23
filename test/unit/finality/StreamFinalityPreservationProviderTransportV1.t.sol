// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityFullPreservationDispatchV1 as Original
} from "../../../smart-contracts/domains/finality/StreamFinalityFullPreservationDispatchV1.sol";
import {
    StreamCurrentAuthorityFullPreservationDispatchV1 as Current
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationDispatchV1.sol";
import {
    StreamFinalityScopedPreservationPolicyGraphSelectionV1 as OG
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as CG
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityPreservationPolicyGraphSelectionV1 as OC
} from "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CC
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as Profiles
} from "../../../smart-contracts/domains/finality/StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as P
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as G
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamFinalityViewProviderBindingTransportV1 as BindingTransport
} from "../../../smart-contracts/domains/finality/StreamFinalityViewProviderBindingTransportV1.sol";
import {
    StreamFinalityViewPreservationBindingV1 as BindingState
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as V
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as B
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1 as Full
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamViewAdoptionTypes as D
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit typed storage boundary, not an authenticated provider deployment or publication.
/// These tests isolate ABI transport and first-error order; original ceremony suites remain separate.
contract PreservationProviderTransportHarness {
    bytes32 public canaryBefore = keccak256("transport before");
    OG.Context private _original;
    CG.Context private _current;
    OC.Context private _originalCollection;
    CC.Context private _currentCollection;
    Profiles.Context private _profiles;
    BindingState.State private _binding;
    bytes32 public canaryAfter = keccak256("transport after");

    constructor() {
        _original.original.chainId = block.chainid;
        _original.original.targets[0] = address(0x1234);
        _original.original.componentSourceGas = 345678;
        _current.original = _original.original;
        _original.binding = G.FactoryBinding(
            address(0xA1),
            bytes32(uint256(101)),
            bytes32(uint256(102)),
            bytes32(uint256(103)),
            104,
            bytes32(uint256(105))
        );
        _current.binding = _original.binding;
        _originalCollection.binding = C.CollectionFactoryBinding(
            address(0xB1),
            bytes32(uint256(201)),
            bytes32(uint256(202)),
            bytes32(uint256(203)),
            204,
            bytes32(uint256(205))
        );
        _currentCollection.binding = _originalCollection.binding;
        for (uint256 i; i < 2; ++i) {
            _profiles.profiles[i] = P.Profile(
                bytes32(i + 1),
                address(uint160(301 + i)),
                bytes32(401 + i),
                address(uint160(501 + i)),
                bytes32(601 + i),
                address(uint160(701 + i)),
                bytes32(801 + i),
                bytes32(901 + i)
            );
        }
        _binding.capability = V.Capability(
            address(0xD1), bytes32(uint256(11)), bytes32(uint256(12)), bytes32(uint256(13))
        );
        _binding.receipt.configuration.snapshotHost = address(0xE1);
        _binding.receipt.actionId = bytes32(uint256(21));
        _binding.receipt.boundAt = 22;
    }

    function graphRead(bool current, bytes calldata input)
        external
        view
        returns (bytes memory result)
    {
        bool handled;
        if (current) {
            (handled, result) = Current.read(_current, _currentCollection, _profiles, input);
        } else {
            (handled, result) = Original.read(_original, _originalCollection, _profiles, input);
        }
        require(handled, "selected getter handled");
    }

    function bindingRead(bytes calldata input) external view returns (bytes memory) {
        return BindingTransport.read(_binding, _original.original, address(0), 0, 0, input);
    }

    function bindingWrite(bytes calldata input) external returns (bytes memory) {
        return BindingTransport.write(_binding, _original.original, address(0), 0, 0, input);
    }

    function setBound(bytes32 value) external {
        _binding.receipt.recordHash = value;
    }

    function originalReceipt() external view returns (V.Receipt memory) {
        return _binding.receipt;
    }

    function stateHash() external view returns (bytes32) {
        return keccak256(abi.encode(canaryBefore, _binding, canaryAfter));
    }
}

contract StreamFinalityPreservationProviderTransportV1Test {
    PreservationProviderTransportHarness private h;

    function setUp() public {
        h = new PreservationProviderTransportHarness();
    }

    function _same(bytes memory input, bytes memory expected) private view {
        bytes memory a = h.graphRead(false, input);
        bytes memory b = h.graphRead(true, input);
        require(
            keccak256(a) == keccak256(expected) && keccak256(b) == keccak256(expected),
            "both nominal literal ABI"
        );
    }

    function _failure(bytes memory input, bytes memory expected) private view {
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory error) =
                address(h).staticcall(abi.encodeCall(h.graphRead, (i == 1, input)));
            require(!ok && keccak256(error) == keccak256(expected), "both nominal exact refusal");
        }
    }

    function testStoredBindingsKeepExactSixWordOuterBytes() public view {
        _same(
            abi.encodeWithSignature("scopedPreservationPolicyPublicationBinding()"),
            abi.encode(
                address(0xA1),
                bytes32(uint256(101)),
                bytes32(uint256(102)),
                bytes32(uint256(103)),
                uint256(104),
                bytes32(uint256(105))
            )
        );
        _same(
            abi.encodeWithSignature("collectionPreservationPolicyPublicationBinding()"),
            abi.encode(
                address(0xB1),
                bytes32(uint256(201)),
                bytes32(uint256(202)),
                bytes32(uint256(203)),
                uint256(204),
                bytes32(uint256(205))
            )
        );
    }

    function testBothCatalogueRowsAndOriginalOutOfRangeRefusal() public view {
        for (uint8 i; i < 2; ++i) {
            _same(
                abi.encodeWithSignature("finalitySourceProfile(uint8)", i),
                abi.encode(
                    bytes32(uint256(i) + 1),
                    address(uint160(301 + uint256(i))),
                    bytes32(401 + uint256(i)),
                    address(uint160(501 + uint256(i))),
                    bytes32(601 + uint256(i)),
                    address(uint160(701 + uint256(i))),
                    bytes32(801 + uint256(i)),
                    bytes32(901 + uint256(i))
                )
            );
        }
        _failure(
            abi.encodeWithSignature("finalitySourceProfile(uint8)", uint8(2)),
            abi.encodeWithSignature("InvalidFinalitySourceProfile()")
        );
    }

    function testScopeGasProjectionRetainsClosedCanonicalKinds() public view {
        for (uint8 kind = 1; kind <= 3; ++kind) {
            StreamFinalityScope memory s = StreamFinalityScope(
                StreamFinalityScopeType(kind),
                9,
                kind == 1 ? 77 : 0,
                kind == 1 ? bytes32(0) : bytes32(uint256(99))
            );
            _same(
                abi.encodeWithSignature(
                    "scopedPreservationPolicySnapshotValidationGas((uint8,uint256,uint256,bytes32))",
                    s
                ),
                abi.encode(uint256(345678))
            );
        }
        StreamFinalityScope memory c =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 9, 0, 0);
        _failure(
            abi.encodeWithSignature(
                "scopedPreservationPolicySnapshotValidationGas((uint8,uint256,uint256,bytes32))", c
            ),
            abi.encodeWithSignature("ScopedPolicyGraphConfiguration()")
        );
    }

    function testHistoricalBindingBytesRemainUnvalidatedAndUnmutated() public view {
        bytes32 state = h.stateHash();
        require(
            keccak256(h.bindingRead(abi.encodeCall(B.viewPreservationBindingCapability, ())))
                == keccak256(
                    abi.encode(
                        address(0xD1),
                        bytes32(uint256(11)),
                        bytes32(uint256(12)),
                        bytes32(uint256(13))
                    )
                ),
            "literal capability"
        );
        require(
            keccak256(h.bindingRead(abi.encodeCall(B.viewPreservationBindingReceipt, ())))
                == keccak256(abi.encode(h.originalReceipt())),
            "complete original receipt ABI"
        );
        require(h.stateHash() == state, "no stored mutation");
    }

    function testAlreadyBoundPrecedesInvalidFactoryForBothWriteAndPreview() public {
        V.Configuration memory c;
        D.Binding memory d;
        Selection.Selection memory s;
        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeCall(B.viewPreservationBindingTransition, (c, d));
        calls[1] = abi.encodeCall(Full.completeViewPreservationBindingTransition, (c, d, s));
        calls[2] = abi.encodeCall(B.bindViewPreservation, (c, d));
        calls[3] = abi.encodeCall(Full.bindCompleteViewPreservation, (c, d, s));
        h.setBound(bytes32(uint256(1)));
        bytes32 before_ = h.stateHash();
        for (uint256 i; i < 4; ++i) {
            bytes memory outer = i < 2
                ? abi.encodeCall(h.bindingRead, (calls[i]))
                : abi.encodeCall(h.bindingWrite, (calls[i]));
            (bool ok, bytes memory error) = address(h).call(outer);
            require(
                !ok
                    && keccak256(error)
                        == keccak256(abi.encodeWithSignature("ViewPreservationAlreadyBound()")),
                "original first error"
            );
            require(h.stateHash() == before_, "all storage unchanged on refusal");
        }
    }

    function testUnknownSelectorsCannotChooseAnotherWorkerOrWrite() public {
        bytes memory unknown = hex"ffffffff";
        _failure(unknown, abi.encodeWithSignature("UnsupportedPreservationSelector()"));
        bytes32 before_ = h.stateHash();
        (bool ok, bytes memory error) = address(h).call(abi.encodeCall(h.bindingWrite, (unknown)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSignature("UnsupportedViewBindingSelector()")),
            "closed write decoder"
        );
        require(h.stateHash() == before_, "unknown selector rollback");
    }
}
