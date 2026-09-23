// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintEngineTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintSaleAllowlist.sol";

/// @dev Separate caller proves that sale-side library reads do not inherit the Manager context.
contract MintSaleAllowlistReader {
    function validate(address manager, bytes32 phase, bytes32 counter) external view {
        StreamMintSaleAllowlist.validatePolicy(manager, 1, phase, counter);
    }

    function price(
        address manager,
        bytes32 phase,
        address payer,
        address recipient,
        bytes calldata data,
        bytes32 counter
    ) external view returns (bool, uint256) {
        return StreamMintSaleAllowlist.price(manager, 1, phase, payer, recipient, data, counter);
    }
}

/// @dev Actual Manager/Ledger/Registry; Core, Artist and governance use declared typed seams.
contract StreamMintSaleAllowlistTest is MintEngineTestBase {
    bytes32 private constant PRICE = keccak256("sale-price");
    bytes32 private constant OTHER = keccak256("additional-recipient-cap");
    bytes32 private constant STATIC = keccak256("static-cap");
    address private constant PAYER = address(0xA11);
    address private constant RECIPIENT = address(0xBEEF);
    MintSaleAllowlistReader private reader;

    function setUp() public override {
        super.setUp();
        reader = new MintSaleAllowlistReader();
    }

    function _proof(uint64 cap, bool overridePrice, uint256 value)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory proof)
    {
        proof = IStreamMintCounterPolicy.AllowlistProof(cap, overridePrice, value, new bytes32[](0));
    }

    /// @dev Independent canonical transcript, not a call to the implementation leaf helper.
    function _leaf(
        address mintManager,
        bytes32 phase,
        bytes32 counter,
        address account,
        IStreamMintCounterPolicy.AllowlistProof memory proof
    ) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        mintManager,
                        uint256(1),
                        phase,
                        counter,
                        account,
                        proof.maxCount,
                        proof.hasPriceOverride,
                        proof.priceOverride
                    )
                )
            )
        );
    }

    function _configure(
        bytes32 phase,
        bytes32[] memory ids,
        IStreamMintManager.CounterKeyMode[] memory keys,
        bytes32[] memory roots
    ) private {
        IStreamMintManager.MintCounterConfig[] memory
            configs = new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            bytes32 definition = ledger.registerCounterDefinition(
                IStreamMintCounterPolicy.Definition(
                    IStreamMintCounterPolicy.CounterScope.PHASE, keys[i], roots[i], 0
                )
            );
            configs[i] = IStreamMintManager.MintCounterConfig(
                true,
                keys[i],
                roots[i] == 0
                    ? IStreamMintLedger.CounterCapMode.STATIC
                    : IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
                IStreamMintLedger.CounterDeltaMode.STATIC,
                3,
                1,
                definition
            );
        }
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 10, keccak256("sale-policy"), 0),
            gate,
            ids,
            configs
        );
    }

    function _one(bytes32 phase, IStreamMintManager.CounterKeyMode key, bytes32 root) private {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = PRICE;
        IStreamMintManager.CounterKeyMode[] memory keys = new IStreamMintManager.CounterKeyMode[](1);
        keys[0] = key;
        bytes32[] memory roots = new bytes32[](1);
        roots[0] = root;
        _configure(phase, ids, keys, roots);
    }

    function _data(IStreamMintCounterPolicy.AllowlistProof memory proof)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[0][0] = proof;
        return abi.encode(groups);
    }

    function _price(bytes32 phase, bytes memory data) private view returns (bool, uint256) {
        return reader.price(address(manager), phase, PAYER, RECIPIENT, data, PRICE);
    }

    function _assertInvalidProof(bytes memory data, address account) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE, account
            )
        );
        _price(PHASE, data);
    }

    function testAuthenticatedFreeOverrideIsDistinctFromFallback() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(3, true, 0);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof)
        );
        reader.validate(address(manager), PHASE, PRICE);
        (bool hasOverride, uint256 value) = _price(PHASE, _data(proof));
        require(hasOverride && value == 0, "authenticated free price");
    }

    function testFuzzAuthenticatedFullWidthPrice(uint256 value) public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(3, true, value);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.PAYER,
            _leaf(address(manager), PHASE, PRICE, PAYER, proof)
        );
        (bool hasOverride, uint256 result) = _price(PHASE, _data(proof));
        require(hasOverride && result == value, "full-width payer price");
    }

    function testMaximumUintPricePreserved() public {
        testFuzzAuthenticatedFullWidthPrice(type(uint256).max);
    }

    function testCapOnlyLeafReturnsFallback() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, false, 0);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof)
        );
        (bool hasOverride, uint256 value) = _price(PHASE, _data(proof));
        require(!hasOverride && value == 0, "cap-only fallback");
    }

    function testChangedSubjectAndKeyRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        bytes32 root = _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof);
        _one(PHASE, IStreamMintManager.CounterKeyMode.RECIPIENT, root);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE, PAYER
            )
        );
        reader.price(address(manager), PHASE, PAYER, PAYER, _data(proof), PRICE);
        bytes32 payerPhase = keccak256("payer-key");
        _one(
            payerPhase,
            IStreamMintManager.CounterKeyMode.PAYER,
            _leaf(address(manager), payerPhase, PRICE, RECIPIENT, proof)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE, PAYER
            )
        );
        _price(payerPhase, _data(proof));
    }

    function testChangedChainRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof)
        );
        vm.chainId(block.chainid + 1);
        _assertInvalidProof(_data(proof), RECIPIENT);
    }

    function testChangedManagerRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(reader), PHASE, PRICE, RECIPIENT, proof)
        );
        _assertInvalidProof(_data(proof), RECIPIENT);
    }

    function testChangedPhaseAndCounterTranscriptRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), keccak256("wrong-phase"), PRICE, RECIPIENT, proof)
        );
        _assertInvalidProof(_data(proof), RECIPIENT);
        bytes32 phase = keccak256("wrong-counter");
        _one(
            phase,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), phase, OTHER, RECIPIENT, proof)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE, RECIPIENT
            )
        );
        _price(phase, _data(proof));
    }

    function testChangedRootRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        _one(PHASE, IStreamMintManager.CounterKeyMode.RECIPIENT, keccak256("different-root"));
        _assertInvalidProof(_data(proof), RECIPIENT);
    }

    function testSortedMerkleProofAndChangedSibling() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        bytes32 leaf = _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof);
        bytes32 sibling = keccak256("sibling");
        bytes32 root = leaf < sibling
            ? keccak256(abi.encode(leaf, sibling))
            : keccak256(abi.encode(sibling, leaf));
        _one(PHASE, IStreamMintManager.CounterKeyMode.RECIPIENT, root);
        proof.proof = new bytes32[](1);
        proof.proof[0] = sibling;
        (bool hasOverride, uint256 value) = _price(PHASE, _data(proof));
        require(hasOverride && value == 100, "sorted sibling proof");
        proof.proof[0] = keccak256("changed-sibling");
        _assertInvalidProof(_data(proof), RECIPIENT);
    }

    function testAuthenticatedZeroAndOverCeilingCapsRejected() public {
        for (uint256 i; i < 2; ++i) {
            bytes32 phase = keccak256(abi.encode("invalid-cap", i));
            IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(i == 0 ? 0 : 4, true, 100);
            _one(
                phase,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                _leaf(address(manager), phase, PRICE, RECIPIENT, proof)
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE, RECIPIENT
                )
            );
            _price(phase, _data(proof));
        }
    }

    function testFalseFlagWithAuthenticatedNonzeroPriceRejected() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, false, 100);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistPrice.selector, PRICE
            )
        );
        _price(PHASE, _data(proof));
    }

    function testExactGroupAndSingleTokenProofCountsRequired() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(2, true, 100);
        _one(
            PHASE,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            _leaf(address(manager), PHASE, PRICE, RECIPIENT, proof)
        );
        for (uint256 length; length <= 2; length += 2) {
            IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
                new IStreamMintCounterPolicy.AllowlistProof[][](length);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintSaleAllowlist.SaleAllowlistProofCountMismatch.selector, length, 1
                )
            );
            _price(PHASE, abi.encode(groups));
            groups = new IStreamMintCounterPolicy.AllowlistProof[][](1);
            groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](length);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintSaleAllowlist.SaleAllowlistProofCountMismatch.selector, length, 1
                )
            );
            _price(PHASE, abi.encode(groups));
        }
        vm.expectRevert();
        _price(PHASE, hex"01");
    }

    function testZeroMissingAndStaticPriceCounterRejected() public {
        _one(PHASE, IStreamMintManager.CounterKeyMode.PAYER, 0);
        bytes32[3] memory rejected = [bytes32(0), OTHER, PRICE];
        for (uint256 i; i < rejected.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintSaleAllowlist.InvalidSaleAllowlistPolicy.selector, rejected[i]
                )
            );
            reader.validate(address(manager), PHASE, rejected[i]);
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistPolicy.selector, PRICE
            )
        );
        reader.validate(address(manager), keccak256("missing-phase"), PRICE);
    }

    function _multiple(bool secondPriced) private returns (bytes memory) {
        IStreamMintCounterPolicy.AllowlistProof memory first = _proof(2, true, 100);
        IStreamMintCounterPolicy.AllowlistProof memory second =
            _proof(3, secondPriced, secondPriced ? 100 : 0);
        bytes32[] memory ids = new bytes32[](3);
        ids[0] = STATIC;
        ids[1] = PRICE;
        ids[2] = OTHER;
        IStreamMintManager.CounterKeyMode[] memory keys = new IStreamMintManager.CounterKeyMode[](3);
        keys[0] = IStreamMintManager.CounterKeyMode.CONSTANT;
        keys[1] = IStreamMintManager.CounterKeyMode.PAYER;
        keys[2] = IStreamMintManager.CounterKeyMode.RECIPIENT;
        bytes32[] memory roots = new bytes32[](3);
        roots[1] = _leaf(address(manager), PHASE, PRICE, PAYER, first);
        roots[2] = _leaf(address(manager), PHASE, OTHER, RECIPIENT, second);
        _configure(PHASE, ids, keys, roots);
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](2);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[0][0] = first;
        groups[1] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[1][0] = second;
        return abi.encode(groups);
    }

    function testAllMerkleGroupsVerifiedAlongsideStaticCounter() public {
        bytes memory data = _multiple(false);
        (bool hasOverride, uint256 value) = _price(PHASE, data);
        require(hasOverride && value == 100, "explicit counter among caps");
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            abi.decode(data, (IStreamMintCounterPolicy.AllowlistProof[][]));
        groups[1][0].maxCount = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, OTHER, RECIPIENT
            )
        );
        _price(PHASE, abi.encode(groups));
    }

    function testSecondPricedCounterRejectedEvenWithSamePrice() public {
        bytes memory data = _multiple(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.AmbiguousSaleAllowlistPrice.selector, PRICE, OTHER
            )
        );
        _price(PHASE, data);
    }

    function testMaximumCounterPolicyWithLastCounterSelected() public {
        uint256 count = manager.MAX_PHASE_COUNTERS();
        bytes32[] memory ids = new bytes32[](count);
        IStreamMintManager.CounterKeyMode[] memory keys =
            new IStreamMintManager.CounterKeyMode[](count);
        bytes32[] memory roots = new bytes32[](count);
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](count);
        for (uint256 i; i < count; ++i) {
            bool selected = i == count - 1;
            ids[i] = selected ? PRICE : keccak256(abi.encode("counter", i));
            keys[i] = i % 2 == 0
                ? IStreamMintManager.CounterKeyMode.PAYER
                : IStreamMintManager.CounterKeyMode.RECIPIENT;
            groups[i] = new IStreamMintCounterPolicy.AllowlistProof[](1);
            groups[i][0] = _proof(3, selected, selected ? 100 : 0);
            roots[i] = _leaf(
                address(manager), PHASE, ids[i], i % 2 == 0 ? PAYER : RECIPIENT, groups[i][0]
            );
        }
        _configure(PHASE, ids, keys, roots);
        (bool hasOverride, uint256 value) = _price(PHASE, abi.encode(groups));
        require(hasOverride && value == 100, "full counter policy selection");
    }
}
