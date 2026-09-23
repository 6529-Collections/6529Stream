// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDocumentaryArtistFixture.sol";
import "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";
import "../../smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamDirectPrimarySaleReceipt.sol";
import {
    StreamDirectPrimarySaleTypes as DocumentaryDirect
} from "../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";
import {
    StreamConservationFloorTypes as DocumentaryFloor
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";

interface DocumentaryCallVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Documentary sale model using the actual current graph and original native buy API.
/// @dev Explicit documentary fixture reservations: SOURCE1m / PRODUCER4m / CALL6m. Native
/// execution must prove workload fit; these are not defaults, 500k acceptance or public archival.
abstract contract CurrentDocumentaryConservationFixture is CurrentDocumentaryArtistFixture {
    bytes32 internal constant DOCUMENTARY_TIER = keccak256("MUSEUM_GRADE_LITE");
    uint256 internal constant DOCUMENTARY_PRICE = 0.01 ether;
    uint256 internal constant DOCUMENTARY_FUNDS = 100 ether;
    uint256 internal constant DOCUMENTARY_READ_GAS = 300_000;
    uint256 internal constant DOCUMENTARY_PRODUCER_GAS = 4_000_000;
    uint256 internal constant DOCUMENTARY_CALL_GAS = 6_000_000;
    uint256 internal constant DOCUMENTARY_TRANSACTION_GAS = 16_777_216;
    StreamConservationFloor internal documentaryFloor;
    StreamNativeConservationFloorProvider internal documentaryProvider;
    OfficialSafe internal documentaryBuyerSafe;
    uint256[] internal documentaryBuyerKeys;
    uint256 internal documentaryEOADebit;
    uint256 internal documentarySafeDebit;
    uint256 internal documentaryBurned;
    uint256 internal documentaryNextNonce;
    uint256 internal documentaryNextMedia = 1;
    bytes32 internal documentaryFirstHash;
    bytes32 internal documentaryFirstTuple;
    bytes32[] internal documentaryPurchases;
    mapping(bytes32 => bytes32) internal documentaryHistory;
    mapping(bytes32 => bytes32) internal documentaryPurchaseNonce;
    mapping(bytes32 => bytes32) internal documentaryReleaseHistory;
    mapping(uint256 => address) internal documentaryOwners;
    bytes32[] internal documentarySourceRows;
    bytes32[] internal documentarySourceHeads;

    struct DocumentaryBuy {
        IStreamFixedPriceSaleAdapter.SaleAuthorization authorization;
        bytes data;
        bytes32 id;
        DocumentaryDirect.Receipt expected;
    }

    event DocumentaryGas(bytes32 indexed operation, uint256 executionGas, uint256 configuredLimit);

    function _setUpDocumentaryConservation() internal {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installDocumentaryGovernor();
        _documentaryBaseDocuments();
        _deployDocumentaryMedia();
        _publishDocumentaryArtist();
        _publishDocumentaryMedia(documentaryNextMedia, true);
        _deployDocumentaryFloor();
        _registerDocumentarySale();
        _declareDocumentaryTier();
        _appendDocumentarySource();
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xD0CB01;
        owners[1] = 0xD0CB02;
        owners[2] = 0xD0CB03;
        documentaryBuyerKeys.push(owners[0]);
        documentaryBuyerKeys.push(owners[1]);
        documentaryBuyerSafe = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 0xD0CB
        );
        vm.deal(BUYER, DOCUMENTARY_FUNDS);
        vm.deal(address(documentaryBuyerSafe), DOCUMENTARY_FUNDS);
        _assertDocumentaryHistory();
    }

    function _fixtureSupplyLimit() internal pure virtual override returns (uint64) {
        return 512;
    }

    function _deployDocumentaryFloor() private {
        documentaryFloor = StreamConservationFloor(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamConservationFloor.sol:StreamConservationFloor",
                abi.encode(
                    address(core),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_READ_GAS", DOCUMENTARY_READ_GAS, DOCUMENTARY_READ_GAS, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_PRODUCER_GAS",
                        DOCUMENTARY_PRODUCER_GAS,
                        DOCUMENTARY_PRODUCER_GAS,
                        2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "CONSERVATION_FLOOR_CALL_GAS", DOCUMENTARY_CALL_GAS, DOCUMENTARY_CALL_GAS, 2
                    )
                )
            )
        );
        _assertDeployableProductionInstance(address(documentaryFloor));
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] =
            _documentaryPolicy(address(documentaryFloor), documentaryFloor.appendSource.selector);
        _documentaryAddPolicies(rows);
        (bytes32 scope, bytes32 previous, bytes32 next) =
            core.conservationFloorTransition(address(documentaryFloor));
        _documentaryGovern(
            address(core),
            abi.encodeCall(core.bindConservationFloor, (address(documentaryFloor))),
            scope,
            previous,
            next
        );
        (address selected, bytes32 pin) = core.conservationFloor();
        require(
            selected == address(documentaryFloor) && pin == selected.codehash,
            "actual permanent documentary floor"
        );
    }

    function _registerDocumentarySale() private {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = StreamModuleRegistration(
            address(sale),
            DocumentaryDirect.MODULE_TYPE,
            DocumentaryDirect.MODULE_VERSION,
            type(IStreamDirectPrimarySaleReceipt).interfaceId,
            500_000,
            address(sale).codehash,
            DEPLOYMENT_HASH,
            keccak256("actual documentary DIRECT fixture"),
            "urn:fixture:documentary-direct"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, rows);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        vm.warp(ready);
        _documentarySafeCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            registry.isModuleEligible(
                address(sale),
                DocumentaryDirect.MODULE_TYPE,
                type(IStreamDirectPrimarySaleReceipt).interfaceId
            ),
            "actual original DIRECT admission"
        );
    }

    function _declareDocumentaryTier() private {
        _documentaryGrantWriter(StreamRecordFamilies.CONSERVATION, address(governorSafe));
        _documentarySafeCall(
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.declareConservationTier, (1, DOCUMENTARY_TIER))
        );
        (bytes32 declared, bytes32 effective) = assemblyMetadata.conservationTier(1);
        require(
            declared == DOCUMENTARY_TIER && effective == DOCUMENTARY_TIER
                && core.declaredConservationTier(1) == DOCUMENTARY_TIER
                && core.collectionMintedEver(1) == 0,
            "original non-WAIVED tier precedes paid mint"
        );
    }

    function _appendDocumentarySource() internal {
        StreamNativeConservationFloorProvider.Configuration memory c;
        c.targets = [
            address(core),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRights),
            address(assemblyConservation),
            address(documentaryMasters),
            address(router),
            address(artists),
            address(0)
        ];
        for (uint256 i; i < 9; ++i) {
            c.codeHashes[i] = c.targets[i].codehash;
        }
        c.executor = address(executor);
        c.readGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_READ_GAS", 300_000, 100_000, 2
        );
        c.sourceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_SOURCE_GAS", 1_000_000, 1_000_000, 2
        );
        c.referenceGas = IStreamGasParameterHost.GasParameterConfig(
            "CONSERVATION_PROVIDER_REFERENCE_GAS", 16_000_000, 1_000_000, 2
        );
        documentaryProvider = StreamNativeConservationFloorProvider(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol:StreamNativeConservationFloorProvider",
                abi.encode(c)
            )
        );
        _assertDeployableProductionInstance(address(documentaryProvider));
        require(
            documentaryProvider.configurationHash()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CONSERVATION_PROVIDER_V1"), block.chainid, c
                    )
                ),
            "exact original provider configuration"
        );
        (uint64 beforeCount, bytes32 beforeHead) = documentaryFloor.sourceSetHead();
        (bytes32 scope, bytes32 previous, bytes32 next) = documentaryFloor.sourceTransition(
            address(assemblyMetadata), address(documentaryProvider), beforeCount
        );
        _documentaryGovern(
            address(documentaryFloor),
            abi.encodeCall(
                documentaryFloor.appendSource,
                (address(assemblyMetadata), address(documentaryProvider), beforeCount)
            ),
            scope,
            previous,
            next
        );
        DocumentaryFloor.Source memory row = documentaryFloor.sourceAt(beforeCount + 1);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                beforeHead,
                beforeCount + 1,
                address(assemblyMetadata),
                address(assemblyMetadata).codehash,
                address(documentaryProvider),
                address(documentaryProvider).codehash,
                documentaryProvider.configurationHash(),
                beforeCount
            )
        );
        (uint64 count, bytes32 head) = documentaryFloor.sourceSetHead();
        require(
            count == beforeCount + 1 && head == expected && row.predecessor == beforeCount
                && row.metadata == address(assemblyMetadata)
                && row.provider == address(documentaryProvider)
                && row.metadataCodeHash == address(assemblyMetadata).codehash
                && row.providerCodeHash == address(documentaryProvider).codehash
                && row.admittedAt == block.timestamp
                && row.configurationHash == documentaryProvider.configurationHash()
                && executor.governanceAction(row.actionId).status
                    == GovernanceActionStatus.EXECUTED,
            "original appended documentary source and independently derived head"
        );
        documentarySourceRows.push(keccak256(abi.encode(row)));
        documentarySourceHeads.push(expected);
    }

    function _prepareDocumentaryBuy(bool safePayer) internal returns (DocumentaryBuy memory b) {
        address payer = safePayer ? address(documentaryBuyerSafe) : BUYER;
        bytes32 nonce = keccak256(abi.encode("documentary signed nonce", ++documentaryNextNonce));
        b.authorization = IStreamFixedPriceSaleAdapter.SaleAuthorization(
            1,
            PHASE,
            payer,
            payer,
            artist,
            profile,
            _nativePrimaryPolicyHash(),
            keccak256(TOKEN_DATA),
            keccak256(abi.encode("documentary original mint", nonce)),
            manager.phasePolicyHash(1, PHASE),
            DOCUMENTARY_PRICE,
            nonce,
            type(uint64).max,
            sale.signerEpoch()
        );
        bytes32 digest = sale.authorizationDigest(b.authorization);
        b.id = sale.authorizationId(artist, nonce);
        b.data = abi.encodeCall(
            sale.buy,
            (
                b.authorization,
                TOKEN_DATA,
                _documentarySign(PLATFORM_KEY, digest),
                _documentarySign(ARTIST_KEY, digest)
            )
        );
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = PHASE;
        batch.payer = payer;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = payer;
        batch.beneficiaries[0] = payer;
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments[0] = b.authorization.mintCommitment;
        batch.expectedPolicyHash = b.authorization.mintPolicyHash;
        batch.authorizationId = b.id;
        batch.contextHash = digest;
        vm.prank(address(sale));
        (bytes32 root, bytes32[] memory ids) = manager.previewSingleStepMintOperation(batch, "");
        bytes32 operationId = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TOKEN_OPERATION_ID_V1"),
                root,
                core.collectionMintedEver(1),
                uint256(0),
                keccak256(TOKEN_DATA),
                b.authorization.mintCommitment
            )
        );
        require(
            ids.length == 1 && ids[0] == operationId, "independent current token operation identity"
        );
        b.expected = DocumentaryDirect.Receipt(
            digest,
            1,
            core.lastAllocatedTokenId() + 1,
            root,
            operationId,
            b.authorization.mintPolicyHash,
            b.authorization.expectedPrimaryPolicyHash,
            profile,
            wallet,
            uint64(block.timestamp),
            false,
            payer,
            registry.moduleRecord(address(sale)).revision,
            payer,
            address(0),
            DOCUMENTARY_PRICE
        );
    }

    function _documentarySign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _documentaryContext()
        internal
        view
        returns (DocumentaryFloor.ReleaseContext memory r)
    {
        r.scopeSubject = documentaryMediaSubject;
        r.mediaInventoryHash = documentaryMediaInventoryHash;
        r.membershipHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                r.scopeSubject,
                r.mediaInventoryHash,
                bytes32(0)
            )
        );
        IStreamMetadataServingFacts.ServingFacts memory serving = router.collectionServingFacts(1);
        require(
            serving.mode == keccak256("OFFCHAIN") && serving.scriptBytes == 0
                && serving.scriptHash == keccak256(bytes("")),
            "original stable OFFCHAIN serving convention"
        );
        r.sourceContextHash = keccak256(
            abi.encode(
                documentaryProvider.configurationHash(),
                documentaryMediaManifestHash,
                bytes32(0),
                uint8(1),
                serving,
                r.membershipHash
            )
        );
    }

    function _documentaryReleaseKey(DocumentaryFloor.ReleaseContext memory r)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_RELEASE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                r.scopeSubject,
                r.membershipHash,
                r.mediaInventoryHash,
                r.scriptSourceHash,
                r.scriptWork
            )
        );
    }

    function _documentaryDirectKey(bytes32 id) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"),
                block.chainid,
                address(core),
                address(sale),
                DocumentaryDirect.NATIVE_FIXED_PRICE,
                id
            )
        );
    }

    function _executeDocumentaryBuy(DocumentaryBuy memory b) internal {
        DocumentaryFloor.ReleaseContext memory context = _documentaryContext();
        bytes32 releaseKey = _documentaryReleaseKey(context);
        bool first = documentaryPurchases.length == 0;
        bool newRelease = documentaryReleaseHistory[releaseKey] == 0;
        DocumentaryFloor.CollectionFacts memory expectedFacts;
        if (first) expectedFacts = _expectedDocumentaryCollectionFacts();
        b.expected.createdAt = uint64(block.timestamp);
        uint256 beforeSafe = documentaryBuyerSafe.nonce();
        uint256 beforeGas = gasleft();
        if (b.authorization.payer == address(documentaryBuyerSafe)) {
            require(
                _boundedDocumentarySafeBuy(b.data, false),
                "literal threshold Safe documentary payment"
            );
            documentarySafeDebit += DOCUMENTARY_PRICE;
            require(documentaryBuyerSafe.nonce() == beforeSafe + 1, "one successful Safe nonce");
        } else {
            uint256 cap = _documentaryCallGas(b.data, DOCUMENTARY_PRICE);
            vm.prank(BUYER);
            (bool ok, bytes memory returned) =
                address(sale).call{ value: DOCUMENTARY_PRICE, gas: cap }(b.data);
            if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
            (uint256 token, bytes32 root) = abi.decode(returned, (uint256, bytes32));
            require(
                token == b.expected.tokenId && root == b.expected.operationRoot,
                "exact original buy return"
            );
            documentaryEOADebit += DOCUMENTARY_PRICE;
            require(documentaryBuyerSafe.nonce() == beforeSafe, "EOA payment cannot use Safe nonce");
        }
        emit DocumentaryGas(
            keccak256("ORIGINAL_NATIVE_DOCUMENTARY_BUY"),
            beforeGas - gasleft(),
            DOCUMENTARY_TRANSACTION_GAS
        );
        IStreamDirectPrimarySaleReceipt product = IStreamDirectPrimarySaleReceipt(address(sale));
        DocumentaryDirect.Receipt memory original = product.directPrimarySaleReceipt(b.id);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(b.expected)),
            "all original paid receipt words"
        );
        bytes32 paidHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"),
                block.chainid,
                address(core),
                address(sale),
                DocumentaryDirect.NATIVE_FIXED_PRICE,
                b.id,
                b.expected
            )
        );
        require(
            product.directPrimarySaleReceiptHash(b.id) == paidHash, "independent original paid hash"
        );
        bytes32 directKey = _documentaryDirectKey(b.id);
        DocumentaryFloor.FirstSaleReceipt memory initial = documentaryFloor.firstSale(1);
        DocumentaryFloor.ReleaseFloorReceipt memory release =
            documentaryFloor.releaseFloorReceipt(releaseKey);
        (uint64 sourceId, bytes32 sourceHead) = documentaryFloor.sourceSetHead();
        if (first) {
            require(
                initial.collectionId == 1 && initial.effectiveTier == DOCUMENTARY_TIER
                    && initial.recorder == address(sale) && initial.settlementKey == directKey
                    && initial.recordedAt == block.timestamp && initial.sourceId == sourceId
                    && initial.sourceSetHash == sourceHead
                    && keccak256(abi.encode(initial.facts)) == keccak256(abi.encode(expectedFacts)),
                "exact original first documentary facts"
            );
            bytes32 hash = initial.receiptHash;
            initial.receiptHash = 0;
            require(
                hash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONSERVATION_FIRST_SALE_V1"),
                            block.chainid,
                            address(core),
                            address(documentaryFloor),
                            initial
                        )
                    ),
                "independent first documentary receipt hash"
            );
            initial.receiptHash = hash;
            documentaryFirstHash = hash;
            documentaryFirstTuple = keccak256(abi.encode(initial));
        }
        if (newRelease) {
            require(
                release.receiptHash != 0 && release.releaseKey == releaseKey
                    && release.collectionId == 1 && release.effectiveTier == DOCUMENTARY_TIER
                    && release.recorder == address(sale) && release.settlementKey == directKey
                    && release.recordedAt == block.timestamp && release.sourceId == sourceId
                    && release.sourceSetHash == sourceHead
                    && keccak256(abi.encode(release.context)) == keccak256(abi.encode(context))
                    && release.facts.sourceContextHash == context.sourceContextHash
                    && release.facts.mediaEvidenceHash == documentaryMediaEvidenceHash
                    && release.facts.referenceEvidenceHash == 0,
                "exact occupied OFFCHAIN master release"
            );
            bytes32 hash = release.receiptHash;
            release.receiptHash = 0;
            require(
                hash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1"),
                            block.chainid,
                            address(core),
                            address(documentaryFloor),
                            release
                        )
                    ),
                "independent release receipt hash"
            );
            release.receiptHash = hash;
            documentaryReleaseHistory[releaseKey] = keccak256(abi.encode(release));
        }
        StreamDirectPrimaryConservationTypes.Receipt memory expected;
        expected.adapter = address(sale);
        expected.adapterCodeHash = address(sale).codehash;
        expected.directKey = directKey;
        expected.authorizationId = b.id;
        expected.originalReceiptHash = paidHash;
        expected.bindings = DocumentaryDirect.Bindings(
            address(core),
            address(core).codehash,
            address(manager),
            address(manager).codehash,
            block.chainid,
            DocumentaryDirect.NATIVE_FIXED_PRICE
        );
        expected.sale = b.expected;
        expected.effectiveTier = DOCUMENTARY_TIER;
        expected.firstSaleReceiptHash = documentaryFirstHash;
        expected.releaseReceiptHash = release.receiptHash;
        expected.recordedAt = uint64(block.timestamp);
        expected.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                block.chainid,
                address(core),
                address(documentaryFloor),
                expected
            )
        );
        require(
            keccak256(abi.encode(documentaryFloor.directPrimarySaleFloorReceipt(directKey)))
                == keccak256(abi.encode(expected)),
            "complete independent documentary DIRECT floor tuple"
        );
        documentaryPurchases.push(b.id);
        documentaryPurchaseRelease[b.id] = releaseKey;
        documentaryPurchaseNonce[b.id] = b.authorization.nonce;
        documentaryHistory[b.id] = _documentaryHistoryHash(b.id, releaseKey);
        documentaryOwners[b.expected.tokenId] = b.authorization.recipient;
        _assertDocumentaryHistory();
    }

    function _expectDocumentaryBuyFailure(DocumentaryBuy memory b) internal {
        _expectDocumentaryFailure(b, true);
    }

    function _expectDocumentaryEarlyBuyFailure(DocumentaryBuy memory b) internal {
        _expectDocumentaryFailure(b, false);
    }

    function _expectDocumentaryFailure(DocumentaryBuy memory b, bool late) private {
        bytes32 before = _documentaryMutableStateHash();
        uint256 beforeSafe = documentaryBuyerSafe.nonce();
        if (b.authorization.payer == address(documentaryBuyerSafe)) {
            require(
                !_boundedDocumentarySafeBuy(b.data, true),
                "real Safe reports rejected documentary buy"
            );
            require(
                documentaryBuyerSafe.nonce() == beforeSafe + 1,
                "only failed outer Safe nonce persists"
            );
        } else {
            bytes memory expectedReason = late
                ? abi.encodeWithSignature(
                    "DirectSaleFloorCallFailed(address,bytes4)",
                    address(documentaryFloor),
                    IStreamConservationFloor.ConservationFloorRead.selector
                )
                : abi.encodeWithSignature(
                    "ArtistAuthorityReadFailed(address,bytes4)",
                    address(artists),
                    IStreamArtistMintConsent.requireMintConsent.selector
                );
            uint256 cap = _documentaryCallGas(b.data, DOCUMENTARY_PRICE);
            vm.prank(BUYER);
            (bool ok, bytes memory reason) =
                address(sale).call{ value: DOCUMENTARY_PRICE, gas: cap }(b.data);
            require(
                !ok && keccak256(reason) == keccak256(expectedReason),
                "exact documentary rejection boundary"
            );
            require(
                documentaryBuyerSafe.nonce() == beforeSafe, "failed EOA does not consume Safe nonce"
            );
        }
        require(
            before == _documentaryMutableStateHash(),
            "all money Core Ledger nonce entropy and history rollback"
        );
        require(
            !sale.authorizationUsed(artist, b.authorization.nonce)
                && !manager.isAuthorizationUsed(b.id)
                && !manager.isOperationRootUsed(b.expected.operationRoot),
            "exact signed sale remains retryable"
        );
        DocumentaryDirect.Receipt memory empty;
        StreamDirectPrimaryConservationTypes.Receipt memory noFloor;
        require(
            IStreamDirectPrimarySaleReceipt(address(sale)).directPrimarySaleReceiptHash(b.id) == 0
                && keccak256(
                    abi.encode(
                        IStreamDirectPrimarySaleReceipt(address(sale))
                            .directPrimarySaleReceipt(b.id)
                    )
                ) == keccak256(abi.encode(empty))
                && keccak256(
                    abi.encode(
                        documentaryFloor.directPrimarySaleFloorReceipt(_documentaryDirectKey(b.id))
                    )
                ) == keccak256(abi.encode(noFloor)),
            "rejected paid operation retains no receipt"
        );
        _assertDocumentaryHistory();
    }

    function _documentaryMutableStateHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                BUYER.balance,
                address(documentaryBuyerSafe).balance,
                wallet.balance,
                address(sale).balance,
                address(revenueEscrow).balance,
                sale.totalNativeProceeds(),
                sale.nativeProceeds(profile),
                revenueEscrow.totalOwed(address(0)),
                revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0)),
                core.totalSupply(),
                core.collectionMintedEver(1),
                core.lastAllocatedTokenId(),
                manager.nextOperationNonce(),
                _documentaryLedgerCount(),
                entropy.tokenEntropyStatus(core.lastAllocatedTokenId() + 1),
                documentaryFloor.firstSale(1),
                documentaryFloor.releaseFloorReceipt(_documentaryReleaseKey(_documentaryContext()))
            )
        );
    }

    /// @dev No access list; charge transaction base and the literal signed outer calldata.
    function _documentaryTransactionExecutionGas(bytes memory data) private pure returns (uint256) {
        uint256 intrinsic = 21_000;
        for (uint256 i; i < data.length; ++i) {
            intrinsic += data[i] == 0 ? 4 : 16;
        }
        require(intrinsic < DOCUMENTARY_TRANSACTION_GAS, "bounded documentary calldata");
        return DOCUMENTARY_TRANSACTION_GAS - intrinsic;
    }

    /// @dev A positive-value CALL adds a stipend after the requested gas. Subtract it so the
    /// callee's complete allowance stays inside the original transaction execution envelope.
    function _documentaryCallGas(bytes memory data, uint256 value) private pure returns (uint256) {
        uint256 execution = _documentaryTransactionExecutionGas(data);
        uint256 stipend = value == 0 ? 0 : 2_300;
        require(execution >= stipend, "bounded documentary value stipend");
        return execution - stipend;
    }

    function _boundedDocumentarySafeBuy(bytes memory data, bool failureProbe)
        private
        returns (bool)
    {
        uint256 inner = failureProbe ? 16_000_000 : 0;
        bytes32 digest = documentaryBuyerSafe.getTransactionHash(
            address(sale),
            DOCUMENTARY_PRICE,
            data,
            0,
            inner,
            0,
            0,
            address(0),
            address(0),
            documentaryBuyerSafe.nonce()
        );
        bytes memory outer = abi.encodeCall(
            documentaryBuyerSafe.execTransaction,
            (
                address(sale),
                DOCUMENTARY_PRICE,
                data,
                uint8(0),
                inner,
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(documentaryBuyerKeys, digest)
            )
        );
        uint256 cap = _documentaryCallGas(outer, 0);
        (bool ok, bytes memory result) = address(documentaryBuyerSafe).call{ gas: cap }(outer);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        require(result.length == 32, "canonical actual Safe transaction result");
        return abi.decode(result, (bool));
    }

    function _documentaryLedgerCount() private view returns (uint64) {
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(ledger),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                uint256(1),
                PHASE,
                keccak256("supply")
            )
        );
        return manager.counterValue(1, PHASE, keccak256("supply"), subject);
    }

    function _documentaryHistoryHash(bytes32 id, bytes32 releaseKey)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                IStreamDirectPrimarySaleReceipt(address(sale)).directPrimarySaleReceipt(id),
                IStreamDirectPrimarySaleReceipt(address(sale)).directPrimarySaleReceiptHash(id),
                documentaryFloor.directPrimarySaleFloorReceipt(_documentaryDirectKey(id)),
                documentaryFloor.firstSale(1),
                documentaryFloor.releaseFloorReceipt(releaseKey),
                documentaryFloor.settlementReceipt(_documentaryDirectKey(id))
            )
        );
    }

    function _assertDocumentaryHistory() internal view {
        uint256 count = documentaryPurchases.length;
        require(
            documentaryFloor.sourceCount() == documentarySourceRows.length
                && documentaryFloor.sourceSetHashAt(0)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                            block.chainid,
                            address(core),
                            address(documentaryFloor)
                        )
                    ),
            "original source genesis and count"
        );
        for (uint256 i; i < documentarySourceRows.length; ++i) {
            require(
                keccak256(abi.encode(documentaryFloor.sourceAt(uint64(i + 1))))
                        == documentarySourceRows[i]
                    && documentaryFloor.sourceSetHashAt(uint64(i + 1)) == documentarySourceHeads[i],
                "permanent complete source rows and prefix heads"
            );
        }
        require(
            BUYER.balance == DOCUMENTARY_FUNDS - documentaryEOADebit
                && address(documentaryBuyerSafe).balance
                    == DOCUMENTARY_FUNDS - documentarySafeDebit,
            "documentary intended payer debit"
        );
        require(
            wallet.balance == count * DOCUMENTARY_PRICE
                && sale.totalNativeProceeds() == count * DOCUMENTARY_PRICE
                && sale.nativeProceeds(profile) == count * DOCUMENTARY_PRICE
                && address(sale).balance == 0 && revenueEscrow.totalOwed(address(0)) == 0
                && address(revenueEscrow).balance == 0
                && revenueEscrow.escrowOwed(PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
                    == 0,
            "documentary value conserved in original split wallet"
        );
        require(
            core.collectionMintedEver(1) == count && core.lastAllocatedTokenId() == count
                && manager.nextOperationNonce() == count && _documentaryLedgerCount() == count
                && core.totalSupply() == count - documentaryBurned,
            "documentary supply and replay counts"
        );
        if (count == 0) {
            require(
                documentaryFloor.firstSale(1).receiptHash == 0,
                "no unpaid first documentary receipt"
            );
        } else {
            require(
                keccak256(abi.encode(documentaryFloor.firstSale(1))) == documentaryFirstTuple,
                "permanent full first documentary evidence"
            );
        }
        for (uint256 i; i < count; ++i) {
            bytes32 id = documentaryPurchases[i];
            DocumentaryDirect.Receipt memory original =
                IStreamDirectPrimarySaleReceipt(address(sale)).directPrimarySaleReceipt(id);
            StreamDirectPrimaryConservationTypes.Receipt memory retained =
                documentaryFloor.directPrimarySaleFloorReceipt(_documentaryDirectKey(id));
            // Locate the immutable release by its retained current content, independently of a later selection.
            bytes32 releaseKey = documentaryPurchaseRelease[id];
            require(
                documentaryHistory[id] == _documentaryHistoryHash(id, releaseKey)
                    && documentaryReleaseHistory[releaseKey]
                        == keccak256(abi.encode(documentaryFloor.releaseFloorReceipt(releaseKey)))
                    && retained.firstSaleReceiptHash == documentaryFirstHash
                    && retained.releaseReceiptHash != 0,
                "permanent all documentary receipt words"
            );
            require(
                manager.isAuthorizationUsed(id)
                    && manager.isOperationRootUsed(original.operationRoot)
                    && sale.authorizationUsed(artist, documentaryPurchaseNonce[id]),
                "retained documentary replay protection"
            );
            DocumentaryFloor.SettlementReceipt memory noUniversal;
            require(
                keccak256(abi.encode(documentaryFloor.settlementReceipt(_documentaryDirectKey(id))))
                    == keccak256(abi.encode(noUniversal)),
                "DIRECT is not a fabricated universal settlement"
            );
            (bool exists, uint256 cid, uint256 serial, bool burned) =
                core.tokenCollectionIdentity(i + 1);
            require(
                exists && cid == 1 && serial == i + 1
                    && burned == (documentaryOwners[i + 1] == address(0))
                    && core.tokenLifecycle(i + 1) == (burned ? 3 : 2)
                    && core.coordinatorAtMint(i + 1) == address(entropy)
                    && entropy.tokenEntropyStatus(i + 1) == StreamEntropyStatus.REGISTERED,
                "permanent documentary Core and entropy identity"
            );
            if (!burned) {
                require(
                    core.ownerOf(i + 1) == documentaryOwners[i + 1], "documentary current custody"
                );
            }
        }
    }

    mapping(bytes32 => bytes32) internal documentaryPurchaseRelease;

    function _documentaryBuy(bool safePayer) internal returns (bytes32 id) {
        DocumentaryBuy memory b = _prepareDocumentaryBuy(safePayer);
        documentaryPurchaseRelease[b.id] = _documentaryReleaseKey(_documentaryContext());
        _executeDocumentaryBuy(b);
        return b.id;
    }

    function _documentaryTransferOrBurn(uint256 seed, bool burn) internal {
        uint256 count = documentaryPurchases.length;
        if (count == 0 || documentaryBurned == count) {
            _documentaryBuy(seed % 2 == 0);
            return;
        }
        uint256 id = 1 + seed % count;
        while (documentaryOwners[id] == address(0)) id = id == count ? 1 : id + 1;
        address owner = documentaryOwners[id];
        address recipient = owner == BUYER ? address(documentaryBuyerSafe) : BUYER;
        bytes memory data = burn
            ? abi.encodeCall(core.burn, (id))
            : abi.encodeCall(core.transferFrom, (owner, recipient, id));
        if (owner == address(documentaryBuyerSafe)) {
            require(
                executeSafe(documentaryBuyerSafe, documentaryBuyerKeys, address(core), 0, data, 0),
                "actual Safe documentary custody action"
            );
        } else {
            vm.prank(owner);
            (bool ok,) = address(core).call(data);
            require(ok, "actual EOA documentary custody action");
        }
        documentaryOwners[id] = burn ? address(0) : recipient;
        if (burn) ++documentaryBurned;
        _assertDocumentaryHistory();
    }

    function _documentaryMissingMasterRetry(bool safePayer) internal {
        _publishDocumentaryMedia(++documentaryNextMedia, false);
        DocumentaryBuy memory b = _prepareDocumentaryBuy(safePayer);
        bytes32 key = _documentaryReleaseKey(_documentaryContext());
        require(
            documentaryFloor.releaseFloorReceipt(key).receiptHash == 0,
            "new unproved semantic release"
        );
        // The original adapter makes exactly one Floor call per execution. This authorization
        // is unique to this failed/successful pair: its retry alone cannot satisfy two calls.
        // Exact-count expectations are verified at the root return, including reverted calls.
        DocumentaryCallVm(address(vm))
            .expectCall(
                address(documentaryFloor),
                abi.encodeCall(documentaryFloor.recordDirectPrimarySale, (b.id)),
                2
            );
        _expectDocumentaryBuyFailure(b);
        _completeDocumentaryMaster();
        documentaryPurchaseRelease[b.id] = key;
        _executeDocumentaryBuy(b);
    }
}
