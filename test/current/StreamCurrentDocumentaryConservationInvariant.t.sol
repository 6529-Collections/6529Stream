// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDocumentaryConservationFixture.sol";

interface DocumentaryStatefulHost {
    function documentaryStep(uint256 action, uint256 seed) external returns (uint256 completed);
    function completedDocumentaryActions() external view returns (uint256);
    function assertDocumentaryCampaignState() external view;
}

/// @notice One bounded dispatcher over real documentary commerce and original evidence producers.
/// @dev Supported invariant depth is at most 256. Every successful step changes actual Core state
/// and passes the host's complete payment, receipt and permanent-identity model before counting.
contract StreamCurrentDocumentaryConservationHandler {
    uint256 public constant OPENING_ACTIONS = 9;
    uint256 public constant MAX_STEPS = 256;
    DocumentaryStatefulHost public immutable host;
    uint256 public steps;
    uint256 public randomizedSteps;
    uint256[9] public actionCalls;

    constructor(DocumentaryStatefulHost host_) {
        host = host_;
    }

    function step(uint256 seed) external {
        uint256 previous = steps;
        require(previous < MAX_STEPS, "documentary campaign exceeds supported depth");
        require(
            host.completedDocumentaryActions() == previous, "documentary dispatch counters agree"
        );
        uint256 action = previous < OPENING_ACTIONS ? previous : seed % OPENING_ACTIONS;
        require(
            host.documentaryStep(action, seed) == previous + 1,
            "documentary dispatch completed exactly once"
        );
        steps = previous + 1;
        ++actionCalls[action];
        if (previous >= OPENING_ACTIONS) ++randomizedSteps;
        host.assertDocumentaryCampaignState();
    }

    function assertInvariants() external view {
        uint256 total;
        for (uint256 i; i < OPENING_ACTIONS; ++i) {
            total += actionCalls[i];
        }
        require(
            total == steps && host.completedDocumentaryActions() == steps,
            "documentary completed actions match actual dispatches"
        );
        require(
            steps <= MAX_STEPS
                && randomizedSteps == (steps > OPENING_ACTIONS ? steps - OPENING_ACTIONS : 0),
            "documentary bounded opening and random tail"
        );
        host.assertDocumentaryCampaignState();
    }

    function assertCampaignActivity() external view {
        require(
            steps >= OPENING_ACTIONS, "documentary campaign lacked required successful activity"
        );
        for (uint256 i; i < OPENING_ACTIONS; ++i) {
            require(actionCalls[i] != 0, "documentary campaign lacked required successful activity");
        }
    }

    function assertRandomizedActivity() external view {
        require(randomizedSteps != 0, "documentary campaign stopped at deterministic opening");
    }
}

