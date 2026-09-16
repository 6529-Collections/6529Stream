// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../script/current/StreamArtistActivationPlan.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Read-only planning boundary; actual Executor and cold artist calls are tested separately.
contract ArtistReadBudgetPlanHost {
    uint256 private _value = 300_000;
    uint256 private _floor = 150_000;
    uint8 private _failure = 2;
    uint64 private _revision = 2;

    function set(uint256 value, uint256 floor, uint8 failure, uint64 revision) external {
        _value = value;
        _floor = floor;
        _failure = failure;
        _revision = revision;
    }

    function gasParameterInfo(bytes32 id) external view returns (uint256, uint256, uint8, uint64) {
        require(id == keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT"), "exact artist key");
        return (_value, _floor, _failure, _revision);
    }
}

contract ArtistReadBudgetPlanHarness {
    function build(address host) external view returns (StreamArtistActivationPlan.Plan memory) {
        return StreamArtistActivationPlan.buildReadBudgetExpansion(IStreamGasParameterHost(host));
    }
}

contract StreamArtistReadBudgetPlanTest is CharacterizationTestBase {
    ArtistReadBudgetPlanHost private host;
    ArtistReadBudgetPlanHarness private planner;

    function setUp() public {
        host = new ArtistReadBudgetPlanHost();
        planner = new ArtistReadBudgetPlanHarness();
    }

    function testExactSecondRaisePreservesKeyFloorFailureClassAndRevision() public view {
        StreamArtistActivationPlan.Plan memory plan = planner.build(address(host));
        require(plan.calls.length == 1 && plan.callDatas.length == 1, "one governed transition");
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        GovernanceCall memory call_ = plan.calls[0];
        require(
            call_.target == address(host) && call_.value == 0
                && call_.selector == IStreamGasParameterHost.raiseGasParameter.selector,
            "exact host and raise selector"
        );
        bytes memory expectedData = abi.encodeWithSelector(
            IStreamGasParameterHost.raiseGasParameter.selector, id, uint256(600_000)
        );
        require(
            keccak256(plan.callDatas[0]) == keccak256(expectedData)
                && call_.callDataHash == keccak256(expectedData),
            "exact600k payload"
        );
        require(call_.scopeHash == scope, "chain and Manager-bound scope");
        require(
            call_.oldValueHash
                    == keccak256(
                        abi.encode(
                            domain, scope, uint256(300_000), uint256(150_000), uint8(2), uint64(2)
                        )
                    )
                && call_.newValueHash
                    == keccak256(
                        abi.encode(
                            domain, scope, uint256(600_000), uint256(150_000), uint8(2), uint64(3)
                        )
                    ),
            "exact old and new state commitments"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(
            value == 300_000 && floor == 150_000 && failure == 2 && revision == 2,
            "planning neither raises budget nor changes authority"
        );
    }

    function testCannotSkipOriginalInitialRaise() public {
        host.set(150_000, 150_000, 2, 1);
        vm.expectRevert();
        planner.build(address(host));
    }

    function testCannotBuildAgainAfterExpansion() public {
        host.set(600_000, 150_000, 2, 3);
        vm.expectRevert();
        planner.build(address(host));
    }

    function testRejectsChangedFloorOrFailureClass() public {
        host.set(300_000, 150_001, 2, 2);
        vm.expectRevert();
        planner.build(address(host));
        host.set(300_000, 150_000, 1, 2);
        vm.expectRevert();
        planner.build(address(host));
    }

    function testFuzzRejectsOtherRevisionWithoutGuessingHistoricalState(uint64 revision) public {
        if (revision == 2) return;
        host.set(300_000, 150_000, 2, revision);
        vm.expectRevert();
        planner.build(address(host));
    }
}
