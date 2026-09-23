// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { OfficialSafeFixture, OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    StreamCanonicalSaleAuthorization
} from "../../../smart-contracts/domains/mint/StreamCanonicalSaleAuthorization.sol";
import {
    StreamPrivateSaleTypes as A
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as P
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";

/// @dev Test-only expected-payload input. Production hosts derive it from their bound sale/request.
contract CanonicalSaleAuthorizationHarness {
    address public immutable authorizer;
    uint8 public immutable kind;

    constructor(address authorizer_, uint8 kind_) {
        authorizer = authorizer_;
        kind = kind_;
    }

    function verify(
        A.SaleAuthorization memory expected,
        A.SaleAuthorization memory actual,
        P.Signature memory proof
    ) external view returns (bytes32) {
        return StreamCanonicalSaleAuthorization.verify(
            authorizer, kind, expected, actual, proof, 400_000
        );
    }
}

/// @dev Signature transport fault boundary; only mode zero has the exact valid magic word.
contract CanonicalSale1271Fixture {
    uint256 public mode;

    function setMode(uint256 value) external {
        mode = value;
    }

    fallback() external {
        require(msg.sig == 0x1626ba7e, "signature selector");
        uint256 selected = mode;
        assembly ("memory-safe") {
            mstore(0, shl(224, 0x1626ba7e))
            switch selected
            case 0 { return(0, 32) }
            case 1 { return(0, 4) }
            case 2 {
                mstore(32, 0)
                return(0, 64)
            }
            case 3 {
                mstore(0, or(mload(0), 1))
                return(0, 32)
            }
            case 4 { revert(0, 0) }
            default { return(0, 0) }
        }
    }
}

/// @notice Fixed linked verifier differential tests; no Manager or purchase execution is modeled.
contract StreamCanonicalSaleAuthorizationTest is CharacterizationTestBase, OfficialSafeFixture {
    uint256 private constant KEY = 0x6529123;
    address private signer;
    CanonicalSaleAuthorizationHarness private host;

    function setUp() public {
        vm.warp(1000);
        signer = vm.addr(KEY);
        host = new CanonicalSaleAuthorizationHarness(signer, 1);
    }

    function testLiteralFullSalesDigestAndOpenSignerNonceDeadline() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        require(
            host.verify(expected, actual, _proof(actual)) == _literalDigest(actual),
            "original full digest"
        );
        // These are the only copied fields. The signer can issue a different live envelope.
        actual.nonce = keccak256("different issued nonce");
        actual.deadline = 1000;
        require(
            host.verify(expected, actual, _proof(actual)) == _literalDigest(actual),
            "deadline equality admitted"
        );
        require(expected.nonce == 0 && expected.deadline == 0, "caller's expected memory unchanged");
    }

    function testEachOfTwentyTwoBoundWordsRejectsEvenWithMatchingNewSignature() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory original = _actual(expected);
        require(abi.encode(original).length == 24 * 32, "original tuple shape");
        for (uint256 i; i < 24; ++i) {
            if (i == 21 || i == 22) continue;
            bytes memory encoded = abi.encode(original);
            assembly ("memory-safe") {
                let ptr := add(add(encoded, 32), mul(i, 32))
                mstore(ptr, xor(mload(ptr), 1))
            }
            A.SaleAuthorization memory changed = abi.decode(encoded, (A.SaleAuthorization));
            P.Signature memory proof = _proof(changed);
            _invalidPayload();
            host.verify(expected, changed, proof);
        }
        require(
            host.verify(expected, original, _proof(original)) == _literalDigest(original),
            "same original healthy"
        );
    }

    function testNonceZeroAndExpiredDeadlineRejectWithValidSignatures() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        actual.nonce = 0;
        P.Signature memory proof = _proof(actual);
        _invalidPayload();
        host.verify(expected, actual, proof);
        actual.nonce = bytes32(uint256(1));
        actual.deadline = 999;
        proof = _proof(actual);
        _invalidPayload();
        host.verify(expected, actual, proof);
        actual.deadline = 1000;
        require(
            host.verify(expected, actual, _proof(actual)) == _literalDigest(actual),
            "inclusive original deadline"
        );
    }

    function testCopiedNonceAndDeadlineStillRequireOriginalSignature() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        P.Signature memory proof = _proof(actual);
        actual.nonce = bytes32(uint256(2));
        _invalidSignature(signer);
        host.verify(expected, actual, proof);
        actual.nonce = bytes32(uint256(1));
        actual.deadline += 1;
        _invalidSignature(signer);
        host.verify(expected, actual, proof);
    }

    function testMembershipKindAndErrorOrderRemainExplicit() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        P.Signature memory proof = _proof(actual);
        CanonicalSale1271Fixture outsider = new CanonicalSale1271Fixture();
        proof.authorizer = address(outsider);
        proof.kind = 2;
        actual.nonce = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                S.ImmediateSaleSignerUnavailable.selector, address(outsider), uint8(2)
            )
        );
        host.verify(expected, actual, proof);
        proof.authorizer = signer;
        vm.expectRevert(
            abi.encodeWithSelector(S.ImmediateSaleSignerUnavailable.selector, signer, uint8(2))
        );
        host.verify(expected, actual, proof);
        proof.kind = 1;
        _invalidPayload();
        host.verify(expected, actual, proof);
        actual.nonce = bytes32(uint256(1));
        require(
            host.verify(expected, actual, proof) == _literalDigest(actual),
            "same correctly presented account"
        );
    }

    function testZeroBoundSignerCannotProduceAuthority() public {
        CanonicalSaleAuthorizationHarness empty =
            new CanonicalSaleAuthorizationHarness(address(0), 1);
        A.SaleAuthorization memory expected = _expected(address(empty));
        A.SaleAuthorization memory actual = _actual(expected);
        _invalidSignature(address(0));
        empty.verify(expected, actual, P.Signature(address(0), 1, ""));
    }

    function testExplicitECDSAKindSupportsCodeBearingCompactProofAndRejectsNoncanonicalS() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        bytes32 digest = _literalDigest(actual);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        bytes32 highS = bytes32(
            uint256(0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141) - uint256(s)
        );
        P.Signature memory proof =
            P.Signature(signer, 1, abi.encodePacked(r, highS, v == 27 ? uint8(28) : uint8(27)));
        _invalidSignature(signer);
        host.verify(expected, actual, proof);
        vm.etch(signer, hex"60006000fd");
        bytes32 vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
        proof.signature = abi.encodePacked(r, vs);
        require(
            host.verify(expected, actual, proof) == digest,
            "explicit ECDSA is not a code-size branch"
        );
    }

    function testWrongDomainAndOrdinaryUnsignedPayloadCannotPass() public {
        A.SaleAuthorization memory expected = _expected(address(host));
        A.SaleAuthorization memory actual = _actual(expected);
        A.SaleAuthorization memory wrongDomain = _actual(expected);
        wrongDomain.saleAdapter = address(0xBAD);
        P.Signature memory proof = _proof(wrongDomain);
        _invalidSignature(signer);
        host.verify(expected, actual, proof);
        proof.signature = "";
        _invalidSignature(signer);
        host.verify(expected, actual, proof);
    }

    function testERC1271ExactShapeAndParentGasRefusal() public {
        CanonicalSale1271Fixture account = new CanonicalSale1271Fixture();
        CanonicalSaleAuthorizationHarness contractHost =
            new CanonicalSaleAuthorizationHarness(address(account), 2);
        A.SaleAuthorization memory expected = _expected(address(contractHost));
        A.SaleAuthorization memory actual = _actual(expected);
        P.Signature memory proof = P.Signature(address(account), 2, hex"1234");
        for (uint256 mode = 1; mode <= 5; ++mode) {
            account.setMode(mode);
            _invalidSignature(address(account));
            contractHost.verify(expected, actual, proof);
        }
        account.setMode(0);
        (bool ok, bytes memory reason) = address(contractHost).staticcall{ gas: 150_000 }(
            abi.encodeCall(contractHost.verify, (expected, actual, proof))
        );
        require(
            !ok && reason.length >= 4 && bytes4(reason) == P.PrivateSaleInsufficientGas.selector,
            "existing signature cap headroom error"
        );
        require(
            contractHost.verify(expected, actual, proof) == _literalDigest(actual),
            "full envelope exact magic succeeds"
        );
    }

    function testActualSafe141UsesItsMessageWrapperAroundOriginalSalesDigest() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652901;
        keys[1] = 0x652902;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1601);
        CanonicalSaleAuthorizationHarness safeHost =
            new CanonicalSaleAuthorizationHarness(address(account), 2);
        A.SaleAuthorization memory expected = _expected(address(safeHost));
        A.SaleAuthorization memory actual = _actual(expected);
        bytes32 digest = _literalDigest(actual);
        P.Signature memory proof =
            P.Signature(address(account), 2, safeThresholdSignature(keys, digest));
        _invalidSignature(address(account));
        safeHost.verify(expected, actual, proof);
        proof.signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        require(
            safeHost.verify(expected, actual, proof) == digest,
            "actual Safe signature under original Sales domain"
        );
    }

    function testFuzzLiteralOriginalPayloadAndCallerSelectedExpectedPrice(
        bytes32 salt,
        uint256 price,
        uint64 deadline
    ) public {
        A.SaleAuthorization memory expected = _expected(address(host));
        expected.unitPrice = price;
        expected.initialRecipientsHash = keccak256(abi.encode(salt, uint8(1)));
        expected.beneficiariesHash = keccak256(abi.encode(salt, uint8(2)));
        expected.tokenDataArrayHash = keccak256(abi.encode(salt, uint8(3)));
        expected.mintCommitmentsHash = keccak256(abi.encode(salt, uint8(4)));
        A.SaleAuthorization memory actual = _actual(expected);
        actual.nonce = salt == 0 ? bytes32(uint256(1)) : salt;
        actual.deadline = deadline < 1000 ? 1000 : deadline;
        require(
            host.verify(expected, actual, _proof(actual)) == _literalDigest(actual),
            "fixed expected full tuple; host owns price policy"
        );
    }

    function _expected(address adapter) private view returns (A.SaleAuthorization memory a) {
        a.chainId = block.chainid;
        a.saleAdapter = adapter;
        a.mintManager = address(0xBEEF);
        a.collectionId = 1;
        a.phaseId = keccak256("canonical helper phase");
        a.saleId = keccak256("canonical helper sale");
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = keccak256("bound primary policy");
        a.initialRecipientsHash = keccak256("recipients");
        a.beneficiariesHash = keccak256("beneficiaries");
        a.tokenDataArrayHash = keccak256("token data");
        a.mintCommitmentsHash = keccak256("commitments");
        a.payer = address(0xA);
        a.executor = address(0xA);
        a.unitPrice = 100;
        a.quantity = 1;
        a.policyHash = keccak256("bound mint policy");
    }

    function _actual(A.SaleAuthorization memory expected)
        private
        pure
        returns (A.SaleAuthorization memory a)
    {
        a = abi.decode(abi.encode(expected), (A.SaleAuthorization));
        a.nonce = bytes32(uint256(1));
        a.deadline = 2000;
    }

    function _literalDigest(A.SaleAuthorization memory a) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                a.saleAdapter
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _proof(A.SaleAuthorization memory a) private returns (P.Signature memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, _literalDigest(a));
        return P.Signature(signer, 1, abi.encodePacked(r, s, v));
    }

    function _invalidPayload() private {
        vm.expectRevert(abi.encodeWithSelector(S.InvalidImmediateSale.selector));
    }

    function _invalidSignature(address authorizer) private {
        vm.expectRevert(
            abi.encodeWithSelector(S.ImmediateSaleSignatureInvalid.selector, authorizer)
        );
    }
}
