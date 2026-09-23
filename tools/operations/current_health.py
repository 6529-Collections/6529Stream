"""Observe one pinned current-stack block; never sign, deploy, or repair state."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import sys

from tools.museum import canonical, chain_abi, chain_rpc
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from tools.museum.chain_abi import decode
from tools.museum.chain_rpc import quantity
from . import transport as transport_module
from .transport import HttpTransport, Recorder, Replay, RpcFailure

MAX_INPUT = 16777216
MAX_PRODUCTS = 128
MAX_PINS = 256
MAX_LOGS = 2048
PROFILE_SCHEMA = "6529stream.genesis-deployment-profile.v2"
CANDIDATE_SCHEMA = "6529stream.canonical-deployment-candidate.v2"
NATIVE_MODE = "current_museum_native_products_v1"

# Exact, no-argument view signatures. A call also requires an exact match in the
# authenticated artifact ABI AND compiler methodIdentifiers; no selector guesses.
VIEWS = {
    "genesisInitialized()": ("bool",),
    "governanceActionPolicyState()": ("bytes32", "bytes32", "uint256", "uint64"),
    "entropyPolicyInventory()": ("uint256", "uint64", "bytes32"),
    "incompleteFinalityRecoveryRefreshPlanCount()": ("uint256",),
    "recoveryExecutorBinding()": ("address", "bytes32"),
    "paused()": ("bool",),
}
EVENT_NAMES = frozenset({
    "GenesisInitialized", "GovernanceActionPolicyBound", "GovernanceActionPolicyValidated",
    "GovernanceActionPolicyExtended", "ImmediateSalePause", "NativeAuctionPause",
    "AuctionsPauseChanged", "Paused", "Unpaused", "EntropyRecoveryRequested",
    "EntropyRecoveryEvidence", "EntropyRecoverySuperseded", "FreshRecoveryPolicyConfigured",
    "FreshRecoveryPolicyFrozen", "EscrowRecoveryScheduled", "EscrowRecoveryCancelled",
    "EscrowRecoveryExecuted",
})


def require(condition, message):
    if not condition:
        raise MuseumError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_bytes(path, maximum=MAX_INPUT):
    # Bounded read before JSON parsing; never include a local path in errors.
    try:
        with Path(path).open("rb") as stream:
            raw = stream.read(maximum + 1)
    except OSError:
        raise MuseumError("input file unavailable") from None
    require(0 < len(raw) <= maximum, "input file byte bound")
    return raw


def pinned(path, expected):
    require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected), "SHA-256 pin format")
    raw = read_bytes(path)
    require(sha(raw) == expected, "input SHA-256 mismatch")
    return loads(raw, maximum=MAX_INPUT), raw


def address(value):
    hex_bytes(value, 20)
    require(value != "0x" + "00" * 20, "zero deployment address")
    return value


def abi_type(row):
    kind = row["type"]
    if kind.startswith("tuple"):
        return "(" + ",".join(abi_type(r) for r in row["components"]) + ")" + kind[5:]
    require(isinstance(kind, str) and len(kind) <= 128, "ABI type bound")
    return kind


def read_plan(artifact):
    abi = artifact["abi"]
    require(isinstance(abi, list) and len(abi) <= 4096, "artifact ABI bound")
    methods = artifact.get("methodIdentifiers", {})
    require(isinstance(methods, dict), "compiler method identifiers missing")
    views, events = {}, {}
    for row in abi:
        require(isinstance(row, dict), "ABI entry shape")
        if row.get("type") not in ("function", "event"):
            continue
        signature = row["name"] + "(" + ",".join(abi_type(r) for r in row["inputs"]) + ")"
        if row["type"] == "function" and signature in VIEWS:
            require(signature not in views, "duplicate monitored ABI function")
            require(row.get("stateMutability") in ("view", "pure"), "monitored ABI function is not read-only")
            require(tuple(abi_type(r) for r in row["outputs"]) == VIEWS[signature], "monitored ABI outputs differ")
            selector = keccak256(signature.encode("ascii"))[2:10]
            require(methods.get(signature) == selector, "compiler selector absent or inconsistent")
            views[signature] = "0x" + selector
        if row["type"] == "event" and row["name"] in EVENT_NAMES and not row.get("anonymous", False):
            topic = keccak256(signature.encode("ascii"))
            require(topic not in events, "duplicate monitored ABI event")
            indexed = sum(bool(r.get("indexed")) for r in row["inputs"])
            require(indexed <= 3, "event indexed argument bound")
            events[topic] = {"signature": signature, "topicCount": 1 + indexed}
    return dict(sorted(views.items())), dict(sorted(events.items()))


class Inputs:
    """Adapter for existing capture evidence, with optional canonical role binding.

    This is deliberately not a new deployment manifest or a replacement for the
    canonical candidate validator. A native product inventory alone is rejected.
    """

    def __init__(self, *, anchor_path, anchor_sha256, evidence_path, native_path,
                 profile_path, profile_sha256, candidate_path=None, candidate_sha256=None):
        try:
            self._load(anchor_path, anchor_sha256, evidence_path, native_path,
                       profile_path, profile_sha256, candidate_path, candidate_sha256)
        except (KeyError, TypeError, AttributeError, IndexError, UnicodeError):
            raise MuseumError("unsupported or malformed monitoring input") from None

    def _load(self, anchor_path, anchor_sha256, evidence_path, native_path,
              profile_path, profile_sha256, candidate_path, candidate_sha256):
        anchor, _ = pinned(anchor_path, anchor_sha256)
        require(isinstance(anchor, dict), "anchor object required")
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
            hex_bytes(anchor[key], 32)
        for key in ("chainId", "blockNumber", "timestamp"):
            uint(anchor[key])
        require(uint(anchor["chainId"]) > 0, "zero chain ID")
        address(anchor["core"])
        require(isinstance(anchor["environment"], str) and re.fullmatch(r"[A-Za-z0-9_-]{1,80}", anchor["environment"]),
                "anchor environment format")
        evidence_raw = read_bytes(evidence_path)
        require(keccak256(evidence_raw) == anchor["deploymentEvidenceHash"], "deployment evidence commitment mismatch")
        evidence = loads(evidence_raw, maximum=MAX_INPUT)
        native, native_raw = pinned(native_path, evidence["nativeInputManifestSha256"])
        require(native["mode"] == NATIVE_MODE, "unsupported native input format")
        require(isinstance(native["products"], dict) and len(native["products"]) <= MAX_PRODUCTS,
                "native product bound")
        rows = evidence["artifacts"]
        require(isinstance(rows, dict) and 0 < len(rows) <= MAX_PRODUCTS, "actual deployment artifact rows required")
        products = {}
        for name, row in sorted(rows.items()):
            require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", name), "artifact name format")
            native_row = native["products"][name]
            require(all(row[k] == native_row[k] for k in ("source", "artifact", "sha256")),
                    "deployed artifact differs from native input")
            artifact, _ = pinned(native_row["artifact"], native_row["sha256"])
            require(artifact["metadata"]["settings"]["compilationTarget"] == {row["source"]: name},
                    "compiler source identity differs")
            target = address(row["address"])
            require(target not in products, "duplicate deployed artifact address")
            hex_bytes(row["runtimeHash"], 32)
            require(0 < uint(row["runtimeBytes"]) <= 1048576, "deployed runtime size bound")
            views, events = read_plan(artifact)
            products[target] = {"name": name, "source": row["source"], "artifactSha256": row["sha256"],
                                "runtimeHash": row["runtimeHash"], "runtimeBytes": row["runtimeBytes"],
                                "views": views, "events": events}
        require(anchor["core"] in products and products[anchor["core"]]["name"] == "StreamCore",
                "anchor Core is not the captured Core artifact")
        pins = anchor["codePins"]
        require(isinstance(pins, list) and 0 < len(pins) <= MAX_PINS, "anchor code pin bound")
        extra_pins = {}
        seen = set()
        for pin in pins:
            target = address(pin["address"])
            hex_bytes(pin["runtimeHash"], 32)
            require(target not in seen, "duplicate anchor code pin")
            seen.add(target)
            if target in products:
                require(pin["runtimeHash"] == products[target]["runtimeHash"], "anchor/evidence runtime pin conflict")
            else:
                extra_pins[target] = pin["runtimeHash"]
        require(anchor["core"] in seen, "Core missing from anchor code pins")
        profile, _ = pinned(profile_path, profile_sha256)
        require(profile["schema_version"] == PROFILE_SCHEMA, "unsupported genesis profile")
        entries = profile["entries"]
        require(isinstance(entries, list) and len(entries) == 37
                and all(type(e["id"]) is int for e in entries)
                and [e["id"] for e in entries] == list(range(1, 38))
                and len({e["key"] for e in entries}) == 37, "genesis role identity/order differs")
        roles = {entry["id"]: {"id": entry["id"], "key": entry["key"], "bindings": []} for entry in entries}
        candidate = None
        require(bool(candidate_path) == bool(candidate_sha256), "candidate path and external pin must be supplied together")
        if candidate_path:
            candidate, _ = pinned(candidate_path, candidate_sha256)
            require(candidate["schema_version"] == CANDIDATE_SCHEMA, "unsupported canonical candidate")
            require(candidate["genesis_profile"]["sha256"] == "sha256:" + profile_sha256
                    and candidate["genesis_profile"]["schema_version"] == PROFILE_SCHEMA
                    and candidate["genesis_profile"]["entry_count"] == 37, "candidate genesis profile differs")
            require(type(candidate["network"]["chain_id"]) is int
                    and candidate["network"]["chain_id"] == uint(anchor["chainId"]), "candidate chain differs from anchor")
            instances = candidate["instances"]
            require(isinstance(instances, list) and len(instances) <= MAX_PRODUCTS, "candidate instance bound")
            seen_instances = set()
            seen_addresses = set()
            for instance in instances:
                require(type(instance["profile_entry_id"]) is int, "candidate role ID type")
                role = roles[instance["profile_entry_id"]]
                require(instance["profile_entry_key"] == role["key"], "candidate role ID/key mismatch")
                target = address(instance["address"])
                require((role["id"], target) not in seen_instances, "duplicate candidate role binding")
                seen_instances.add((role["id"], target))
                require(target not in seen_addresses, "monitor requires distinct candidate role addresses")
                seen_addresses.add(target)
                implementation = entries[role["id"] - 1]["implementation"]
                if implementation["mode"] == "exact":
                    require(instance["target"]["name"] in implementation["names"], "candidate exact implementation differs")
                expected = instance["runtime"]["expected_keccak256"]
                hex_bytes(expected, 32)
                status = "not_in_capture"
                if target in products:
                    product = products[target]
                    require(product["name"] == instance["target"]["name"]
                            and product["source"] == instance["target"]["source"]
                            and "sha256:" + product["artifactSha256"] == instance["target"]["artifact_sha256"]
                            and product["runtimeHash"] == expected, "candidate/capture artifact or runtime conflict")
                    status = "captured"
                role["bindings"].append({"address": target, "expectedRuntimeHash": expected, "captureStatus": status})
        for entry in entries:
            role = roles[entry["id"]]
            role["minimum"] = entry["multiplicity"]["minimum"]
            role["maximum"] = entry["multiplicity"]["maximum"]
            require(type(role["minimum"]) is int and role["minimum"] >= 1, "profile minimum multiplicity")
            require(type(role["maximum"]) is int and role["minimum"] <= role["maximum"] <= MAX_PRODUCTS,
                    "profile maximum multiplicity")
            role["bindings"].sort(key=lambda r: r["address"])
        self.anchor = anchor
        self.products = dict(sorted(products.items()))
        self.extra_pins = dict(sorted(extra_pins.items()))
        self.roles = list(roles.values())
        self.pins = {"anchorSha256": anchor_sha256, "deploymentEvidenceKeccak256": keccak256(evidence_raw),
                     "nativeManifestSha256": sha(native_raw), "genesisProfileSha256": profile_sha256,
                     "candidateSha256": candidate_sha256}


def reader_identity():
    modules = (Path(__file__), Path(transport_module.__file__), Path(canonical.__file__),
               Path(chain_abi.__file__), Path(chain_rpc.__file__))
    # Hash bytes, not platform text conversion. Same source bytes replay identically.
    return {p.name: sha(p.read_bytes()) for p in modules}


class Monitor:
    def __init__(self, inputs, transport):
        self.inputs = inputs
        self.reader = Recorder(transport)
        self.incidents = []
        self.event_positions = set()
        self.block = {"blockHash": inputs.anchor["blockHash"], "requireCanonical": True}

    def incident(self, level, code, subject):
        identity = {"chainId": self.inputs.anchor["chainId"], "blockHash": self.block["blockHash"],
                    "level": level, "code": code, "subject": subject}
        self.incidents.append(identity | {"id": keccak256(dumps(identity))})

    def rpc(self, method, params, subject):
        try:
            return True, self.reader.request(method, params)
        except RpcFailure as exc:
            self.incident("unavailable", exc.code, subject)
            return False, None

    def block_check(self, method, params, phase):
        ok, value = self.rpc(method, params, phase)
        if not ok:
            return False
        try:
            require(isinstance(value, dict), "block unavailable")
            hex_bytes(value["hash"], 32)
            hex_bytes(value["stateRoot"], 32)
            actual = {"blockHash": value["hash"], "blockNumber": str(quantity(value["number"])),
                      "timestamp": str(quantity(value["timestamp"])), "stateRoot": value["stateRoot"]}
        except (MuseumError, KeyError, TypeError):
            self.incident("unavailable", "invalid_block_response", phase)
            return False
        matches = all(actual[k] == self.inputs.anchor[k] for k in actual)
        if not matches:
            self.incident("failure", "block_identity_mismatch", phase)
        return matches

    def runtime(self, target, expected, expected_size=None):
        ok, value = self.rpc("eth_getCode", [target, self.block], target + ":runtime")
        result = {"address": target, "expectedRuntimeHash": expected, "status": "unavailable"}
        if not ok:
            return result
        try:
            code = hex_bytes(value)
        except MuseumError:
            self.incident("unavailable", "invalid_runtime_response", target)
            return result
        result.update({"observedRuntimeHash": keccak256(code), "observedRuntimeBytes": str(len(code))})
        valid = bool(code) and keccak256(code) == expected and (expected_size is None or len(code) == uint(expected_size))
        result["status"] = "matched" if valid else "mismatch"
        if not valid:
            self.incident("failure", "runtime_mismatch", target)
        return result

    def views(self, target, product, runtime_ok):
        rows = []
        for signature, selector in product["views"].items():
            row = {"signature": signature, "selector": selector, "status": "unavailable"}
            rows.append(row)
            if not runtime_ok:
                row["reason"] = "runtime_not_verified"
                continue
            ok, value = self.rpc("eth_call", [{"to": target, "data": selector, "gas": "0xf4240"}, self.block],
                                 target + ":" + signature)
            if not ok:
                continue
            try:
                values = decode(VIEWS[signature], hex_bytes(value), maximum=128)
            except MuseumError:
                self.incident("unavailable", "invalid_view_response", target + ":" + signature)
                continue
            # Integers use canonical decimal strings, preserving uint256 exactly.
            row.update({"status": "observed", "values": [str(v) if type(v) is int else v for v in values]})
            if ((signature == "paused()" and values[0])
                    or (signature == "genesisInitialized()" and not values[0])
                    or (signature == "incompleteFinalityRecoveryRefreshPlanCount()" and values[0] > 0)):
                self.incident("attention", "state_requires_operator_review", target + ":" + signature)
        return rows

    def events(self, target, product, runtime_ok):
        topics = product["events"]
        if not topics:
            return {"status": "unsupported", "events": []}
        if not runtime_ok:
            return {"status": "unavailable", "reason": "runtime_not_verified", "events": []}
        ok, logs = self.rpc("eth_getLogs", [{"blockHash": self.block["blockHash"], "address": target,
                                           "topics": [list(topics)]}], target + ":events")
        if not ok:
            return {"status": "unavailable", "events": []}
        try:
            require(isinstance(logs, list) and len(logs) <= MAX_LOGS, "event result bound")
            rows, seen = [], set()
            for log in logs:
                require(isinstance(log, dict) and log["removed"] is False, "removed event")
                require(log["address"] == target and log["blockHash"] == self.block["blockHash"]
                        and str(quantity(log["blockNumber"])) == self.inputs.anchor["blockNumber"], "event block/address mismatch")
                hex_bytes(log["transactionHash"], 32)
                index = quantity(log["logIndex"])
                tx_index = quantity(log["transactionIndex"])
                require(index not in seen, "duplicate event index")
                require(index not in self.event_positions, "event index reused across products")
                seen.add(index)
                event_topics = log["topics"]
                require(isinstance(event_topics, list) and 1 <= len(event_topics) <= 4, "event topics bound")
                for topic in event_topics:
                    hex_bytes(topic, 32)
                definition = topics[event_topics[0]]
                require(len(event_topics) == definition["topicCount"], "event indexed shape differs")
                data = hex_bytes(log["data"])
                require(len(data) % 32 == 0 and len(data) <= 32768, "event data bound/alignment")
                identity = {"chainId": self.inputs.anchor["chainId"], "blockHash": log["blockHash"],
                            "transactionHash": log["transactionHash"], "logIndex": str(index), "address": target}
                rows.append(identity | {"id": keccak256(dumps(identity)), "transactionIndex": str(tx_index),
                                        "signature": definition["signature"], "topics": event_topics, "payloadDecoded": False,
                                        "dataKeccak256": keccak256(data)})
            rows.sort(key=lambda r: int(r["logIndex"]))
        except (MuseumError, KeyError, TypeError, IndexError):
            self.incident("failure", "invalid_event_response", target)
            return {"status": "invalid", "events": []}
        self.event_positions.update(seen)
        return {"status": "observed", "events": rows}

    def check_event_transactions(self, products):
        """Check the selected logs jointly; no claim to have the full receipt set."""
        rows = sorted((event for product in products for event in product["events"]["events"]),
                      key=lambda event: int(event["logIndex"]))
        by_index, by_hash, last_index = {}, {}, -1
        for event in rows:
            index, tx_hash = int(event["transactionIndex"]), event["transactionHash"]
            if (by_index.get(index, tx_hash) != tx_hash or by_hash.get(tx_hash, index) != index
                    or index < last_index):
                self.incident("failure", "event_transaction_identity_mismatch", "block:events")
                for product in products:
                    if product["events"]["events"]:
                        product["events"]["status"] = "invalid"
                        product["events"]["reason"] = "block_transaction_identity_inconsistent"
                return
            by_index[index], by_hash[tx_hash], last_index = tx_hash, index, index

    def run(self):
        anchor = self.inputs.anchor
        ok, chain = self.rpc("eth_chainId", [], "chain")
        chain_ok = False
        if ok:
            try:
                chain_ok = str(quantity(chain)) == anchor["chainId"]
                if not chain_ok:
                    self.incident("failure", "chain_identity_mismatch", "chain")
            except MuseumError:
                self.incident("unavailable", "invalid_chain_response", "chain")
        hash_ok = self.block_check("eth_getBlockByHash", [anchor["blockHash"], False], "block_by_hash")
        before_ok = self.block_check("eth_getBlockByNumber", [hex(uint(anchor["blockNumber"])), False], "canonical_before")
        identity_ok = chain_ok and hash_ok and before_ok
        products, runtime_by_address = [], {}
        for target, product in self.inputs.products.items():
            if identity_ok:
                runtime = self.runtime(target, product["runtimeHash"], product["runtimeBytes"])
            else:
                runtime = {"address": target, "expectedRuntimeHash": product["runtimeHash"],
                           "status": "unavailable", "reason": "anchor_not_verified"}
            runtime_by_address[target] = runtime
            runtime_ok = runtime["status"] == "matched"
            products.append({"name": product["name"], "source": product["source"],
                             "artifactSha256": product["artifactSha256"], "runtime": runtime,
                             "views": self.views(target, product, runtime_ok),
                             "unsupportedViews": sorted(set(VIEWS) - set(product["views"])),
                             "events": self.events(target, product, runtime_ok)})
        self.check_event_transactions(products)
        extra = []
        for target, expected in self.inputs.extra_pins.items():
            extra.append(self.runtime(target, expected) if identity_ok else {
                "address": target, "expectedRuntimeHash": expected, "status": "unavailable", "reason": "anchor_not_verified"})
        roles = []
        for role in self.inputs.roles:
            bindings = [r | {"runtimeStatus": runtime_by_address.get(r["address"], {}).get("status", "unavailable")}
                        for r in role["bindings"]]
            complete = role["minimum"] <= len(bindings) <= role["maximum"] and all(
                r["captureStatus"] == "captured" and r["runtimeStatus"] == "matched" for r in bindings)
            roles.append(role | {"bindings": bindings, "status": "observed" if complete else "unavailable"})
            if not complete:
                self.incident("unavailable", "role_coverage_incomplete", "role:" + str(role["id"]))
        after_ok = self.block_check("eth_getBlockByNumber", [hex(uint(anchor["blockNumber"])), False], "canonical_after")
        # Reorg or late RPC failure invalidates the report's common-block coherence,
        # even if individual earlier reads matched their pinned expectations.
        coherent = identity_ok and after_ok
        levels = {r["level"] for r in self.incidents}
        outcome = ("failure" if "failure" in levels else "attention" if "attention" in levels
                   else "incomplete" if "unavailable" in levels else "observed")
        transcript = self.reader.transcript()
        report = {"schema": "6529stream.current-health.v1", "outcome": outcome,
                  "coherentBlock": coherent, "inputs": self.inputs.pins, "readerSources": reader_identity(),
                  "anchor": {k: anchor[k] for k in ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")},
                  "transcriptSha256": sha(transcript), "roles": roles, "products": products, "additionalCodePins": extra,
                  "incidents": sorted(self.incidents, key=lambda r: (r["subject"], r["code"], r["id"])),
                  "limits": {"stateProofVerified": False, "consensusFinalityVerified": False,
                             "releaseReadinessVerified": False, "canonicalCandidateValidated": False,
                             "eventScope": "selected ABI events in the anchor block only",
                             "policyScope": "observed values; no approved-policy baseline or historical comparison",
                             "roleScope": "explicit candidate bindings to captured artifacts only",
                             "pauseScope": "ABI-advertised paused() only; no inferred Dutch or per-sale pause state"}}
        return dumps(report), transcript


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    for name in ("anchor", "anchor-sha256", "deployment-evidence", "native-manifest", "genesis-profile", "genesis-profile-sha256"):
        result.add_argument("--" + name, required=True)
    result.add_argument("--candidate")
    result.add_argument("--candidate-sha256")
    mode = result.add_mutually_exclusive_group(required=True)
    mode.add_argument("--endpoint-env", help="name of an environment variable containing the RPC URL")
    mode.add_argument("--replay", help="exact retained monitor transcript")
    result.add_argument("--replay-sha256")
    result.add_argument("--output", required=True, help="new output directory; existing directories are refused")
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        require(bool(args.replay) == bool(args.replay_sha256), "replay path and pin must be supplied together")
        inputs = Inputs(anchor_path=args.anchor, anchor_sha256=args.anchor_sha256,
                        evidence_path=args.deployment_evidence, native_path=args.native_manifest,
                        profile_path=args.genesis_profile, profile_sha256=args.genesis_profile_sha256,
                        candidate_path=args.candidate, candidate_sha256=args.candidate_sha256)
        if args.replay:
            transport = Replay(read_bytes(args.replay), args.replay_sha256)
        else:
            require(args.endpoint_env in os.environ, "RPC environment variable unavailable")
            transport = HttpTransport(os.environ[args.endpoint_env])
        report, transcript = Monitor(inputs, transport).run()
        if args.replay:
            transport.finish()
        else:
            replay = Replay(transcript, sha(transcript))
            replayed, replay_transcript = Monitor(inputs, replay).run()
            replay.finish()
            require((replayed, replay_transcript) == (report, transcript), "internal offline replay differs")
        output = Path(args.output)
        output.mkdir(parents=True, exist_ok=False)
        output.joinpath("report.json").write_bytes(report)
        output.joinpath("transcript.json").write_bytes(transcript)
        output.joinpath("pins.json").write_bytes(dumps({"reportSha256": sha(report), "transcriptSha256": sha(transcript)}))
        outcome = loads(report, maximum=MAX_INPUT)["outcome"]
        print("monitor: " + outcome + "; report SHA-256 " + sha(report))
        return 0 if outcome == "observed" else 2
    except MuseumError as exc:
        # These are fixed local diagnostics, never URL/path/remote error text.
        print("monitor rejected: " + str(exc), file=sys.stderr)
        return 1
    except OSError:
        print("monitor input/output rejected; verify pins, supported formats and output directory", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
