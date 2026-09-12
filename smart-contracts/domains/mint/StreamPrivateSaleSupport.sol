// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrivateSaleHash.sol";
import "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";

import {
    IStreamPrivateSaleAdapter as P
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../vendor/openzeppelin/IERC721.sol";
import "../../vendor/openzeppelin/IERC2981.sol";
import "../revenue/StreamSettlementAdmission.sol";

/// @notice Fixed-shape reads and explicitly selected signature checks for secondary custody sales.
/// @dev Trusted immutable Core/registry use available gas and bounded copies. Recipient and signature
///      calls use their distinct current governed caps. No signature kind is inferred from code size.
library StreamPrivateSaleSupport {
    bytes32 internal constant ROLE = keccak256("PRIVATE_SALE_ADAPTER");
    bytes32 internal constant VERSION = keccak256("6529STREAM_NATIVE_CONSIGNMENT_V1");
    uint256 private constant _HALF_ORDER =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    struct Context {
        address core;
        address registry;
        bytes32 coreCodeHash;
        bytes32 registryCodeHash;
    }

    function requireGas(uint256 cap) internal view {
        uint256 available = gasleft();
        // Includes cold CALL overhead and value stipend accounting, plus post-call bookkeeping.
        uint256 required = cap + (cap + 62) / 63 + 40_000;
        if (available < required) revert P.PrivateSaleInsufficientGas(required, available);
    }

    function validSignature(
        address signer,
        uint8 kind,
        bytes32 digest,
        bytes memory signature,
        uint256 cap
    ) public view returns (bool) {
        if (signer == address(0)) return false;
        if (kind == 1) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    s := mload(add(signature, 64))
                    v := byte(0, mload(add(signature, 96)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    vs := mload(add(signature, 64))
                }
                s = bytes32(uint256(vs) & ((uint256(1) << 255) - 1));
                v = uint8((uint256(vs) >> 255) + 27);
            } else {
                return false;
            }
            if (uint256(s) > _HALF_ORDER || (v != 27 && v != 28)) return false;
            address recovered = ecrecover(digest, v, r, s);
            return recovered != address(0) && recovered == signer;
        }
        if (kind != 2) return false;
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        requireGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }

    function interfaceSupported(address target, bytes4 id) internal view returns (bool) {
        bytes memory data = abi.encodeWithSelector(bytes4(0x01ffc9a7), id);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == 1;
    }

    function requireAdmission(Context memory c, uint64 createdAt, uint64 revision)
        public
        view
        returns (uint64 currentRevision)
    {
        StreamSettlementAdmission.requireRegistry(
            c.core, c.coreCodeHash, c.registry, c.registryCodeHash
        );
        address adapter = address(this);
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (adapter));
        uint256[14] memory w;
        bool ok;
        uint256 size;
        address registry = c.registry;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), w, 448)
            size := returndatasize()
        }
        if (
            !ok || size < 448 || w[0] != 32 || w[1] > 3 || w[5] > type(uint32).max || w[9] != 384
                || w[10] > type(uint64).max || w[11] > type(uint64).max || w[12] > type(uint64).max
                || w[13] > size - 448 || size - 448 != ((w[13] + 31) / 32) * 32
        ) {
            revert P.PrivateSaleModuleNotAdmitted();
        }
        if (
            (w[1] != 1 && w[1] != 2) || bytes32(w[2]) != ROLE || bytes32(w[3]) != VERSION
                || w[4] != uint256(uint32(type(P).interfaceId)) << 224
                || bytes32(w[6]) != adapter.codehash || w[7] == 0 || w[8] == 0 || w[10] == 0
                || w[10] > block.timestamp || w[11] < w[10] || w[11] > block.timestamp || w[12] == 0
                || !interfaceSupported(adapter, type(P).interfaceId)
        ) {
            revert P.PrivateSaleModuleNotAdmitted();
        }
        if (createdAt == 0) {
            if (w[1] != 1 || revision != 0) revert P.PrivateSaleModuleNotAdmitted();
        } else if (
            createdAt > block.timestamp || createdAt < w[10] || revision == 0 || revision > w[12]
                || (w[1] == 2 && (createdAt >= w[11] || revision >= w[12]))
        ) {
            revert P.PrivateSaleModuleNotAdmitted();
        }
        return uint64(w[12]);
    }

    function ownerOf(Context memory c, uint256 tokenId) public view returns (address owner) {
        _core(c);
        uint256 word = readWord(c.core, abi.encodeCall(IERC721.ownerOf, (tokenId)));
        if (word == 0 || word > type(uint160).max) revert P.PrivateSaleTokenInvalid(tokenId);
        return address(uint160(word));
    }

    function requireToken(Context memory c, uint256 collectionId, uint256 tokenId) public view {
        _core(c);
        bytes memory data = abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId));
        address target = c.core;
        uint256[4] memory w;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), w, 128)
            size := returndatasize()
        }
        if (
            !ok || size != 128 || w[0] != 1 || w[1] != collectionId || w[3] != 0
                || readWord(target, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)))
                    != 2
        ) {
            revert P.PrivateSaleTokenInvalid(tokenId);
        }
    }

    function royalty(Context memory c, uint256 tokenId, uint256 price)
        public
        view
        returns (address receiver, uint256 amount)
    {
        _core(c);
        bytes memory data = abi.encodeCall(IERC2981.royaltyInfo, (tokenId, price));
        uint256[2] memory w;
        bool ok;
        uint256 size;
        address target = c.core;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), w, 64)
            size := returndatasize()
        }
        if (
            !ok || size != 64 || w[0] > type(uint160).max || w[1] > price
                || (w[1] != 0 && w[0] == 0)
        ) revert P.PrivateSaleRoyaltyInvalid(tokenId);
        return (address(uint160(w[0])), w[1]);
    }

    function takeCustody(Context memory c, address owner, uint256 tokenId) public {
        _core(c);
        bytes memory data = abi.encodeCall(IERC721.transferFrom, (owner, address(this), tokenId));
        address target = c.core;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0 || ownerOf(c, tokenId) != address(this)) {
            revert P.CustodyGrantInvalid();
        }
    }

    function deliverNft(Context memory c, uint256 tokenId, address receiver, uint256 cap)
        public
        returns (bool ok)
    {
        _core(c);
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)", address(this), receiver, tokenId
        );
        address target = c.core;
        requireGas(cap);
        uint256 size;
        assembly ("memory-safe") {
            ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        // Successful malformed return cannot become a claim: the NFT may already have moved.
        if (ok && size != 0) revert P.PrivateSaleTokenInvalid(tokenId);
    }

    function deliverRoyalty(address receiver, uint256 amount, uint256 cap)
        public
        returns (bool ok)
    {
        requireGas(cap);
        if (cap < 2300) revert P.InvalidPrivateSale();
        uint256 beforeBalance = address(this).balance;
        assembly ("memory-safe") {
            ok := call(sub(cap, 2300), receiver, amount, 0, 0, 0, 0)
        }
        if (address(this).balance != beforeBalance - (ok ? amount : 0)) {
            revert P.PrivateSaleBalanceMismatch();
        }
    }

    function readWord(address target, bytes memory data) internal view returns (uint256 word) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert P.PrivateSaleReadFailed(target);
    }

    function authorizationFields(
        P.SaleConfig memory config,
        StreamPrivateSaleTypes.SaleAuthorization memory a
    ) public view {
        address[] memory buyer = new address[](1);
        buyer[0] = config.buyer;
        bytes[] memory emptyData = new bytes[](0);
        bytes32[] memory emptyCommitments = new bytes32[](0);
        if (
            a.chainId != block.chainid || a.saleAdapter != address(this)
                || a.mintManager != address(0) || a.collectionId != config.collectionId
                || a.phaseId != 0 || a.saleKind != config.saleKind || a.revenueClass != 0
                || a.expectedPrimaryPolicyHash != 0 || a.primaryPolicyMode != 0
                || a.initialRecipientsHash != keccak256(abi.encode(buyer))
                || a.beneficiariesHash != keccak256(abi.encode(buyer))
                || a.tokenDataArrayHash != keccak256(abi.encode(emptyData))
                || a.mintCommitmentsHash != keccak256(abi.encode(emptyCommitments))
                || a.payer != config.buyer || a.executor != config.buyer || a.asset != address(0)
                || a.unitPrice != config.price || a.quantity != 1 || a.contentSelectionHash != 0
                || a.policyHash != 0 || a.deadline == 0 || a.deadline > config.deadline
                || a.finalizeBy != 0
        ) revert P.InvalidPrivateSale();
    }

    function validateConfig(P.SaleConfig memory config, P.CollectionSigner memory signer)
        public
        view
    {
        if (
            (config.saleKind != 5 && config.saleKind != 6) || config.tokenId == 0
                || config.consignor == address(0) || config.consignor == address(this)
                || config.buyer == address(0) || config.buyer == address(this) || config.price == 0
                || config.startTime >= config.deadline || config.deadline < block.timestamp
                || !config.secondaryConsignment || config.expectedPrimaryPolicyHash != 0
                || (config.saleKind == 5 && config.offerDigest != 0)
                || (config.saleKind == 6 && config.offerDigest == 0) || !signer.enabled
                || signer.revision == 0 || signer.evidenceHash != config.signerEvidenceHash
                || signer.revision != config.signerRevision
                || signer.authority != config.signerAuthority || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) revert P.InvalidPrivateSale();
    }

    function directOrSignature(
        address signer,
        uint8 kind,
        bytes32 digest,
        bytes memory signature,
        uint256 cap
    ) public view {
        if (kind != 1 && kind != 2) {
            revert P.PrivateSaleAuthorityInvalid(signer);
        }
        if (msg.sender != signer && !validSignature(signer, kind, digest, signature, cap)) {
            revert P.PrivateSaleAuthorityInvalid(signer);
        }
    }

    function authorizationProof(
        P.SaleConfig memory config,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        P.Signature memory proof,
        address platformSigner,
        uint256 cap
    ) public view returns (bytes32 digest) {
        authorizationFields(config, a);
        if (a.deadline < block.timestamp || proof.authorizer != platformSigner) {
            revert P.PrivateSaleAuthorityInvalid(proof.authorizer);
        }
        digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(a)
        );
        if (!validSignature(proof.authorizer, proof.kind, digest, proof.signature, cap)) {
            revert P.PrivateSaleAuthorityInvalid(proof.authorizer);
        }
    }

    function offerProof(
        P.SaleConfig memory config,
        address core,
        StreamPrivateSaleTypes.SaleOffer memory offer,
        P.Signature memory proof,
        uint256 cap
    ) public view returns (bytes32 digest) {
        digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(offer)
        );
        if (
            offer.chainId != block.chainid || offer.saleAdapter != address(this)
                || offer.core != core || offer.collectionId != config.collectionId
                || offer.tokenId != config.tokenId || offer.contentSelectionHash != 0
                || offer.buyer != config.buyer || offer.asset != address(0)
                || offer.price != config.price || offer.deadline < block.timestamp
                || offer.deadline > config.deadline || offer.finalizeBy != 0
                || digest != config.offerDigest || proof.authorizer != offer.buyer
        ) revert P.InvalidPrivateSale();
        if (!validSignature(proof.authorizer, proof.kind, digest, proof.signature, cap)) {
            revert P.PrivateSaleAuthorityInvalid(proof.authorizer);
        }
    }

    function _core(Context memory c) private view {
        if (!StreamSettlementAdmission.isContract(c.core) || c.core.codehash != c.coreCodeHash) {
            revert P.PrivateSaleReadFailed(c.core);
        }
    }

    function requireRole(address registry, bytes32 registryHash, address authority, bytes32 role)
        public
        view
    {
        if (
            registry.codehash != registryHash
                || readWord(authority, abi.encodeWithSignature("roleRegistry()"))
                    != uint256(uint160(registry))
                || readWord(registry, abi.encodeWithSignature("owner()"))
                    != uint256(uint160(authority))
                || readWord(
                        registry, abi.encodeCall(IStreamRoleRegistry.hasRole, (role, msg.sender))
                    ) != 1
        ) {
            revert P.PrivateSaleRoleNotAuthorized(role, msg.sender);
        }
    }
}
