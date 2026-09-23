// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistDeploymentSplitActualFixture.sol";

contract StreamArtistDeploymentSplitIdentityATest is ArtistDeploymentSplitActualFixture {
    function testSplitFacadeRejectsWrongHostAndKindThenRetries() public {
        address expected = avm.computeCreateAddress(address(this), avm.getNonce(address(this)));
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] =
                artistExtensionFactory.deployRegistry(i + 4, address(0x1234), address(coordinator));
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, children[0]
            )
        );
        this.deployFacade(address(artistExtensionFactory), children);
        for (uint8 i; i < 3; ++i) {
            children[i] =
                artistExtensionFactory.deployRegistry(i + 4, expected, address(coordinator));
        }
        address original = children[0];
        children[0] = children[1];
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, children[0]
            )
        );
        this.deployFacade(address(artistExtensionFactory), children);
        children[0] = original;
        require(
            address(this.deployFacade(address(artistExtensionFactory), children)) == expected,
            "same facade coordinate remains usable"
        );
    }

    function testSplitIdentityRejectsFakeFactoryAndRetriesSameCoordinate() public {
        address expected = avm.computeCreateAddress(address(this), avm.getNonce(address(this)));
        address[3] memory children = _identityChildren(expected);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, address(core)
            )
        );
        this.deployIdentity(address(core), children, suite.archive);
        require(expected.code.length == 0, "failed host absent");
        require(
            address(this.deployIdentity(address(artistExtensionFactory), children, suite.archive))
                == expected,
            "same coordinate retry"
        );
    }

}
