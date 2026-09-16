// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

contract StreamNativeSettlementSafeTest is NativeSettlementTestBase {
    OfficialSafe private safe;
    uint256[] private keys;
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 766);
        vm.deal(address(safe), 1 ether);
    }

    function testActualSafePayablePayerTemplatePayeeRecipientAndArtistSignature() public {
        _safe();
        _template(address(safe));
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(address(safe), address(safe), 1);
        artist = address(safe);
        artists.accept(artist);
        e.authorization.artist = artist;
        bytes32 digest = nativeSale.authorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = safeThresholdSignature(keys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector, artist
            )
        );
        nativeSale.previewExecution(e);
        e.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c =
            nativeSale.previewExecution(e);
        _exec(address(nativeSale), 1000, abi.encodeCall(nativeSale.purchase, (e)));
        require(
            manager.ownerOf(1) == address(safe) && address(safe).balance == 1 ether - 1000
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "actual Safe payer and NFT custody"
        );
        escrow.flushEscrow(CLASS, c.rights.profileId, c.rights.wallet, address(0));
        _exec(
            c.rights.wallet,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(0), address(safe), payable(address(safe)))
            )
        );
        require(
            address(safe).balance == 1 ether - 100
                && IStreamSplitWallet(c.rights.wallet).releasable(address(0), address(safe)) == 0,
            "actual native artist payout into Safe"
        );
    }

    function testActualSafeOwnerAndPermissionlessMutationSelectors() public {
        _safe();
        nativeSale.transferOwnership(address(safe));
        IStreamNativeFixedPriceSaleAdapter.SaleConfig memory cfg =
        nativeSale.saleRecord(nativeId).config;
        bytes32 nextId = nativeSale.saleIdFor(1, PHASE, nativeSale.nextSaleNonce());
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.registerSale, (cfg)));
        require(nativeSale.saleRecord(nextId).saleNonce == 2, "Safe registers sale");
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.cancelSale, (nextId)));
        require(nativeSale.saleRecord(nextId).cancelled, "Safe cancels sale");
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.setPaused, (true)));
        require(nativeSale.paused(), "Safe pauses");
        _exec(address(nativeSale), 0, abi.encodeCall(nativeSale.setPaused, (false)));
        _exec(
            address(nativeSale),
            0,
            abi.encodeCall(nativeSale.cancelAuthorization, (bytes32(uint256(54))))
        );
        require(
            nativeSale.authorizationUsed(address(safe), bytes32(uint256(54))),
            "Safe own signer-scoped cancellation"
        );
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(address(safe), address(safe), 1);
        _reject(
            address(recorder),
            1000,
            abi.encodeCall(
                IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter, (c)
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        _exec(address(nativeSale), 1000, abi.encodeCall(nativeSale.purchase, (e)));
        _exec(
            address(nativeSale),
            0,
            abi.encodeWithSignature("transferOwnership(address)", address(this))
        );
        require(nativeSale.owner() == address(this), "Safe transfers owner");
        nativeSale.transferOwnership(address(safe));
        _exec(address(nativeSale), 0, abi.encodeWithSignature("renounceOwnership()"));
        require(nativeSale.owner() == address(0), "Safe renounces owner");
    }

    function testActualSafeEveryNativeReadAndLinkedHelperSelector() public {
        _safe();
        string[21] memory names = [
            "SALE_AUTHORIZATION_TYPEHASH()",
            "mintManager()",
            "mintManagerCodeHash()",
            "primarySaleSettlement()",
            "settlementCodeHash()",
            "platformSigner()",
            "artistRegistry()",
            "artistRegistryCodeHash()",
            "nextSaleNonce()",
            "paused()",
            "core()",
            "moduleRegistry()",
            "revenueResolver()",
            "splitFactory()",
            "assetPolicyRegistry()",
            "coreCodeHash()",
            "moduleRegistryCodeHash()",
            "resolverCodeHash()",
            "factoryCodeHash()",
            "assetRegistryCodeHash()",
            "owner()"
        ];
        for (uint256 i; i < names.length; ++i) {
            _read(address(nativeSale), abi.encodeWithSignature(names[i]));
        }
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(address(safe), address(safe), 1);
        _read(address(nativeSale), abi.encodeCall(nativeSale.saleRecord, (nativeId)));
        _read(
            address(nativeSale),
            abi.encodeCall(nativeSale.saleIdFor, (uint256(1), PHASE, uint256(1)))
        );
        _read(
            address(nativeSale), abi.encodeCall(nativeSale.authorizationDigest, (e.authorization))
        );
        _read(address(nativeSale), abi.encodeCall(nativeSale.previewExecution, (e)));
        _read(
            address(nativeSale), abi.encodeCall(nativeSale.nativeSaleLifecycleBinding, (nativeId))
        );
        _read(
            address(nativeSale),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamNativeSaleBinding).interfaceId
            )
        );
        _read(
            address(nativeSale),
            abi.encodeWithSignature(
                "authorizationUsed(address,bytes32)", artist, bytes32(uint256(1))
            )
        );
        _read(
            address(nativeSale),
            abi.encodeWithSignature("executionIdByNonce(bytes32,uint256)", nativeId, uint256(1))
        );
        _read(
            address(nativeSale),
            abi.encodeWithSignature("executionStatus(bytes32)", c.executionBinding.executionId)
        );
        _read(
            address(recorder),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamNativePrimarySaleSettlement).interfaceId
            )
        );
        _read(
            address(StreamNativeSettlementAdmission),
            abi.encodeWithSelector(
                StreamNativeSettlementAdmission.capture.selector,
                address(registry),
                address(nativeSale)
            )
        );
        _read(
            address(StreamNativeSettlementAdmission),
            abi.encodeWithSelector(
                StreamNativeSettlementAdmission.requireAdmission.selector, address(registry), c
            )
        );
        StreamSaleTemplate.Selection memory selected =
            StreamNativeSettlementSupport.rights(resolver, 1);
        _read(
            address(StreamNativeSettlementSupport),
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.rights.selector, resolver, uint256(1)
            )
        );
        _read(
            address(StreamNativeSettlementSupport),
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.requireCurrent.selector,
                resolver,
                uint256(1),
                selected
            )
        );
        _read(
            address(StreamNativeSettlementSupport),
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.gasParameter.selector,
                factory,
                address(factory).codehash,
                keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT")
            )
        );
        _read(
            address(StreamNativeSettlementSupport),
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.validSignature.selector,
                artist,
                nativeSale.authorizationDigest(e.authorization),
                e.artistSignature,
                uint256(200_000)
            )
        );
        _reject(
            address(StreamNativeSettlementSupport),
            0,
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.fundNative.selector,
                escrow,
                address(escrow).codehash,
                selected,
                uint256(1000),
                uint256(500_000)
            ),
            ""
        );
    }

    function _exec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(safe, keys, target, value, data, 0) && safe.nonce() == nonce + 1,
            "actual Safe execution/nonce"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(count == 1, "actual Safe ExecutionSuccess");
        emit SafeSelectorObserved(target, bytes4(data), 1);
    }

    function _read(address target, bytes memory data) private {
        (bool ok, bytes memory expected) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(data);
        require(
            ok && safeOk && keccak256(actual) == keccak256(expected), "Safe return-value parity"
        );
        _exec(target, 0, data);
    }

    function _reject(address target, uint256 value, bytes memory data, bytes memory expected)
        private
    {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = target.call{ value: value }(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact direct Safe rejection");
        uint256 nonce = safe.nonce();
        (ok, reason) = address(this).call(abi.encodeCall(this.attemptSafe, (target, value, data)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe failure rolls back"
        );
        emit SafeSelectorObserved(target, bytes4(data), 2);
    }

    function attemptSafe(address target, uint256 value, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(safe, keys, target, value, data, 0), "Safe returned false");
    }
}
