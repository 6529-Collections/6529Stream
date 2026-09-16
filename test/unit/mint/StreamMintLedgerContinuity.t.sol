// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintContinuityProfiles.t.sol";

/// @dev Unsupported/malformed source capability only; ordinary succession tests use actual Ledgers.
contract MintAncestryUnsupportedSource {
    uint256 private immutable _mode;

    constructor(uint256 mode) {
        _mode = mode;
    }

    function supportsInterface(bytes4) external view returns (bool) {
        if (_mode == 0) return false;
        uint256 word = _mode == 1 ? 1 : 2;
        uint256 length = _mode == 1 ? 64 : 32;
        assembly ("memory-safe") {
            mstore(0, word)
            mstore(32, 0)
            return(0, length)
        }
    }

    function ledgerWriterRetiredAt(address) external view returns (uint64) {
        return uint64(block.number);
    }

    function ledgerWriter(address) external pure returns (bool) {
        return false;
    }

    function managerDefinitionCount(address) external pure returns (uint256) {
        return 0;
    }

    function mintAncestorCount(address) external pure returns (uint256) {
        return 0;
    }
}

/// @dev Actual Ledger ancestry storage, retirement and import; Manager/Core/governance are typed seams.
contract StreamMintLedgerContinuityTest is CharacterizationTestBase {
    bytes32 private constant MANIFEST = keccak256("mint-ancestry-test-manifest");
    MockGovernedParameterAuthority private authority;
    StreamMintLedger private ledger;
    MintContinuityProfileWriter private first;

    function setUp() public {
        vm.roll(100);
        authority = new MockGovernedParameterAuthority(true);
        ledger = new StreamMintLedger();
        first = _writer(ledger);
    }

    function _writer(StreamMintLedger target) private returns (MintContinuityProfileWriter result) {
        result = new MintContinuityProfileWriter(target, address(this), address(authority));
        address admin = target.owner();
        vm.prank(admin);
        target.setLedgerWriter(address(result), true);
    }

    function _retire(StreamMintLedger target, MintContinuityProfileWriter writer) private {
        address admin = target.owner();
        vm.prank(admin);
        target.retireLedgerWriter(address(writer));
    }

    function _root(
        StreamMintLedger source,
        MintContinuityProfileWriter prior,
        StreamMintLedger destination,
        MintContinuityProfileWriter next
    ) private view returns (bytes32) {
        // No counter or nullifier is consumed in this suite; the descriptor is the sole Merkle leaf.
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(destination),
                        address(source),
                        address(prior),
                        address(next),
                        uint64(block.number),
                        MANIFEST,
                        uint64(0),
                        uint64(0)
                    )
                )
            )
        );
    }

    function _authorize(
        StreamMintLedger source,
        MintContinuityProfileWriter prior,
        StreamMintLedger destination,
        MintContinuityProfileWriter next,
        bytes32 root
    ) private {
        if (destination.owner() == address(this)) {
            destination.transferOwnership(address(authority));
        }
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(destination),
                address(next)
            )
        );
        bytes32 value = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(source),
                address(prior),
                address(next),
                uint64(block.number),
                root,
                MANIFEST
            )
        );
        authority.setCurrentAction(true, keccak256("mint-ancestry-action"), 1, scope, 0, value);
    }

    function _commit(
        StreamMintLedger source,
        MintContinuityProfileWriter prior,
        StreamMintLedger destination,
        MintContinuityProfileWriter next
    ) private returns (bytes32 root) {
        root = _root(source, prior, destination, next);
        _authorize(source, prior, destination, next, root);
        vm.prank(address(authority));
        destination.commitCounterImportRoot(
            address(source), address(prior), address(next), uint64(block.number), root, MANIFEST
        );
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _begin(
        StreamMintLedger source,
        MintContinuityProfileWriter prior,
        StreamMintLedger destination,
        MintContinuityProfileWriter next
    ) private returns (bytes32) {
        _retire(source, prior);
        return _commit(source, prior, destination, next);
    }

    function _finish(StreamMintLedger target, bytes32 root) private {
        (uint256 copied, uint256 required) = target.mintImportAncestryProgress(root);
        while (copied < required) {
            target.importMintAncestors(root, 32);
            (copied, required) = target.mintImportAncestryProgress(root);
        }
        target.completeCounterImport(root, 0, 0, new bytes32[](0));
    }

    function _assertPair(
        StreamMintLedger target,
        MintContinuityProfileWriter writer,
        uint256 index,
        StreamMintLedger ancestorLedger,
        MintContinuityProfileWriter ancestor
    ) private view {
        (address actualLedger, address actualManager) =
            target.mintAncestorAt(address(writer), index);
        require(
            actualLedger == address(ancestorLedger) && actualManager == address(ancestor),
            "exact ancestor pair"
        );
    }

    function _assertProgress(
        StreamMintLedger target,
        bytes32 root,
        uint256 imported,
        uint256 required
    ) private view {
        (uint256 actualImported, uint256 actualRequired) = target.mintImportAncestryProgress(root);
        require(actualImported == imported && actualRequired == required, "exact ancestry progress");
    }

    function testFirstGenerationHasImmediateAncestorAndIndependentInterface() public {
        require(
            ledger.supportsInterface(type(IStreamMintLedgerImport).interfaceId),
            "original import capability"
        );
        require(
            ledger.supportsInterface(type(IStreamMintLedgerContinuity).interfaceId),
            "separate continuity capability"
        );
        MintContinuityProfileWriter next = _writer(ledger);
        bytes32 root = _begin(ledger, first, ledger, next);
        _assertProgress(ledger, root, 0, 0);
        require(
            ledger.mintAncestorCount(address(next)) == 1, "immediate predecessor recorded at commit"
        );
        _assertPair(ledger, next, 0, ledger, first);
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "pending root authorizes nothing"
        );
        _finish(ledger, root);
        require(
            ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "completed immediate descendant"
        );
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(next), address(next)),
            "identity is not its own ancestor"
        );
    }

    function testThreeGenerationsKeepOriginalAndRetiredIntermediateAnchors() public {
        StreamMintLedger middleLedger = new StreamMintLedger();
        MintContinuityProfileWriter middle = _writer(middleLedger);
        bytes32 firstRoot = _begin(ledger, first, middleLedger, middle);
        _finish(middleLedger, firstRoot);
        StreamMintLedger lastLedger = new StreamMintLedger();
        MintContinuityProfileWriter last = _writer(lastLedger);
        bytes32 secondRoot = _begin(middleLedger, middle, lastLedger, last);
        require(
            !middleLedger.isCompletedMintDescendant(
                address(ledger), address(first), address(middle)
            ),
            "retired intermediate is not live"
        );
        require(
            middleLedger.mintImportCommitment(firstRoot).complete, "historical completion retained"
        );
        _assertProgress(lastLedger, secondRoot, 0, 1);
        require(
            !lastLedger.isCompletedMintDescendant(
                address(middleLedger), address(middle), address(last)
            ),
            "pending direct anchor refused"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        lastLedger.completeCounterImport(secondRoot, 0, 0, new bytes32[](0));
        vm.prank(address(0xBEEF));
        lastLedger.importMintAncestors(secondRoot, 1);
        _assertProgress(lastLedger, secondRoot, 1, 1);
        _assertPair(lastLedger, last, 0, middleLedger, middle);
        _assertPair(lastLedger, last, 1, ledger, first);
        _finish(lastLedger, secondRoot);
        require(
            lastLedger.isCompletedMintDescendant(address(ledger), address(first), address(last)),
            "original anchor retained"
        );
        require(
            lastLedger.isCompletedMintDescendant(
                address(middleLedger), address(middle), address(last)
            ),
            "intermediate anchor retained"
        );
        require(
            !lastLedger.isCompletedMintDescendant(
                address(middleLedger), address(first), address(last)
            ),
            "ledger and manager cannot be mixed"
        );
        require(
            !lastLedger.isCompletedMintDescendant(address(ledger), address(middle), address(last)),
            "opposite wrong pair refused"
        );
    }

    function testSiblingIsNotAnAncestorOrAnAlternateSuccessor() public {
        MintContinuityProfileWriter sibling = _writer(ledger);
        bytes32 siblingRoot = _begin(ledger, first, ledger, sibling);
        _finish(ledger, siblingRoot);
        MintContinuityProfileWriter next = _writer(ledger);
        bytes32 nextRoot = _commit(ledger, first, ledger, next);
        _finish(ledger, nextRoot);
        require(
            ledger.isCompletedMintDescendant(address(ledger), address(first), address(sibling)),
            "sibling has its own root"
        );
        require(
            ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "next has its own root"
        );
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(sibling), address(next)),
            "shared origin is not ancestry"
        );
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(next), address(sibling)),
            "branches are not interchangeable"
        );
        require(
            !ledger.isMintSuccessorReady(address(ledger), address(sibling), address(next)),
            "Core immediate-pair guard remains exact"
        );
    }

    function testDisabledOrRetiredSuccessorFailsLiveCheckWithoutDeletingHistory() public {
        MintContinuityProfileWriter next = _writer(ledger);
        bytes32 root = _begin(ledger, first, ledger, next);
        _finish(ledger, root);
        vm.prank(address(authority));
        ledger.setLedgerWriter(address(next), false);
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "disabled writer refused"
        );
        vm.prank(address(authority));
        ledger.setLedgerWriter(address(next), true);
        require(
            ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "reenabled completed writer accepted"
        );
        _retire(ledger, next);
        require(
            !ledger.isCompletedMintDescendant(address(ledger), address(first), address(next)),
            "retired writer refused"
        );
        require(ledger.mintAncestorCount(address(next)) == 1, "historical ancestry not deleted");
        _assertPair(ledger, next, 0, ledger, first);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importMintAncestors(root, 1);
    }

    function testAncestryPaginationBoundsAndCompletionGate() public {
        MintContinuityProfileWriter prior = first;
        // Build a real 33-link completed history without synthetic storage writes.
        for (uint256 i; i < 33; ++i) {
            MintContinuityProfileWriter next = _writer(ledger);
            bytes32 completedRoot = _begin(ledger, prior, ledger, next);
            _finish(ledger, completedRoot);
            prior = next;
        }
        require(ledger.mintAncestorCount(address(prior)) == 33, "source ancestry length");
        StreamMintLedger destination = new StreamMintLedger();
        MintContinuityProfileWriter last = _writer(destination);
        bytes32 root = _begin(ledger, prior, destination, last);
        _assertProgress(destination, root, 0, 33);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importMintAncestors(root, 0);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importMintAncestors(root, 33);
        destination.importMintAncestors(root, 32);
        _assertProgress(destination, root, 32, 33);
        require(
            destination.mintAncestorCount(address(last)) == 33,
            "immediate predecessor plus first page"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.completeCounterImport(root, 0, 0, new bytes32[](0));
        require(
            !destination.isCompletedMintDescendant(address(ledger), address(prior), address(last)),
            "partial ancestry is not ready"
        );
        destination.importMintAncestors(root, 32);
        _assertProgress(destination, root, 33, 33);
        require(destination.mintAncestorCount(address(last)) == 34, "all unique ancestors copied");
        destination.importMintAncestors(root, 32);
        require(
            destination.mintAncestorCount(address(last)) == 34,
            "exhausted cursor never duplicates ancestors"
        );
        _finish(destination, root);
        require(
            destination.isCompletedMintDescendant(address(ledger), address(first), address(last)),
            "oldest anchor survives bounded pages"
        );
        _assertPair(destination, last, 33, ledger, first);
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        destination.importMintAncestors(root, 1);
    }

    function testUnknownRootCannotWriteAncestry() public {
        vm.expectRevert(abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector));
        ledger.importMintAncestors(keccak256("unknown-root"), 1);
        require(ledger.mintAncestorCount(address(first)) == 0, "unknown root cannot seed ancestry");
    }

    function testUnsupportedOrMalformedSourceCapabilityFailsClosed() public {
        for (uint256 mode; mode < 3; ++mode) {
            StreamMintLedger source =
                StreamMintLedger(address(new MintAncestryUnsupportedSource(mode)));
            MintContinuityProfileWriter prior =
                new MintContinuityProfileWriter(source, address(this), address(authority));
            StreamMintLedger destination = new StreamMintLedger();
            MintContinuityProfileWriter next = _writer(destination);
            bytes32 root = _root(source, prior, destination, next);
            _authorize(source, prior, destination, next, root);
            vm.prank(address(authority));
            vm.expectRevert(
                abi.encodeWithSelector(IStreamMintLedgerImport.MintImportInvalid.selector)
            );
            destination.commitCounterImportRoot(
                address(source), address(prior), address(next), uint64(block.number), root, MANIFEST
            );
            require(
                destination.mintImportCommitment(root).successorManager == address(0),
                "unsupported source leaves no commitment"
            );
            require(
                destination.mintAncestorCount(address(next)) == 0,
                "unsupported source leaves no ancestry"
            );
        }
    }
}
