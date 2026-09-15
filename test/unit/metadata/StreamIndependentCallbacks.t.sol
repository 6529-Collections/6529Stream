// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionAttestations.t.sol";

contract IndependentReentrantSigner {
    address private target;
    bytes private callback;
    bytes32 private approved;

    function configure(address nextTarget, bytes memory nextCallback, bytes32 digest) external {
        target = nextTarget;
        callback = nextCallback;
        approved = digest;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        (bool ok, bytes memory result) = target.staticcall(callback);
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()")),
            "exact active host guard"
        );
        return digest == approved ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamIndependentCallbacksTest is IndependentAttestationTestBase {
    function testSignatureCallbackPinsGuardForAllThreeRecordNonceEntries() public {
        IndependentReentrantSigner wallet = new IndependentReentrantSigner();
        for (uint256 i; i < 3; ++i) {
            (
                IStreamCollectionAttestations.Subject memory s,
                IStreamCollectionAttestations.IndependentRecord memory r
            ) = _request(address(wallet), i);
            bytes memory nested;
            if (i == 0) {
                nested = abi.encodeCall(host.recordIndependentPreservation, (s, r, bytes("")));
            } else if (i == 1) {
                nested = abi.encodeCall(host.revokeIndependentAttestorNonce, (uint256(700)));
            } else {
                nested = abi.encodeCall(
                    host.revokeIndependentAttestorNonceFor,
                    (address(wallet), uint256(701), r.deadline, bytes(""))
                );
            }
            wallet.configure(address(host), nested, host.independentRecordDigest(r));
            host.recordIndependentPreservation(s, r, hex"01");
            require(host.isIndependentAttestorNonceUsed(address(wallet), i), "outer success");
            require(
                !host.isIndependentAttestorNonceUsed(address(wallet), 700)
                    && !host.isIndependentAttestorNonceUsed(address(wallet), 701),
                "no nested nonce effects"
            );
        }
    }

    function testLiveDependencyFailureRollsBackAndSameSignedProofRetries() public {
        (
            IStreamCollectionAttestations.Subject memory s,
            IStreamCollectionAttestations.IndependentRecord memory r
        ) = _request(signer, 91);
        bytes memory signature = _sign(host.independentRecordDigest(r));
        bytes memory original = address(store).code;
        vm.etch(address(store), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionAttestations.IndependentDependencyChanged.selector, address(store)
            )
        );
        host.recordIndependentPreservation(s, r, signature);
        require(
            !host.isIndependentAttestorNonceUsed(signer, 91) && host.payloadPointerCount(1) == 0,
            "post-verification failure rollback"
        );
        (, uint64 count) = host.recordChainHash(1, r.recordType);
        require(count == 0, "no partial chain");
        vm.etch(address(store), original);
        host.recordIndependentPreservation(s, r, signature);
    }
}
