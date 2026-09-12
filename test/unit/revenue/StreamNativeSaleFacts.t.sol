// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

contract StreamNativeSaleFactsTest is NativeSettlementTestBase {
    function testExactRegisteredFixedAndPriceFactsWithoutMutation() public {
        (uint256 collection, bytes32 hash) = nativeSale.saleConsentFacts(nativeId);
        require(
            collection == 1 && hash == nativeSale.saleRecord(nativeId).configHash, "fixed facts"
        );
        IStreamNativePricePrograms.PriceProgramConfig memory config =
            IStreamNativePricePrograms.PriceProgramConfig(
                1, PHASE, 12, 0, 0, 1, 0, 0, 2, manager.POLICY(), 0
            );
        bytes32 id = nativeSale.registerPriceProgram(config);
        (collection, hash) = nativeSale.saleConsentFacts(id);
        require(
            collection == 1 && hash == nativeSale.priceProgramRecord(id).configHash, "free facts"
        );
        uint256 nonce = nativeSale.nextSaleNonce();
        nativeSale.setPaused(true);
        nativeSale.closePriceProgram(id);
        (uint256 retainedCollection, bytes32 retainedHash) = nativeSale.saleConsentFacts(id);
        require(retainedCollection == collection && retainedHash == hash, "immutable closed facts");
        require(
            nativeSale.nextSaleNonce() == nonce && manager.nonce() == 0, "read grants no execution"
        );
        require(
            nativeSale.supportsInterface(type(IStreamArtistSaleFacts).interfaceId), "advertised"
        );
        require(!nativeSale.supportsInterface(0xffffffff), "invalid interface rejected");
        require(
            nativeSale.streamModuleType() == keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            "canonical type"
        );
        require(
            nativeSale.streamModuleInterfaceId() == type(IStreamNativeSaleBinding).interfaceId,
            "canonical interface"
        );
    }

    function testMissingFactsRevertAndActualSafeReadsExactTwoWords() public {
        bytes32 missing = keccak256("unregistered sale");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistSaleFacts.SaleConsentFactsUnavailable.selector, missing
            )
        );
        nativeSale.saleConsentFacts(missing);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 987);
        bytes memory data = abi.encodeCall(IStreamArtistSaleFacts.saleConsentFacts, (nativeId));
        (bool ok, bytes memory normal) = address(nativeSale).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory fromSafe) = address(nativeSale).staticcall(data);
        require(
            ok && safeOk && normal.length == 64 && keccak256(normal) == keccak256(fromSafe),
            "exact Safe read"
        );
        vm.recordLogs();
        require(executeSafe(safe, keys, address(nativeSale), 0, data, 0), "actual Safe execution");
        require(safe.nonce() == 1 && manager.nonce() == 0, "only Safe nonce changes");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1, "one actual ExecutionSuccess");
        bytes memory typeData =
            abi.encodeCall(StreamNativeFixedPriceSaleAdapter.streamModuleType, ());
        bytes memory interfaceData =
            abi.encodeCall(StreamNativeFixedPriceSaleAdapter.streamModuleInterfaceId, ());
        vm.prank(address(safe));
        (bool typeOk, bytes memory typeResult) = address(nativeSale).staticcall(typeData);
        vm.prank(address(safe));
        (bool interfaceOk, bytes memory interfaceResult) =
            address(nativeSale).staticcall(interfaceData);
        require(
            typeOk && typeResult.length == 32
                && abi.decode(typeResult, (bytes32)) == keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            "Safe exact type"
        );
        require(
            interfaceOk && interfaceResult.length == 32
                && keccak256(interfaceResult)
                    == keccak256(abi.encode(type(IStreamNativeSaleBinding).interfaceId)),
            "Safe exact interface"
        );
        require(executeSafe(safe, keys, address(nativeSale), 0, typeData, 0), "Safe type execution");
        require(
            executeSafe(safe, keys, address(nativeSale), 0, interfaceData, 0),
            "Safe interface execution"
        );
        require(safe.nonce() == 3 && manager.nonce() == 0, "three read executions only");
    }
}
