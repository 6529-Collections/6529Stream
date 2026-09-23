// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistDeploymentSplitActualFixture.sol";

contract StreamArtistDeploymentSplitTest is ArtistDeploymentSplitActualFixture {
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

}
