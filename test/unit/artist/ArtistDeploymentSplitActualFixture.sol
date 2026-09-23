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
abstract contract ArtistDeploymentSplitActualFixture is ArtistOnboardingFixture {
    uint256 internal constant CAP = 16_777_216;
    event SplitDeploymentGas(
        bytes32 indexed product, uint256 callGas, uint256 conservativeEnvelope
    );

    function _measure(bytes32 label, uint256 beforeGas, bytes memory callData) internal {
        uint256 used = beforeGas - gasleft();
        // Charge every calldata byte at the nonzero rate, plus transaction and call overhead margin.
        uint256 envelope = used + 21_000 + callData.length * 16 + 50_000;
        emit SplitDeploymentGas(label, used, envelope);
        require(envelope < CAP, "individual conservative deployment envelope");
    }

    function _artifactCreation(string memory coordinate) internal returns (bytes memory) {
        ArtistArtifactVm vm =
            ArtistArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory creation = vm.getCode(coordinate);
        require(creation.length != 0, "missing production creation artifact");
        return creation;
    }

    function _create(bytes memory creation, bytes memory arguments)
        internal
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

    function _identityChildren(address host) internal returns (address[3] memory children) {
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

}
