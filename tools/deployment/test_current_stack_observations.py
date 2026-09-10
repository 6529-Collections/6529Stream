#!/usr/bin/env python3
"""Public export completeness and private-operation exclusion regressions."""
import copy
import json
import unittest

from tools.deployment.export_current_stack_observations import observations


class ObservationTests(unittest.TestCase):
    def setUp(self):
        account = "0x" + "11" * 20
        request = "0x" + "22" * 32
        receipt = {"transactionHash": request, "blockNumber": "0x10", "gasUsed": "0x5208",
                   "effectiveGasPrice": "0x1", "status": "0x1"}
        self.state = {
            "chainId": 11155111, "demonstrated": True, "metadataState": "final",
            "accounts": dict.fromkeys(("deployer", "artist", "platform", "protocol"), account),
            "addresses": {"core": account}, "wallet": account, "finalOwner": account,
            "providerResult": [3, request, request, True, True], "requestKey": request,
            "receipts": {label: copy.deepcopy(receipt) for label in
                         ("deployment-0", "paidMint", "requestEntropy", "artistWithdrawal",
                          "protocolWithdrawal", "transfer")},
            "vrf": {"coordinator": account, "keyHash": request, "confirmations": 3,
                    "callbackGas": 1500000, "nativePayment": True},
            "deploymentSourceCommit": "a" * 40, "tokenId": "1", "mintPriceWei": "1000",
            "subscriptionId": str(2 ** 255), "providerRequestId": str(2 ** 254),
            "royaltyInfo": [account, "50"],
        }
        self.metadata = {"metadata_state": "final"}
        self.verification = {"chain_id": 11155111,
                             "schema": "6529stream.current-deployment-bytecode-check.v1",
                             "result": "bytecode comparisons passed", "verification_block": "0x11",
                             "contracts": [{"address": account}]}

    def export(self):
        return observations(self.state, self.metadata, self.verification)

    def test_excludes_private_operational_fields_and_preserves_large_ids(self):
        self.state["passwordRecord"] = "SENTINEL_PRIVATE_OPERATION"
        self.state["deploymentAttempt"] = {"broadcastFile": "SENTINEL_LOCAL_PATH"}
        report = self.export()
        self.assertNotIn("SENTINEL", json.dumps(report))
        self.assertEqual(report["vrf"]["subscription_id"], str(2 ** 255))
        self.assertEqual(report["receipts"]["paidMint"]["block_number"], 16)

    def test_rejects_incomplete_demo(self):
        self.state["demonstrated"] = False
        with self.assertRaises(ValueError):
            self.export()

    def test_rejects_failed_receipt(self):
        self.state["receipts"]["paidMint"]["status"] = "0x0"
        with self.assertRaises(ValueError):
            self.export()

    def test_rejects_unverified_module(self):
        self.state["addresses"]["core"] = "0x" + "33" * 20
        with self.assertRaises(ValueError):
            self.export()

    def test_rejects_other_provider_request(self):
        self.state["providerResult"][1] = "0x" + "44" * 32
        with self.assertRaises(ValueError):
            self.export()

    def test_rejects_missing_transfer(self):
        del self.state["receipts"]["transfer"]
        with self.assertRaises(ValueError):
            self.export()

    def test_invalid_objects_use_the_controlled_failure_path(self):
        for invalid in ([], "invalid", 17, None):
            for index in range(3):
                inputs = [self.state, self.metadata, self.verification]
                inputs[index] = invalid
                with self.subTest(input=index, value=invalid), self.assertRaises(ValueError):
                    observations(*inputs)
            for field in ("addresses", "receipts"):
                state = {**self.state, field: invalid}
                with self.subTest(field=field, value=invalid), self.assertRaises(ValueError):
                    observations(state, self.metadata, self.verification)


if __name__ == "__main__":
    unittest.main()
