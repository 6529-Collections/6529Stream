// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamViewRouteReadBudgetV1 as ReadBudget
} from "../../../smart-contracts/domains/finality/StreamViewRouteReadBudgetV1.sol";
import {
    IStreamViewRouteReadBudgetV1 as Budget
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";
import {
    IStreamViewSourceBinding as Source
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";

contract RouteBudgetProviderFixture {
    uint256 public supported = 1;
    bool public failBudget;
    bool public failBinding;
    bytes internal budget;
    bytes internal binding;

    function configure(uint256 flag, bool pending, bool failed, bytes memory b, bytes memory d)
        external
    {
        supported = flag;
        failBudget = pending;
        failBinding = failed;
        budget = b;
        binding = d;
    }

    fallback() external {
        bytes memory result;
        if (msg.sig == 0x01ffc9a7) {
            result = abi.encode(supported);
        } else if (msg.sig == Budget.viewRouteReadBudget.selector) {
            require(!failBudget, "pending");
            result = budget;
        } else if (msg.sig == Source.viewSourceBinding.selector) {
            require(!failBinding, "unavailable");
            result = binding;
        } else {
            revert("unexpected selector");
        }
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}

contract RouteBudgetFinalityFixture {
    address public scopeEvidenceProvider;
    bytes32 public scopeEvidenceProviderCodeHash;

    constructor(address provider) {
        scopeEvidenceProvider = provider;
        scopeEvidenceProviderCodeHash = provider.codehash;
    }

    function corruptPin() external {
        scopeEvidenceProviderCodeHash = bytes32(uint256(1));
    }
}

contract RouteBudgetHarness {
    function select(address finality, uint256 cap) external view returns (uint256, bool) {
        return ReadBudget.select(finality, cap);
    }
}

/// @dev Fixed budget kernel with typed Finality/provider boundaries. This is not the
/// full renderer/adoption/snapshot/root ceremony or its capacity acceptance.
contract StreamViewRouteReadBudgetV1Test is CharacterizationTestBase {
    bytes32 constant PROFILE = keccak256("6529STREAM_GOVERNED_VIEW_ROUTE_READ_BUDGET_V1");
    RouteBudgetProviderFixture internal provider;
    RouteBudgetFinalityFixture internal finality;
    RouteBudgetHarness internal harness;

    function setUp() public {
        provider = new RouteBudgetProviderFixture();
        finality = new RouteBudgetFinalityFixture(address(provider));
        harness = new RouteBudgetHarness();
        _configure(200000, 200000, 500000);
    }

    function _binding(uint32 cap, uint32 source) internal pure returns (bytes memory) {
        return abi.encode(
            V.Binding(
                address(0x1001),
                bytes32(uint256(2)),
                address(0x1002),
                bytes32(uint256(3)),
                cap,
                source
            )
        );
    }

    function _configure(uint256 cap, uint32 declared, uint32 source) internal {
        provider.configure(1, false, false, abi.encode(PROFILE, cap), _binding(declared, source));
    }

    function _reject() internal {
        vm.expectRevert();
        harness.select(address(finality), 56000000);
    }

    function testExplicitGovernedRouteDoesNotForwardLargeGlobalAllowance() public {
        (bool ok, bytes memory out) = address(harness).staticcall{ gas: 1000000 }(
            abi.encodeCall(harness.select, (address(finality), 56000000))
        );
        require(ok);
        (uint256 cap, bool governed) = abi.decode(out, (uint256, bool));
        require(cap == 200000);
        require(governed);
    }

    function testLegacyKeepsExactGlobalCapAndIgnoresUnadvertisedBudget() public {
        provider.configure(0, true, true, hex"01", hex"02");
        finality.corruptPin();
        (uint256 cap, bool governed) = harness.select(address(finality), 56000000);
        require(cap == 56000000);
        require(!governed);
    }

    function testMissingOptionalBootstrapKeepsLegacyValidationResponsibility() public {
        (uint256 cap, bool governed) = harness.select(address(0xdead), 200000);
        require(cap == 200000);
        require(!governed);
    }

    function testNoncanonicalInterfaceBooleanDoesNotAdvertiseProfile() public {
        provider.configure(2, true, true, hex"01", hex"02");
        (uint256 cap, bool governed) = harness.select(address(finality), 56000000);
        require(cap == 56000000);
        require(!governed);
    }

    function testAdvertisedPendingCannotFallBackToLegacy() public {
        provider.configure(
            1, true, false, abi.encode(PROFILE, uint256(200000)), _binding(200000, 500000)
        );
        _reject();
    }

    function testAdvertisedWrongProfileCannotFallBackToLegacy() public {
        provider.configure(
            1,
            false,
            false,
            abi.encode(bytes32(uint256(1)), uint256(200000)),
            _binding(200000, 500000)
        );
        _reject();
    }

    function testAdvertisedWrongRuntimePinRejected() public {
        finality.corruptPin();
        _reject();
    }

    function testAdvertisedShortBudgetRejected() public {
        provider.configure(1, false, false, abi.encode(PROFILE), _binding(200000, 500000));
        _reject();
    }

    function testAdvertisedOversizedBudgetRejected() public {
        provider.configure(1, false, false, new bytes(4096), _binding(200000, 500000));
        _reject();
    }

    function testNoncanonicalUint32BudgetRejected() public {
        _configure(uint256(1) << 32, 200000, 500000);
        _reject();
    }

    function testBelowMinimumBudgetRejected() public {
        _configure(49999, 49999, 500000);
        _reject();
    }

    function testAboveViewMaximumRejected() public {
        _configure(16777217, 16777217, 16777217);
        _reject();
    }

    function testBudgetCannotRaiseOriginalGlobalLimit() public {
        vm.expectRevert();
        harness.select(address(finality), 100000);
    }

    function testFullDeclarationMustAgreeWithCheapBudget() public {
        _configure(200000, 200001, 500000);
        _reject();
    }

    function testFullDeclarationFailureCannotFallBack() public {
        provider.configure(
            1, false, true, abi.encode(PROFILE, uint256(200000)), _binding(200000, 500000)
        );
        _reject();
    }

    function testFullDeclarationMustBeExactlySixWords() public {
        provider.configure(
            1,
            false,
            false,
            abi.encode(PROFILE, uint256(200000)),
            abi.encodePacked(_binding(200000, 500000), bytes32(0))
        );
        _reject();
    }

    function testNoncanonicalDeclarationAddressRejected() public {
        bytes memory raw = _binding(200000, 500000);
        assembly ("memory-safe") { mstore(add(raw, 32), shl(160, 1)) }
        provider.configure(1, false, false, abi.encode(PROFILE, uint256(200000)), raw);
        _reject();
    }

    function testDeclarationSourceBudgetCannotBeSmaller() public {
        _configure(200000, 200000, 199999);
        _reject();
    }

    function testAdvertisedEqualGlobalBudgetRetainsExplicitProfile() public {
        (uint256 cap, bool governed) = harness.select(address(finality), 200000);
        require(cap == 200000);
        require(governed);
    }

    function testFuzzExactGovernedBudgetWithinOriginalBounds(uint32 seed) public {
        uint32 cap = uint32(50000 + uint256(seed) % (16777216 - 50000 + 1));
        _configure(cap, cap, cap);
        (uint256 actual, bool governed) = harness.select(address(finality), 56000000);
        require(actual == cap);
        require(governed);
    }
}
