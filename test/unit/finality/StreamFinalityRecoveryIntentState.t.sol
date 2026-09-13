// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryIntentState.sol";

interface RecoveryIntentVm {
    function etch(address target, bytes calldata code) external;
    function prank(address actor) external;
}

contract RecoveryIntentHost {
    StreamFinalityRecoveryIntentState.State private state;

    function stage(bytes calldata data) external returns (bytes32) {
        return StreamFinalityRecoveryIntentState.stage(state, data);
    }

    function manifest(bytes32 hash) external view returns (bytes memory) {
        return StreamFinalityRecoveryIntentState.manifestBytes(state, hash);
    }

    function request(bytes32 hash) external view returns (StreamFinalityRecoveryRequest memory) {
        return StreamFinalityRecoveryIntentState.requestFor(state, hash);
    }

    function register(StreamFinalityRecoveryRequest calldata r, bool lateFailure)
        external
        returns (bytes32 h)
    {
        h = StreamFinalityRecoveryIntentState.register(state, environment(), r);
        require(!lateFailure, "late fixture rollback");
    }

    function validate(StreamFinalityRecoveryRequest calldata r)
        external
        view
        returns (bytes memory)
    {
        return StreamFinalityRecoveryIntentState.validate(state, environment(), r);
    }

    function pointers(bytes32 hash) external view returns (address, address) {
        return (state.manifests[hash].pointer, state.requests[hash].pointer);
    }

    function environment() public view returns (StreamFinalityRecoveryHashes.Environment memory) {
        return StreamFinalityRecoveryHashes.Environment(block.chainid, address(this));
    }
}

