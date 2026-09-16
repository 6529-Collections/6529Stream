// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeRightsAuctionFixture.sol";

interface DefaultPreparedCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

contract DefaultPreparedArtist is NativeRightsAuctionArtist {
    address public lateWallet;
    constructor(address c, address m) NativeRightsAuctionArtist(c, m) { }

    function arm(address wallet_) external {
        lateWallet = wallet_;
    }

    function requireEconomicsConsent(uint256, bytes32, uint8 scope, uint256, bytes32)
        external
        view
        override
    {
        require(consent, "typed default economics");
        if (scope == 0) {
            require(lateWallet == address(0) || lateWallet.balance == 0, "late default consent");
        }
    }
}

/// @notice Actual current prepared default-PROFILE consumer; Artist/governance remain typed.
contract StreamCurrentPreparedDefaultProfileTest is NativeRightsAuctionFixture {
    DefaultPreparedArtist private defaultArtist;
    DefaultPreparedCalls private constant calls =
        DefaultPreparedCalls(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private defaultHash;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        defaultArtist = new DefaultPreparedArtist(address(core), address(manager));
        rightsArtist = defaultArtist;
        return defaultArtist;
    }
    bytes32 private constant RECEIPT = keccak256(
        "PreparedNativeRightsRevenueRecorded(bytes32,bytes32,bytes32,((address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),((uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),bytes32)"
    );

    function setUp() public override {
        super.setUp();
        defaultHash = resolver.setPrimaryProfileAssignment(CLASS, 0, 0, profile, 0);
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
    }

    function _selected() internal view override returns (StreamSaleTemplate.Selection memory) {
        return StreamDefaultPrimaryProfile.resolve(resolver, 1, 0);
    }

    function _original()
        internal
        view
        override
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        return StreamPreparedNativeRightsTypes.OriginalPolicy(4, defaultHash, 0);
    }

    function testPreparedDefaultProfileUsesActualTokenPolicyAndOriginalDefaultHashTwice() public {
        StreamSaleTemplate.Selection memory selected = _selected();
        for (uint256 n = 1; n <= 2; ++n) {
            bytes32 id = _createRights(_rightsConfig());
            _rightsBid(id, payer);
            _endRights(id);
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            require(
                token == n && core.ownerOf(token) == payer && wallet.balance == n * 1000
                    && manager.nextOperationNonce() == n,
                "actual prepared default payment"
            );
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                        && logs[i].topics[0] == RECEIPT
                ) {
                    ++count;
                    (
                        StreamPreparedNativeRightsTypes.Facts memory facts,
                        StreamPreparedNativeRightsTypes.Intent memory original,
                        bytes32 policy
                    ) = abi.decode(
                        logs[i].data,
                        (
                            StreamPreparedNativeRightsTypes.Facts,
                            StreamPreparedNativeRightsTypes.Intent,
                            bytes32
                        )
                    );
                    bytes32 factsHash = keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"),
                            block.chainid,
                            facts
                        )
                    );
                    require(
                        logs[i].data.length == 1376 && logs[i].topics[1] == key
                            && logs[i].topics[2]
                                == recorder.preparedNativeSaleKey(
                                    address(house),
                                    house.auction(id).saleId,
                                    house.auction(id).saleNonce
                                ) && logs[i].topics[3] == factsHash,
                        "full original event indexing"
                    );
                    require(
                        original.original.mode == 4
                            && original.original.assignmentHash == defaultHash
                            && original.original.templateId == 0
                            && keccak256(abi.encode(original.original))
                                == keccak256(abi.encode(facts.original))
                            && facts.mint.tokenId == token && policy == _policy(token, selected)
                            && policy != original.sale.originalPrimaryPolicyHash,
                        "scope0 source and actual token policy remain distinct"
                    );
                    require(
                        ledger.isManagerOperationRootUsed(
                                address(manager), facts.mint.operationRoot
                            )
                            && recorder.settlementResult(key).operationIdentityCommitment
                            == facts.mint.operationRoot
                            && recorder.preparedNativeRightsFactsHash(key) == factsHash,
                        "actual root and complete original result"
                    );
                }
            }
            require(count == 1, "one original complete default-mode receipt");
        }
    }

    function testDefaultModeCannotSkipConfiguredCollectionAndExactOriginalSettlementRetries()
        public
    {
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        _endRights(id);
        bytes memory original = abi.encodeCall(house.settle, (id));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        (bool ok,) = address(house).call(original);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && house.totalBuyerLiabilities() == 1100 && wallet.balance == 0,
            "configured identical profile still overrides default source"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        (ok,) = address(house).call(original);
        require(
            ok && core.ownerOf(1) == payer && wallet.balance == 1000,
            "exact original retry with restored selected source"
        );
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, profile, 0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.defaultToken, (uint256(1))));
        require(!ok, "actual token override cannot be bypassed");
    }

    function defaultToken(uint256 token) external view returns (bytes32) {
        return StreamDefaultPrimaryProfile.resolve(resolver, 1, token).assignmentHash;
    }

    function testDefaultPreparedSafePostWalletConsentFailureAndByteIdenticalRetry() public {
        bytes32 id = _createRights(_rightsConfig());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x16491;
        keys[1] = 0x16492;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 16491);
        vm.deal(address(safe), 1 ether);
        uint256 price = 1000 + entropy.fee();
        require(
            executeSafe(
                safe, keys, address(house), price, abi.encodeCall(house.bid, (id, address(safe))), 0
            ),
            "actual Safe default-mode bid"
        );
        _endRights(id);
        uint256 nonce = safe.nonce();
        bytes memory data = abi.encodeCall(house.settle, (id));
        bytes32 digest =
            safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory original = abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        require(wallet.balance == 0, "zero wallet fault baseline");
        defaultArtist.arm(wallet);
        calls.expectCall(wallet, 1000, bytes(""), 2);
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && wallet.balance == 0 && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0 && house.auction(id).winner.amount == 1000
                && recorder.totalOfficialSettled(address(0)) == 0,
            "post-payment failure rolls back mint and all payment"
        );
        defaultArtist.arm(address(0));
        bytes memory returned;
        (ok, returned) = address(safe).call(original);
        require(
            ok && abi.decode(returned, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe) && wallet.balance == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "identical full Safe transaction commits once"
        );
    }
}
