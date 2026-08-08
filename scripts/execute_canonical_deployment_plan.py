#!/usr/bin/env python3
"""Execute canonical target-isolated initcode and verify retained chain state.

The v1 executor is intentionally limited to non-production candidates. It
materializes the current plan again, requires the on-disk plan to match byte
for byte, simulates every entry, broadcasts each entry through a generic
production-import-free Solidity script, and verifies the actual transaction
input, receipt, and runtime code through JSON-RPC before writing a receipt.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

import materialize_canonical_deployment_plan as materializer


EXECUTION_SCHEMA = "6529stream.canonical-deployment-execution.v1"
JOURNAL_SCHEMA = "6529stream.canonical-deployment-execution-journal.v1"
GENERATOR_VERSION = "1"
DEFAULT_PLAN = Path("tmp/canonical-deployment-plan.json")
DEFAULT_OUTPUT = Path("tmp/canonical-deployment-execution-receipt.json")
DEFAULT_SCRIPT = Path("deployment-script/DeployCanonicalInitcode.s.sol")
DEFAULT_FOUNDRY_CONFIG = Path("deployment-script/foundry.toml")
EXECUTOR_DRIVER_PATH = Path("scripts/execute_canonical_deployment_plan.py")
EXECUTION_SCHEMA_PATH = Path(
    "deployments/schema/canonical-deployment-execution.schema.json"
)
STAGING_ROOT = Path("deployments/.canonical-deployment-run")
SESSION_ROOT = Path("tmp/canonical-deployment-run")
NON_PRODUCTION_STATUSES = frozenset({"non_production_tooling_only"})
FINAL_JOURNAL_STATUS = "verified"
EXECUTION_MODES = frozenset({"anvil", "local", "fork", "sepolia", "production"})
SIGNER_MODES = frozenset({"unlocked", "ledger", "trezor", "keystore"})
RETRY_SAFE_JOURNAL_STATUSES = frozenset(
    {"preflight", "failed_preflight"}
)
SEPOLIA_CHAIN_ID = 11155111
LOCAL_ANVIL_CHAIN_ID = 31337
HEX_HASH_LENGTH = 66
RPC_QUANTITY_RE = re.compile(r"^0x(?:0|[1-9a-f][0-9a-f]*)$")
SAFE_CHILD_ENVIRONMENT = frozenset(
    {
        "APPDATA",
        "COMSPEC",
        "COMMONPROGRAMFILES",
        "COMMONPROGRAMFILES(X86)",
        "COMMONPROGRAMW6432",
        "HOME",
        "HOMEDRIVE",
        "HOMEPATH",
        "LANG",
        "LC_ALL",
        "LOCALAPPDATA",
        "PATH",
        "PATHEXT",
        "PROGRAMDATA",
        "PROGRAMFILES",
        "PROGRAMFILES(X86)",
        "PROGRAMW6432",
        "SSL_CERT_DIR",
        "SSL_CERT_FILE",
        "SYSTEMROOT",
        "SYSTEMDRIVE",
        "TEMP",
        "TMP",
        "TMPDIR",
        "USERPROFILE",
        "USERNAME",
        "WINDIR",
    }
)


class CanonicalExecutionError(RuntimeError):
    """Raised when canonical deployment cannot proceed fail closed."""


CommandRunner = Callable[
    [Sequence[str], Path, Mapping[str, str]],
    subprocess.CompletedProcess[str],
]
RpcCaller = Callable[[str, Sequence[Any]], Any]
HostResolver = Callable[..., Sequence[tuple[Any, ...]]]
PUBLIC_RPC_RESOLUTION_POLICY = "all_public_unchanged_before_request_v1"
JOURNAL_IDENTITY_FIELDS = (
    "schema_version",
    "execution_key",
    "plan_sha256",
    "candidate_id",
    "release_receipt_sha256",
    "target_catalog_sha256",
    "release_config_sha256",
    "release_foundry_config_sha256",
    "executor_script_sha256",
    "executor_foundry_config_sha256",
    "executor_driver_sha256",
    "execution_schema_sha256",
    "network",
    "chain_id",
    "sender",
    "deployment_authority",
)


def prefixed_sha256(raw: bytes) -> str:
    return materializer.sha256_bytes(raw)


def require_dict(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CanonicalExecutionError(f"{field} must be an object")
    return value


def require_list(value: Any, field: str) -> list[Any]:
    if not isinstance(value, list):
        raise CanonicalExecutionError(f"{field} must be an array")
    return value


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise CanonicalExecutionError(f"{field} must be a non-empty string")
    return value


def require_integer(value: Any, field: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise CanonicalExecutionError(f"{field} must be an integer")
    return value


def require_repo_path(value: Any, field: str) -> str:
    """Apply the canonical materializer's exact portable repository-path policy."""
    try:
        return materializer.require_safe_relative_path(value, field)
    except materializer.DeploymentPlanError as exc:
        raise CanonicalExecutionError(str(exc)) from exc


def require_hex(value: Any, field: str, *, bytes_length: int | None = None) -> str:
    text = require_string(value, field)
    if not materializer.HEX_RE.fullmatch(text):
        raise CanonicalExecutionError(f"{field} must be even-length 0x-prefixed hex")
    if bytes_length is not None and len(text) != 2 + (2 * bytes_length):
        raise CanonicalExecutionError(f"{field} must encode {bytes_length} bytes")
    return text.lower()


def require_hash(value: Any, field: str) -> str:
    text = require_string(value, field).lower()
    if len(text) != HEX_HASH_LENGTH or not materializer.KECCAK_RE.fullmatch(text):
        raise CanonicalExecutionError(f"{field} must be a 32-byte 0x-prefixed hash")
    return text


def require_address(value: Any, field: str) -> str:
    text = require_string(value, field)
    if not materializer.ADDRESS_RE.fullmatch(text):
        raise CanonicalExecutionError(f"{field} must be an Ethereum address")
    return text.lower()


def normalize_rpc_quantity(value: Any, field: str) -> int:
    text = require_string(value, field).lower()
    if not RPC_QUANTITY_RE.fullmatch(text):
        raise CanonicalExecutionError(f"{field} must be a JSON-RPC hex quantity")
    try:
        return int(text, 16)
    except ValueError as exc:
        raise CanonicalExecutionError(
            f"{field} must be a JSON-RPC hex quantity"
        ) from exc


def is_loopback_rpc_url(rpc_url: str) -> bool:
    try:
        parsed = urlparse(rpc_url)
        host = parsed.hostname
    except ValueError:
        return False
    if parsed.scheme not in {"http", "https"} or host is None:
        return False
    normalized_host = host.rstrip(".").casefold()
    if normalized_host == "localhost":
        return True
    try:
        address = ipaddress.ip_address(normalized_host)
    except ValueError:
        try:
            address = ipaddress.ip_address(socket.inet_aton(normalized_host))
        except OSError:
            return False
    if address.is_loopback:
        return True
    mapped = getattr(address, "ipv4_mapped", None)
    return mapped is not None and mapped.is_loopback


