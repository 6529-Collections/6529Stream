// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistDeploymentSplitActualFixture.sol";

contract StreamArtistDeploymentSplitIdentityBTest is ArtistDeploymentSplitActualFixture {
    function testSplitIdentityRejectsChangedRuntimeAndRestoredOriginalRetries() public {
        address expected = avm.computeCreateAddress(address(this), avm.getNonce(address(this)));
        address[3] memory children = _identityChildren(expected);
        bytes memory original = children[0].code;
        vm.etch(children[0], hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamArtistExtensionAdmission.InvalidExtensionBinding.selector, children[0]
            )
        );
        this.deployIdentity(address(artistExtensionFactory), children, suite.archive);
        vm.etch(children[0], original);
        require(
            address(this.deployIdentity(address(artistExtensionFactory), children, suite.archive))
                == expected,
            "restored original runtime retry"
        );
    }

    function testSplitHostsPreserveOriginalSafeIngressAndDirectChildRejection() public {
        _all();
        StreamArtistIdentityAuthority identity = StreamArtistIdentityAuthority(suite.owners[2]);
        require(
            _originalExtension(identity.identityWriterExtension(), address(identity), 1)
                && _originalExtension(ingress.registryReadExtension(), address(ingress), 5),
            "full original factory receipts"
        );
        require(
            IStreamArtistIdentityOwner(address(identity)).identity(artistId).authorityAddress
                == address(artist),
            "original Safe identity"
        );
        (bool readerOk, bytes memory readerError) = ingress.registryReadExtension()
            .staticcall(abi.encodeWithSignature("estateActivationState(bytes32)", artistId));
        require(
            !readerOk
                && keccak256(readerError)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamArtistRegistryReadExtension.ExtensionWrongHost.selector,
                            address(this)
                        )
                    ),
            "actual reader selector rejects non-facade caller"
        );
        (bool writerOk, bytes memory writerError) = identity.identityWriterExtension()
            .staticcall(abi.encodeWithSignature("ownerStateSnapshotV2()"));
        require(
            !writerOk
                && keccak256(writerError)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamArtistIdentityWriterExtension.ExtensionWrongHost.selector,
                            identity.identityWriterExtension()
                        )
                    ),
            "actual writer selector requires delegatecall host"
        );
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        bytes memory direct = abi.encodeWithSignature(
            "deployWriter(address,address,address,address,address,address)",
            address(identity),
            suite.registry,
            address(coordinator),
            suite.archive,
            suite.core,
            suite.mintManager
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeTargetSafe(address(StreamArtistIdentityExtensionDeployment), direct);
        require(
            artist.nonce() == safeNonce && _roots() == roots,
            "direct linked library is not an authority path"
        );
    }
}
