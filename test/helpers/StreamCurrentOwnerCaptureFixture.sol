// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentCommerceConservationFixture.sol";
import "../../smart-contracts/domains/metadata/StreamOwnerRecords.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

/// @dev Shared original Owner deployment prefix and virtual hooks. Keep field order stable:
/// the test host appends its Safe, token and receipt-oracle state after these two fields.
abstract contract StreamCurrentOwnerCaptureFixture is CurrentCommerceConservationFixture {
    StreamSchemaRegistry internal ownerSchemas;
    StreamOwnerRecords internal ownerRecords;

    function _deployAdditionalProducts() internal override {
        ownerSchemas = StreamSchemaRegistry(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamSchemaRegistry.sol:StreamSchemaRegistry",
                abi.encode(address(executor))
            )
        );
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.schemas = address(ownerSchemas);
        c.executor = address(executor);
        c.deploymentManifestHash = DEPLOYMENT_HASH;
        // Raw CID of the exact manifest bytes below; publication/availability is not asserted.
        c.manifestURI = "ipfs://bafkreihrgxci5bintrod4j2fsvklcrs2pibs6h6detr2jgseg3f4emrdpq";
        c.manifestHash = keccak256("public local owner dossier recipe");
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 300000, 50000, 2
        );
        ownerRecords = StreamOwnerRecords(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/metadata/StreamOwnerRecords.sol:StreamOwnerRecords",
                    abi.encode(c)
                ))
        );
        _assertDeployableProductionInstance(address(ownerSchemas));
        _assertDeployableProductionInstance(address(ownerRecords));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(ownerSchemas),
            ownerSchemas.registerDocument.selector,
            address(ownerSchemas).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(ownerSchemas))),
            1,
            0,
            0,
            0
        );
        rows = _commerceFloorPolicies(rows);
    }
}
