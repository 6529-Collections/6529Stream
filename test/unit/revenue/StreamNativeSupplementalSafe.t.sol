// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSupplementalTestBase.sol";

contract StreamNativeSupplementalSafeTest is NativeSupplementalTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 8701);
    }

    function _exec(address target, uint256 value, bytes memory data) private {
        uint256 before = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, target, value, data, 0), "actual Safe success");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1 && safe.nonce() == before + 1, "Safe event and nonce");
    }

    function _read(address target, bytes memory data) private {
        (bool ok, bytes memory ordinary) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory fromSafe) = target.staticcall(data);
        require(ok && safeOk && keccak256(ordinary) == keccak256(fromSafe), "read parity");
        _exec(target, 0, data);
    }

    function attempt(address target, bytes calldata data) external {
        require(msg.sender == address(this));
        require(executeSafe(safe, keys, target, 0, data, 0));
    }

    function _reject(address target, bytes memory data, bytes memory reason) private {
        vm.prank(address(safe));
        (bool ok, bytes memory out) = target.call(data);
        require(!ok && keccak256(out) == keccak256(reason), "target exact rejection");
        uint256 nonce = safe.nonce();
        (ok, out) = address(this).call(abi.encodeCall(this.attempt, (target, data)));
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe failure and nonce rollback"
        );
    }

    function testActualSafeFloorPayerTokenCustodySupplementExecutorAndWalletPayout() external {
        _safe();
        payer = address(safe);
        vm.deal(payer, 5000);
        (profile, wallet) = _newProfile(payer, keccak256("Safe payout"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        IStreamMintManager.MintBatch memory batch = _batch(1);
        (StreamPrimarySettlementTypes.PrimaryRights memory rights, bytes32 policyHash) = _rights(0);
        _exec(
            address(clearing),
            1000,
            abi.encodeCall(clearing.floorAndMint, (batch, 1, rights, policyHash))
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(clearing),
                keccak256("clearing sale"),
                payer,
                uint256(1)
            )
        );
        (rights, policyHash) = _rights(1);
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c =
            clearing.candidate(id, rights, policyHash, payer);
        _exec(address(clearing), 2000, abi.encodeCall(clearing.supplement, (c)));
        require(
            supplementalManager.ownerOf(1) == payer && supplementalManager.nonce() == 1
                && payer.balance == 2000 && wallet.balance == 3000,
            "real Safe payable calls and custody"
        );
        _exec(
            wallet,
            0,
            abi.encodeCall(IStreamSplitWallet.release, (address(0), payer, payable(payer)))
        );
        require(payer.balance == 5000 && wallet.balance == 0, "native Safe payout");
        _read(
            address(recorder),
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamNativeSupplementalSettlement).interfaceId)
            )
        );
        _read(
            address(recorder),
            abi.encodeCall(recorder.supplementalPurchaseKey, (address(clearing), id))
        );
        _read(
            address(recorder),
            abi.encodeCall(recorder.supplementalFloorKey, (c.purchase.floorSettlementKey))
        );
        _read(
            address(recorder),
            abi.encodeCall(
                recorder.supplementalPurchaseConsumed,
                (recorder.supplementalPurchaseKey(address(clearing), id))
            )
        );
        _read(
            address(recorder),
            abi.encodeCall(
                recorder.supplementalFloorConsumed,
                (recorder.supplementalFloorKey(c.purchase.floorSettlementKey))
            )
        );
        _read(
            address(recorder),
            abi.encodeCall(IStreamNativeSupplementalSettlement.nativeSupplementalResult, (_key(c)))
        );
        _reject(
            address(recorder),
            abi.encodeCall(
                IStreamNativeSupplementalSettlement.settleNativeSupplementalRevenueFromAdapter, (c)
            ),
            abi.encodeWithSelector(
                IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement.selector
            )
        );
    }

    function testAllNewMutableLibraryDirectCallsRejectAndRecorderControlWorks() external {
        _safe();
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        StreamPrimarySettlementRights.Context memory rights = StreamPrimarySettlementRights.Context(
            resolver, factory, factory.splitWalletRuntimeCodeHash()
        );
        StreamSaleTemplate.Selection memory selection = StreamSaleTemplate.Selection(
            c.currentRights.profileId,
            c.currentRights.wallet,
            c.currentRights.templateId,
            c.currentRights.assignmentHash,
            c.currentRights.entriesHash
        );
        StreamNativeSupplementalExecution.Context memory x =
            StreamNativeSupplementalExecution.Context(
                rights, escrow, address(escrow).codehash, address(factory).codehash
            );
        _reject(
            address(StreamNativeSupplementalExecution),
            abi.encodeWithSelector(
                StreamNativeSupplementalExecution.fund.selector, x, c, _key(c), uint256(2000)
            ),
            ""
        );
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory common;
        _reject(
            address(StreamNativeSupplementalExecution),
            abi.encodeWithSelector(
                StreamNativeSupplementalExecution.emitResult.selector, c, result, common
            ),
            ""
        );
        _reject(
            address(StreamNativeSupplementalRights),
            abi.encodeWithSelector(
                StreamNativeSupplementalRights.materialize.selector,
                rights,
                uint256(1),
                uint256(1),
                selection
            ),
            ""
        );
        _reject(
            address(StreamNativePrimaryExecution),
            abi.encodeWithSelector(
                StreamNativePrimaryExecution.fund.selector,
                StreamNativePrimaryExecution.Context(
                    rights, escrow, address(escrow).codehash, address(factory).codehash
                ),
                uint256(1),
                uint256(2000),
                selection
            ),
            ""
        );
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory erc20;
        _reject(
            address(StreamPrimaryTokenRouting),
            abi.encodeWithSelector(
                StreamPrimaryTokenRouting.route.selector,
                StreamPrimaryTokenRouting.Context(rights, escrow, address(escrow).codehash),
                erc20,
                selection,
                uint256(500_000)
            ),
            ""
        );
        _submit(c);
        require(
            wallet.balance == 3000 && recorder.totalOfficialSettled(address(0)) == 3000,
            "compiler linked recorder path control"
        );
    }
}
