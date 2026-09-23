// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol";
import {
    StreamArtistEstateCreationPart
} from "../../../smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol";

import "./ArtistOnboardingFixture.sol";
import { ArtistArtifactVm } from "../../helpers/ArtistArtifactCreate.sol";
import {
    StreamArtistExtensionAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistExtensionAdmission.sol";
import {
    StreamArtistExtensionFactory
} from "../../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistExtensionFactoryRuntime
} from "../../../smart-contracts/domains/artist/StreamArtistExtensionFactoryRuntime.sol";

/// @notice Actual fixed Artist products and Safe ingress with the original explicit unit Core/governance boundaries.
/// @dev Call-envelope measurements precede separate transaction receipt acceptance; no full current graph claim.
contract StreamArtistDeploymentSplitTest is ArtistOnboardingFixture {
    uint256 private constant CAP = 16_777_216;
    event SplitDeploymentGas(
        bytes32 indexed product, uint256 callGas, uint256 conservativeEnvelope
    );

    function _measure(bytes32 label, uint256 beforeGas, bytes memory callData) private {
        uint256 used = beforeGas - gasleft();
        // Charge every calldata byte at the nonzero rate, plus transaction and call overhead margin.
        uint256 envelope = used + 21_000 + callData.length * 16 + 50_000;
        emit SplitDeploymentGas(label, used, envelope);
        require(envelope < CAP, "individual conservative deployment envelope");
    }

    function _artifactCreation(string memory coordinate) private returns (bytes memory) {
        ArtistArtifactVm vm =
            ArtistArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory creation = vm.getCode(coordinate);
        require(creation.length != 0, "missing production creation artifact");
        return creation;
    }

    function _create(bytes memory creation, bytes memory arguments)
        private
        returns (address deployed)
    {
        bytes memory init = bytes.concat(creation, arguments);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function _identityChildren(address host) private returns (address[3] memory children) {
        for (uint8 i; i < 3; ++i) {
            children[i] = artistExtensionFactory.deployIdentity(
                i + 1,
                [
                    host,
                    suite.registry,
                    address(coordinator),
                    suite.archive,
                    suite.core,
                    suite.mintManager
                ]
            );
        }
    }

    function deployIdentity(address factory_, address[3] memory children, address archive_)
        external
        returns (StreamArtistIdentityAuthority)
    {
        require(msg.sender == address(this), "fixture deployment only");
        return StreamArtistIdentityAuthority(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
                    abi.encode(
                        suite.registry,
                        address(coordinator),
                        archive_,
                        suite.core,
                        suite.mintManager,
                        factory_,
                        children
                    )
                ))
        );
    }

    function testEachActualFactoryChildAndHostFitsConservativeDeploymentEnvelope() public {
        address[4] memory parts;
        for (uint8 i; i < 4; ++i) {
            bytes memory creation;
            bytes memory partInit;
            if (i < 2) {
                creation = _artifactCreation(
                    "smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol:StreamArtistIdentityCreationPart"
                );
            } else {
                creation = _artifactCreation(
                    "smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol:StreamArtistEstateCreationPart"
                );
            }
            uint256 beforePart = gasleft();
            bytes memory arguments = abi.encode(i < 2 ? i : i - 2);
            parts[i] = _create(creation, arguments);
            partInit = bytes.concat(creation, arguments);
            _measure(bytes32(uint256(100 + i)), beforePart, partInit);
            require(
                parts[i].code.length <= 24_576 && partInit.length <= 49_152,
                "part deployment bounds"
            );
        }
        bytes memory factoryCreation = _artifactCreation(
            "smart-contracts/domains/artist/StreamArtistExtensionFactory.sol:StreamArtistExtensionFactory"
        );
        uint256 started = gasleft();
        StreamArtistExtensionFactory f =
            StreamArtistExtensionFactory(_create(factoryCreation, abi.encode(parts)));
        _measure(keccak256("factory"), started, bytes.concat(factoryCreation, abi.encode(parts)));
        require(
            address(f).codehash == StreamArtistExtensionFactoryRuntime.expected()
                && address(f).code.length <= 24_576,
            "canonical factory runtime"
        );
        uint64 nonce = avm.getNonce(address(this));
        address facade = avm.computeCreateAddress(address(this), nonce);
        address owner = avm.computeCreateAddress(address(this), nonce + 1);
        address[3] memory readers;
        address[3] memory writers;
        for (uint8 i; i < 3; ++i) {
            bytes memory data =
                abi.encodeCall(f.deployRegistry, (i + 4, facade, address(coordinator)));
            started = gasleft();
            readers[i] = f.deployRegistry{ gas: CAP - 100_000 }(i + 4, facade, address(coordinator));
            _measure(bytes32(uint256(i + 4)), started, data);
        }
        address[6] memory pins =
            [owner, facade, address(coordinator), suite.archive, suite.core, suite.mintManager];
        for (uint8 i; i < 3; ++i) {
            bytes memory data = abi.encodeCall(f.deployIdentity, (i + 1, pins));
            started = gasleft();
            writers[i] = f.deployIdentity{ gas: CAP - 100_000 }(i + 1, pins);
            _measure(bytes32(uint256(i + 1)), started, data);
        }
        bytes memory facadeArgs = abi.encode(
            suite.core,
            suite.mintManager,
            address(coordinator),
            address(manager.governanceAuthority()),
            address(estateCoverageProvider),
            keccak256("split deployment"),
            "urn:split-facade",
            keccak256("split manifest"),
            address(f),
            readers
        );
        bytes memory facadeCreation = _artifactCreation(
            "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry"
        );
        started = gasleft();
        StreamArtistOnboardingRegistry actualFacade =
            StreamArtistOnboardingRegistry(payable(_create(facadeCreation, facadeArgs)));
        _measure(keccak256("facade"), started, bytes.concat(facadeCreation, facadeArgs));
        bytes memory ownerArgs = abi.encode(
            facade,
            address(coordinator),
            suite.archive,
            suite.core,
            suite.mintManager,
            address(f),
            writers
        );
        bytes memory ownerCreation = _artifactCreation(
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority"
        );
        started = gasleft();
        StreamArtistIdentityAuthority actualOwner =
            StreamArtistIdentityAuthority(payable(_create(ownerCreation, ownerArgs)));
        _measure(keccak256("Identity"), started, bytes.concat(ownerCreation, ownerArgs));
        require(
            address(actualFacade) == facade && address(actualOwner) == owner,
            "original planned host coordinates"
        );
        require(
            facade.code.length <= 24_576 && owner.code.length <= 24_576, "both host runtimes fit"
        );
        require(
            facadeCreation.length + facadeArgs.length <= 49_152
                && ownerCreation.length + ownerArgs.length <= 49_152,
            "argument-inclusive host initcode"
        );
        require(
            avm.getNonce(facade) == 1 && avm.getNonce(owner) == 1, "hosts perform no child CREATE"
        );
        require(
            actualOwner.identityWriterExtension() == writers[0]
                && actualFacade.registryFinalityReadExtension() == readers[2],
            "exact immutable children"
        );
    }

    function deployFacade(address factory_, address[3] memory children)
        external
        returns (StreamArtistOnboardingRegistry)
    {
        require(msg.sender == address(this), "fixture deployment only");
        return StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        suite.core,
                        suite.mintManager,
                        address(coordinator),
                        address(manager.governanceAuthority()),
                        address(estateCoverageProvider),
                        keccak256("split deployment"),
                        "urn:split-facade",
                        keccak256("split manifest"),
                        factory_,
                        children
                    )
                ))
        );
    }

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
