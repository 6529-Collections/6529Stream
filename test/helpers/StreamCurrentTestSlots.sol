// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamDeploymentSlot } from "../../script/current/StreamDeploymentSlot.sol";
import {
    StreamCurrentFinalityArtifacts,
    CurrentGraphArtifactVm
} from "../../script/current/StreamCurrentFinalityArtifacts.sol";
import {
    StreamArtistExtensionFactory
} from "../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistEstateCoverage
} from "../../smart-contracts/domains/artist/StreamArtistEstateCoverage.sol";
import {
    StreamArtistTimingState
} from "../../smart-contracts/domains/artist/StreamArtistTimingState.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";

/// @notice Fixed slot and split-Artist operations for current test fixtures.
/// @dev DELEGATECALL retains the fixture's CREATE identity and outward caller.
/// Split preparation returns before the original host artifact/runtime hooks;
/// finishing resumes the original slot deployment only after those hooks succeed.
library StreamCurrentTestSlots {
    CurrentGraphArtifactVm private constant graphVm =
        CurrentGraphArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct FacadeContext {
        address operator_;
        address factory_;
        address[5] p;
        bytes32 deploymentHash;
        string uri;
        bytes32 manifestHash;
    }

    struct IdentityContext {
        address operator_;
        address factory_;
        address[5] p;
    }

    struct SplitPlan {
        StreamDeploymentSlot slot;
        address[3] children;
        string name;
        string[] parents;
        StreamCurrentFinalityArtifacts.RuntimeValue[] values;
    }

    function reserve(address graphOperator)
        public
        returns (StreamDeploymentSlot slot, address expected)
    {
        slot = new StreamDeploymentSlot(graphOperator);
        expected = slot.product();
        require(
            slot.operator() == graphOperator && !slot.consumed()
                && graphVm.getNonce(address(slot)) == 1,
            "fresh operator-owned CREATE coordinate"
        );
        require(
            expected == graphVm.computeCreateAddress(address(slot), 1), "exact product reservation"
        );
    }

    function deploySlot(
        address graphOperator,
        StreamDeploymentSlot slot,
        address expected,
        bytes calldata creation,
        bytes calldata args,
        bytes calldata runtime
    ) public returns (address product) {
        require(
            slot.operator() == graphOperator && slot.product() == expected && !slot.consumed(),
            "original operator reservation"
        );
        require(graphVm.getNonce(address(slot)) == 1, "only first CREATE admitted");
        product = slot.deploy(bytes.concat(creation, args), keccak256(runtime));
        require(
            product == expected && graphVm.getNonce(address(slot)) == 2 && slot.consumed(),
            "one original product CREATE"
        );
        require(keccak256(product.code) == keccak256(runtime), "full actual runtime bytes");
    }

    function prepareFacade(FacadeContext calldata c) public returns (SplitPlan memory) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(c.operator_);
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] = StreamArtistExtensionFactory(c.factory_)
                .deployRegistry(i + 4, slot.product(), c.p[2]);
        }
        StreamCurrentFinalityArtifacts.RuntimeValue[] memory v =
            new StreamCurrentFinalityArtifacts.RuntimeValue[](14);
        string memory name = "StreamArtistOnboardingRegistry";
        v[0] = _runtimeValue("artist", name, "core", _addressWord(c.p[0]));
        v[1] = _runtimeValue("artist", name, "mintManager", _addressWord(c.p[1]));
        v[2] = _runtimeValue("artist", name, "operationCoordinator", _addressWord(c.p[2]));
        v[3] = _runtimeValue("artist", name, "registryWriterExtension", _addressWord(children[0]));
        v[4] = _runtimeValue("artist", name, "registryReadExtension", _addressWord(children[1]));
        v[5] = _runtimeValue(
            "artist", name, "registryFinalityReadExtension", _addressWord(children[2])
        );
        v[6] = _runtimeValue("artist", name, "archivalCoverage", _addressWord(c.p[4]));
        v[7] = _runtimeValue("artist", name, "archivalCoverageCodeHash", c.p[4].codehash);
        v[8] = _runtimeValue(
            "artist",
            name,
            "archivalCoverageConfigurationHash",
            StreamArtistEstateCoverage.admit(c.p[0], c.p[1], c.p[3], c.p[4])
        );
        v[9] = _runtimeValue(
            "parameters", "StreamGasParameterHost", "governanceAuthority", _addressWord(c.p[3])
        );
        v[10] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.artist-onboarding.v1")
        );
        v[11] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", bytes32(0));
        v[12] = _runtimeValue(
            "modules", "StreamModuleBase", "_deploymentManifestHash", c.deploymentHash
        );
        v[13] = _runtimeValue("modules", "StreamModuleBase", "_manifestHash", c.manifestHash);
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        return SplitPlan(slot, children, name, parents, v);
    }

    function finishFacade(
        FacadeContext calldata c,
        SplitPlan calldata plan,
        bytes calldata creation,
        bytes calldata runtime
    ) public returns (StreamArtistOnboardingRegistry) {
        address host = plan.slot
            .deploy(
                bytes.concat(
                    creation,
                    abi.encode(
                        c.p[0],
                        c.p[1],
                        c.p[2],
                        c.p[3],
                        c.p[4],
                        c.deploymentHash,
                        c.uri,
                        c.manifestHash,
                        c.factory_,
                        plan.children
                    )
                ),
                keccak256(runtime)
            );
        require(
            host == plan.slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split facade runtime"
        );
        return StreamArtistOnboardingRegistry(payable(host));
    }

    function prepareIdentity(IdentityContext calldata c) public returns (SplitPlan memory) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(c.operator_);
        address[3] memory children;
        address[6] memory pins = [slot.product(), c.p[0], c.p[1], c.p[2], c.p[3], c.p[4]];
        for (uint8 i; i < 3; ++i) {
            children[i] = StreamArtistExtensionFactory(c.factory_).deployIdentity(i + 1, pins);
        }
        StreamCurrentFinalityArtifacts.RuntimeValue[] memory v =
            new StreamCurrentFinalityArtifacts.RuntimeValue[](13);
        string memory name = "StreamArtistIdentityAuthority";
        v[0] = _runtimeValue("artist", "StreamArtistOwner", "artistRegistry", _addressWord(c.p[0]));
        v[1] = _runtimeValue(
            "artist", "StreamArtistOwner", "operationCoordinator", _addressWord(c.p[1])
        );
        v[2] = _runtimeValue("artist", "StreamArtistOwner", "archiveV2", _addressWord(c.p[2]));
        v[3] = _runtimeValue("artist", "StreamArtistOwner", "core", _addressWord(c.p[3]));
        v[4] = _runtimeValue("artist", "StreamArtistOwner", "mintManager", _addressWord(c.p[4]));
        v[5] = _runtimeValue(
            "artist", "StreamArtistOwner", "deploymentChainId", bytes32(block.chainid)
        );
        v[6] = _runtimeValue(
            "artist", "StreamArtistOwner", "domainId", keccak256("domain:identity_authority")
        );
        v[7] = _runtimeValue(
            "artist",
            name,
            "artistWindowAuthority",
            _addressWord(StreamArtistTimingState.canonicalAuthority(c.p[3], c.p[4]))
        );
        v[8] = _runtimeValue("artist", name, "identityWriterExtension", _addressWord(children[0]));
        v[9] = _runtimeValue("artist", name, "identityEstateExtension", _addressWord(children[1]));
        v[10] =
            _runtimeValue("artist", name, "identityRecoveryExtension", _addressWord(children[2]));
        // The real Identity constructor creates these children in order through fixed
        // delegatecalled deployment libraries. Both CREATEs execute in the new host.
        v[11] = _runtimeValue(
            "artist",
            name,
            "identityAdjudicationExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 1))
        );
        v[12] = _runtimeValue(
            "artist",
            name,
            "identityRewindExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 2))
        );
        string[] memory parents = new string[](1);
        parents[0] = "StreamArtistOwner";
        return SplitPlan(slot, children, name, parents, v);
    }

    function finishIdentity(
        IdentityContext calldata c,
        SplitPlan calldata plan,
        bytes calldata creation,
        bytes calldata runtime
    ) public returns (address host) {
        host = plan.slot
            .deploy(
                bytes.concat(
                    creation,
                    abi.encode(c.p[0], c.p[1], c.p[2], c.p[3], c.p[4], c.factory_, plan.children)
                ),
                keccak256(runtime)
            );
        require(
            host == plan.slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split Identity runtime"
        );
    }

    function _runtimeValue(
        string memory domain,
        string memory name,
        string memory variable,
        bytes32 value
    ) private pure returns (StreamCurrentFinalityArtifacts.RuntimeValue memory) {
        return StreamCurrentFinalityArtifacts.RuntimeValue(
                string.concat("smart-contracts/domains/", domain, "/", name, ".sol"),
                name,
                variable,
                value
            );
    }

    function _addressWord(address value) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }
}
