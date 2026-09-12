// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativePricePrograms.t.sol";

interface PriceProgramChainVm {
    function getChainId() external view returns (uint256);
}

contract StreamNativePriceProgramsSafeTest is NativePriceProgramTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 988);
        vm.deal(address(safe), 1 ether);
    }

    function _safeExecution(bytes32 id, uint256 number, uint256 chosen, uint256 signedPrice)
        private
        returns (IStreamNativePricePrograms.PriceProgramExecution memory e)
    {
        e = _execution(id, number, chosen, signedPrice);
        e.authorization.payer = address(safe);
        e.authorization.executor = address(safe);
        e.authorization.recipient = address(safe);
        bytes32 digest = nativeSale.priceProgramAuthorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = artist == address(safe)
            ? safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)))
            : _sign(ARTIST_KEY, digest);
    }

    function testActualSafeAllPriceProgramSelectorsAndTerminalOwnerClose() public {
        _safe();
        IStreamNativePricePrograms.PriceProgramConfig memory cfg = _config(1, 100, 100, 0);
        cfg.closeRule = 2;
        cfg.endsAt = 0;
        bytes32 id = nativeSale.priceProgramIdFor(1, PHASE, 1, nativeSale.nextSaleNonce());
        nativeSale.transferOwnership(address(safe));
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.registerPriceProgram, (cfg)));
        IStreamNativePricePrograms.PriceProgramExecution memory e = _safeExecution(id, 1, 100, 100);
        _read(address(nativeSale), abi.encodeCall(nativeSale.priceProgramRecord, (id)));
        _read(
            address(nativeSale),
            abi.encodeCall(nativeSale.priceProgramIdFor, (uint256(1), PHASE, uint8(1), uint256(2)))
        );
        _read(
            address(nativeSale),
            abi.encodeCall(nativeSale.priceProgramAuthorizationDigest, (e.authorization))
        );
        _read(address(nativeSale), abi.encodeCall(nativeSale.previewPriceProgram, (e)));
        _read(
            address(nativeSale),
            abi.encodeCall(
                nativeSale.supportsInterface, (type(IStreamNativePricePrograms).interfaceId)
            )
        );
        _exec(address(nativeSale), 100, abi.encodeCall(nativeSale.executePriceProgram, (e)));
        require(
            manager.ownerOf(1) == address(safe) && recorder.totalOfficialSettled(address(0)) == 100,
            "Safe pays and receives"
        );
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.closePriceProgram, (id)));
        require(nativeSale.priceProgramRecord(id).closed, "Safe terminal close");
    }

    function testActualSafeFreeClaimAndWrappedArtistPWYWTemplatePayout() public {
        _safe();
        _template(address(safe));
        artist = address(safe);
        artists.accept(artist);
        bytes32 freeId = _program(12, 0, 0, 2);
        IStreamNativePricePrograms.PriceProgramExecution memory free =
            _safeExecution(freeId, 1, 0, 0);
        bytes32 digest = nativeSale.priceProgramAuthorizationDigest(free.authorization);
        free.artistSignature = safeThresholdSignature(keys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector, artist
            )
        );
        nativeSale.previewPriceProgram(free);
        free.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.executePriceProgram, (free)));
        require(
            manager.ownerOf(1) == address(safe) && address(safe).balance == 1 ether
                && recorder.totalOfficialSettled(address(0)) == 0,
            "Safe free custody no payment"
        );
        bytes32 paidId = _program(13, 100, 1000, 2);
        IStreamNativePricePrograms.PriceProgramExecution memory paid =
            _safeExecution(paidId, 2, 777, 100);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(resolver, 1);
        _exec(address(nativeSale), 777, abi.encodeCall(nativeSale.executePriceProgram, (paid)));
        require(
            manager.ownerOf(2) == address(safe) && address(safe).balance == 1 ether - 777
                && recorder.totalOfficialSettled(address(0)) == 777,
            "Safe exact chosen amount"
        );
        escrow.flushEscrow(CLASS, rights.profileId, rights.wallet, address(0));
        uint256 amount = IStreamSplitWallet(rights.wallet).releasable(address(0), address(safe));
        require(amount == 699, "actual split rounding");
        _exec(
            rights.wallet,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(0), address(safe), payable(address(safe)))
            )
        );
        require(address(safe).balance == 1 ether - 777 + 699, "explicit template payout into Safe");
    }

    function testNewDomainAndSignedMinimumDriftRejectBeforeSafePayment() public {
        _safe();
        bytes32 id = _program(13, 0, 1000, 3);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _safeExecution(id, 1, 777, 200);
        e.authorization.unitPrice = 201;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewPriceProgram(e);
        e.authorization.unitPrice = 200;
        // An external cheat read is not optimizer-cached like transaction-constant CHAINID.
        uint256 chain = PriceProgramChainVm(address(vm)).getChainId();
        vm.chainId(chain + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewPriceProgram(e);
        vm.chainId(chain);
        require(PriceProgramChainVm(address(vm)).getChainId() == chain, "restored chain");
        StreamNativeFixedPriceSaleAdapter other = new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
        );
        bytes32 foreign = other.priceProgramAuthorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, foreign);
        e.artistSignature = _sign(ARTIST_KEY, foreign);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewPriceProgram(e);
        e = _safeExecution(id, 1, 777, 200);
        _exec(address(nativeSale), 777, abi.encodeCall(nativeSale.executePriceProgram, (e)));
        require(recorder.totalOfficialSettled(address(0)) == 777, "valid exact-domain control");
    }

    function _exec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(safe, keys, target, value, data, 0) && safe.nonce() == nonce + 1,
            "Safe execution nonce"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(count == 1, "real Safe ExecutionSuccess");
    }

    function _read(address target, bytes memory data) private {
        (bool ok, bytes memory expected) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(data);
        require(ok && safeOk && keccak256(actual) == keccak256(expected), "Safe view parity");
        _exec(target, 0, data);
    }
}
