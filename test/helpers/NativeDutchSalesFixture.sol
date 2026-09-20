// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamDutchPriceSchedule
} from "../../smart-contracts/interfaces/stream/mint/IStreamDutchPriceSchedule.sol";
import { NativeEnglishAuctionFixture } from "./NativeEnglishAuctionFixture.sol";
import { NativeAuctionArtist, NativeAuctionEntropy } from "./NativeEnglishAuctionMocks.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamNativeDutchSales
} from "../../smart-contracts/domains/mint/StreamNativeDutchSales.sol";
import {
    StreamCollectionMetadataV1
} from "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    StreamSchemaRegistry
} from "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamConservationFloor
} from "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamCollectionMetadataV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamEntropyCollectionPolicy
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyCoordinator
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    IStreamRevealFeeEscrow
} from "../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import {
    IStreamNativeImmediateSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamPrivateSaleTypes
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import {
    IStreamRevenueResolver
} from "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    GovernanceAction,
    GovernanceActionStatus
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    IStreamArtistBeneficiaryFacts
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

import {
    IStreamNativeDutchSales as D
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import {
    ImmediateSalesArtistBoundary,
    ImmediateSalesMetadataAuthority,
    ImmediateSalesEntropyBoundary
} from "./NativeImmediateSalesFixture.sol";

/// @notice Actual current Core/Manager/Ledger/Recorder/Resolver/Registry/Floor/Metadata and upstream Safe.
/// @dev Artist and entropy are typed semantic boundaries; governance is target-side context only.
/// WAIVED is explicitly written by actual Metadata into Core, never a mocked floor bypass.
abstract contract NativeDutchSalesFixture is NativeEnglishAuctionFixture {
    bytes32 internal constant WAIVED = keccak256("CONSERVATION_WAIVED");
    uint256 internal constant PRICE = 1000;
    StreamNativeDutchSales internal dutch;
    StreamConservationFloor internal dutchFloor;
    StreamCollectionMetadataV1 internal dutchMetadata;
    ImmediateSalesEntropyBoundary internal dutchEntropy;
    ImmediateSalesMetadataAuthority private metadataAuthority;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        return new ImmediateSalesArtistBoundary(address(core), address(manager));
    }

    function _deployAuctionEntropy() internal override returns (NativeAuctionEntropy) {
        dutchEntropy = new ImmediateSalesEntropyBoundary(address(core));
        dutchEntropy.configure(true, 0);
        return NativeAuctionEntropy(address(dutchEntropy));
    }

    function setUp() public virtual override {
        super.setUp();
        _installMetadataAndFloor();
        StreamNativeDutchSales.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = recorder;
        d.artists = artists;
        d.roles = auctionRoles;
        d.authority = address(revenueAuthority);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 500000, 100000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 2000000, 50000, 2
        );
        dutch = StreamNativeDutchSales(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeDutchSales.sol:StreamNativeDutchSales",
                    abi.encode(d)
                ))
        );
        dutch.transferOwnership(address(revenueAuthority));
        _register(
            address(dutch),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(dutch), true);
        require(address(dutch).code.length <= 24576, "production adapter EIP170");
    }

    function _installMetadataAndFloor() private {
        metadataAuthority = new ImmediateSalesMetadataAuthority(address(this));
        StreamSchemaRegistry schemas = new StreamSchemaRegistry(address(metadataAuthority));
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(metadataAuthority);
        c.schemas = address(schemas);
        c.artistRegistry = address(artists);
        c.deploymentManifestHash = MANIFEST;
        c.manifestHash = MANIFEST;
        c.manifestURI = "https://example.invalid/canonical-dutch-metadata.json";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        dutchMetadata = StreamCollectionMetadataV1(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1",
                abi.encode(c)
            )
        );
        _register(
            address(dutchMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("COLLECTION_METADATA"), address(dutchMetadata));
        (bytes32 scope, bytes32 before_, bytes32 after_) = dutchMetadata.familyWriterTransition(
            1, StreamRecordFamilies.CONSERVATION, 7, address(this), true
        );
        metadataAuthority.execute(
            address(dutchMetadata),
            abi.encodeCall(
                dutchMetadata.setFamilyWriter,
                (1, StreamRecordFamilies.CONSERVATION, 7, address(this), true)
            ),
            scope,
            before_,
            after_
        );
        dutchFloor = StreamConservationFloor(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamConservationFloor.sol:StreamConservationFloor",
                abi.encode(
                    address(core),
                    address(revenueAuthority),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_CALL_GAS", 2000000, 2000000, 2
                    )
                )
            )
        );
        (scope, before_, after_) = core.conservationFloorTransition(address(dutchFloor));
        _context(scope, before_, after_, 1);
        vm.prank(address(revenueAuthority));
        core.bindConservationFloor(address(dutchFloor));
        _clearContext();
        if (_declareWaiverAtSetup()) _declareWaiver();
    }

    function _declareWaiverAtSetup() internal view virtual returns (bool) {
        return true;
    }

    function _declareWaiver() internal {
        dutchMetadata.declareConservationTier(1, WAIVED);
        require(core.declaredConservationTier(1) == WAIVED, "actual explicit Core waiver");
    }

    function _configuration(uint8 mode, bool declaredFree, address signer, uint8 signerKind)
        internal
        returns (D.Configuration memory c)
    {
        c.sale.collectionId = 1;
        c.sale.phaseId = PHASE;
        c.sale.saleKind = 3;
        c.sale.authorityMode = mode;
        c.sale.unitPrice = PRICE;
        c.sale.startsAt = uint64(block.timestamp + 10);
        c.sale.endsAt = uint64(block.timestamp + 1 days);
        c.sale.saleSupplyLimit = 8;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        c.sale.expectedPrimaryPolicyHash = _primaryPolicyHash();
        c.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(
            uint96(PRICE), declaredFree ? 0 : 100, c.sale.startsAt, c.sale.startsAt + 100, 0, 0, 0
        );
        c.declaredFree = declaredFree;
        if (mode == 1) {
            vm.prank(address(revenueAuthority));
            dutch.configureCollectionSigner(
                1, signer, signerKind, keccak256("collection Dutch authority"), true
            );
            (c.sale.signer,) = dutch.collectionSigner(1, signer, signerKind);
        }
    }

    function _start(bytes32 id) internal {
        vm.warp(dutch.saleRecord(id).schedule.startTime);
    }

    function _primaryPolicyHash() internal view returns (bytes32) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        bytes32 selectedProfile = a.profileId;
        address selectedWallet;
        if (a.templateId != 0) {
            (selectedProfile, selectedWallet,) =
                resolver.previewCollectionPrimaryProfile(a.templateId, 1, address(0));
        } else {
            selectedWallet = factory.walletFor(selectedProfile);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                uint256(0),
                a.templateId,
                selectedProfile,
                selectedWallet,
                a.assignmentHash
            )
        );
    }

    function _registerDutch(D.Configuration memory c) internal returns (bytes32 id) {
        vm.prank(address(revenueAuthority));
        id = dutch.registerSale(c);
    }

    function _purchase(bytes32 id, address who, uint256 tag)
        internal
        view
        returns (IStreamNativeImmediateSales.Purchase memory p)
    {
        p.saleId = id;
        p.payer = who;
        p.executor = who;
        p.initialRecipient = address(0xBEEF);
        p.beneficiary = address(0xCAFE);
        p.tokenData = abi.encode("canonical dutch artwork", tag);
        p.mintCommitment = keccak256(abi.encode("mint commitment", tag));
        p.executionNonce = dutch.nextExecutionNonce(id, who);
    }

    function _authorization(IStreamNativeImmediateSales.Purchase memory p, uint256 nonce)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        IStreamNativeImmediateSales.Record memory r = dutch.saleRecord(p.saleId).sale;
        a.chainId = block.chainid;
        a.saleAdapter = address(dutch);
        a.mintManager = address(manager);
        a.collectionId = r.config.collectionId;
        a.phaseId = r.config.phaseId;
        a.saleId = p.saleId;
        a.saleKind = r.config.saleKind;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = r.config.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = r.config.primaryPolicyMode;
        address[] memory recipients = new address[](1);
        recipients[0] = p.initialRecipient;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = p.beneficiary;
        bytes[] memory data = new bytes[](1);
        data[0] = p.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = p.mintCommitment;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.payer;
        a.executor = p.executor;
        a.unitPrice = r.config.unitPrice;
        a.quantity = 1;
        a.policyHash = r.config.mintPolicyHash;
        a.nonce = bytes32(nonce);
        a.deadline = uint64(block.timestamp + 1 hours);
    }

    function _literalDigest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(dutch)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _sign(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        returns (IStreamPrivateSaleAdapter.Signature memory s)
    {
        (uint8 v, bytes32 r, bytes32 sigS) = vm.sign(SIGNER_KEY, _literalDigest(a));
        s = IStreamPrivateSaleAdapter.Signature(
            vm.addr(SIGNER_KEY), 1, abi.encodePacked(r, sigS, v)
        );
    }

    function _safe(uint256 salt) internal returns (OfficialSafe account, uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = 0x6529501;
        keys[1] = 0x6529502;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, salt);
        vm.deal(address(account), 1 ether);
    }
}