def normalize_ip_address(value: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address:
    """Return one canonical address, collapsing IPv4-mapped IPv6 aliases."""
    try:
        address = ipaddress.ip_address(value.split("%", 1)[0])
    except ValueError as exc:
        raise CanonicalExecutionError(
            "RPC hostname resolution returned a non-IP address"
        ) from exc
    mapped = getattr(address, "ipv4_mapped", None)
    return mapped if mapped is not None else address


def parse_rpc_endpoint(rpc_url: str) -> tuple[str, int]:
    try:
        parsed = urlparse(rpc_url)
        host = parsed.hostname
        port = parsed.port
    except ValueError as exc:
        raise CanonicalExecutionError("RPC URL has an invalid hostname or port") from exc
    if parsed.scheme not in {"http", "https"} or host is None:
        raise CanonicalExecutionError("RPC URL must use http or https with a hostname")
    normalized_host = host.rstrip(".").casefold()
    if not normalized_host:
        raise CanonicalExecutionError("RPC URL must contain a hostname")
    return normalized_host, port or (443 if parsed.scheme == "https" else 80)


def require_public_rpc_address(
    address: ipaddress.IPv4Address | ipaddress.IPv6Address,
) -> str:
    if (
        not address.is_global
        or address.is_loopback
        or address.is_unspecified
        or address.is_link_local
        or address.is_multicast
        or address.is_reserved
    ):
        raise CanonicalExecutionError(
            "live Sepolia RPC resolution must contain only globally routable "
            "unicast addresses"
        )
    return address.compressed.casefold()


def resolve_public_rpc_addresses(
    rpc_url: str,
    *,
    resolver: HostResolver | None = None,
) -> tuple[str, ...]:
    """Resolve and normalize the all-public address set for a live RPC URL."""
    host, port = parse_rpc_endpoint(rpc_url)
    if host == "localhost":
        raise CanonicalExecutionError(
            "live Sepolia RPC resolution rejects localhost"
        )

    literal: ipaddress.IPv4Address | ipaddress.IPv6Address | None = None
    try:
        literal = normalize_ip_address(host)
    except CanonicalExecutionError:
        try:
            packed = socket.inet_aton(host)
            literal = ipaddress.ip_address(packed)
        except (OSError, ValueError):
            literal = None
    if literal is not None:
        return (require_public_rpc_address(literal),)

    resolver = resolver or socket.getaddrinfo
    try:
        answers = resolver(host, port, socket.AF_UNSPEC, socket.SOCK_STREAM)
    except OSError as exc:
        raise CanonicalExecutionError(
            "live Sepolia RPC hostname resolution failed"
        ) from exc
    addresses: set[str] = set()
    for answer in answers:
        if not isinstance(answer, tuple) or len(answer) != 5:
            raise CanonicalExecutionError(
                "RPC hostname resolution returned malformed address metadata"
            )
        family, _, _, _, socket_address = answer
        if family not in {socket.AF_INET, socket.AF_INET6}:
            raise CanonicalExecutionError(
                "RPC hostname resolution returned a non-IP address family"
            )
        if not isinstance(socket_address, tuple) or not socket_address:
            raise CanonicalExecutionError(
                "RPC hostname resolution returned malformed socket metadata"
            )
        addresses.add(
            require_public_rpc_address(
                normalize_ip_address(require_string(socket_address[0], "resolved address"))
            )
        )
    if not addresses:
        raise CanonicalExecutionError(
            "live Sepolia RPC hostname resolution returned no addresses"
        )
    return tuple(
        sorted(
            addresses,
            key=lambda item: (
                ipaddress.ip_address(item).version,
                ipaddress.ip_address(item).packed,
            ),
        )
    )


def assert_rpc_resolution_unchanged(
    rpc_url: str,
    pinned_addresses: Sequence[str],
    *,
    resolver: HostResolver | None = None,
) -> None:
    expected = tuple(pinned_addresses)
    current = resolve_public_rpc_addresses(rpc_url, resolver=resolver)
    if current != expected:
        raise CanonicalExecutionError(
            "live Sepolia RPC resolution changed after authorization"
        )


def resolution_guarded_rpc(
    rpc: RpcCaller,
    rpc_url: str,
    pinned_addresses: Sequence[str],
    *,
    resolver: HostResolver | None = None,
) -> RpcCaller:
    """Re-resolve immediately before each executor-owned JSON-RPC request."""

    def call(method: str, params: Sequence[Any]) -> Any:
        assert_rpc_resolution_unchanged(
            rpc_url,
            pinned_addresses,
            resolver=resolver,
        )
        return rpc(method, params)

    return call


def pinned_rpc_addresses(network: Mapping[str, Any]) -> tuple[str, ...] | None:
    if network.get("execution_mode") != "sepolia":
        return None
    resolution = require_dict(network.get("rpc_resolution"), "network.rpc_resolution")
    if resolution.get("policy") != PUBLIC_RPC_RESOLUTION_POLICY:
        raise CanonicalExecutionError("live Sepolia RPC resolution policy is missing")
    if resolution.get("actual_peer_verified") is not False:
        raise CanonicalExecutionError(
            "executor must not claim live RPC peer verification"
        )
    addresses = tuple(
        require_string(value, f"network.rpc_resolution.resolved_addresses[{index}]")
        for index, value in enumerate(
            require_list(
                resolution.get("resolved_addresses"),
                "network.rpc_resolution.resolved_addresses",
            )
        )
    )
    if not addresses:
        raise CanonicalExecutionError("live Sepolia RPC resolution set is empty")
    normalized = tuple(
        sorted(
            {
                require_public_rpc_address(normalize_ip_address(value))
                for value in addresses
            },
            key=lambda item: (
                ipaddress.ip_address(item).version,
                ipaddress.ip_address(item).packed,
            ),
        )
    )
    if addresses != normalized:
        raise CanonicalExecutionError(
            "live Sepolia RPC resolution set is not exact normalized evidence"
        )
    return addresses


def execution_network_record(
    plan: Mapping[str, Any],
    *,
    rpc_url: str,
    execution_mode: str,
    live_broadcast_authorized: bool,
    ephemeral_local: bool,
    resolver: HostResolver | None = None,
) -> dict[str, Any]:
    """Bind the operator-selected execution mode to a safe RPC scope."""
    if execution_mode not in EXECUTION_MODES:
        raise CanonicalExecutionError(
            f"unsupported execution mode {execution_mode!r}"
        )
    network = require_dict(plan.get("network"), "network")
    environment = require_string(network.get("environment"), "network.environment")
    chain_id = require_integer(network.get("chain_id"), "network.chain_id")
    posture = require_dict(plan.get("release_posture"), "release_posture")
    production_candidate = posture.get("production_candidate") is True
    loopback = is_loopback_rpc_url(rpc_url)

    if execution_mode == "anvil":
        if environment != "anvil" or chain_id != LOCAL_ANVIL_CHAIN_ID:
            raise CanonicalExecutionError(
                "anvil mode requires an anvil plan on chain 31337"
            )
        if not ephemeral_local or not loopback:
            raise CanonicalExecutionError(
                "anvil mode requires --local-anvil and a loopback RPC"
            )
        rpc_scope = "ephemeral_loopback_anvil"
    elif execution_mode == "local":
        if (
            environment != "local"
            or chain_id != LOCAL_ANVIL_CHAIN_ID
            or not loopback
            or ephemeral_local
        ):
            raise CanonicalExecutionError(
                "local mode requires a local chain-31337 plan and an "
                "operator-supplied loopback RPC"
            )
        rpc_scope = "operator_loopback_local"
    elif execution_mode == "fork":
        if (
            environment != "fork"
            or chain_id != LOCAL_ANVIL_CHAIN_ID
            or not loopback
            or ephemeral_local
        ):
            raise CanonicalExecutionError(
                "fork mode requires a fork chain-31337 plan and an "
                "operator-supplied loopback RPC"
            )
        rpc_scope = "operator_loopback_fork"
    elif execution_mode == "sepolia":
        if environment != "testnet" or chain_id != SEPOLIA_CHAIN_ID:
            raise CanonicalExecutionError(
                "sepolia mode requires a testnet plan on chain 11155111"
            )
        if ephemeral_local or not live_broadcast_authorized:
            raise CanonicalExecutionError(
                "sepolia mode requires explicit --authorize-live-broadcast"
            )
        if loopback:
            raise CanonicalExecutionError(
                "sepolia mode rejects loopback and localhost RPC endpoints"
            )
        resolved_addresses = resolve_public_rpc_addresses(
            rpc_url,
            resolver=resolver,
        )
        rpc_scope = "authorized_live_sepolia"
    else:
        if not production_candidate:
            raise CanonicalExecutionError(
                "production mode refuses a non-production candidate"
            )
        raise CanonicalExecutionError(
            "production execution remains schema-blocked until issue #656 lands"
        )

    if live_broadcast_authorized and execution_mode != "sepolia":
        raise CanonicalExecutionError(
            "--authorize-live-broadcast is accepted only for sepolia in executor v1"
        )
    record: dict[str, Any] = {
        "environment": environment,
        "chain_id": chain_id,
        "execution_mode": execution_mode,
        "rpc_scope": rpc_scope,
    }
    if execution_mode == "sepolia":
        record["rpc_resolution"] = {
            "policy": PUBLIC_RPC_RESOLUTION_POLICY,
            "resolved_addresses": list(resolved_addresses),
            "actual_peer_verified": False,
        }
    return record


def signer_arguments(
    mode: str,
    *,
    keystore: Path | None = None,
    password_file: Path | None = None,
) -> list[str]:
    """Return reviewed Forge signer flags without accepting raw key material."""
    if mode not in SIGNER_MODES:
        raise CanonicalExecutionError(f"unsupported signer mode {mode!r}")
    if mode != "keystore" and (keystore is not None or password_file is not None):
        raise CanonicalExecutionError(
            "--keystore and --password-file require --signer keystore"
        )
    if mode == "keystore":
        if keystore is None:
            raise CanonicalExecutionError(
                "--signer keystore requires --keystore"
            )
        arguments = ["--keystore", str(keystore)]
        if password_file is not None:
            arguments.extend(["--password-file", str(password_file)])
        return arguments
    return {
        "unlocked": ["--unlocked"],
        "ledger": ["--ledger"],
        "trezor": ["--trezor"],
    }[mode]


def rlp_encode_bytes(value: bytes) -> bytes:
    if len(value) == 1 and value[0] < 0x80:
        return value
    if len(value) <= 55:
        return bytes([0x80 + len(value)]) + value
    length = len(value).to_bytes((len(value).bit_length() + 7) // 8, "big")
    return bytes([0xB7 + len(length)]) + length + value


def rlp_encode_list(values: Sequence[bytes]) -> bytes:
    payload = b"".join(values)
    if len(payload) <= 55:
        return bytes([0xC0 + len(payload)]) + payload
    length = len(payload).to_bytes((len(payload).bit_length() + 7) // 8, "big")
    return bytes([0xF7 + len(length)]) + length + payload


def create_address(sender: str, nonce: int) -> str:
    sender_bytes = bytes.fromhex(require_address(sender, "sender")[2:])
    if nonce < 0:
        raise CanonicalExecutionError("deployment nonce must not be negative")
    nonce_bytes = (
        b"" if nonce == 0 else nonce.to_bytes((nonce.bit_length() + 7) // 8, "big")
    )
    encoded = rlp_encode_list(
        [rlp_encode_bytes(sender_bytes), rlp_encode_bytes(nonce_bytes)]
    )
    return "0x" + materializer.keccak256_hex(encoded)[-40:]


def execution_key(plan_sha256: str, chain_id: int, sender: str) -> str:
    return prefixed_sha256(
        materializer.canonical_json_bytes(
            {
                "plan_sha256": plan_sha256,
                "chain_id": chain_id,
                "sender": require_address(sender, "sender"),
            }
        )
    ).removeprefix("sha256:")


def sender_lock_key(chain_id: int, sender: str) -> str:
    return prefixed_sha256(
        materializer.canonical_json_bytes(
            {
                "chain_id": chain_id,
                "sender": require_address(sender, "sender"),
            }
        )
    ).removeprefix("sha256:")


def acquire_execution_lock(
    session_parent: Path,
    lock_key: str,
    session_id: str,
) -> Path:
    lock_parent = session_parent / ".locks"
    lock_parent.mkdir(parents=True, exist_ok=True)
    lock_path = lock_parent / lock_key
    try:
        lock_path.mkdir()
    except FileExistsError as exc:
        raise CanonicalExecutionError(
            "another canonical execution is active or left a stale lock for "
            f"this repository-local chain/sender: {lock_path}"
        ) from exc
    write_json_atomic(
        lock_path / "owner.json",
        {"sender_lock_key": lock_key, "session_id": session_id},
    )
    return lock_path


def release_execution_lock(lock_path: Path) -> None:
    owner = lock_path / "owner.json"
    owner.unlink(missing_ok=True)
    try:
        lock_path.rmdir()
    except FileNotFoundError:
        return


def require_matching_journal_identity(
    journal: Mapping[str, Any],
    expected_identity: Mapping[str, Any],
    path: Path,
) -> None:
    for field in JOURNAL_IDENTITY_FIELDS:
        if field not in expected_identity or journal.get(field) != expected_identity[field]:
            raise CanonicalExecutionError(
                f"prior execution journal identity is malformed or changed at {field}: "
                f"{path}"
            )


def require_coherent_prebroadcast_journal(
    journal: Mapping[str, Any],
    path: Path,
) -> None:
    status = journal.get("status")
    allowed = set(JOURNAL_IDENTITY_FIELDS) | {
        "status",
        "success",
        "active_deployment",
        "verified_deployments",
        "rpc_preflight",
        "initial_nonce",
    }
    if status == "failed_preflight":
        allowed.update({"failure_type", "failure"})
    if set(journal) - allowed:
        raise CanonicalExecutionError(
            f"retry-safe pre-broadcast journal has unexpected state: {path}"
        )
    if (
        status not in RETRY_SAFE_JOURNAL_STATUSES
        or "success" not in journal
        or journal.get("success") is not False
        or "active_deployment" not in journal
        or journal.get("active_deployment") is not None
        or "verified_deployments" not in journal
        or journal.get("verified_deployments") != []
    ):
        raise CanonicalExecutionError(
            f"retry-safe pre-broadcast journal is incoherent: {path}"
        )
    if "rpc_preflight" in journal:
        evidence = require_dict(
            journal["rpc_preflight"],
            f"retry-safe journal {path}.rpc_preflight",
        )
        if (
            set(evidence)
            != {
                "block_number",
                "block_hash",
                "block_by_hash_verified",
                "eip_1898_get_code_verified",
            }
            or type(evidence.get("block_number")) is not int
            or evidence["block_number"] < 0
            or evidence["block_number"] > materializer.IJSON_SAFE_INTEGER_MAX
            or evidence.get("block_by_hash_verified") is not True
            or evidence.get("eip_1898_get_code_verified") is not True
        ):
            raise CanonicalExecutionError(
                f"retry-safe pre-broadcast journal has malformed RPC evidence: {path}"
            )
        require_hash(
            evidence.get("block_hash"),
            f"retry-safe journal {path}.rpc_preflight.block_hash",
        )
    if "initial_nonce" in journal and (
        type(journal["initial_nonce"]) is not int
        or journal["initial_nonce"] < 0
        or journal["initial_nonce"] > materializer.IJSON_SAFE_INTEGER_MAX
    ):
        raise CanonicalExecutionError(
            f"retry-safe pre-broadcast journal has malformed nonce evidence: {path}"
        )
    if status == "preflight" and (
        "failure_type" in journal or "failure" in journal
    ):
        raise CanonicalExecutionError(
            f"active preflight journal contains failure state: {path}"
        )
    if status == "failed_preflight" and (
        not isinstance(journal.get("failure_type"), str)
        or not journal.get("failure_type")
        or not isinstance(journal.get("failure"), str)
        or not journal.get("failure")
    ):
        raise CanonicalExecutionError(
            f"failed-preflight journal lacks exact failure state: {path}"
        )


def reject_ambiguous_journals(
    session_parent: Path,
    *,
    expected_identity: Mapping[str, Any],
) -> None:
    for field in JOURNAL_IDENTITY_FIELDS:
        if field not in expected_identity:
            raise CanonicalExecutionError(
                f"expected execution journal identity is missing {field}"
            )
    plan_sha256 = require_string(
        expected_identity.get("plan_sha256"),
        "expected journal plan_sha256",
    )
    chain_id = require_integer(
        expected_identity.get("chain_id"),
        "expected journal chain_id",
    )
    sender = require_address(
        expected_identity.get("sender"),
        "expected journal sender",
    )
    expected_key = require_string(
        expected_identity.get("execution_key"),
        "expected journal execution_key",
    )
    if not session_parent.exists():
        return
    for path in sorted(session_parent.glob("*/execution-journal.json")):
        try:
            value = materializer.decode_json_bytes(path.read_bytes(), path)
        except (OSError, materializer.DeploymentPlanError) as exc:
            raise CanonicalExecutionError(
                f"cannot safely classify prior execution journal {path}: {exc}"
            ) from exc
        journal = require_dict(value, f"execution journal {path}")
        exact_tuple = (
            journal.get("plan_sha256") == plan_sha256
            and journal.get("chain_id") == chain_id
            and journal.get("sender") == sender
        )
        if journal.get("execution_key") != expected_key and not exact_tuple:
            continue
        require_matching_journal_identity(journal, expected_identity, path)
        status = journal.get("status")
        if status in RETRY_SAFE_JOURNAL_STATUSES:
            require_coherent_prebroadcast_journal(journal, path)
            continue
        if status == "discarded_ephemeral_chain":
            network = require_dict(
                journal.get("network"),
                f"execution journal {path}.network",
            )
            if (
                journal.get("ephemeral_chain_destroyed") is True
                and journal.get("success") is False
                and network.get("execution_mode") == "anvil"
                and network.get("rpc_scope") == "ephemeral_loopback_anvil"
            ):
                continue
        raise CanonicalExecutionError(
            "prior canonical execution is terminal or unresolved; reconcile its "
            f"exact journal and chain state before retrying: {path}"
        )


def mark_ephemeral_chain_destroyed(journal_path: Path) -> None:
    """Make retry safe only after the owning local-Anvil process has stopped."""
    try:
        value = materializer.decode_json_bytes(
            journal_path.read_bytes(),
            journal_path,
        )
    except (OSError, materializer.DeploymentPlanError) as exc:
        raise CanonicalExecutionError(
            f"cannot prove ephemeral-chain destruction for {journal_path}: {exc}"
        ) from exc
    journal = require_dict(value, f"execution journal {journal_path}")
    network = require_dict(
        journal.get("network"),
        f"execution journal {journal_path}.network",
    )
    if (
        network.get("execution_mode") != "anvil"
        or network.get("rpc_scope") != "ephemeral_loopback_anvil"
    ):
        raise CanonicalExecutionError(
            "only an executor-owned ephemeral Anvil journal can be discarded"
        )
    status = journal.get("status")
    if status == FINAL_JOURNAL_STATUS:
        if journal.get("success") is not True:
            raise CanonicalExecutionError(
                "verified ephemeral journal must retain success before destruction"
            )
    elif status == "awaiting_ephemeral_chain_destruction":
        if journal.get("success") is not False:
            raise CanonicalExecutionError(
                "failed ephemeral journal cannot claim success before destruction"
            )
    else:
        raise CanonicalExecutionError(
            "ephemeral journal is not in a destructible terminal state"
        )
    journal["status"] = "discarded_ephemeral_chain"
    journal["success"] = False
    journal["ephemeral_chain_destroyed"] = True
    write_json_atomic(journal_path, journal)


def canonical_plan_snapshot(
    repo_root: Path,
    candidate_path: Path,
    plan_path: Path,
) -> tuple[dict[str, Any], bytes, str]:
    """Re-materialize authority and require the serialized plan to match exactly."""
    expected = materializer.materialize_deployment_plan(repo_root, candidate_path)
    expected_raw = materializer.json_text(expected).encode("utf-8")
    try:
        actual_raw = plan_path.read_bytes()
    except OSError as exc:
        raise CanonicalExecutionError(
            f"cannot read canonical deployment plan {plan_path}: {exc}"
        ) from exc
    try:
        actual = materializer.decode_json_bytes(actual_raw, plan_path)
    except materializer.DeploymentPlanError as exc:
        raise CanonicalExecutionError(str(exc)) from exc
    if actual != expected or actual_raw != expected_raw:
        raise CanonicalExecutionError(
            f"{plan_path} is stale or mutated; rematerialize before execution"
        )
    posture = require_dict(expected.get("release_posture"), "release_posture")
    if posture.get("production_candidate") is not False:
        raise CanonicalExecutionError(
            "v1 executor refuses production candidates until issue #656 lands"
        )
    if posture.get("status") not in NON_PRODUCTION_STATUSES:
        raise CanonicalExecutionError(
            "deployment plan does not declare the non-production tooling posture"
        )
    return expected, expected_raw, prefixed_sha256(expected_raw)


def assert_authority_unchanged(
    repo_root: Path,
    candidate_path: Path,
    plan_path: Path,
    expected_plan_sha256: str,
) -> None:
    _, _, actual_sha256 = canonical_plan_snapshot(
        repo_root,
        candidate_path,
        plan_path,
    )
    if actual_sha256 != expected_plan_sha256:
        raise CanonicalExecutionError(
            "canonical plan authority changed during execution"
        )


def validate_broadcaster_source(repo_root: Path, script_path: Path) -> str:
    """Reject any broadcaster that can compile target creation bytecode."""
    repo_root = repo_root.resolve()
    script_path = materializer.normalize_repo_path(
        repo_root,
        script_path,
        "generic broadcaster source",
    )
    try:
        raw = script_path.read_bytes()
        source = raw.decode("utf-8", "strict")
    except (OSError, UnicodeDecodeError) as exc:
        raise CanonicalExecutionError(
            f"cannot read generic broadcaster {script_path}: {exc}"
        ) from exc
    forbidden = (
        "smart-contracts/",
        "smart-contracts\\",
        ".creationCode",
        "type(",
    )
    for token in forbidden:
        if token in source:
            raise CanonicalExecutionError(
                f"generic broadcaster contains forbidden token {token!r}"
            )
    required = (
        "sha256(bytes(plan))",
        'parseJsonBytes(plan, string.concat(deploymentPath, ".initcode"))',
        "create(0, add(initcode, 0x20), mload(initcode))",
    )
    if any(token not in source for token in required):
        raise CanonicalExecutionError(
            "generic broadcaster does not hash and deploy plan-provided raw initcode"
        )
    return prefixed_sha256(raw)


def validate_build_closure(session_root: Path) -> None:
    build_info_root = session_root / "out" / "build-info"
    candidates = sorted(build_info_root.glob("*.json"))
    if len(candidates) != 1:
        raise CanonicalExecutionError(
            f"expected one generic-script build-info file, found {len(candidates)}"
        )
    try:
        value = materializer.decode_json_bytes(
            candidates[0].read_bytes(),
            candidates[0],
        )
    except (OSError, materializer.DeploymentPlanError) as exc:
        raise CanonicalExecutionError(
            f"cannot validate generic-script build-info: {exc}"
        ) from exc
    build_info = require_dict(value, "generic-script build-info")
    source_map = require_dict(
        build_info.get("source_id_to_path"),
        "generic-script build-info.source_id_to_path",
    )
    if set(source_map.values()) != {"DeployCanonicalInitcode.s.sol"}:
        raise CanonicalExecutionError(
            "generic-script compiler closure contains sources beyond the raw-initcode broadcaster"
        )


def read_file_snapshot(path: Path, label: str) -> tuple[bytes, str]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise CanonicalExecutionError(f"cannot read {label} {path}: {exc}") from exc
    return raw, prefixed_sha256(raw)


def assert_file_snapshot_unchanged(
    path: Path,
    expected_sha256: str,
    label: str,
) -> None:
    _, actual_sha256 = read_file_snapshot(path, label)
    if actual_sha256 != expected_sha256:
        raise CanonicalExecutionError(f"{label} changed during execution")


def default_command_runner(
    command: Sequence[str],
    cwd: Path,
    env: Mapping[str, str],
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        list(command),
        cwd=cwd,
        env=dict(env),
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        detail = "\n".join(
            part.strip()
            for part in (completed.stdout, completed.stderr)
            if part.strip()
        )
        for key, value in env.items():
            upper = key.upper()
            if value and any(
                marker in upper
                for marker in (
                    "URL",
                    "KEY",
                    "TOKEN",
                    "PASSWORD",
                    "MNEMONIC",
                    "SECRET",
                )
            ):
                detail = detail.replace(value, f"<redacted:{key}>")
        raise CanonicalExecutionError(
            f"canonical broadcaster command failed with exit "
            f"{completed.returncode}: {detail}"
        )
    return completed


def rpc_client(rpc_url: str, *, timeout: float = 30.0) -> RpcCaller:
    request_id = 0

    def call(method: str, params: Sequence[Any]) -> Any:
        nonlocal request_id
        request_id += 1
        if request_id > materializer.IJSON_SAFE_INTEGER_MAX:
            raise CanonicalExecutionError("JSON-RPC request id exceeded I-JSON range")
        payload = json.dumps(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "method": method,
                "params": list(params),
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = Request(
            rpc_url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urlopen(request, timeout=timeout) as response:
                raw_response = response.read()
            decoded = materializer.decode_json_bytes(
                raw_response,
                Path(f"<JSON-RPC {method} response>"),
            )
        except (OSError, URLError, materializer.DeploymentPlanError) as exc:
            raise CanonicalExecutionError(
                f"JSON-RPC {method} failed without retaining success "
                f"({type(exc).__name__})"
            ) from exc
        if not isinstance(decoded, dict):
            raise CanonicalExecutionError(f"JSON-RPC {method} returned no object")
        response_id = decoded.get("id")
        if (
            decoded.get("jsonrpc") != "2.0"
            or type(response_id) is not int
            or response_id < 0
            or response_id > materializer.IJSON_SAFE_INTEGER_MAX
            or response_id != request_id
        ):
            raise CanonicalExecutionError(
                f"JSON-RPC {method} returned the wrong protocol version or id"
            )
        members = set(decoded)
        if members == {"jsonrpc", "id", "error"}:
            raise CanonicalExecutionError(
                f"JSON-RPC {method} returned an error response"
            )
        if members != {"jsonrpc", "id", "result"}:
            raise CanonicalExecutionError(
                f"JSON-RPC {method} returned an ambiguous response shape"
            )
        return decoded["result"]

    return call


def find_free_local_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def start_local_anvil(chain_id: int) -> tuple[subprocess.Popen[str], str]:
    executable = shutil.which("anvil")
    if executable is None:
        raise CanonicalExecutionError("anvil is required for --local-anvil")
    port = find_free_local_port()
    command = [
        executable,
        "--host",
        "127.0.0.1",
        "--port",
        str(port),
        "--chain-id",
        str(chain_id),
        "--silent",
    ]
    creationflags = (
        subprocess.CREATE_NO_WINDOW
        if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW")
        else 0
    )
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
        creationflags=creationflags,
    )
    rpc_url = f"http://127.0.0.1:{port}"
    caller = rpc_client(rpc_url, timeout=1.0)
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise CanonicalExecutionError(
                "ephemeral anvil exited before becoming ready"
            )
        try:
            caller("eth_chainId", [])
            return process, rpc_url
        except CanonicalExecutionError:
            time.sleep(0.1)
    process.terminate()
    raise CanonicalExecutionError("ephemeral anvil did not become ready")


def stop_local_anvil(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def write_json_atomic(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = materializer.json_text(value).encode("utf-8")
    with tempfile.NamedTemporaryFile(
        mode="wb",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as handle:
        temporary = Path(handle.name)
        handle.write(raw)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def write_bytes_atomic(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="wb",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as handle:
        temporary = Path(handle.name)
        handle.write(raw)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def write_json_exclusive(path: Path, value: Any) -> None:
    """Atomically publish a receipt only if no prior receipt exists."""
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = materializer.json_text(value).encode("utf-8")
    with tempfile.NamedTemporaryFile(
        mode="wb",
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as handle:
        temporary = Path(handle.name)
        handle.write(raw)
        handle.flush()
        os.fsync(handle.fileno())
    try:
        os.link(temporary, path)
    except FileExistsError as exc:
        raise CanonicalExecutionError(
            f"refusing to overwrite existing execution receipt {path}"
        ) from exc
    except OSError as exc:
        raise CanonicalExecutionError(
            f"cannot publish execution receipt {path}: {exc}"
        ) from exc
    finally:
        temporary.unlink(missing_ok=True)


def forge_command(
    executor_root: Path,
    *,
    sender: str,
    signer_cli: Sequence[str],
    broadcast: bool,
) -> list[str]:
    command = [
        "forge",
        "script",
        f"{executor_root / 'DeployCanonicalInitcode.s.sol'}:DeployCanonicalInitcode",
        "--root",
        str(executor_root),
        "--contracts",
        ".",
        "--config-path",
        str(executor_root / "foundry.toml"),
        "--rpc-url",
        "canonical_executor",
        "--sender",
        sender,
        "--slow",
    ]
    command.extend(signer_cli)
    if broadcast:
        command.append("--broadcast")
    return command


def deployment_authority_record(
    deployment: Mapping[str, Any],
) -> dict[str, Any]:
    target = require_dict(deployment.get("target"), "deployment.target")
    artifact = require_dict(deployment.get("artifact"), "deployment.artifact")
    constructor = require_dict(
        deployment.get("constructor"),
        "deployment.constructor",
    )
    libraries = require_list(deployment.get("libraries"), "deployment.libraries")
    immutables = require_list(
        deployment.get("immutables"),
        "deployment.immutables",
    )
    return {
        "target_name": require_string(target.get("name"), "deployment.target.name"),
        "target_source": require_repo_path(
            target.get("source"),
            "deployment.target.source",
        ),
        "artifact_path": require_repo_path(
            artifact.get("path"),
            "deployment.artifact.path",
        ),
        "artifact_sha256": require_string(
            artifact.get("sha256"),
            "deployment.artifact.sha256",
        ),
        "constructor_sha256": prefixed_sha256(
            materializer.canonical_json_bytes(constructor)
        ),
        "libraries_sha256": prefixed_sha256(
            materializer.canonical_json_bytes(libraries)
        ),
        "immutables_sha256": prefixed_sha256(
            materializer.canonical_json_bytes(immutables)
        ),
        "linked_creation_bytecode_keccak256": require_hash(
            deployment.get("linked_creation_bytecode_keccak256"),
            "deployment.linked_creation_bytecode_keccak256",
        ),
        "initcode_keccak256": require_hash(
            deployment.get("initcode_keccak256"),
            "deployment.initcode_keccak256",
        ),
        "expected_runtime_keccak256": require_hash(
            deployment.get("expected_runtime_keccak256"),
            "deployment.expected_runtime_keccak256",
        ),
    }


def validate_deployment(
    deployment: Mapping[str, Any],
    *,
    expected_order: int,
) -> None:
    order = require_integer(deployment.get("order"), "deployment.order")
    if order != expected_order:
        raise CanonicalExecutionError(
            f"deployment order must be contiguous: expected {expected_order}, got {order}"
        )
    instance_id = require_string(
        deployment.get("instance_id"),
        "deployment.instance_id",
    )
    initcode = require_hex(deployment.get("initcode"), "deployment.initcode")
    initcode_length = require_integer(
        deployment.get("initcode_length_bytes"),
        "deployment.initcode_length_bytes",
    )
    if len(initcode[2:]) // 2 != initcode_length:
        raise CanonicalExecutionError(
            f"deployment {instance_id} initcode length does not match its bytes"
        )
    expected_initcode_hash = require_hash(
        deployment.get("initcode_keccak256"),
        "deployment.initcode_keccak256",
    )
    if materializer.keccak256_hex(bytes.fromhex(initcode[2:])) != expected_initcode_hash:
        raise CanonicalExecutionError(
            f"deployment {instance_id} initcode hash does not match its bytes"
        )
    expected_runtime = require_hex(
        deployment.get("expected_runtime_bytecode"),
        "deployment.expected_runtime_bytecode",
    )
    runtime_length = require_integer(
        deployment.get("expected_runtime_length_bytes"),
        "deployment.expected_runtime_length_bytes",
    )
    if len(expected_runtime[2:]) // 2 != runtime_length:
        raise CanonicalExecutionError(
            f"deployment {instance_id} runtime length does not match its bytes"
        )
    expected_runtime_hash = require_hash(
        deployment.get("expected_runtime_keccak256"),
        "deployment.expected_runtime_keccak256",
    )
    if materializer.keccak256_hex(bytes.fromhex(expected_runtime[2:])) != expected_runtime_hash:
        raise CanonicalExecutionError(
            f"deployment {instance_id} runtime hash does not match its bytes"
        )


def forge_environment(
    base: Mapping[str, str],
    *,
    rpc_url: str,
    sender: str,
    plan_path: Path,
    plan_sha256: str,
    deployment_index: int,
    deployment_count: int,
    session_root: Path,
    broadcast_root: Path,
) -> dict[str, str]:
    env = {
        key: value
        for key, value in base.items()
        if key.upper() in SAFE_CHILD_ENVIRONMENT
    }
    env.update(
        {
            "CANONICAL_DEPLOYMENT_RPC_URL": rpc_url,
            "CANONICAL_DEPLOYMENT_SENDER": sender,
            "CANONICAL_DEPLOYMENT_PLAN_PATH": str(plan_path),
            "CANONICAL_DEPLOYMENT_PLAN_SHA256": "0x" + plan_sha256.removeprefix(
                "sha256:"
            ),
            "CANONICAL_DEPLOYMENT_INDEX": str(deployment_index),
            "CANONICAL_DEPLOYMENT_COUNT": str(deployment_count),
            "FOUNDRY_OUT": str(session_root / "out"),
            "FOUNDRY_CACHE_PATH": str(session_root / "cache"),
            "FOUNDRY_BROADCAST": str(broadcast_root),
        }
    )
    return env


def locate_broadcast(broadcast_root: Path) -> Path:
    candidates = sorted(broadcast_root.rglob("run-latest.json"))
    if len(candidates) != 1:
        raise CanonicalExecutionError(
            f"expected exactly one Foundry run-latest.json, found {len(candidates)}"
        )
    return candidates[0]


def transaction_hash_from_broadcast(
    path: Path,
    *,
    expected_chain_id: int,
    expected_sender: str,
    expected_nonce: int,
    expected_contract_address: str,
    expected_initcode: str,
) -> tuple[str, str]:
    try:
        value = materializer.decode_json_bytes(path.read_bytes(), path)
    except (OSError, materializer.DeploymentPlanError) as exc:
        raise CanonicalExecutionError(
            f"cannot validate Foundry broadcast {path}: {exc}"
        ) from exc
    document = require_dict(value, "Foundry broadcast")
    if require_integer(document.get("chain"), "Foundry broadcast.chain") != expected_chain_id:
        raise CanonicalExecutionError("Foundry broadcast chain id mismatch")
    if require_list(document.get("pending"), "Foundry broadcast.pending"):
        raise CanonicalExecutionError("Foundry broadcast retains pending transactions")
    if require_list(document.get("libraries"), "Foundry broadcast.libraries"):
        raise CanonicalExecutionError(
            "generic broadcaster unexpectedly records linked libraries"
        )
    transactions = require_list(
        document.get("transactions"),
        "Foundry broadcast.transactions",
    )
    if len(transactions) != 1:
        raise CanonicalExecutionError(
            "generic broadcaster must retain exactly one transaction per entry"
        )
    transaction = require_dict(transactions[0], "Foundry broadcast transaction")
    if transaction.get("transactionType") != "CREATE":
        raise CanonicalExecutionError(
            "generic broadcaster retained a non-CREATE transaction"
        )
    if transaction.get("additionalContracts") != []:
        raise CanonicalExecutionError(
            "generic broadcaster retained unexpected additional contracts"
        )
    transaction_hash = require_hash(
        transaction.get("hash"),
        "Foundry transaction hash",
    )
    contract_address = require_address(
        transaction.get("contractAddress"),
        "Foundry transaction contract address",
    )
    if int(contract_address[2:], 16) == 0:
        raise CanonicalExecutionError(
            "Foundry transaction retained the zero contract address"
        )
    if contract_address != expected_contract_address:
        raise CanonicalExecutionError(
            "Foundry contract address differs from the sender/nonce CREATE address"
        )
    raw_transaction = require_dict(
        transaction.get("transaction"),
        "Foundry raw transaction",
    )
    if raw_transaction.get("to") is not None:
        raise CanonicalExecutionError("Foundry CREATE transaction has a recipient")
    if require_address(
        raw_transaction.get("from"),
        "Foundry transaction.from",
    ) != expected_sender:
        raise CanonicalExecutionError("Foundry transaction sender mismatch")
    if normalize_rpc_quantity(
        raw_transaction.get("nonce"),
        "Foundry transaction.nonce",
    ) != expected_nonce:
        raise CanonicalExecutionError("Foundry transaction nonce mismatch")
    if normalize_rpc_quantity(
        raw_transaction.get("chainId"),
        "Foundry transaction.chainId",
    ) != expected_chain_id:
        raise CanonicalExecutionError("Foundry transaction chain id mismatch")
    if normalize_rpc_quantity(
        raw_transaction.get("value"),
        "Foundry transaction.value",
    ) != 0:
        raise CanonicalExecutionError("generic CREATE transaction has nonzero value")
    if require_hex(
        raw_transaction.get("input"),
        "Foundry transaction.input",
    ) != expected_initcode:
        raise CanonicalExecutionError(
            "Foundry transaction input differs from canonical initcode"
        )
    receipts = require_list(
        document.get("receipts"),
        "Foundry broadcast.receipts",
    )
    if len(receipts) != 1:
        raise CanonicalExecutionError(
            "generic broadcaster must retain exactly one receipt per entry"
        )
    retained_receipt = require_dict(receipts[0], "Foundry retained receipt")
    if require_hash(
        retained_receipt.get("transactionHash"),
        "Foundry receipt transaction hash",
    ) != transaction_hash:
        raise CanonicalExecutionError("Foundry receipt transaction hash mismatch")
    if normalize_rpc_quantity(
        retained_receipt.get("status"),
        "Foundry receipt status",
    ) != 1:
        raise CanonicalExecutionError("Foundry retained receipt is not successful")
    if retained_receipt.get("to") is not None:
        raise CanonicalExecutionError("Foundry CREATE receipt has a recipient")
    if require_address(
        retained_receipt.get("from"),
        "Foundry receipt.from",
    ) != expected_sender:
        raise CanonicalExecutionError("Foundry receipt sender mismatch")
    if require_address(
        retained_receipt.get("contractAddress"),
        "Foundry receipt.contractAddress",
    ) != contract_address:
        raise CanonicalExecutionError("Foundry receipt contract address mismatch")
    return transaction_hash, contract_address


def wait_for_confirmations(
    rpc: RpcCaller,
    *,
    receipt_block: int,
    confirmations: int,
    timeout_seconds: float = 120.0,
    poll_seconds: float = 1.0,
    clock: Callable[[], float] = time.monotonic,
    sleeper: Callable[[float], None] = time.sleep,
) -> int:
    required_tip = receipt_block + max(confirmations - 1, 0)
    deadline = clock() + timeout_seconds
    while True:
        latest_block = normalize_rpc_quantity(
            rpc("eth_blockNumber", []),
            "eth_blockNumber",
        )
        if latest_block >= required_tip:
            return latest_block
        if clock() >= deadline:
            raise CanonicalExecutionError(
                f"deployment has {latest_block - receipt_block + 1} "
                f"confirmation(s); {confirmations} required"
            )
        sleeper(poll_seconds)


def require_uncontended_sender_nonce(
    rpc: RpcCaller,
    *,
    sender: str,
    expected_nonce: int | None,
) -> int:
    latest_nonce = normalize_rpc_quantity(
        rpc("eth_getTransactionCount", [sender, "latest"]),
        "latest sender nonce",
    )
    pending_nonce = normalize_rpc_quantity(
        rpc("eth_getTransactionCount", [sender, "pending"]),
        "pending sender nonce",
    )
    if latest_nonce != pending_nonce:
        raise CanonicalExecutionError(
            "sender has pending transactions; refusing ambiguous nonce ownership"
        )
    if expected_nonce is not None and latest_nonce != expected_nonce:
        raise CanonicalExecutionError(
            f"sender nonce interleaving detected: expected {expected_nonce}, "
            f"got {latest_nonce}"
        )
    return latest_nonce


def verify_chain_deployment(
    rpc: RpcCaller,
    *,
    transaction_hash: str,
    expected_sender: str,
    expected_chain_id: int,
    expected_nonce: int,
    expected_initcode: str,
    expected_contract_address: str,
    expected_runtime: str,
    expected_runtime_hash: str,
    confirmations: int = 1,
    verification_tip: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    transaction = require_dict(
        rpc("eth_getTransactionByHash", [transaction_hash]),
        "eth_getTransactionByHash result",
    )
    if require_hash(transaction.get("hash"), "transaction.hash") != transaction_hash:
        raise CanonicalExecutionError("deployment transaction hash mismatch")
    if transaction.get("to") is not None:
        raise CanonicalExecutionError("deployment transaction unexpectedly has a recipient")
    sender = require_address(transaction.get("from"), "transaction.from")
    if sender != expected_sender:
        raise CanonicalExecutionError(
            f"deployment sender mismatch: expected {expected_sender}, got {sender}"
        )
    transaction_input = require_hex(
        transaction.get("input"),
        "transaction.input",
    )
    if transaction_input != expected_initcode:
        raise CanonicalExecutionError(
            "actual deployment transaction input differs from canonical initcode"
        )
    if normalize_rpc_quantity(transaction.get("value"), "transaction.value") != 0:
        raise CanonicalExecutionError(
            "actual deployment transaction has nonzero value"
        )
    transaction_nonce = normalize_rpc_quantity(
        transaction.get("nonce"),
        "transaction.nonce",
    )
    if transaction_nonce != expected_nonce:
        raise CanonicalExecutionError(
            f"deployment nonce mismatch: expected {expected_nonce}, got {transaction_nonce}"
        )
    transaction_chain = transaction.get("chainId")
    if transaction_chain is not None and normalize_rpc_quantity(
        transaction_chain,
        "transaction.chainId",
    ) != expected_chain_id:
        raise CanonicalExecutionError("deployment transaction chain id mismatch")

    transaction_block_hash = require_hash(
        transaction.get("blockHash"),
        "transaction.blockHash",
    )
    transaction_block_number = normalize_rpc_quantity(
        transaction.get("blockNumber"),
        "transaction.blockNumber",
    )

    receipt = require_dict(
        rpc("eth_getTransactionReceipt", [transaction_hash]),
        "eth_getTransactionReceipt result",
    )
    if normalize_rpc_quantity(receipt.get("status"), "receipt.status") != 1:
        raise CanonicalExecutionError("deployment receipt is not successful")
    contract_address = require_address(
        receipt.get("contractAddress"),
        "receipt.contractAddress",
    )
    if contract_address != expected_contract_address:
        raise CanonicalExecutionError(
            "actual receipt contract address differs from Foundry broadcast"
        )
    if receipt.get("to") is not None:
        raise CanonicalExecutionError("actual CREATE receipt has a recipient")
    block_number_hex = require_string(receipt.get("blockNumber"), "receipt.blockNumber")
    block_number = normalize_rpc_quantity(block_number_hex, "receipt.blockNumber")
    if require_hash(
        receipt.get("transactionHash"),
        "receipt.transactionHash",
    ) != transaction_hash:
        raise CanonicalExecutionError("receipt transaction hash mismatch")
    if require_address(receipt.get("from"), "receipt.from") != expected_sender:
        raise CanonicalExecutionError("receipt sender mismatch")
    receipt_block_hash = require_hash(receipt.get("blockHash"), "receipt.blockHash")
    if transaction_block_hash != receipt_block_hash or transaction_block_number != block_number:
        raise CanonicalExecutionError(
            "deployment transaction and receipt block identity mismatch"
        )
    wait_for_confirmations(
        rpc,
        receipt_block=block_number,
        confirmations=confirmations,
    )
    canonical_block = require_dict(
        rpc("eth_getBlockByNumber", [block_number_hex, False]),
        "eth_getBlockByNumber result",
    )
    if require_hash(canonical_block.get("hash"), "block.hash") != receipt_block_hash:
        raise CanonicalExecutionError("receipt block is no longer canonical")
    block_by_hash = require_dict(
        rpc("eth_getBlockByHash", [receipt_block_hash, False]),
        "eth_getBlockByHash result",
    )
    if normalize_rpc_quantity(block_by_hash.get("number"), "block.number") != block_number:
        raise CanonicalExecutionError("receipt block hash resolves to the wrong height")
    runtime_block_hash = receipt_block_hash
    if verification_tip is not None:
        tip_number = require_integer(
            verification_tip.get("block_number"),
            "verification_tip.block_number",
        )
        runtime_block_hash = require_hash(
            verification_tip.get("block_hash"),
            "verification_tip.block_hash",
        )
        if tip_number < block_number:
            raise CanonicalExecutionError(
                "final verification tip predates the deployment receipt"
            )
        tip_by_number = require_dict(
            rpc("eth_getBlockByNumber", [hex(tip_number), False]),
            "verification-tip eth_getBlockByNumber result",
        )
        if require_hash(
            tip_by_number.get("hash"),
            "verification-tip block.hash",
        ) != runtime_block_hash:
            raise CanonicalExecutionError(
                "final verification tip is no longer canonical"
            )
        tip_by_hash = require_dict(
            rpc("eth_getBlockByHash", [runtime_block_hash, False]),
            "verification-tip eth_getBlockByHash result",
        )
        if (
            normalize_rpc_quantity(
                tip_by_hash.get("number"),
                "verification-tip block.number",
            )
            != tip_number
            or require_hash(
                tip_by_hash.get("hash"),
                "verification-tip block.hash",
            )
            != runtime_block_hash
        ):
            raise CanonicalExecutionError(
                "final verification tip hash resolves to the wrong block"
            )
    runtime_selector = {
        "blockHash": runtime_block_hash,
        "requireCanonical": True,
    }
    runtime = require_hex(
        rpc(
            "eth_getCode",
            [
                contract_address,
                runtime_selector,
            ],
        ),
        "eth_getCode result",
    )
    if runtime == "0x":
        raise CanonicalExecutionError("deployed address has no runtime code")
    actual_runtime_hash = materializer.keccak256_hex(bytes.fromhex(runtime[2:]))
    if runtime != expected_runtime:
        raise CanonicalExecutionError(
            "actual deployed runtime bytes differ from canonical runtime bytes"
        )
    if actual_runtime_hash != expected_runtime_hash:
        raise CanonicalExecutionError(
            "actual deployed runtime hash differs from canonical runtime hash"
        )
    stable_runtime = require_hex(
        rpc("eth_getCode", [contract_address, runtime_selector]),
        "stable eth_getCode result",
    )
    if stable_runtime != expected_runtime:
        raise CanonicalExecutionError(
            "stable deployed runtime differs from canonical runtime bytes"
        )

    repeated_receipt = require_dict(
        rpc("eth_getTransactionReceipt", [transaction_hash]),
        "repeated eth_getTransactionReceipt result",
    )
    repeated_identity = (
        require_hash(repeated_receipt.get("transactionHash"), "repeated receipt.transactionHash"),
        normalize_rpc_quantity(repeated_receipt.get("status"), "repeated receipt.status"),
        require_address(repeated_receipt.get("from"), "repeated receipt.from"),
        repeated_receipt.get("to"),
        require_address(
            repeated_receipt.get("contractAddress"),
            "repeated receipt.contractAddress",
        ),
        normalize_rpc_quantity(
            repeated_receipt.get("blockNumber"),
            "repeated receipt.blockNumber",
        ),
        require_hash(repeated_receipt.get("blockHash"), "repeated receipt.blockHash"),
    )
    original_identity = (
        transaction_hash,
        1,
        expected_sender,
        None,
        expected_contract_address,
        block_number,
        receipt_block_hash,
    )
    if repeated_identity != original_identity:
        raise CanonicalExecutionError(
            "deployment receipt changed during canonical runtime verification"
        )
    repeated_block = require_dict(
        rpc("eth_getBlockByNumber", [block_number_hex, False]),
        "repeated eth_getBlockByNumber result",
    )
    if require_hash(repeated_block.get("hash"), "repeated block.hash") != receipt_block_hash:
        raise CanonicalExecutionError(
            "receipt block changed during canonical runtime verification"
        )
    repeated_runtime = require_hex(
        rpc(
            "eth_getCode",
            [
                contract_address,
                runtime_selector,
            ],
        ),
        "repeated eth_getCode result",
    )
    if repeated_runtime != runtime:
        raise CanonicalExecutionError(
            "receipt-block runtime changed during canonical verification"
        )
    return {
        "transaction_hash": transaction_hash,
        "transaction_input_keccak256": materializer.keccak256_hex(
            bytes.fromhex(transaction_input[2:])
        ),
        "sender": sender,
        "contract_address": contract_address,
        "block_number": block_number,
        "block_hash": receipt_block_hash,
        "nonce": transaction_nonce,
        "confirmations_verified": confirmations,
        "actual_runtime_length_bytes": len(runtime[2:]) // 2,
        "actual_runtime_keccak256": actual_runtime_hash,
    }


def capture_canonical_tip(rpc: RpcCaller) -> dict[str, Any]:
    number = normalize_rpc_quantity(rpc("eth_blockNumber", []), "eth_blockNumber")
    number_hex = hex(number)
    block = require_dict(
        rpc("eth_getBlockByNumber", [number_hex, False]),
        "tip eth_getBlockByNumber result",
    )
    block_hash = require_hash(block.get("hash"), "tip block.hash")
    block_by_hash = require_dict(
        rpc("eth_getBlockByHash", [block_hash, False]),
        "tip eth_getBlockByHash result",
    )
    if (
        normalize_rpc_quantity(block_by_hash.get("number"), "tip block.number")
        != number
        or require_hash(block_by_hash.get("hash"), "tip block.hash") != block_hash
    ):
        raise CanonicalExecutionError(
            "canonical tip hash resolves to the wrong block"
        )
    return {"block_number": number, "block_hash": block_hash}


def preflight_rpc_capabilities(
    rpc: RpcCaller,
    *,
    probe_address: str,
) -> dict[str, Any]:
    """Require every block-identity RPC used after an irreversible broadcast."""
    tip = capture_canonical_tip(rpc)
    block_number = require_integer(tip.get("block_number"), "tip.block_number")
    block_hash = require_hash(tip.get("block_hash"), "tip.block_hash")
    block_by_hash = require_dict(
        rpc("eth_getBlockByHash", [block_hash, False]),
        "preflight eth_getBlockByHash result",
    )
    if normalize_rpc_quantity(
        block_by_hash.get("number"),
        "preflight block.number",
    ) != block_number:
        raise CanonicalExecutionError(
            "RPC block-hash lookup resolves the canonical tip to the wrong height"
        )
    if require_hash(
        block_by_hash.get("hash"),
        "preflight block.hash",
    ) != block_hash:
        raise CanonicalExecutionError(
            "RPC block-hash lookup returned the wrong canonical tip"
        )
    require_hex(
        rpc(
            "eth_getCode",
            [
                require_address(probe_address, "preflight probe address"),
                {"blockHash": block_hash, "requireCanonical": True},
            ],
        ),
        "preflight EIP-1898 eth_getCode result",
    )
    assert_canonical_tip_unchanged(rpc, tip)
    return {
        "block_number": block_number,
        "block_hash": block_hash,
        "block_by_hash_verified": True,
        "eip_1898_get_code_verified": True,
    }


def assert_canonical_tip_unchanged(rpc: RpcCaller, tip: Mapping[str, Any]) -> None:
    number = require_integer(tip.get("block_number"), "tip.block_number")
    expected_hash = require_hash(tip.get("block_hash"), "tip.block_hash")
    current_number = normalize_rpc_quantity(
        rpc("eth_blockNumber", []),
        "repeated eth_blockNumber",
    )
    if current_number != number:
        raise CanonicalExecutionError(
            "canonical tip advanced or regressed during final deployment sweep"
        )
    block = require_dict(
        rpc("eth_getBlockByNumber", [hex(current_number), False]),
        "repeated tip eth_getBlockByNumber result",
    )
    if require_hash(block.get("hash"), "repeated tip block.hash") != expected_hash:
        raise CanonicalExecutionError(
            "canonical tip changed during final deployment sweep"
        )
    block_by_hash = require_dict(
        rpc("eth_getBlockByHash", [expected_hash, False]),
        "repeated tip eth_getBlockByHash result",
    )
    if (
        normalize_rpc_quantity(
            block_by_hash.get("number"),
            "repeated tip block.number",
        )
        != number
        or require_hash(
            block_by_hash.get("hash"),
            "repeated tip block.hash",
        )
        != expected_hash
    ):
        raise CanonicalExecutionError(
            "canonical tip hash changed during final deployment sweep"
        )


def execute_plan(
    repo_root: Path,
    candidate_path: Path,
    plan_path: Path,
    output_path: Path | None,
    *,
    rpc_url: str,
    sender: str,
    signer_cli: Sequence[str],
    execution_mode: str,
    live_broadcast_authorized: bool = False,
    ephemeral_local: bool = False,
    command_runner: CommandRunner = default_command_runner,
    rpc: RpcCaller | None = None,
    confirmations: int = 1,
    resolver: HostResolver | None = None,
) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    plan_path = materializer.resolve_output_path(repo_root, plan_path)
    if output_path is not None:
        output_path = materializer.resolve_output_path(repo_root, output_path)
    plan, plan_raw, plan_sha256 = canonical_plan_snapshot(
        repo_root,
        candidate_path,
        plan_path,
    )
    script_path = materializer.normalize_repo_path(
        repo_root,
        repo_root / DEFAULT_SCRIPT,
        "generic broadcaster source",
    )
    script_sha256 = validate_broadcaster_source(repo_root, script_path)
    foundry_config_path = materializer.normalize_repo_path(
        repo_root,
        repo_root / DEFAULT_FOUNDRY_CONFIG,
        "generic broadcaster Foundry config",
    )
    executor_driver_path = materializer.normalize_repo_path(
        repo_root,
        repo_root / EXECUTOR_DRIVER_PATH,
        "canonical executor driver",
    )
    execution_schema_path = materializer.normalize_repo_path(
        repo_root,
        repo_root / EXECUTION_SCHEMA_PATH,
        "canonical execution receipt schema",
    )
    script_raw, script_snapshot_sha256 = read_file_snapshot(
        script_path,
        "generic broadcaster source",
    )
    if script_snapshot_sha256 != script_sha256:
        raise CanonicalExecutionError(
            "generic broadcaster source changed while being validated"
        )
    foundry_config_raw, foundry_config_sha256 = read_file_snapshot(
        foundry_config_path,
        "generic broadcaster Foundry config",
    )
    _, executor_driver_sha256 = read_file_snapshot(
        executor_driver_path,
        "canonical executor driver",
    )
    _, execution_schema_sha256 = read_file_snapshot(
        execution_schema_path,
        "canonical execution receipt schema",
    )
    sender = require_address(sender, "sender")
    network = execution_network_record(
        plan,
        rpc_url=rpc_url,
        execution_mode=execution_mode,
        live_broadcast_authorized=live_broadcast_authorized,
        ephemeral_local=ephemeral_local,
        resolver=resolver,
    )
    chain_id = require_integer(network.get("chain_id"), "network.chain_id")
    pinned_addresses = pinned_rpc_addresses(network)
    rpc = rpc or rpc_client(rpc_url)
    if pinned_addresses is not None:
        rpc = resolution_guarded_rpc(
            rpc,
            rpc_url,
            pinned_addresses,
            resolver=resolver,
        )
    actual_chain_id = normalize_rpc_quantity(rpc("eth_chainId", []), "eth_chainId")
    if actual_chain_id != chain_id:
        raise CanonicalExecutionError(
            f"RPC chain id {actual_chain_id} does not match plan chain id {chain_id}"
        )

    deployments = [
        require_dict(item, f"deployments[{index}]")
        for index, item in enumerate(require_list(plan.get("deployments"), "deployments"))
    ]
    if not deployments:
        raise CanonicalExecutionError("canonical deployment plan has no deployments")
    if confirmations < 1:
        raise CanonicalExecutionError("confirmations must be at least one")
    if output_path is not None and output_path.exists():
        raise CanonicalExecutionError(
            f"refusing to overwrite existing execution receipt {output_path}"
        )

    session_id = uuid.uuid4().hex
    staging_parent = materializer.normalize_repo_path(
        repo_root,
        repo_root / STAGING_ROOT,
        "canonical deployment staging root",
    )
    session_parent = materializer.normalize_repo_path(
        repo_root,
        repo_root / SESSION_ROOT,
        "canonical deployment session root",
    )
    key = execution_key(plan_sha256, chain_id, sender)
    concurrency_key = sender_lock_key(chain_id, sender)
    journal_identity = {
        "schema_version": JOURNAL_SCHEMA,
        "execution_key": key,
        "plan_sha256": plan_sha256,
        "candidate_id": plan["candidate"]["candidate_id"],
        "release_receipt_sha256": plan["release_build"]["receipt_sha256"],
        "target_catalog_sha256": plan["release_build"]["target_catalog_sha256"],
        "release_config_sha256": plan["release_build"]["config_sha256"],
        "release_foundry_config_sha256": plan["release_build"][
            "foundry_config_sha256"
        ],
        "executor_script_sha256": script_sha256,
        "executor_foundry_config_sha256": foundry_config_sha256,
        "executor_driver_sha256": executor_driver_sha256,
        "execution_schema_sha256": execution_schema_sha256,
        "network": network,
        "chain_id": chain_id,
        "sender": sender,
        "deployment_authority": [
            deployment_authority_record(deployment) for deployment in deployments
        ],
    }
    lock_path = acquire_execution_lock(session_parent, concurrency_key, session_id)
    staging_root = staging_parent / session_id
    session_root = session_parent / session_id
    try:
        reject_ambiguous_journals(
            session_parent,
            expected_identity=journal_identity,
        )
        staging_root.mkdir(parents=True, exist_ok=False)
        session_root.mkdir(parents=True, exist_ok=False)
        if output_path is None:
            output_path = materializer.resolve_output_path(
                repo_root,
                session_root / "execution-receipt.json",
            )
        materializer.normalize_repo_path(
            repo_root,
            staging_root,
            "canonical deployment staging session",
        )
        materializer.normalize_repo_path(
            repo_root,
            session_root,
            "canonical deployment execution session",
        )
        executor_snapshot_root = staging_root / "executor"
        plan_snapshot_root = staging_root / "deployments"
        executor_snapshot_root.mkdir()
        plan_snapshot_root.mkdir()
        staged_script_path = executor_snapshot_root / DEFAULT_SCRIPT.name
        staged_foundry_config_path = executor_snapshot_root / "foundry.toml"
        staged_plan_path = plan_snapshot_root / "canonical-deployment-plan.json"
        write_bytes_atomic(staged_script_path, script_raw)
        write_bytes_atomic(staged_foundry_config_path, foundry_config_raw)
        write_bytes_atomic(staged_plan_path, plan_raw)
        staged_script_sha256 = validate_broadcaster_source(
            repo_root,
            staged_script_path,
        )
        if staged_script_sha256 != script_sha256:
            raise CanonicalExecutionError(
                "staged generic broadcaster differs from its validated snapshot"
            )
        if (
            prefixed_sha256(staged_foundry_config_path.read_bytes())
            != foundry_config_sha256
        ):
            raise CanonicalExecutionError(
                "staged Foundry config differs from its validated snapshot"
            )
        journal_path = session_root / "execution-journal.json"
        journal = {
            **journal_identity,
            "status": "preflight",
            "success": False,
            "active_deployment": None,
            "verified_deployments": [],
        }
        write_json_atomic(journal_path, journal)
    except Exception:
        release_execution_lock(lock_path)
        raise
    broadcast_attempted = False
    try:
        for index, deployment in enumerate(deployments):
            validate_deployment(deployment, expected_order=index + 1)

        # The complete plan must simulate as one ordered state transition before
        # any transaction is submitted.
        dry_run_root = session_root / "simulation"
        env = forge_environment(
            os.environ,
            rpc_url=rpc_url,
            sender=sender,
            plan_path=staged_plan_path,
            plan_sha256=plan_sha256,
            deployment_index=0,
            deployment_count=len(deployments),
            session_root=session_root,
            broadcast_root=dry_run_root,
        )
        command = forge_command(
            executor_snapshot_root,
            sender=sender,
            signer_cli=signer_cli,
            broadcast=False,
        )
        assert_file_snapshot_unchanged(
            staged_script_path,
            script_sha256,
            "staged generic broadcaster source",
        )
        assert_file_snapshot_unchanged(
            staged_foundry_config_path,
            foundry_config_sha256,
            "staged generic broadcaster Foundry config",
        )
        if pinned_addresses is not None:
            assert_rpc_resolution_unchanged(
                rpc_url,
                pinned_addresses,
                resolver=resolver,
            )
        command_runner(command, repo_root, env)
        assert_file_snapshot_unchanged(
            staged_script_path,
            script_sha256,
            "staged generic broadcaster source",
        )
        assert_file_snapshot_unchanged(
            staged_foundry_config_path,
            foundry_config_sha256,
            "staged generic broadcaster Foundry config",
        )
        validate_build_closure(session_root)
        assert_authority_unchanged(
            repo_root,
            candidate_path,
            plan_path,
            plan_sha256,
        )

        rpc_preflight = preflight_rpc_capabilities(rpc, probe_address=sender)
        journal["rpc_preflight"] = rpc_preflight
        write_json_atomic(journal_path, journal)
        initial_nonce = require_uncontended_sender_nonce(
            rpc,
            sender=sender,
            expected_nonce=None,
        )
        journal["initial_nonce"] = initial_nonce
        journal["status"] = "broadcasting"
        write_json_atomic(journal_path, journal)
        retained: list[dict[str, Any]] = []
        for index, deployment in enumerate(deployments):
            order = require_integer(deployment["order"], "deployment.order")
            instance_id = require_string(
                deployment.get("instance_id"),
                "deployment.instance_id",
            )
            expected_nonce = initial_nonce + index
            require_uncontended_sender_nonce(
                rpc,
                sender=sender,
                expected_nonce=expected_nonce,
            )
            expected_initcode = require_hex(
                deployment.get("initcode"),
                "deployment.initcode",
            )
            expected_contract_address = create_address(sender, expected_nonce)
            journal["active_deployment"] = {
                "status": "prepared",
                "order": order,
                "instance_id": instance_id,
                "nonce": expected_nonce,
                "expected_contract_address": expected_contract_address,
                "initcode_keccak256": deployment["initcode_keccak256"],
            }
            write_json_atomic(journal_path, journal)
            broadcast_root = session_root / f"broadcast-{order:04d}"
            env = forge_environment(
                os.environ,
                rpc_url=rpc_url,
                sender=sender,
                plan_path=staged_plan_path,
                plan_sha256=plan_sha256,
                deployment_index=index,
                deployment_count=1,
                session_root=session_root,
                broadcast_root=broadcast_root,
            )
            command = forge_command(
                executor_snapshot_root,
                sender=sender,
                signer_cli=signer_cli,
                broadcast=True,
            )
            assert_file_snapshot_unchanged(
                staged_script_path,
                script_sha256,
                "staged generic broadcaster source",
            )
            assert_file_snapshot_unchanged(
                staged_foundry_config_path,
                foundry_config_sha256,
                "staged generic broadcaster Foundry config",
            )
            broadcast_attempted = True
            if pinned_addresses is not None:
                assert_rpc_resolution_unchanged(
                    rpc_url,
                    pinned_addresses,
                    resolver=resolver,
                )
            command_runner(command, repo_root, env)
            assert_file_snapshot_unchanged(
                staged_script_path,
                script_sha256,
                "staged generic broadcaster source",
            )
            assert_file_snapshot_unchanged(
                staged_foundry_config_path,
                foundry_config_sha256,
                "staged generic broadcaster Foundry config",
            )
            validate_build_closure(session_root)
            transaction_hash, recorded_contract_address = transaction_hash_from_broadcast(
                locate_broadcast(broadcast_root),
                expected_chain_id=chain_id,
                expected_sender=sender,
                expected_nonce=expected_nonce,
                expected_contract_address=expected_contract_address,
                expected_initcode=expected_initcode,
            )
            journal["active_deployment"] = {
                **journal["active_deployment"],
                "status": "submitted",
                "transaction_hash": transaction_hash,
                "contract_address": recorded_contract_address,
            }
            write_json_atomic(journal_path, journal)
            verified = verify_chain_deployment(
                rpc,
                transaction_hash=transaction_hash,
                expected_sender=sender,
                expected_chain_id=chain_id,
                expected_nonce=expected_nonce,
                expected_initcode=expected_initcode,
                expected_contract_address=expected_contract_address,
                expected_runtime=require_hex(
                    deployment.get("expected_runtime_bytecode"),
                    "deployment.expected_runtime_bytecode",
                ),
                expected_runtime_hash=require_hash(
                    deployment.get("expected_runtime_keccak256"),
                    "deployment.expected_runtime_keccak256",
                ),
                confirmations=confirmations,
            )
            require_uncontended_sender_nonce(
                rpc,
                sender=sender,
                expected_nonce=expected_nonce + 1,
            )
            record = {
                "order": order,
                "instance_id": instance_id,
                "expected_contract_address": expected_contract_address,
                "initcode_length_bytes": deployment["initcode_length_bytes"],
                "initcode_keccak256": deployment["initcode_keccak256"],
                "expected_runtime_length_bytes": deployment[
                    "expected_runtime_length_bytes"
                ],
                "expected_runtime_keccak256": deployment[
                    "expected_runtime_keccak256"
                ],
                "authority": deployment_authority_record(deployment),
                **verified,
            }
            retained.append(record)
            journal["active_deployment"] = None
            journal["verified_deployments"] = retained
            write_json_atomic(journal_path, journal)
            assert_authority_unchanged(
                repo_root,
                candidate_path,
                plan_path,
                plan_sha256,
            )

        final_tip = capture_canonical_tip(rpc)
        for index, (deployment, retained_record) in enumerate(
            zip(deployments, retained, strict=True)
        ):
            reverified = verify_chain_deployment(
                rpc,
                transaction_hash=require_hash(
                    retained_record.get("transaction_hash"),
                    f"retained[{index}].transaction_hash",
                ),
                expected_sender=sender,
                expected_chain_id=chain_id,
                expected_nonce=require_integer(
                    retained_record.get("nonce"),
                    f"retained[{index}].nonce",
                ),
                expected_initcode=require_hex(
                    deployment.get("initcode"),
                    f"deployments[{index}].initcode",
                ),
                expected_contract_address=require_address(
                    retained_record.get("expected_contract_address"),
                    f"retained[{index}].expected_contract_address",
                ),
                expected_runtime=require_hex(
                    deployment.get("expected_runtime_bytecode"),
                    f"deployments[{index}].expected_runtime_bytecode",
                ),
                expected_runtime_hash=require_hash(
                    deployment.get("expected_runtime_keccak256"),
                    f"deployments[{index}].expected_runtime_keccak256",
                ),
                confirmations=confirmations,
                verification_tip=final_tip,
            )
            for field, value in reverified.items():
                if retained_record.get(field) != value:
                    raise CanonicalExecutionError(
                        f"deployment {retained_record['instance_id']} changed "
                        f"during final sweep at {field}"
                    )
        assert_canonical_tip_unchanged(rpc, final_tip)

        receipt = {
            "schema_version": EXECUTION_SCHEMA,
            "generated_by": (
                f"scripts/execute_canonical_deployment_plan.py:{GENERATOR_VERSION}"
            ),
            "release_posture": {
                "production_candidate": False,
                "readiness_evidence": False,
                "status": "non_production_execution_only",
                "note": (
                    "This receipt does not authorize a production broadcast or "
                    "establish release readiness."
                ),
            },
            "plan": {
                "path": require_repo_path(
                    plan_path.relative_to(repo_root).as_posix(),
                    "receipt.plan.path",
                ),
                "sha256": plan_sha256,
                "candidate_id": plan["candidate"]["candidate_id"],
                "release_receipt_sha256": plan["release_build"]["receipt_sha256"],
                "target_catalog_sha256": plan["release_build"][
                    "target_catalog_sha256"
                ],
                "release_config_sha256": plan["release_build"]["config_sha256"],
                "release_foundry_config_sha256": plan["release_build"][
                    "foundry_config_sha256"
                ],
            },
            "network": network,
            "finalization": {
                "tip_block_number": final_tip["block_number"],
                "tip_block_hash": final_tip["block_hash"],
                "confirmations_required": confirmations,
                "deployments_reverified": len(retained),
                "tip_unchanged_during_final_sweep": True,
            },
            "executor": {
                "script_path": DEFAULT_SCRIPT.as_posix(),
                "script_sha256": script_sha256,
                "foundry_config_path": DEFAULT_FOUNDRY_CONFIG.as_posix(),
                "foundry_config_sha256": foundry_config_sha256,
                "driver_path": EXECUTOR_DRIVER_PATH.as_posix(),
                "driver_sha256": executor_driver_sha256,
                "receipt_schema_path": EXECUTION_SCHEMA_PATH.as_posix(),
                "receipt_schema_sha256": execution_schema_sha256,
                "output_root": require_repo_path(
                    session_root.relative_to(repo_root).as_posix(),
                    "receipt.executor.output_root",
                ),
                "compiler_output_isolated_from": "out-release",
            },
            "deployments": retained,
        }
        assert_file_snapshot_unchanged(
            script_path,
            script_sha256,
            "generic broadcaster source",
        )
        assert_file_snapshot_unchanged(
            foundry_config_path,
            foundry_config_sha256,
            "generic broadcaster Foundry config",
        )
        assert_file_snapshot_unchanged(
            executor_driver_path,
            executor_driver_sha256,
            "canonical executor driver",
        )
        assert_file_snapshot_unchanged(
            execution_schema_path,
            execution_schema_sha256,
            "canonical execution receipt schema",
        )
        materializer.validate_draft_2020_12_schema(
            repo_root,
            EXECUTION_SCHEMA_PATH,
            receipt,
            "canonical deployment execution receipt",
        )
        journal["status"] = "publishing"
        journal["success"] = False
        write_json_atomic(journal_path, journal)
        write_json_exclusive(output_path, receipt)
        receipt_raw = materializer.json_text(receipt).encode("utf-8")
        journal["status"] = FINAL_JOURNAL_STATUS
        journal["success"] = True
        journal["receipt_path"] = output_path.relative_to(repo_root).as_posix()
        journal["receipt_sha256"] = prefixed_sha256(receipt_raw)
        write_json_atomic(journal_path, journal)
        return receipt
    except Exception as exc:
        if ephemeral_local:
            journal["status"] = "awaiting_ephemeral_chain_destruction"
            setattr(exc, "canonical_ephemeral_journal_path", journal_path)
        elif not broadcast_attempted:
            journal["status"] = "failed_preflight"
        else:
            journal["status"] = "failed_or_ambiguous"
        journal["success"] = False
        journal["failure_type"] = type(exc).__name__
        journal["failure"] = str(exc)
        write_json_atomic(journal_path, journal)
        raise
    finally:
        shutil.rmtree(staging_root, ignore_errors=True)
        release_execution_lock(lock_path)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Execute and verify a non-production canonical deployment plan."
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--candidate",
        type=Path,
        default=materializer.DEFAULT_CANDIDATE,
    )
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument("--output", type=Path)
    output_group.add_argument(
        "--ephemeral-output",
        action="store_true",
        help="retain the verified receipt under the unique session directory",
    )
    parser.add_argument(
        "--rpc-env",
        default="CANONICAL_DEPLOYMENT_RPC_URL",
        help="environment variable containing the RPC URL",
    )
    parser.add_argument("--sender")
    parser.add_argument(
        "--mode",
        choices=sorted(EXECUTION_MODES),
        required=True,
        help="operator-selected network posture; v1 production remains blocked",
    )
    parser.add_argument(
        "--signer",
        choices=sorted(SIGNER_MODES),
        help="reviewed Forge signer transport; raw private-key flags are unsupported",
    )
    parser.add_argument("--keystore", type=Path)
    parser.add_argument("--password-file", type=Path)
    parser.add_argument(
        "--authorize-live-broadcast",
        action="store_true",
        help="explicitly authorize the v1 Sepolia live-testnet path",
    )
    parser.add_argument(
        "--confirmations",
        type=int,
        default=1,
        help="minimum canonical confirmations required before runtime retention",
    )
    parser.add_argument(
        "--local-anvil",
        action="store_true",
        help="start and stop an isolated local Anvil and use its first unlocked account",
    )
    return parser.parse_args(argv)


def resolve(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    process: subprocess.Popen[str] | None = None
    ephemeral_journal_path: Path | None = None
    receipt: dict[str, Any] | None = None
    failure: Exception | None = None
    output_path: Path | None = None
    try:
        repo_root = args.repo_root.resolve()
        candidate_path = resolve(repo_root, args.candidate)
        plan_path = materializer.resolve_output_path(
            repo_root,
            resolve(repo_root, args.plan),
        )
        if not args.ephemeral_output:
            requested_output = args.output if args.output is not None else DEFAULT_OUTPUT
            output_path = materializer.resolve_output_path(
                repo_root,
                resolve(repo_root, requested_output),
            )
        preview, _, _ = canonical_plan_snapshot(
            repo_root,
            candidate_path,
            plan_path,
        )
        chain_id = require_integer(preview["network"]["chain_id"], "network.chain_id")
        if args.local_anvil:
            if args.mode != "anvil":
                raise CanonicalExecutionError(
                    "--local-anvil requires --mode anvil"
                )
            if chain_id != LOCAL_ANVIL_CHAIN_ID:
                raise CanonicalExecutionError(
                    "--local-anvil requires a plan on chain 31337"
                )
            if args.sender is not None or os.environ.get(args.rpc_env):
                raise CanonicalExecutionError(
                    "--local-anvil cannot be combined with --sender or an RPC environment"
                )
            if args.signer not in {None, "unlocked"}:
                raise CanonicalExecutionError(
                    "--local-anvil supports only the unlocked ephemeral signer"
                )
            if args.keystore is not None or args.password_file is not None:
                raise CanonicalExecutionError(
                    "--local-anvil cannot use keystore options"
                )
            signer_cli = signer_arguments("unlocked")
            process, rpc_url = start_local_anvil(chain_id)
            rpc = rpc_client(rpc_url)
            accounts = require_list(rpc("eth_accounts", []), "eth_accounts")
            if not accounts:
                raise CanonicalExecutionError("ephemeral anvil returned no unlocked account")
            sender = require_address(accounts[0], "eth_accounts[0]")
        else:
            if args.signer is None:
                raise CanonicalExecutionError(
                    "external execution requires an explicit --signer mode"
                )
            signer_cli = signer_arguments(
                args.signer,
                keystore=args.keystore,
                password_file=args.password_file,
            )
            rpc_url = require_string(os.environ.get(args.rpc_env), args.rpc_env)
            sender = require_address(args.sender, "--sender")
            rpc = rpc_client(rpc_url)
        receipt = execute_plan(
            repo_root,
            candidate_path,
            plan_path,
            output_path,
            rpc_url=rpc_url,
            sender=sender,
            signer_cli=signer_cli,
            execution_mode=args.mode,
            live_broadcast_authorized=args.authorize_live_broadcast,
            ephemeral_local=args.local_anvil,
            rpc=rpc,
            confirmations=args.confirmations,
        )
        if process is not None:
            executor_record = require_dict(receipt.get("executor"), "receipt.executor")
            output_root = require_repo_path(
                executor_record.get("output_root"),
                "receipt.executor.output_root",
            )
            ephemeral_journal_path = materializer.normalize_repo_path(
                repo_root,
                repo_root / Path(output_root) / "execution-journal.json",
                "ephemeral execution journal",
            )
    except (CanonicalExecutionError, materializer.DeploymentPlanError) as exc:
        failure = exc
        candidate_journal = getattr(exc, "canonical_ephemeral_journal_path", None)
        if candidate_journal is not None:
            ephemeral_journal_path = Path(candidate_journal)
    finally:
        if process is not None:
            try:
                stop_local_anvil(process)
                if ephemeral_journal_path is not None:
                    mark_ephemeral_chain_destroyed(ephemeral_journal_path)
            except CanonicalExecutionError as cleanup_exc:
                if failure is None:
                    failure = cleanup_exc
                else:
                    failure = CanonicalExecutionError(
                        f"{failure}; ephemeral-chain cleanup proof also failed: "
                        f"{cleanup_exc}"
                    )
    if failure is not None:
        print(f"canonical deployment execution failed: {failure}", file=sys.stderr)
        return 1
    if receipt is None:
        raise CanonicalExecutionError("execution returned no receipt")
    print(
        "verified non-production canonical deployment: "
        f"{len(receipt['deployments'])} instance(s); "
        + (
            "receipt retained under the unique session directory"
            if output_path is None
            else f"receipt {output_path}"
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
