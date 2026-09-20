// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RecoveredPreparationTupleFixture } from "./StreamArtistRecoveredPreparationTuple.t.sol";
import {
    StreamArtistRecoveredIdentityTransport as Transport
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityTransport.sol";
import {
    StreamArtistRecoveredIdentityTransportNonces as Nonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityTransportNonces.sol";
import {
    StreamArtistRecoveredIdentityTransportImport as ImportStage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityTransportImport.sol";
import {
    StreamArtistHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationExportRows.sol";
import {
    StreamArtistRecoveredIdentityHydrationImport as Import
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationImport.sol";
import {
    StreamArtistRecoveredIdentitySourceCodec as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceCodec.sol";
import {
    StreamArtistRecoveredIdentitySourceValidation as Validation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentitySourceValidation.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredOwnerReads as Reads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistHistoryState as History
} from "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";
import {
    StreamArtistIdentityState as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistOwnerHydration as Original
} from "../../../smart-contracts/domains/artist/StreamArtistOwnerHydration.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM,
    IStreamArtistRecoveredTimingInventory as TimingAPI
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    IStreamArtistRecoveredIdentityHydrationOwner as Raw
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredIdentityHydrationOwner.sol";
import {
    IStreamArtistRecoveredHydrationOwner as API
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";

interface RecoveredIdentityTransportVm {
    function store(address target, bytes32 slot, bytes32 value) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function expectCall(address target, bytes calldata input, uint64 count) external;
    function clearMockedCalls() external;
}

abstract contract RecoveredIdentityTransportFixture is RecoveredPreparationTupleFixture {
    RecoveredIdentityTransportVm internal constant vm =
        RecoveredIdentityTransportVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant GUARDS_SLOT =
        keccak256("6529STREAM_ARTIST_AUTHORITY_HYDRATION_STORAGE_V1");
    bytes32 internal constant VALUE = keccak256("owner guard commitment");
    bytes32 internal constant COMPLETE = keccak256("transport boundary completed");

    error StageReached(uint256 stage);

    function _setCommitment(bytes32 value) internal {
        vm.store(address(this), GUARDS_SLOT, value);
    }

    function _reverted(bool ok, bytes memory actual, bytes memory expected) internal pure {
        assert(!ok);
        _same(actual, expected);
    }
}

/// @notice Scoped transport dispatch and ABI boundary tests with fixed downstream mocks.
/// @dev These do not prove the exporter, canonical codec, source authentication, importer,
/// History activation or a complete operation60 flow. The nonce suite above runs its real worker.
contract StreamArtistRecoveredIdentityTransportBoundaryTest is RecoveredIdentityTransportFixture {
    function _roots() private pure returns (uint256[17] memory roots) {
        for (uint256 i; i < 17; ++i) {
            roots[i] = 101 + 37 * i;
        }
    }

    function _owner() private pure returns (Identity.OwnerContext memory owner) {
        owner.environment.registry = address(0x1234);
        owner.coordinator = address(0x2345);
        owner.archive = address(0x3456);
        owner.domain = keccak256("identity owner domain");
    }

    // Match the real host's terminal forwarding of Transport.read's unwrapped bytes result.
    function readHost(bytes calldata data) external view {
        bytes memory result = Transport.read(_roots(), _owner(), data);
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function sliceOracle(bytes calldata data) external pure returns (bytes4) {
        return bytes4(data[:4]);
    }

    function importHost(bytes calldata encoded) external returns (bytes32) {
        Transport.importEncoded(_roots(), encoded);
        return COMPLETE;
    }

    function _host(bytes memory input) private view returns (bytes memory output) {
        (bool ok, bytes memory result) =
            address(this).staticcall(abi.encodeCall(this.readHost, (input)));
        assert(ok);
        return result;
    }

    function testReadRawAndSemanticBytesLayers() public {
        IH.Bundle memory b = _identity(53, true);
        AH.Query memory q = _query(53, true);
        RH.OwnerProvenance memory p = RH.ownerProvenance(_provenance(53, true), 2);
        bytes memory canonical = abi.encode(b);
        bytes memory exportCall =
            abi.encodeWithSelector(Export.exportEncoded.selector, _roots(), q, p);
        vm.mockCall(address(Export), exportCall, abi.encode(canonical));
        vm.expectCall(address(Export), exportCall, 3);
        bytes memory validateCall =
            abi.encodeWithSelector(Validation.validateEncoded.selector, canonical, p);
        vm.mockCallRevert(
            address(Validation), validateCall, abi.encodeWithSelector(StageReached.selector, 1)
        );
        _same(
            _host(abi.encodeWithSelector(Raw.recoveredIdentityHydrationRaw.selector, q, p)),
            canonical
        );
        (bool ok, bytes memory reason) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.readHost,
                    (abi.encodeWithSelector(API.recoveredAuthorityHydrationState.selector, q, p))
                )
            );
        _reverted(ok, reason, abi.encodeWithSelector(StageReached.selector, 1));
        vm.mockCall(
            address(Validation), validateCall, abi.encode(keccak256(abi.encode(IH.SCHEMA, b)))
        );
        vm.expectCall(address(Validation), validateCall, 1);
        _same(
            _host(abi.encodeWithSelector(API.recoveredAuthorityHydrationState.selector, q, p)),
            abi.encode(abi.encode(IH.SCHEMA, b))
        );
        vm.clearMockedCalls();
    }

    function testAllFourOriginalEarlyReadRoutes() public {
        bytes32 action = keccak256("action");
        bytes32 artist = keccak256("artist");
        bytes memory callData =
            abi.encodeWithSelector(Export.actionArtist.selector, _roots(), action);
        vm.mockCall(address(Export), callData, abi.encode(artist));
        vm.expectCall(address(Export), callData, 1);
        _same(
            _host(
                abi.encodeWithSelector(Raw.recoveredIdentityHydrationActionArtist.selector, action)
            ),
            abi.encode(artist)
        );

        TM.Checkpoint memory checkpoint =
            TM.Checkpoint(artist, 11, 12, action, bytes32(uint256(13)));
        callData = abi.encodeWithSelector(Export.timingCheckpoint.selector, _roots());
        vm.mockCall(address(Export), callData, abi.encode(checkpoint));
        vm.expectCall(address(Export), callData, 1);
        _same(
            _host(abi.encodeWithSelector(TimingAPI.recoveredTimingCheckpoint.selector)),
            abi.encode(checkpoint)
        );
        TM.Entry memory entry;
        entry.index = 14;
        entry.commitment = artist;
        callData = abi.encodeWithSelector(Timing.entryAt.selector, uint256(17));
        vm.mockCall(address(Timing), callData, abi.encode(entry));
        vm.expectCall(address(Timing), callData, 1);
        _same(
            _host(abi.encodeWithSelector(TimingAPI.recoveredTimingEntryAt.selector, uint256(17))),
            abi.encode(entry)
        );

        Identity.OwnerContext memory owner = _owner();
        RH.OriginEnvironment memory environment = _provenance(19, true).origins[0];
        callData = abi.encodeWithSelector(
            Reads.environment.selector,
            Original.Binding(
                owner.environment.registry, owner.coordinator, owner.archive, owner.domain
            ),
            uint8(2)
        );
        vm.mockCall(address(Reads), callData, abi.encode(environment));
        vm.expectCall(address(Reads), callData, 1);
        RH.Point memory point = RH.Point(RH.originHash(environment), 2, 91);
        callData = abi.encodeWithSelector(
            Export.auxiliaryPoint.selector, _roots(), action, artist, point.environmentHash
        );
        vm.mockCall(address(Export), callData, abi.encode(point));
        vm.expectCall(address(Export), callData, 1);
        _same(
            _host(
                abi.encodeWithSelector(
                    API.recoveredHydrationAuxiliaryPoint.selector, action, artist
                )
            ),
            abi.encode(point)
        );
        vm.clearMockedCalls();
    }

    function testReadOriginalSelectorFailuresAndWorkerReverts() public {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.readHost, (hex"ffffffff")));
        _reverted(ok, reason, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector));
        (bool oldOk, bytes memory oldReason) =
            address(this).staticcall(abi.encodeCall(this.sliceOracle, (hex"010203")));
        (ok, reason) = address(this).staticcall(abi.encodeCall(this.readHost, (hex"010203")));
        assert(!oldOk && !ok);
        _same(reason, oldReason);
        bytes memory trap = abi.encodeWithSelector(StageReached.selector, 8);
        vm.mockCallRevert(address(Export), abi.encodePacked(Export.exportEncoded.selector), trap);
        AH.Query memory q = _query(1, true);
        RH.OwnerProvenance memory p = RH.ownerProvenance(_provenance(1, true), 2);
        (ok, reason) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.readHost,
                    (abi.encodeWithSelector(Raw.recoveredIdentityHydrationRaw.selector, q, p))
                )
            );
        _reverted(ok, reason, trap);
        vm.clearMockedCalls();
    }

    function testImportOrderedForwardingAndExactSeventeenRoots() public {
        IH.Bundle memory b = _identity(73, true);
        AH.Query memory q = _query(73, true);
        AH.OwnerData memory data;
        data.typedState = hex"112233";
        T.ActionContext memory context;
        Payload.Payload memory payload;
        payload.provenance = RH.ownerProvenance(_provenance(73, true), 2);
        (, payload.nonces) = _nonceFixture(73, 2, 2);
        payload.semanticState = abi.encode(IH.SCHEMA, b);
        RH.ExportHeader memory header;
        bytes memory encoded = abi.encode(context, q, data, VALUE);
        address[5] memory targets =
            [address(Payload), address(Codec), address(Guards), address(Import), address(History)];
        bytes[5] memory calls;
        calls[0] = abi.encodeWithSelector(Payload.decode.selector, data.typedState, uint8(2));
        calls[1] = abi.encodeWithSelector(
            Codec.decode.selector, payload.semanticState, payload.provenance
        );
        calls[2] = abi.encodeWithSelector(Guards.commitment.selector);
        calls[3] = abi.encodeWithSelector(
            Import.importEncoded.selector,
            _roots(),
            q.artistId,
            payload.semanticState,
            payload.provenance
        );
        calls[4] =
            abi.encodeWithSelector(History.activate.selector, q.artistId, q.collectionId, VALUE);
        bytes[5] memory outputs;
        outputs[0] = abi.encode(header, payload);
        outputs[1] = abi.encode(abi.encode(b));
        outputs[2] = abi.encode(VALUE);
        outputs[3] = abi.encode(keccak256("ignored importer return, not activation value"));
        outputs[4] = hex"";
        for (uint256 reached; reached < 5; ++reached) {
            vm.clearMockedCalls();
            for (uint256 i; i < 5; ++i) {
                if (i < reached) {
                    vm.mockCall(targets[i], calls[i], outputs[i]);
                } else {
                    vm.mockCallRevert(
                        targets[i], calls[i], abi.encodeWithSelector(StageReached.selector, i)
                    );
                }
            }
            (bool ok, bytes memory reason) =
                address(this).call(abi.encodeCall(this.importHost, (encoded)));
            _reverted(ok, reason, abi.encodeWithSelector(StageReached.selector, reached));
        }
        vm.clearMockedCalls();
        _setCommitment(VALUE);
        // A STATICCALL at either new boundary would read these misleading library slots.
        vm.store(address(Transport), GUARDS_SLOT, bytes32(uint256(7)));
        vm.store(address(ImportStage), GUARDS_SLOT, bytes32(uint256(8)));
        vm.store(address(Nonces), GUARDS_SLOT, bytes32(uint256(9)));
        vm.store(address(Guards), GUARDS_SLOT, bytes32(uint256(10)));
        for (uint256 i; i < 5; ++i) {
            if (i != 2) vm.mockCall(targets[i], calls[i], outputs[i]);
            vm.expectCall(targets[i], calls[i], 1);
        }
        assert(this.importHost(encoded) == COMPLETE);
        vm.clearMockedCalls();
    }
}