/// @dev Byte availability only; current scope, route and authority admission remain companion gates.
contract StreamFinalityRecoveryIntentStateTest {
    RecoveryIntentVm private constant vm =
        RecoveryIntentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryIntentHost private host;

    function setUp() public {
        host = new RecoveryIntentHost();
    }

    function _request() private pure returns (StreamFinalityRecoveryRequest memory r) {
        r.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        r.expectedOriginalFinalityRecordHash = keccak256("original");
        r.expectedOldRouteHash = keccak256("old");
        r.replacementRoute = StreamFinalityComponentExpectation(
            keccak256("renderer"),
            address(0xBEEF),
            0x12345678,
            keccak256("code"),
            keccak256("version"),
            keccak256("manifest"),
            keccak256("data")
        );
        r.recoveryManifest = StreamFinalityManifestRef(
            unicode"urn:recovery:東京/🖼",
            0,
            0,
            keccak256("schema"),
            keccak256("canonicalization")
        );
        r.reasonHash = keccak256("reason");
        r.reasonURI = "urn:reason:preservation";
    }

    function _stage(StreamFinalityRecoveryRequest memory r)
        private
        returns (StreamFinalityRecoveryRequest memory)
    {
        r.recoveryManifest.uriHash = keccak256(bytes(r.recoveryManifest.uri));
        bytes memory data = StreamFinalityRecoveryHashes.intentBytes(host.environment(), r);
        require(data.length == 704, "permanent staged length");
        r.recoveryManifest.contentHash = host.stage(data);
        return r;
    }

    function _reject(StreamFinalityRecoveryRequest memory r) private {
        (bool ok,) = address(host).call(abi.encodeCall(host.register, (r, false)));
        require(!ok, "must reject");
    }

    function testRecoveryIntentRegistersCompleteStringsAndDuplicateIsImmutable() public {
        StreamFinalityRecoveryRequest memory r = _stage(_request());
        bytes32 hash = host.register(r, false);
        require(hash == keccak256(abi.encode(r)), "complete canonical request hash");
        require(
            keccak256(abi.encode(host.request(r.recoveryManifest.contentHash))) == hash,
            "all strings and fields retained"
        );
        (address manifest, address request) = host.pointers(r.recoveryManifest.contentHash);
        require(
            keccak256(SSTORE2.read(request)) == hash && SSTORE2.read(manifest).length == 704,
            "actual objects complete"
        );
        vm.prank(address(0xCAFE));
        require(host.register(r, false) == hash, "permissionless exact duplicate");
        (address m2, address r2) = host.pointers(r.recoveryManifest.contentHash);
        require(m2 == manifest && r2 == request, "duplicate cannot replace pointers");
        require(
            keccak256(host.validate(r)) == hash, "preparation revalidates original staged bytes"
        );
    }

    function testRecoveryIntentRequiresStagedExactPreimageAndAllUriFields() public {
        StreamFinalityRecoveryRequest memory r = _request();
        r.recoveryManifest.uriHash = keccak256(bytes(r.recoveryManifest.uri));
        r.recoveryManifest.contentHash =
            keccak256(StreamFinalityRecoveryHashes.intentBytes(host.environment(), r));
        _reject(r);
        r = _stage(r);
        host.register(r, false);
        r.reasonURI = "urn:substitution";
        _reject(r);
        r.reasonURI = "urn:reason:preservation";
        r.recoveryManifest.uri = "urn:substitution";
        _reject(r);
        r.recoveryManifest.uriHash = keccak256(bytes(r.recoveryManifest.uri));
        _reject(r);
        r = _stage(_request());
        r.expectedPredecessorRecoveryId = keccak256("other lineage");
        _reject(r);
        r = _stage(_request());
        r.recoveryManifest.schemaId = keccak256("other schema");
        _reject(r);
    }

    function testRecoveryIntentOtherCompanionAndNoncanonicalStageCannotAuthorize() public {
        StreamFinalityRecoveryRequest memory r = _stage(_request());
        RecoveryIntentHost other = new RecoveryIntentHost();
        other.stage(host.manifest(r.recoveryManifest.contentHash));
        (bool ok,) = address(other).call(abi.encodeCall(other.register, (r, false)));
        require(!ok, "domain binds actual owning companion");
        bytes memory tail = bytes.concat(host.manifest(r.recoveryManifest.contentHash), hex"00");
        r.recoveryManifest.contentHash = host.stage(tail);
        _reject(r);
        require(
            host.manifest(r.recoveryManifest.contentHash).length == 705,
            "staging alone grants no canonical intent"
        );
    }

    function testRecoveryIntentValidatesCanonicalScopesAndUtf8WithoutInventingMembership() public {
        StreamFinalityRecoveryRequest memory r = _request();
        for (uint8 i; i < 5; ++i) {
            r.scope = StreamFinalityScope(
                StreamFinalityScopeType(i),
                7,
                i == 1 ? 987 : 0,
                i > 1 ? keccak256("scope") : bytes32(0)
            );
            r = _stage(r);
            host.register(r, false);
        }
        r.scope.tokenId = 1;
        r = _stage(r);
        _reject(r);
        r = _request();
        r.scope.collectionId = 0;
        r = _stage(r);
        _reject(r);
        bytes[5] memory invalid = [
            bytes(hex"c080"),
            bytes(hex"eda080"),
            bytes(hex"f4908080"),
            bytes(hex"f0808080"),
            bytes(hex"e282")
        ];
        for (uint256 i; i < invalid.length; ++i) {
            r = _request();
            r.reasonURI = string(invalid[i]);
            r = _stage(r);
            _reject(r);
        }
    }

    function testRecoveryIntentMaximumCompleteObjectAndOneWordTooLarge() public {
        StreamFinalityRecoveryRequest memory r = _request();
        r.recoveryManifest.uri = "x";
        r.reasonURI = "";
        uint256 base = abi.encode(r).length;
        bytes memory reason = new bytes(24544 - base);
        for (uint256 i; i < reason.length; ++i) {
            reason[i] = 0x61;
        }
        r.reasonURI = string(reason);
        r = _stage(r);
        require(abi.encode(r).length == 24544, "maximum ABI-aligned object");
        bytes32 hash = host.register(r, false);
        (, address pointer) = host.pointers(r.recoveryManifest.contentHash);
        require(
            pointer.code.length == 24545 && keccak256(SSTORE2.read(pointer)) == hash,
            "whole maximum object plus STOP fits"
        );
        r.reasonURI = string(bytes.concat(reason, hex"61"));
        r = _stage(r);
        require(abi.encode(r).length == 24576, "next padded word");
        _reject(r);
    }

    function testRecoveryIntentPointerDriftAndLateRollbackPreserveExactRetry() public {
        StreamFinalityRecoveryRequest memory r = _stage(_request());
        (bool ok,) = address(host).call(abi.encodeCall(host.register, (r, true)));
        require(!ok, "late failure");
        (address manifest, address request) = host.pointers(r.recoveryManifest.contentHash);
        require(request == address(0), "no partial registration");
        bytes32 hash = host.register(r, false);
        (, request) = host.pointers(r.recoveryManifest.contentHash);
        bytes memory original = manifest.code;
        vm.etch(manifest, hex"0001");
        _reject(r);
        vm.etch(manifest, original);
        original = request.code;
        vm.etch(request, hex"0001");
        _reject(r);
        (ok,) =
            address(host).staticcall(abi.encodeCall(host.request, (r.recoveryManifest.contentHash)));
        require(!ok, "corrupt complete request fails closed");
        vm.etch(request, original);
        require(host.register(r, false) == hash, "identical retained request healthy retry");
    }
}
