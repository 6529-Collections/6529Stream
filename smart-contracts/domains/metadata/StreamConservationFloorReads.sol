// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamConservationFloor.sol";
import "../../interfaces/stream/metadata/IStreamConservationFloorProvider.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../revenue/StreamSettlementAdmission.sol";

/// @notice Bounded exact reads and native recorder admission for the permanent floor ledger.
library StreamConservationFloorReads {
    struct Context {
        address core;
        bytes32 coreCodeHash;
        uint256 chainId;
        uint256 readGas;
    }

    function requireBound(Context memory x) public view {
        if (
            block.chainid != x.chainId || x.core.code.length == 0
                || x.core.codehash != x.coreCodeHash
        ) revert IStreamConservationFloor.ConservationFloorDependency(x.core);
        bytes memory raw =
            read(x.core, abi.encodeWithSignature("conservationFloor()"), 64, x.readGas);
        (address host, bytes32 codeHash) = abi.decode(raw, (address, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(host, codeHash)) || host != address(this)
                || codeHash != address(this).codehash
        ) revert IStreamConservationFloor.ConservationFloorNotBound();
    }

    function selected(Context memory x, bytes32 kind)
        public
        view
        returns (address target, bytes32 codeHash)
    {
        bytes memory raw = read(
            x.core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, x.readGas
        );
        uint256[10] memory w = abi.decode(raw, (uint256[10]));
        if (
            w[0] > type(uint160).max || w[2] > 1 || bytes32(w[3]) != kind
                || (w[4] & type(uint224).max) != 0 || w[5] > type(uint160).max || w[6] != 1
                || w[7] == 0 || w[8] == 0 || w[9] == 0 || w[9] > type(uint64).max
        ) revert IStreamConservationFloor.ConservationFloorDependency(x.core);
        target = address(uint160(w[0]));
        codeHash = bytes32(w[1]);
        if (!StreamSettlementAdmission.isContract(target) || target.codehash != codeHash) {
            revert IStreamConservationFloor.ConservationFloorDependency(target);
        }
    }

    function requireRecorder(Context memory x, address recorder) public view {
        (address registry, bytes32 registryHash) = selected(x, keccak256("MODULE_REGISTRY"));
        if (
            !StreamSettlementAdmission.isContract(recorder)
                || word(recorder, abi.encodeWithSignature("core()"), x.readGas) != uint160(x.core)
                || bytes32(word(recorder, abi.encodeWithSignature("coreCodeHash()"), x.readGas))
                    != x.coreCodeHash
                || word(recorder, abi.encodeWithSignature("moduleRegistry()"), x.readGas)
                    != uint160(registry)
                || bytes32(
                        word(
                            recorder, abi.encodeWithSignature("moduleRegistryCodeHash()"), x.readGas
                        )
                    ) != registryHash
        ) revert IStreamConservationFloor.ConservationFloorAuthority(recorder);
        _recorderRecord(registry, recorder, x.readGas);
    }

    function _recorderRecord(address registry, address recorder, uint256 cap) private view {
        uint256[14] memory w = _moduleRecord(registry, recorder, cap);
        if (bytes32(w[2]) != keccak256("PRIMARY_SALE_SETTLEMENT")) {
            revert IStreamConservationFloor.ConservationFloorAuthority(recorder);
        }
        bytes4 id;
        if (bytes32(w[3]) == keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")) {
            id = type(IStreamPrimarySaleSettlement).interfaceId;
        } else if (bytes32(w[3]) == keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")) {
            id = type(IStreamPreparedNativePrimarySaleSettlement).interfaceId;
        } else {
            revert IStreamConservationFloor.ConservationFloorAuthority(recorder);
        }
        _moduleInterface(recorder, w[4], id, cap);
        // DEPRECATED recorders keep their own exact operation-lifecycle admission. The floor
        // does not grant new sale creation rights or replace those original checks.
    }

    function requireNativeSale(
        Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        (address registry,) = selected(x, keccak256("MODULE_REGISTRY"));
        uint256[14] memory w = _moduleRecord(registry, c.saleAdapter, x.readGas);
        if (
            bytes32(w[2]) != keccak256("NATIVE_PRIMARY_SALE_ADAPTER")
                || bytes32(w[3]) != keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        ) {
            revert IStreamConservationFloor.ConservationFloorAuthority(c.saleAdapter);
        }
        _moduleInterface(c.saleAdapter, w[4], type(IStreamNativeSaleBinding).interfaceId, x.readGas);
        bytes memory raw = read(
            c.saleAdapter,
            abi.encodeCall(
                IStreamNativeSaleBinding.nativeSaleLifecycleBinding, (c.sale.settlementId)
            ),
            64,
            x.readGas
        );
        if (
            keccak256(raw) != keccak256(abi.encode(c.lifecycleBinding))
                || c.lifecycleBinding.saleCreatedAt == 0
                || c.lifecycleBinding.saleCreatedAt > block.timestamp
                || c.lifecycleBinding.saleCreatedAt < w[10]
                || c.lifecycleBinding.saleAdapterRegistryRevision == 0
                || c.lifecycleBinding.saleAdapterRegistryRevision > w[12]
                || (w[1] == 2
                    && (c.lifecycleBinding.saleCreatedAt >= w[11]
                        || c.lifecycleBinding.saleAdapterRegistryRevision >= w[12]))
        ) {
            revert IStreamConservationFloor.ConservationFloorAuthority(c.saleAdapter);
        }
    }

    function _moduleRecord(address registry, address module, uint256 cap)
        private
        view
        returns (uint256[14] memory w)
    {
        if (!StreamSettlementAdmission.isContract(module)) {
            revert IStreamConservationFloor.ConservationFloorAuthority(module);
        }
        bytes memory input = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (module));
        bool ok;
        uint256 size;
        _gas(registry, bytes4(input), cap);
        assembly ("memory-safe") {
            ok := staticcall(cap, registry, add(input, 32), mload(input), w, 448)
            size := returndatasize()
        }
        // A single dynamic tuple with twelve fixed fields and its bounded URI tail.
        if (
            !ok || size < 448 || size > 4096 || w[0] != 32 || w[9] != 384 || w[13] > size - 448
                || size - 448 != ((w[13] + 31) / 32) * 32 || (w[1] != 1 && w[1] != 2)
                || w[5] > type(uint32).max || bytes32(w[6]) != module.codehash || w[7] == 0
                || w[8] == 0 || w[10] == 0 || w[10] > block.timestamp || w[10] > type(uint64).max
                || w[11] > type(uint64).max || w[11] < w[10] || w[11] > block.timestamp
                || w[12] == 0 || w[12] > type(uint64).max
        ) revert IStreamConservationFloor.ConservationFloorAuthority(module);
    }

    function _moduleInterface(address module, uint256 encodedId, bytes4 id, uint256 cap)
        private
        view
    {
        if (
            encodedId != uint256(uint32(id)) << 224
                || word(module, abi.encodeCall(IERC165.supportsInterface, (id)), cap) != 1
                || word(
                        module, abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))), cap
                    ) != 1
                || word(
                        module, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), cap
                    ) != 0
        ) revert IStreamConservationFloor.ConservationFloorAuthority(module);
    }

    function requireCandidate(
        Context memory x,
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) public view {
        requireProjection(x, recorder, c, r, true);
        requireStoredResult(x, recorder, r);
    }

    /// @dev Preparation may name a future prepared-mint identity. Only the paid entry proves it
    /// allocated; custody always requires an already completed original token.
    function requireProjection(
        Context memory x,
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r,
        bool paid
    ) public view {
        if (
            c.sale.collectionId == 0 || c.sale.revenueClass != keccak256("PRIMARY_SALE")
                || c.sale.settlementId == 0 || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.beneficiary == address(0) || c.sale.amount == 0
                || c.sale.expectedPrimaryPolicyHash == 0 || c.saleAdapter == address(0)
                || c.executor == address(0) || c.executionBinding.executionId == 0
                || c.saleExecutionHash == 0 || r.candidateCommitment == 0
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        recorder, c.saleAdapter, c.executionBinding.executionId
                    ) || r.amount != c.sale.amount || r.asset != c.asset || r.executor != c.executor
                || r.executionId != c.executionBinding.executionId || r.profileId == 0
                || r.wallet == address(0) || r.profileId != c.rights.profileId
                || r.wallet != c.rights.wallet
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
                || word(
                        x.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionExists, (c.sale.collectionId)
                        ),
                        x.readGas
                    ) != 1
        ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        if (c.orchestrationOrder == 1 || c.orchestrationOrder == 2) {
            if (
                c.operationIdentityCommitment == 0 || c.operationId == 0 || c.currentPolicyHash == 0
                    || c.boundPolicyHash == 0
                    || !StreamSettlementAdmission.isContract(c.mintManager)
                    || word(c.mintManager, abi.encodeWithSignature("core()"), x.readGas)
                        != uint160(x.core) || (c.orchestrationOrder == 1 && c.sale.tokenId != 0)
            ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        } else if (c.orchestrationOrder == 3) {
            if (
                c.sale.tokenId == 0 || c.mintManager != address(0)
                    || c.operationIdentityCommitment != 0 || c.operationId != 0
                    || c.currentPolicyHash != 0 || c.boundPolicyHash != 0
            ) revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        } else {
            revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        }
        if (c.sale.tokenId != 0 && (paid || c.orchestrationOrder == 3)) {
            requireToken(x, c.sale.collectionId, c.sale.tokenId, c.orchestrationOrder == 3);
        }
    }

    function requireToken(Context memory x, uint256 cid, uint256 token, bool completed)
        public
        view
    {
        bytes memory raw = read(
            x.core,
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
            128,
            x.readGas
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        uint256 lifecycle =
            word(x.core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (token)), x.readGas);
        if (
            keccak256(raw) != keccak256(abi.encode(exists, collection, serial, burned)) || !exists
                || collection != cid || serial == 0 || lifecycle == 0 || lifecycle > 3
                || (completed && lifecycle < 2) || burned != (lifecycle == 3)
        ) revert IStreamConservationFloor.ConservationFloorInvalidEvidence();
    }

    function requireStoredResult(
        Context memory x,
        address recorder,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) public view {
        if (
            word(
                        recorder,
                        abi.encodeCall(
                            IStreamPrimarySaleSettlement.settlementConsumed, (r.settlementKey)
                        ),
                        x.readGas
                    ) != 1
                || keccak256(
                        read(
                            recorder,
                            abi.encodeCall(
                                IStreamPrimarySaleSettlement.settlementResult, (r.settlementKey)
                            ),
                            384,
                            x.readGas
                        )
                    ) != keccak256(abi.encode(r))
        ) {
            revert IStreamConservationFloor.ConservationFloorSettlementMismatch(r.settlementKey);
        }
    }

    function word(address target, bytes memory input, uint256 cap) internal view returns (uint256) {
        return abi.decode(read(target, input, 32, cap), (uint256));
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        public
        view
        returns (bytes memory output)
    {
        _gas(target, bytes4(input), cap);
        output = new bytes(size);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), size)
            returned := returndatasize()
        }
        if (!ok || returned != size) {
            revert IStreamConservationFloor.ConservationFloorRead(target, bytes4(input));
        }
    }

    function _gas(address target, bytes4 selector, uint256 cap) private view {
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert IStreamConservationFloor.ConservationFloorRead(target, selector);
        }
    }
}
