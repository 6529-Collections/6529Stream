// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";

/// @dev Real Manager/Ledger accounting regression for the typed stored-counter extraction.
contract StreamMintRevocationAccountingTest is MintRevocationTestBase {
    function testTwoDistinctStoredCountersSurviveExecutorRefreshAndPreparedExecution() public {
        bytes32 phase = keccak256("two counters");
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = keccak256("supply");
        ids[1] = keccak256("payer");
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](2);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("supply terms")
        );
        counters[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            15,
            2,
            keccak256("payer terms")
        );
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 2, keccak256("two config"), keccak256("two metadata")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(1, phase, config, gate, ids, counters);
        bytes32 original = manager.phasePolicyHash(1, phase);
        manager.setPhaseExecutor(1, phase, address(this), true);
        bytes32 changed = manager.phasePolicyHash(1, phase);
        require(changed != original, "executor hash changed");
        for (uint256 i; i < 2; i++) {
            IStreamMintLedger.LedgerCounterPolicy memory actual =
                ledger.registeredCounterPolicy(address(manager), 1, phase, ids[i]);
            IStreamMintManager.MintCounterConfig memory expected = counters[i];
            require(
                keccak256(abi.encode(actual))
                    == keccak256(
                        abi.encode(
                            true,
                            expected.capMode,
                            expected.deltaMode,
                            expected.staticCap,
                            expected.staticIncrement,
                            expected.counterConfigHash
                        )
                    ),
                "full projection"
            );
        }
        IStreamMintManager.MintBatch memory b = _batch(keccak256("prepared exact ID"));
        b.phaseId = phase;
        b.expectedPolicyHash = changed;
        b.initialRecipients = new address[](2);
        b.initialRecipients[0] = signer;
        b.initialRecipients[1] = signer;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](2);
        b.mintCommitments = new bytes32[](2);
        bytes32[2] memory keys;
        for (uint256 i; i < 2; i++) {
            bytes32 subject = manager.previewSubjectKey(
                counters[i].keyMode, 1, phase, ids[i], signer, signer, address(this), address(0), 0
            );
            keys[i] = ledger.deriveCounterValueKey(address(manager), 1, phase, ids[i], subject);
            require(ledger.counterValue(keys[i]) == 0, "initial counter");
        }
        manager.executePreparedMint(b, "");
        require(
            core.minted() == 2 && manager.nextOperationNonce() == 2
                && ledger.counterValue(keys[0]) == 2 && ledger.counterValue(keys[1]) == 4,
            "exact copied static deltas"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executePreparedMint(b, "");
        require(
            core.minted() == 2 && manager.nextOperationNonce() == 2
                && ledger.counterValue(keys[0]) == 2 && ledger.counterValue(keys[1]) == 4,
            "replay leaves counters"
        );
    }
}
