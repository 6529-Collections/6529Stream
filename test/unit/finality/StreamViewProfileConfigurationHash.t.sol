// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityProfileSourceReads as Source
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileSourceReads.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";

contract ViewProfileHashProbe {
    uint256 public before_ = 111;
    Source.Context private first;
    uint256 public between_ = 222;
    Source.Context private second;
    uint256 public after_ = 333;

    function install(Source.Context memory c, bool other) external {
        if (other) second = c;
        else first = c;
    }

    function stored(bool other) external view returns (bytes32) {
        return other
            ? Source.configurationHashStored(second)
            : Source.configurationHashStored(first);
    }

    function original(bool other) external view returns (bytes32) {
        return other ? Source.configurationHash(second) : Source.configurationHash(first);
    }
}

contract StreamViewProfileConfigurationHashTest {
    bytes32 private constant DOMAIN = keccak256("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1");

    function _context(uint256 seed) private pure returns (Source.Context memory c) {
        c.core = address(uint160(seed));
        c.router = address(0x222);
        c.routerCodeHash = keccak256(abi.encode(seed, "router"));
        c.chainId = 31337;
        c.readGas = 800000;
        c.policyOutput = address(0x333);
        c.policyOutputCodeHash = keccak256("output");
        for (uint256 i; i < 3; ++i) {
            c.profiles[i] = Profiles.Profile(
                keccak256(abi.encode(seed, i)),
                address(uint160(i + 10)),
                keccak256(abi.encode(i, "ref")),
                address(uint160(i + 20)),
                keccak256(abi.encode(i, "snapshot")),
                address(uint160(i + 30)),
                keccak256(abi.encode(i, "factory")),
                keccak256(abi.encode(seed, i, "config"))
            );
        }
    }

    function _check(ViewProfileHashProbe p, Source.Context memory c, bool other) private view {
        bytes32 literal = keccak256(abi.encode(DOMAIN, c.chainId, address(p), c));
        require(
            p.stored(other) == literal && p.original(other) == literal,
            "full literal/context parity"
        );
        require(p.before_() == 111 && p.between_() == 222 && p.after_() == 333, "storage canaries");
    }

    function testTwoStorageRootsAndCrossHostFullLiteralHash() public {
        ViewProfileHashProbe a = new ViewProfileHashProbe();
        ViewProfileHashProbe b = new ViewProfileHashProbe();
        Source.Context memory c = _context(42);
        Source.Context memory d = _context(43);
        a.install(c, false);
        a.install(d, true);
        b.install(c, false);
        _check(a, c, false);
        _check(a, d, true);
        _check(b, c, false);
        require(
            a.stored(false) != a.stored(true) && a.stored(false) != b.stored(false),
            "root and host distinction"
        );
    }

    function testEmptyForeignChainAndMalformedSemanticContextPreserveHashOnlyMeaning() public {
        ViewProfileHashProbe p = new ViewProfileHashProbe();
        Source.Context memory c;
        _check(p, c, false);
        c = _context(51);
        c.chainId = type(uint256).max;
        c.readGas = 0;
        c.profiles[1].profileHash = 0;
        c.profiles[2].referenceRender = address(0);
        p.install(c, true); // Original getter is an identity hash, not source admission.
        _check(p, c, true);
    }

    function testEveryContextWordMutationChangesHashAndRestores() public {
        ViewProfileHashProbe p = new ViewProfileHashProbe();
        Source.Context memory c = _context(91);
        p.install(c, false);
        bytes32 baseline = p.stored(false);
        bytes memory raw = abi.encode(c);
        require(raw.length == 31 * 32);
        for (uint256 i; i < 31; ++i) {
            bytes memory changed = abi.encode(c);
            assembly ("memory-safe") {
                let pos := add(add(changed, 32), mul(i, 32))
                mstore(pos, xor(mload(pos), 1))
            }
            Source.Context memory d = abi.decode(changed, (Source.Context));
            p.install(d, false);
            _check(p, d, false);
            require(p.stored(false) != baseline);
        }
        p.install(c, false);
        _check(p, c, false);
        require(p.stored(false) == baseline);
    }

    function testFuzzStoredHashFullContext(uint256 seed) public {
        ViewProfileHashProbe p = new ViewProfileHashProbe();
        Source.Context memory c = _context(seed);
        p.install(c, true);
        _check(p, c, true);
    }
}
