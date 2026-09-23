// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";

/// @dev Fault-injection boundary for exact Core-side continuity responses; no authority stand-in.
contract ContinuityReadSource {
    address public immutable core;
    bytes private response;
    bool private refuses;
    bytes private inventory;
    bytes private ready;
    bool private inventoryRefuses;
    bool private readyRefuses;
    bytes32 private expectedReadyCall;

    constructor(address c) {
        core = c;
        response = abi.encode(uint256(0));
        inventory = abi.encode(uint256(3), uint64(7), bytes32(uint256(123)));
        ready = abi.encode(true);
    }

    function set(bytes memory value, bool failure) external {
        response = value;
        refuses = failure;
    }

    function setInventory(bytes memory value, bool failure) external {
        inventory = value;
        inventoryRefuses = failure;
    }

    function setReady(bytes memory value, bool failure, bytes32 expectedCall) external {
        ready = value;
        readyRefuses = failure;
        expectedReadyCall = expectedCall;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        if (msg.sig == IStreamEntropyPolicyContinuity.entropyPolicyInventory.selector) {
            require(!inventoryRefuses);
            return inventory;
        }
        if (msg.sig == IStreamEntropyPolicyContinuity.entropyPolicyImportReady.selector) {
            require(!readyRefuses);
            if (expectedReadyCall != bytes32(0) && keccak256(input) != expectedReadyCall) {
                return abi.encode(false);
            }
            return ready;
        }
        require(!refuses);
        return response;
    }
}

contract ContinuityCoreReadHarness {
    function admitted(address prior, address next, uint256 cap) external view returns (bool) {
        return StreamCoreExternalReads.entropySuccessorAdmitted(
            prior, prior.codehash, next, next.codehash, 9, cap, 165300
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

    function testPolicyInventoryRequiresExactCanonicalThreeWords() public {
        bytes memory valid = abi.encode(uint256(3), uint64(7), bytes32(uint256(123)));
        prior.setInventory(bytes(""), false);
        require(!reader.admitted(address(prior), address(next), 500000), "missing inventory");
        prior.setInventory(abi.encode(uint256(3), uint64(7)), false);
        require(!reader.admitted(address(prior), address(next), 500000), "short inventory");
        prior.setInventory(bytes.concat(valid, abi.encode(uint256(0))), false);
        require(!reader.admitted(address(prior), address(next), 500000), "long inventory");
        prior.setInventory(abi.encode(uint256(3), uint256(1) << 64, bytes32(uint256(123))), false);
        require(!reader.admitted(address(prior), address(next), 500000), "noncanonical serial");
        prior.setInventory(valid, true);
        require(!reader.admitted(address(prior), address(next), 500000), "reverting inventory");
        prior.setInventory(valid, false);
        require(reader.admitted(address(prior), address(next), 500000), "restored inventory");
    }

    function testPolicyReadinessRequiresExactCanonicalTrue() public {
        next.setReady(bytes(""), false, 0);
        require(!reader.admitted(address(prior), address(next), 500000), "missing import");
        next.setReady(abi.encode(false), false, 0);
        require(!reader.admitted(address(prior), address(next), 500000), "unsealed import");
        next.setReady(abi.encode(uint256(2)), false, 0);
        require(!reader.admitted(address(prior), address(next), 500000), "noncanonical bool");
        next.setReady(abi.encode(true, uint256(0)), false, 0);
        require(!reader.admitted(address(prior), address(next), 500000), "overlong bool");
        next.setReady(abi.encode(true), true, 0);
        require(!reader.admitted(address(prior), address(next), 500000), "reverting import");
        next.setReady(abi.encode(true), false, 0);
        require(reader.admitted(address(prior), address(next), 500000), "restored import");
    }

    function testReadyCallBindsLiveSourceRuntimeRevisionAndCompleteHeader() public {
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamEntropyPolicyContinuity.entropyPolicyImportReady,
                (
                    address(prior),
                    address(prior).codehash,
                    uint64(9),
                    uint256(3),
                    uint64(7),
                    bytes32(uint256(123))
                )
            )
        );
        next.setReady(abi.encode(true), false, expected);
        require(reader.admitted(address(prior), address(next), 500000), "exact header");
        prior.setInventory(abi.encode(uint256(2), uint64(7), bytes32(uint256(123))), false);
        require(!reader.admitted(address(prior), address(next), 500000), "omitted collection");
        prior.setInventory(abi.encode(uint256(3), uint64(8), bytes32(uint256(123))), false);
        require(!reader.admitted(address(prior), address(next), 500000), "mutated inventory");
        prior.setInventory(abi.encode(uint256(3), uint64(7), bytes32(uint256(124))), false);
        require(!reader.admitted(address(prior), address(next), 500000), "changed ordering");
        prior.setInventory(abi.encode(uint256(3), uint64(7), bytes32(uint256(123))), false);
        require(reader.admitted(address(prior), address(next), 500000), "original exact header");
        ContinuityReadSource alternate = new ContinuityReadSource(address(reader));
        require(!reader.admitted(address(alternate), address(next), 500000), "foreign source");
        expected = keccak256(
            abi.encodeCall(
                IStreamEntropyPolicyContinuity.entropyPolicyImportReady,
                (
                    address(prior),
                    address(prior).codehash,
                    uint64(10),
                    uint256(3),
                    uint64(7),
                    bytes32(uint256(123))
                )
            )
        );
        next.setReady(abi.encode(true), false, expected);
        require(!reader.admitted(address(prior), address(next), 500000), "foreign revision");
    }

    function testEmptyInventoryStillRequiresAuthenticatedSealedImport() public {
        prior.setInventory(abi.encode(uint256(0), uint64(0), bytes32(0)), false);
        next.setReady(abi.encode(false), false, 0);
        require(
            !reader.admitted(address(prior), address(next), 500000), "empty does not waive import"
        );
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamEntropyPolicyContinuity.entropyPolicyImportReady,
                (
                    address(prior),
                    address(prior).codehash,
                    uint64(9),
                    uint256(0),
                    uint64(0),
                    bytes32(0)
                )
            )
        );
        next.setReady(abi.encode(true), false, expected);
        require(reader.admitted(address(prior), address(next), 500000), "explicit empty import");
    }

    function testFuzzReadyCallPreservesEveryInventoryBit(
        uint256 count,
        uint64 serial,
        bytes32 digest
    ) public {
        prior.setInventory(abi.encode(count, serial, digest), false);
        bytes32 expected = keccak256(
            abi.encodeCall(
                IStreamEntropyPolicyContinuity.entropyPolicyImportReady,
                (address(prior), address(prior).codehash, uint64(9), count, serial, digest)
            )
        );
        next.setReady(abi.encode(true), false, expected);
        require(reader.admitted(address(prior), address(next), 500000), "inventory truncation");
    }
}
