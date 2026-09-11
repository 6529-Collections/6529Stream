// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";

/// @notice Official threshold Safes act as artist, buyer, NFT owner, beneficiary and governor.
/// @dev Uses the actual current protocol topology; only the external entropy service is a double.
contract StreamCurrentSafeTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 1);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 2);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 10 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testSafeArtistBuyerCustodyApprovalTransferAndRevenueRelease() public {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(buyerSafe),
                recipient: address(buyerSafe),
                artist: address(artistSafe),
                profileId: profile,
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("Safe current artwork"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("Safe current mint"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "Safe purchase execution"
        );
        uint256 tokenId = core.lastAllocatedTokenId();
        require(
            core.ownerOf(tokenId) == address(buyerSafe) && core.collectionMintedEver(1) == 1,
            "Safe NFT custody"
        );
        require(
            wallet.balance == a.price && sale.authorizationUsed(address(artistSafe), a.nonce),
            "Safe paid mint accounting"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("Safe mint entropy"));
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && seed != bytes32(0), "Safe token entropy finalized");
        require(
            keccak256(bytes(core.tokenURI(tokenId)))
                == keccak256(bytes(router.tokenURI(address(core), tokenId))),
            "Safe token uses actual metadata router"
        );
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(core),
                0,
                abi.encodeWithSignature("setApprovalForAll(address,bool)", SECOND_OWNER, true),
                0
            ),
            "Safe operator approval"
        );
        require(core.isApprovedForAll(address(buyerSafe), SECOND_OWNER), "Safe approval result");
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(core),
                0,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256,bytes)",
                    address(buyerSafe),
                    address(artistSafe),
                    tokenId,
                    bytes("Safe custody")
                ),
                0
            ),
            "Safe NFT transfer"
        );
        require(core.ownerOf(tokenId) == address(artistSafe), "recipient Safe received NFT");
        require(
            executeSafe(
                artistSafe,
                keys,
                wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(artistSafe), payable(address(artistSafe)))
                ),
                0
            ),
            "Safe release execution"
        );
        require(
            address(artistSafe).balance == 0.009 ether && wallet.balance == 0.001 ether,
            "Safe revenue balance"
        );
    }

    function testSafeGovernorSchedulesAndExecutesActualFactoryGasRaise() public {
        (address previous, bytes32 previousHash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(buyerSafe), address(buyerSafe).codehash)
        );
        GovernanceActionRequest memory request = _request(address(executor), data);
        request.actionClass = 3;
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        request.oldValueHash = _rootState(previous, previousHash, revision);
        request.newValueHash =
            _rootState(address(buyerSafe), address(buyerSafe).codehash, revision + 1);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        (address governor,,) = executor.governanceRootState();
        require(governor == address(buyerSafe), "actual Safe governor");
        bytes32 id = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
        (uint256 value, uint256 floor, uint8 failureClass, uint64 gasRevision) =
            factory.gasParameterInfo(id);
        require(value != 0, "registered verification budget");
        data = abi.encodeCall(factory.raiseGasParameter, (id, value * 2));
        // A Safe owner has no direct host authority; only the actual Executor may mutate the value.
        vm.prank(address(buyerSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(buyerSafe)
            )
        );
        factory.raiseGasParameter(id, value * 2);
        request = _request(address(factory), data);
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(factory), id
            )
        );
        request.oldValueHash = _gasState(request.scopeHash, value, floor, failureClass, gasRevision);
        request.newValueHash =
            _gasState(request.scopeHash, value * 2, floor, failureClass, gasRevision + 1);
        vm.recordLogs();
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.scheduleGovernanceAction, (request)),
                0
            ),
            "Safe governance schedule"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 actionId;
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) actionId = logs[i].topics[1];
        }
        require(actionId != bytes32(0), "scheduled action event");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                actionId,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(actionId, data);
        require(factory.gasParameter(id) == value, "timelock preserved");
        vm.warp(request.notBefore);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(executor.executeGovernanceAction, (actionId, data)),
                0
            ),
            "Safe governance execution"
        );
        require(factory.gasParameter(id) == value * 2, "real governed host updated");
    }

    function _request(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceActionRequest(
            1,
            target,
            0,
            selector,
            data,
            bytes32(0),
            bytes32(0),
            bytes32(0),
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("Safe governance test"),
            "urn:6529stream:fixture:safe-governance",
            DEPLOYMENT_HASH
        );
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _gasState(
        bytes32 scope,
        uint256 value,
        uint256 floor,
        uint8 failureClass,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                value,
                floor,
                failureClass,
                revision
            )
        );
    }
}
