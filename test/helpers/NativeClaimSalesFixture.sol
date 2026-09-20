// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { NativeEnglishAuctionFixture } from "./NativeEnglishAuctionFixture.sol";
import { NativeAuctionArtist } from "./NativeEnglishAuctionMocks.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamNativeClaimSales
} from "../../smart-contracts/domains/mint/StreamNativeClaimSales.sol";
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
    IStreamNativeClaimSales as C
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    ImmediateSalesArtistBoundary,
    ImmediateSalesMetadataAuthority,
    ImmediateSalesEntropyBoundary
} from "./NativeImmediateSalesFixture.sol";

/// @notice Actual current Core/Manager/Ledger/Recorder/Resolver/Registry/Floor/Metadata and upstream Safe.
/// @dev Artist and entropy are typed semantic boundaries; governance is target-side context only.
/// WAIVED is explicitly written by actual Metadata into Core, never a mocked floor bypass.
abstract contract NativeClaimSalesFixture is NativeEnglishAuctionFixture {
    bytes32 internal constant WAIVED = keccak256("CONSERVATION_WAIVED");
    uint256 internal constant PRICE = 1000;
    StreamNativeClaimSales internal claims;
    StreamConservationFloor internal claimFloor;
    StreamCollectionMetadataV1 internal claimMetadata;
    ImmediateSalesEntropyBoundary internal claimEntropy;
    ImmediateSalesMetadataAuthority private metadataAuthority;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        return new ImmediateSalesArtistBoundary(address(core), address(manager));
    }

    function setUp() public virtual override {
        super.setUp();
        _installMetadataAndFloor();
        claimEntropy = new ImmediateSalesEntropyBoundary(address(core));
        claimEntropy.configure(true, 0);
        _register(
            address(claimEntropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ENTROPY_COORDINATOR"), address(claimEntropy));
        StreamNativeClaimSales.DeploymentConfig memory d;
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
        claims = StreamNativeClaimSales(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeClaimSales.sol:StreamNativeClaimSales",
                    abi.encode(d)
                ))
        );
        claims.transferOwnership(address(revenueAuthority));
        _register(
            address(claims),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(claims), true);
        require(address(claims).code.length <= 24576, "production adapter EIP170");
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
        c.manifestURI = "urn:claims:metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        claimMetadata = StreamCollectionMetadataV1(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1",
                abi.encode(c)
            )
        );
        _register(
            address(claimMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("COLLECTION_METADATA"), address(claimMetadata));
        (bytes32 scope, bytes32 before_, bytes32 after_) = claimMetadata.familyWriterTransition(
            1, StreamRecordFamilies.CONSERVATION, 7, address(this), true
        );
        metadataAuthority.execute(
            address(claimMetadata),
            abi.encodeCall(
                claimMetadata.setFamilyWriter,
                (1, StreamRecordFamilies.CONSERVATION, 7, address(this), true)
            ),
            scope,
            before_,
            after_
        );
        claimFloor = StreamConservationFloor(
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
        (scope, before_, after_) = core.conservationFloorTransition(address(claimFloor));
        _context(scope, before_, after_, 1);
        vm.prank(address(revenueAuthority));
        core.bindConservationFloor(address(claimFloor));
        _clearContext();
        if (_declareWaiverAtSetup()) _declareWaiver();
    }

    function _declareWaiverAtSetup() internal view virtual returns (bool) {
        return true;
    }

    function _declareWaiver() internal {
        claimMetadata.declareConservationTier(1, WAIVED);
        require(core.declaredConservationTier(1) == WAIVED, "actual explicit Core waiver");
    }

    function _configuration(
        uint8 mode,
        uint8 kind,
        uint256 minimum,
        uint256 maximum,
        address signer,
        uint8 signerKind
    ) internal returns (C.Configuration memory c) {
        c.sale.collectionId = 1;
        c.sale.phaseId = PHASE;
        c.sale.saleKind = kind;
        c.sale.authorityMode = mode;
        c.sale.unitPrice = minimum;
        c.maxUnitPrice = maximum;
        c.sale.startsAt = uint64(block.timestamp);
        c.sale.endsAt = uint64(block.timestamp + 1 days);
        c.sale.saleSupplyLimit = 8;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        if (kind == 13) c.sale.expectedPrimaryPolicyHash = _primaryPolicyHash();
        if (mode == 1) {
            vm.prank(address(revenueAuthority));
            claims.configureCollectionSigner(
                1, signer, signerKind, keccak256("collection claim authority"), true
            );
            (c.sale.signer,) = claims.collectionSigner(1, signer, signerKind);
        }
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

    function _registerClaim(C.Configuration memory c) internal returns (bytes32 id) {
        vm.prank(address(revenueAuthority));
        id = claims.registerSale(c);
    }

    function _purchase(bytes32 id, address who, uint256 tag, uint256 chosen)
        internal
        view
        returns (C.Purchase memory p)
    {
        p.mint.saleId = id;
        p.mint.payer = who;
        p.mint.executor = who;
        p.mint.initialRecipient = address(0xBEEF);
        p.mint.beneficiary = address(0xCAFE);
        p.mint.tokenData = abi.encode("canonical claims artwork", tag);
        p.mint.mintCommitment = keccak256(abi.encode("mint commitment", tag));
        p.mint.executionNonce = claims.nextExecutionNonce(id, who);
        p.chosenUnitPrice = chosen;
    }

    function _authorization(C.Purchase memory p, uint256 nonce)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        IStreamNativeImmediateSales.Record memory r = claims.saleRecord(p.mint.saleId).sale;
        a.chainId = block.chainid;
        a.saleAdapter = address(claims);
        a.mintManager = address(manager);
        a.collectionId = r.config.collectionId;
        a.phaseId = r.config.phaseId;
        a.saleId = p.mint.saleId;
        a.saleKind = r.config.saleKind;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = r.config.expectedPrimaryPolicyHash;
        a.primaryPolicyMode = r.config.primaryPolicyMode;
        address[] memory recipients = new address[](1);
        recipients[0] = p.mint.initialRecipient;
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = p.mint.beneficiary;
        bytes[] memory data = new bytes[](1);
        data[0] = p.mint.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = p.mint.mintCommitment;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), recipients));
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.mint.payer;
        a.executor = p.mint.executor;
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
                address(claims)
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
