// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeRoyaltySnapshotFixture.sol";

interface SnapshotProofStateVm {
    struct Log { bytes32[] topics; bytes data; address emitter; }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Actual producer state with the selected Manager caller impersonated only to hold the
/// prepared window open. This tests Resolver idempotence, not Manager transcript authorization.
contract StreamCurrentRoyaltySnapshotProofStateTest is NativeRoyaltySnapshotFixture {
    SnapshotProofStateVm private constant evidence = SnapshotProofStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testSameCompletePreparedProofIsSilentNoopAndConflictingExpectedPolicyFails() public {
        bytes32 root = keccak256("controlled original real Ledger root");
        bytes32 operation = keccak256("controlled original real Core operation");
        bytes32 policyHash = manager.phasePolicyHash(1, SNAP_PHASE);
        IStreamMintLedger.CounterConsumption[] memory counters = new IStreamMintLedger.CounterConsumption[](0);
        bytes32[] memory nullifiers = new bytes32[](0);
        vm.prank(address(manager));
        ledger.consume(1, SNAP_PHASE, counters, keccak256("controlled proof authorization"), nullifiers, policyHash, root);
        bytes memory data = bytes("actual pending snapshot proof data");
        bytes32 dataHash = keccak256(data);
        vm.prank(address(manager));
        (uint256 token, uint256 serial) = core.prepareMintFromManager(1, data, dataHash, operation);
        require(token == 1 && serial == 1 && core.preparedMint(token).exists, "actual prepared Core window retained");
        vm.prank(address(manager));
        bytes32 first = royalty.snapshotTokenRoyaltyAtMint(token, 1, root, operation, keccak256("ROYALTY_ERC2981"), originalRoyalty.sourceRoyaltyPolicyHash);
        IStreamRoyaltySnapshot.Snapshot memory saved = _assertSnapshot(token);
        bytes memory exact = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (token, uint256(1), root, operation, keccak256("ROYALTY_ERC2981"), originalRoyalty.sourceRoyaltyPolicyHash));
        evidence.recordLogs();
        vm.prank(address(manager));
        (bool ok, bytes memory raw) = address(royalty).call(exact);
        require(ok && raw.length == 32 && abi.decode(raw, (bytes32)) == first && evidence.getRecordedLogs().length == 0
            && keccak256(abi.encode(royalty.royaltySnapshot(token))) == keccak256(abi.encode(saved))
            && royalty.tokenRoyalty(token).revision == 1, "complete same proof returns exact policy with no new event or persistent state");
        bytes memory wrong = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (token, uint256(1), root, operation, keccak256("ROYALTY_ERC2981"), keccak256("wrong original policy")));
        vm.prank(address(manager));
        (ok,) = address(royalty).call(wrong);
        require(!ok && keccak256(abi.encode(royalty.royaltySnapshot(token))) == keccak256(abi.encode(saved)),
            "saved state cannot mask a conflicting expected source");
        vm.prank(address(manager));
        core.completePreparedMintFromManager(token, payer, operation, keccak256("proof state mint commitment"));
        vm.prank(address(manager));
        (ok,) = address(royalty).call(exact);
        require(!ok && core.ownerOf(token) == payer, "completed original proof cannot authorize another call");
    }
}
