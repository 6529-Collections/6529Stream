// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistDeploymentSplitActualFixture.sol";

contract StreamArtistDeploymentSplitAdditionalTest is ArtistDeploymentSplitActualFixture {
    function testSplitIdentityRejectsOtherHostKindAndConfig() public {
        address expected = avm.computeCreateAddress(address(this), avm.getNonce(address(this)));
        address[3] memory wrongHost = _identityChildren(address(0x1234));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, wrongHost[0]
            )
        );
        this.deployIdentity(address(artistExtensionFactory), wrongHost, suite.archive);
        address[3] memory children = _identityChildren(expected);
        address temporary = children[0];
        children[0] = children[1];
        children[1] = temporary;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, children[0]
            )
        );
        this.deployIdentity(address(artistExtensionFactory), children, suite.archive);
        children[1] = children[0];
        children[0] = temporary;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, children[0]
            )
        );
        this.deployIdentity(address(artistExtensionFactory), children, address(0xA11CE));
        require(
            address(this.deployIdentity(address(artistExtensionFactory), children, suite.archive))
                == expected,
            "healthy exact binding remains usable"
        );
    }

    function testSplitIdentityRejectsCrossTransactionRecoveryAuthorityDrift() public {
        ArtistUnitGovernance replacement = new ArtistUnitGovernance();
        address expected = avm.computeCreateAddress(address(this), avm.getNonce(address(this)));
        address[3] memory children = _identityChildren(expected);
        // Adversarial unit boundary: both current canonical reads change, while the child's original pin remains.
        avm.mockCall(
            address(manager),
            abi.encodeWithSignature("governanceAuthority()"),
            abi.encode(address(replacement))
        );
        avm.mockCall(
            address(manager.moduleRegistry()),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(address(replacement))
        );
        avm.expectRevert(T.InvalidBinding.selector);
        this.deployIdentity(address(artistExtensionFactory), children, suite.archive);
        avm.clearMockedCalls();
        require(
            address(this.deployIdentity(address(artistExtensionFactory), children, suite.archive))
                == expected,
            "original canonical authority retry"
        );
    }

    function testSplitFactoryDoesNotReserveHostAndRetainsDistinctBirths() public {
        address host = address(0x9876);
        address first = artistExtensionFactory.deployRegistry(4, host, address(coordinator));
        StreamArtistExtensionFactory.Birth memory original = artistExtensionFactory.birth(first);
        address second = artistExtensionFactory.deployRegistry(4, host, address(coordinator));
        require(
            first != second
                && keccak256(abi.encode(original))
                    == keccak256(abi.encode(artistExtensionFactory.birth(first))),
            "no overwrite or host first-writer grief"
        );
        require(
            artistExtensionFactory.birth(second).bindingHash == original.bindingHash,
            "same immutable tuple distinct actual birth"
        );
        avm.expectRevert(StreamArtistExtensionFactory.InvalidExtensionBirth.selector);
        artistExtensionFactory.deployRegistry(0, host, address(coordinator));
    }

}
