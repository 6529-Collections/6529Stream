// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeFixedPriceSaleAdapter as F
} from "../../interfaces/stream/mint/IStreamNativeFixedPriceSaleAdapter.sol";
import {
    IStreamNativePricePrograms as P
} from "../../interfaces/stream/mint/IStreamNativePricePrograms.sol";
import { IStreamArtistSaleFacts } from "../../interfaces/stream/artist/IStreamArtistSaleFacts.sol";
import "./StreamNativePriceProgram.sol";
import "./StreamImmediateSaleReveal.sol";
import "./StreamSaleConsent.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";

/// @notice Fixed host-context read/registration worker. Existing host owns guard, caller checks and nonce.
/// @dev Registration has no external call after its final admission read: final writes/events
/// use that coordinate, and the host advances its scalar immediately after return. Views alone return raw bytes.
library StreamNativeImmediateSaleWorker {
    event NativeSaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash
    );
    event NativePriceProgramConfigured(
        bytes32 indexed saleId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash,
        P.PriceProgramConfig config,
        uint64 createdAt,
        uint64 registryRevision
    );

    function read(
        mapping(bytes32 => F.SaleRecord) storage sales,
        mapping(bytes32 => P.PriceProgramRecord) storage programs,
        address core,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == F.saleIdFor.selector) {
            (uint256 collection, bytes32 phase, uint256 nonce) =
                abi.decode(data[4:], (uint256, bytes32, uint256));
            return abi.encode(_id(collection, phase, 0, nonce));
        }
        if (selector == P.priceProgramIdFor.selector) {
            (uint256 collection, bytes32 phase, uint8 kind, uint256 nonce) =
                abi.decode(data[4:], (uint256, bytes32, uint8, uint256));
            return abi.encode(_id(collection, phase, kind, nonce));
        }
        if (selector == P.priceProgramAuthorizationDigest.selector) {
            P.PriceProgramAuthorization memory authorization =
                abi.decode(data[4:], (P.PriceProgramAuthorization));
            return abi.encode(StreamNativePriceProgram.authorizationDigest(authorization));
        }
        if (selector == F.authorizationDigest.selector) {
            F.SaleAuthorization memory a = abi.decode(data[4:], (F.SaleAuthorization));
            bytes32 domain = keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("6529StreamNativeFixedPriceSaleAdapter"),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
            return abi.encode(
                keccak256(
                    abi.encodePacked(
                        hex"1901",
                        domain,
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
                                ),
                                a
                            )
                        )
                    )
                )
            );
        }
        bytes32 id = abi.decode(data[4:], (bytes32));
        if (selector == F.saleRecord.selector) return abi.encode(sales[id]);
        if (selector == P.priceProgramRecord.selector) return abi.encode(programs[id]);
        if (selector == IStreamArtistSaleFacts.saleConsentFacts.selector) {
            if (sales[id].saleNonce != 0) {
                return abi.encode(sales[id].config.collectionId, sales[id].configHash);
            }
            if (programs[id].saleNonce != 0) {
                return abi.encode(programs[id].config.collectionId, programs[id].configHash);
            }
            revert IStreamArtistSaleFacts.SaleConsentFactsUnavailable(id);
        }
        if (selector == bytes4(keccak256("nativeSaleLifecycleBinding(bytes32)"))) {
            return
                abi.encode(sales[id].saleNonce != 0 ? sales[id].lifecycle : programs[id].lifecycle);
        }
        if (selector == IStreamImmediateSaleReveal.saleRevealQuote.selector) {
            uint256 collectionId = sales[id].saleNonce != 0
                ? sales[id].config.collectionId
                : programs[id].config.collectionId;
            if (collectionId == 0) revert F.NativeSaleUnavailable(id);
            return abi.encode(StreamImmediateSaleReveal.quote(core, collectionId));
        }
        revert F.InvalidNativeSale();
    }

    function preview(
        StreamNativePriceProgram.Context memory context,
        F.SaleRecord memory sale,
        F.SaleExecutionData memory execution,
        bool paused,
        bool used,
        bytes32 previous
    ) public view returns (bytes memory) {
        (StreamNativeSettlementTypes.NativeSettlementCandidate memory c,) =
            StreamNativePriceProgram.prepareFixed(context, sale, execution, paused, used, previous);
        return abi.encode(c);
    }

    function requireConsent(
        mapping(bytes32 => F.SaleRecord) storage sales,
        mapping(bytes32 => P.PriceProgramRecord) storage programs,
        address core,
        address artists,
        bytes32 artistHash,
        bytes32 id
    ) public view {
        F.SaleRecord storage fixedRecord = sales[id];
        if (fixedRecord.saleNonce != 0) {
            StreamSaleConsent.requireConsent(
                core,
                artists,
                artistHash,
                fixedRecord.config.collectionId,
                id,
                fixedRecord.configHash
            );
        } else {
            P.PriceProgramRecord storage program = programs[id];
            if (program.saleNonce == 0) revert F.NativeSaleUnavailable(id);
            StreamSaleConsent.requireConsent(
                core, artists, artistHash, program.config.collectionId, id, program.configHash
            );
        }
    }

    function _id(uint256 collection, bytes32 phase, uint8 kind, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                kind,
                collection,
                phase,
                nonce
            )
        );
    }

    function registerFixed(
        mapping(bytes32 => F.SaleRecord) storage sales,
        StreamNativePriceProgram.Context memory context,
        address core,
        address modules,
        F.SaleConfig memory config,
        uint256 nonce
    ) public returns (bytes32 id) {
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.price == 0
                || config.endsAt <= config.startsAt || config.endsAt < block.timestamp
                || config.mintPolicyHash == 0 || config.primaryAssignmentHash == 0
                || IStreamMintReads(address(context.manager))
                        .phasePolicyHash(config.collectionId, config.phaseId)
                    != config.mintPolicyHash
        ) {
            revert F.InvalidNativeSale();
        }
        StreamImmediateSaleReveal.quote(core, config.collectionId);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(context.resolver, config.collectionId);
        if (rights.assignmentHash != config.primaryAssignmentHash) revert F.InvalidNativeSale();
        StreamNativeSettlementTypes.SaleLifecycleBinding memory binding =
            StreamNativeSettlementAdmission.capture(modules, address(this));
        id = _id(config.collectionId, config.phaseId, 0, nonce);
        bytes32 hash =
            keccak256(abi.encode(keccak256("6529STREAM_NATIVE_FIXED_PRICE_CONFIG_V1"), id, config));
        sales[id] = F.SaleRecord(config, nonce, hash, binding, false);
        emit NativeSaleConfigured(id, config.collectionId, config.phaseId, 1, nonce, hash);
    }

    function registerProgram(
        mapping(bytes32 => P.PriceProgramRecord) storage programs,
        StreamNativePriceProgram.Context memory context,
        address core,
        address modules,
        P.PriceProgramConfig memory config,
        uint256 nonce
    ) public returns (bytes32 id) {
        StreamNativePriceProgram.validateConfig(context, config);
        StreamImmediateSaleReveal.quote(core, config.collectionId);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(modules, address(this));
        id = _id(config.collectionId, config.phaseId, config.kind, nonce);
        bytes32 hash = keccak256(
            abi.encode(keccak256("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), id, config)
        );
        programs[id] = P.PriceProgramRecord(config, nonce, hash, lifecycle, 0, false);
        emit NativePriceProgramConfigured(
            id,
            1,
            nonce,
            hash,
            config,
            lifecycle.saleCreatedAt,
            lifecycle.saleAdapterRegistryRevision
        );
    }
    event NativeAllowlistPricePolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bool allowFree,
        bytes32 saleConfigHash
    );

    function registerAllowlistProgram(
        mapping(bytes32 => P.PriceProgramRecord) storage programs,
        mapping(
            bytes32 => IStreamNativeAllowlistPricePrograms.AllowlistPricePolicy
        ) storage policies,
        StreamNativePriceProgram.Context memory context,
        address core,
        address modules,
        P.PriceProgramConfig memory config,
        IStreamNativeAllowlistPricePrograms.AllowlistPricePolicy memory policy,
        uint256 nonce
    ) public returns (bytes32 id) {
        if (policy.counterId == 0 || (policy.allowFree && config.kind != 0 && config.kind != 1)) {
            revert IStreamNativeAllowlistPricePrograms.InvalidAllowlistPricePolicy();
        }
        StreamMintSaleAllowlist.validatePolicy(
            address(context.manager), config.collectionId, config.phaseId, policy.counterId
        );
        StreamNativePriceProgram.validateConfig(context, config);
        StreamImmediateSaleReveal.quote(core, config.collectionId);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(modules, address(this));
        id = _id(config.collectionId, config.phaseId, config.kind, nonce);
        bytes32 originalHash = keccak256(
            abi.encode(keccak256("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), id, config)
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ALLOWLIST_PRICE_PROGRAM_CONFIG_V1"),
                originalHash,
                policy
            )
        );
        programs[id] = P.PriceProgramRecord(config, nonce, hash, lifecycle, 0, false);
        policies[id] = policy;
        emit NativePriceProgramConfigured(
            id,
            1,
            nonce,
            hash,
            config,
            lifecycle.saleCreatedAt,
            lifecycle.saleAdapterRegistryRevision
        );
        emit NativeAllowlistPricePolicy(id, policy.counterId, 1, policy.allowFree, hash);
    }

    error InvalidSettlementContext(address target);

    /// @dev Original host immutable getters, fixed self-read only. External dependency checks
    /// retain the original Registry -> Resolver -> Factory -> Recorder -> Manager order.
    function requireContext() public view {
        StreamSettlementAdmission.requireRegistry(
            address(uint160(_contextWord("core()"))),
            bytes32(_contextWord("coreCodeHash()")),
            address(uint160(_contextWord("moduleRegistry()"))),
            bytes32(_contextWord("moduleRegistryCodeHash()"))
        );
        _requireCode("revenueResolver()", "resolverCodeHash()");
        _requireCode("splitFactory()", "factoryCodeHash()");
        _requireCode("primarySaleSettlement()", "settlementCodeHash()");
        _requireCode("mintManager()", "mintManagerCodeHash()");
    }

    function _requireCode(string memory getter, string memory hashGetter) private view {
        address target = address(uint160(_contextWord(getter)));
        if (target.codehash != bytes32(_contextWord(hashGetter))) {
            revert InvalidSettlementContext(target);
        }
    }

    function _contextWord(string memory getter) private view returns (uint256 word) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256(bytes(getter))));
        bool ok;
        uint256 size;
        address host = address(this);
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(gas(), host, add(data, 32), mload(data), p, 32)
            size := returndatasize()
            word := mload(p)
        }
        if (!ok || size != 32) revert InvalidSettlementContext(host);
    }
}
