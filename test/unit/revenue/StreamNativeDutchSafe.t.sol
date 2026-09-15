// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/DutchSaleTestBase.sol";

contract StreamNativeDutchSafeTest is DutchSaleTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safes() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7501);
    }

    function _exec(uint256 value, bytes memory data) private {
        _execFor(safe, value, data);
    }

    function _execFor(OfficialSafe account, uint256 value, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.recordLogs();
        require(
            executeSafe(account, keys, address(dutchSale), value, data, 0), "actual Safe execution"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1 && account.nonce() == nonce + 1, "actual Safe success and nonce");
    }

    function testActualSafeThresholdSignsPaysReceivesNFTAndPullsExcess() public {
        _safes();
        artists.accept(address(safe));
        vm.deal(address(safe), 1500);
        IStreamNativeDutchSale.DutchPurchaseData memory d =
            _dutchData(1, address(safe), address(safe));
        d.authorization.artist = address(safe);
        bytes32 digest = dutchSale.authorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature = safeThresholdSignature(keys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchSignatureInvalid.selector, address(safe)
            )
        );
        vm.prank(address(safe));
        dutchSale.purchase{ value: 1500 }(d);
        require(
            safe.nonce() == 0 && address(safe).balance == 1500 && wallet.balance == 0,
            "raw digest not Safe authorization"
        );
        d.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        _exec(1500, abi.encodeCall(IStreamNativeDutchSale.purchase, (d)));
        require(
            refundManager.ownerOf(1) == address(safe) && wallet.balance == 1000
                && refundEntropy.revealFeeEscrow(1) == 100
                && dutchSale.refundableBalance(dutchId, address(safe)) == 400,
            "actual Safe custody and payment"
        );
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.claimRefund, (dutchId, address(safe))));
        require(
            address(safe).balance == 400 && dutchSale.refundLiability() == 0,
            "actual native payout into Safe"
        );
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.eip712Domain, ()));
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.currentPrice, (dutchId)));
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.cancelAuthorization, (bytes32(uint256(99)))));
        require(
            dutchSale.authorizationUsed(address(safe), bytes32(uint256(99))),
            "Safe caller cancellation"
        );
    }

    function _read(bytes memory data) private {
        (bool firstOk, bytes memory first) = address(dutchSale).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory safeResult) = address(dutchSale).staticcall(data);
        require(
            firstOk && safeOk && keccak256(first) == keccak256(safeResult), "Safe read value parity"
        );
        _exec(0, data);
    }

    function attemptSafe(bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(safe, keys, address(dutchSale), 0, data, 0), "Safe execution");
    }

    function _reject(bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory out) = address(dutchSale).call(data);
        require(!ok && keccak256(out) == keccak256(expected), "exact target error from Safe caller");
        uint256 nonce = safe.nonce();
        (ok, out) = address(this).call(abi.encodeCall(this.attemptSafe, (data)));
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe rejects and restores nonce"
        );
    }

    function testActualSafeEveryReadSelectorAndCorrectOwnerGuardianAndGovernanceBoundaries()
        public
    {
        _safes();
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        string[35] memory names = [
            "FAILURE_CLASS_FAIL_CLOSED_PRECHECK()",
            "FAILURE_CLASS_FORWARDING_CAP()",
            "FAILURE_CLASS_MIN_GAS_GATE()",
            "FAILURE_CLASS_NONE()",
            "GAS_PARAMETER_SCHEMA_VERSION()",
            "artistRegistry()",
            "artistRegistryCodeHash()",
            "assetPolicyRegistry()",
            "assetRegistryCodeHash()",
            "core()",
            "coreCodeHash()",
            "eip712Domain()",
            "entropyCodeHash()",
            "entropyCoordinator()",
            "factoryCodeHash()",
            "gasParameterIds()",
            "governanceAuthority()",
            "mintManager()",
            "mintManagerCodeHash()",
            "moduleRegistry()",
            "moduleRegistryCodeHash()",
            "nextSaleNonce()",
            "owner()",
            "paused()",
            "platformSigner()",
            "primarySaleSettlement()",
            "refundLiability()",
            "resolverCodeHash()",
            "revenueResolver()",
            "roleRegistry()",
            "roleRegistryCodeHash()",
            "settlementCodeHash()",
            "splitFactory()",
            "streamModuleInterfaceId()",
            "streamModuleType()"
        ];
        for (uint256 i; i < names.length; ++i) {
            _read(abi.encodeWithSignature(names[i]));
        }
        _read(abi.encodeCall(IStreamNativeDutchSale.authorizationDigest, (d.authorization)));
        _read(
            abi.encodeWithSignature(
                "authorizationUsed(address,bytes32)", address(safe), bytes32(uint256(1))
            )
        );
        _read(abi.encodeCall(IStreamNativeDutchSale.currentPrice, (dutchId)));
        _read(abi.encodeWithSignature("executionIdByNonce(bytes32,uint256)", dutchId, uint256(1)));
        _read(abi.encodeWithSignature("executionStatus(bytes32)", bytes32(uint256(1))));
        bytes32 parameter = keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameter, (parameter)));
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (parameter)));
        _read(abi.encodeCall(IStreamNativeSaleBinding.nativeSaleLifecycleBinding, (dutchId)));
        _read(abi.encodeWithSignature("refundCredit(address)", address(safe)));
        _read(abi.encodeCall(IStreamNativeDutchSale.refundableBalance, (dutchId, address(safe))));
        _read(abi.encodeCall(IStreamArtistSaleFacts.saleConsentFacts, (dutchId)));
        _read(abi.encodeCall(IStreamNativeDutchSale.saleIdFor, (uint256(1), PHASE, uint256(1))));
        _read(abi.encodeCall(IStreamNativeDutchSale.saleRecord, (dutchId)));
        _read(abi.encodeCall(IERC165.supportsInterface, (type(IStreamNativeDutchSale).interfaceId)));
        _reject(
            abi.encodeCall(IStreamNativeDutchSale.closeSale, (dutchId)),
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        _reject(
            abi.encodeCall(IStreamNativeDutchSale.pauseAdapter, (bytes32(uint256(1)))),
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchRoleNotAuthorized.selector,
                keccak256("ROLE_PAUSE_GUARDIAN"),
                address(safe)
            )
        );
        _reject(
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (parameter, uint256(400000))),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        OfficialSafe unpauseSafe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7502);
        _grantRefundRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(safe));
        _grantRefundRole(keccak256("ROLE_UNPAUSE"), address(unpauseSafe));
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.pauseAdapter, (bytes32(uint256(1)))));
        _reject(
            abi.encodeCall(IStreamNativeDutchSale.unpauseAdapter, (bytes32(uint256(2)))),
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchRoleNotAuthorized.selector,
                keccak256("ROLE_UNPAUSE"),
                address(safe)
            )
        );
        _execFor(
            unpauseSafe,
            0,
            abi.encodeCall(IStreamNativeDutchSale.unpauseAdapter, (bytes32(uint256(2))))
        );
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.pauseSale, (dutchId, bytes32(uint256(3)))));
        _execFor(
            unpauseSafe,
            0,
            abi.encodeCall(IStreamNativeDutchSale.unpauseSale, (dutchId, bytes32(uint256(4))))
        );
        dutchSale.transferOwnership(address(safe));
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.registerDutchSale, (_dutchConfig())));
        _exec(0, abi.encodeCall(IStreamNativeDutchSale.closeSale, (dutchId)));
        _exec(0, abi.encodeCall(StreamNativeDutchSale.transferOwnership, (address(this))));
        dutchSale.transferOwnership(address(safe));
        _exec(0, abi.encodeCall(StreamNativeDutchSale.renounceOwnership, ()));
        require(
            dutchSale.owner() == address(0) && !dutchSale.paused()
                && dutchSale.saleRecord(dutchId).closed,
            "actual Safe roles and ownership transitions"
        );
    }
}
