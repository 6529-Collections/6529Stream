// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentCommerceConservationFixture.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";

/// @notice Actual Safe governance and explicitly waived DIRECT commerce for stateful campaigns.
/// @dev Reuses the full current Artist/Core graph and original fixture gas/supply limits. This
/// proves neither documentary MUSEUM/LITE evidence nor production deployment size or gas capacity.
abstract contract CurrentStatefulConservationFixture is CurrentCommerceConservationFixture {
    address internal statefulHandler;

    /// @dev The fixture/handler drives real delayed actions; no owner prank or direct pause write.
    function statefulSetNativeSalePaused(bool next) external {
        require(msg.sender == address(this) || msg.sender == statefulHandler, "stateful controller");
        bool previous = sale.paused();
        require(previous != next, "real pause transition");
        bytes32 scope =
            keccak256(abi.encode("stateful native sale pause", block.chainid, address(sale)));
        _govern(
            _governanceRequest(
                1,
                address(sale),
                abi.encodeCall(sale.setPaused, (next)),
                scope,
                keccak256(abi.encode(scope, previous)),
                keccak256(abi.encode(scope, next))
            )
        );
        require(sale.paused() == next, "actual Safe governed pause transition");
    }

    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _commerceFloorPolicies(super._additionalOperatingPolicies());
    }

    /// @dev Called after the ordinary current-stack deployment, before any subject is minted.
    function _enableStatefulConservation(address additionalERC20) internal {
        require(address(governorSafe) == address(0), "one stateful governor");
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x57A7E01;
        owners[1] = 0x57A7E02;
        owners[2] = 0x57A7E03;
        uint256[] memory signers = new uint256[](2);
        signers[0] = owners[0];
        signers[1] = owners[1];
        OfficialSafe governor = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 0x57A7E
        );
        _installGovernorSafe(governor, signers);

        StreamModuleRegistration[] memory records =
            new StreamModuleRegistration[](additionalERC20 == address(0) ? 2 : 3);
        records[0] = _statefulDirectRegistration(address(sale));
        records[1] = _statefulDirectRegistration(address(auction));
        if (additionalERC20 != address(0)) {
            require(
                additionalERC20 != address(sale) && additionalERC20 != address(auction),
                "distinct additional product"
            );
            records[2] = _statefulDirectRegistration(additionalERC20);
        }
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, action, ready
            )
        );
        executor.executeGovernanceBatch(action, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED
                && executor.governanceAction(action).proposer == address(governorSafe),
            "actual Safe registration action"
        );
        for (uint256 i; i < records.length; ++i) {
            require(
                registry.isModuleEligible(
                    records[i].module,
                    StreamDirectPrimarySaleTypes.MODULE_TYPE,
                    type(IStreamDirectPrimarySaleReceipt).interfaceId
                ),
                "actual canonical DIRECT product"
            );
        }
        _enableWaivedCommerceFloor();
    }

    function _statefulDirectRegistration(address adapter)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            adapter,
            StreamDirectPrimarySaleTypes.MODULE_TYPE,
            StreamDirectPrimarySaleTypes.MODULE_VERSION,
            type(IStreamDirectPrimarySaleReceipt).interfaceId,
            500_000,
            adapter.codehash,
            DEPLOYMENT_HASH,
            keccak256(abi.encode("stateful original DIRECT product", adapter)),
            "urn:stream:test:stateful-direct"
        );
    }

    function _statefulDirectKey(address adapter, bytes32 authorizationId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"),
                block.chainid,
                address(core),
                adapter,
                IStreamDirectPrimarySaleReceipt(adapter).directPrimaryBindings().productKind,
                authorizationId
            )
        );
    }

    function _assertNoStatefulDirectReceipt(address adapter, bytes32 authorizationId)
        internal
        view
    {
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        StreamDirectPrimarySaleTypes.Receipt memory empty;
        StreamDirectPrimaryConservationTypes.Receipt memory emptyFloor;
        StreamConservationFloorTypes.SettlementReceipt memory emptyUniversal;
        bytes32 key = _statefulDirectKey(adapter, authorizationId);
        require(
            product.directPrimarySaleReceiptHash(authorizationId) == 0
                && keccak256(abi.encode(product.directPrimarySaleReceipt(authorizationId)))
                    == keccak256(abi.encode(empty))
                && keccak256(abi.encode(commerceFloor.directPrimarySaleFloorReceipt(key)))
                    == keccak256(abi.encode(emptyFloor))
                && keccak256(abi.encode(commerceFloor.settlementReceipt(key)))
                    == keccak256(abi.encode(emptyUniversal)),
            "unpaid operation has no paid or floor receipt"
        );
    }

    function _assertStatefulDirectReceipt(
        address adapter,
        bytes32 authorizationId,
        uint256 expectedAmount
    ) internal view {
        if (expectedAmount == 0) {
            _assertNoStatefulDirectReceipt(adapter, authorizationId);
            return;
        }
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        StreamDirectPrimarySaleTypes.Bindings memory bindings = product.directPrimaryBindings();
        StreamDirectPrimarySaleTypes.Receipt memory original =
            product.directPrimarySaleReceipt(authorizationId);
        bytes32 originalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"),
                block.chainid,
                address(core),
                adapter,
                bindings.productKind,
                authorizationId,
                original
            )
        );
        require(
            bindings.core == address(core) && bindings.coreCodeHash == address(core).codehash
                && bindings.mintManager == address(manager)
                && bindings.mintManagerCodeHash == address(manager).codehash
                && bindings.deploymentChainId == block.chainid && original.collectionId == 1
                && original.amount == expectedAmount && original.payer != address(0)
                && original.beneficiary != address(0) && original.operationId != 0
                && original.authorizationDigest != 0 && original.boundMintPolicyHash != 0
                && original.expectedPrimaryPolicyHash != 0 && original.profileId == profile
                && original.wallet == wallet && original.registryRevision != 0
                && original.createdAt != 0 && original.createdAt <= block.timestamp
                && manager.isAuthorizationUsed(authorizationId)
                && manager.isOperationRootUsed(original.operationRoot)
                && product.directPrimarySaleReceiptHash(authorizationId) == originalHash,
            "genuine original DIRECT paid identity"
        );
        (bool exists, uint256 cid, uint256 serial,) = core.tokenCollectionIdentity(original.tokenId);
        uint8 lifecycle = core.tokenLifecycle(original.tokenId);
        require(
            exists && cid == 1 && serial != 0 && (lifecycle == 2 || lifecycle == 3),
            "completed permanent identity"
        );

        bytes32 key = _statefulDirectKey(adapter, authorizationId);
        StreamDirectPrimaryConservationTypes.Receipt memory recorded =
            commerceFloor.directPrimarySaleFloorReceipt(key);
        StreamConservationFloorTypes.FirstSaleReceipt memory first = commerceFloor.firstSale(1);
        StreamConservationFloorTypes.CollectionFacts memory noFacts;
        require(
            recorded.receiptHash != 0 && recorded.adapter == adapter
                && recorded.adapterCodeHash == adapter.codehash && recorded.directKey == key
                && recorded.authorizationId == authorizationId
                && recorded.originalReceiptHash == originalHash
                && keccak256(abi.encode(recorded.bindings)) == keccak256(abi.encode(bindings))
                && keccak256(abi.encode(recorded.sale)) == keccak256(abi.encode(original))
                && recorded.effectiveTier == COMMERCE_WAIVED
                && recorded.firstSaleReceiptHash == first.receiptHash && first.receiptHash != 0
                && first.collectionId == 1 && first.effectiveTier == COMMERCE_WAIVED
                && first.sourceId == 0
                && keccak256(abi.encode(first.facts)) == keccak256(abi.encode(noFacts))
                && recorded.releaseReceiptHash == 0 && recorded.recordedAt >= original.createdAt
                && recorded.recordedAt <= block.timestamp && commerceFloor.sourceCount() == 0,
            "full permanent explicitly waived DIRECT floor evidence"
        );
        bytes32 recordedHash = recorded.receiptHash;
        recorded.receiptHash = 0;
        require(
            recordedHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                        block.chainid,
                        address(core),
                        address(commerceFloor),
                        recorded
                    )
                ),
            "independent floor hash"
        );
        StreamConservationFloorTypes.SettlementReceipt memory noUniversal;
        StreamConservationFloorTypes.ReleaseFloorReceipt memory noRelease;
        require(
            keccak256(abi.encode(commerceFloor.settlementReceipt(key)))
                    == keccak256(abi.encode(noUniversal))
                && keccak256(abi.encode(commerceFloor.releaseFloorReceipt(bytes32(0))))
                    == keccak256(abi.encode(noRelease)),
            "no universal projection or invented WAIVED release evidence"
        );
    }

    /// @dev Includes the shared first receipt and explicit empty release, so callers can detect
    /// changes across payer failure, transfer, beneficiary release, or later successful sales.
    function _statefulDirectEvidenceHash(address adapter, bytes32 authorizationId)
        internal
        view
        returns (bytes32)
    {
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(adapter);
        bytes32 key = _statefulDirectKey(adapter, authorizationId);
        return keccak256(
            abi.encode(
                product.directPrimarySaleReceipt(authorizationId),
                product.directPrimarySaleReceiptHash(authorizationId),
                commerceFloor.directPrimarySaleFloorReceipt(key),
                commerceFloor.firstSale(1),
                commerceFloor.settlementReceipt(key),
                commerceFloor.releaseFloorReceipt(bytes32(0))
            )
        );
    }
}
