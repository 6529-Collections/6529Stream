// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/OfficialSafeFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamSaleSignatures.sol";
import "../../../smart-contracts/domains/revenue/StreamClaimRouter.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";

contract SafeStreamSignatureProbe {
    function valid(address signer, bytes32 digest, bytes calldata signature)
        external
        view
        returns (bool)
    {
        return StreamSaleSignatures.isValid(signer, digest, signature);
    }
}

contract SafeExecutionReceiver {
    address public sender;
    uint256 public received;

    function record() external payable {
        sender = msg.sender;
        received += msg.value;
    }
}

contract StreamOfficialSafeTest is CharacterizationTestBase, OfficialSafeFixture {
    event log_named_uint(string key, uint256 value);
    bytes4 private constant MAGIC = 0x1626ba7e;
    uint256[] private _owners;
    uint256[] private _signers;

    function setUp() public {
        _owners.push(0xA1101);
        _owners.push(0xA1102);
        _owners.push(0xA1103);
        _signers.push(_owners[0]);
        _signers.push(_owners[1]);
    }

    function testSafe130ThresholdSigningExecutionAndClaims() public {
        _exercise("1.3.0");
    }

    function testSafe141ThresholdSigningExecutionAndClaims() public {
        _exercise("1.4.1");
    }

    function testSafe150ThresholdSigningExecutionAndClaims() public {
        _exercise("1.5.0");
    }

    function _exercise(string memory version) private {
        SafeComponents memory c = deploySafeComponents(version);
        OfficialSafe account = createOfficialSafe(c, safeOwnerAddresses(_owners), 2, 1);
        require(keccak256(bytes(account.VERSION())) == keccak256(bytes(version)), "version");
        SafeStreamSignatureProbe probe = new SafeStreamSignatureProbe();
        bytes32 streamDigest = keccak256("actual Stream application digest");
        bytes memory signature =
            safeThresholdSignature(_signers, safeMessageDigest(account, abi.encode(streamDigest)));
        require(
            probe.valid(address(account), streamDigest, signature), "real Safe signature rejected"
        );
        bytes32 approvedDigest = keccak256("Safe approved Stream message");
        require(
            !probe.valid(address(account), approvedDigest, bytes("")), "unapproved empty signature"
        );
        require(
            executeSafe(
                account,
                _signers,
                c.signMessage,
                0,
                abi.encodeWithSignature("signMessage(bytes)", abi.encode(approvedDigest)),
                1
            ),
            "Safe message approval"
        );
        require(
            probe.valid(address(account), approvedDigest, bytes("")),
            "approved empty signature rejected"
        );
        require(
            !probe.valid(address(account), bytes32(uint256(streamDigest) ^ 1), signature),
            "digest substitution"
        );
        require(
            !probe.valid(
                address(account), streamDigest, safeThresholdSignature(_signers, streamDigest)
            ),
            "unwrapped signature"
        );
        uint256[] memory one = new uint256[](1);
        one[0] = _signers[0];
        require(
            !probe.valid(
                address(account),
                streamDigest,
                safeThresholdSignature(one, safeMessageDigest(account, abi.encode(streamDigest)))
            ),
            "threshold bypass"
        );
        OfficialSafe other = createOfficialSafe(c, safeOwnerAddresses(_owners), 2, 2);
        require(!probe.valid(address(other), streamDigest, signature), "cross-Safe replay");
        uint256 chain = block.chainid;
        vm.chainId(chain + 1);
        require(!probe.valid(address(account), streamDigest, signature), "cross-chain replay");
        vm.chainId(chain);
        SafeExecutionReceiver receiver = new SafeExecutionReceiver();
        vm.deal(address(account), 2 ether);
        require(
            executeSafe(
                account,
                _signers,
                address(receiver),
                1 ether,
                abi.encodeCall(receiver.record, ()),
                0
            ),
            "Safe execution failed"
        );
        require(
            receiver.sender() == address(account) && receiver.received() == 1 ether,
            "wrong caller or value"
        );
        _claimIntoSafe(account);
        require(
            executeSafe(
                account,
                _signers,
                address(account),
                0,
                abi.encodeWithSignature("changeThreshold(uint256)", 3),
                0
            ),
            "threshold change"
        );
        require(
            !probe.valid(address(account), streamDigest, signature), "stale threshold signatures"
        );
        require(
            probe.valid(
                address(account),
                streamDigest,
                safeThresholdSignature(
                    _owners, safeMessageDigest(account, abi.encode(streamDigest))
                )
            ),
            "new threshold"
        );
    }

    function _claimIntoSafe(OfficialSafe account) private {
        StreamAssetPolicyRegistry policy = new StreamAssetPolicyRegistry();
        StreamSplitFactory factory = new StreamSplitFactory(policy);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(account), 1_000_000, keccak256("ARTIST"));
        (, address wallet) = factory.createProfile(entries, keccak256("Safe payout"));
        vm.deal(address(this), 3 ether);
        (bool ok,) = wallet.call{ value: 3 ether }("");
        require(ok, "fund split");
        StreamClaimRouter router = new StreamClaimRouter();
        IStreamClaimRouter.ClaimCall[] memory claims = new IStreamClaimRouter.ClaimCall[](1);
        claims[0] = IStreamClaimRouter.ClaimCall(wallet, address(0), address(account));
        uint256 beforeBalance = address(account).balance;
        uint256[] memory amounts = router.claimMany(claims, false);
        require(
            amounts[0] == 3 ether && address(account).balance == beforeBalance + 3 ether,
            "Safe payout"
        );
        require(router.claimMany(claims, true)[0] == 0, "double claim");
        require(address(account).balance == beforeBalance + 3 ether, "repeat claim changed balance");
    }

    function testSafe141NestedThresholdSignatureWithStorageCooled() public {
        SafeComponents memory c = deploySafeComponents("1.4.1");
        OfficialSafe inner = createOfficialSafe(c, safeOwnerAddresses(_owners), 2, 1);
        address[] memory outerOwners = new address[](2);
        outerOwners[0] = address(inner);
        outerOwners[1] = safeVm.addr(0xB1101);
        OfficialSafe outer = createOfficialSafe(c, outerOwners, 2, 2);
        bytes32 digest = keccak256("nested Stream signature");
        bytes32 messageStruct = keccak256(
            abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(digest)))
        );
        bytes memory outerPreimage =
            abi.encodePacked(bytes2(0x1901), outer.domainSeparator(), messageStruct);
        bytes memory innerSignature =
            safeThresholdSignature(_signers, safeMessageDigest(inner, outerPreimage));
        uint256[] memory key = new uint256[](1);
        key[0] = 0xB1101;
        bytes memory eoaSignature = safeThresholdSignature(key, keccak256(outerPreimage));
        bytes memory contractHeader = abi.encodePacked(
            bytes32(uint256(uint160(address(inner)))), bytes32(uint256(130)), uint8(0)
        );
        bytes memory signature = address(inner) < outerOwners[1]
            ? bytes.concat(contractHeader, eoaSignature)
            : bytes.concat(eoaSignature, contractHeader);
        signature = bytes.concat(signature, abi.encode(innerSignature.length), innerSignature);
        safeVm.cool(address(inner));
        safeVm.cool(address(outer));
        safeVm.cool(c.singleton);
        safeVm.cool(c.handler);
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory result) = address(outer).staticcall{ gas: 400_000 }(
            abi.encodeWithSelector(MAGIC, digest, signature)
        );
        // cool resets storage access; this same-transaction setup is not all-cold account evidence.
        emit log_named_uint(
            "storage-cooled nested Safe 1.4.1 verification caller gas", beforeGas - gasleft()
        );
        require(
            ok && result.length == 32 && abi.decode(result, (bytes4)) == MAGIC, "nested signature"
        );
    }
}
