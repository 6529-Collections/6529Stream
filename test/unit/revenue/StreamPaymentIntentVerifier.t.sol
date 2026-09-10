// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/revenue/StreamPaymentIntentVerifier.sol";

/// @dev Exercises the consent primitive; the sale suite exercises actual ERC-20 pulls.
contract PaymentIntentHarness is StreamPaymentIntentVerifier {
    uint256 public authorized;

    function authorize(
        PaymentTerms calldata terms,
        PaymentIntent calldata intent,
        bytes calldata signature,
        bool fail
    ) external nonReentrant {
        _authorizePayment(terms, intent, signature);
        authorized += 1;
        require(!fail, "downstream failure");
    }
}

contract PaymentIntentWallet {
    bytes32 public digest;
    uint8 public mode;

    function configure(bytes32 digest_, uint8 mode_) external {
        digest = digest_;
        mode = mode_;
    }

    function isValidSignature(bytes32 digest_, bytes calldata) external view returns (bytes4) {
        if (mode == 1) {
            uint256 start = gasleft();
            while (start - gasleft() < 320_000) { }
        }
        if (mode == 2) while (true) { }
        if (mode == 3) revert("wallet rejects");
        if (mode == 4) {
            assembly {
                mstore(0, shl(224, 0x1626ba7e))
                return(0, 4)
            }
        }
        if (mode == 5) {
            assembly {
                mstore(0, shl(224, 0x1626ba7e))
                return(0, 64)
            }
        }
        if (mode == 6) return 0xffffffff;
        return digest_ == digest ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamPaymentIntentVerifierTest is CharacterizationTestBase {
    uint256 private constant PAYER_KEY = 0xA11CE;
    PaymentIntentHarness private verifier;
    address private payer;
    StreamPaymentIntentVerifier.PaymentTerms private terms;
    IStreamPaymentIntentVerifier.PaymentIntent private intent;

    function setUp() public {
        verifier = new PaymentIntentHarness();
        payer = vm.addr(PAYER_KEY);
        terms = StreamPaymentIntentVerifier.PaymentTerms(
            payer, address(0x20), 70, keccak256("sale"), keccak256("policy")
        );
        intent = IStreamPaymentIntentVerifier.PaymentIntent(
            payer,
            terms.asset,
            100,
            terms.saleRef,
            terms.primaryPolicyHash,
            bytes32(0),
            uint64(block.timestamp + 1 days)
        );
    }

    function testPinnedTypehashDomainAndDigestMatchIndependentEncoding() public view {
        require(
            verifier.PAYMENT_INTENT_TYPEHASH()
                == 0x72c99e6f6f9e2422510a5dd5c2dc2f9ffd83c776670a8de4ffab990e45f825cd,
            "intent typehash"
        );
        require(
            verifier.PAYMENT_INTENT_REVOCATION_TYPEHASH()
                == 0x3a5991afab010b2aa3f78362da982cf536e46d406a9e205c1f27b0f0e4c42e50,
            "revoke typehash"
        );
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chain,
            address target,
            bytes32 salt,
            uint256[] memory extensions
        ) = verifier.eip712Domain();
        require(
            fields == 0x0f && keccak256(bytes(name)) == keccak256("6529StreamPaymentIntentVerifier")
                && keccak256(bytes(version)) == keccak256("1") && chain == block.chainid
                && target == address(verifier) && salt == 0 && extensions.length == 0,
            "ERC5267 exact domain"
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(verifier)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                verifier.PAYMENT_INTENT_TYPEHASH(),
                intent.payer,
                intent.asset,
                intent.maxAmount,
                intent.saleRef,
                intent.expectedPrimaryPolicyHash,
                intent.nonce,
                intent.deadline
            )
        );
        require(
            verifier.paymentIntentDigest(intent)
                == keccak256(abi.encodePacked(hex"1901", domain, body)),
            "independent digest"
        );
        bytes32 revocation = keccak256(
            abi.encode(
                verifier.PAYMENT_INTENT_REVOCATION_TYPEHASH(), payer, intent.nonce, intent.deadline
            )
        );
        require(
            verifier.paymentIntentRevocationDigest(payer, intent.nonce, intent.deadline)
                == keccak256(abi.encodePacked(hex"1901", domain, revocation)),
            "independent revocation digest"
        );
    }

    function testSignedIntentConsumesOnceAndEmitsExactCanonicalEvent() public {
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        vm.recordLogs();
        verifier.authorize(terms, intent, signature, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(verifier), "only consumption event");
        require(
            logs[0].topics[0]
                    == keccak256(
                        "PaymentIntentConsumed(address,bytes32,bytes32,uint16,address,uint256)"
                    ) && logs[0].topics[1] == bytes32(uint256(uint160(payer)))
                && logs[0].topics[2] == terms.saleRef && logs[0].topics[3] == intent.nonce,
            "indexed payer sale nonce"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(uint16(1), terms.asset, terms.amount)),
            "amount schema"
        );
        require(
            verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "explicit payer replay view"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPaymentIntentVerifier.PaymentIntentNonceUsed.selector, payer, intent.nonce
            )
        );
        verifier.authorize(terms, intent, signature, false);
        require(verifier.authorized() == 1, "once");
    }

    function testEverySignedFieldMutationRejectsBeforeConsumption() public {
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        for (uint256 i; i < 7; ++i) {
            IStreamPaymentIntentVerifier.PaymentIntent memory changed = intent;
            if (i == 0) changed.payer = address(0xBAD);
            if (i == 1) changed.asset = address(0xBAD);
            if (i == 2) changed.maxAmount = terms.amount - 1;
            if (i == 3) changed.saleRef = keccak256("another sale");
            if (i == 4) changed.expectedPrimaryPolicyHash = keccak256("another policy");
            if (i == 5) changed.nonce = bytes32(uint256(1));
            if (i == 6) changed.deadline += 1;
            (bool ok,) = address(verifier)
                .call(abi.encodeCall(verifier.authorize, (terms, changed, signature, false)));
            require(
                !ok && verifier.authorized() == 0
                    && !verifier.isPaymentIntentNonceUsed(payer, intent.nonce),
                "mutated consent accepted"
            );
        }
    }

    function testWrongChainVerifierAndExpiredIntentReject() public {
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        uint256 chain = block.chainid;
        vm.chainId(chain + 1);
        vm.expectRevert();
        verifier.authorize(terms, intent, signature, false);
        vm.chainId(chain);
        PaymentIntentHarness another = new PaymentIntentHarness();
        vm.expectRevert();
        another.authorize(terms, intent, signature, false);
        vm.warp(uint256(intent.deadline) + 1);
        vm.expectRevert();
        verifier.authorize(terms, intent, signature, false);
        require(!verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "failed checks consumed");
    }

    function testOnlyLiteralPayerMayOmitSignature() public {
        vm.expectRevert();
        verifier.authorize(terms, intent, "", false);
        vm.prank(payer);
        verifier.authorize(terms, intent, "", false);
        require(
            verifier.authorized() == 1 && !verifier.isPaymentIntentNonceUsed(payer, intent.nonce),
            "caller exemption"
        );
    }

    function testNoncesArePayerScopedAndDownstreamFailureRollsBack() public {
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        vm.expectRevert();
        verifier.authorize(terms, intent, signature, true);
        require(
            !verifier.isPaymentIntentNonceUsed(payer, intent.nonce) && verifier.authorized() == 0,
            "rolled back"
        );
        verifier.authorize(terms, intent, signature, false);
        terms.payer = vm.addr(0xB0B);
        intent.payer = terms.payer;
        verifier.authorize(terms, intent, _sign(0xB0B, verifier.paymentIntentDigest(intent)), false);
        require(
            verifier.authorized() == 2
                && verifier.isPaymentIntentNonceUsed(terms.payer, intent.nonce),
            "independent payer"
        );
    }

    function testDirectAndSignedRevocationArePermanentAndReplayProtected() public {
        vm.prank(payer);
        verifier.revokePaymentIntent(intent.nonce);
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        vm.expectRevert();
        verifier.authorize(terms, intent, signature, false);
        intent.nonce = bytes32(uint256(2));
        signature = _sign(
            PAYER_KEY, verifier.paymentIntentRevocationDigest(payer, intent.nonce, intent.deadline)
        );
        verifier.revokePaymentIntentBySignature(payer, intent.nonce, intent.deadline, signature);
        vm.expectRevert();
        verifier.revokePaymentIntentBySignature(payer, intent.nonce, intent.deadline, signature);
        vm.warp(uint256(intent.deadline) + 1);
        require(verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "expiry cannot revive");
        intent.nonce = bytes32(uint256(3));
        vm.expectRevert();
        verifier.revokePaymentIntentBySignature(payer, intent.nonce, intent.deadline, signature);
        require(
            !verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "expired relay not consumed"
        );
    }

    function testCanonicalEOANegativesAndCompactSignature() public {
        bytes32 digest = verifier.paymentIntentDigest(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PAYER_KEY, digest);
        vm.expectRevert();
        verifier.authorize(terms, intent, abi.encodePacked(r, s, uint8(0)), false);
        vm.expectRevert();
        verifier.authorize(terms, intent, abi.encodePacked(r, bytes32(type(uint256).max), v), false);
        vm.expectRevert();
        verifier.authorize(
            terms, intent, abi.encodePacked(bytes32(0), bytes32(0), uint8(27)), false
        );
        bytes32 vs = s | bytes32(uint256(v - 27) << 255);
        verifier.authorize(terms, intent, abi.encodePacked(r, vs), false);
        require(verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "compact canonical EOA");
    }

    function testHeavyContractWalletAndMalformedResponses() public {
        PaymentIntentWallet contractPayer = new PaymentIntentWallet();
        terms.payer = address(contractPayer);
        intent.payer = terms.payer;
        bytes32 digest = verifier.paymentIntentDigest(intent);
        for (uint8 mode = 2; mode <= 6; ++mode) {
            contractPayer.configure(digest, mode);
            (bool ok,) = address(verifier)
                .call(abi.encodeCall(verifier.authorize, (terms, intent, hex"01", false)));
            require(
                !ok && !verifier.isPaymentIntentNonceUsed(terms.payer, intent.nonce),
                "invalid wallet response"
            );
        }
        contractPayer.configure(digest, 1);
        verifier.authorize(terms, intent, hex"01", false);
        require(
            verifier.isPaymentIntentNonceUsed(terms.payer, intent.nonce),
            "heavy valid wallet supported"
        );
    }

    function testContractWalletSignedRevocationAndLowParentGasAdmission() public {
        PaymentIntentWallet contractPayer = new PaymentIntentWallet();
        terms.payer = address(contractPayer);
        intent.payer = terms.payer;
        contractPayer.configure(verifier.paymentIntentDigest(intent), 0);
        (bool ok, bytes memory result) = address(verifier).call{ gas: 430_000 }(
            abi.encodeCall(verifier.authorize, (terms, intent, hex"01", false))
        );
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamPaymentIntentVerifier.InsufficientSignatureGas.selector
                        )
                    ),
            "underfunded parent rejected"
        );
        contractPayer.configure(
            verifier.paymentIntentRevocationDigest(terms.payer, intent.nonce, intent.deadline), 1
        );
        verifier.revokePaymentIntentBySignature(terms.payer, intent.nonce, intent.deadline, hex"01");
        require(verifier.isPaymentIntentNonceUsed(terms.payer, intent.nonce), "heavy revoke");
    }

    function testSignatureGasIsOwnerGovernedAndRaiseOnly() public {
        require(verifier.signatureGasLimit() == 400_000, "genesis stipend");
        vm.prank(payer);
        vm.expectRevert();
        verifier.raiseSignatureGasLimit(500_000);
        vm.expectRevert();
        verifier.raiseSignatureGasLimit(399_999);
        vm.expectRevert();
        verifier.raiseSignatureGasLimit(400_000);
        verifier.raiseSignatureGasLimit(500_000);
        require(verifier.signatureGasLimit() == 500_000, "governed raise");
    }

    function testRevocationCanonicalNegativesAndSignerDomainBinding() public {
        bytes32 digest =
            verifier.paymentIntentRevocationDigest(payer, intent.nonce, intent.deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PAYER_KEY, digest);
        bytes[] memory signatures = new bytes[](3);
        signatures[0] = abi.encodePacked(r, s, uint8(0));
        signatures[1] = abi.encodePacked(r, bytes32(type(uint256).max), v);
        signatures[2] = abi.encodePacked(bytes32(0), bytes32(0), uint8(27));
        for (uint256 i; i < signatures.length; ++i) {
            (bool ok,) = address(verifier)
                .call(
                    abi.encodeCall(
                        verifier.revokePaymentIntentBySignature,
                        (payer, intent.nonce, intent.deadline, signatures[i])
                    )
                );
            require(
                !ok && !verifier.isPaymentIntentNonceUsed(payer, intent.nonce),
                "noncanonical revocation"
            );
        }
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.expectRevert();
        verifier.revokePaymentIntentBySignature(
            address(0xBAD), intent.nonce, intent.deadline, signature
        );
        uint256 chain = block.chainid;
        vm.chainId(chain + 1);
        vm.expectRevert();
        verifier.revokePaymentIntentBySignature(payer, intent.nonce, intent.deadline, signature);
        vm.chainId(chain);
        PaymentIntentHarness another = new PaymentIntentHarness();
        vm.expectRevert();
        another.revokePaymentIntentBySignature(payer, intent.nonce, intent.deadline, signature);
        require(
            !verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "invalid relays did not revoke"
        );
    }

    function testDelegationDesignationRetainsCanonicalEOAConsentPath() public {
        bytes memory signature = _sign(PAYER_KEY, verifier.paymentIntentDigest(intent));
        vm.etch(payer, abi.encodePacked(hex"ef0100", address(0xDE1E6A7)));
        verifier.authorize(terms, intent, signature, false);
        require(
            verifier.isPaymentIntentNonceUsed(payer, intent.nonce), "delegated EOA own-key intent"
        );
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
