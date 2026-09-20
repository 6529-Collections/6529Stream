// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { NativeEnglishAuctionFixture } from "./NativeEnglishAuctionFixture.sol";
import { NativeAuctionArtist } from "./NativeEnglishAuctionMocks.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamNativeImmediateSales
} from "../../smart-contracts/domains/mint/StreamNativeImmediateSales.sol";
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

contract ImmediateSalesArtistBoundary is NativeAuctionArtist, IStreamArtistBeneficiaryFacts {
    uint8 private contest;
    bool private failedContestRead;
    constructor(address c, address m) NativeAuctionArtist(c, m) { }

    function supportsInterface(bytes4 id) public pure override returns (bool) {
        return id == type(IStreamArtistBeneficiaryFacts).interfaceId || super.supportsInterface(id);
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(artist != address(0));
        return (keccak256("native auction artist"), artist, keccak256("typed payout designation"));
    }

    function setContest(uint8 value, bool failRead) external {
        contest = value;
        failedContestRead = failRead;
    }

    function platformWorksContest(uint256) external view returns (uint8, bytes32) {
        require(!failedContestRead, "typed contest unavailable");
        return (contest, contest == 0 ? bytes32(0) : keccak256("typed contest record"));
    }
}

/// @dev Explicit executing-governance boundary for actual Metadata grants, not a delayed Executor.
contract ImmediateSalesMetadataAuthority {
    address public immutable root;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    bool private executing;
    uint256 private nonce;

    constructor(address root_) {
        root = root_;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, root.codehash, 1);
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = 1;
        a.proposer = root;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (executing, bytes32(nonce), 1, scope, oldHash, newHash);
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n) external {
        require(msg.sender == root);
        executing = true;
        ++nonce;
        scope = s;
        oldHash = o;
        newHash = n;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        executing = false;
    }
}

/// @dev Typed entropy policy/delivery boundary only. No actual Coordinator/provider proof is claimed.
contract ImmediateSalesEntropyBoundary {
    address public immutable core;
    bool public disabled;
    uint256 public fee;
    uint256 public mintCalls;
    uint256 public requestCalls;
    mapping(uint256 => uint256) public revealFeeEscrow;
    mapping(uint256 => bool) private registered;

    constructor(address c) {
        core = c;
    }

    function configure(bool noEntropy, uint256 value) external {
        disabled = noEntropy;
        fee = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamEntropyCoordinator).interfaceId
            || id == type(IStreamRevealFeeEscrow).interfaceId
            || id == type(IStreamEntropyCollectionPolicy).interfaceId;
    }

    function collectionEntropyPolicy(uint256)
        external
        view
        returns (IStreamEntropyCollectionPolicy.PolicyRecord memory p)
    {
        if (!disabled) {
            p.mode = IStreamEntropyCollectionPolicy.Mode.ASYNC;
            return p;
        }
        p.configured = true;
        p.explicitPolicy = true;
        p.frozen = true;
        p.mode = IStreamEntropyCollectionPolicy.Mode.DISABLED;
        p.renderRequirement = IStreamEntropyCollectionPolicy.RenderRequirement.NOT_REQUIRED;
        p.revision = 1;
        p.policyHash = keccak256("typed disabled policy");
        p.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, true)
        );
        p.lastActionId = keccak256("typed entropy action");
        p.artistConsentRecord = keccak256("typed entropy Artist consent");
    }

    function collectionRevealPolicy(uint256)
        external
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory p)
    {
        if (!disabled) {
            p = IStreamRevealFeeEscrow.CollectionRevealPolicy(
                true, 1, keccak256("ROLE_ENTROPY_REQUESTER"), 20, fee
            );
        }
    }

    function onTokenMinted(uint256 token, uint256, address, bytes32) external {
        require(msg.sender == core);
        registered[token] = true;
        ++mintCalls;
    }

    function tokenEntropy(uint256 token)
        external
        view
        returns (uint8, bytes32, address, uint32, bytes32, uint64, uint64, uint64)
    {
        return (registered[token] && disabled ? 1 : 0, 0, address(0), 0, 0, 0, 0, 0);
    }

    function tokenEntropyStatus(uint256 token) external view returns (uint8) {
        return registered[token] && disabled ? 1 : 0;
    }

    function tokenSeed(uint256) external pure returns (bool, bytes32) {
        return (false, 0);
    }

    function fundRevealFeeEscrow(uint256 cid) external payable {
        revealFeeEscrow[cid] += msg.value;
    }

    function requestEntropy(uint256 token) external returns (bytes32, uint256) {
        ++requestCalls;
        return (keccak256(abi.encode(token)), requestCalls);
    }
}

