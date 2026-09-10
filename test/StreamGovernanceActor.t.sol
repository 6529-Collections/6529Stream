// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "./helpers/CharacterizationTestBase.sol";

contract GovernanceActorTarget {
    error Rejected();
    address public caller;
    uint256 public value;

    function setValue(uint256 value_) external payable returns (uint256) {
        caller = msg.sender;
        value = value_;
        return value_ + 1;
    }

    function reject() external pure {
        revert Rejected();
    }
}

contract StreamGovernanceActorTest is CharacterizationTestBase {
    function testControllerExercisesContractAuthorityAndForwardsValue() public {
        StreamGovernanceActor actor = new StreamGovernanceActor(address(this));
        GovernanceActorTarget target = new GovernanceActorTarget();
        vm.deal(address(this), 1 ether);
        bytes memory result = actor.execute{ value: 1 ether }(
            address(target), 1 ether, abi.encodeCall(target.setValue, (7))
        );
        require(target.caller() == address(actor), "actual contract authority");
        require(target.value() == 7 && abi.decode(result, (uint256)) == 8, "call and return data");
        require(address(target).balance == 1 ether, "exact forwarded value");
    }

    function testRejectsNonControllerAndBubblesTargetRevert() public {
        StreamGovernanceActor actor = new StreamGovernanceActor(address(this));
        GovernanceActorTarget target = new GovernanceActorTarget();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamGovernanceActor.UnauthorizedController.selector, address(1)
            )
        );
        vm.prank(address(1));
        actor.execute(address(target), 0, abi.encodeCall(target.setValue, (7)));
        require(target.value() == 0, "unauthorized call had no effect");
        vm.expectRevert(abi.encodeWithSelector(GovernanceActorTarget.Rejected.selector));
        actor.execute(address(target), 0, abi.encodeCall(target.reject, ()));
    }
}
