// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library StreamArtistApprovals {
    error ArtistSignatureInvalid();

    bytes32 private constant _ARTIST_APPROVAL_EIP712_NAME_HASH =
        keccak256("6529StreamArtistApproval");
    bytes32 private constant _ARTIST_APPROVAL_EIP712_VERSION_HASH = keccak256("1");
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _ARTIST_APPROVAL_TYPEHASH = keccak256(
        "StreamArtistApproval(address artist,bytes32 freezeManifestHash,uint256 maxCollectionPurchases,uint256 collectionTotalSupply,uint256 finalSupplyDelay)"
    );
    bytes32 private constant _EIP2098_S_MASK =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant _SECP256K1_N_DIV_2 =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    function domainSeparator(address core, uint256 chainId) external pure returns (bytes32) {
        bytes32 domainTypehash = _EIP712_DOMAIN_TYPEHASH;
        bytes32 nameHash = _ARTIST_APPROVAL_EIP712_NAME_HASH;
        bytes32 versionHash = _ARTIST_APPROVAL_EIP712_VERSION_HASH;
        bytes32 separator;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, domainTypehash)
            mstore(add(ptr, 0x20), nameHash)
            mstore(add(ptr, 0x40), versionHash)
            mstore(add(ptr, 0x60), chainId)
            mstore(add(ptr, 0x80), core)
            separator := keccak256(ptr, 0xa0)
        }
        return separator;
    }

    function hashTypedApproval(bytes32 structHash, address core, uint256 chainId)
        external
        pure
        returns (bytes32)
    {
        bytes32 domainTypehash = _EIP712_DOMAIN_TYPEHASH;
        bytes32 nameHash = _ARTIST_APPROVAL_EIP712_NAME_HASH;
        bytes32 versionHash = _ARTIST_APPROVAL_EIP712_VERSION_HASH;
        bytes32 digest;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, domainTypehash)
            mstore(add(ptr, 0x20), nameHash)
            mstore(add(ptr, 0x40), versionHash)
            mstore(add(ptr, 0x60), chainId)
            mstore(add(ptr, 0x80), core)
            let separator := keccak256(ptr, 0xa0)
            mstore(ptr, shl(240, 0x1901))
            mstore(add(ptr, 0x02), separator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
        return digest;
    }

    function hashApproval(
        address artist,
        bytes32 freezeManifestHash,
        uint256 maxCollectionPurchases,
        uint256 collectionTotalSupply,
        uint256 finalSupplyDelay
    ) external pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _ARTIST_APPROVAL_TYPEHASH,
                artist,
                freezeManifestHash,
                maxCollectionPurchases,
                collectionTotalSupply,
                finalSupplyDelay
            )
        );
    }

    function validateEOASignature(address artist, bytes32 digest, bytes calldata signature)
        external
        pure
    {
        if (_recoverEOASigner(digest, signature) != artist) {
            revert ArtistSignatureInvalid();
        }
    }

    function _recoverEOASigner(bytes32 digest, bytes calldata signature)
        private
        pure
        returns (address)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (signature.length == 65) {
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }
        } else if (signature.length == 64) {
            bytes32 vs;
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 32))
            }
            s = vs & _EIP2098_S_MASK;
            v = uint8((uint256(vs) >> 255) + 27);
        } else {
            revert ArtistSignatureInvalid();
        }

        if (uint256(s) > _SECP256K1_N_DIV_2 || (v != 27 && v != 28)) {
            revert ArtistSignatureInvalid();
        }
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) {
            revert ArtistSignatureInvalid();
        }
        return signer;
    }
}
