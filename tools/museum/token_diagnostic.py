"""Task-owned local Anvil checkpoints for helper diagnosis, never capture acceptance."""
import hashlib
from pathlib import Path

from .canonical import dumps, keccak256, loads
from .independent_wire import require

FIELDS = (
    "addresses", "artifact_rows", "receipts", "safe_accounts", "safe_components", "account",
    "governor", "attestor", "deployment", "schemas", "store", "token_action_policies",
    "token_suite", "token_artist_safe", "token_platform_safe", "token_protocol_safe", "token_buyer",
    "token_split_profile", "token_split_wallet", "token_entropy_qualification", "token_entropy_evidence",
    "token_artist_authorization_nonce", "token_artist_evidence", "token_initial_phase_policy",
    "token_mint_policy", "token_primary_policy", "token_chain_id",
)
MAXIMUM = 128 * 1024 * 1024


def checkpoint(fixture, directory):
    directory = Path(directory)
    require(not directory.exists(), "diagnostic checkpoint already exists")
    block = fixture.rpc("eth_getBlockByNumber", ["latest", False])
    state = dumps({"state": fixture.rpc("anvil_dumpState", [])})
    context = dumps({name: getattr(fixture, name) for name in FIELDS if hasattr(fixture, name)})
    require(len(state) <= MAXIMUM and len(context) <= MAXIMUM, "diagnostic checkpoint byte bound")
    manifest = dumps({"mode": "local_token_helper_diagnostic_checkpoint", "acceptanceEvidence": False,
        "chainId": fixture.rpc("eth_chainId", []), "blockHash": block["hash"], "blockNumber": block["number"],
        "stateHash": keccak256(state), "contextHash": keccak256(context),
        "nativeManifestSha256": hashlib.sha256(fixture.manifest_raw).hexdigest(),
        "qualification": "Exact task-owned local Anvil state and public fixture context. Restore is for helper diagnosis only; final capture must start with a fresh deployment."})
    directory.mkdir(parents=True)
    (directory / "state.json").write_bytes(state)
    (directory / "context.json").write_bytes(context)
    (directory / "manifest.json").write_bytes(manifest)
    return keccak256(manifest)


def restore(fixture, directory, manifest_hash):
    """Restore only to the caller's fresh loopback Anvil, with an external pin."""
    directory = Path(directory)
    raw = (directory / "manifest.json").read_bytes()
    require(keccak256(raw) == manifest_hash, "diagnostic checkpoint manifest pin differs")
    manifest = loads(raw, maximum=65536, canonical=True)
    require(manifest["mode"] == "local_token_helper_diagnostic_checkpoint"
        and manifest["acceptanceEvidence"] is False
        and manifest["nativeManifestSha256"] == hashlib.sha256(fixture.manifest_raw).hexdigest(),
        "diagnostic checkpoint origin differs")
    require(fixture.rpc("eth_chainId", []) == manifest["chainId"] == "0x7a69"
        and fixture.rpc("eth_blockNumber", []) == "0x0" and not fixture.receipts,
        "diagnostic restore requires fresh task-owned local chain")
    def read(name, pin):
        path = directory / name
        require(path.stat().st_size <= MAXIMUM, "diagnostic checkpoint byte bound")
        value = path.read_bytes()
        require(keccak256(value) == pin, "diagnostic checkpoint input pin differs")
        return loads(value, maximum=MAXIMUM, canonical=True)
    state = read("state.json", manifest["stateHash"])
    context = read("context.json", manifest["contextHash"])
    require(set(context) <= set(FIELDS) and {"addresses", "receipts", "token_primary_policy"} <= set(context),
        "diagnostic checkpoint context differs")
    require(fixture.rpc("anvil_loadState", [state["state"]]) is True, "diagnostic state restore failed")
    block = fixture.rpc("eth_getBlockByNumber", ["latest", False])
    require((block["hash"], block["number"]) == (manifest["blockHash"], manifest["blockNumber"]),
        "diagnostic restored block differs")
    for name, value in context.items(): setattr(fixture, name, value)
    fixture.token_suite = tuple(fixture.token_suite)
    fixture.diagnostic_restore = manifest_hash
    return manifest