/// @notice Actual current Core/Manager/Ledger/Recorder/Resolver/Registry/Floor/Metadata and upstream Safe.
/// @dev Artist and entropy are typed semantic boundaries; governance is target-side context only.
/// WAIVED is explicitly written by actual Metadata into Core, never a mocked floor bypass.
abstract contract NativeImmediateSalesFixture is NativeEnglishAuctionFixture {
    bytes32 internal constant WAIVED = keccak256("CONSERVATION_WAIVED");
    uint256 internal constant PRICE = 1000;
    StreamNativeImmediateSales internal immediate;
    StreamConservationFloor internal immediateFloor;
    StreamCollectionMetadataV1 internal immediateMetadata;
    ImmediateSalesEntropyBoundary internal immediateEntropy;
    ImmediateSalesMetadataAuthority private metadataAuthority;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        return new ImmediateSalesArtistBoundary(address(core), address(manager));
    }

    function setUp() public virtual override {
        super.setUp();
        _installMetadataAndFloor();
        immediateEntropy = new ImmediateSalesEntropyBoundary(address(core));
        _register(
            address(immediateEntropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ENTROPY_COORDINATOR"), address(immediateEntropy));
        StreamNativeImmediateSales.DeploymentConfig memory d;
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
        immediate = StreamNativeImmediateSales(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamNativeImmediateSales.sol:StreamNativeImmediateSales",
                    abi.encode(d)
                ))
        );
        immediate.transferOwnership(address(revenueAuthority));
        _register(
            address(immediate),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        manager.setPhaseExecutor(1, PHASE, address(immediate), true);
        require(address(immediate).code.length <= 24576, "production adapter EIP170");
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
        c.manifestURI = "https://example.org/immediate";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        immediateMetadata = StreamCollectionMetadataV1(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol:StreamCollectionMetadataV1",
                abi.encode(c)
            )
        );
        _register(
            address(immediateMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("COLLECTION_METADATA"), address(immediateMetadata));
        (bytes32 scope, bytes32 before_, bytes32 after_) = immediateMetadata.familyWriterTransition(
            1, StreamRecordFamilies.CONSERVATION, 7, address(this), true
        );
        metadataAuthority.execute(
            address(immediateMetadata),
            abi.encodeCall(
                immediateMetadata.setFamilyWriter,
                (1, StreamRecordFamilies.CONSERVATION, 7, address(this), true)
            ),
            scope,
            before_,
            after_
        );
        immediateFloor = StreamConservationFloor(
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
        (scope, before_, after_) = core.conservationFloorTransition(address(immediateFloor));
        _context(scope, before_, after_, 1);
        vm.prank(address(revenueAuthority));
        core.bindConservationFloor(address(immediateFloor));
        _clearContext();
        if (_declareWaiverAtSetup()) _declareWaiver();
    }

    function _declareWaiverAtSetup() internal view virtual returns (bool) {
        return true;
    }

    function _declareWaiver() internal {
        immediateMetadata.declareConservationTier(1, WAIVED);
        require(core.declaredConservationTier(1) == WAIVED, "actual explicit Core waiver");
    }

    function _configuration(uint8 mode, uint8 kind, address signer, uint8 signerKind)
        internal
        returns (IStreamNativeImmediateSales.Configuration memory c)
    {
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.saleKind = kind;
        c.authorityMode = mode;
        c.unitPrice = PRICE;
        c.startsAt = uint64(block.timestamp);
        c.endsAt = uint64(block.timestamp + 1 days);
        c.saleSupplyLimit = kind == 0 ? 8 : 0;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
        c.expectedPrimaryPolicyHash = _primaryPolicyHash();
        if (mode == 1) {
            vm.prank(address(revenueAuthority));
            immediate.configureCollectionSigner(
                1, signer, signerKind, keccak256("collection singleton authority"), true
            );
            (c.signer,) = immediate.collectionSigner(1, signer, signerKind);
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

    function _registerImmediate(IStreamNativeImmediateSales.Configuration memory c)
        internal
        returns (bytes32 id)
    {
        vm.prank(address(revenueAuthority));
        id = immediate.registerSale(c);
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
        p.tokenData = abi.encode("canonical immediate artwork", tag);
        p.mintCommitment = keccak256(abi.encode("mint commitment", tag));
        p.executionNonce = immediate.nextExecutionNonce(id, who);
    }

    function _authorization(IStreamNativeImmediateSales.Purchase memory p, uint256 nonce)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        IStreamNativeImmediateSales.Record memory r = immediate.saleRecord(p.saleId);
        a.chainId = block.chainid;
        a.saleAdapter = address(immediate);
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
                address(immediate)
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
