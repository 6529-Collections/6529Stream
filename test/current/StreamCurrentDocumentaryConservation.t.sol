// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDocumentaryConservationFixture.sol";

interface DocumentaryHistoryFaultVm {
    function mockCall(address target, bytes calldata data, bytes calldata returned) external;
    function clearMockedCalls() external;
}

/// @notice Non-WAIVED documentary commerce using original Core, Safe, Artist and record producers.
/// @dev The complete local image/archive evidence is a synthetic fixture, not a public upload.
/// Unlike the separate WAIVED campaign, both immutable first-sale and release facts are required.
contract StreamCurrentDocumentaryConservationTest is CurrentDocumentaryConservationFixture {
    function setUp() public {
        _setUpDocumentaryConservation();
    }

    function testOriginalLiteFirstSaleStoresRealSignedPersonhoodRightsAndArchivedMaster() public {
        require(
            documentaryInitialWaiver != 0 && documentaryFirstGeneral != 0
                && documentaryFirstNative != documentaryInitialWaiver
                && documentaryFirstSummary != 0,
            "actual General and native personhood supersede onboarding waiver"
        );
        DocumentaryFloor.CollectionFacts memory current =
            documentaryProvider.requireCollectionFloor(1, DOCUMENTARY_TIER);
        require(
            keccak256(abi.encode(current))
                    == keccak256(abi.encode(_expectedDocumentaryCollectionFacts()))
                && !current.platformWorks
                && current.personhoodEvidenceHash == documentaryFirstSummary
                && current.rightsRecordHash == documentaryRightsRecord
                && current.intentWaiverRecordHash != 0,
            "genuine original documentary collection evidence"
        );
        DocumentaryFloor.ReleaseContext memory release =
            documentaryProvider.currentReleaseContext(1);
        require(
            keccak256(abi.encode(release)) == keccak256(abi.encode(_documentaryContext()))
                && release.mediaInventoryHash != 0 && release.scriptSourceHash == 0
                && !release.scriptWork,
            "independent genuine occupied OFFCHAIN semantic release"
        );
        _documentaryBuy(false);
    }

    function testRealSafePaysOriginalTierAndRepeatedContentReusesWholeFirstAndReleaseReceipts()
        public
    {
        bytes32 first = _documentaryBuy(true);
        bytes32 key = documentaryPurchaseRelease[first];
        bytes32 historicalFirst = keccak256(abi.encode(documentaryFloor.firstSale(1)));
        bytes32 historicalRelease = keccak256(abi.encode(documentaryFloor.releaseFloorReceipt(key)));
        vm.warp(block.timestamp + 1);
        bytes32 second = _documentaryBuy(false);
        require(
            documentaryPurchaseRelease[second] == key
                && documentaryFloor.releaseFloorReceipt(key).settlementKey
                    == _documentaryDirectKey(first)
                && keccak256(abi.encode(documentaryFloor.firstSale(1))) == historicalFirst
                && keccak256(abi.encode(documentaryFloor.releaseFloorReceipt(key)))
                    == historicalRelease,
            "exact immutable first-success denominator reused"
        );
    }

    function testSupersededGeneralBlocksFirstSaleThenIdenticalSignedSafeBuyRetriesAfterRealOp24()
        public
    {
        DocumentaryBuy memory b = _prepareDocumentaryBuy(true);
        _supersedeDocumentaryPersonhood(false);
        _assertCurrentDocumentaryPersonhoodUnavailable();
        bytes32 signedBytes = keccak256(b.data);
        _expectDocumentaryEarlyBuyFailure(b);
        _refreshDocumentaryPersonhood();
        require(
            keccak256(b.data) == signedBytes, "same literal commercial authorization and signatures"
        );
        _executeDocumentaryBuy(b);
        require(
            documentaryFloor.firstSale(1).facts.personhoodEvidenceHash == documentaryCurrentSummary
                && documentaryCurrentSummary != documentaryFirstSummary,
            "first successful current signed summary retained"
        );
    }

    function testSupersessionAfterFirstSaleDoesNotRewriteHistoricalDocumentaryDenominator() public {
        _documentaryBuy(false);
        DocumentaryBuy memory b = _prepareDocumentaryBuy(false);
        _supersedeDocumentaryPersonhood(false);
        _assertCurrentDocumentaryPersonhoodUnavailable();
        _expectDocumentaryEarlyBuyFailure(b);
        _assertDocumentaryHistory();
        _refreshDocumentaryPersonhood();
        DocumentaryFloor.CollectionFacts memory current =
            documentaryProvider.requireCollectionFloor(1, DOCUMENTARY_TIER);
        require(
            current.personhoodEvidenceHash == documentaryCurrentSummary
                && current.personhoodEvidenceHash
                    != documentaryFloor.firstSale(1).facts.personhoodEvidenceHash,
            "live refreshed personhood and historical first sale remain distinct"
        );
        _executeDocumentaryBuy(b);
    }

    function testMissingMasterBeforeFirstSaleRollsBackAndExactEOAAuthorizationRetries() public {
        _documentaryMissingMasterRetry(false);
    }

    function testMissingMasterRejectsLateSafePaymentAndOnlyOuterNonceSurvivesBeforeExactRetry()
        public
    {
        _documentaryBuy(true);
        _documentaryMissingMasterRetry(true);
    }

    function testSourceAppendReprovesCurrentMappingAndPreservesOriginalPaidEvidence() public {
        bytes32 first = _documentaryBuy(false);
        bytes32 key = documentaryPurchaseRelease[first];
        _appendDocumentarySource();
        _documentaryBuy(true);
        require(
            documentaryFloor.sourceCount() == 2 && documentaryFloor.firstSale(1).sourceId == 1
                && documentaryFloor.releaseFloorReceipt(key).sourceId == 1,
            "source replacement cannot rewrite retained evidence"
        );
        _documentaryMissingMasterRetry(false);
        bytes32 latest = documentaryPurchases[documentaryPurchases.length - 1];
        require(
            documentaryFloor.releaseFloorReceipt(documentaryPurchaseRelease[latest]).sourceId == 2,
            "new semantic content uses current admitted source"
        );
    }

    function testTransferAndCompletedBurnPreserveAllDocumentarySaleHistoryAndLifetimeIdentity()
        public
    {
        _documentaryBuy(true);
        _documentaryTransferOrBurn(0, false);
        _documentaryTransferOrBurn(0, true);
        _documentaryBuy(false);
        require(
            core.collectionMintedEver(1) == 2 && core.totalSupply() == 1,
            "burn changes live supply only"
        );
    }

    function testDocumentaryModelRejectsWrongPayerDebitWithUnchangedAggregate() public {
        _documentaryBuy(false);
        vm.prank(BUYER);
        (bool ok,) = payable(address(documentaryBuyerSafe)).call{ value: 1 }("");
        require(ok, "real one-wei wrong-payer movement");
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "documentary intended payer debit")
        );
        this.assertDocumentaryHistory();
    }

    function testDocumentaryModelRejectsMissingFirstReceiptAfterGenuineSuccessfulSale() public {
        _documentaryBuy(false);
        DocumentaryFloor.FirstSaleReceipt memory empty;
        DocumentaryHistoryFaultVm(address(vm))
            .mockCall(
                address(documentaryFloor),
                abi.encodeCall(documentaryFloor.firstSale, (1)),
                abi.encode(empty)
            );
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "permanent full first documentary evidence")
        );
        this.assertDocumentaryHistory();
        DocumentaryHistoryFaultVm(address(vm)).clearMockedCalls();
        _assertDocumentaryHistory();
    }

    /// @dev Measures the actual joined producers under the explicit documentary fixture limits.
    /// Named account cooling excludes transaction intrinsic gas and is not full cold-closure proof.
    function testOriginalDocumentaryProducerBudgetMeasuresRealCollectionAndReleaseReads() public {
        DocumentaryFloor.CollectionFacts memory expected = _expectedDocumentaryCollectionFacts();
        _coolDocumentaryAccounts();
        uint256 before = gasleft();
        (bool ok, bytes memory data) = address(documentaryProvider)
        .staticcall{ gas: DOCUMENTARY_PRODUCER_GAS }(
            abi.encodeCall(documentaryProvider.requireCollectionFloor, (1, DOCUMENTARY_TIER))
        );
        emit DocumentaryGas(
            keccak256("COLLECTION_FLOOR_NAMED_ACCOUNTS_COOLED"),
            before - gasleft(),
            DOCUMENTARY_PRODUCER_GAS
        );
        require(
            ok && keccak256(data) == keccak256(abi.encode(expected)),
            "original collection producer allowance must fit real proof"
        );
        DocumentaryFloor.ReleaseContext memory context = _documentaryContext();
        DocumentaryFloor.SaleContext memory saleContext;
        saleContext.collectionId = 1;
        _coolDocumentaryAccounts();
        before = gasleft();
        (ok, data) = address(documentaryProvider).staticcall{ gas: DOCUMENTARY_PRODUCER_GAS }(
            abi.encodeCall(
                documentaryProvider.requireReleaseFloor, (saleContext, context, DOCUMENTARY_TIER)
            )
        );
        emit DocumentaryGas(
            keccak256("RELEASE_FLOOR_NAMED_ACCOUNTS_COOLED"),
            before - gasleft(),
            DOCUMENTARY_PRODUCER_GAS
        );
        require(
            ok
                && keccak256(data)
                    == keccak256(
                        abi.encode(
                            DocumentaryFloor.ReleaseFacts(
                                context.sourceContextHash, documentaryMediaEvidenceHash, bytes32(0)
                            )
                        )
                    ),
            "original release producer allowance must fit real occupied proof"
        );
    }

    /// @dev Retains the original incompatible configuration as an explicit negative diagnostic.
    /// It cannot become a success claim merely by warming data: reservation admission precedes
    /// the source call. The successful fixture above has a separately declared configuration.
    function testOriginal8mSourceCannotFitOriginal1mProducerAnd6mCallReservations() public {
        StreamNativeConservationFloorProvider.Configuration memory original =
            documentaryProvider.originalConfiguration();
        original.sourceGas.genesisValue = 8_000_000;
        StreamNativeConservationFloorProvider incompatible = StreamNativeConservationFloorProvider(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol:StreamNativeConservationFloorProvider",
                abi.encode(original)
            )
        );
        uint256 sourceReservation = 8_000_000 + uint256(8_000_000) / 63 + 10_000;
        require(
            sourceReservation > 1_000_000 && sourceReservation > 6_000_000,
            "original inner reservation exceeds both outer envelopes"
        );
        (bool ok, bytes memory reason) = address(incompatible).staticcall{ gas: 1_000_000 }(
            abi.encodeCall(incompatible.currentReleaseContext, (1))
        );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamNativeConservationFloorProvider.NativeConservationRead.selector,
                            address(documentaryMasters),
                            IStreamMediaMasterSelection.collectionMediaContext.selector
                        )
                    ),
            "exact original reservation failure before occupied source read"
        );
        _assertDocumentaryHistory();
    }

    function testOriginal1mMasterCannotFitInside1mProviderSourceReservation() public {
        StreamMediaMasterSelection incompatible = StreamMediaMasterSelection(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamMediaMasterSelection.sol:StreamMediaMasterSelection",
                abi.encode(
                    address(core),
                    address(assemblyMetadata),
                    address(assemblySchemas),
                    address(assemblyExternal),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "MEDIA_MASTER_MANIFEST_READ_GAS", 1_000_000, 500_000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "MEDIA_MASTER_COVERAGE_READ_GAS", 1_000_000, 500_000, 2
                    )
                )
            )
        );
        (bool ok, bytes memory reason) = address(incompatible).staticcall{ gas: 1_000_000 }(
            abi.encodeCall(incompatible.collectionMediaContext, (1))
        );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamMediaMasterTypes.MasterCoverageUnavailable.selector
                        )
                    ),
            "exact original nested master reservation rejection"
        );
        _assertDocumentaryHistory();
    }

    function testMasterConstructorRejectsSubminimumManifestFloor() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamMediaMasterTypes.InvalidMasterWitness.selector)
        );
        this.deployRejectedDocumentaryMaster();
        _assertDocumentaryHistory();
    }

    function deployRejectedDocumentaryMaster() external returns (address) {
        require(msg.sender == address(this), "local documentary constructor probe");
        return _artistArtifactCreate(
            "smart-contracts/domains/metadata/StreamMediaMasterSelection.sol:StreamMediaMasterSelection",
            abi.encode(
                address(core),
                address(assemblyMetadata),
                address(assemblySchemas),
                address(assemblyExternal),
                address(executor),
                IStreamGasParameterHost.GasParameterConfig(
                    "MEDIA_MASTER_MANIFEST_READ_GAS", 300_000, 100_000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig(
                    "MEDIA_MASTER_COVERAGE_READ_GAS", 800_000, 500_000, 2
                )
            )
        );
    }

    function assertDocumentaryHistory() external view {
        _assertDocumentaryHistory();
    }

    function _assertCurrentDocumentaryPersonhoodUnavailable() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeConservationFloorProvider.NativePersonhoodVerificationUnavailable
                .selector,
                uint256(1),
                fixtureArtistId,
                documentaryRegistrationIdentity
            )
        );
        documentaryProvider.requireCollectionFloor(1, DOCUMENTARY_TIER);
    }

    function _coolDocumentaryAccounts() private {
        safeVm.cool(address(documentaryProvider));
        safeVm.cool(address(documentaryMasters));
        safeVm.cool(address(core));
        safeVm.cool(address(registry));
        safeVm.cool(address(assemblyMetadata));
        safeVm.cool(address(assemblySchemas));
        safeVm.cool(address(assemblyStore));
        safeVm.cool(address(assemblyRights));
        safeVm.cool(address(assemblyConservation));
        safeVm.cool(address(assemblyExternal));
        safeVm.cool(address(assemblyObjectVerifier));
        safeVm.cool(address(documentaryNotary));
        safeVm.cool(address(router));
        safeVm.cool(address(artists));
        safeVm.cool(address(artistCoordinator));
        safeVm.cool(artistSuite.archive);
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(artistSuite.owners[i]);
        }
    }
}
