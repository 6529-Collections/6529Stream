// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice RFC5646 syntax plus case-insensitive variant/singleton uniqueness.
/// @dev This does not prove dated IANA subtag registration or extension-specific semantics.
/// Original tag bytes are never rewritten; lowercase bytes exist only for parsing/comparison.
library StreamConservationLanguage {
    error InvalidConservationLanguage();

    /// @notice Validate ordered tags in one linked call and emit their exact ASCII JSON array.
    /// @dev Accepted tag bytes contain only ALNUM/hyphen, so none need JSON escaping.
    function arrayJSON(string[] memory values) public pure returns (string memory) {
        if (values.length == 0) revert InvalidConservationLanguage();
        uint256 size = 2;
        for (uint256 i; i < values.length; ++i) {
            size += bytes(values[i]).length + 2 + (i == 0 ? 0 : 1);
            if (size > 8192) revert InvalidConservationLanguage();
            requireWellFormed(values[i]);
        }
        bytes memory out = new bytes(size);
        out[0] = "[";
        uint256 at = 1;
        for (uint256 i; i < values.length; ++i) {
            if (i != 0) out[at++] = ",";
            out[at++] = '"';
            bytes memory value = bytes(values[i]);
            for (uint256 j; j < value.length; ++j) {
                out[at++] = value[j];
            }
            out[at++] = '"';
        }
        out[at] = "]";
        return string(out);
    }

    function requireWellFormed(string memory value) public pure {
        (bytes memory b, uint256[] memory parts) = _parts(value);
        if (_grandfathered(keccak256(b))) return;
        uint256 n = parts.length;
        if (_size(parts[0]) == 1 && b[0] == "x") {
            if (n == 1) revert InvalidConservationLanguage();
            return;
        }
        uint256 languageLength = _size(parts[0]);
        if (languageLength < 2 || !_alpha(b, parts[0])) revert InvalidConservationLanguage();
        uint256 i = 1;
        if (languageLength <= 3) {
            uint256 count;
            while (i < n && count < 3 && _size(parts[i]) == 3 && _alpha(b, parts[i])) {
                ++i;
                ++count;
            }
        }
        if (i < n && _size(parts[i]) == 4 && _alpha(b, parts[i])) ++i;
        if (
            i < n
                && ((_size(parts[i]) == 2 && _alpha(b, parts[i]))
                    || (_size(parts[i]) == 3 && _digits(b, parts[i])))
        ) ++i;

        bytes32[] memory variants = new bytes32[](n);
        uint256 variantCount;
        while (i < n && _variant(b, parts[i])) {
            variants[variantCount++] = _hashPart(b, parts[i]);
            ++i;
        }
        _unique(variants, variantCount);

        uint256 singletons;
        while (i < n && _size(parts[i]) == 1 && b[parts[i] >> 8] != "x") {
            uint256 bit = uint256(1) << uint8(b[parts[i] >> 8]);
            if (singletons & bit != 0) revert InvalidConservationLanguage();
            singletons |= bit;
            ++i;
            uint256 start = i;
            while (i < n && _size(parts[i]) >= 2) ++i;
            if (i == start) revert InvalidConservationLanguage();
        }
        if (i < n && _size(parts[i]) == 1 && b[parts[i] >> 8] == "x") {
            ++i;
            if (i == n) revert InvalidConservationLanguage();
            // Every remaining part already satisfies private-use's1..8ALNUM production.
            i = n;
        }
        if (i != n) revert InvalidConservationLanguage();
    }

    function _parts(string memory value)
        private
        pure
        returns (bytes memory b, uint256[] memory parts)
    {
        bytes memory original = bytes(value);
        uint256 length = original.length;
        if (length == 0 || length > 8192 || original[0] == "-" || original[length - 1] == "-") {
            revert InvalidConservationLanguage();
        }
        b = new bytes(length);
        uint256 count = 1;
        for (uint256 i; i < length; ++i) {
            uint8 c = uint8(original[i]);
            if (c >= 65 && c <= 90) c += 32;
            if (c == 45) {
                if (i != 0 && original[i - 1] == "-") revert InvalidConservationLanguage();
                ++count;
            } else if (!((c >= 97 && c <= 122) || (c >= 48 && c <= 57))) {
                revert InvalidConservationLanguage();
            }
            b[i] = bytes1(c);
        }
        parts = new uint256[](count);
        uint256 start;
        uint256 index;
        for (uint256 i; i <= length; ++i) {
            if (i == length || b[i] == "-") {
                uint256 size = i - start;
                if (size == 0 || size > 8) revert InvalidConservationLanguage();
                parts[index++] = start << 8 | size;
                start = i + 1;
            }
        }
    }

    function _size(uint256 part) private pure returns (uint256) {
        return part & 255;
    }

    function _alpha(bytes memory b, uint256 part) private pure returns (bool) {
        uint256 start = part >> 8;
        uint256 end = start + _size(part);
        for (uint256 i = start; i < end; ++i) {
            if (b[i] < "a" || b[i] > "z") return false;
        }
        return true;
    }

    function _digits(bytes memory b, uint256 part) private pure returns (bool) {
        uint256 start = part >> 8;
        uint256 end = start + _size(part);
        for (uint256 i = start; i < end; ++i) {
            if (b[i] < "0" || b[i] > "9") return false;
        }
        return true;
    }

    function _variant(bytes memory b, uint256 part) private pure returns (bool) {
        uint256 size = _size(part);
        return size >= 5 || (size == 4 && b[part >> 8] >= "0" && b[part >> 8] <= "9");
    }

    function _hashPart(bytes memory b, uint256 part) private pure returns (bytes32) {
        bytes memory out = new bytes(_size(part));
        for (uint256 i; i < out.length; ++i) {
            out[i] = b[(part >> 8) + i];
        }
        return keccak256(out);
    }

    function _unique(bytes32[] memory hashes, uint256 n) private pure {
        for (uint256 i = n / 2; i != 0;) {
            --i;
            _sift(hashes, i, n);
        }
        for (uint256 end = n; end > 1;) {
            --end;
            (hashes[0], hashes[end]) = (hashes[end], hashes[0]);
            _sift(hashes, 0, end);
        }
        for (uint256 i = 1; i < n; ++i) {
            if (hashes[i - 1] == hashes[i]) revert InvalidConservationLanguage();
        }
    }

    function _sift(bytes32[] memory hashes, uint256 root, uint256 n) private pure {
        while (root < n / 2) {
            uint256 child = root * 2 + 1;
            if (child + 1 < n && hashes[child] < hashes[child + 1]) ++child;
            if (hashes[root] >= hashes[child]) return;
            (hashes[root], hashes[child]) = (hashes[child], hashes[root]);
            root = child;
        }
    }

    /// @dev The complete permanent26-tag regular/irregular set in RFC5646 section2.1.
    function _grandfathered(bytes32 h) private pure returns (bool) {
        return h == keccak256("en-gb-oed") || h == keccak256("i-ami") || h == keccak256("i-bnn")
            || h == keccak256("i-default") || h == keccak256("i-enochian")
            || h == keccak256("i-hak") || h == keccak256("i-klingon") || h == keccak256("i-lux")
            || h == keccak256("i-mingo") || h == keccak256("i-navajo") || h == keccak256("i-pwn")
            || h == keccak256("i-tao") || h == keccak256("i-tay") || h == keccak256("i-tsu")
            || h == keccak256("sgn-be-fr") || h == keccak256("sgn-be-nl")
            || h == keccak256("sgn-ch-de") || h == keccak256("art-lojban")
            || h == keccak256("cel-gaulish") || h == keccak256("no-bok") || h == keccak256("no-nyn")
            || h == keccak256("zh-guoyu") || h == keccak256("zh-hakka") || h == keccak256("zh-min")
            || h == keccak256("zh-min-nan") || h == keccak256("zh-xiang");
    }
}
