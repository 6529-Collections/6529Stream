// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

interface SigningDomainChainVm {
    function getChainId() external view returns (uint256);
}

/// @dev Actual sale consumers and threshold Safe; the existing fixture doubles Core/Manager/artist.
contract StreamSaleSigningDomainsTest is NativeSettlementTestBase {
    struct Domain {
        bytes1 fields;
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
        bytes32 salt;
        uint256[] extensions;
    }

    bytes32 private constant NATIVE_TYPE = keccak256(
        "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
    );
    bytes32 private constant UNIVERSAL_TYPE = keccak256(
        "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant PROGRAM_TYPE = keccak256(
        "NativePriceProgramAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)"
    );
    OfficialSafe private safe;
    uint256[] private keys;

    function testPublishedDomainsReconstructAllThreeExistingAuthorizationDigests() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory n,) =
            _nativeExecution(payer, payer, 101);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory u,) =
            _execution(payer, payer, payer, 102);
        IStreamNativePricePrograms.PriceProgramExecution memory p = _program(payer);
        require(
            nativeSale.authorizationDigest(n.authorization)
                == _digest(_nativeDomain(), _nativeMessage(n.authorization)),
            "native complete digest"
        );
        require(
            sale.authorizationDigest(u.authorization)
                == _digest(_universalDomain(), _universalMessage(u.authorization)),
            "universal complete digest"
        );
        require(
            nativeSale.priceProgramAuthorizationDigest(p.authorization)
                == _digest(_programDomain(), _programMessage(p.authorization)),
            "program complete digest"
        );
        require(_nativeDomain() != _programDomain(), "existing families remain distinct");
        require(
            nativeSale.supportsInterface(type(IERC5267).interfaceId), "native discovery capability"
        );
        require(
            sale.supportsInterface(type(IERC5267).interfaceId), "universal discovery capability"
        );
        require(
            nativeSale.supportsInterface(type(IStreamNativePriceProgramDomain).interfaceId),
            "program discovery capability"
        );
        require(
            nativeSale.supportsInterface(type(IStreamNativeFixedPriceSaleAdapter).interfaceId),
            "prior native interface"
        );
        require(
            nativeSale.supportsInterface(type(IStreamNativePricePrograms).interfaceId),
            "prior program interface"
        );
        require(
            sale.supportsInterface(type(IStreamUniversalFixedPriceSaleAdapter).interfaceId),
            "prior universal interface"
        );
    }

    function testActualSafeReadsAndFixedNativeMintFromPublishedDomain() public {
        _safe();
        _safeRead(address(nativeSale), IERC5267.eip712Domain.selector);
        _safeRead(
            address(nativeSale), IStreamNativePriceProgramDomain.priceProgramEip712Domain.selector
        );
        _safeRead(address(sale), IERC5267.eip712Domain.selector);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(address(safe), address(safe), 201);
        bytes32 digest = _digest(_nativeDomain(), _nativeMessage(e.authorization));
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
        _exec(address(nativeSale), 1000, abi.encodeCall(nativeSale.purchase, (e)));
        require(manager.ownerOf(1) == address(safe), "Safe receives actual fixture mint");
        require(recorder.totalOfficialSettled(address(0)) == 1000, "official native proceeds");
        require(address(safe).balance == 1 ether - 1000, "exact Safe payment");
    }

    function testPriceProgramRequiresItsPublishedFamilyThenSafePurchaseSucceeds() public {
        _safe();
        IStreamNativePricePrograms.PriceProgramExecution memory e = _program(address(safe));
        bytes32 message = _programMessage(e.authorization);
        bytes32 wrong = _digest(_nativeDomain(), message);
        e.platformSignature = _sign(PLATFORM_KEY, wrong);
        e.artistSignature = _sign(ARTIST_KEY, wrong);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewPriceProgram(e);
        require(
            !nativeSale.authorizationUsed(artist, e.authorization.nonce),
            "wrong family does not consume authorization"
        );
        require(address(safe).balance == 1 ether, "wrong family no payment");
        bytes32 correct = _digest(_programDomain(), message);
        e.platformSignature = _sign(PLATFORM_KEY, correct);
        e.artistSignature = _sign(ARTIST_KEY, correct);
        _exec(
            address(nativeSale),
            e.chosenUnitPrice,
            abi.encodeCall(nativeSale.executePriceProgram, (e))
        );
        require(manager.ownerOf(1) == address(safe), "program Safe custody");
        require(recorder.totalOfficialSettled(address(0)) == 333, "program exact proceeds");
        require(address(safe).balance == 1 ether - 333, "program exact Safe payment");
    }

    function testFuzzDiscoveryTracksChainAndVerifyingContract(uint64 chain, bytes32 nonce) public {
        uint256 original = SigningDomainChainVm(address(vm)).getChainId();
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory n,) =
            _nativeExecution(payer, payer, 301);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory u,) =
            _execution(payer, payer, payer, 302);
        IStreamNativePricePrograms.PriceProgramExecution memory p = _program(payer);
        n.authorization.nonce = nonce;
        u.authorization.nonce = nonce;
        p.authorization.nonce = nonce;
        vm.chainId(chain);
        bytes32 nativeDomain = _nativeDomain();
        require(
            nativeSale.authorizationDigest(n.authorization)
                == _digest(nativeDomain, _nativeMessage(n.authorization)),
            "native live chain"
        );
        require(
            sale.authorizationDigest(u.authorization)
                == _digest(_universalDomain(), _universalMessage(u.authorization)),
            "universal live chain"
        );
        require(
            nativeSale.priceProgramAuthorizationDigest(p.authorization)
                == _digest(_programDomain(), _programMessage(p.authorization)),
            "program live chain"
        );
        vm.chainId(original);
        StreamNativeFixedPriceSaleAdapter other = new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
        );
        bytes32 otherDomain = _domain(
            address(other), IERC5267.eip712Domain.selector, "6529StreamNativeFixedPriceSaleAdapter"
        );
        require(otherDomain != _nativeDomain(), "same family different verifying contract");
        require(
            other.authorizationDigest(n.authorization)
                == _digest(otherDomain, _nativeMessage(n.authorization)),
            "other contract complete digest"
        );
    }

    function _nativeDomain() private view returns (bytes32) {
        return _domain(
            address(nativeSale),
            IERC5267.eip712Domain.selector,
            "6529StreamNativeFixedPriceSaleAdapter"
        );
    }

    function _programDomain() private view returns (bytes32) {
        return _domain(
            address(nativeSale),
            IStreamNativePriceProgramDomain.priceProgramEip712Domain.selector,
            "6529StreamNativePricePrograms"
        );
    }

    function _universalDomain() private view returns (bytes32) {
        return _domain(
            address(sale),
            IERC5267.eip712Domain.selector,
            "6529StreamUniversalFixedPriceSaleAdapter"
        );
    }

    function _domain(address target, bytes4 selector, string memory expectedName)
        private
        view
        returns (bytes32)
    {
        (bool ok, bytes memory data) = target.staticcall(abi.encodeWithSelector(selector));
        require(ok, "domain read");
        Domain memory d;
        (d.fields, d.name, d.version, d.chainId, d.verifyingContract, d.salt, d.extensions) =
            abi.decode(data, (bytes1, string, string, uint256, address, bytes32, uint256[]));
        require(
            d.fields == hex"0f" && keccak256(bytes(d.name)) == keccak256(bytes(expectedName)),
            "exact fields/name"
        );
        require(
            keccak256(bytes(d.version)) == keccak256("1")
                && d.chainId == SigningDomainChainVm(address(vm)).getChainId(),
            "version/live chain"
        );
        require(
            d.verifyingContract == target && d.salt == 0 && d.extensions.length == 0,
            "contract/no salt/extensions"
        );
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(d.name)),
                keccak256(bytes(d.version)),
                d.chainId,
                d.verifyingContract
            )
        );
    }

    function _nativeMessage(IStreamNativeFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                NATIVE_TYPE,
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.executionNonce,
                a.nonce,
                a.deadline,
                a.expectedPrimaryPolicyHash
            )
        );
    }

    function _universalMessage(IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                UNIVERSAL_TYPE,
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.executionNonce,
                a.nonce,
                a.deadline
            )
        );
    }

    function _programMessage(IStreamNativePricePrograms.PriceProgramAuthorization memory a)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PROGRAM_TYPE,
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.executionNonce,
                a.nonce,
                a.deadline,
                a.expectedPrimaryPolicyHash,
                a.unitPrice
            )
        );
    }

    function _digest(bytes32 domain, bytes32 message) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domain, message));
    }

    function _program(address who)
        private
        returns (IStreamNativePricePrograms.PriceProgramExecution memory e)
    {
        IStreamNativePricePrograms.PriceProgramConfig memory config =
            IStreamNativePricePrograms.PriceProgramConfig(
                1,
                PHASE,
                13,
                125,
                1000,
                2,
                0,
                10_000,
                1,
                manager.POLICY(),
                resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash
            );
        bytes32 id = nativeSale.registerPriceProgram(config);
        e.tokenData = abi.encode("published-domain artwork", uint256(401));
        e.chosenUnitPrice = 333;
        e.authorization = IStreamNativePricePrograms.PriceProgramAuthorization(
            id,
            nativeSale.priceProgramRecord(id).configHash,
            who,
            who,
            who,
            artist,
            keccak256(e.tokenData),
            keccak256("published-domain mint"),
            401,
            bytes32(uint256(401)),
            uint64(block.timestamp + 1 hours),
            _primaryPolicy(),
            125
        );
    }

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 991);
        vm.deal(address(safe), 1 ether);
    }

    function _safeRead(address target, bytes4 selector) private {
        (bool ok, bytes memory expected) = target.staticcall(abi.encodeWithSelector(selector));
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(abi.encodeWithSelector(selector));
        require(ok && safeOk && keccak256(actual) == keccak256(expected), "Safe read parity");
        _exec(target, 0, abi.encodeWithSelector(selector));
    }

    function _exec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(safe, keys, target, value, data, 0) && safe.nonce() == nonce + 1,
            "Safe actual execution"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1, "one Safe ExecutionSuccess");
    }
}
