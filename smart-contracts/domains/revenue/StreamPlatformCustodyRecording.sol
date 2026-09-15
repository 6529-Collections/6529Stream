// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPlatformCustodyValidation.sol";
import "../../interfaces/stream/revenue/IStreamPlatformCustodyPrimarySettlement.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamScopedNativePrimaryExecution.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementHash.sol";

/// @notice Official payment before custody delivery, with no mint or ledger operation.
library StreamPlatformCustodyRecording {
    struct Context {
        StreamNativeCustodyPrimaryAdmission.Context admission;
        bytes32 resolverHash;
        StreamNativePrimaryExecution.Context funding;
    }
    event PlatformCustodyRevenueRecorded(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        bytes32 declarationHash,
        StreamPreparedNativeRightsTypes.OriginalPolicy original,
        StreamNativeCustodySettlementTypes.Facts facts,
        bytes32 beneficiaryHash,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );

    function execute(
        Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        mapping(bytes32 => bool) storage saleConsumed,
        mapping(bytes32 => bool) storage consumed,
        mapping(
            bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult
        ) storage results,
        mapping(bytes32 => bytes32) storage factsHashes,
        mapping(bytes32 => uint256) storage official,
        mapping(address => uint256) storage total,
        bytes32 id
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r) {
        requireContext(x);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamPlatformCustodyValidation.read(x.admission, pin, id);
        (bytes32 declaration, StreamPreparedNativeRightsTypes.OriginalPolicy memory original) =
            StreamPlatformCustodyValidation.binding(x.funding.rights.resolver, msg.sender, f);
        if (
            msg.value != f.auction.winner.amount
                || f.auction.winner.payer == address(x.funding.escrow)
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        ) = StreamPlatformCustodyValidation.derive(x.funding.rights, f, msg.sender, address(this));
        if (c.sale.payer == selected.wallet) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes32 saleKey = StreamPreparedNativeSettlementHash.saleKey(
            address(this), msg.sender, f.auction.saleId, f.auction.saleNonce
        );
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), msg.sender, c.executionBinding.executionId
        );
        if (saleConsumed[saleKey] || consumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        saleConsumed[saleKey] = true;
        consumed[key] = true;
        bool escrowed = StreamScopedNativePrimaryExecution.fund(
            x.funding,
            c.sale.collectionId,
            c.sale.tokenId,
            original.mode,
            c.sale.poster,
            c.sale.amount,
            selected,
            beneficiaryHash
        );
        requireContext(x);
        StreamNativeCustodySettlementTypes.Facts memory after_ =
            StreamPlatformCustodyValidation.read(x.admission, pin, id);
        (
            bytes32 afterDeclaration,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory afterOriginal
        ) = StreamPlatformCustodyValidation.binding(x.funding.rights.resolver, msg.sender, after_);
        (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory afterCandidate,,
            bytes32 afterBeneficiaries
        ) = StreamPlatformCustodyValidation.derive(
            x.funding.rights, after_, msg.sender, address(this)
        );
        if (
            keccak256(abi.encode(f)) != keccak256(abi.encode(after_))
                || declaration != afterDeclaration
                || keccak256(abi.encode(original)) != keccak256(abi.encode(afterOriginal))
                || keccak256(abi.encode(c)) != keccak256(abi.encode(afterCandidate))
                || beneficiaryHash != afterBeneficiaries
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes32 factsHash =
            StreamPlatformCustodyHash.facts(address(this), msg.sender, f, declaration, original);
        r = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamPlatformCustodyHash.candidate(
                address(this), msg.sender, f, declaration, original, c, beneficiaryHash
            ),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            0,
            0,
            0
        );
        results[key] = r;
        factsHashes[key] = factsHash;
        official[
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1"),
                    keccak256("PRIMARY_SALE"),
                    selected.profileId,
                    selected.wallet,
                    address(0)
                )
            )
        ] += r.amount;
        total[address(0)] += r.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, r, address(0), f.auction.config.expectedPrimaryPolicyHash
        );
        emit PlatformCustodyRevenueRecorded(
            1, key, saleKey, factsHash, declaration, original, f, beneficiaryHash, r
        );
    }

    function requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.admission.core, x.admission.coreHash, x.admission.registry, x.admission.registryHash
        );
        if (
            address(x.funding.rights.resolver).codehash != x.resolverHash
                || address(x.funding.rights.factory).codehash != x.funding.factoryHash
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
    }
}