/// @notice Non-WAIVED current-stack stateful conservation, separate from the WAIVED campaign.
/// @dev Real Safe, Artist and archive contracts authenticate local fixture evidence. No public
/// upload, independent retrieval or passing runtime/capacity evidence is implied by this source.
contract StreamCurrentDocumentaryConservationInvariantTest is
    CurrentDocumentaryConservationFixture
{
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }

    StreamCurrentDocumentaryConservationHandler private documentaryHandler;
    uint256 public completedDocumentaryActions;

    function setUp() public {
        _setUpDocumentaryConservation();
        documentaryHandler =
            new StreamCurrentDocumentaryConservationHandler(DocumentaryStatefulHost(address(this)));
    }

    /// @dev Only the handler can mutate the campaign. Every branch performs one checked sale or
    /// custody transition; a failed late-floor probe is always followed by the exact signed retry.
    function documentaryStep(uint256 action, uint256 seed) external returns (uint256) {
        require(msg.sender == address(documentaryHandler), "only documentary handler");
        require(action < 9 && completedDocumentaryActions < 256, "bounded documentary action");
        bytes32 previousCore = _documentaryCoreProgress();
        if (action == 0) {
            _documentaryBuy(false);
        } else if (action == 1) {
            _documentaryBuy(true);
        } else if (action == 2) {
            DocumentaryBuy memory buy = _prepareDocumentaryBuy(true);
            bytes32 signedBytes = keccak256(buy.data);
            bytes32 native = documentaryCurrentNative;
            bytes32 general = documentaryCurrentGeneral;
            _supersedeDocumentaryPersonhood(false);
            require(
                documentaryCurrentGeneral != general && documentaryCurrentNative == native,
                "General successor does not replace original native selection"
            );
            // Actual Artist prerequisites reject the stale native reference before funding.
            // The permanent first-sale receipt does not authorize another mint by itself.
            _expectDocumentaryEarlyBuyFailure(buy);
            _assertDocumentaryHistory();
            _refreshDocumentaryPersonhood();
            require(
                keccak256(buy.data) == signedBytes,
                "same signed sale after fresh original personhood"
            );
            _executeDocumentaryBuy(buy);
        } else if (action == 3) {
            bytes32 native = documentaryCurrentNative;
            bytes32 general = documentaryCurrentGeneral;
            _supersedeDocumentaryPersonhood(true);
            require(
                documentaryCurrentNative != native && documentaryCurrentGeneral != general,
                "fresh General report and original Artist selection"
            );
            _documentaryBuy(false);
        } else if (action == 4) {
            _documentaryMissingMasterRetry(false);
        } else if (action == 5) {
            _documentaryMissingMasterRetry(true);
        } else if (action == 6) {
            uint64 count = documentaryFloor.sourceCount();
            _appendDocumentarySource();
            require(documentaryFloor.sourceCount() == count + 1, "actual source append progress");
            _documentaryBuy(seed % 2 == 0);
        } else if (action == 7) {
            _documentaryTransferOrBurn(seed, false);
        } else {
            _documentaryTransferOrBurn(seed, true);
        }
        _assertDocumentaryHistory();
        require(
            _documentaryCoreProgress() != previousCore,
            "documentary action made no checked progress"
        );
        return ++completedDocumentaryActions;
    }

    /// @dev Progress derives from actual supply and owners, never the dispatch counter itself.
    function _documentaryCoreProgress() private view returns (bytes32 hash) {
        uint256 minted = core.collectionMintedEver(1);
        hash = keccak256(abi.encode(minted, core.totalSupply(), core.lastAllocatedTokenId()));
        for (uint256 id = 1; id <= minted; ++id) {
            uint8 lifecycle = core.tokenLifecycle(id);
            address owner = lifecycle == 2 ? core.ownerOf(id) : address(0);
            hash = keccak256(abi.encode(hash, id, lifecycle, owner));
        }
    }

    function assertDocumentaryCampaignState() external view {
        _assertDocumentaryHistory();
        require(
            completedDocumentaryActions == documentaryHandler.steps(),
            "documentary host and handler progress agree"
        );
        require(
            documentaryPurchases.length <= completedDocumentaryActions,
            "at most one successful paid mint per documentary dispatch"
        );
        require(
            documentaryNextMedia
                    == 1 + documentaryHandler.actionCalls(4) + documentaryHandler.actionCalls(5)
                && documentaryNextMedia <= 250,
            "bounded fresh media variants without skipped retries"
        );
        require(
            documentaryFloor.sourceCount() == 1 + documentaryHandler.actionCalls(6),
            "all documentary source appends accounted for"
        );
    }

    // Standard Foundry invariant discovery ABI; only the single bounded step is targeted.
    function targetContracts() external view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(documentaryHandler);
    }

    function targetSelectors() external view returns (FuzzSelector[] memory targets) {
        targets = new FuzzSelector[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = StreamCurrentDocumentaryConservationHandler.step.selector;
        targets[0] = FuzzSelector(address(documentaryHandler), selectors);
    }

    function excludeContracts() external pure returns (address[] memory) {
        return new address[](0);
    }

    function targetSenders() external pure returns (address[] memory) {
        return new address[](0);
    }

    function excludeSenders() external pure returns (address[] memory) {
        return new address[](0);
    }

    function targetArtifacts() external pure returns (string[] memory) {
        return new string[](0);
    }

    function excludeArtifacts() external pure returns (string[] memory) {
        return new string[](0);
    }

    function targetArtifactSelectors() external pure returns (FuzzArtifactSelector[] memory) {
        return new FuzzArtifactSelector[](0);
    }

    function targetInterfaces() external pure returns (FuzzInterface[] memory) {
        return new FuzzInterface[](0);
    }

    function excludeSelectors() external pure returns (FuzzSelector[] memory) {
        return new FuzzSelector[](0);
    }

    function invariant_documentaryValueAndOriginalEvidenceRemainPermanent() public view {
        documentaryHandler.assertInvariants();
    }

    function afterInvariant() public view {
        documentaryHandler.assertCampaignActivity();
        documentaryHandler.assertRandomizedActivity();
        documentaryHandler.assertInvariants();
    }

    function testDocumentaryOpeningExercisesEveryRequiredOriginalOperation() public {
        _documentaryOpening();
        require(
            completedDocumentaryActions == 9 && documentaryPurchases.length == 7
                && documentaryBurned == 1 && documentaryNextMedia == 3,
            "exact deterministic documentary opening activity"
        );
        documentaryHandler.assertCampaignActivity();
    }

    function testDocumentaryActivityOracleRejectsNoProgress() public {
        documentaryHandler.assertInvariants();
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "documentary campaign lacked required successful activity"
            )
        );
        documentaryHandler.assertCampaignActivity();
    }

    function testDocumentaryRandomTailRequiredAndEveryRandomTargetProgresses() public {
        _documentaryOpening();
        vm.expectRevert(
            abi.encodeWithSignature(
                "Error(string)", "documentary campaign stopped at deterministic opening"
            )
        );
        documentaryHandler.assertRandomizedActivity();
        for (uint256 i; i < 9; ++i) {
            uint256 before = documentaryHandler.actionCalls(i);
            documentaryHandler.step(9_000 + i);
            require(
                documentaryHandler.actionCalls(i) == before + 1,
                "each randomized documentary target completed"
            );
        }
        afterInvariant();
    }

    function testDocumentaryHostRejectsNonHandlerDispatch() public {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "only documentary handler"));
        this.documentaryStep(0, 7);
        require(
            completedDocumentaryActions == 0 && documentaryPurchases.length == 0,
            "unauthorized dispatch changes no campaign state"
        );
        documentaryHandler.assertInvariants();
    }

    function testFuzzDocumentaryOpeningAndSixteenStatefulTailSteps(uint256 seed) public {
        _documentaryOpening();
        for (uint256 i; i < 16; ++i) {
            seed = uint256(keccak256(abi.encode("documentary random tail", seed, i)));
            documentaryHandler.step(seed);
        }
        require(
            completedDocumentaryActions == 25 && documentaryHandler.randomizedSteps() == 16,
            "all seeded documentary tail steps completed"
        );
        afterInvariant();
    }

    function _documentaryOpening() private {
        for (uint256 i; i < 9; ++i) {
            documentaryHandler.step(i * 101 + 7);
        }
        documentaryHandler.assertInvariants();
    }
}
