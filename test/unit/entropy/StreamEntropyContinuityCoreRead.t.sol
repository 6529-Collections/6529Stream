// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";

/// @dev Fault-injection boundary for exact Core-side continuity responses; no authority stand-in.
contract ContinuityReadSource {
    address public immutable core;
    bytes private response;
    bool private refuses;

    constructor(address c) {
        core = c;
        response = abi.encode(uint256(0));
    }

    function set(bytes memory value, bool failure) external {
        response = value;
        refuses = failure;
    }

    fallback(bytes calldata) external returns (bytes memory) {
        require(!refuses);
        return response;
    }
}

contract ContinuityCoreReadHarness {
    function admitted(address prior, address next, uint256 cap) external view returns (bool) {
        return StreamCoreExternalReads.entropySuccessorAdmitted(
            prior, prior.codehash, next, next.codehash, cap, 165300
        );
    }
}

contract StreamEntropyContinuityCoreReadTest {
    ContinuityCoreReadHarness private reader;
    ContinuityReadSource private prior;
    ContinuityReadSource private next;

    function setUp() public {
        reader = new ContinuityCoreReadHarness();
        prior = new ContinuityReadSource(address(reader));
        next = new ContinuityReadSource(address(reader));
    }

    function testMissingOverlongRevertingAndForeignCoreReadsRefuse() public {
        require(reader.admitted(address(prior), address(next), 500000));
        prior.set(bytes(""), false);
        require(!reader.admitted(address(prior), address(next), 500000));
        prior.set(abi.encode(uint256(0), uint256(0)), false);
        require(!reader.admitted(address(prior), address(next), 500000));
        prior.set(abi.encode(uint256(0)), true);
        require(!reader.admitted(address(prior), address(next), 500000));
        prior.set(abi.encode(uint256(0)), false);
        ContinuityReadSource foreign = new ContinuityReadSource(address(this));
        require(!reader.admitted(address(prior), address(foreign), 500000));
        require(reader.admitted(address(prior), address(next), 500000));
    }

    function testInsufficientParentBudgetCannotAdmitEvenZeroPending() public view {
        (bool ok, bytes memory result) = address(reader).staticcall{ gas: 300000 }(
            abi.encodeCall(reader.admitted, (address(prior), address(next), 500000))
        );
        require(
            ok && !abi.decode(result, (bool)), "must not forward reduced cap and infer currentness"
        );
        require(reader.admitted(address(prior), address(next), 500000));
    }

    function testFuzzOnlyExactZeroCountAdmits(uint256 count) public {
        prior.set(abi.encode(count), false);
        require(reader.admitted(address(prior), address(next), 500000) == (count == 0));
    }
}
