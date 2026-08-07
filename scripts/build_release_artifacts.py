#!/usr/bin/env python3
"""Build canonical release artifacts one configured target at a time."""

from __future__ import annotations

import argparse
import atexit
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable, Sequence

if os.name == "nt":
    import msvcrt
else:
    class _MsvcrtCompatibility:
        """Import-stable surface; authoritative native reads remain Windows-only."""

        @staticmethod
        def open_osfhandle(_handle: int, _flags: int) -> int:
            raise EvidenceFailure(
                "NON_WINDOWS_EVIDENCE_MODE",
                "authoritative evidence mode requires canonical Windows",
            )

        @staticmethod
        def get_osfhandle(_descriptor: int) -> int:
            raise EvidenceFailure(
                "NON_WINDOWS_EVIDENCE_MODE",
                "authoritative evidence mode requires canonical Windows",
            )

    msvcrt = _MsvcrtCompatibility()

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - the checked toolchain is Python 3.12.
    tomllib = None  # type: ignore[assignment]


RELEASE_BUILD_SCHEMA = "6529stream.release-build.v1"
GENERATOR_VERSION = "5"
DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_CONFIG = Path("foundry.toml")
DEFAULT_OUTPUT_DIR = Path("out-release")
MANIFEST_FILENAME = "release-build-manifest.json"
CANONICAL_BUILD_COMMAND = "python scripts/build_release_artifacts.py"
FOUNDRY_VERSION = "1.7.1"
SOLC_VERSION = "0.8.19"
SOLC_LONG_VERSION = "0.8.19+commit.7dd6d404"
EVM_VERSION = "paris"
OPTIMIZER_RUNS = 200
SANITIZED_ENVIRONMENT_PREFIXES = ("DAPP_", "FOUNDRY_")
CONTROLLED_FORGE_ENVIRONMENT = {"FOUNDRY_PROFILE": "default"}
TARGET_GROUPS = (
    ("production_contract", "production_contracts"),
    ("interface", "interfaces"),
)
RESTRICTED_RELEASE_SOURCE_ROOTS = frozenset({"script", "test"})
PORTABLE_COMPILER_PATHS = {
    "allowPaths": [".", "lib"],
    "basePath": ".",
    "includePaths": ["."],
}
TARGET_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
FORGE_BUILD_TIMESTAMP_RE = re.compile(
    r"^Build Timestamp:\s+.+$",
    flags=re.MULTILINE,
)
PORTABLE_FORGE_BUILD_TIMESTAMP = "Build Timestamp: <platform-packaging-timestamp>"
IJSON_SAFE_INTEGER_MAX = (1 << 53) - 1

R4_EVIDENCE_EVENT_SCHEMA = "6529stream.release-builder-event.r4.v1"
EVIDENCE_EVENT_SCHEMA = "6529stream.release-builder-event.v1"
R4_EVIDENCE_TERMINAL_SCHEMA = "6529stream.release-builder-terminal.r4.v1"
EVIDENCE_TERMINAL_SCHEMA = "6529stream.release-builder-terminal.v1"
R4_SOURCE_AGGREGATE_SHA256 = (
    "1EB0A58B8A1DCA624493839D41FA5267078E7FBA67B4AE6DF9205DD003659857"
)
R4_FOUNDRY_CONFIG_SHA256 = (
    "C356A459BC9919AE14225E59979601C8EAB26133B19C146E5928D28A7DAFBD61"
)
R4_TARGET_CONFIG_SHA256 = (
    "84B3A32B16B8C171130D0D5F5192F06B2D199D17EF25862FF04B433FD8C3B9F9"
)
R4_GROUP_MAP_SHA256 = (
    "5630717FF8C470F250780937C7333062D7CA84DCE87A0CB1510901E5FA18B913"
)
R4_CONSTRUCTOR_MAP_SHA256 = (
    "0A48FF8AEB3F4358D0AE8889693CCF136B33E1E1982E9497E6F1BB2429BDD06F"
)
R4_SUCCESS_EVENT_COUNT = 37
R4_SUCCESS_EVIDENCE_FILE_COUNT = 38
R4_SUCCESS_OUTPUT_FILE_COUNT = 37
R4_INITCODE_LIMIT = 49_152
R4_RUNTIME_PACKET_LIMIT = 24_576
R4_CODE_DEPOSIT_GAS_PER_BYTE = 200
R4_ARCHITECTURE_PREFIX = "smart-contracts/architecture/issue670/"


def _r4_source(name: str) -> str:
    return R4_ARCHITECTURE_PREFIX + name


_COMMON_SIX = (
    _r4_source("IStreamArtistFoundationOwnershipV1.sol"),
    "smart-contracts/IERC165.sol",
    "smart-contracts/IStreamArtistArchiveV2.sol",
    "smart-contracts/IStreamArtistRegistryValidationCommon.sol",
    "smart-contracts/IStreamGovernanceExecutor.sol",
)
_LIFECYCLE_COMMON = _COMMON_SIX + (
    _r4_source("StreamArtistLifecycleSkeletonBase.sol"),
    "smart-contracts/IStreamGasParameterHost.sol",
)
_WRITE_INTERFACES = (
    "smart-contracts/IStreamArtistRegistryWritesA.sol",
    "smart-contracts/IStreamArtistRegistryWritesB.sol",
    "smart-contracts/IStreamArtistRegistryWritesC.sol",
)


def _r4_group(
    index: int,
    source_name: str,
    sources: Sequence[str],
    aggregate: str,
) -> dict[str, Any]:
    source = _r4_source(source_name)
    return {
        "group": f"{index:03d}",
        "source": source,
        "sources": tuple(sorted(sources, key=str.casefold)),
        "aggregate_sha256": aggregate,
        "group_string": f"{index:03d}::{source}",
    }


R4_GROUPS = (
    _r4_group(0, "StreamArtistArchiveCompatibilityStateV3Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveCompatibilityStateV3Skeleton.sol"),), "C9BDE11D3DBD78A20D0CC63628ADBDB885F21CBDFBFA73022979AFA8161ECFBD"),
    _r4_group(1, "StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol"),), "FA33DD799CBA9CA213571D63D22AD2079A75254671F8535164B84EA35D95F036"),
    _r4_group(2, "StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol"),), "E509564C803BB073421C0ABC1AE75A16D6121E8B40983858E1801F2BE26ABF40"),
    _r4_group(3, "StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol", _LIFECYCLE_COMMON + (_r4_source("StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol"),), "E23BC0FBDF44281A9BB5E2A1941B31316A44B233147D4D93C9E83DA22642C99D"),
    _r4_group(4, "StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol"),), "255995D205A2D619F3FBA02E98B85C1E4EEE0C71DA84A2344407B712C51B2732"),
    _r4_group(5, "StreamArtistArchiveEvidenceStoreV2Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveEvidenceStoreV2Skeleton.sol"),), "7149D57E5E3C3F905063EE7ED152401DF8799E1CD77FCC888FEFB92681537D76"),
    _r4_group(6, "StreamArtistArchiveReadProjectionV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistArchiveReadProjectionV1Skeleton.sol"),), "8BE52656CC872C5718FAAE66642BCCDB1EC0C8DFC8059727826A50B8D06CA247"),
    _r4_group(7, "StreamArtistArchiveV2Skeleton.sol", _LIFECYCLE_COMMON + (_r4_source("StreamArtistArchiveV2Skeleton.sol"),), "A15BD83F911CE89308B16EFF506A9BA53E2DC463A6FD131A0D3FBDAC7BC49EC5"),
    _r4_group(8, "StreamArtistBindingLifecycleV1Skeleton.sol", _LIFECYCLE_COMMON + _WRITE_INTERFACES + (_r4_source("StreamArtistBindingLifecycleV1Skeleton.sol"),), "4348C8AC10AA9F1E7A94F8538C36EE532B58F90E41D2EBBC8EB76F9D82AEE17B"),
    _r4_group(9, "StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol"),), "CC3AE2FA3DA87E956A1FBA87231F0400AB1A5DE2E8A46F8CC529D9A1A7E07F3F"),
    _r4_group(10, "StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol"),), "C23DEE9FDD1A9CD14AFD515C54D10C6A99EA4355A4A8082D138AA974291CB94F"),
    _r4_group(11, "StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol", _COMMON_SIX + (_r4_source("StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol"),), "DBB22F56049D9097D1AAD9C9BAD1ADF3442A8EC8489D30FD74800991C25A933D"),
    _r4_group(12, "StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol", _LIFECYCLE_COMMON + _WRITE_INTERFACES + (_r4_source("StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol"),), "DBC0ADC083758109CED4DBBABC95C2C757412B33A0F21C966E885E68A287D3EE"),
    _r4_group(13, "StreamArtistDirectoryV1Skeleton.sol", _LIFECYCLE_COMMON + (_r4_source("StreamArtistDirectoryV1Skeleton.sol"),), "574C3F466321A8F6661DF0930DC57F9D715618E17877C14B1AFF2D7CA30502A2"),
    _r4_group(14, "StreamArtistFoundationControllerV2Skeleton.sol", _COMMON_SIX + ("smart-contracts/IStreamArtistRegistryWritesA.sol", _r4_source("StreamArtistFoundationControllerV2Skeleton.sol")), "537E6C21E7EC01BB8BD54DD820A2E0446A54520C39E97AF449F63BE4EE2F5D45"),
    _r4_group(15, "StreamArtistFoundationReadFacadeV1Skeleton.sol", _LIFECYCLE_COMMON + ("smart-contracts/IStreamArtistConsent.sol", "smart-contracts/IStreamArtistRead.sol", "smart-contracts/IStreamArtistRecoveryEvidence.sol", "smart-contracts/IStreamArtistRegistry.sol", _r4_source("StreamArtistFoundationReadFacadeV1Skeleton.sol")), "0F0025EF311EC0A085B1A8DA449B97C201E6D8AED8D1A2A4D31836E50B2D77BF"),
    _r4_group(16, "StreamArtistFutureControllerCompatibilitySkeletons.sol", _LIFECYCLE_COMMON + ("smart-contracts/IStreamArtistRegistryWritesB.sol", "smart-contracts/IStreamArtistRegistryWritesC.sol", _r4_source("StreamArtistFutureControllerCompatibilitySkeletons.sol")), "A4C7F9C082A29DF3D451C34A4DD6CD83377B8B3D4BD495BDB429A08787E0E8B3"),
)


def _target_authority(
    semantic_id: str,
    name: str,
    source_name: str,
    signature: str,
    runtime_cap: int,
) -> dict[str, Any]:
    types = signature.removeprefix("constructor(").removesuffix(")")
    words = 0 if not types else len(types.split(","))
    return {
        "semantic_id": semantic_id,
        "target": name,
        "source": _r4_source(source_name),
        "signature": signature,
        "input_types": tuple([] if not types else types.split(",")),
        "words": words,
        "bytes": words * 32,
        "runtime_cap": runtime_cap,
    }


R4_TARGET_AUTHORITIES = (
    _target_authority("Store", "StreamArtistArchiveEvidenceStoreV2Skeleton", "StreamArtistArchiveEvidenceStoreV2Skeleton.sol", "constructor(address,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)", 19_968),
    _target_authority("Coordinator", "StreamArtistArchiveEvidenceCoordinatorV1Skeleton", "StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)", 20_480),
    _target_authority("EvidenceDirectory", "StreamArtistArchiveEvidenceDirectoryV1Skeleton", "StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol", "constructor(address,address,bytes32,bytes32,bytes32,bytes32)", 18_432),
    _target_authority("CompatibilityState", "StreamArtistArchiveCompatibilityStateV3Skeleton", "StreamArtistArchiveCompatibilityStateV3Skeleton.sol", "constructor(address,bytes32,address,bytes32,address,bytes32,bytes32,bytes32,address,bytes32,bytes32)", 21_040),
    _target_authority("ReadProjection", "StreamArtistArchiveReadProjectionV1Skeleton", "StreamArtistArchiveReadProjectionV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,address,bytes32,address,bytes32,bytes32)", 16_384),
    _target_authority("Admission", "StreamArtistArchiveEvidenceAdmissionV3Skeleton", "StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol", "constructor(address,bytes32,address,bytes32,address,bytes32,address,bytes32,bytes32,bytes32,address,bytes32,bytes32,address,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)", 20_528),
    _target_authority("Materializer", "StreamArtistArchiveEvidenceMaterializerV1Skeleton", "StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,address,bytes32,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32)", 18_432),
    _target_authority("ArchiveV2", "StreamArtistArchiveV2Skeleton", "StreamArtistArchiveV2Skeleton.sol", "constructor(address,address,address,bytes32)", 22_064),
    _target_authority("Transition", "StreamArtistBindingTransitionArchiveVerifierV1Skeleton", "StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,bytes32,bytes32)", 22_064),
    _target_authority("Proposal", "StreamArtistBindingProposalArchiveVerifierV1Skeleton", "StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,bytes32,bytes32)", 22_064),
    _target_authority("Collaborator", "StreamArtistCollaboratorArchiveVerifierV1Skeleton", "StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol", "constructor(address,bytes32,address,bytes32,bytes32,bytes32)", 22_064),
    _target_authority("ArtistDirectory", "StreamArtistDirectoryV1Skeleton", "StreamArtistDirectoryV1Skeleton.sol", "constructor(address,address,bytes32)", 22_064),
    _target_authority("BindingLifecycle", "StreamArtistBindingLifecycleV1Skeleton", "StreamArtistBindingLifecycleV1Skeleton.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
    _target_authority("CollaboratorLifecycle", "StreamArtistCollaboratorIdentityLifecycleV1Skeleton", "StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
    _target_authority("ValidatorA", "StreamArtistFoundationValidatorAV2Skeleton", "StreamArtistFutureControllerCompatibilitySkeletons.sol", "constructor(address,address,address,bytes32)", 22_064),
    _target_authority("ControllerA", "StreamArtistFoundationControllerV2Skeleton", "StreamArtistFoundationControllerV2Skeleton.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
    _target_authority("ControllerB", "StreamArtistFutureControllerBCompatibilityV1Skeleton", "StreamArtistFutureControllerCompatibilitySkeletons.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
    _target_authority("ControllerC", "StreamArtistFutureControllerCCompatibilityV1Skeleton", "StreamArtistFutureControllerCompatibilitySkeletons.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
    _target_authority("ReadFacade", "StreamArtistFoundationReadFacadeV1Skeleton", "StreamArtistFoundationReadFacadeV1Skeleton.sol", "constructor(address,address,address,address,address,bytes32)", 22_064),
)

R4_AGGREGATE_GATES = {
    3: (
        ("AGG_G3_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory"), "runtime_bytes", 58_880),
        ("AGG_G3_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory"), "code_deposit_gas", 11_776_000),
    ),
    7: (
        ("AGG_G7_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "Admission", "Materializer"), "runtime_bytes", 118_880),
        ("AGG_G7_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "Admission", "Materializer"), "code_deposit_gas", 23_776_000),
    ),
    8: (
        ("AGG_G8_READ_RUNTIME", ("Store", "CompatibilityState", "ReadProjection", "ArchiveV2"), "runtime_bytes", 79_456),
        ("AGG_G8_READ_DEPOSIT", ("Store", "CompatibilityState", "ReadProjection", "ArchiveV2"), "code_deposit_gas", 15_891_200),
        ("AGG_G8_EIGHT_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "ReadProjection", "Admission", "Materializer", "ArchiveV2"), "runtime_bytes", 157_328),
        ("AGG_G8_EIGHT_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "ReadProjection", "Admission", "Materializer", "ArchiveV2"), "code_deposit_gas", 31_465_600),
    ),
    11: (
        ("AGG_G11_VERIFIER_RUNTIME", ("Transition", "Proposal", "Collaborator"), "runtime_bytes", 65_000),
        ("AGG_G11_FULL_INITCODE", ("Transition", "Proposal", "Collaborator"), "full_initcode_bytes", 66_500),
        ("AGG_G11_DEPOSIT", ("Transition", "Proposal", "Collaborator"), "code_deposit_gas", 13_000_000),
    ),
}


class ReleaseBuildError(RuntimeError):
    """Raised when canonical release artifacts cannot be built or validated."""


class EvidenceFailure(ReleaseBuildError):
    """One typed R4 operation, predicate, call, or state-machine failure."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        operands: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(f"{code}: {message}")
        self.code = code
        self.operands = dict(operands or {})


@dataclass(frozen=True)
class CommandResult:
    """Captured result of one direct child call made by the builder."""

    launched: bool
    returncode: int | None
    stdout: bytes
    stderr: bytes


BYTECODE_STEPS = (
    "CREATION_CONTAINER",
    "CREATION_OBJECT_STRING",
    "NORMALIZE_CREATION_PREFIX",
    "CREATION_NONEMPTY",
    "CREATION_EVEN_LENGTH",
    "CREATION_PLACEHOLDER_ABSENT",
    "CREATION_FULL_HEX",
    "CREATION_LINK_REFERENCES_EMPTY",
    "RUNTIME_CONTAINER",
    "RUNTIME_OBJECT_STRING",
    "NORMALIZE_RUNTIME_PREFIX",
    "RUNTIME_NONEMPTY",
    "RUNTIME_EVEN_LENGTH",
    "RUNTIME_PLACEHOLDER_ABSENT",
    "RUNTIME_FULL_HEX",
    "RUNTIME_LINK_REFERENCES_EMPTY",
    "CONSTRUCTOR_ABI_SHAPE",
    "DERIVE_CONSTRUCTOR_METRICS",
    "CONSTRUCTOR_METRICS_EXACT",
    "DECODE_CREATION_BYTES",
    "COMPUTE_FULL_INITCODE",
    "FULL_INITCODE_LIMIT",
    "DECODE_RUNTIME_BYTES",
    "RUNTIME_PACKET_LIMIT",
    "RUNTIME_TARGET_CAP",
    "COMPUTE_CODE_DEPOSIT_GAS",
)
GROUP_CLOSURES = R4_GROUPS
CONSTRUCTOR_AUTHORITY = R4_TARGET_AUTHORITIES
SIZE_GATES = R4_AGGREGATE_GATES


class _ByHandleFileInformation(ctypes.Structure):
    _fields_ = (
        ("dwFileAttributes", wintypes.DWORD),
        ("ftCreationTime", wintypes.FILETIME),
        ("ftLastAccessTime", wintypes.FILETIME),
        ("ftLastWriteTime", wintypes.FILETIME),
        ("dwVolumeSerialNumber", wintypes.DWORD),
        ("nFileSizeHigh", wintypes.DWORD),
        ("nFileSizeLow", wintypes.DWORD),
        ("nNumberOfLinks", wintypes.DWORD),
        ("nFileIndexHigh", wintypes.DWORD),
        ("nFileIndexLow", wintypes.DWORD),
    )


_INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
_GENERIC_READ = 0x80000000
_FILE_READ_ATTRIBUTES = 0x0080
_FILE_SHARE_READ = 0x00000001
_FILE_SHARE_WRITE = 0x00000002
_FILE_SHARE_DELETE = 0x00000004
_OPEN_EXISTING = 3
_FILE_ATTRIBUTE_NORMAL = 0x00000080
_FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
_MOVEFILE_WRITE_THROUGH = 0x00000008
_WAIT_OBJECT_0 = 0x00000000
_WAIT_ABANDONED = 0x00000080
_WAIT_TIMEOUT = 0x00000102
_R4_KERNEL32: Any | None = None
_R4_ACTIVE_EVIDENCE_LOCKS: list["R4WindowsDirectoryLock"] = []


def _r4_kernel32() -> Any:
    global _R4_KERNEL32
    if os.name != "nt":
        raise EvidenceFailure(
            "NON_WINDOWS_EVIDENCE_MODE", "R4 evidence mode requires Windows",
        )
    if _R4_KERNEL32 is not None:
        return _R4_KERNEL32
    kernel32 = ctypes.WinDLL("kernel32.dll", use_last_error=True)
    kernel32.CreateFileW.argtypes = (
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
        wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
    )
    kernel32.CreateFileW.restype = wintypes.HANDLE
    kernel32.GetFileInformationByHandle.argtypes = (
        wintypes.HANDLE, ctypes.POINTER(_ByHandleFileInformation),
    )
    kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
    kernel32.CreateMutexW.argtypes = (ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR)
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.ReleaseMutex.argtypes = (wintypes.HANDLE,)
    kernel32.ReleaseMutex.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
    kernel32.CloseHandle.restype = wintypes.BOOL
    kernel32.MoveFileExW.argtypes = (
        wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
    )
    kernel32.MoveFileExW.restype = wintypes.BOOL
    _R4_KERNEL32 = kernel32
    return kernel32


def _r4_winerror(operation: str) -> EvidenceFailure:
    error = ctypes.get_last_error()
    return EvidenceFailure(
        f"OP_{operation}_EXCEPTION",
        f"Windows error {error}: {ctypes.FormatError(error).strip()}",
        operands={"winerror": error},
    )


def _r4_open_windows_handle(path: Path, *, directory: bool, deny_delete: bool) -> int:
    kernel32 = _r4_kernel32()
    desired_access = _FILE_READ_ATTRIBUTES if directory else _GENERIC_READ
    share = _FILE_SHARE_READ | _FILE_SHARE_WRITE
    if not deny_delete:
        share |= _FILE_SHARE_DELETE
    flags = _FILE_FLAG_BACKUP_SEMANTICS if directory else _FILE_ATTRIBUTE_NORMAL
    handle = kernel32.CreateFileW(
        str(path),
        desired_access,
        share,
        None,
        _OPEN_EXISTING,
        flags,
        None,
    )
    if handle == _INVALID_HANDLE_VALUE:
        raise _r4_winerror("OPEN_FILE_IDENTITY")
    return int(handle)


def _r4_identity_from_handle(handle: int) -> tuple[int, int]:
    information = _ByHandleFileInformation()
    if not _r4_kernel32().GetFileInformationByHandle(
        handle,
        ctypes.byref(information),
    ):
        raise _r4_winerror("READ_FILE_IDENTITY")
    file_index = (int(information.nFileIndexHigh) << 32) | int(
        information.nFileIndexLow
    )
    return int(information.dwVolumeSerialNumber), file_index


def _r4_close_windows_handle(handle: int) -> None:
    if handle and handle != _INVALID_HANDLE_VALUE:
        _r4_kernel32().CloseHandle(handle)


def _r4_has_alternate_data_stream(path: Path) -> bool:
    tail = str(path)[len(path.anchor) :]
    return ":" in tail


def _r4_path_is_link_or_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attributes = getattr(os.lstat(path), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(reparse_flag and attributes & reparse_flag)


def _r4_reject_reparse_components_absolute(path: Path, label: str) -> None:
    cursor = Path(path.anchor)
    for part in path.parts[1:]:
        cursor /= part
        if _r4_path_is_link_or_reparse(cursor):
            raise EvidenceFailure(
                "PATH_REPARSE_POINT",
                f"{label} contains a link, junction, or reparse component: {cursor}",
            )


def r4_validate_absolute_ordinary_path(
    value: Path,
    label: str,
    *,
    directory: bool,
) -> Path:
    if os.name != "nt":
        raise EvidenceFailure("NON_WINDOWS_EVIDENCE_MODE", "R4 evidence mode requires Windows")
    if not value.is_absolute():
        raise EvidenceFailure("PATH_NOT_ABSOLUTE", f"{label} must be absolute: {value}")
    lexical = Path(os.path.abspath(os.path.normpath(value)))
    if _r4_has_alternate_data_stream(lexical):
        raise EvidenceFailure("PATH_ALTERNATE_DATA_STREAM", f"{label} uses an alternate data stream")
    _r4_reject_reparse_components_absolute(lexical, label)
    try:
        resolved = lexical.resolve(strict=True)
    except (FileNotFoundError, OSError) as exc:
        raise EvidenceFailure("PATH_MISSING", f"{label} is missing: {lexical}") from exc
    if directory:
        if not resolved.is_dir():
            raise EvidenceFailure("PATH_NOT_DIRECTORY", f"{label} is not a directory: {resolved}")
    elif not resolved.is_file():
        raise EvidenceFailure("PATH_NOT_FILE", f"{label} is not an ordinary file: {resolved}")
    if _r4_path_is_link_or_reparse(resolved):
        raise EvidenceFailure("PATH_REPARSE_POINT", f"{label} is a link or reparse point: {resolved}")
    return resolved


def r4_windows_path_identity(path: Path, *, directory: bool = False) -> dict[str, str]:
    handle = _r4_open_windows_handle(path, directory=directory, deny_delete=False)
    try:
        volume_serial, file_index = _r4_identity_from_handle(handle)
    finally:
        _r4_close_windows_handle(handle)
    return {
        "volume_serial": f"{volume_serial:08X}",
        "file_index": f"{file_index:016X}",
    }


def _r4_read_required_bytes(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing required file: {path}") from exc
    except OSError as exc:
        raise ReleaseBuildError(f"unable to read required file {path}: {exc}") from exc


def _r4_sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def r4_windows_file_receipt(
    path: Path,
    label: str,
    *,
    directory: bool = False,
) -> dict[str, Any]:
    resolved = r4_validate_absolute_ordinary_path(path, label, directory=directory)
    before = r4_windows_path_identity(resolved, directory=directory)
    if directory:
        byte_count: int | None = None
        digest: str | None = None
    else:
        raw = _r4_read_required_bytes(resolved)
        byte_count = len(raw)
        digest = _r4_sha256_bytes(raw)
    after = r4_windows_path_identity(resolved, directory=directory)
    if before != after:
        raise EvidenceFailure(
            "FILE_IDENTITY_MISMATCH",
            f"{label} changed identity while its checkpoint was read",
            operands={"before": before, "after": after},
        )
    return {
        "path": str(resolved),
        "identity": before,
        "byte_count": byte_count,
        "sha256": digest,
    }


class R4WindowsDirectoryLock:
    """Same-session mutex keyed by the held evidence-directory file identity."""

    def __init__(self, path: Path, directory_handle: int, mutex_handle: int, name: str) -> None:
        self.path = path
        self.directory_handle = directory_handle
        self.mutex_handle = mutex_handle
        self.name = name
        self.owned = True

    @classmethod
    def acquire(cls, path: Path, *, recovery: bool = False) -> "R4WindowsDirectoryLock":
        resolved = r4_validate_absolute_ordinary_path(
            path, "evidence directory", directory=True,
        )
        directory_handle = _r4_open_windows_handle(
            resolved,
            directory=True,
            deny_delete=True,
        )
        mutex_handle = 0
        owned = False
        try:
            volume_serial, file_index = _r4_identity_from_handle(directory_handle)
            name = f"Local\\6529Stream.ReleaseBuilder.{volume_serial:08X}-{file_index:016X}"
            if any(lock.owned and lock.name == name for lock in _R4_ACTIVE_EVIDENCE_LOCKS):
                raise EvidenceFailure(
                    "EVIDENCE_LOCKED",
                    "evidence directory is already owned by this process",
                )
            mutex_handle = int(_r4_kernel32().CreateMutexW(None, False, name))
            if not mutex_handle:
                raise _r4_winerror("CREATE_EVIDENCE_MUTEX")
            wait_result = int(_r4_kernel32().WaitForSingleObject(mutex_handle, 0))
            if wait_result == _WAIT_TIMEOUT:
                raise EvidenceFailure("EVIDENCE_LOCKED", "evidence directory already has an owner")
            if wait_result == _WAIT_ABANDONED and not recovery:
                owned = True
                raise EvidenceFailure("LOCK_ABANDONED", "build mode rejects abandoned mutex ownership")
            if wait_result not in (_WAIT_OBJECT_0, _WAIT_ABANDONED):
                raise EvidenceFailure(
                    "LOCK_WAIT_FAILED",
                    f"unexpected mutex wait result {wait_result}",
                    operands={"wait_result": wait_result},
                )
            owned = True
            current = r4_windows_path_identity(resolved, directory=True)
            expected = {
                "volume_serial": f"{volume_serial:08X}",
                "file_index": f"{file_index:016X}",
            }
            if current != expected:
                raise EvidenceFailure(
                    "EVIDENCE_DIRECTORY_IDENTITY_MISMATCH",
                    "evidence directory path changed identity after lock acquisition",
                    operands={"expected": expected, "actual": current},
                )
            lock = cls(resolved, directory_handle, mutex_handle, name)
            _R4_ACTIVE_EVIDENCE_LOCKS.append(lock)
            return lock
        except BaseException:
            if owned and mutex_handle:
                _r4_kernel32().ReleaseMutex(mutex_handle)
            if mutex_handle:
                _r4_close_windows_handle(mutex_handle)
            _r4_close_windows_handle(directory_handle)
            raise

    def close(self) -> None:
        if not self.owned:
            return
        self.owned = False
        _r4_kernel32().ReleaseMutex(self.mutex_handle)
        _r4_close_windows_handle(self.mutex_handle)
        _r4_close_windows_handle(self.directory_handle)
        if self in _R4_ACTIVE_EVIDENCE_LOCKS:
            _R4_ACTIVE_EVIDENCE_LOCKS.remove(self)


def _r4_close_active_evidence_locks() -> None:
    for lock in tuple(reversed(_R4_ACTIVE_EVIDENCE_LOCKS)):
        try:
            lock.close()
        except BaseException:
            pass


atexit.register(_r4_close_active_evidence_locks)


def _r4_validate_evidence_json_value(value: Any, path: str = "evidence") -> None:
    if value is None or isinstance(value, (bool, str)):
        return
    if isinstance(value, int) and not isinstance(value, bool):
        if abs(value) > IJSON_SAFE_INTEGER_MAX:
            raise EvidenceFailure(
                "EVIDENCE_INTEGER_RANGE",
                f"{path} integer is outside the I-JSON interoperable range",
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _r4_validate_evidence_json_value(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise EvidenceFailure("EVIDENCE_MEMBER_TYPE", f"{path} has a non-string key")
            _r4_validate_evidence_json_value(item, f"{path}.{key}")
        return
    raise EvidenceFailure(
        "EVIDENCE_VALUE_TYPE",
        f"{path} has unsupported type {type(value).__name__}",
    )


def _r4_reject_non_unicode_scalars(value: Any, path: str) -> None:
    if isinstance(value, str):
        if any(0xD800 <= ord(character) <= 0xDFFF for character in value):
            raise ReleaseBuildError(
                f"{path} contains a non-Unicode-scalar surrogate code point",
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _r4_reject_non_unicode_scalars(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _r4_reject_non_unicode_scalars(key, f"{path}.<member>")
            _r4_reject_non_unicode_scalars(item, f"{path}.{key}")


def r4_canonical_evidence_bytes(value: Any) -> bytes:
    _r4_validate_evidence_json_value(value)
    _r4_reject_non_unicode_scalars(value, "evidence")
    try:
        return (
            json.dumps(
                value,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=False,
            )
            + "\n"
        ).encode("utf-8", "strict")
    except (TypeError, ValueError, UnicodeError) as exc:
        raise EvidenceFailure("EVIDENCE_ENCODING", f"evidence is not canonical JSON: {exc}") from exc


def _r4_windows_move_no_replace(source: Path, destination: Path, operation: str) -> None:
    if destination.exists() or _r4_path_is_link_or_reparse(destination):
        raise EvidenceFailure(
            f"{operation}_COLLISION",
            f"destination already exists: {destination}",
        )
    if source.parent.stat().st_dev != destination.parent.stat().st_dev:
        raise EvidenceFailure(
            f"{operation}_CROSS_VOLUME",
            "atomic publication requires one volume",
            operands={"source": str(source), "destination": str(destination)},
        )
    if not _r4_kernel32().MoveFileExW(
        str(source),
        str(destination),
        _MOVEFILE_WRITE_THROUGH,
    ):
        raise _r4_winerror(operation)


def r4_publish_json_no_replace(directory: Path, name: str, value: Any) -> tuple[bytes, str]:
    if Path(name).name != name or not name.endswith(".json"):
        raise EvidenceFailure("EVIDENCE_FILENAME", f"invalid evidence filename: {name!r}")
    raw = r4_canonical_evidence_bytes(value)
    destination = directory / name
    for attempt in range(32):
        temp = directory / f".{name}.{os.getpid()}.{time.monotonic_ns()}.{attempt}.tmp"
        try:
            descriptor = os.open(
                temp,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0),
                0o600,
            )
            break
        except FileExistsError:
            continue
    else:
        raise EvidenceFailure("EVIDENCE_TEMP_COLLISION", "unable to allocate a unique evidence temp")
    flush_error: BaseException | None = None
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise OSError("short evidence write")
            view = view[written:]
        os.fsync(descriptor)
    except BaseException as exc:
        flush_error = exc
    finally:
        try:
            os.close(descriptor)
        except BaseException as exc:
            if flush_error is None:
                flush_error = exc
    if flush_error is not None:
        try:
            os.unlink(temp)
        except OSError:
            pass
        raise EvidenceFailure(
            "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION",
            f"unable to flush {temp}: {flush_error}",
        ) from flush_error
    _r4_windows_move_no_replace(temp, destination, "PUBLISH_EVIDENCE_NO_REPLACE")
    return raw, _r4_sha256_bytes(raw)


def r4_install_output_no_replace(staged: Path, output_dir: Path) -> None:
    if not staged.is_dir() or _r4_path_is_link_or_reparse(staged):
        raise EvidenceFailure(
            "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION",
            f"staged output is not an ordinary directory: {staged}",
        )
    _r4_windows_move_no_replace(staged, output_dir, "INSTALL_OUTPUT_NO_REPLACE")


def _r4_captured_subprocess(command: list[str], cwd: Path, environment: dict[str, str]) -> CommandResult:
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        check=False,
        capture_output=True,
    )
    if not isinstance(completed, subprocess.CompletedProcess):
        raise TypeError("subprocess.run did not return CompletedProcess")
    return CommandResult(
        launched=True,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def _r4_sanitized_forge_environment() -> dict[str, str]:
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.upper().startswith(SANITIZED_ENVIRONMENT_PREFIXES)
    }
    environment.update(CONTROLLED_FORGE_ENVIRONMENT)
    return environment


class R4ExecutionJournal:
    default_runner: CommandRunner | None = None

    def __init__(
        self,
        evidence_dir: Path,
        invocation_id: str,
        static_receipts: dict[str, Any],
        forge_bin: Path,
        solc_bin: Path,
    ) -> None:
        self.evidence_dir = evidence_dir
        self.invocation_id = invocation_id
        self.static_receipts = static_receipts
        self.forge_bin = forge_bin
        self.solc_bin = solc_bin
        self.sequence = -1
        self.event_head_sha256: str | None = None
        self.calls: list[dict[str, Any]] = []
        self.checkpoints: list[dict[str, Any]] = []
        self.terminal: dict[str, Any] | None = None

    def _publish_event(
        self,
        filename: str,
        event_type: str,
        phase: str,
        operands: dict[str, Any],
    ) -> dict[str, Any]:
        sequence = self.sequence + 1
        event = {
            "schema": R4_EVIDENCE_EVENT_SCHEMA,
            "invocation_id": self.invocation_id,
            "sequence": sequence,
            "previous_event_sha256": self.event_head_sha256,
            "event_type": event_type,
            "phase": phase,
            "operands": operands,
        }
        _, digest = r4_publish_json_no_replace(self.evidence_dir, filename, event)
        self.sequence = sequence
        self.event_head_sha256 = digest
        return event

    def publish_started(self) -> dict[str, Any]:
        if self.sequence != -1:
            raise EvidenceFailure("STATE_NOT_EMPTY", "STARTED can only be published from EMPTY")
        return self._publish_event(
            "execution-started.json",
            "execution_started",
            "execution",
            {"path_tokens": self.static_receipts},
        )

    def _checkpoint(self, label: str) -> dict[str, Any]:
        checkpoint = {
            "label": label,
            "forge": r4_windows_file_receipt(self.forge_bin, "Forge executable"),
            "solc": r4_windows_file_receipt(self.solc_bin, "Solc executable"),
        }
        for token in ("forge", "solc"):
            initial = self.static_receipts[token]
            actual = checkpoint[token]
            comparable = ("path", "identity", "byte_count", "sha256")
            if any(actual.get(field) != initial.get(field) for field in comparable):
                raise EvidenceFailure(
                    "COMPILER_IDENTITY_CHECKPOINT_MISMATCH",
                    f"{token} differs from its initial authenticated checkpoint",
                    operands={"checkpoint": label, "expected": initial, "actual": actual},
                )
        self.checkpoints.append(checkpoint)
        return checkpoint

    def invoke(
        self,
        ordinal: int,
        command: list[str],
        cwd: Path,
        *,
        phase: str,
        group_string: str | None,
        runner: CommandRunner | None = None,
    ) -> CommandResult:
        if self.sequence < 0:
            raise EvidenceFailure("STATE_NOT_STARTED", "a call cannot precede STARTED")
        if ordinal != len(self.calls):
            raise EvidenceFailure(
                "CALL_ORDINAL",
                f"expected ordinal {len(self.calls):03d}, got {ordinal:03d}",
            )
        environment = _r4_sanitized_forge_environment()
        checkpoint_before = self._checkpoint(f"invocation-{ordinal:03d}-before")
        start_monotonic_ms = time.monotonic_ns() // 1_000_000
        self._publish_event(
            f"invocation-{ordinal:03d}-start.json",
            "invocation_start",
            phase,
            {
                "ordinal": ordinal,
                "group_string": group_string,
                "executable": command[0],
                "argv": command,
                "argv_sha256": _r4_sha256_bytes(r4_canonical_evidence_bytes(command)),
                "environment_sha256": _r4_sha256_bytes(r4_canonical_evidence_bytes(environment)),
                "environment_entry_count": len(environment),
                "cwd": str(cwd),
                "start_monotonic_ms": start_monotonic_ms,
                "checkpoint": checkpoint_before,
            },
        )
        result = CommandResult(True, 0, b"", b"")
        call_error: BaseException | None = None
        try:
            if runner is None or runner is type(self).default_runner:
                result = _r4_captured_subprocess(command, cwd, environment)
            else:
                returned = runner(command, cwd)
                if isinstance(returned, CommandResult):
                    result = returned
                elif isinstance(returned, subprocess.CompletedProcess):
                    result = CommandResult(
                        True,
                        returned.returncode,
                        bytes(returned.stdout or b""),
                        bytes(returned.stderr or b""),
                    )
                else:
                    result = CommandResult(True, 0, b"", b"")
        except BaseException as exc:
            call_error = exc
        end_monotonic_ms = time.monotonic_ns() // 1_000_000
        checkpoint_after: dict[str, Any] | None = None
        checkpoint_error: BaseException | None = None
        try:
            checkpoint_after = self._checkpoint(f"invocation-{ordinal:03d}-after")
        except BaseException as exc:
            checkpoint_error = exc
            if call_error is None:
                call_error = exc
        exception_value = call_error or checkpoint_error
        exit_operands = {
            "ordinal": ordinal,
            "group_string": group_string,
            "launched": result.launched,
            "exit_code": result.returncode,
            "start_monotonic_ms": start_monotonic_ms,
            "end_monotonic_ms": end_monotonic_ms,
            "stdout_sha256": _r4_sha256_bytes(result.stdout),
            "stderr_sha256": _r4_sha256_bytes(result.stderr),
            "exception_type": type(exception_value).__name__ if exception_value else None,
            "exception_sha256": (
                _r4_sha256_bytes(str(exception_value).encode("utf-8"))
                if exception_value
                else None
            ),
            "checkpoint": checkpoint_after,
        }
        self._publish_event(
            f"invocation-{ordinal:03d}-exit.json",
            "invocation_exit",
            phase,
            exit_operands,
        )
        call_record = {
            "ordinal": ordinal,
            "phase": phase,
            "group_string": group_string,
            "argv": command,
            **exit_operands,
        }
        self.calls.append(call_record)
        if call_error is not None:
            if isinstance(call_error, EvidenceFailure):
                raise call_error
            raise EvidenceFailure(
                "CALL_EXCEPTION",
                f"invocation {ordinal:03d} raised {type(call_error).__name__}",
                operands=exit_operands,
            ) from call_error
        if result.returncode != 0:
            raise EvidenceFailure(
                "FORGE_NONZERO_EXIT",
                f"invocation {ordinal:03d} exited {result.returncode}",
                operands=exit_operands,
            )
        return result

    def publish_terminal(
        self,
        status: str,
        first_red: dict[str, Any] | None,
        *,
        results: dict[str, Any],
    ) -> dict[str, Any]:
        if self.sequence < 0 or self.event_head_sha256 is None:
            raise EvidenceFailure(
                "STATE_NOT_STARTED",
                "terminal publication requires a canonical STARTED sentinel",
            )
        if status not in ("GO", "NO_GO"):
            raise EvidenceFailure("TERMINAL_STATUS", f"invalid terminal status {status!r}")
        if self.terminal is not None:
            raise EvidenceFailure("TERMINAL_EXISTS", "terminal already published")
        terminal = {
            "schema": R4_EVIDENCE_TERMINAL_SCHEMA,
            "invocation_id": self.invocation_id,
            "status": status,
            "first_red": first_red,
            "event_count": self.sequence + 1,
            "event_head_sha256": self.event_head_sha256,
            "calls": self.calls,
            "checkpoints": self.checkpoints,
            "results": results,
            "no_retry": True,
        }
        r4_publish_json_no_replace(self.evidence_dir, "terminal.json", terminal)
        self.terminal = terminal
        return terminal


def _validate_evidence_json_value(value: Any, path: str = "evidence") -> None:
    if value is None or isinstance(value, (bool, str)):
        return
    if isinstance(value, int) and not isinstance(value, bool):
        if abs(value) > IJSON_SAFE_INTEGER_MAX:
            raise EvidenceFailure(
                "EVIDENCE_INTEGER_RANGE",
                f"{path} integer is outside the I-JSON interoperable range",
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _validate_evidence_json_value(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise EvidenceFailure(
                    "EVIDENCE_MEMBER_TYPE", f"{path} has a non-string key",
                )
            _validate_evidence_json_value(item, f"{path}.{key}")
        return
    raise EvidenceFailure(
        "EVIDENCE_VALUE_TYPE",
        f"{path} has unsupported type {type(value).__name__}",
    )


def canonical_evidence_bytes(value: Any) -> bytes:
    _validate_evidence_json_value(value)
    reject_non_unicode_scalars(value, "evidence")
    try:
        return (
            json.dumps(
                value,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=False,
            )
            + "\n"
        ).encode("utf-8", "strict")
    except (TypeError, ValueError, UnicodeError) as exc:
        raise EvidenceFailure(
            "EVIDENCE_ENCODING", f"evidence is not canonical JSON: {exc}",
        ) from exc


def _windows_move_no_replace(source: Path, destination: Path, operation: str) -> None:
    if destination.exists() or path_is_link_or_reparse(destination):
        raise EvidenceFailure(
            f"{operation}_COLLISION", f"destination already exists: {destination}",
        )
    if source.parent.stat().st_dev != destination.parent.stat().st_dev:
        raise EvidenceFailure(
            f"{operation}_CROSS_VOLUME", "atomic publication requires one volume",
            operands={"source": str(source), "destination": str(destination)},
        )
    if not _kernel32().MoveFileExW(
        str(source), str(destination), _MOVEFILE_WRITE_THROUGH,
    ):
        error = int(ctypes.get_last_error())
        raise EvidenceFailure(
            f"OP_{operation}_EXCEPTION",
            f"Windows error {error}: {ctypes.FormatError(error).strip()}",
            operands={"winerror": error},
        )


def publish_json_no_replace(
    directory: Path, name: str, value: Any,
) -> tuple[bytes, str]:
    if Path(name).name != name or not name.endswith(".json"):
        raise EvidenceFailure(
            "EVIDENCE_FILENAME", f"invalid evidence filename: {name!r}",
        )
    raw = canonical_evidence_bytes(value)
    destination = directory / name
    for attempt in range(32):
        temp = directory / f".{name}.{os.getpid()}.{time.monotonic_ns()}.{attempt}.tmp"
        try:
            descriptor = os.open(
                temp,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0),
                0o600,
            )
            break
        except FileExistsError:
            continue
    else:
        raise EvidenceFailure(
            "EVIDENCE_TEMP_COLLISION", "unable to allocate a unique evidence temp",
        )
    flush_error: BaseException | None = None
    try:
        view = memoryview(raw)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise OSError("short evidence write")
            view = view[written:]
        os.fsync(descriptor)
    except BaseException as exc:
        flush_error = exc
    finally:
        try:
            os.close(descriptor)
        except BaseException as exc:
            if flush_error is None:
                flush_error = exc
    if flush_error is not None:
        try:
            os.unlink(temp)
        except OSError:
            pass
        raise EvidenceFailure(
            "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION", f"unable to flush {temp}: {flush_error}",
        ) from flush_error
    _windows_move_no_replace(temp, destination, "PUBLISH_EVIDENCE_NO_REPLACE")
    return raw, sha256_bytes(raw)


def install_output_no_replace(staged: Path, output_dir: Path) -> None:
    if not staged.is_dir() or path_is_link_or_reparse(staged):
        raise EvidenceFailure(
            "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION",
            f"staged output is not an ordinary directory: {staged}",
        )
    _windows_move_no_replace(staged, output_dir, "INSTALL_OUTPUT_NO_REPLACE")


def _captured_subprocess(
    command: list[str], cwd: Path, environment: dict[str, str],
) -> CommandResult:
    completed = subprocess.run(
        command, cwd=cwd, env=environment, check=False, capture_output=True,
    )
    if not isinstance(completed, subprocess.CompletedProcess):
        raise TypeError("subprocess.run did not return CompletedProcess")
    return CommandResult(
        launched=True,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def _r11_open_directory_chain(
    path: Path | str,
    retained_directory_token: str,
) -> tuple[str, str, list[tuple[int, dict[str, str], int, int | None, str | None]]]:
    _r11_validate_filetoken(retained_directory_token)
    root_path, components, _ = _r11_absolute_parts(path)
    retained: list[tuple[int, dict[str, str], int, int | None, str | None]] = []
    root_handle, root_identity, root_attributes, _ = _r11_open_child(
        root_path, directory=True, depth=None, token=None,
        parent_identity=None, root=True,
    )
    retained.append((root_handle, root_identity, root_attributes, None, None))
    parent_path = root_path
    parent_identity = root_identity
    parent_token = retained_directory_token
    try:
        for depth, component in enumerate(components):
            requested_token = retained_directory_token
            records = _r11_find_snapshot(
                parent_path, root=(depth == 0), parent_token=parent_token,
                parent_identity=parent_identity,
                mode="inventory" if depth == 0 else "lookup",
                requested_token=None if depth == 0 else requested_token,
                requested_depth=None if depth == 0 else depth,
            )
            _r11_assert_directory_stable(
                retained[-1][0], parent_identity, retained[-1][2], root=(depth == 0),
                component_index=None if depth == 0 else depth - 1,
                path_token=None if depth == 0 else parent_token,
            )
            record = _r11_lookup_record(
                records, component, requested_token=requested_token, depth=depth,
                parent_identity=parent_identity, parent_token=parent_token,
            )
            if record["attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ENTRY_REPARSE", "validate_selected_entry",
                    component_index=depth, path_token=requested_token,
                    actual_attributes=record["attributes"],
                    identity_before=parent_identity,
                )
            child_path = parent_path + ("" if parent_path.endswith("\\") else "\\") + record["long_name"]
            child_handle, child_identity, child_attributes, _ = _r11_open_child(
                child_path, directory=True, depth=depth,
                token=requested_token, parent_identity=parent_identity,
            )
            try:
                for ancestor_handle, ancestor_identity, ancestor_attributes, ancestor_depth, ancestor_token in reversed(retained):
                    _r11_assert_directory_stable(
                        ancestor_handle, ancestor_identity, ancestor_attributes,
                        root=ancestor_depth is None,
                        component_index=ancestor_depth,
                        path_token=ancestor_token,
                    )
            except BaseException as primary:
                try:
                    _r11_close_traversal_handle(
                        child_handle, code="TRAVERSAL_HANDLE_CLOSE",
                        operation="close_child", component_index=depth,
                        path_token=requested_token, identity_before=child_identity,
                    )
                except BaseException:
                    pass
                raise primary
            retained.append((child_handle, child_identity, child_attributes, depth, requested_token))
            parent_path = child_path
            parent_identity = child_identity
            parent_token = requested_token
        return parent_path, parent_token, retained
    except BaseException:
        for handle, identity, _attributes, depth, token in reversed(retained):
            try:
                _r11_close_traversal_handle(
                    handle,
                    code="TRAVERSAL_ROOT_HANDLE_CLOSE" if depth is None else "TRAVERSAL_HANDLE_CLOSE",
                    operation="close_root" if depth is None else "close_child",
                    component_index=depth, path_token=token,
                    identity_before=identity,
                )
            except BaseException:
                pass
        raise


def _r11_close_directory_chain(
    retained: Sequence[tuple[int, dict[str, str], int, int | None, str | None]],
) -> None:
    first: BaseException | None = None
    for handle, identity, _attributes, depth, token in reversed(retained):
        try:
            _r11_close_traversal_handle(
                handle,
                code="TRAVERSAL_ROOT_HANDLE_CLOSE" if depth is None else "TRAVERSAL_HANDLE_CLOSE",
                operation="close_root" if depth is None else "close_child",
                component_index=depth, path_token=token,
                identity_before=identity,
            )
        except BaseException as exc:
            if first is None:
                first = exc
    if first is not None:
        raise first


def r11_native_inventory(
    path: Path | str,
    retained_directory_token: str,
) -> list[dict[str, Any]]:
    records, _ = _r11_retained_tree_snapshot(
        path, retained_directory_token, read_files=False,
    )
    return records


_ACTIVE_EVIDENCE_LOCKS: list["WindowsDirectoryLock"] = []


class WindowsDirectoryLock:
    """One same-session mutex plus the complete retained cumulative handle chain."""

    def __init__(
        self,
        path: Path,
        retained: list[tuple[int, dict[str, str], int, int | None, str | None]],
        mutex_handle: int,
        name: str,
    ) -> None:
        self.path = path
        self.retained = retained
        self.directory_handle = retained[-1][0]
        self.identity = dict(retained[-1][1])
        self.mutex_handle = mutex_handle
        self.name = name
        self.owned = True
        self.executable_leases: R11ExecutableLeaseSet | None = None

    @classmethod
    def acquire(cls, path: Path, *, recovery: bool = False) -> "WindowsDirectoryLock":
        resolved = validate_absolute_ordinary_path(path, "evidence directory", directory=True)
        _, _, retained = _r11_open_directory_chain(resolved, "evidence")
        mutex_handle = 0
        owned = False
        try:
            identity = retained[-1][1]
            name = (
                "Local\\6529Stream.ReleaseBuilder."
                f"{identity['volume_serial']}-{identity['file_index']}"
            )
            if any(lock.owned and lock.name == name for lock in _ACTIVE_EVIDENCE_LOCKS):
                raise EvidenceFailure("EVIDENCE_LOCKED", "evidence directory already has this-process owner")
            ctypes.set_last_error(0)
            mutex_handle = int(_kernel32().CreateMutexW(None, False, name))
            if not mutex_handle:
                error = int(ctypes.get_last_error())
                raise EvidenceFailure("CREATE_EVIDENCE_MUTEX", "mutex creation failed", operands={"winerror": error})
            ctypes.set_last_error(0)
            wait_result = int(_kernel32().WaitForSingleObject(mutex_handle, 0))
            if wait_result == _WAIT_TIMEOUT:
                raise EvidenceFailure("EVIDENCE_LOCKED", "evidence directory already has an owner")
            if wait_result == _WAIT_ABANDONED and not recovery:
                owned = True
                raise EvidenceFailure("LOCK_ABANDONED", "build rejects an abandoned owner")
            if wait_result not in (_WAIT_OBJECT_0, _WAIT_ABANDONED):
                raise EvidenceFailure("LOCK_WAIT_FAILED", "unexpected mutex wait result", operands={"wait_result": wait_result})
            owned = True
            actual, attributes, _ = _r11_query_handle(retained[-1][0])
            if actual != identity or attributes != retained[-1][2]:
                raise EvidenceFailure("EVIDENCE_DIRECTORY_IDENTITY_CHANGED", "held evidence identity changed")
            lock = cls(resolved, retained, mutex_handle, name)
            _ACTIVE_EVIDENCE_LOCKS.append(lock)
            return lock
        except BaseException:
            if owned and mutex_handle:
                _kernel32().ReleaseMutex(mutex_handle)
            if mutex_handle:
                _kernel32().CloseHandle(mutex_handle)
            _r11_close_directory_chain(retained)
            raise

    def close(self) -> None:
        if not self.owned:
            return
        self.owned = False
        failures: list[BaseException] = []
        if self.executable_leases is not None:
            try:
                self.executable_leases.close()
            except BaseException as exc:
                failures.append(exc)
        ctypes.set_last_error(0)
        if not _kernel32().ReleaseMutex(self.mutex_handle):
            failures.append(EvidenceFailure("RELEASE_EVIDENCE_MUTEX", "mutex release failed", operands={"winerror": int(ctypes.get_last_error())}))
        ctypes.set_last_error(0)
        if not _kernel32().CloseHandle(self.mutex_handle):
            failures.append(EvidenceFailure("CLOSE_EVIDENCE_MUTEX", "mutex close failed", operands={"winerror": int(ctypes.get_last_error())}))
        try:
            _r11_close_directory_chain(self.retained)
        except BaseException as exc:
            failures.append(exc)
        if self in _ACTIVE_EVIDENCE_LOCKS:
            _ACTIVE_EVIDENCE_LOCKS.remove(self)
        if failures:
            raise failures[0]

    def __enter__(self) -> "WindowsDirectoryLock":
        return self

    def __exit__(self, *_exc: Any) -> None:
        self.close()


def _close_active_evidence_locks() -> None:
    for lock in tuple(reversed(_ACTIVE_EVIDENCE_LOCKS)):
        try:
            lock.close()
        except BaseException:
            pass


atexit.register(_close_active_evidence_locks)


def _r11_lexical_within(path: Path | str, parent: Path | str) -> bool:
    path_text = str(path).rstrip("\\").casefold()
    parent_text = str(parent).rstrip("\\").casefold()
    return path_text == parent_text or path_text.startswith(parent_text + "\\")


def _r11_read_path(path: Path | str, selected_file_token: str) -> bytes:
    raw, _, _ = r11_native_read(path, selected_file_token)
    return raw


def _r11_output_must_be_absent(output_dir: Path) -> None:
    text = str(output_dir)
    parent = Path(text.rsplit("\\", 1)[0])
    leaf = text.rsplit("\\", 1)[1]
    _r11_validate_component(leaf)
    inventory = r11_native_inventory(parent, "output-parent")
    matching = [
        entry for entry in inventory if entry["name"].casefold() == leaf.casefold()
    ]
    if matching:
        raise EvidenceFailure(
            "OUTPUT_ALREADY_EXISTS",
            "authoritative output must be absent before STARTED",
            operands={
                "candidate_count": len(matching),
                "candidate_set_sha256": sha256_bytes(
                    canonical_evidence_bytes(sorted(entry["name"] for entry in matching))
                ),
            },
        )


@dataclass(frozen=True)
class R11BoundaryOwner:
    """Immutable call-site authority for one traversal semantic lifecycle."""

    boundary: str
    state_items: tuple[tuple[str, Any], ...]
    selected_file_token: str | None
    read_ordinal: int | None
    supplies_read_state: bool = False
    lifecycle_token: str | None = None

    def __post_init__(self) -> None:
        if self.boundary not in R11_BOUNDARY_IDS:
            raise ValueError("unknown boundary owner")
        state = dict(self.state_items)
        if len(state) != len(self.state_items):
            raise ValueError("boundary owner state keys are not unique")
        if self.selected_file_token is not None:
            _r11_validate_filetoken(self.selected_file_token)
        if self.lifecycle_token is not None:
            _r11_validate_filetoken(self.lifecycle_token)
        if self.boundary in (
            "INSTALLED_INVENTORY", "RECOVERY_INVENTORY",
        ) and self.lifecycle_token is None:
            raise ValueError("inventory boundary owner has no frozen lifecycle token")
        state_selected = state.get(
            "selected_file_token", state.get("selected_artifact_token")
        )
        if state_selected != self.selected_file_token and (
            "selected_file_token" in state or "selected_artifact_token" in state
        ):
            raise ValueError("boundary owner selected token is not exact")
        if self.read_ordinal is not None and not _r11_u53(self.read_ordinal):
            raise ValueError("boundary owner read ordinal is not U53")
        if self.boundary == "INSTALLED_READ":
            if self.read_ordinal is None:
                raise ValueError("installed read owner has no read ordinal")
            expected_prefix = "CLEAN" if self.read_ordinal == 0 else "READ_PARTIAL"
            if state.get("prefix") != expected_prefix:
                raise ValueError("installed read prefix does not match its ordinal")
        elif self.read_ordinal is not None and (
            not self.boundary.endswith("_READ") or self.read_ordinal != 0
        ):
            raise ValueError("non-installed read owner ordinal is not exact zero")
        if self.supplies_read_state:
            if (
                self.boundary != "ARTIFACT_READ"
                or self.read_ordinal != 0
                or "read_state" in state
            ):
                raise ValueError("dynamic READ_STATE owner is not exact")
            state["read_state"] = None
        _r11_validate_boundary_state(self.boundary, state)

    def translate(
        self,
        diagnostic: "R11TraversalDiagnostic",
        read_state: dict[str, Any] | None,
    ) -> BaseException | dict[str, Any]:
        r11_validate_diagnostic(diagnostic)
        diagnostic_token = diagnostic.operands["path_token"]
        frozen_token = self.lifecycle_token
        if self.boundary == "INSTALLED_READ":
            if diagnostic_token != self.selected_file_token:
                raise ValueError(
                    "installed-read diagnostic token differs from frozen selection"
                )
        elif diagnostic_token is not None:
            selected_match = diagnostic_token == self.selected_file_token
            lifecycle_match = (
                self.lifecycle_token is not None
                and (
                    diagnostic_token == self.lifecycle_token
                    or diagnostic_token.startswith(self.lifecycle_token + "/")
                )
            )
            if not selected_match and not lifecycle_match:
                raise ValueError(
                    "diagnostic token differs from frozen boundary lifecycle"
                )
        proof = diagnostic.record_proof
        if proof is not None:
            proof_owner_match = (
                frozen_token is not None
                and (
                    proof.parent_token == frozen_token
                    or not proof.root
                    and proof.parent_token.startswith(frozen_token + "/")
                )
            )
            if not proof_owner_match:
                raise ValueError(
                    "record proof token differs from frozen lifecycle owner"
                )
        state = dict(self.state_items)
        if self.supplies_read_state:
            state["read_state"] = read_state
        translated = r11_translate_diagnostic(diagnostic, self.boundary, state)
        if self.boundary == "RECOVERY_INVENTORY" and isinstance(translated, dict):
            return translated
        if not isinstance(translated, BaseException):
            raise diagnostic
        return translated


def _prepare_evidence_run_r11(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: Path,
    solc_bin: Path,
    evidence_dir: Path,
) -> tuple[
    WindowsDirectoryLock,
    Path,
    Path,
    dict[str, Any],
    str,
    dict[str, Any],
]:
    validate_r4_authority_constants()
    repo = validate_absolute_ordinary_path(repo_root, "repository root", directory=True)
    evidence = validate_absolute_ordinary_path(evidence_dir, "evidence directory", directory=True)
    output = validate_absolute_ordinary_path(output_dir, "output directory", directory=False)
    if _r11_lexical_within(evidence, repo):
        raise EvidenceFailure("EVIDENCE_INSIDE_ROOT", "evidence directory must be outside repository")
    for variable in ("TEMP", "TMP"):
        value = os.environ.get(variable)
        if value:
            try:
                _r11_absolute_parts(value)
            except EvidenceFailure:
                continue
            if _r11_lexical_within(evidence, value) or _r11_lexical_within(value, evidence):
                raise EvidenceFailure("EVIDENCE_TEMP_ALIAS", "evidence directory aliases a temp root")
    if r11_native_inventory(evidence, "evidence"):
        raise EvidenceFailure("EVIDENCE_NOT_EMPTY", "evidence directory must initially be empty")
    _r11_output_must_be_absent(output)
    forge = validate_absolute_ordinary_path(forge_bin, "Forge executable", directory=False)
    solc = validate_absolute_ordinary_path(solc_bin, "Solc executable", directory=False)
    config_raw = _r11_read_path(config_path, "target-config")
    foundry_raw = _r11_read_path(foundry_config_path, "foundry-config")
    if hashlib.sha256(config_raw).hexdigest().upper() != R4_TARGET_CONFIG_SHA256:
        raise EvidenceFailure("TARGET_CONFIG_AUTHORITY", "target config is not exact 84B3")
    if hashlib.sha256(foundry_raw).hexdigest().upper() != R4_FOUNDRY_CONFIG_SHA256:
        raise EvidenceFailure("FOUNDRY_CONFIG_AUTHORITY", "Foundry config is not exact C356")
    source_paths = sorted(
        {path for group in R4_GROUPS for path in group["sources"]},
        key=str.casefold,
    )
    source_records = []
    for relative in source_paths:
        source_path = Path(str(repo).rstrip("\\") + "\\" + relative.replace("/", "\\"))
        raw = _r11_read_path(source_path, relative)
        source_records.append(
            {"path": relative, "sha256": sha256_bytes(raw), "byte_count": len(raw)}
        )
    aggregate = _source_closure_aggregate(source_records)
    if len(source_records) != 31 or aggregate != R4_SOURCE_AGGREGATE_SHA256:
        raise EvidenceFailure(
            "SOURCE_AUTHORITY", "compiler root is not exact 31-file 1EB0 authority",
            operands={"count": len(source_records), "aggregate_sha256": aggregate},
        )
    builder_path = Path(os.path.abspath(__file__))
    test_path = builder_path.with_name("test_release_build_artifacts.py")
    static_receipts: dict[str, Any] = {
        "builder": _receipt_with_kind(windows_file_receipt(builder_path, "builder"), "file"),
        "test": _receipt_with_kind(windows_file_receipt(test_path, "builder test"), "file"),
        "config": _receipt_with_kind(windows_file_receipt(config_path, "target config"), "file"),
        "foundry_config": _receipt_with_kind(windows_file_receipt(foundry_config_path, "Foundry config"), "file"),
        "forge": _receipt_with_kind(windows_file_receipt(forge, "Forge executable"), "file"),
        "solc": _receipt_with_kind(windows_file_receipt(solc, "Solc executable"), "file"),
        "repo_root": _receipt_with_kind(windows_file_receipt(repo, "repo root", directory=True), "directory"),
        "evidence_dir": _receipt_with_kind(windows_file_receipt(evidence, "evidence directory", directory=True), "directory"),
        "output_dir": {
            "path": str(output),
            "identity": None,
            "byte_count": None,
            "sha256": None,
            "path_token": _r11_validate_filetoken("output-dir"),
            "kind": "directory",
            "initial_status": "absent",
        },
        "source_aggregate": {
            **_receipt_with_kind(
                windows_file_receipt(repo / "smart-contracts", "source root", directory=True),
                "directory",
            ),
            "byte_count": sum(record["byte_count"] for record in source_records),
            "sha256": "sha256:" + R4_SOURCE_AGGREGATE_SHA256.lower(),
            "source_count": 31,
        },
    }
    for token, raw in (("config", config_raw), ("foundry_config", foundry_raw)):
        if (
            static_receipts[token]["byte_count"] != len(raw)
            or static_receipts[token]["sha256"] != sha256_bytes(raw)
        ):
            raise EvidenceFailure(
                "STATIC_INPUT_IDENTITY_CHANGED",
                f"{token} changed between authority validation and receipt capture",
            )
    for record in source_records:
        source_path = Path(str(repo).rstrip("\\") + "\\" + record["path"].replace("/", "\\"))
        receipt = _receipt_with_kind(
            windows_file_receipt(source_path, record["path"]), "file",
        )
        if (
            receipt["byte_count"] != record["byte_count"]
            or receipt["sha256"] != record["sha256"]
        ):
            raise EvidenceFailure(
                "SOURCE_AUTHORITY_CHANGED",
                "source changed between aggregate validation and receipt capture",
            )
        static_receipts[f"source:{record['path']}"] = receipt
    executable_leases = R11ExecutableLeaseSet.acquire(
        forge, solc, static_receipts,
    )
    try:
        lock = WindowsDirectoryLock.acquire(evidence)
    except BaseException as primary:
        try:
            executable_leases.close()
        except BaseException as cleanup:
            raise cleanup from primary
        raise primary
    lock.executable_leases = executable_leases
    try:
        static_identity = static_receipts["evidence_dir"]["identity"]
        held_identity = lock.identity
        current_identity = windows_file_receipt(
            evidence, "evidence directory", directory=True,
        )["identity"]
        if static_identity != held_identity or held_identity != current_identity:
            raise EvidenceFailure(
                "EVIDENCE_DIRECTORY_IDENTITY_CHANGED",
                "static, held and current evidence identities differ",
            )
        if r11_native_inventory(evidence, "evidence"):
            raise EvidenceFailure(
                "EVIDENCE_CHANGED_BEFORE_STARTED",
                "evidence directory changed before STARTED",
            )
        pre_started_checkpoint = _r11_checkpoint(
            "pre-started", forge, solc, static_receipts,
        )
        invocation_domain = {
            "builder": static_receipts["builder"],
            "test": static_receipts["test"],
            "source_aggregate_sha256": R4_SOURCE_AGGREGATE_SHA256,
            "foundry_config_sha256": R4_FOUNDRY_CONFIG_SHA256,
            "target_config_sha256": R4_TARGET_CONFIG_SHA256,
            "group_map_sha256": R4_GROUP_MAP_SHA256,
            "constructor_map_sha256": R4_CONSTRUCTOR_MAP_SHA256,
            "forge": static_receipts["forge"],
            "solc": static_receipts["solc"],
            "repo_root": static_receipts["repo_root"],
            "output_dir": static_receipts["output_dir"],
            "evidence_dir": static_receipts["evidence_dir"],
            "held_evidence_directory_identity": held_identity,
            "pre_started_checkpoint": pre_started_checkpoint,
        }
        invocation_id = sha256_bytes(canonical_evidence_bytes(invocation_domain))
        return (
            lock, forge, solc, static_receipts, invocation_id,
            pre_started_checkpoint,
        )
    except BaseException:
        lock.close()
        raise


def _r11_load_build_info_input(
    build_info_dir: Path,
    group_index: int,
) -> dict[str, Any]:
    retained: R11RetainedTree | None = None
    selected_path: Path | None = None
    selected_token: str | None = None
    raw: bytes | None = None
    read_complete = False
    read_boundary_owner: R11BoundaryOwner | None = None
    lookup_boundary_owner = R11BoundaryOwner(
        "PORTABLE_BUILD_INFO_LOOKUP",
        (
            ("group_index", group_index),
            ("count_complete", False),
            ("actual_count", None),
        ),
        None,
        None,
        lifecycle_token=f"build-info/{group_index:03d}",
    )
    try:
        with R11RetainedTree(
            build_info_dir, f"build-info/{group_index:03d}",
        ) as retained:
            topology = retained.topology()
            json_entries = [
                name for name, kind in topology
                if kind == "file" and name.endswith(".json")
            ]
            if len(topology) != 1 or len(json_entries) != 1:
                raise _r11_first_red(
                    "PORTABLE_INPUT_BUILD_INFO_COUNT", "portable_input",
                    {"expected_count": 1, "actual_count": len(topology)},
                    call_ordinal=group_index + 1, group_index=group_index,
                )
            selected_name = json_entries[0]
            selected_token = retained.files[selected_name]["path_token"]
            selected_path = build_info_dir / Path(selected_name)
            retained.select_read_order([selected_name])
            read_boundary_owner = R11BoundaryOwner(
                "PORTABLE_BUILD_INFO_READ",
                (
                    ("group_index", group_index),
                    ("selected_file_token", selected_token),
                ),
                selected_token,
                0,
                lifecycle_token=selected_token,
            )
            raw = retained.read_file(
                selected_name,
                on_read_failure=read_boundary_owner.translate,
            )
            read_complete = True
    except R11TraversalDiagnostic as diagnostic:
        if read_complete:
            if read_boundary_owner is None:
                raise
            raise read_boundary_owner.translate(diagnostic, None)
        translated = lookup_boundary_owner.translate(diagnostic, None)
        if not isinstance(translated, BaseException):
            raise AssertionError("build-info lookup owner returned a non-exception")
        raise translated
    if raw is None or selected_path is None or selected_token is None:
        raise AssertionError("retained build-info read did not complete")
    try:
        build_info_value = load_json_bytes(raw, selected_path)
    except ReleaseBuildError as exc:
        cause = exc.__cause__
        reason = (
            "duplicate_key"
            if str(exc).startswith("duplicate JSON member:")
            else "syntax"
            if isinstance(cause, json.JSONDecodeError)
            else "non_ijson"
        )
        raise _r11_first_red(
            "PORTABLE_INPUT_BUILD_INFO_JSON", "portable_input",
            {
                "path_token": selected_token,
                "byte_count": len(raw),
                "sha256": sha256_bytes(raw),
                "reason": reason,
            },
            call_ordinal=group_index + 1, group_index=group_index,
        ) from exc
    if (
        not isinstance(build_info_value, dict)
        or not isinstance(build_info_value.get("input"), dict)
    ):
        raise _r11_first_red(
            "PORTABLE_INPUT_BUILD_INFO_JSON", "portable_input",
            {
                "path_token": selected_token,
                "byte_count": len(raw),
                "sha256": sha256_bytes(raw),
                "reason": "non_object",
            },
            call_ordinal=group_index + 1, group_index=group_index,
        )
    return build_info_value["input"]


def _r11_metadata_failure(
    authority: dict[str, Any],
    item: int,
    code: str,
    reason: str,
) -> R11BuilderFailure:
    return _r11_first_red(
        code, "metadata_admission", {"item": item, "reason": reason},
        call_ordinal=R11_GROUP_INDEX_BY_SOURCE[authority["source"]] + 1,
        authority=authority,
    )


def _r11_metadata_and_bindings(
    repo_root: Path,
    artifact: dict[str, Any],
    artifact_sha256: str,
    authority: dict[str, Any],
    target: dict[str, str],
    foundry_config_path: Path,
    compiler_input: dict[str, Any],
    solc_bin: Path,
) -> dict[str, Any]:
    if not isinstance(artifact, dict):
        raise _r11_metadata_failure(
            authority, 2, "METADATA_ARTIFACT_OBJECT_AND_HASH", "artifact_not_object",
        )
    if not artifact_sha256.startswith("sha256:"):
        raise _r11_metadata_failure(
            authority, 2, "METADATA_ARTIFACT_OBJECT_AND_HASH", "artifact_hash_mismatch",
        )
    metadata_value = artifact.get("metadata")
    if metadata_value is None:
        raise _r11_metadata_failure(authority, 3, "METADATA_OBJECT", "metadata_missing")
    if isinstance(metadata_value, str):
        try:
            metadata_value = load_json_text(metadata_value, f"{authority['target']}.metadata")
        except ReleaseBuildError as exc:
            raise _r11_metadata_failure(
                authority, 3, "METADATA_OBJECT", "metadata_json_invalid",
            ) from exc
    if not isinstance(metadata_value, dict):
        raise _r11_metadata_failure(authority, 3, "METADATA_OBJECT", "metadata_not_object")
    metadata = metadata_value
    compiler = metadata.get("compiler")
    if compiler is None:
        raise _r11_metadata_failure(authority, 4, "METADATA_COMPILER_VERSION", "compiler_missing")
    if not isinstance(compiler, dict):
        raise _r11_metadata_failure(authority, 4, "METADATA_COMPILER_VERSION", "compiler_not_object")
    if "version" not in compiler:
        raise _r11_metadata_failure(authority, 4, "METADATA_COMPILER_VERSION", "version_missing")
    if not isinstance(compiler["version"], str):
        raise _r11_metadata_failure(authority, 4, "METADATA_COMPILER_VERSION", "version_not_string")
    if compiler["version"] != SOLC_LONG_VERSION:
        raise _r11_metadata_failure(authority, 4, "METADATA_COMPILER_VERSION", "version_mismatch")
    settings = metadata.get("settings")
    if settings is None:
        raise _r11_metadata_failure(authority, 5, "METADATA_COMPILATION_TARGET", "settings_missing")
    if not isinstance(settings, dict):
        raise _r11_metadata_failure(authority, 5, "METADATA_COMPILATION_TARGET", "settings_not_object")
    compilation_target = settings.get("compilationTarget")
    if compilation_target is None:
        raise _r11_metadata_failure(authority, 5, "METADATA_COMPILATION_TARGET", "compilation_target_missing")
    if not isinstance(compilation_target, dict):
        raise _r11_metadata_failure(authority, 5, "METADATA_COMPILATION_TARGET", "compilation_target_not_object")
    if compilation_target != {target["source"]: target["name"]}:
        raise _r11_metadata_failure(authority, 5, "METADATA_COMPILATION_TARGET", "compilation_target_mismatch")
    if settings.get("viaIR") is not True:
        raise _r11_metadata_failure(authority, 6, "METADATA_VIA_IR", "via_ir_not_true")
    if settings.get("evmVersion") != EVM_VERSION:
        raise _r11_metadata_failure(authority, 7, "METADATA_EVM_PARIS", "evm_version_not_paris")
    optimizer = settings.get("optimizer")
    if optimizer is None:
        raise _r11_metadata_failure(authority, 8, "METADATA_OPTIMIZER_200", "optimizer_missing")
    if not isinstance(optimizer, dict):
        raise _r11_metadata_failure(authority, 8, "METADATA_OPTIMIZER_200", "optimizer_not_object")
    if optimizer.get("enabled") is not True:
        raise _r11_metadata_failure(authority, 8, "METADATA_OPTIMIZER_200", "enabled_not_true")
    if optimizer.get("runs") != OPTIMIZER_RUNS:
        raise _r11_metadata_failure(authority, 8, "METADATA_OPTIMIZER_200", "runs_not_200")
    metadata_settings = settings.get("metadata")
    if metadata_settings is None:
        raise _r11_metadata_failure(authority, 9, "METADATA_NO_HASH_NO_CBOR", "metadata_settings_missing")
    if not isinstance(metadata_settings, dict):
        raise _r11_metadata_failure(authority, 9, "METADATA_NO_HASH_NO_CBOR", "metadata_settings_not_object")
    if metadata_settings.get("bytecodeHash") != "none":
        raise _r11_metadata_failure(authority, 9, "METADATA_NO_HASH_NO_CBOR", "bytecode_hash_not_none")
    if metadata_settings.get("appendCBOR") is not False:
        raise _r11_metadata_failure(authority, 9, "METADATA_NO_HASH_NO_CBOR", "append_cbor_not_false")
    compiler_sources_value = compiler_input.get("sources")
    if not isinstance(compiler_sources_value, dict) or not compiler_sources_value:
        raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "sources_missing")
    compiler_sources = []
    for source in sorted(compiler_sources_value):
        value = compiler_sources_value[source]
        if not isinstance(value, dict) or not isinstance(value.get("content"), str):
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "source_entry_not_object")
        raw = value["content"].encode("utf-8", errors="strict")
        compiler_sources.append(
            {"path": source, "sha256": sha256_bytes(raw), "keccak256": keccak256_hex(raw)}
        )
    metadata_sources_value = metadata.get("sources")
    if metadata_sources_value is None:
        raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "sources_missing")
    if not isinstance(metadata_sources_value, dict):
        raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "sources_not_object")
    if not metadata_sources_value:
        raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "sources_empty")
    metadata_sources = []
    compiler_by_path = {record["path"]: record for record in compiler_sources}
    for source in sorted(metadata_sources_value):
        value = metadata_sources_value[source]
        if not isinstance(value, dict):
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "source_entry_not_object")
        if "keccak256" not in value:
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "keccak_missing")
        if not isinstance(value["keccak256"], str):
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "keccak_not_string")
        expected = compiler_by_path.get(source)
        if expected is None:
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "source_missing")
        if value["keccak256"].casefold() != expected["keccak256"].casefold():
            raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "source_keccak_mismatch")
        metadata_sources.append(dict(expected))
    if target["source"] not in metadata_sources_value:
        raise _r11_metadata_failure(authority, 10, "METADATA_SOURCE_BINDING", "configured_source_absent")
    if [record["path"] for record in metadata_sources] != [record["path"] for record in compiler_sources]:
        raise _r11_metadata_failure(authority, 11, "METADATA_BUILD_BINDING", "source_set_mismatch")
    input_settings = compiler_input.get("settings")
    if not isinstance(input_settings, dict):
        raise _r11_metadata_failure(authority, 11, "METADATA_BUILD_BINDING", "compiler_input_binding_mismatch")
    if (
        input_settings.get("viaIR") is not True
        or input_settings.get("evmVersion") != EVM_VERSION
        or not isinstance(input_settings.get("optimizer"), dict)
        or input_settings["optimizer"].get("enabled") is not True
        or input_settings["optimizer"].get("runs") != OPTIMIZER_RUNS
        or not isinstance(input_settings.get("metadata"), dict)
        or input_settings["metadata"].get("bytecodeHash") != "none"
        or input_settings["metadata"].get("appendCBOR") is not False
    ):
        raise _r11_metadata_failure(authority, 11, "METADATA_BUILD_BINDING", "compiler_input_binding_mismatch")
    ordered_input = ordered_json_bytes(compiler_input)
    normalized_argv = normalized_forge_argv(
        target["source"], normalize_path(foundry_config_path, repo_root),
        solc_bin=solc_bin,
    )
    source_universe = {record["path"]: record["sha256"] for record in metadata_sources}
    compiler_bindings = {
        "compiler_input_sources": compiler_sources,
        "compiler_input_source_order": [record["path"] for record in compiler_sources],
        "compiler_input_settings_sha256": canonical_json_sha256(input_settings),
        "compiler_input_ordered_sha256": sha256_bytes(ordered_input),
        "compiler_input_canonical_sha256": canonical_json_sha256(compiler_input),
    }
    return {
        "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
        "forge_argv": normalized_argv,
        "metadata_sources": metadata_sources,
        "canonical_source_universe_sha256": canonical_json_sha256(source_universe),
        "compiler_settings_sha256": canonical_json_sha256(settings),
        **compiler_bindings,
        "canonical_build_input_sha256": canonical_json_sha256(
            {
                "compiler_version": compiler["version"],
                "compiler_input_canonical_sha256": compiler_bindings["compiler_input_canonical_sha256"],
                "compiler_input_ordered_sha256": compiler_bindings["compiler_input_ordered_sha256"],
                "forge_argv": normalized_argv,
                "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
                "language": metadata.get("language", "Solidity"),
                "settings": settings,
                "source_universe": source_universe,
                "target": target,
            }
        ),
    }


def _r11_snapshot_tree(
    root: Path,
    retained_directory_token: str,
) -> tuple[list[dict[str, Any]], dict[str, bytes]]:
    contents: dict[str, bytes] = {}
    files: list[dict[str, Any]] = []
    with R11RetainedTree(root, retained_directory_token) as retained:
        for relative in sorted(retained.files):
            raw = retained.read_file(relative)
            contents[relative] = raw
            files.append(
                {
                    "path": relative,
                    "byte_count": len(raw),
                    "sha256": sha256_bytes(raw),
                }
            )
    return files, contents


def _r11_expected_topology(file_names: Sequence[str]) -> list[tuple[str, str]]:
    directories: set[str] = set()
    for name in file_names:
        _r11_validate_filetoken(name)
        parts = name.split("/")
        for limit in range(1, len(parts)):
            directories.add("/".join(parts[:limit]))
    return sorted(
        [(name, "directory") for name in directories]
        + [(name, "file") for name in file_names]
    )


def _r11_read_retained_output(
    retained: "R11RetainedTree",
    expected_receipts: Sequence[dict[str, Any]],
    *,
    read_boundary: str | None = None,
) -> tuple[list[dict[str, Any]], dict[str, bytes]]:
    expected = list(expected_receipts)
    expected_names = [receipt["path"] for receipt in expected]
    if expected_names != sorted(expected_names):
        raise EvidenceFailure("OUTPUT_FILE_SCHEMA", "expected output receipts are not sorted")
    expected_topology = _r11_expected_topology(expected_names)
    actual_topology = retained.topology()
    if actual_topology != expected_topology:
        actual_names = sorted(retained.files)
        raise EvidenceFailure(
            "OUTPUT_TOPOLOGY_MISMATCH",
            "installed output topology differs",
            operands={
                "expected_count": len(expected_names),
                "actual_count": len(actual_names),
                "expected_names_sha256": sha256_bytes(canonical_evidence_bytes(expected_names)),
                "actual_names_sha256": sha256_bytes(canonical_evidence_bytes(actual_names)),
            },
        )
    actual_receipts: list[dict[str, Any]] = []
    contents: dict[str, bytes] = {}
    for read_index, expected_receipt in enumerate(expected):
        name = expected_receipt["path"]
        selected_file_token = _r11_validate_filetoken(
            retained.root_token + "/" + name,
        )
        prefix = "CLEAN" if read_index == 0 else "READ_PARTIAL"
        on_read_failure = None
        if read_boundary is not None:
            boundary_owner = R11BoundaryOwner(
                read_boundary,
                (
                    ("prefix", prefix),
                    ("selected_file_token", selected_file_token),
                ),
                selected_file_token,
                read_index,
                lifecycle_token=selected_file_token,
            )
            on_read_failure = boundary_owner.translate
        raw = retained.read_file(name, on_read_failure=on_read_failure)
        actual_receipt = {
            "path": name,
            "byte_count": len(raw),
            "sha256": sha256_bytes(raw),
        }
        if actual_receipt != expected_receipt:
            raise EvidenceFailure(
                "OUTPUT_BYTES_MISMATCH",
                "installed output byte receipt differs",
                operands={
                    "path_token": selected_file_token,
                    "expected_byte_count": expected_receipt["byte_count"],
                    "actual_byte_count": actual_receipt["byte_count"],
                    "expected_sha256": expected_receipt["sha256"],
                    "actual_sha256": actual_receipt["sha256"],
                },
            )
        actual_receipts.append(actual_receipt)
        contents[name] = raw
    return actual_receipts, contents


def _r11_installed_close_failure(
    diagnostic: "R11TraversalDiagnostic",
    *,
    read_set_complete: bool,
    inventory_owner: R11BoundaryOwner,
) -> BaseException:
    if type(read_set_complete) is not bool:
        raise TypeError("installed close state must be exact bool")
    if read_set_complete:
        return diagnostic
    return inventory_owner.translate(diagnostic, None)


def _r11_install_output_no_replace(
    staged: Path,
    output_dir: Path,
    results: dict[str, Any],
) -> None:
    windows_file_receipt(staged, "staged output", directory=True)
    _r11_output_must_be_absent(output_dir)
    staged_drive = str(staged)[:2].casefold()
    output_drive = str(output_dir)[:2].casefold()
    if staged_drive != output_drive:
        raise EvidenceFailure("OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION", "install crosses volumes")
    ctypes.set_last_error(0)
    if not _kernel32().MoveFileExW(
        str(staged), str(output_dir), _MOVEFILE_WRITE_THROUGH,
    ):
        error = int(ctypes.get_last_error())
        raise EvidenceFailure(
            "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION", "output install failed",
            operands={"winerror": error},
        )
    results["output_installed"] = True
    results["output_quarantine_without_matching_go"] = True


def _r11_cleanup_build_temp(temp_root: Path, results: dict[str, Any]) -> None:
    shutil.rmtree(temp_root)
    results["temporary_root"] = None


def _r11_pretty_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def _build_release_output_evidence_r11(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: Path,
    solc_bin: Path,
    evidence_dir: Path,
) -> dict[str, Any]:
    (
        _lock,
        forge,
        solc,
        static_receipts,
        invocation_id,
        pre_started_checkpoint,
    ) = _prepare_evidence_run_r11(
        repo_root, config_path, foundry_config_path, output_dir,
        forge_bin, solc_bin, evidence_dir,
    )
    execution_authority = R11ExecutionAuthority(_lock)
    try:
        journal = ExecutionJournal(
            Path(static_receipts["evidence_dir"]["path"]),
            invocation_id,
            static_receipts,
            forge,
            solc,
            held_evidence_directory_identity=_lock.identity,
            pre_started_checkpoint=pre_started_checkpoint,
            execution_authority=execution_authority,
        )
        journal.publish_started()
        results = r11_initial_results()
    except BaseException as primary:
        execution_authority.close(primary)
        raise
    temp_root: Path | None = None
    try:
        version_result = journal.invoke(
            0, [str(forge), "--version"], repo_root,
            phase="forge_version", group_string=None,
        )
        try:
            forge_version = r11_validate_forge_version_bytes(version_result.stdout)
        except EvidenceFailure as exc:
            raise _r11_first_red(
                exc.code, "forge_version", exc.operands, call_ordinal=0,
            ) from exc

        temp_root = Path(tempfile.mkdtemp(prefix=".release-build-", dir=repo_root))
        results["temporary_root"] = str(temp_root)
        staged = temp_root / "aggregate"
        staged.mkdir()
        expected_output: dict[str, bytes] = {}
        records: list[dict[str, Any]] = []
        admitted_artifacts: dict[str, dict[str, Any]] = {}
        config_sha256 = static_receipts["config"]["sha256"]
        foundry_config_sha256 = static_receipts["foundry_config"]["sha256"]
        targets = [
            {
                "kind": "production_contract",
                "name": authority["target"],
                "source": authority["source"],
            }
            for authority in R4_TARGET_AUTHORITIES
        ]
        targets_by_source: dict[str, list[dict[str, str]]] = {}
        for target in targets:
            targets_by_source.setdefault(target["source"], []).append(target)
        source_groups = [
            (group["source"], targets_by_source[group["source"]])
            for group in R4_GROUPS
        ]
        evaluation_by_target = {
            evaluation["target"]: evaluation
            for evaluation in results["target_evaluations"]
        }

        for group_index, (source, source_targets) in enumerate(source_groups):
            target_root = temp_root / "targets" / f"{group_index:03d}-{Path(source).stem}"
            target_out = target_root / "out"
            target_cache = target_root / "cache"
            target_build_info = target_root / "build-info"
            command = forge_command(
                str(forge), repo_root, foundry_config_path, source,
                target_out, target_cache, target_build_info, solc_bin=solc,
            )
            group = R4_GROUPS[group_index]
            journal.invoke(
                group_index + 1, command, repo_root,
                phase="forge_build", group_string=group["group_string"],
            )
            raw_compiler_input = _r11_load_build_info_input(target_build_info, group_index)
            try:
                group_receipt = validate_evidence_group_closure(
                    group_index,
                    source,
                    raw_compiler_input,
                    {
                        path: static_receipts[f"source:{path}"]
                        for path in group["sources"]
                    },
                )
            except EvidenceFailure as exc:
                raise _r11_first_red(
                    exc.code, "group_closure", exc.operands,
                    call_ordinal=group_index + 1, group_index=group_index,
                ) from exc
            try:
                compiler_input = canonicalize_build_info_compiler_paths(
                    repo_root, raw_compiler_input, source,
                )
            except ReleaseBuildError as exc:
                raise _r11_first_red(
                    "PORTABLE_INPUT_PATH_BINDING", "portable_input",
                    {
                        "field": "out",
                        "expected_sha256": sha256_bytes(canonical_evidence_bytes(PORTABLE_COMPILER_PATHS)),
                        "actual_type": "object",
                        "actual_sha256": canonical_json_sha256(raw_compiler_input),
                    },
                    call_ordinal=group_index + 1, group_index=group_index,
                ) from exc
            compiler_input_relative = Path("compiler-inputs") / f"{group_index:03d}-{Path(source).stem}.json"
            compiler_input_bytes = ordered_json_bytes(compiler_input)
            compiler_input_destination = staged / compiler_input_relative
            compiler_input_destination.parent.mkdir(parents=True, exist_ok=True)
            try:
                write_exact_bytes(
                    compiler_input_destination, compiler_input_bytes,
                    "retained compiler input",
                )
            except BaseException as exc:
                raise _r11_first_red(
                    "OP_RETAINED_INPUT_WRITE_EXCEPTION", "portable_input",
                    {
                        "path_token": compiler_input_relative.as_posix(),
                        "exception_type": type(exc).__name__,
                        "message_sha256": sha256_bytes(str(exc).encode("utf-8")),
                    },
                    call_ordinal=group_index + 1, group_index=group_index,
                ) from exc
            expected_output[compiler_input_relative.as_posix()] = compiler_input_bytes
            compiler_input_sha256 = sha256_bytes(compiler_input_bytes)

            for target in source_targets:
                authority = R11_TARGET_BY_NAME[target["name"]]
                evaluation = evaluation_by_target[target["name"]]
                evaluation["metadata_evaluated"] = True
                artifact_path = target_out / Path(target["source"]).name / f"{target['name']}.json"
                artifact_token = _r11_validate_filetoken(
                    f"artifact/{authority['semantic_id']}.json"
                )
                artifact_lookup_owner = R11BoundaryOwner(
                    "ARTIFACT_LOOKUP",
                    (
                        ("group_index", group_index),
                        ("semantic_id", authority["semantic_id"]),
                        ("target", authority["target"]),
                        ("metadata_evaluated", True),
                        ("item1_passed", False),
                    ),
                    artifact_token,
                    None,
                    lifecycle_token=artifact_token,
                )
                artifact_read_owner = R11BoundaryOwner(
                    "ARTIFACT_READ",
                    (
                        ("group_index", group_index),
                        ("semantic_id", authority["semantic_id"]),
                        ("target", authority["target"]),
                        ("item1_passed", True),
                        ("selected_artifact_token", artifact_token),
                    ),
                    artifact_token,
                    0,
                    supplies_read_state=True,
                    lifecycle_token=artifact_token,
                )
                artifact_bytes, _, _ = r11_native_read(
                    artifact_path,
                    artifact_token,
                    on_lookup_failure=artifact_lookup_owner.translate,
                    on_read_failure=artifact_read_owner.translate,
                )
                evaluation["file_read"] = True
                evaluation["artifact_byte_count"] = len(artifact_bytes)
                evaluation["artifact_sha256"] = sha256_bytes(artifact_bytes)
                try:
                    artifact_value = load_json_bytes(artifact_bytes, artifact_path)
                except ReleaseBuildError as exc:
                    cause = exc.__cause__
                    reason = (
                        "duplicate_key"
                        if str(exc).startswith("duplicate JSON member:")
                        else "syntax"
                        if isinstance(cause, json.JSONDecodeError)
                        else "non_ijson"
                    )
                    raise _r11_first_red(
                        "ARTIFACT_JSON_DECODE", "artifact_json_decode",
                        {
                            "artifact_byte_count": len(artifact_bytes),
                            "artifact_sha256": sha256_bytes(artifact_bytes),
                            "reason": reason,
                        },
                        call_ordinal=group_index + 1, authority=authority,
                    ) from exc
                evaluation["artifact_json_decoded"] = True
                artifact = artifact_value
                bindings = _r11_metadata_and_bindings(
                    repo_root, artifact, sha256_bytes(artifact_bytes), authority,
                    target, foundry_config_path, compiler_input, solc,
                )
                evaluation["metadata_admitted"] = True
                admitted_artifacts[target["name"]] = artifact
                relative_artifact = Path(Path(target["source"]).name) / f"{target['name']}.json"
                destination = staged / relative_artifact
                destination.parent.mkdir(parents=True, exist_ok=True)
                try:
                    write_exact_bytes(destination, artifact_bytes, "release artifact")
                except BaseException as exc:
                    raise _r11_metadata_failure(
                        authority, 11, "METADATA_BUILD_BINDING", "canonical_build_input_mismatch",
                    ) from exc
                expected_output[relative_artifact.as_posix()] = artifact_bytes
                records.append(
                    {
                        **target,
                        "artifact_path": normalize_path(output_dir / relative_artifact, repo_root),
                        "artifact_relative_path": relative_artifact.as_posix(),
                        "artifact_sha256": sha256_bytes(artifact_bytes),
                        "compiler_input_path": normalize_path(output_dir / compiler_input_relative, repo_root),
                        "compiler_input_relative_path": compiler_input_relative.as_posix(),
                        "compiler_input_sha256": compiler_input_sha256,
                        **bindings,
                    }
                )
            results["groups"].append(group_receipt)

        try:
            results["source_union"] = validate_evidence_source_union(results["groups"])
        except EvidenceFailure as exc:
            raise _r11_first_red(exc.code, "source_union", exc.operands) from exc

        measurements: dict[str, dict[str, Any]] = {}
        for size_ordinal, authority in enumerate(R4_TARGET_AUTHORITIES, start=1):
            evaluation = evaluation_by_target[authority["target"]]
            if not all(item["metadata_admitted"] for item in results["target_evaluations"]):
                raise AssertionError("bytecode began before all metadata admissions")
            evaluation["bytecode_evaluated"] = True

            def observe_step(_step: str, record: dict[str, Any]) -> None:
                evaluation["bytecode_steps"].append(record)

            try:
                measurement = validate_ordered_bytecode(
                    admitted_artifacts[authority["target"]], authority,
                    step_observer=observe_step,
                )
            except EvidenceFailure as exc:
                step_ordinal = len(evaluation["bytecode_steps"])
                raise _r11_first_red(
                    exc.code, "bytecode", exc.operands,
                    call_ordinal=R11_GROUP_INDEX_BY_SOURCE[authority["source"]] + 1,
                    authority=authority, step_ordinal=step_ordinal,
                ) from exc
            evaluation["bytecode_completed"] = True
            if evaluation["bytecode_steps"] != measurement.pop("bytecode_steps"):
                raise AssertionError("bytecode observer trace differs from returned trace")
            measurements[authority["semantic_id"]] = measurement
            results["artifacts"].append(measurement)
            if size_ordinal in R4_AGGREGATE_GATES:
                try:
                    results["aggregates"].extend(
                        _evaluate_aggregate_gate(
                            size_ordinal, measurements,
                            lambda actual, threshold: actual <= threshold,
                            None,
                        )
                    )
                except EvidenceFailure as exc:
                    aggregate_operands = require_dict(
                        exc.operands, "aggregate failure operands",
                    )
                    raise _r11_first_red(
                        exc.code,
                        "aggregate",
                        {
                            "aggregate_id": aggregate_operands["gate"],
                            "member_semantic_ids": aggregate_operands["members"],
                            "metric": aggregate_operands["field"],
                            "values": aggregate_operands["operands"],
                            "actual": aggregate_operands["actual"],
                            "operator": aggregate_operands["operator"],
                            "threshold": aggregate_operands["threshold"],
                        },
                        authority=authority,
                    ) from exc

        records.sort(key=lambda item: (item["kind"], item["name"], item["source"]))
        manifest = build_manifest(
            repo_root, config_path, foundry_config_path, output_dir,
            records, forge_version,
            config_sha256=config_sha256,
            foundry_config_sha256=foundry_config_sha256,
        )
        manifest_raw = _r11_pretty_json_bytes(manifest)
        manifest_path = staged / MANIFEST_FILENAME
        try:
            write_exact_bytes(manifest_path, manifest_raw, "release manifest")
        except BaseException as exc:
            raise _r11_first_red(
                "STAGED_VALIDATION_FAILED", "staged_validation",
                {
                    "cause_type": type(exc).__name__,
                    "message_sha256": sha256_bytes(str(exc).encode("utf-8")),
                },
            ) from exc
        expected_output[MANIFEST_FILENAME] = manifest_raw
        staged_boundary_owner = R11BoundaryOwner(
            "STAGED_OUTPUT_VALIDATE",
            (("prefix", "DONE"),),
            None,
            None,
            lifecycle_token="staged",
        )
        try:
            staged_files, staged_contents = _r11_snapshot_tree(staged, "staged")
        except R11TraversalDiagnostic as diagnostic:
            translated = staged_boundary_owner.translate(diagnostic, None)
            if not isinstance(translated, BaseException):
                raise AssertionError("staged owner returned a non-exception")
            raise translated
        expected_names = sorted(expected_output)
        actual_names = [record["path"] for record in staged_files]
        if actual_names != expected_names or any(
            staged_contents[name] != expected_output[name] for name in expected_names
        ):
            raise _r11_first_red(
                "STAGED_VALIDATION_FAILED", "staged_validation",
                {
                    "cause_type": "STAGED_BYTES_MISMATCH",
                    "message_sha256": sha256_bytes(
                        canonical_evidence_bytes(
                            {"expected": expected_names, "actual": actual_names}
                        )
                    ),
                },
            )
        try:
            if _lock.executable_leases is None:
                raise EvidenceFailure(
                    "EXECUTABLE_LEASE_CONFLICT",
                    "strict executable lease set is absent",
                )
            _lock.executable_leases.revalidate()
        except EvidenceFailure as exc:
            raise _r11_first_red(
                "STAGED_VALIDATION_FAILED",
                "staged_validation",
                {
                    "cause_type": "EXECUTABLE_LEASE_CONFLICT",
                    "message_sha256": sha256_bytes(
                        canonical_evidence_bytes(
                            {"code": exc.code, "operands": exc.operands}
                        )
                    ),
                },
            ) from exc
        try:
            _r11_install_output_no_replace(staged, output_dir, results)
        except EvidenceFailure as exc:
            raise _r11_first_red(
                "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION", "output_install",
                {
                    "path_token": static_receipts["output_dir"]["path_token"],
                    "exception_type": exc.code,
                    "message_sha256": sha256_bytes(canonical_evidence_bytes({"code": exc.code, "operands": exc.operands})),
                },
            ) from exc
        try:
            _r11_cleanup_build_temp(temp_root, results)
            temp_root = None
        except BaseException as exc:
            raise _r11_first_red(
                "OP_BUILD_TEMP_CLEANUP_EXCEPTION", "temp_cleanup",
                {
                    "path_token": _r11_validate_filetoken("build-temp"),
                    "exception_type": type(exc).__name__,
                    "message_sha256": sha256_bytes(str(exc).encode("utf-8")),
                },
            ) from exc
        installed_files: list[dict[str, Any]] = []
        installed: R11RetainedTree | None = None
        installed_primary: BaseException | None = None
        installed_read_set_complete = False
        installed_inventory_owner = R11BoundaryOwner(
            "INSTALLED_INVENTORY",
            (("prefix", "CLEAN"), ("selected_file_token", None)),
            None,
            None,
            lifecycle_token="installed",
        )
        try:
            try:
                installed = R11RetainedTree(output_dir, "installed")
            except R11TraversalDiagnostic as diagnostic:
                raise installed_inventory_owner.translate(diagnostic, None)
            try:
                expected_receipts = [
                    {
                        "path": name,
                        "byte_count": len(expected_output[name]),
                        "sha256": sha256_bytes(expected_output[name]),
                    }
                    for name in expected_names
                ]
                installed_files, _ = _r11_read_retained_output(
                    installed,
                    expected_receipts,
                    read_boundary="INSTALLED_READ",
                )
                installed_read_set_complete = True
            except R11TraversalDiagnostic as diagnostic:
                raise installed_inventory_owner.translate(diagnostic, None)
        except EvidenceFailure as exc:
            installed_primary = exc
            if exc.code not in ("OUTPUT_TOPOLOGY_MISMATCH", "OUTPUT_BYTES_MISMATCH"):
                raise
            installed_primary = _r11_first_red(
                exc.code, "installed_readback", exc.operands,
            )
            raise installed_primary from exc
        except BaseException as exc:
            installed_primary = exc
            raise
        finally:
            if installed is not None:
                try:
                    installed.close(primary=installed_primary)
                except R11TraversalDiagnostic as diagnostic:
                    raise _r11_installed_close_failure(
                        diagnostic,
                        read_set_complete=installed_read_set_complete,
                        inventory_owner=installed_inventory_owner,
                    )
        results["output_files"] = installed_files
        journal.publish_terminal("GO", None, results=results)
        return manifest
    except R11BuilderFailure as failure:
        if journal.state == "STARTED_IDLE" and journal.guard is None and journal.terminal is None:
            journal.publish_terminal(
                "NO_GO", failure.first_red, results=results,
            )
        execution_authority.close(failure)
        raise
    except BaseException as primary:
        execution_authority.close(primary)
        raise


def _event_filename(sequence: int) -> str:
    if sequence == 0:
        return "execution-started.json"
    ordinal = (sequence - 1) // 2
    suffix = "start" if sequence % 2 == 1 else "exit"
    return f"invocation-{ordinal:03d}-{suffix}.json"


def _load_canonical_evidence(path: Path) -> tuple[dict[str, Any], bytes, str]:
    value, raw, digest = load_json_snapshot(path)
    evidence = require_dict(value, str(path))
    if canonical_evidence_bytes(evidence) != raw:
        raise EvidenceFailure("NONCANONICAL_EVIDENCE", f"evidence is not canonical: {path}")
    return evidence, raw, digest


def _read_event_prefix(evidence_dir: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    events: list[dict[str, Any]] = []
    anomalies: list[dict[str, Any]] = []
    previous: str | None = None
    invocation_id: str | None = None
    for sequence in range(R4_SUCCESS_EVENT_COUNT):
        filename = _event_filename(sequence)
        path = evidence_dir / filename
        if not path.is_file():
            anomalies.append({"path": filename, "status": "missing"})
            break
        try:
            event, raw, digest = _load_canonical_evidence(path)
            if event.get("schema") != R4_EVIDENCE_EVENT_SCHEMA:
                raise EvidenceFailure("EVENT_SCHEMA", f"invalid event schema in {filename}")
            if event.get("sequence") != sequence:
                raise EvidenceFailure("EVENT_SEQUENCE", f"invalid event sequence in {filename}")
            if event.get("previous_event_sha256") != previous:
                raise EvidenceFailure("EVENT_LINK", f"invalid previous hash in {filename}")
            if sequence == 0:
                invocation_id = require_string(event.get("invocation_id"), "sentinel invocation_id")
                if event.get("event_type") != "execution_started":
                    raise EvidenceFailure("SENTINEL_TYPE", "sequence zero is not STARTED")
                forbidden = {"own_sha256", "forward_event_sha256"} & set(event)
                if forbidden:
                    raise EvidenceFailure("SENTINEL_HASH_FIELD", "sentinel has a forbidden hash field")
            elif event.get("invocation_id") != invocation_id:
                raise EvidenceFailure("EVENT_INVOCATION", f"wrong invocation in {filename}")
            events.append(event)
            previous = digest
        except BaseException as exc:
            try:
                raw = path.read_bytes()
                digest = sha256_bytes(raw)
            except OSError:
                digest = None
            anomalies.append(
                {
                    "path": filename,
                    "status": "invalid",
                    "sha256": digest,
                    "error": type(exc).__name__,
                }
            )
            break
    expected_prefix = {_event_filename(index) for index in range(len(events))}
    for path in sorted(evidence_dir.iterdir(), key=lambda item: item.name.casefold()):
        if path.name in expected_prefix or path.name == "terminal.json":
            continue
        if not path.is_file():
            anomalies.append({"path": path.name, "status": "unexpected_non_file"})
            continue
        try:
            raw = path.read_bytes()
            digest = sha256_bytes(raw)
            status = "unlinked_event" if path.name.startswith("invocation-") else "residue"
            anomalies.append({"path": path.name, "status": status, "sha256": digest})
        except OSError:
            anomalies.append({"path": path.name, "status": "unreadable"})
    return events, anomalies


def _snapshot_output_files(output: Path) -> list[dict[str, Any]]:
    entries = list(output.rglob("*"))
    for path in entries:
        if path_is_link_or_reparse(path):
            raise EvidenceFailure(
                "OUTPUT_REPARSE_POINT",
                f"installed output contains a link or reparse point: {path}",
            )
    files = sorted((path for path in entries if path.is_file()), key=lambda item: item.relative_to(output).as_posix())
    return [
        {
            "path": path.relative_to(output).as_posix(),
            "byte_count": path.stat().st_size,
            "sha256": file_sha256(path),
        }
        for path in files
    ]


def r4_validate_authoritative_output(output: Path, evidence_dir: Path) -> dict[str, Any]:
    terminal, _, _ = _load_canonical_evidence(evidence_dir / "terminal.json")
    if (
        terminal.get("schema") != R4_EVIDENCE_TERMINAL_SCHEMA
        or terminal.get("status") != "GO"
    ):
        raise EvidenceFailure("TERMINAL_NOT_GO", "authoritative output requires terminal GO")
    events, anomalies = _read_event_prefix(evidence_dir)
    if anomalies or len(events) != R4_SUCCESS_EVENT_COUNT:
        raise EvidenceFailure(
            "EVENT_CHAIN_MISMATCH",
            "GO terminal does not have one complete 0-36 event chain",
            operands={"event_count": len(events), "anomalies": anomalies},
        )
    head = sha256_bytes(canonical_evidence_bytes(events[-1]))
    if terminal.get("event_count") != R4_SUCCESS_EVENT_COUNT or terminal.get("event_head_sha256") != head:
        raise EvidenceFailure("EVENT_CHAIN_MISMATCH", "GO terminal event head/count is stale")
    files = _snapshot_output_files(output)
    expected = require_dict(terminal.get("results"), "terminal results").get("output_files")
    if len(files) != R4_SUCCESS_OUTPUT_FILE_COUNT:
        raise EvidenceFailure("OUTPUT_TOPOLOGY_MISMATCH", "installed output is not exactly 37 files")
    if files != expected:
        raise EvidenceFailure("OUTPUT_BYTES_MISMATCH", "installed output does not match terminal hashes")
    return {"terminal": terminal, "output_files": files}


def reject_duplicate_json_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Reject duplicate JSON members instead of accepting last-key-wins input."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReleaseBuildError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def parse_ijson_integer(token: str) -> int:
    """Accept only integers interoperable across I-JSON consumers."""
    value = int(token)
    if abs(value) > IJSON_SAFE_INTEGER_MAX:
        raise ReleaseBuildError(
            f"JSON integer is outside the I-JSON interoperable range: {token}"
        )
    return value


def reject_json_float(token: str) -> float:
    """Canonical release inputs do not permit floating-point JSON values."""
    raise ReleaseBuildError(
        f"floating-point JSON is forbidden in canonical release inputs: {token}"
    )


def reject_json_constant(token: str) -> None:
    """Reject NaN and infinities."""
    raise ReleaseBuildError(f"non-I-JSON token is forbidden: {token}")


def reject_non_unicode_scalars(value: Any, path: str) -> None:
    """Reject escaped surrogate code points that strict UTF-8 cannot detect."""
    if isinstance(value, str):
        if any(0xD800 <= ord(character) <= 0xDFFF for character in value):
            raise ReleaseBuildError(
                f"{path} contains a non-Unicode-scalar surrogate code point"
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            reject_non_unicode_scalars(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            reject_non_unicode_scalars(key, f"{path}.<member>")
            reject_non_unicode_scalars(item, f"{path}.{key}")


def load_json_text(text: str, label: str) -> Any:
    """Decode duplicate-free JSON under the canonical I-JSON input policy."""
    try:
        value = json.loads(
            text,
            object_pairs_hook=reject_duplicate_json_pairs,
            parse_int=parse_ijson_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        raise ReleaseBuildError(f"invalid JSON in {label}: {exc}") from exc
    reject_non_unicode_scalars(value, label)
    return value


@dataclass(frozen=True)
class ReleaseFileSnapshot:
    """One exact file version consumed by canonical release validation."""

    path: Path
    raw: bytes
    sha256: str


@dataclass(frozen=True)
class ValidatedReleaseOutput:
    """Validated receipt plus exact receipt/config/artifact file versions."""

    receipt: dict[str, Any]
    receipt_snapshot: ReleaseFileSnapshot
    config_snapshot: ReleaseFileSnapshot
    foundry_config_snapshot: ReleaseFileSnapshot
    artifact_snapshots: tuple[ReleaseFileSnapshot, ...]


CommandRunner = Callable[[list[str], Path], None]


def read_required_bytes(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing required file: {path}") from exc
    except OSError as exc:
        raise ReleaseBuildError(f"unable to read required file {path}: {exc}") from exc


def load_json_bytes(raw: bytes, path: Path) -> Any:
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise ReleaseBuildError(f"{path} is not strict UTF-8 JSON: {exc}") from exc
    return load_json_text(text, str(path))


def load_json_snapshot(path: Path) -> tuple[Any, bytes, str]:
    raw = read_required_bytes(path)
    return load_json_bytes(raw, path), raw, sha256_bytes(raw)


def load_json_with_sha256(path: Path) -> tuple[Any, str]:
    value, _, digest = load_json_snapshot(path)
    return value, digest


def load_json(path: Path) -> Any:
    value, _ = load_json_with_sha256(path)
    return value


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_exact_bytes(path: Path, value: bytes, label: str) -> None:
    try:
        written = path.write_bytes(value)
    except OSError as exc:
        raise ReleaseBuildError(f"unable to write {label} {path}: {exc}") from exc
    if written != len(value):
        raise ReleaseBuildError(
            f"short write for {label} {path}: wrote {written} of {len(value)} bytes"
        )


def file_sha256(path: Path) -> str:
    return sha256_bytes(read_required_bytes(path))


def canonical_json_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def ordered_json_bytes(value: Any) -> bytes:
    """Serialize parsed compiler input while preserving Foundry's object order."""
    return json.dumps(
        value,
        sort_keys=False,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def keccak256_hex(value: bytes) -> str:
    try:
        from eth_hash.auto import keccak

        return "0x" + keccak(value).hex()
    except ImportError:
        pass

    try:
        from Crypto.Hash import keccak as crypto_keccak

        digest = crypto_keccak.new(digest_bits=256)
        digest.update(value)
        return "0x" + digest.hexdigest()
    except ImportError as exc:
        raise ReleaseBuildError(
            "Ethereum Keccak support is required to validate compiler metadata; "
            "install the hashed requirements-tools.lock environment"
        ) from exc


def normalize_path(path: Path, repo_root: Path) -> str:
    lexical = Path(os.path.abspath(os.path.normpath(path)))
    try:
        return lexical.relative_to(repo_root).as_posix()
    except ValueError:
        try:
            return lexical.resolve().relative_to(repo_root.resolve()).as_posix()
        except ValueError:
            return lexical.as_posix()


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseBuildError(f"{label} must be an object")
    return value


def require_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise ReleaseBuildError(f"{label} must be an array")
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ReleaseBuildError(f"{label} must be a non-empty string")
    return value


def lexical_repo_path(repo_root: Path, value: Path, label: str) -> Path:
    path = value if value.is_absolute() else repo_root / value
    lexical = Path(os.path.abspath(os.path.normpath(path)))
    try:
        lexical.relative_to(repo_root)
    except ValueError as exc:
        if os.name != "nt":
            raise ReleaseBuildError(
                f"{label} must stay inside the repository: {value}"
            ) from exc
        # Windows may return an absolute input with an 8.3 path component while
        # Path.resolve() expands the repository root. Inspect every component
        # before resolution, then accept the alias only if it resolves inside.
        cursor = Path(lexical.anchor)
        for part in lexical.parts[1:]:
            cursor /= part
            if path_is_link_or_reparse(cursor):
                raise ReleaseBuildError(
                    f"{label} must not use symlink, junction, or reparse "
                    f"components: {cursor}"
                ) from None
        resolved = lexical.resolve()
        try:
            resolved.relative_to(repo_root)
        except ValueError:
            raise ReleaseBuildError(
                f"{label} must stay inside the repository: {value}"
            ) from exc
        return resolved
    return lexical


def path_is_link_or_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attributes = getattr(os.lstat(path), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(reparse_flag and attributes & reparse_flag)


def reject_link_or_reparse_components(
    repo_root: Path,
    path: Path,
    label: str,
) -> None:
    try:
        relative = path.relative_to(repo_root)
    except ValueError as exc:
        raise ReleaseBuildError(f"{label} must stay inside the repository: {path}") from exc
    cursor = repo_root
    for part in relative.parts:
        cursor /= part
        if path_is_link_or_reparse(cursor):
            raise ReleaseBuildError(
                f"{label} must not use symlink, junction, or reparse components: {cursor}"
            )


def resolve_repo_path(repo_root: Path, value: Path, label: str) -> Path:
    lexical = lexical_repo_path(repo_root, value, label)
    reject_link_or_reparse_components(repo_root, lexical, label)
    resolved = lexical.resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ReleaseBuildError(f"{label} must stay inside the repository: {value}") from exc
    return resolved


def reject_restricted_release_source(
    repo_root: Path,
    source_path: Path,
    label: str,
) -> None:
    relative = normalize_path(source_path, repo_root)
    parts = Path(relative).parts
    if parts and parts[0].casefold() in RESTRICTED_RELEASE_SOURCE_ROOTS:
        raise ReleaseBuildError(
            f"{label} is under restricted canonical release source root "
            f"{parts[0]!r}: {relative}"
        )


def resolve_canonical_output_path(repo_root: Path, value: Path) -> Path:
    lexical = lexical_repo_path(repo_root, value, "release output directory")
    canonical = repo_root / DEFAULT_OUTPUT_DIR
    if lexical != canonical:
        raise ReleaseBuildError(
            "release output directory must be the canonical repository "
            f"{DEFAULT_OUTPUT_DIR.as_posix()} directory"
        )
    reject_link_or_reparse_components(
        repo_root,
        lexical,
        "release output directory",
    )
    return lexical.resolve()


def load_foundry_profile_bytes(raw: bytes, path: Path) -> dict[str, Any]:
    if tomllib is None:
        raise ReleaseBuildError("Python 3.11+ is required to read foundry.toml")
    try:
        config = tomllib.loads(raw.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise ReleaseBuildError(f"invalid UTF-8 in {path}: {exc}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise ReleaseBuildError(f"invalid TOML in {path}: {exc}") from exc
    profile = require_dict(config.get("profile"), "foundry.toml profile")
    return require_dict(profile.get("default"), "foundry.toml profile.default")


def load_foundry_profile(path: Path) -> dict[str, Any]:
    return load_foundry_profile_bytes(read_required_bytes(path), path)


def validate_foundry_profile_data(profile: dict[str, Any]) -> None:
    expected = {
        "test": "test",
        "script": "script",
        "solc_version": SOLC_VERSION,
        "auto_detect_solc": False,
        "evm_version": EVM_VERSION,
        "optimizer": True,
        "optimizer_runs": OPTIMIZER_RUNS,
        "bytecode_hash": "none",
        "cbor_metadata": False,
    }
    for key, expected_value in expected.items():
        actual = profile.get(key)
        if actual != expected_value:
            raise ReleaseBuildError(
                f"foundry.toml profile.default.{key} is {actual!r}, "
                f"expected {expected_value!r}"
            )


def validate_foundry_profile(path: Path) -> None:
    validate_foundry_profile_data(load_foundry_profile(path))


def configured_targets_from_config(
    repo_root: Path,
    config_path: Path,
    config: dict[str, Any],
) -> list[dict[str, str]]:
    targets: list[dict[str, str]] = []
    names: set[str] = set()

    for kind, config_key in TARGET_GROUPS:
        entries = require_list(config.get(config_key, []), f"{config_path}.{config_key}")
        if config_key == "production_contracts" and not entries:
            raise ReleaseBuildError("production_contracts must not be empty")
        for index, value in enumerate(entries):
            entry = require_dict(value, f"{config_path}.{config_key}[{index}]")
            name = require_string(entry.get("name"), f"{config_key}[{index}].name")
            source = Path(
                require_string(entry.get("source"), f"{config_key}[{index}].source")
            ).as_posix()
            if not TARGET_NAME_RE.fullmatch(name):
                raise ReleaseBuildError(f"invalid Solidity target name: {name!r}")
            if name in names:
                raise ReleaseBuildError(f"duplicate configured release target name: {name}")
            names.add(name)

            source_path = resolve_repo_path(
                repo_root,
                Path(source),
                f"{config_key}[{index}].source",
            )
            reject_restricted_release_source(
                repo_root,
                source_path,
                f"{config_key}[{index}].source",
            )
            if source_path.suffix != ".sol" or not source_path.is_file():
                raise ReleaseBuildError(f"configured Solidity source is missing: {source}")
            targets.append({"kind": kind, "name": name, "source": source})

    return sorted(targets, key=lambda item: (item["kind"], item["name"], item["source"]))


def configured_targets(repo_root: Path, config_path: Path) -> list[dict[str, str]]:
    config = require_dict(load_json(config_path), str(config_path))
    return configured_targets_from_config(repo_root, config_path, config)


def artifact_metadata(artifact: dict[str, Any], label: str) -> dict[str, Any]:
    metadata = artifact.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    if isinstance(metadata, str):
        try:
            return require_dict(
                load_json_text(metadata, f"{label}.metadata"),
                f"{label}.metadata",
            )
        except ReleaseBuildError as exc:
            raise ReleaseBuildError(f"invalid metadata JSON in {label}: {exc}") from exc
    raise ReleaseBuildError(f"{label} does not contain compiler metadata")


def metadata_source_records(
    repo_root: Path,
    metadata: dict[str, Any],
    label: str,
) -> list[dict[str, str]]:
    sources = require_dict(metadata.get("sources"), f"{label}.metadata.sources")
    records = []
    for source in sorted(sources):
        metadata_source = require_dict(
            sources.get(source),
            f"{label}.metadata.sources.{source}",
        )
        recorded_keccak = require_string(
            metadata_source.get("keccak256"),
            f"{label}.metadata.sources.{source}.keccak256",
        )
        source_path = resolve_repo_path(repo_root, Path(source), f"{label} metadata source")
        reject_restricted_release_source(
            repo_root,
            source_path,
            f"{label} metadata source",
        )
        if not source_path.is_file():
            raise ReleaseBuildError(f"{label} metadata source is missing: {source}")
        source_bytes = source_path.read_bytes()
        actual_keccak = keccak256_hex(source_bytes)
        if recorded_keccak.lower() != actual_keccak.lower():
            raise ReleaseBuildError(
                f"{label} metadata keccak256 for {source} does not match the checkout"
            )
        records.append(
            {
                "path": Path(source).as_posix(),
                "sha256": sha256_bytes(source_bytes),
                "keccak256": actual_keccak,
            }
        )
    if not records:
        raise ReleaseBuildError(f"{label}.metadata.sources must not be empty")
    return records


def canonicalize_build_info_compiler_paths(
    repo_root: Path,
    compiler_input: dict[str, Any],
    label: str,
) -> dict[str, Any]:
    """Replace exact worktree path carriers with a portable retained form."""
    repo_root = repo_root.resolve()
    raw_root = repo_root.as_posix()
    raw_lib = (repo_root / "lib").as_posix()
    expected = {
        "allowPaths": [raw_root, raw_lib],
        "basePath": raw_root,
        "includePaths": [raw_root],
    }
    for field, expected_value in expected.items():
        if compiler_input.get(field) != expected_value:
            raise ReleaseBuildError(
                f"{label} compiler input {field} must be exactly "
                f"{expected_value!r} before portable retention"
            )

    portable = dict(compiler_input)
    portable.update(
        {
            field: list(value) if isinstance(value, list) else value
            for field, value in PORTABLE_COMPILER_PATHS.items()
        }
    )
    return portable


def validate_portable_compiler_paths(
    compiler_input: dict[str, Any],
    label: str,
) -> None:
    for field, expected_value in PORTABLE_COMPILER_PATHS.items():
        if compiler_input.get(field) != expected_value:
            raise ReleaseBuildError(
                f"{label} retained compiler input {field} must be exactly "
                f"{expected_value!r}"
            )


def validate_compiler_input(
    repo_root: Path,
    compiler_input: dict[str, Any],
    label: str,
) -> dict[str, Any]:
    validate_portable_compiler_paths(compiler_input, label)
    if compiler_input.get("language") != "Solidity":
        raise ReleaseBuildError(f"{label} compiler input language must be Solidity")
    sources = require_dict(compiler_input.get("sources"), f"{label}.input.sources")
    if not sources:
        raise ReleaseBuildError(f"{label}.input.sources must not be empty")

    source_records = []
    for source, value in sources.items():
        source_entry = require_dict(value, f"{label}.input.sources.{source}")
        content = require_string(
            source_entry.get("content"),
            f"{label}.input.sources.{source}.content",
        )
        source_path = resolve_repo_path(
            repo_root,
            Path(source),
            f"{label} compiler input source",
        )
        reject_restricted_release_source(
            repo_root,
            source_path,
            f"{label} compiler input source",
        )
        try:
            checkout_content = source_path.read_bytes().decode("utf-8")
        except FileNotFoundError as exc:
            raise ReleaseBuildError(
                f"{label} compiler input source is missing: {source}"
            ) from exc
        except UnicodeDecodeError as exc:
            raise ReleaseBuildError(
                f"{label} compiler input source is not UTF-8: {source}"
            ) from exc
        if content != checkout_content:
            raise ReleaseBuildError(
                f"{label} compiler input content does not match the checkout: {source}"
            )
        content_bytes = content.encode("utf-8")
        source_records.append(
            {
                "path": Path(source).as_posix(),
                "sha256": sha256_bytes(content_bytes),
                "keccak256": keccak256_hex(content_bytes),
            }
        )

    settings = require_dict(compiler_input.get("settings"), f"{label}.input.settings")
    if settings.get("viaIR") is not True:
        raise ReleaseBuildError(f"{label} compiler input does not enable viaIR")
    if settings.get("evmVersion") != EVM_VERSION:
        raise ReleaseBuildError(
            f"{label} compiler input EVM version must be {EVM_VERSION}"
        )
    optimizer = require_dict(
        settings.get("optimizer"),
        f"{label}.input.settings.optimizer",
    )
    if optimizer.get("enabled") is not True or optimizer.get("runs") != OPTIMIZER_RUNS:
        raise ReleaseBuildError(
            f"{label} compiler input optimizer must use {OPTIMIZER_RUNS} runs"
        )
    metadata = require_dict(
        settings.get("metadata"),
        f"{label}.input.settings.metadata",
    )
    if metadata.get("bytecodeHash") != "none" or metadata.get("appendCBOR") is not False:
        raise ReleaseBuildError(
            f"{label} compiler input metadata must disable bytecode hash and CBOR"
        )

    ordered_input = ordered_json_bytes(compiler_input)
    return {
        "compiler_input_sources": source_records,
        "compiler_input_source_order": [record["path"] for record in source_records],
        "compiler_input_settings_sha256": canonical_json_sha256(settings),
        "compiler_input_ordered_sha256": sha256_bytes(ordered_input),
        "compiler_input_canonical_sha256": canonical_json_sha256(compiler_input),
    }


def _authority_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def validate_r4_authority_constants() -> None:
    group_map = [
        {
            "group": group["group"],
            "source": group["source"].removeprefix("smart-contracts/"),
            "sources": [
                source.removeprefix("smart-contracts/")
                for source in group["sources"]
            ],
        }
        for group in R4_GROUPS
    ]
    if hashlib.sha256(_authority_json_bytes(group_map)).hexdigest().upper() != (
        R4_GROUP_MAP_SHA256
    ):
        raise EvidenceFailure("GROUP_MAP_AUTHORITY", "embedded group map hash is invalid")
    constructor_map = [
        {
            "target": target["target"],
            "signature": target["signature"],
            "words": target["words"],
            "bytes": target["bytes"],
        }
        for target in R4_TARGET_AUTHORITIES
    ]
    if hashlib.sha256(_authority_json_bytes(constructor_map)).hexdigest().upper() != (
        R4_CONSTRUCTOR_MAP_SHA256
    ):
        raise EvidenceFailure(
            "CONSTRUCTOR_MAP_AUTHORITY",
            "embedded constructor map hash is invalid",
        )


def _source_closure_aggregate(records: Sequence[dict[str, Any]]) -> str:
    authority = bytearray()
    for record in sorted(records, key=lambda item: item["path"].casefold()):
        authority.extend(
            record["path"].removeprefix("smart-contracts/").encode("utf-8")
        )
        authority.extend(b"\n")
        authority.extend(record["sha256"].removeprefix("sha256:").upper().encode("ascii"))
        authority.extend(b"\n")
        authority.extend(str(record["byte_count"]).encode("ascii"))
        authority.extend(b"\n")
    return hashlib.sha256(authority).hexdigest().upper()


def validate_evidence_group_closure(
    group_index: int,
    source: str,
    compiler_input: dict[str, Any],
    expected_source_receipts: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    if group_index < 0 or group_index >= len(R4_GROUPS):
        raise EvidenceFailure(
            "GROUP_INDEX",
            f"group index is outside 000-016: {group_index}",
        )
    authority = R4_GROUPS[group_index]
    if source != authority["source"]:
        actual_group_string = (
            f"{group_index:03d}::{source}" if isinstance(source, str) else None
        )
        raise EvidenceFailure(
            "GROUP_STRING_MISMATCH",
            f"group {group_index:03d} source is not exact",
            operands={
                "expected_group_string": authority["group_string"],
                "actual_type": _r11_json_type(source),
                "actual_sha256": (
                    sha256_bytes(actual_group_string.encode("utf-8"))
                    if actual_group_string is not None else None
                ),
            },
        )
    sources = require_dict(
        compiler_input.get("sources"),
        f"group {group_index:03d} compiler input sources",
    )
    actual_paths = set(sources)
    expected_paths = set(authority["sources"])
    if actual_paths != expected_paths:
        expected_names = sorted(expected_paths, key=str.casefold)
        actual_names = sorted(actual_paths, key=str.casefold)
        raise EvidenceFailure(
            "GROUP_CLOSURE_MISMATCH",
            f"group {group_index:03d} source closure is not all-and-only",
            operands={
                "expected_count": len(expected_names),
                "actual_count": len(actual_names),
                "expected_set_sha256": sha256_bytes(
                    canonical_evidence_bytes(expected_names)
                ),
                "actual_set_sha256": sha256_bytes(
                    canonical_evidence_bytes(actual_names)
                ),
            },
        )
    records = []
    expected_byte_count = 0
    for path in sorted(actual_paths, key=str.casefold):
        entry = require_dict(sources[path], f"group {group_index:03d} source {path}")
        content = entry.get("content")
        expected_receipt = (
            expected_source_receipts.get(path)
            if expected_source_receipts is not None else None
        )
        if expected_receipt is not None:
            expected_sha256 = require_string(
                expected_receipt.get("sha256"),
                f"group {group_index:03d} expected source {path} sha256",
            )
            receipt_byte_count = expected_receipt.get("byte_count")
            if not _r11_u53(receipt_byte_count):
                raise EvidenceFailure(
                    "GROUP_SOURCE_BYTES_MISMATCH",
                    f"group {group_index:03d} expected source receipt is malformed",
                )
            expected_byte_count += receipt_byte_count
        else:
            expected_sha256 = None
        if not isinstance(content, str):
            raise EvidenceFailure(
                "GROUP_SOURCE_CONTENT",
                f"group {group_index:03d} source {path}.content must be a string",
                operands={
                    "source_path": path,
                    "expected_sha256": expected_sha256 or sha256_bytes(b""),
                    "actual_sha256": sha256_bytes(canonical_evidence_bytes(content)),
                },
            )
        raw = content.encode("utf-8", "strict")
        actual_sha256 = sha256_bytes(raw)
        if expected_sha256 is not None and actual_sha256 != expected_sha256:
            raise EvidenceFailure(
                "GROUP_SOURCE_CONTENT",
                f"group {group_index:03d} source {path}.content differs",
                operands={
                    "source_path": path,
                    "expected_sha256": expected_sha256,
                    "actual_sha256": actual_sha256,
                },
            )
        records.append(
            {
                "path": path,
                "sha256": actual_sha256,
                "byte_count": len(raw),
            }
        )
    aggregate = _source_closure_aggregate(records)
    if aggregate != authority["aggregate_sha256"]:
        raise EvidenceFailure(
            "GROUP_SOURCE_BYTES_MISMATCH",
            f"group {group_index:03d} source bytes do not match 1EB0 authority",
            operands={
                "expected_byte_count": expected_byte_count,
                "actual_byte_count": sum(record["byte_count"] for record in records),
                "expected_aggregate_sha256": (
                    "sha256:" + authority["aggregate_sha256"].lower()
                ),
                "actual_aggregate_sha256": "sha256:" + aggregate.lower(),
            },
        )
    return {
        "group": authority["group"],
        "group_string": authority["group_string"],
        "source": source,
        "source_count": len(records),
        "aggregate_sha256": aggregate,
        "sources": records,
    }


def validate_evidence_group_string(group_index: int, group_string: str) -> dict[str, Any]:
    if group_index < 0 or group_index >= len(R4_GROUPS):
        raise EvidenceFailure("GROUP_INDEX", f"group index is outside 000-016: {group_index}")
    authority = R4_GROUPS[group_index]
    if group_string != authority["group_string"]:
        raise EvidenceFailure(
            "GROUP_STRING_MISMATCH",
            f"group {group_index:03d} string is not exact",
            operands={"expected": authority["group_string"], "actual": group_string},
        )
    return authority


def validate_evidence_source_union(
    group_receipts: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    occurrences: dict[str, list[tuple[int, str, int]]] = {}
    for group_index, group in enumerate(group_receipts):
        for record in group["sources"]:
            occurrences.setdefault(record["path"], []).append(
                (group_index, record["sha256"], record["byte_count"])
            )
    identities: dict[str, tuple[str, int]] = {}
    for path in sorted(occurrences, key=lambda value: (value.casefold(), value)):
        rows = sorted(occurrences[path])
        first_group_index, first_sha256, first_byte_count = rows[0]
        for second_group_index, second_sha256, second_byte_count in rows[1:]:
            if (second_sha256, second_byte_count) != (first_sha256, first_byte_count):
                raise EvidenceFailure(
                    "SOURCE_UNION_CONFLICT",
                    f"conflicting bytes for {path}",
                    operands={
                        "source_path": path,
                        "first_group_index": first_group_index,
                        "second_group_index": second_group_index,
                        "first_sha256": first_sha256,
                        "second_sha256": second_sha256,
                    },
                )
        identities[path] = (first_sha256, first_byte_count)
    records = [
        {"path": path, "sha256": identity[0], "byte_count": identity[1]}
        for path, identity in identities.items()
    ]
    aggregate = _source_closure_aggregate(records)
    if len(records) != 31 or aggregate != R4_SOURCE_AGGREGATE_SHA256:
        raise EvidenceFailure(
            "SOURCE_UNION_MISMATCH",
            "source union is not exact 31-file 1EB0 authority",
            operands={
                "expected_count": 31,
                "actual_count": len(records),
                "expected_aggregate_sha256": (
                    "sha256:" + R4_SOURCE_AGGREGATE_SHA256.lower()
                ),
                "actual_aggregate_sha256": "sha256:" + aggregate.lower(),
            },
        )
    return {
        "count": 31,
        "aggregate_sha256": "sha256:" + aggregate.lower(),
    }


def _observe_step(
    observer: Callable[[str, dict[str, Any]], None] | None,
    step: str,
    operands: dict[str, Any],
) -> None:
    if observer is not None:
        observer(step, dict(operands))


def _bytecode_predicate(
    step: str,
    passed: bool,
    error_code: str,
    operands: dict[str, Any],
    observer: Callable[[str, dict[str, Any]], None] | None,
) -> None:
    observed = {**operands, "kind": "predicate", "passed": bool(passed)}
    _observe_step(observer, step, observed)
    if not passed:
        raise EvidenceFailure(error_code, f"{step} predicate failed", operands=observed)


def _bytecode_operation(
    step: str,
    operands: dict[str, Any],
    operation: Callable[[], Any],
    observer: Callable[[str, dict[str, Any]], None] | None,
    operation_hook: Callable[[str, dict[str, Any]], None] | None,
) -> Any:
    try:
        if operation_hook is not None:
            operation_hook(step, dict(operands))
        result = operation()
    except BaseException as exc:
        raise EvidenceFailure(
            f"OP_{step}_EXCEPTION",
            f"{step} operation raised {type(exc).__name__}",
            operands=operands,
        ) from exc
    observed = {**operands, "kind": "operation", "result": result}
    _observe_step(observer, step, observed)
    return result


def r4_validate_ordered_bytecode(
    artifact: dict[str, Any],
    target_authority: dict[str, Any],
    *,
    step_observer: Callable[[str, dict[str, Any]], None] | None = None,
    operation_hook: Callable[[str, dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    target = target_authority["target"]
    bytecode = artifact.get("bytecode")
    _bytecode_predicate("CREATION_CONTAINER", isinstance(bytecode, dict), "BC_CREATION_MISSING" if bytecode is None else "BC_CREATION_NOT_OBJECT", {"target": target}, step_observer)
    creation_object = bytecode.get("object")
    _bytecode_predicate("CREATION_OBJECT_STRING", isinstance(creation_object, str), "BC_CREATION_OBJECT_MISSING" if creation_object is None else "BC_CREATION_OBJECT_NOT_STRING", {"target": target}, step_observer)
    creation_normalized = _bytecode_operation(
        "NORMALIZE_CREATION_PREFIX",
        {"target": target, "input_length": len(creation_object), "input_sha256": sha256_bytes(creation_object.encode("utf-8"))},
        lambda: creation_object[2:] if creation_object.startswith(("0x", "0X")) else creation_object,
        step_observer,
        operation_hook,
    )
    creation_base = {"target": target, "length": len(creation_normalized), "sha256": sha256_bytes(creation_normalized.encode("utf-8"))}
    _bytecode_predicate("CREATION_NONEMPTY", len(creation_normalized) > 0, "BC_CREATION_EMPTY", creation_base, step_observer)
    _bytecode_predicate("CREATION_EVEN_LENGTH", len(creation_normalized) % 2 == 0, "BC_CREATION_ODD_LENGTH", creation_base, step_observer)
    _bytecode_predicate("CREATION_PLACEHOLDER_ABSENT", re.search(r"__\$[0-9a-fA-F]{34}\$__", creation_normalized) is None, "BC_CREATION_UNRESOLVED_PLACEHOLDER", creation_base, step_observer)
    _bytecode_predicate("CREATION_FULL_HEX", re.fullmatch(r"[0-9A-Fa-f]*", creation_normalized) is not None, "BC_CREATION_NON_HEX", creation_base, step_observer)
    creation_links = bytecode.get("linkReferences")
    creation_links_code = "BC_CREATION_LINKS_MISSING" if creation_links is None else ("BC_CREATION_LINKS_NOT_OBJECT" if not isinstance(creation_links, dict) else "BC_CREATION_LINKS_NONEMPTY")
    _bytecode_predicate("CREATION_LINK_REFERENCES_EMPTY", isinstance(creation_links, dict) and not creation_links, creation_links_code, {"target": target}, step_observer)

    runtime = artifact.get("deployedBytecode")
    _bytecode_predicate("RUNTIME_CONTAINER", isinstance(runtime, dict), "BC_RUNTIME_MISSING" if runtime is None else "BC_RUNTIME_NOT_OBJECT", {"target": target}, step_observer)
    runtime_object = runtime.get("object")
    _bytecode_predicate("RUNTIME_OBJECT_STRING", isinstance(runtime_object, str), "BC_RUNTIME_OBJECT_MISSING" if runtime_object is None else "BC_RUNTIME_OBJECT_NOT_STRING", {"target": target}, step_observer)
    runtime_normalized = _bytecode_operation(
        "NORMALIZE_RUNTIME_PREFIX",
        {"target": target, "input_length": len(runtime_object), "input_sha256": sha256_bytes(runtime_object.encode("utf-8"))},
        lambda: runtime_object[2:] if runtime_object.startswith(("0x", "0X")) else runtime_object,
        step_observer,
        operation_hook,
    )
    runtime_base = {"target": target, "length": len(runtime_normalized), "sha256": sha256_bytes(runtime_normalized.encode("utf-8"))}
    _bytecode_predicate("RUNTIME_NONEMPTY", len(runtime_normalized) > 0, "BC_RUNTIME_EMPTY", runtime_base, step_observer)
    _bytecode_predicate("RUNTIME_EVEN_LENGTH", len(runtime_normalized) % 2 == 0, "BC_RUNTIME_ODD_LENGTH", runtime_base, step_observer)
    _bytecode_predicate("RUNTIME_PLACEHOLDER_ABSENT", re.search(r"__\$[0-9a-fA-F]{34}\$__", runtime_normalized) is None, "BC_RUNTIME_UNRESOLVED_PLACEHOLDER", runtime_base, step_observer)
    _bytecode_predicate("RUNTIME_FULL_HEX", re.fullmatch(r"[0-9A-Fa-f]*", runtime_normalized) is not None, "BC_RUNTIME_NON_HEX", runtime_base, step_observer)
    runtime_links = runtime.get("linkReferences")
    runtime_links_code = "BC_RUNTIME_LINKS_MISSING" if runtime_links is None else ("BC_RUNTIME_LINKS_NOT_OBJECT" if not isinstance(runtime_links, dict) else "BC_RUNTIME_LINKS_NONEMPTY")
    _bytecode_predicate("RUNTIME_LINK_REFERENCES_EMPTY", isinstance(runtime_links, dict) and not runtime_links, runtime_links_code, {"target": target}, step_observer)

    abi = artifact.get("abi")
    if not isinstance(abi, list):
        _bytecode_predicate("CONSTRUCTOR_ABI_SHAPE", False, "ABI_NOT_ARRAY", {"target": target}, step_observer)
    constructors = [entry for entry in abi if isinstance(entry, dict) and entry.get("type") == "constructor"]
    if len(constructors) != 1:
        _bytecode_predicate("CONSTRUCTOR_ABI_SHAPE", False, "ABI_CONSTRUCTOR_COUNT", {"target": target, "count": len(constructors)}, step_observer)
    inputs = constructors[0].get("inputs")
    if not isinstance(inputs, list) or any(not isinstance(item, dict) or not isinstance(item.get("type"), str) for item in inputs):
        _bytecode_predicate("CONSTRUCTOR_ABI_SHAPE", False, "ABI_CONSTRUCTOR_TYPES_ORDER", {"target": target}, step_observer)
    input_types = [item["type"] for item in inputs]
    expected_types = list(target_authority["input_types"])
    _bytecode_predicate("CONSTRUCTOR_ABI_SHAPE", input_types == expected_types, "ABI_CONSTRUCTOR_TYPES_ORDER", {"target": target, "actual": input_types, "expected": expected_types}, step_observer)
    metrics = _bytecode_operation(
        "DERIVE_CONSTRUCTOR_METRICS",
        {"target": target, "input_types": input_types},
        lambda: {"signature": f"constructor({','.join(input_types)})", "words": len(input_types), "bytes": len(input_types) * 32},
        step_observer,
        operation_hook,
    )
    metric_checks = (("signature", "ABI_CONSTRUCTOR_SIGNATURE"), ("words", "ABI_CONSTRUCTOR_WORDS"), ("bytes", "ABI_CONSTRUCTOR_WIDTH"))
    for field, code in metric_checks:
        if metrics[field] != target_authority[field]:
            _bytecode_predicate("CONSTRUCTOR_METRICS_EXACT", False, code, {"target": target, "field": field, "actual": metrics[field], "expected": target_authority[field]}, step_observer)
    _bytecode_predicate("CONSTRUCTOR_METRICS_EXACT", True, "ABI_CONSTRUCTOR_WIDTH", {"target": target, **metrics}, step_observer)
    creation_bytes = _bytecode_operation("DECODE_CREATION_BYTES", creation_base, lambda: bytes.fromhex(creation_normalized), step_observer, operation_hook)
    full_initcode_bytes = _bytecode_operation("COMPUTE_FULL_INITCODE", {"target": target, "creation_bytes": len(creation_bytes), "constructor_bytes": metrics["bytes"]}, lambda: len(creation_bytes) + metrics["bytes"], step_observer, operation_hook)
    _bytecode_predicate("FULL_INITCODE_LIMIT", full_initcode_bytes < R4_INITCODE_LIMIT, "SIZE_INITCODE_LIMIT", {"target": target, "actual": full_initcode_bytes, "operator": "<", "threshold": R4_INITCODE_LIMIT}, step_observer)
    runtime_bytes_value = _bytecode_operation("DECODE_RUNTIME_BYTES", runtime_base, lambda: bytes.fromhex(runtime_normalized), step_observer, operation_hook)
    runtime_bytes = len(runtime_bytes_value)
    _bytecode_predicate("RUNTIME_PACKET_LIMIT", runtime_bytes < R4_RUNTIME_PACKET_LIMIT, "SIZE_RUNTIME_PACKET_LIMIT", {"target": target, "actual": runtime_bytes, "operator": "<", "threshold": R4_RUNTIME_PACKET_LIMIT}, step_observer)
    _bytecode_predicate("RUNTIME_TARGET_CAP", runtime_bytes <= target_authority["runtime_cap"], "SIZE_RUNTIME_TARGET_CAP", {"target": target, "actual": runtime_bytes, "operator": "<=", "threshold": target_authority["runtime_cap"]}, step_observer)
    code_deposit_gas = _bytecode_operation("COMPUTE_CODE_DEPOSIT_GAS", {"target": target, "runtime_bytes": runtime_bytes, "gas_per_byte": R4_CODE_DEPOSIT_GAS_PER_BYTE}, lambda: runtime_bytes * R4_CODE_DEPOSIT_GAS_PER_BYTE, step_observer, operation_hook)
    return {
        "semantic_id": target_authority["semantic_id"],
        "target": target,
        "creation_bytes": len(creation_bytes),
        "creation_sha256": sha256_bytes(creation_bytes),
        "constructor_signature": metrics["signature"],
        "constructor_words": metrics["words"],
        "constructor_bytes": metrics["bytes"],
        "full_initcode_bytes": full_initcode_bytes,
        "runtime_bytes": runtime_bytes,
        "runtime_sha256": sha256_bytes(runtime_bytes_value),
        "runtime_cap": target_authority["runtime_cap"],
        "code_deposit_gas": code_deposit_gas,
    }


def _evaluate_aggregate_gate(
    gate_index: int,
    measurements: dict[str, dict[str, Any]],
    comparator: Callable[[int, int], bool],
    observer: Callable[[str, dict[str, Any]], None] | None,
) -> list[dict[str, Any]]:
    results = []
    for gate_id, members, field, threshold in R4_AGGREGATE_GATES.get(gate_index, ()):
        operands = [measurements[member][field] for member in members]
        actual = sum(operands)
        result = {
            "gate": gate_id,
            "members": list(members),
            "field": field,
            "operands": operands,
            "actual": actual,
            "operator": "<=",
            "threshold": threshold,
        }
        passed = bool(comparator(actual, threshold))
        if observer is not None:
            observer(gate_id, {**result, "passed": passed})
        if not passed:
            raise EvidenceFailure(gate_id, f"aggregate gate {gate_id} failed", operands=result)
        results.append({**result, "passed": True})
    return results


def evaluate_aggregate_gates(
    measurements: dict[str, dict[str, Any]],
    *,
    comparator: Callable[[int, int], bool] | None = None,
    observer: Callable[[str, dict[str, Any]], None] | None = None,
) -> list[dict[str, Any]]:
    compare = comparator or (lambda actual, threshold: actual <= threshold)
    results = []
    for gate_index in (3, 7, 8, 11):
        missing = [
            member
            for _, members, _, _ in R4_AGGREGATE_GATES[gate_index]
            for member in members
            if member not in measurements
        ]
        if missing:
            raise EvidenceFailure(
                "AGGREGATE_MEMBER_MISSING",
                f"gate {gate_index} is missing measured members",
                operands={"missing": sorted(set(missing))},
            )
        results.extend(_evaluate_aggregate_gate(gate_index, measurements, compare, observer))
    return results


def load_build_info_input(build_info_dir: Path, label: str) -> dict[str, Any]:
    build_info_files = sorted(build_info_dir.glob("*.json"))
    if len(build_info_files) != 1:
        locations = ", ".join(str(path) for path in build_info_files) or "none"
        raise ReleaseBuildError(
            f"{label} must emit exactly one Foundry build-info file, found: {locations}"
        )
    build_info = require_dict(load_json(build_info_files[0]), str(build_info_files[0]))
    return require_dict(build_info.get("input"), f"{build_info_files[0]}.input")


def load_retained_compiler_input_with_sha256(
    path: Path,
    label: str,
) -> tuple[dict[str, Any], str]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise ReleaseBuildError(f"missing retained compiler input: {path}") from exc
    except OSError as exc:
        raise ReleaseBuildError(
            f"unable to read retained compiler input {path}: {exc}"
        ) from exc
    try:
        value = require_dict(load_json_bytes(raw, path), label)
    except ReleaseBuildError as exc:
        raise ReleaseBuildError(
            f"invalid retained compiler input JSON in {path}: {exc}"
        ) from exc
    if ordered_json_bytes(value) != raw:
        raise ReleaseBuildError(f"{path} is not the exact ordered compiler-input encoding")
    return value, sha256_bytes(raw)


def load_retained_compiler_input(path: Path, label: str) -> dict[str, Any]:
    value, _ = load_retained_compiler_input_with_sha256(path, label)
    return value


def validate_target_artifact_data(
    repo_root: Path,
    artifact: dict[str, Any],
    target: dict[str, str],
    foundry_config_path: Path,
    compiler_input: dict[str, Any],
    *,
    solc_bin: Path | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    label = f"{target['source']}:{target['name']}"
    metadata = artifact_metadata(artifact, label)
    compiler = require_dict(metadata.get("compiler"), f"{label}.metadata.compiler")
    compiler_version = require_string(
        compiler.get("version"),
        f"{label}.metadata.compiler.version",
    )
    if compiler_version != SOLC_LONG_VERSION:
        raise ReleaseBuildError(
            f"{label} compiler version is {compiler_version!r}, expected {SOLC_LONG_VERSION!r}"
        )

    settings = require_dict(metadata.get("settings"), f"{label}.metadata.settings")
    compilation_target = require_dict(
        settings.get("compilationTarget"),
        f"{label}.metadata.settings.compilationTarget",
    )
    expected_target = {target["source"]: target["name"]}
    if compilation_target != expected_target:
        raise ReleaseBuildError(
            f"{label} compilation target is {compilation_target!r}, expected {expected_target!r}"
        )
    if settings.get("viaIR") is not True:
        raise ReleaseBuildError(f"{label} was not compiled via IR")
    if settings.get("evmVersion") != EVM_VERSION:
        raise ReleaseBuildError(
            f"{label} EVM version is {settings.get('evmVersion')!r}, expected {EVM_VERSION!r}"
        )

    optimizer = require_dict(settings.get("optimizer"), f"{label}.metadata.settings.optimizer")
    if optimizer.get("enabled") is not True or optimizer.get("runs") != OPTIMIZER_RUNS:
        raise ReleaseBuildError(
            f"{label} optimizer settings must be enabled with {OPTIMIZER_RUNS} runs"
        )
    metadata_settings = require_dict(
        settings.get("metadata"),
        f"{label}.metadata.settings.metadata",
    )
    if (
        metadata_settings.get("bytecodeHash") != "none"
        or metadata_settings.get("appendCBOR") is not False
    ):
        raise ReleaseBuildError(f"{label} metadata must disable bytecode hash and CBOR output")

    source_records = metadata_source_records(repo_root, metadata, label)
    source_paths = {record["path"] for record in source_records}
    if target["source"] not in source_paths:
        raise ReleaseBuildError(f"{label} metadata does not include its configured source")
    compiler_input_bindings = validate_compiler_input(
        repo_root,
        compiler_input,
        label,
    )
    compiler_sources = compiler_input_bindings["compiler_input_sources"]
    if [record["path"] for record in source_records] != sorted(
        record["path"] for record in compiler_sources
    ):
        raise ReleaseBuildError(
            f"{label} artifact metadata source set does not match build-info input"
        )
    metadata_by_path = {record["path"]: record for record in source_records}
    for compiler_source in compiler_sources:
        if metadata_by_path[compiler_source["path"]] != compiler_source:
            raise ReleaseBuildError(
                f"{label} artifact metadata source hash does not match build-info input "
                f"for {compiler_source['path']}"
            )

    normalized_argv = normalized_forge_argv(
        target["source"],
        normalize_path(foundry_config_path, repo_root),
        solc_bin=solc_bin,
    )
    source_universe = {
        record["path"]: record["sha256"]
        for record in source_records
    }
    bindings = {
        "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
        "forge_argv": normalized_argv,
        "metadata_sources": source_records,
        "canonical_source_universe_sha256": canonical_json_sha256(source_universe),
        "compiler_settings_sha256": canonical_json_sha256(settings),
        **compiler_input_bindings,
        "canonical_build_input_sha256": canonical_json_sha256(
            {
                "compiler_version": compiler_version,
                "compiler_input_canonical_sha256": compiler_input_bindings[
                    "compiler_input_canonical_sha256"
                ],
                "compiler_input_ordered_sha256": compiler_input_bindings[
                    "compiler_input_ordered_sha256"
                ],
                "forge_argv": normalized_argv,
                "forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
                "language": metadata.get("language", "Solidity"),
                "settings": settings,
                "source_universe": source_universe,
                "target": target,
            }
        ),
    }
    return artifact, bindings


def validate_target_artifact(
    repo_root: Path,
    artifact_path: Path,
    target: dict[str, str],
    foundry_config_path: Path,
    compiler_input: dict[str, Any],
    *,
    solc_bin: Path | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    artifact = require_dict(load_json(artifact_path), str(artifact_path))
    return validate_target_artifact_data(
        repo_root,
        artifact,
        target,
        foundry_config_path,
        compiler_input,
        solc_bin=solc_bin,
    )


def find_target_artifact(out_dir: Path, target: dict[str, str]) -> Path:
    direct = out_dir / Path(target["source"]).name / f"{target['name']}.json"
    if direct.is_file():
        return direct
    matches = sorted(out_dir.glob(f"**/{target['name']}.json"))
    if not matches:
        raise ReleaseBuildError(
            f"forge did not emit {target['source']}:{target['name']} under {out_dir}"
        )
    if len(matches) > 1:
        locations = ", ".join(str(path) for path in matches)
        raise ReleaseBuildError(
            f"forge emitted ambiguous artifacts for {target['name']}: {locations}"
        )
    return matches[0]


def forge_command(
    forge_bin: str,
    repo_root: Path,
    foundry_config_path: Path,
    source: str,
    out_dir: Path,
    cache_dir: Path,
    build_info_dir: Path,
    solc_bin: Path | None = None,
) -> list[str]:
    command = [
        forge_bin,
        "build",
        source,
        "--root",
        str(repo_root),
        "--config-path",
        str(foundry_config_path),
        "--out",
        str(out_dir),
        "--cache-path",
        str(cache_dir),
        "--build-info",
        "--build-info-path",
        str(build_info_dir),
        "--use",
        str(solc_bin) if solc_bin is not None else SOLC_VERSION,
        "--no-auto-detect",
    ]
    if solc_bin is not None:
        command.append("--offline")
    command.extend([
        "--evm-version",
        EVM_VERSION,
        "--optimize",
        "true",
        "--optimizer-runs",
        str(OPTIMIZER_RUNS),
        "--via-ir",
        "--use-literal-content",
        "--no-metadata",
        "--force",
        "--skip",
        "test",
        "--skip",
        "script",
    ])
    return command


def normalized_forge_argv(
    source: str,
    foundry_config: str,
    *,
    solc_bin: Path | None = None,
) -> list[str]:
    """Return the deterministic argv semantics retained in the build receipt."""
    command = [
        "forge",
        "build",
        source,
        "--root",
        ".",
        "--config-path",
        foundry_config,
        "--out",
        "<isolated-out>",
        "--cache-path",
        "<isolated-cache>",
        "--build-info",
        "--build-info-path",
        "<isolated-build-info>",
        "--use",
        str(solc_bin) if solc_bin is not None else SOLC_VERSION,
        "--no-auto-detect",
    ]
    if solc_bin is not None:
        command.append("--offline")
    command.extend([
        "--evm-version",
        EVM_VERSION,
        "--optimize",
        "true",
        "--optimizer-runs",
        str(OPTIMIZER_RUNS),
        "--via-ir",
        "--use-literal-content",
        "--no-metadata",
        "--force",
        "--skip",
        "test",
        "--skip",
        "script",
    ])
    return command


def sanitized_forge_environment() -> dict[str, str]:
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.upper().startswith(SANITIZED_ENVIRONMENT_PREFIXES)
    }
    environment.update(CONTROLLED_FORGE_ENVIRONMENT)
    return environment


def run_forge(
    command: list[str],
    cwd: Path,
    *,
    journal: ExecutionJournal | None = None,
    ordinal: int | None = None,
    phase: str = "forge_build",
    group_string: str | None = None,
) -> None:
    if journal is not None:
        if ordinal is None:
            raise EvidenceFailure("CALL_ORDINAL", "journaled Forge call requires an ordinal")
        journal.invoke(
            ordinal,
            command,
            cwd,
            phase=phase,
            group_string=group_string,
        )
        return
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=sanitized_forge_environment(),
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise ReleaseBuildError(
            f"{command[0]!r} was not found; install Foundry and ensure forge is on PATH"
        ) from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no compiler output"
        raise ReleaseBuildError(
            f"isolated forge build failed for {command[2]} with exit code "
            f"{result.returncode}: {detail}"
        )


R4ExecutionJournal.default_runner = run_forge


def normalize_forge_version(value: str) -> str:
    normalized = value.replace("\r\n", "\n").replace("\r", "\n").strip()
    if not normalized:
        raise ReleaseBuildError("forge --version returned empty output")
    return normalized


def validate_forge_version(value: str) -> str:
    normalized = normalize_forge_version(value)
    match = re.search(
        r"^forge Version:\s+(\d+\.\d+\.\d+)(?:\s|$)",
        normalized,
        flags=re.MULTILINE,
    )
    if match is None:
        raise ReleaseBuildError("forge --version output does not contain a semantic version")
    actual = match.group(1)
    if actual != FOUNDRY_VERSION:
        raise ReleaseBuildError(
            f"Foundry version is {actual}, expected pinned {FOUNDRY_VERSION}"
        )
    portable, timestamp_count = FORGE_BUILD_TIMESTAMP_RE.subn(
        PORTABLE_FORGE_BUILD_TIMESTAMP,
        normalized,
    )
    if timestamp_count != 1:
        raise ReleaseBuildError(
            "forge --version output must contain exactly one Build Timestamp line"
        )
    return portable


def read_forge_version(
    forge_bin: str,
    repo_root: Path,
    *,
    journal: ExecutionJournal | None = None,
) -> str:
    if journal is not None:
        result = journal.invoke(
            0,
            [forge_bin, "--version"],
            repo_root,
            phase="forge_version",
            group_string=None,
        )
        return validate_forge_version(result.stdout)
    try:
        result = subprocess.run(
            [forge_bin, "--version"],
            cwd=repo_root,
            env=sanitized_forge_environment(),
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except FileNotFoundError as exc:
        raise ReleaseBuildError(
            f"{forge_bin!r} was not found; install Foundry and ensure forge is on PATH"
        ) from exc
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no version output"
        raise ReleaseBuildError(
            f"forge --version failed with exit code {result.returncode}: {detail}"
        )
    return validate_forge_version(result.stdout)


def build_policy(forge_version: str) -> dict[str, Any]:
    forge_version = validate_forge_version(forge_version)
    return {
        "compilation_unit": "one_configured_target_source_and_its_import_closure",
        "restricted_source_roots": sorted(RESTRICTED_RELEASE_SOURCE_ROOTS),
        "portable_compiler_paths": PORTABLE_COMPILER_PATHS,
        "solc_version": SOLC_VERSION,
        "solc_long_version": SOLC_LONG_VERSION,
        "evm_version": EVM_VERSION,
        "optimizer_enabled": True,
        "optimizer_runs": OPTIMIZER_RUNS,
        "via_ir": True,
        "bytecode_hash": "none",
        "cbor_metadata": False,
        "controlled_forge_environment": CONTROLLED_FORGE_ENVIRONMENT,
        "forge_profile": "default",
        "foundry_version": FOUNDRY_VERSION,
        "forge_version": forge_version,
        "forge_version_sha256": sha256_bytes(forge_version.encode("utf-8")),
        "sanitized_environment_prefixes": list(SANITIZED_ENVIRONMENT_PREFIXES),
    }


def build_manifest(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    targets: list[dict[str, Any]],
    forge_version: str,
    *,
    config_sha256: str | None = None,
    foundry_config_sha256: str | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": RELEASE_BUILD_SCHEMA,
        "generated_by": f"scripts/build_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_path(config_path, repo_root),
            "config_sha256": (
                config_sha256
                if config_sha256 is not None
                else file_sha256(config_path)
            ),
            "foundry_config": normalize_path(foundry_config_path, repo_root),
            "foundry_config_sha256": (
                foundry_config_sha256
                if foundry_config_sha256 is not None
                else file_sha256(foundry_config_path)
            ),
        },
        "policy": build_policy(forge_version),
        "output_dir": normalize_path(output_dir, repo_root),
        "targets": targets,
    }


def expected_target_identity(targets: list[dict[str, str]]) -> list[tuple[str, str, str]]:
    return [(target["kind"], target["name"], target["source"]) for target in targets]


def validate_manifest_source_binding_consistency(
    repo_root: Path,
    records: list[Any],
    manifest_path: Path,
) -> None:
    """Require one immutable source identity across every receipt target."""
    bindings: dict[str, tuple[str, str]] = {}
    binding_locations: dict[str, str] = {}
    binding_paths: dict[str, str] = {}
    for target_index, value in enumerate(records):
        record = require_dict(value, f"{manifest_path}.targets[{target_index}]")
        target_label = (
            f"targets[{target_index}] "
            f"{record.get('kind')}:{record.get('source')}:{record.get('name')}"
        )
        for field in ("metadata_sources", "compiler_input_sources"):
            source_records = require_list(
                record.get(field),
                f"{target_label}.{field}",
            )
            local_paths: set[str] = set()
            for source_index, source_value in enumerate(source_records):
                location = f"{target_label}.{field}[{source_index}]"
                source_record = require_dict(source_value, location)
                source_path = require_string(
                    source_record.get("path"),
                    f"{location}.path",
                )
                if source_path in local_paths:
                    raise ReleaseBuildError(
                        f"{target_label}.{field} contains duplicate source path "
                        f"{source_path}"
                    )
                local_paths.add(source_path)
                resolved_source = resolve_repo_path(
                    repo_root,
                    Path(source_path),
                    f"{location}.path",
                )
                canonical_source_path = normalize_path(
                    resolved_source,
                    repo_root,
                )
                if source_path != canonical_source_path:
                    raise ReleaseBuildError(
                        f"{location}.path must use canonical repository spelling "
                        f"{canonical_source_path!r}, got {source_path!r}"
                    )
                binding_key = (
                    canonical_source_path.casefold()
                    if os.name == "nt"
                    else canonical_source_path
                )
                existing_path = binding_paths.get(binding_key)
                if (
                    existing_path is not None
                    and existing_path != canonical_source_path
                ):
                    raise ReleaseBuildError(
                        "release build receipt has case-aliased source paths "
                        f"{existing_path!r} and {canonical_source_path!r}"
                    )
                identity = (
                    require_string(
                        source_record.get("sha256"),
                        f"{location}.sha256",
                    ),
                    require_string(
                        source_record.get("keccak256"),
                        f"{location}.keccak256",
                    ).lower(),
                )
                existing = bindings.get(binding_key)
                if existing is not None and existing != identity:
                    raise ReleaseBuildError(
                        "release build receipt has conflicting source bindings for "
                        f"{canonical_source_path}: "
                        f"{binding_locations[binding_key]} records "
                        f"{existing!r}, while {location} records {identity!r}"
                    )
                bindings[binding_key] = identity
                binding_paths.setdefault(binding_key, canonical_source_path)
                binding_locations.setdefault(binding_key, location)


def validate_release_output_with_snapshots(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    *,
    declared_output_dir: Path | None = None,
    expected_forge_version: str | None = None,
    solc_bin: Path | None = None,
) -> ValidatedReleaseOutput:
    repo_root = repo_root.resolve()
    config_path = resolve_repo_path(repo_root, config_path, "contract config")
    foundry_config_path = resolve_repo_path(
        repo_root,
        foundry_config_path,
        "Foundry config",
    )
    if declared_output_dir is None:
        output_dir = resolve_canonical_output_path(repo_root, output_dir)
        declared = output_dir
    else:
        declared = resolve_canonical_output_path(repo_root, declared_output_dir)
        output_dir = resolve_repo_path(
            repo_root,
            output_dir,
            "staged release output directory",
        )
        staged_relative = output_dir.relative_to(repo_root)
        if (
            len(staged_relative.parts) != 2
            or not staged_relative.parts[0].startswith(".release-build-")
            or staged_relative.parts[1] != "aggregate"
        ):
            raise ReleaseBuildError(
                "staged release output must be a build-owned .release-build-*/aggregate directory"
            )

    config_raw = read_required_bytes(config_path)
    config_sha256 = sha256_bytes(config_raw)
    config = require_dict(load_json_bytes(config_raw, config_path), str(config_path))
    configured = configured_targets_from_config(repo_root, config_path, config)

    foundry_config_raw = read_required_bytes(foundry_config_path)
    foundry_config_sha256 = sha256_bytes(foundry_config_raw)
    foundry_profile = load_foundry_profile_bytes(
        foundry_config_raw,
        foundry_config_path,
    )
    validate_foundry_profile_data(foundry_profile)
    manifest_path = resolve_repo_path(
        repo_root,
        output_dir / MANIFEST_FILENAME,
        "release build receipt",
    )
    manifest_value, manifest_raw, manifest_sha256 = load_json_snapshot(
        manifest_path
    )
    manifest = require_dict(manifest_value, str(manifest_path))
    if manifest.get("schema_version") != RELEASE_BUILD_SCHEMA:
        raise ReleaseBuildError(
            f"{manifest_path} schema must be {RELEASE_BUILD_SCHEMA!r}"
        )
    if manifest.get("generated_by") != (
        f"scripts/build_release_artifacts.py:{GENERATOR_VERSION}"
    ):
        raise ReleaseBuildError(f"{manifest_path} generator identity is invalid")

    source = require_dict(manifest.get("source"), f"{manifest_path}.source")
    if source.get("config") != normalize_path(config_path, repo_root):
        raise ReleaseBuildError(f"{manifest_path} config path is stale")
    if source.get("config_sha256") != config_sha256:
        raise ReleaseBuildError(f"{manifest_path} config hash is stale")
    if source.get("foundry_config") != normalize_path(foundry_config_path, repo_root):
        raise ReleaseBuildError(f"{manifest_path} foundry config path is stale")
    if source.get("foundry_config_sha256") != foundry_config_sha256:
        raise ReleaseBuildError(f"{manifest_path} foundry config hash is stale")
    if manifest.get("output_dir") != normalize_path(declared, repo_root):
        raise ReleaseBuildError(f"{manifest_path} output directory is stale")

    policy = require_dict(manifest.get("policy"), f"{manifest_path}.policy")
    recorded_forge_version = require_string(
        policy.get("forge_version"),
        f"{manifest_path}.policy.forge_version",
    )
    if recorded_forge_version != validate_forge_version(recorded_forge_version):
        raise ReleaseBuildError(
            f"{manifest_path} Forge version identity is not portable"
        )
    if policy.get("forge_version_sha256") != sha256_bytes(
        recorded_forge_version.encode("utf-8")
    ):
        raise ReleaseBuildError(f"{manifest_path} forge version hash is stale")
    if (
        expected_forge_version is not None
        and recorded_forge_version != validate_forge_version(expected_forge_version)
    ):
        raise ReleaseBuildError(
            f"{manifest_path} was built by a different Forge version"
        )
    expected_policy = build_policy(recorded_forge_version)
    if policy != expected_policy:
        raise ReleaseBuildError(f"{manifest_path} compiler policy is stale")

    records = require_list(manifest.get("targets"), f"{manifest_path}.targets")
    validate_manifest_source_binding_consistency(repo_root, records, manifest_path)
    record_identity = []
    expected_files = {Path(MANIFEST_FILENAME)}
    compiler_input_snapshots: dict[Path, tuple[dict[str, Any], str]] = {}
    artifact_snapshots: list[ReleaseFileSnapshot] = []
    for index, value in enumerate(records):
        record = require_dict(value, f"{manifest_path}.targets[{index}]")
        target = {
            "kind": require_string(record.get("kind"), f"targets[{index}].kind"),
            "name": require_string(record.get("name"), f"targets[{index}].name"),
            "source": require_string(record.get("source"), f"targets[{index}].source"),
        }
        record_identity.append((target["kind"], target["name"], target["source"]))
        relative_artifact = Path(
            require_string(
                record.get("artifact_relative_path"),
                f"targets[{index}].artifact_relative_path",
            )
        )
        if relative_artifact.is_absolute() or ".." in relative_artifact.parts:
            raise ReleaseBuildError(f"targets[{index}] artifact path is unsafe")
        expected_artifact_path = declared / relative_artifact
        if record.get("artifact_path") != normalize_path(expected_artifact_path, repo_root):
            raise ReleaseBuildError(f"targets[{index}] artifact path is stale")
        actual_artifact_path = resolve_repo_path(
            repo_root,
            output_dir / relative_artifact,
            f"targets[{index}] artifact",
        )
        expected_files.add(relative_artifact)

        relative_compiler_input = Path(
            require_string(
                record.get("compiler_input_relative_path"),
                f"targets[{index}].compiler_input_relative_path",
            )
        )
        if relative_compiler_input.is_absolute() or ".." in relative_compiler_input.parts:
            raise ReleaseBuildError(f"targets[{index}] compiler input path is unsafe")
        expected_compiler_input_path = declared / relative_compiler_input
        if record.get("compiler_input_path") != normalize_path(
            expected_compiler_input_path,
            repo_root,
        ):
            raise ReleaseBuildError(f"targets[{index}] compiler input path is stale")
        actual_compiler_input_path = resolve_repo_path(
            repo_root,
            output_dir / relative_compiler_input,
            f"targets[{index}] compiler input",
        )
        expected_files.add(relative_compiler_input)
        compiler_input_snapshot = compiler_input_snapshots.get(
            actual_compiler_input_path
        )
        if compiler_input_snapshot is None:
            compiler_input_snapshot = load_retained_compiler_input_with_sha256(
                actual_compiler_input_path,
                f"targets[{index}].compiler_input",
            )
            compiler_input_snapshots[actual_compiler_input_path] = compiler_input_snapshot
        compiler_input, compiler_input_sha256 = compiler_input_snapshot
        if record.get("compiler_input_sha256") != compiler_input_sha256:
            raise ReleaseBuildError(f"targets[{index}] compiler input hash is stale")

        artifact_value, artifact_raw, artifact_sha256 = load_json_snapshot(
            actual_artifact_path
        )
        artifact_snapshots.append(
            ReleaseFileSnapshot(
                path=actual_artifact_path,
                raw=artifact_raw,
                sha256=artifact_sha256,
            )
        )
        artifact = require_dict(artifact_value, str(actual_artifact_path))
        _, bindings = validate_target_artifact_data(
            repo_root,
            artifact,
            target,
            foundry_config_path,
            compiler_input,
            solc_bin=solc_bin,
        )
        if record.get("artifact_sha256") != artifact_sha256:
            raise ReleaseBuildError(f"targets[{index}] artifact hash is stale")
        for binding_name, expected_value in bindings.items():
            if record.get(binding_name) != expected_value:
                raise ReleaseBuildError(
                    f"targets[{index}] {binding_name.replace('_', ' ')} is stale"
                )

    if record_identity != expected_target_identity(configured):
        raise ReleaseBuildError(f"{manifest_path} configured target set is stale")

    output_entries = list(output_dir.rglob("*"))
    for path in output_entries:
        reject_link_or_reparse_components(
            repo_root,
            path,
            "release output entry",
        )
    actual_files = {
        path.relative_to(output_dir)
        for path in output_entries
        if path.is_file()
    }
    if actual_files != expected_files:
        missing = sorted(expected_files - actual_files)
        extra = sorted(actual_files - expected_files)
        details = [f"missing {path.as_posix()}" for path in missing]
        details.extend(f"unexpected {path.as_posix()}" for path in extra)
        raise ReleaseBuildError(
            f"{output_dir} does not contain the exact configured artifact set: "
            + ", ".join(details)
        )
    return ValidatedReleaseOutput(
        receipt=manifest,
        receipt_snapshot=ReleaseFileSnapshot(
            path=manifest_path,
            raw=manifest_raw,
            sha256=manifest_sha256,
        ),
        config_snapshot=ReleaseFileSnapshot(
            path=config_path,
            raw=config_raw,
            sha256=config_sha256,
        ),
        foundry_config_snapshot=ReleaseFileSnapshot(
            path=foundry_config_path,
            raw=foundry_config_raw,
            sha256=foundry_config_sha256,
        ),
        artifact_snapshots=tuple(artifact_snapshots),
    )


def validate_release_output(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    *,
    declared_output_dir: Path | None = None,
    expected_forge_version: str | None = None,
    solc_bin: Path | None = None,
) -> dict[str, Any]:
    """Validate canonical output while preserving the legacy receipt API."""
    return validate_release_output_with_snapshots(
        repo_root,
        config_path,
        foundry_config_path,
        output_dir,
        declared_output_dir=declared_output_dir,
        expected_forge_version=expected_forge_version,
        solc_bin=solc_bin,
    ).receipt


def replace_output_directory(staged: Path, output_dir: Path, temp_root: Path) -> None:
    if path_is_link_or_reparse(output_dir) or (
        output_dir.exists() and not output_dir.is_dir()
    ):
        raise ReleaseBuildError(
            f"release output must be a non-link, non-reparse directory: {output_dir}"
        )
    previous = temp_root / "previous-release-output"
    had_previous = output_dir.exists()
    try:
        if had_previous:
            os.replace(output_dir, previous)
        os.replace(staged, output_dir)
    except BaseException:
        if had_previous and previous.exists() and not output_dir.exists():
            try:
                os.replace(previous, output_dir)
            except BaseException as rollback_error:
                raise ReleaseBuildError(
                    "release output replacement failed and the previous output "
                    "could not be restored"
                ) from rollback_error
        raise
    if previous.exists():
        shutil.rmtree(previous)


def _path_is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def _receipt_with_kind(receipt: dict[str, Any], kind: str) -> dict[str, Any]:
    return {**receipt, "kind": kind}


def _prepare_evidence_run(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: Path,
    solc_bin: Path,
    evidence_dir: Path,
) -> tuple[WindowsDirectoryLock, Path, Path, dict[str, Any], str]:
    validate_r4_authority_constants()
    evidence = validate_absolute_ordinary_path(
        evidence_dir,
        "evidence directory",
        directory=True,
    )
    if _path_is_within(evidence, repo_root):
        raise EvidenceFailure("EVIDENCE_INSIDE_ROOT", "evidence directory must be outside repo root")
    for variable in ("TEMP", "TMP"):
        value = os.environ.get(variable)
        if value:
            try:
                temp_root = Path(value).resolve(strict=True)
            except OSError:
                continue
            if _path_is_within(evidence, temp_root) or _path_is_within(temp_root, evidence):
                raise EvidenceFailure(
                    "EVIDENCE_TEMP_ALIAS",
                    f"evidence directory must be distinct from {variable}",
                )
    if any(evidence.iterdir()):
        raise EvidenceFailure("EVIDENCE_NOT_EMPTY", "evidence directory must initially be empty")
    if output_dir.exists() or path_is_link_or_reparse(output_dir):
        raise EvidenceFailure(
            "OUTPUT_ALREADY_EXISTS",
            "authoritative out-release must be absent before STARTED",
        )
    if not output_dir.parent.is_dir():
        raise EvidenceFailure("OUTPUT_PARENT_MISSING", "authoritative output parent is missing")
    forge = validate_absolute_ordinary_path(forge_bin, "Forge executable", directory=False)
    solc = validate_absolute_ordinary_path(solc_bin, "Solc executable", directory=False)
    config_raw = read_required_bytes(config_path)
    foundry_raw = read_required_bytes(foundry_config_path)
    if hashlib.sha256(config_raw).hexdigest().upper() != R4_TARGET_CONFIG_SHA256:
        raise EvidenceFailure("TARGET_CONFIG_AUTHORITY", "target config is not exact 84B3")
    if hashlib.sha256(foundry_raw).hexdigest().upper() != R4_FOUNDRY_CONFIG_SHA256:
        raise EvidenceFailure("FOUNDRY_CONFIG_AUTHORITY", "foundry config is not exact C356")

    source_paths = sorted(
        {path for group in R4_GROUPS for path in group["sources"]},
        key=str.casefold,
    )
    source_records = []
    for relative in source_paths:
        source_path = resolve_repo_path(repo_root, Path(relative), "R4 source authority")
        raw = read_required_bytes(source_path)
        source_records.append(
            {
                "path": relative,
                "sha256": sha256_bytes(raw),
                "byte_count": len(raw),
            }
        )
    aggregate = _source_closure_aggregate(source_records)
    if len(source_records) != 31 or aggregate != R4_SOURCE_AGGREGATE_SHA256:
        raise EvidenceFailure(
            "SOURCE_AUTHORITY",
            "compiler root does not contain exact 31-file 1EB0 source authority",
            operands={"count": len(source_records), "aggregate_sha256": aggregate},
        )

    builder_path = Path(__file__).resolve()
    test_path = builder_path.with_name("test_release_build_artifacts.py")
    static_receipts: dict[str, Any] = {
        "builder": _receipt_with_kind(windows_file_receipt(builder_path, "builder"), "file"),
        "test": _receipt_with_kind(windows_file_receipt(test_path, "builder test"), "file"),
        "config": _receipt_with_kind(windows_file_receipt(config_path, "target config"), "file"),
        "foundry_config": _receipt_with_kind(windows_file_receipt(foundry_config_path, "Foundry config"), "file"),
        "forge": _receipt_with_kind(windows_file_receipt(forge, "Forge executable"), "file"),
        "solc": _receipt_with_kind(windows_file_receipt(solc, "Solc executable"), "file"),
        "repo_root": _receipt_with_kind(windows_file_receipt(repo_root, "repo root", directory=True), "directory"),
        "evidence_dir": _receipt_with_kind(windows_file_receipt(evidence, "evidence directory", directory=True), "directory"),
        "output_dir": {
            "path": str(output_dir),
            "identity": None,
            "byte_count": None,
            "sha256": None,
            "kind": "directory",
            "initial_status": "absent",
        },
        "source_aggregate": {
            "path": str(repo_root / "smart-contracts"),
            "identity": r4_windows_path_identity(repo_root / "smart-contracts", directory=True),
            "byte_count": sum(record["byte_count"] for record in source_records),
            "sha256": "sha256:" + R4_SOURCE_AGGREGATE_SHA256.lower(),
            "kind": "directory",
            "source_count": 31,
        },
    }
    for record in source_records:
        source_path = repo_root / record["path"]
        static_receipts[f"source:{record['path']}"] = _receipt_with_kind(
            windows_file_receipt(source_path, record["path"]),
            "file",
        )
    lock = WindowsDirectoryLock.acquire(evidence)
    if any(evidence.iterdir()):
        raise EvidenceFailure(
            "EVIDENCE_CHANGED_BEFORE_STARTED",
            "evidence directory changed before STARTED publication",
        )
    invocation_domain = {
        "builder": static_receipts["builder"],
        "test": static_receipts["test"],
        "source_aggregate_sha256": R4_SOURCE_AGGREGATE_SHA256,
        "foundry_config_sha256": R4_FOUNDRY_CONFIG_SHA256,
        "target_config_sha256": R4_TARGET_CONFIG_SHA256,
        "group_map_sha256": R4_GROUP_MAP_SHA256,
        "constructor_map_sha256": R4_CONSTRUCTOR_MAP_SHA256,
        "forge": static_receipts["forge"],
        "solc": static_receipts["solc"],
        "repo_root": static_receipts["repo_root"],
        "output_dir": static_receipts["output_dir"],
        "evidence_dir": static_receipts["evidence_dir"],
    }
    invocation_id = sha256_bytes(canonical_evidence_bytes(invocation_domain))
    return lock, forge, solc, static_receipts, invocation_id


def _first_red(exc: BaseException) -> dict[str, Any]:
    if isinstance(exc, EvidenceFailure):
        return {"code": exc.code, "operands": exc.operands}
    raise exc


def _validate_installed_output_evidence(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_version: str,
    solc_bin: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    try:
        files = _snapshot_output_files(output_dir)
    except BaseException as exc:
        raise EvidenceFailure(
            "OP_INSTALLED_OUTPUT_READ_EXCEPTION",
            f"unable to read installed output: {type(exc).__name__}",
        ) from exc
    if len(files) != R4_SUCCESS_OUTPUT_FILE_COUNT:
        raise EvidenceFailure(
            "OUTPUT_TOPOLOGY_MISMATCH",
            "installed output is not exactly 37 files",
            operands={"file_count": len(files)},
        )
    try:
        manifest = validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            expected_forge_version=forge_version,
            solc_bin=solc_bin,
        )
    except BaseException as exc:
        raise EvidenceFailure(
            "OUTPUT_BYTES_MISMATCH",
            f"installed output validation failed: {type(exc).__name__}",
        ) from exc
    return manifest, files


def _build_release_output_evidence(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: Path,
    solc_bin: Path,
    evidence_dir: Path,
    runner: CommandRunner,
) -> dict[str, Any]:
    _, forge, solc, static_receipts, invocation_id = _prepare_evidence_run(
        repo_root,
        config_path,
        foundry_config_path,
        output_dir,
        forge_bin,
        solc_bin,
        evidence_dir,
    )
    journal = ExecutionJournal(
        Path(static_receipts["evidence_dir"]["path"]),
        invocation_id,
        static_receipts,
        forge,
        solc,
    )
    journal.publish_started()
    results: dict[str, Any] = {
        "groups": [],
        "artifacts": [],
        "aggregates": [],
        "output_files": [],
    }
    temp_root: Path | None = None
    output_installed = False
    publishing_go = False
    try:
        forge_version = read_forge_version(str(forge), repo_root, journal=journal)
        temp_root = Path(tempfile.mkdtemp(prefix=".release-build-", dir=repo_root))
        staged = temp_root / "aggregate"
        staged.mkdir()
        records = []
        admitted_artifacts: dict[str, dict[str, Any]] = {}
        targets_by_source: dict[str, list[dict[str, str]]] = {}
        config_raw = read_required_bytes(config_path)
        config_sha256 = sha256_bytes(config_raw)
        config = require_dict(load_json_bytes(config_raw, config_path), str(config_path))
        targets = configured_targets_from_config(repo_root, config_path, config)
        foundry_config_raw = read_required_bytes(foundry_config_path)
        foundry_config_sha256 = sha256_bytes(foundry_config_raw)
        foundry_profile = load_foundry_profile_bytes(foundry_config_raw, foundry_config_path)
        validate_foundry_profile_data(foundry_profile)
        expected_targets = {
            ("production_contract", item["target"], item["source"])
            for item in R4_TARGET_AUTHORITIES
        }
        if set(expected_target_identity(targets)) != expected_targets:
            raise EvidenceFailure("TARGET_SET_MISMATCH", "configured target set is not exact 19-target authority")
        for target in targets:
            targets_by_source.setdefault(target["source"], []).append(target)
        source_groups = sorted(targets_by_source.items())
        if [source for source, _ in source_groups] != [group["source"] for group in R4_GROUPS]:
            raise EvidenceFailure("GROUP_ORDER_MISMATCH", "configured emitting group order is not exact 000-016")

        for source_index, (source, source_targets) in enumerate(source_groups):
            target_root = temp_root / "targets" / f"{source_index:03d}-{Path(source).stem}"
            target_out = target_root / "out"
            target_cache = target_root / "cache"
            target_build_info = target_root / "build-info"
            command = forge_command(
                str(forge),
                repo_root,
                foundry_config_path,
                source,
                target_out,
                target_cache,
                target_build_info,
                solc_bin=solc,
            )
            group_authority = validate_evidence_group_string(
                source_index,
                R4_GROUPS[source_index]["group_string"],
            )
            journal.invoke(
                source_index + 1,
                command,
                repo_root,
                phase="forge_build",
                group_string=group_authority["group_string"],
                runner=runner,
            )
            raw_compiler_input = load_build_info_input(target_build_info, source)
            group_receipt = validate_evidence_group_closure(
                source_index,
                source,
                raw_compiler_input,
            )
            results["groups"].append(group_receipt)
            compiler_input = canonicalize_build_info_compiler_paths(
                repo_root,
                raw_compiler_input,
                source,
            )
            validate_compiler_input(repo_root, compiler_input, source)
            compiler_input_relative = Path("compiler-inputs") / f"{source_index:03d}-{Path(source).stem}.json"
            compiler_input_destination = staged / compiler_input_relative
            compiler_input_destination.parent.mkdir(parents=True, exist_ok=True)
            compiler_input_bytes = ordered_json_bytes(compiler_input)
            compiler_input_sha256 = sha256_bytes(compiler_input_bytes)
            write_exact_bytes(compiler_input_destination, compiler_input_bytes, "retained compiler input")
            for target in source_targets:
                artifact_path = find_target_artifact(target_out, target)
                artifact_value, artifact_bytes, artifact_sha256 = load_json_snapshot(artifact_path)
                artifact_data = require_dict(artifact_value, str(artifact_path))
                _, bindings = validate_target_artifact_data(
                    repo_root,
                    artifact_data,
                    target,
                    foundry_config_path,
                    compiler_input,
                    solc_bin=solc,
                )
                admitted_artifacts[target["name"]] = artifact_data
                relative_artifact = Path(Path(target["source"]).name) / f"{target['name']}.json"
                destination = staged / relative_artifact
                if destination.exists():
                    raise EvidenceFailure("ARTIFACT_PATH_COLLISION", f"target collision at {relative_artifact.as_posix()}")
                destination.parent.mkdir(parents=True, exist_ok=True)
                write_exact_bytes(destination, artifact_bytes, "release artifact")
                records.append(
                    {
                        **target,
                        "artifact_path": normalize_path(output_dir / relative_artifact, repo_root),
                        "artifact_relative_path": relative_artifact.as_posix(),
                        "artifact_sha256": artifact_sha256,
                        "compiler_input_path": normalize_path(output_dir / compiler_input_relative, repo_root),
                        "compiler_input_relative_path": compiler_input_relative.as_posix(),
                        "compiler_input_sha256": compiler_input_sha256,
                        **bindings,
                    }
                )

        results["source_union"] = validate_evidence_source_union(results["groups"])
        measurements: dict[str, dict[str, Any]] = {}
        for gate_index, authority in enumerate(R4_TARGET_AUTHORITIES, start=1):
            artifact = admitted_artifacts.get(authority["target"])
            if artifact is None:
                raise EvidenceFailure("ARTIFACT_ADMISSION_MISSING", f"missing admitted artifact {authority['target']}")
            measurement = r4_validate_ordered_bytecode(artifact, authority)
            measurements[authority["semantic_id"]] = measurement
            results["artifacts"].append(measurement)
            if gate_index in R4_AGGREGATE_GATES:
                results["aggregates"].extend(
                    _evaluate_aggregate_gate(
                        gate_index,
                        measurements,
                        lambda actual, threshold: actual <= threshold,
                        None,
                    )
                )
        records.sort(key=lambda item: (item["kind"], item["name"], item["source"]))
        manifest = build_manifest(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            records,
            forge_version,
            config_sha256=config_sha256,
            foundry_config_sha256=foundry_config_sha256,
        )
        write_json(staged / MANIFEST_FILENAME, manifest)
        validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            staged,
            declared_output_dir=output_dir,
            expected_forge_version=forge_version,
            solc_bin=solc,
        )
        try:
            install_output_no_replace(staged, output_dir)
        except BaseException as exc:
            raise EvidenceFailure(
                "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION",
                f"output installation failed: {type(exc).__name__}",
            ) from exc
        output_installed = True
        try:
            shutil.rmtree(temp_root)
            temp_root = None
        except BaseException as exc:
            raise EvidenceFailure(
                "OP_BUILD_TEMP_CLEANUP_EXCEPTION",
                f"build temporary cleanup failed: {type(exc).__name__}",
            ) from exc
        installed_manifest, output_files = _validate_installed_output_evidence(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            forge_version,
            solc,
        )
        results["output_files"] = output_files
        results["output_installed"] = True
        results["output_quarantine_without_matching_go"] = True
        publishing_go = True
        journal.publish_terminal("GO", None, results=results)
        return installed_manifest
    except BaseException as exc:
        if publishing_go:
            raise EvidenceFailure(
                "OP_TERMINAL_GO_PUBLISH_EXCEPTION",
                f"terminal GO publication failed: {type(exc).__name__}",
                operands={"output_installed": output_installed},
            ) from exc
        results["output_installed"] = output_installed
        results["temporary_root"] = str(temp_root) if temp_root is not None else None
        try:
            journal.publish_terminal(
                "NO_GO",
                _first_red(exc),
                results=results,
            )
        except BaseException:
            pass
        raise


def build_release_output(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
    forge_bin: str = "forge",
    runner: CommandRunner = run_forge,
    forge_version_output: str | None = None,
    *,
    solc_bin: Path | None = None,
    evidence_dir: Path | None = None,
) -> dict[str, Any]:
    if (solc_bin is None) != (evidence_dir is None):
        raise EvidenceFailure(
            "PAIRED_EVIDENCE_ARGUMENTS",
            "--solc-bin and --evidence-dir must be supplied together",
        )
    if solc_bin is not None and evidence_dir is not None:
        if runner is not run_forge:
            raise EvidenceFailure(
                "EVIDENCE_RUNNER_INJECTION_FORBIDDEN",
                "authoritative evidence mode owns every child-process invocation",
            )
        if os.name != "nt":
            raise EvidenceFailure(
                "NON_WINDOWS_EVIDENCE_MODE",
                "authoritative evidence mode requires canonical Windows",
            )
        if forge_version_output is not None:
            raise EvidenceFailure(
                "FORGE_VERSION_INJECTION_FORBIDDEN",
                "authoritative evidence mode must directly invoke Forge --version",
            )
        lexical_repo = Path(str(repo_root))
        if not lexical_repo.is_absolute():
            raise EvidenceFailure(
                "PATH_NOT_LOCAL_DRIVE_ABSOLUTE",
                "authoritative repository root must already be absolute",
            )

        def lexical_repo_child(value: Path) -> Path:
            return value if value.is_absolute() else Path(
                str(lexical_repo).rstrip("\\") + "\\" + str(value).replace("/", "\\")
            )

        return _build_release_output_evidence_r11(
            lexical_repo,
            lexical_repo_child(config_path),
            lexical_repo_child(foundry_config_path),
            lexical_repo_child(output_dir),
            Path(forge_bin),
            solc_bin,
            evidence_dir,
        )
    repo_root = repo_root.resolve()
    config_path = resolve_repo_path(repo_root, config_path, "contract config")
    foundry_config_path = resolve_repo_path(
        repo_root,
        foundry_config_path,
        "Foundry config",
    )
    output_dir = resolve_canonical_output_path(repo_root, output_dir)
    output_dir.parent.mkdir(parents=True, exist_ok=True)

    config_raw = read_required_bytes(config_path)
    config_sha256 = sha256_bytes(config_raw)
    config = require_dict(load_json_bytes(config_raw, config_path), str(config_path))
    targets = configured_targets_from_config(repo_root, config_path, config)

    foundry_config_raw = read_required_bytes(foundry_config_path)
    foundry_config_sha256 = sha256_bytes(foundry_config_raw)
    foundry_profile = load_foundry_profile_bytes(
        foundry_config_raw,
        foundry_config_path,
    )
    validate_foundry_profile_data(foundry_profile)
    forge_version = (
        validate_forge_version(forge_version_output)
        if forge_version_output is not None
        else read_forge_version(forge_bin, repo_root)
    )
    with tempfile.TemporaryDirectory(prefix=".release-build-", dir=repo_root) as temp:
        temp_root = Path(temp)
        staged = temp_root / "aggregate"
        staged.mkdir()
        records = []
        targets_by_source: dict[str, list[dict[str, str]]] = {}
        for target in targets:
            targets_by_source.setdefault(target["source"], []).append(target)
        source_groups = sorted(targets_by_source.items())
        for source_index, (source, source_targets) in enumerate(source_groups):
            target_root = (
                temp_root
                / "targets"
                / f"{source_index:03d}-{Path(source).stem}"
            )
            target_out = target_root / "out"
            target_cache = target_root / "cache"
            target_build_info = target_root / "build-info"
            print(
                f"[{source_index + 1}/{len(source_groups)}] building "
                f"{source} ({len(source_targets)} configured target"
                f"{'s' if len(source_targets) != 1 else ''})",
                flush=True,
            )
            runner(
                forge_command(
                    forge_bin,
                    repo_root,
                    foundry_config_path,
                    source,
                    target_out,
                    target_cache,
                    target_build_info,
                ),
                repo_root,
            )
            raw_compiler_input = load_build_info_input(
                target_build_info,
                source,
            )
            compiler_input = canonicalize_build_info_compiler_paths(
                repo_root,
                raw_compiler_input,
                source,
            )
            validate_compiler_input(
                repo_root,
                compiler_input,
                source,
            )
            compiler_input_relative = (
                Path("compiler-inputs")
                / f"{source_index:03d}-{Path(source).stem}.json"
            )
            compiler_input_destination = staged / compiler_input_relative
            compiler_input_destination.parent.mkdir(parents=True, exist_ok=True)
            compiler_input_bytes = ordered_json_bytes(compiler_input)
            compiler_input_sha256 = sha256_bytes(compiler_input_bytes)
            write_exact_bytes(
                compiler_input_destination,
                compiler_input_bytes,
                "retained compiler input",
            )
            for target in source_targets:
                artifact_path = find_target_artifact(target_out, target)
                artifact_value, artifact_bytes, artifact_sha256 = load_json_snapshot(
                    artifact_path
                )
                artifact_data = require_dict(artifact_value, str(artifact_path))
                _, bindings = validate_target_artifact_data(
                    repo_root,
                    artifact_data,
                    target,
                    foundry_config_path,
                    compiler_input,
                )
                relative_artifact = (
                    Path(Path(target["source"]).name) / f"{target['name']}.json"
                )
                destination = staged / relative_artifact
                if destination.exists():
                    raise ReleaseBuildError(
                        f"configured targets collide at {relative_artifact.as_posix()}"
                    )
                destination.parent.mkdir(parents=True, exist_ok=True)
                write_exact_bytes(destination, artifact_bytes, "release artifact")
                records.append(
                    {
                        **target,
                        "artifact_path": normalize_path(
                            output_dir / relative_artifact,
                            repo_root,
                        ),
                        "artifact_relative_path": relative_artifact.as_posix(),
                        "artifact_sha256": artifact_sha256,
                        "compiler_input_path": normalize_path(
                            output_dir / compiler_input_relative,
                            repo_root,
                        ),
                        "compiler_input_relative_path": compiler_input_relative.as_posix(),
                        "compiler_input_sha256": compiler_input_sha256,
                        **bindings,
                    }
                )

        records.sort(key=lambda item: (item["kind"], item["name"], item["source"]))

        manifest = build_manifest(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            records,
            forge_version,
            config_sha256=config_sha256,
            foundry_config_sha256=foundry_config_sha256,
        )
        write_json(staged / MANIFEST_FILENAME, manifest)
        validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            staged,
            declared_output_dir=output_dir,
            expected_forge_version=forge_version,
        )
        replace_output_directory(staged, output_dir, temp_root)

    return validate_release_output(
        repo_root,
        config_path,
        foundry_config_path,
        output_dir,
        expected_forge_version=forge_version,
    )


# ---------------------------------------------------------------------------
# Issue #670 authoritative evidence successor (R11 -> R4).
#
# This late-bound closure intentionally leaves the legacy unpaired builder
# above unchanged.  build_release_output resolves these globals at call time,
# so evidence mode uses only the definitions below.
# ---------------------------------------------------------------------------

R11_BOUNDARY_IDS = (
    "EVIDENCE_CONTROL",
    "PORTABLE_BUILD_INFO_LOOKUP",
    "PORTABLE_BUILD_INFO_READ",
    "PORTABLE_SOURCE_LOOKUP",
    "PORTABLE_SOURCE_READ",
    "ARTIFACT_LOOKUP",
    "ARTIFACT_READ",
    "STAGED_OUTPUT_VALIDATE",
    "OUTPUT_INSTALL",
    "TEMP_CLEANUP",
    "INSTALLED_INVENTORY",
    "INSTALLED_READ",
    "RECOVERY_INVENTORY",
)

R11_CANONICAL_DIAGNOSTICS = (
    "PATH_NOT_LOCAL_DRIVE_ABSOLUTE",
    "PATH_DEVICE_NAMESPACE",
    "PATH_UNSUPPORTED_DRIVE_TYPE",
    "TRAVERSAL_ROOT_OPEN",
    "TRAVERSAL_ROOT_REPARSE",
    "TRAVERSAL_ROOT_NOT_DIRECTORY",
    "TRAVERSAL_ROOT_ENUM_OPEN",
    "TRAVERSAL_ROOT_ENUM_NEXT",
    "TRAVERSAL_ROOT_ENUM_CLOSE",
    "TRAVERSAL_ROOT_ENTRY_NAME",
    "TRAVERSAL_ROOT_ENTRY_COLLISION",
    "TRAVERSAL_ROOT_IDENTITY_CHANGED",
    "TRAVERSAL_ROOT_HANDLE_CLOSE",
    "TRAVERSAL_ENUM_OPEN",
    "TRAVERSAL_ENUM_NEXT",
    "TRAVERSAL_ENUM_CLOSE",
    "TRAVERSAL_ENTRY_NAME",
    "TRAVERSAL_ENTRY_COLLISION",
    "TRAVERSAL_COMPONENT_MISSING",
    "TRAVERSAL_COMPONENT_CASE_MISMATCH",
    "TRAVERSAL_COMPONENT_SHORT_ALIAS",
    "TRAVERSAL_ENTRY_REPARSE",
    "TRAVERSAL_CHILD_OPEN",
    "TRAVERSAL_CHILD_REPARSE",
    "TRAVERSAL_CHILD_TYPE_CHANGED",
    "TRAVERSAL_IDENTITY_CHANGED",
    "TRAVERSAL_READ",
    "TRAVERSAL_HANDLE_CLOSE",
)

R11_DIAGNOSTIC_CLASS = {
    "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": "PATH_NOT_LOCAL_DRIVE_ABSOLUTE",
    "PATH_DEVICE_NAMESPACE": "PATH_DEVICE_NAMESPACE",
    "PATH_UNSUPPORTED_DRIVE_TYPE": "PATH_UNSUPPORTED_DRIVE_TYPE",
    "TRAVERSAL_ROOT_OPEN": "TRAVERSAL_OPEN_ANCESTOR",
    "TRAVERSAL_ROOT_REPARSE": "TRAVERSAL_ANCESTOR_REPARSE",
    "TRAVERSAL_ROOT_NOT_DIRECTORY": "TRAVERSAL_ANCESTOR_NOT_DIRECTORY",
    "TRAVERSAL_ROOT_ENUM_OPEN": "TRAVERSAL_ENUM_OPEN",
    "TRAVERSAL_ROOT_ENUM_NEXT": "TRAVERSAL_ENUM_NEXT",
    "TRAVERSAL_ROOT_ENUM_CLOSE": "TRAVERSAL_ENUM_CLOSE",
    "TRAVERSAL_ROOT_ENTRY_NAME": "TRAVERSAL_ENTRY_NAME",
    "TRAVERSAL_ROOT_ENTRY_COLLISION": "TRAVERSAL_ENTRY_COLLISION",
    "TRAVERSAL_ROOT_IDENTITY_CHANGED": "TRAVERSAL_IDENTITY_CHANGED",
    "TRAVERSAL_ROOT_HANDLE_CLOSE": "TRAVERSAL_HANDLE_CLOSE",
    "TRAVERSAL_ENUM_OPEN": "TRAVERSAL_ENUM_OPEN",
    "TRAVERSAL_ENUM_NEXT": "TRAVERSAL_ENUM_NEXT",
    "TRAVERSAL_ENUM_CLOSE": "TRAVERSAL_ENUM_CLOSE",
    "TRAVERSAL_ENTRY_NAME": "TRAVERSAL_ENTRY_NAME",
    "TRAVERSAL_ENTRY_COLLISION": "TRAVERSAL_ENTRY_COLLISION",
    "TRAVERSAL_COMPONENT_MISSING": "TRAVERSAL_COMPONENT_MISSING",
    "TRAVERSAL_COMPONENT_CASE_MISMATCH": "TRAVERSAL_COMPONENT_CASE_MISMATCH",
    "TRAVERSAL_COMPONENT_SHORT_ALIAS": "TRAVERSAL_COMPONENT_SHORT_ALIAS",
    "TRAVERSAL_ENTRY_REPARSE": "TRAVERSAL_CHILD_REPARSE",
    "TRAVERSAL_CHILD_OPEN": "TRAVERSAL_CHILD_OPEN",
    "TRAVERSAL_CHILD_REPARSE": "TRAVERSAL_CHILD_REPARSE",
    "TRAVERSAL_CHILD_TYPE_CHANGED": "TRAVERSAL_CHILD_TYPE_CHANGED",
    "TRAVERSAL_IDENTITY_CHANGED": "TRAVERSAL_IDENTITY_CHANGED",
    "TRAVERSAL_READ": "TRAVERSAL_READ",
    "TRAVERSAL_HANDLE_CLOSE": "TRAVERSAL_HANDLE_CLOSE",
}

_R11_MATRIX_ROWS = {
    "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "PATH_DEVICE_NAMESPACE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "PATH_UNSUPPORTED_DRIVE_TYPE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_OPEN_ANCESTOR": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ANCESTOR_REPARSE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ANCESTOR_NOT_DIRECTORY": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_NEXT": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENTRY_NAME": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENTRY_COLLISION": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_REPARSE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_TYPE_CHANGED": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_IDENTITY_CHANGED": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "ARI", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_READ": ("V", "X", "BIR", "X", "SRD", "X", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_HANDLE_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_COMPONENT_MISSING": ("V", "BLD", "BIR", "SPA", "SRD", "AM", "AFR", "X", "X", "X", "X", "OIR", "X"),
    "TRAVERSAL_COMPONENT_CASE_MISMATCH": ("V", "BLD", "BIR", "SPC", "SRD", "AA", "AFR", "X", "X", "X", "X", "OIR", "X"),
    "TRAVERSAL_COMPONENT_SHORT_ALIAS": ("V", "BLD", "BIR", "SPC", "SRD", "AA", "AFR", "X", "X", "X", "X", "OIR", "X"),
}
R11_TRANSLATION_MATRIX = {
    row: dict(zip(R11_BOUNDARY_IDS, values, strict=True))
    for row, values in _R11_MATRIX_ROWS.items()
}
R11_INDUCED_MATRIX = {
    code: dict(R11_TRANSLATION_MATRIX[R11_DIAGNOSTIC_CLASS[code]])
    for code in R11_CANONICAL_DIAGNOSTICS
}

_R11_DRIVE_FIXED = 3
_R11_DRIVE_REMOTE = 4
_R11_FILE_ATTRIBUTE_DIRECTORY = 0x00000010
_R11_FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400
_R11_FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000
_R11_ERROR_FILE_NOT_FOUND = 2
_R11_ERROR_PATH_NOT_FOUND = 3
_R11_ERROR_NO_MORE_FILES = 18
_R11_MAX_WIN32_ARGUMENT_UNITS = 32767
_R11_READ_CHUNK = 1024 * 1024
_R11_FILE_BEGIN = 0


class _R11FileTime(ctypes.Structure):
    _fields_ = [
        ("dwLowDateTime", wintypes.DWORD),
        ("dwHighDateTime", wintypes.DWORD),
    ]


class _R11FindData(ctypes.Structure):
    _fields_ = [
        ("dwFileAttributes", wintypes.DWORD),
        ("ftCreationTime", _R11FileTime),
        ("ftLastAccessTime", _R11FileTime),
        ("ftLastWriteTime", _R11FileTime),
        ("nFileSizeHigh", wintypes.DWORD),
        ("nFileSizeLow", wintypes.DWORD),
        ("dwReserved0", wintypes.DWORD),
        ("dwReserved1", wintypes.DWORD),
        ("cFileName", wintypes.WCHAR * 260),
        ("cAlternateFileName", wintypes.WCHAR * 14),
    ]


_R11_KERNEL32: Any | None = None


def _kernel32() -> Any:
    global _R11_KERNEL32
    if os.name != "nt":
        raise EvidenceFailure(
            "NON_WINDOWS_EVIDENCE_MODE",
            "authoritative evidence mode requires canonical Windows",
        )
    if _R11_KERNEL32 is not None:
        return _R11_KERNEL32
    if ctypes.sizeof(wintypes.WCHAR) != 2 or ctypes.sizeof(_R11FileTime) != 8:
        raise EvidenceFailure("WINDOWS_ABI_LAYOUT", "WCHAR/FILETIME ABI mismatch")
    expected_offsets = (0, 4, 12, 20, 28, 32, 36, 40, 44, 564)
    fields = tuple(name for name, _ in _R11FindData._fields_)
    actual_offsets = tuple(getattr(_R11FindData, name).offset for name in fields)
    if ctypes.sizeof(_R11FindData) != 592 or actual_offsets != expected_offsets:
        raise EvidenceFailure("WINDOWS_ABI_LAYOUT", "WIN32_FIND_DATAW ABI mismatch")
    kernel32 = ctypes.WinDLL("kernel32.dll", use_last_error=True)
    kernel32.CreateFileW.argtypes = (
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
        wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
    )
    kernel32.CreateFileW.restype = wintypes.HANDLE
    kernel32.GetFileInformationByHandle.argtypes = (
        wintypes.HANDLE, ctypes.POINTER(_ByHandleFileInformation),
    )
    kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
    kernel32.CreateMutexW.argtypes = (ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR)
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    kernel32.ReleaseMutex.argtypes = (wintypes.HANDLE,)
    kernel32.ReleaseMutex.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)
    kernel32.CloseHandle.restype = wintypes.BOOL
    kernel32.MoveFileExW.argtypes = (wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD)
    kernel32.MoveFileExW.restype = wintypes.BOOL
    kernel32.GetDriveTypeW.argtypes = [wintypes.LPCWSTR]
    kernel32.GetDriveTypeW.restype = wintypes.UINT
    kernel32.FindFirstFileW.argtypes = [
        wintypes.LPCWSTR, ctypes.POINTER(_R11FindData),
    ]
    kernel32.FindFirstFileW.restype = wintypes.HANDLE
    kernel32.FindNextFileW.argtypes = [
        wintypes.HANDLE, ctypes.POINTER(_R11FindData),
    ]
    kernel32.FindNextFileW.restype = wintypes.BOOL
    kernel32.FindClose.argtypes = [wintypes.HANDLE]
    kernel32.FindClose.restype = wintypes.BOOL
    kernel32.ReadFile.argtypes = (
        wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p,
    )
    kernel32.ReadFile.restype = wintypes.BOOL
    kernel32.SetFilePointerEx.argtypes = (
        wintypes.HANDLE, ctypes.c_longlong,
        ctypes.POINTER(ctypes.c_longlong), wintypes.DWORD,
    )
    kernel32.SetFilePointerEx.restype = wintypes.BOOL
    _R11_KERNEL32 = kernel32
    return kernel32


@dataclass(frozen=True)
class R11CopiedRecordProof:
    code: str
    operation: str
    records: tuple[
        tuple[bytes, bytes, int, bytes, int, bool, str | None, str | None], ...
    ]
    records_sha256: str
    winner: tuple[bytes, bytes, int, bytes, int, bool, str | None, str | None] | None
    root: bool
    inventory: bool
    requested_depth: int | None
    requested_token: str | None
    parent_token: str | None
    parent_identity: tuple[str, str]
    requested_component: str | None
    observed_winner_token: str | None


class R11TraversalDiagnostic(EvidenceFailure):
    """Closed eight-key native diagnostic; raw path/name text is never stored."""

    def __init__(
        self,
        code: str,
        operation: str,
        *,
        component_index: int | None = None,
        path_token: str | None = None,
        winerror: int | None = None,
        expected_attributes: int | None = None,
        actual_attributes: int | None = None,
        identity_before: dict[str, str] | None = None,
        identity_after: dict[str, str] | None = None,
        record_proof: R11CopiedRecordProof | None = None,
    ) -> None:
        if code not in R11_CANONICAL_DIAGNOSTICS:
            raise ValueError(f"unknown canonical traversal diagnostic: {code}")
        operands = {
            "operation": operation,
            "component_index": component_index,
            "path_token": path_token,
            "winerror": winerror,
            "expected_attributes": expected_attributes,
            "actual_attributes": actual_attributes,
            "identity_before": identity_before,
            "identity_after": identity_after,
        }
        super().__init__(code, f"typed native traversal failure: {operation}", operands=operands)
        self.record_proof = record_proof


def _r11_identity(information: _ByHandleFileInformation) -> dict[str, str]:
    index = (int(information.nFileIndexHigh) << 32) | int(information.nFileIndexLow)
    return {
        "volume_serial": f"{int(information.dwVolumeSerialNumber):08X}",
        "file_index": f"{index:016X}",
    }


def _r11_query_handle(handle: int) -> tuple[dict[str, str], int, int]:
    information = _ByHandleFileInformation()
    ctypes.set_last_error(0)
    if not _kernel32().GetFileInformationByHandle(handle, ctypes.byref(information)):
        error = int(ctypes.get_last_error())
        raise OSError(error, "GetFileInformationByHandle failed")
    size = (int(information.nFileSizeHigh) << 32) | int(information.nFileSizeLow)
    return _r11_identity(information), int(information.dwFileAttributes), size


def _r11_u16(value: str) -> int:
    return len(value.encode("utf-16-le", errors="strict")) // 2


def _r11_require_w_argument(value: str) -> None:
    if _r11_u16(value) + 1 > _R11_MAX_WIN32_ARGUMENT_UNITS:
        raise R11TraversalDiagnostic(
            "PATH_NOT_LOCAL_DRIVE_ABSOLUTE", "lexical_validate",
        )


def _r11_validate_component(value: str) -> str:
    if type(value) is not str:
        raise TypeError("component must be an exact string")
    if not value or value in (".", ".."):
        raise ValueError("empty/dot component")
    if any(char in value for char in ("\x00", "/", "\\", ":", "*", "?")):
        raise ValueError("forbidden component character")
    if value.endswith((".", " ")):
        raise ValueError("forbidden component ending")
    value.encode("utf-16-le", errors="strict")
    return value


def _r11_validate_filetoken(value: str) -> str:
    if type(value) is not str:
        raise TypeError("FILETOKEN must be an exact string")
    raw = value.encode("utf-8", errors="strict")
    if not 1 <= len(raw) <= 32767 or "\\" in value or value.startswith("/"):
        raise ValueError("invalid FILETOKEN")
    for component in value.split("/"):
        _r11_validate_component(component)
    return value


def _r11_absolute_parts(value: Path | str) -> tuple[str, list[str], str]:
    text = str(value)
    folded = text.casefold()
    if folded.startswith(("\\\\?\\", "\\\\.\\", "\\??\\")) or "globalroot" in folded:
        raise R11TraversalDiagnostic("PATH_DEVICE_NAMESPACE", "namespace_validate")
    if not re.fullmatch(r"[A-Za-z]:\\(?:[^\\]+(?:\\[^\\]+)*)?", text):
        raise R11TraversalDiagnostic("PATH_NOT_LOCAL_DRIVE_ABSOLUTE", "lexical_validate")
    drive = text[0].upper()
    components = [] if len(text) == 3 else text[3:].split("\\")
    try:
        components = [_r11_validate_component(component) for component in components]
    except (ValueError, UnicodeError) as exc:
        raise R11TraversalDiagnostic(
            "PATH_NOT_LOCAL_DRIVE_ABSOLUTE", "lexical_validate",
        ) from exc
    root = f"\\\\?\\{drive}:\\"
    cumulative = root + "\\".join(components)
    _r11_require_w_argument(cumulative)
    drive_type = int(_kernel32().GetDriveTypeW(f"{drive}:\\"))
    if drive_type != _R11_DRIVE_FIXED:
        raise R11TraversalDiagnostic(
            "PATH_UNSUPPORTED_DRIVE_TYPE", "drive_type",
            expected_attributes=_R11_DRIVE_FIXED,
            actual_attributes=drive_type,
        )
    return root, components, cumulative


def _r11_decode_wchar_array(raw: bytes, units: int, *, alternate: bool) -> str:
    terminator = None
    for index in range(units):
        if raw[index * 2:index * 2 + 2] == b"\x00\x00":
            terminator = index
            break
    if terminator is None:
        raise ValueError("unterminated WCHAR array")
    value = raw[:terminator * 2].decode("utf-16-le", errors="strict")
    if alternate and not value:
        return ""
    _r11_validate_component(value)
    return value


def _r11_is_exact_dot_record(record: dict[str, Any]) -> bool:
    """Recognize only the zero-filled fixed-array encodings of `.` and `..`."""
    raw = record["raw_long"]
    for value in (".", ".."):
        encoded = value.encode("utf-16-le") + b"\x00\x00"
        if raw == encoded + bytes(520 - len(encoded)):
            return True
    return False


def _r11_copy_find_record(data: _R11FindData) -> dict[str, Any]:
    base = ctypes.addressof(data)
    raw_long = ctypes.string_at(base + 44, 520)
    raw_alt = ctypes.string_at(base + 564, 28)
    attributes = int(data.dwFileAttributes)
    return {
        "raw_long": raw_long,
        "raw_alt": raw_alt,
        "attributes": attributes,
        "record_key": raw_long + raw_alt + attributes.to_bytes(4, "little", signed=False),
    }


def _r11_record_names(record: dict[str, Any]) -> tuple[str, str]:
    return (
        _r11_decode_wchar_array(record["raw_long"], 260, alternate=False),
        _r11_decode_wchar_array(record["raw_alt"], 14, alternate=True),
    )


def _r11_pattern(parent: str, *, root: bool) -> str:
    if root:
        if not parent.endswith("\\"):
            raise ValueError("root constructor requires terminal separator")
        pattern = parent + "*"
    else:
        if parent.endswith("\\"):
            raise ValueError("child constructor forbids terminal separator")
        pattern = parent + "\\*"
    _r11_require_w_argument(pattern)
    return pattern


def _r11_freeze_copied_record(
    record: dict[str, Any],
) -> tuple[bytes, bytes, int, bytes, int, bool, str | None, str | None]:
    names_present = "long_name" in record or "alternate_name" in record
    if names_present and not (
        "long_name" in record and "alternate_name" in record
    ):
        raise ValueError("copied record decoded-name presence is not paired")
    return (
        record["raw_long"],
        record["raw_alt"],
        record["attributes"],
        record["record_key"],
        record["raw_ordinal"],
        names_present,
        record.get("long_name"),
        record.get("alternate_name"),
    )


def _r11_thaw_copied_record(
    frozen: tuple[bytes, bytes, int, bytes, int, bool, str | None, str | None],
) -> dict[str, Any]:
    raw_long, raw_alt, attributes, record_key, raw_ordinal, names_present, long_name, alternate_name = frozen
    record: dict[str, Any] = {
        "raw_long": raw_long,
        "raw_alt": raw_alt,
        "attributes": attributes,
        "record_key": record_key,
        "raw_ordinal": raw_ordinal,
    }
    if names_present:
        record["long_name"] = long_name
        record["alternate_name"] = alternate_name
    return record


def _r11_copied_record_multiset_sha256(
    records: Sequence[dict[str, Any]],
) -> str:
    """Commit the complete copied-record multiset without losing duplicates."""
    entries = [
        {
            "raw_long": record["raw_long"].hex(),
            "raw_alt": record["raw_alt"].hex(),
            "attributes": record["attributes"],
            "record_key": record["record_key"].hex(),
            "raw_ordinal": record["raw_ordinal"],
            "names_present": "long_name" in record or "alternate_name" in record,
            "long_name": record.get("long_name"),
            "alternate_name": record.get("alternate_name"),
        }
        for record in records
    ]
    entries.sort(
        key=lambda item: (
            item["record_key"], item["raw_long"], item["raw_alt"],
            item["attributes"], item["raw_ordinal"], item["names_present"],
            "" if item["long_name"] is None else item["long_name"],
            "" if item["alternate_name"] is None else item["alternate_name"],
        )
    )
    return sha256_bytes(canonical_evidence_bytes(entries))


def _r11_strict_smaller_ranks(keys: Sequence[bytes]) -> dict[bytes, int]:
    first_index: dict[bytes, int] = {}
    for index, key in enumerate(sorted(keys)):
        first_index.setdefault(key, index)
    return first_index


def _r11_validate_requested_depth_authority(
    *, root: bool, inventory: bool, requested_depth: int | None,
) -> None:
    if root or inventory:
        if requested_depth is not None:
            raise ValueError("inventory record proof requested depth is not null")
    elif not _r11_u53(requested_depth):
        raise ValueError("lookup record proof requested depth is not U53")


def _r11_record_proof(
    code: str,
    operation: str,
    *,
    records: Sequence[dict[str, Any]],
    winner: dict[str, Any] | None,
    root: bool,
    inventory: bool,
    requested_depth: int | None,
    requested_token: str | None,
    parent_token: str | None,
    parent_identity: dict[str, str],
    requested_component: str | None,
    observed_winner_token: str | None,
) -> R11CopiedRecordProof:
    _r11_validate_requested_depth_authority(
        root=root, inventory=inventory, requested_depth=requested_depth,
    )
    return R11CopiedRecordProof(
        code,
        operation,
        tuple(_r11_freeze_copied_record(record) for record in records),
        _r11_copied_record_multiset_sha256(records),
        None if winner is None else _r11_freeze_copied_record(winner),
        root,
        inventory,
        requested_depth,
        requested_token,
        parent_token,
        (parent_identity["volume_serial"], parent_identity["file_index"]),
        requested_component,
        observed_winner_token,
    )


def _r11_reconstruct_record_position(
    records: Sequence[dict[str, Any]],
    winner: dict[str, Any],
) -> tuple[bytes, int]:
    keys: list[bytes] = []
    for record in records:
        raw_long = record.get("raw_long")
        raw_alt = record.get("raw_alt")
        attributes = record.get("attributes")
        if type(raw_long) is not bytes or len(raw_long) != 520:
            raise ValueError("diagnostic record long-name bytes are not exact")
        if type(raw_alt) is not bytes or len(raw_alt) != 28:
            raise ValueError("diagnostic record alternate-name bytes are not exact")
        if not _r11_dword(attributes):
            raise ValueError("diagnostic record attributes are not a DWORD")
        key = raw_long + raw_alt + attributes.to_bytes(4, "little", signed=False)
        if record.get("record_key") != key:
            raise ValueError("diagnostic record key does not reconstruct")
        try:
            long_name, alternate_name = _r11_record_names(record)
        except (ValueError, UnicodeError):
            if "long_name" in record or "alternate_name" in record:
                raise ValueError("malformed record carries caller decoded names")
        else:
            if (
                record.get("long_name") != long_name
                or record.get("alternate_name") != alternate_name
            ):
                raise ValueError("diagnostic decoded names do not reconstruct")
        keys.append(key)
    winner_key = winner.get("record_key")
    exact_winners = [
        record for record, key in zip(records, keys, strict=True)
        if key == winner_key
    ]
    if not exact_winners or winner not in exact_winners:
        raise ValueError("diagnostic winner is not one exact copied record")
    ordinal_by_key = _r11_strict_smaller_ranks(keys)
    for record, key in zip(records, keys, strict=True):
        exact_ordinal = ordinal_by_key[key]
        if record.get("raw_ordinal") != exact_ordinal:
            raise ValueError("diagnostic record global ordinal does not reconstruct")
    return winner_key, ordinal_by_key[winner_key]


def _r11_record_backed_diagnostic(
    code: str,
    operation: str,
    *,
    records: Sequence[dict[str, Any]],
    winner: dict[str, Any],
    root: bool,
    inventory: bool,
    requested_depth: int | None,
    requested_token: str | None,
    parent_token: str | None,
    parent_identity: dict[str, str],
    requested_component: str | None = None,
    observed_winner_token: str | None = None,
    _skip_proof_validation: bool = False,
) -> "R11TraversalDiagnostic":
    winner_key, global_ordinal = _r11_reconstruct_record_position(records, winner)
    root_code = code.startswith("TRAVERSAL_ROOT_")
    if root != root_code:
        raise ValueError("record diagnostic root/code binding differs")
    if root and inventory is not True:
        raise ValueError("root record diagnostics require the root inventory mode")
    expected_operation = (
        "validate_root_entry"
        if root
        else "resolve_component"
        if code.startswith("TRAVERSAL_COMPONENT_")
        else "validate_inventory_entry"
        if inventory
        else "validate_entry"
    )
    if operation != expected_operation:
        raise ValueError("record diagnostic operation/mode binding differs")
    if parent_token is None:
        raise ValueError("record diagnostic has no retained parent token")
    _r11_validate_filetoken(parent_token)
    _r11_validate_requested_depth_authority(
        root=root, inventory=inventory, requested_depth=requested_depth,
    )
    if root:
        if requested_depth is not None or requested_token is not None:
            raise ValueError("root record diagnostic requested state is not null")
    else:
        if requested_token is None:
            raise ValueError("non-root record diagnostic requested token is absent")
        _r11_validate_filetoken(requested_token)
        if inventory and requested_token != parent_token:
            raise ValueError(
                "inventory record diagnostic token differs from retained parent"
            )
    component_lookup = code.startswith("TRAVERSAL_COMPONENT_")
    if component_lookup != (requested_component is not None):
        raise ValueError("record diagnostic requested component is not exact")
    if component_lookup != (observed_winner_token is not None):
        raise ValueError("record diagnostic observed winner token is not exact")
    decoded: list[dict[str, Any]] = []
    malformed: list[dict[str, Any]] = []
    for record in records:
        try:
            long_name, alternate_name = _r11_record_names(record)
        except (ValueError, UnicodeError):
            malformed.append(record)
            continue
        decoded.append(
            {**record, "long_name": long_name, "alternate_name": alternate_name}
        )
    expected_winner: dict[str, Any] | None = None
    if code in ("TRAVERSAL_ROOT_ENTRY_NAME", "TRAVERSAL_ENTRY_NAME"):
        if malformed:
            expected_winner = min(malformed, key=lambda item: item["record_key"])
    elif code in (
        "TRAVERSAL_ROOT_ENTRY_COLLISION", "TRAVERSAL_ENTRY_COLLISION",
    ):
        collision_groups: dict[str, list[dict[str, Any]]] = {}
        for record in decoded:
            collision_groups.setdefault(record["long_name"].casefold(), []).append(record)
        candidates = [
            min(group, key=lambda item: item["record_key"])
            for group in collision_groups.values()
            if len(group) >= 2
        ]
        if candidates and not malformed:
            expected_winner = min(candidates, key=lambda item: item["record_key"])
    elif code == "TRAVERSAL_COMPONENT_CASE_MISMATCH":
        collision = len({record["long_name"].casefold() for record in decoded}) != len(decoded)
        if requested_component is not None and not malformed and not collision and not any(
            record["long_name"] == requested_component for record in decoded
        ):
            candidates = [
                record for record in decoded
                if record["long_name"].casefold() == requested_component.casefold()
            ]
            if candidates:
                expected_winner = min(candidates, key=lambda item: item["record_key"])
    elif code == "TRAVERSAL_COMPONENT_SHORT_ALIAS":
        collision = len({record["long_name"].casefold() for record in decoded}) != len(decoded)
        if requested_component is not None and not malformed and not collision and not any(
            record["long_name"] == requested_component
            or record["long_name"].casefold() == requested_component.casefold()
            for record in decoded
        ):
            candidates = [
                record for record in decoded
                if record["alternate_name"]
                and record["alternate_name"].casefold()
                == requested_component.casefold()
            ]
            if candidates:
                expected_winner = min(candidates, key=lambda item: item["record_key"])
    if expected_winner is None or expected_winner["record_key"] != winner_key:
        raise ValueError("diagnostic winner does not reconstruct from semantic priority")
    if observed_winner_token is not None:
        if root or parent_token is None or "long_name" not in winner:
            raise ValueError("diagnostic winner token has no retained parent")
        exact_winner_token = _r11_validate_filetoken(
            parent_token + "/" + winner["long_name"]
        )
        if observed_winner_token != exact_winner_token:
            raise ValueError("diagnostic winner token does not reconstruct")
    component_index = (
        0
        if root
        else global_ordinal
        if inventory
        else requested_depth
    )
    path_token = None if root else parent_token if inventory else requested_token
    proof = _r11_record_proof(
        code,
        operation,
        records=records,
        winner=winner,
        root=root,
        inventory=inventory,
        requested_depth=requested_depth,
        requested_token=requested_token,
        parent_token=parent_token,
        parent_identity=parent_identity,
        requested_component=requested_component,
        observed_winner_token=observed_winner_token,
    )
    diagnostic = R11TraversalDiagnostic(
        code,
        operation,
        component_index=component_index,
        path_token=path_token,
        actual_attributes=winner["attributes"],
        identity_before=parent_identity,
        record_proof=proof,
    )
    if not _skip_proof_validation:
        r11_validate_diagnostic(diagnostic)
    return diagnostic


def _r11_missing_record_diagnostic(
    *,
    records: Sequence[dict[str, Any]],
    requested_component: str,
    requested_depth: int,
    requested_token: str,
    parent_token: str,
    parent_identity: dict[str, str],
    _skip_proof_validation: bool = False,
) -> "R11TraversalDiagnostic":
    _r11_validate_copied_records(records)
    if not _r11_u53(requested_depth):
        raise ValueError("missing diagnostic requested depth is not U53")
    _r11_validate_filetoken(requested_token)
    _r11_validate_filetoken(parent_token)
    _r11_validate_component(requested_component)
    if any(
        record["long_name"] == requested_component
        or record["long_name"].casefold() == requested_component.casefold()
        or record["alternate_name"]
        and record["alternate_name"].casefold() == requested_component.casefold()
        for record in records
    ):
        raise ValueError("missing diagnostic snapshot contains a semantic match")
    proof = _r11_record_proof(
        "TRAVERSAL_COMPONENT_MISSING",
        "resolve_component",
        records=records,
        winner=None,
        root=False,
        inventory=False,
        requested_depth=requested_depth,
        requested_token=requested_token,
        parent_token=parent_token,
        parent_identity=parent_identity,
        requested_component=requested_component,
        observed_winner_token=None,
    )
    diagnostic = R11TraversalDiagnostic(
        "TRAVERSAL_COMPONENT_MISSING",
        "resolve_component",
        component_index=requested_depth,
        path_token=requested_token,
        identity_before=parent_identity,
        record_proof=proof,
    )
    if not _skip_proof_validation:
        r11_validate_diagnostic(diagnostic)
    return diagnostic


def _r11_find_snapshot(
    parent: str,
    *,
    root: bool,
    parent_token: str | None,
    parent_identity: dict[str, str],
    mode: str,
    requested_token: str | None = None,
    requested_depth: int | None = None,
) -> list[dict[str, Any]]:
    if mode not in ("inventory", "lookup"):
        raise ValueError("record snapshot mode is not closed")
    if parent_token is None:
        raise ValueError("record snapshot retained parent token is absent")
    _r11_validate_filetoken(parent_token)
    if root:
        if (
            mode != "inventory"
            or requested_token is not None
            or requested_depth is not None
        ):
            raise ValueError("root snapshot authority is not exact")
    else:
        if requested_token is None:
            raise ValueError("non-root snapshot requested token is absent")
        _r11_validate_filetoken(requested_token)
        if mode == "inventory" and requested_token != parent_token:
            raise ValueError("inventory snapshot token authority differs")
        if not _r11_u53(requested_depth):
            raise ValueError("non-root snapshot depth is not U53")
    kernel32 = _kernel32()
    data = _R11FindData()
    ctypes.set_last_error(0)
    handle = kernel32.FindFirstFileW(
        _r11_pattern(parent, root=root), ctypes.byref(data),
    )
    if handle == _INVALID_HANDLE_VALUE:
        error = int(ctypes.get_last_error())
        if error == _R11_ERROR_FILE_NOT_FOUND:
            return []
        raise R11TraversalDiagnostic(
            "TRAVERSAL_ROOT_ENUM_OPEN" if root else "TRAVERSAL_ENUM_OPEN",
            "enum_root_open" if root else "enum_child_open",
            component_index=None if root else requested_depth,
            path_token=None if root else requested_token,
            winerror=error,
            identity_before=parent_identity,
        )
    primary: BaseException | None = None
    records: list[dict[str, Any]] = []
    try:
        records.append(_r11_copy_find_record(data))
        while True:
            data = _R11FindData()
            ctypes.set_last_error(0)
            if kernel32.FindNextFileW(handle, ctypes.byref(data)):
                records.append(_r11_copy_find_record(data))
                continue
            error = int(ctypes.get_last_error())
            if error != _R11_ERROR_NO_MORE_FILES:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ROOT_ENUM_NEXT" if root else "TRAVERSAL_ENUM_NEXT",
                    "enum_root_next" if root else "enum_child_next",
                    component_index=None if root else requested_depth,
                    path_token=None if root else requested_token,
                    winerror=error,
                    identity_before=parent_identity,
                )
            break
    except BaseException as exc:
        primary = exc
        raise
    finally:
        ctypes.set_last_error(0)
        if not kernel32.FindClose(handle):
            error = int(ctypes.get_last_error())
            if primary is None:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ROOT_ENUM_CLOSE" if root else "TRAVERSAL_ENUM_CLOSE",
                    "enum_root_close" if root else "enum_child_close",
                    component_index=None if root else requested_depth,
                    path_token=None if root else requested_token,
                    winerror=error,
                    identity_before=parent_identity,
                )
    nondot = []
    malformed: list[dict[str, Any]] = []
    for record in records:
        if _r11_is_exact_dot_record(record):
            continue
        try:
            long_name, alternate_name = _r11_record_names(record)
        except (ValueError, UnicodeError):
            malformed.append(record)
            continue
        record = {**record, "long_name": long_name, "alternate_name": alternate_name}
        nondot.append(record)
    raw_order = sorted(nondot + malformed, key=lambda item: item["record_key"])
    ordinal = _r11_strict_smaller_ranks(
        [record["record_key"] for record in raw_order],
    )
    for record in raw_order:
        record["raw_ordinal"] = ordinal[record["record_key"]]
    if malformed:
        rejected = min(malformed, key=lambda item: item["record_key"])
        raise _r11_record_backed_diagnostic(
            "TRAVERSAL_ROOT_ENTRY_NAME" if root else "TRAVERSAL_ENTRY_NAME",
            "validate_root_entry" if root else (
                "validate_inventory_entry" if mode == "inventory" else "validate_entry"
            ),
            records=raw_order,
            winner=rejected,
            root=root,
            inventory=True if root else mode == "inventory",
            requested_depth=(
                None if root or mode == "inventory" else requested_depth
            ),
            requested_token=requested_token,
            parent_token=parent_token,
            parent_identity=parent_identity,
        )
    groups: dict[str, list[dict[str, Any]]] = {}
    for record in nondot:
        groups.setdefault(record["long_name"].casefold(), []).append(record)
    collision_members = [
        min(group, key=lambda item: item["record_key"])
        for group in groups.values() if len(group) >= 2
    ]
    if collision_members:
        rejected = min(collision_members, key=lambda item: item["record_key"])
        raise _r11_record_backed_diagnostic(
            "TRAVERSAL_ROOT_ENTRY_COLLISION" if root else "TRAVERSAL_ENTRY_COLLISION",
            "validate_root_entry" if root else (
                "validate_inventory_entry" if mode == "inventory" else "validate_entry"
            ),
            records=raw_order,
            winner=rejected,
            root=root,
            inventory=True if root else mode == "inventory",
            requested_depth=(
                None if root or mode == "inventory" else requested_depth
            ),
            requested_token=requested_token,
            parent_token=parent_token,
            parent_identity=parent_identity,
        )
    return [
        {**record, "raw_ordinal": ordinal[record["record_key"]]}
        for record in sorted(
            nondot,
            key=lambda item: (item["long_name"].casefold(), item["long_name"]),
        )
    ]


def _r11_lookup_record(
    records: Sequence[dict[str, Any]],
    requested: str,
    *,
    requested_token: str,
    depth: int,
    parent_identity: dict[str, str],
    parent_token: str,
) -> dict[str, Any]:
    _r11_validate_component(requested)
    _r11_validate_filetoken(requested_token)
    if not _r11_u53(depth):
        raise ValueError("lookup component depth is not U53")
    _r11_validate_filetoken(parent_token)
    _r11_validate_copied_records(records)
    exact = [record for record in records if record["long_name"] == requested]
    if len(exact) == 1:
        return exact[0]
    folded = [record for record in records if record["long_name"].casefold() == requested.casefold()]
    if folded:
        winner = min(folded, key=lambda item: item["record_key"])
        winner_token = _r11_validate_filetoken(parent_token + "/" + winner["long_name"])
        raise _r11_record_backed_diagnostic(
            "TRAVERSAL_COMPONENT_CASE_MISMATCH", "resolve_component",
            records=records,
            winner=winner,
            root=False,
            inventory=False,
            requested_depth=depth,
            requested_token=requested_token,
            parent_token=parent_token,
            parent_identity=parent_identity,
            requested_component=requested,
            observed_winner_token=winner_token,
        )
    aliases = [
        record for record in records
        if record["alternate_name"]
        and record["alternate_name"].casefold() == requested.casefold()
    ]
    if aliases:
        winner = min(aliases, key=lambda item: item["record_key"])
        winner_token = _r11_validate_filetoken(parent_token + "/" + winner["long_name"])
        raise _r11_record_backed_diagnostic(
            "TRAVERSAL_COMPONENT_SHORT_ALIAS", "resolve_component",
            records=records,
            winner=winner,
            root=False,
            inventory=False,
            requested_depth=depth,
            requested_token=requested_token,
            parent_token=parent_token,
            parent_identity=parent_identity,
            requested_component=requested,
            observed_winner_token=winner_token,
        )
    raise _r11_missing_record_diagnostic(
        records=records,
        requested_component=requested,
        requested_depth=depth,
        requested_token=requested_token,
        parent_token=parent_token,
        parent_identity=parent_identity,
    )


def r11_strict_bic_alias_winner(
    records: Sequence[dict[str, Any]],
    requested: str,
    parent_token: str,
) -> dict[str, Any]:
    _r11_validate_component(requested)
    _r11_validate_filetoken(parent_token)
    _r11_validate_copied_records(records)
    if any(
        record["long_name"] == requested
        or record["long_name"].casefold() == requested.casefold()
        for record in records
    ):
        raise EvidenceFailure(
            "BIC_LONG_MATCH_PRESENT", "BIC is only an alias-only proof",
        )
    groups: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        groups.setdefault(record["long_name"].casefold(), []).append(record)
    if any(len(group) >= 2 for group in groups.values()):
        raise EvidenceFailure(
            "BIC_COLLISION_PRESENT", "BIC rejects a colliding long-name snapshot",
        )
    aliases = [
        record for record in records
        if record["alternate_name"]
        and record["alternate_name"].casefold() == requested.casefold()
    ]
    if not aliases:
        raise EvidenceFailure("BIC_ALIAS_ABSENT", "BIC requires an alternate-name match")
    winner = min(aliases, key=lambda item: item["record_key"])
    observed = _r11_validate_filetoken(parent_token + "/" + winner["long_name"])
    _winner_key, _global_ordinal = _r11_reconstruct_record_position(records, winner)
    return {"actual_sha256": sha256_bytes(observed.encode("utf-8"))}


def _r11_validate_copied_records(records: Sequence[dict[str, Any]]) -> None:
    keys: list[bytes] = []
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("copied record is not an object")
        raw_long = record.get("raw_long")
        raw_alt = record.get("raw_alt")
        attributes = record.get("attributes")
        if type(raw_long) is not bytes or len(raw_long) != 520:
            raise ValueError("copied long-name bytes are not exact")
        if type(raw_alt) is not bytes or len(raw_alt) != 28:
            raise ValueError("copied alternate-name bytes are not exact")
        if not _r11_dword(attributes):
            raise ValueError("copied attributes are not a DWORD")
        key = raw_long + raw_alt + attributes.to_bytes(4, "little", signed=False)
        if record.get("record_key") != key:
            raise ValueError("copied record key does not reconstruct")
        long_name, alternate_name = _r11_record_names(record)
        if record.get("long_name") != long_name or record.get("alternate_name") != alternate_name:
            raise ValueError("decoded copied names do not reconstruct")
        keys.append(key)
    ordinal_by_key = _r11_strict_smaller_ranks(keys)
    for record, key in zip(records, keys, strict=True):
        expected_ordinal = ordinal_by_key[key]
        if record.get("raw_ordinal") != expected_ordinal:
            raise ValueError("copied raw ordinal does not reconstruct")


def r11_validate_strict_bic(
    records: Sequence[dict[str, Any]],
    requested: str,
    retained_parent_token: str,
    candidate: dict[str, Any],
) -> None:
    expected = r11_strict_bic_alias_winner(
        records, requested, retained_parent_token,
    )
    if not isinstance(candidate, dict) or tuple(candidate) != ("actual_sha256",):
        raise ValueError("strict BIC schema mismatch")
    if candidate != expected:
        raise ValueError("strict BIC winner/token hash does not reconstruct")


def _r11_close_traversal_handle(
    handle: int,
    *,
    code: str,
    operation: str,
    component_index: int | None,
    path_token: str | None,
    identity_before: dict[str, str] | None,
) -> None:
    ctypes.set_last_error(0)
    if not _kernel32().CloseHandle(handle):
        error = int(ctypes.get_last_error())
        raise R11TraversalDiagnostic(
            code, operation, component_index=component_index,
            path_token=path_token, winerror=error,
            identity_before=identity_before,
        )


def _r11_open_child(
    path: str,
    *,
    directory: bool,
    depth: int | None,
    token: str | None,
    parent_identity: dict[str, str] | None,
    root: bool = False,
) -> tuple[int, dict[str, str], int, int]:
    desired = _FILE_READ_ATTRIBUTES if directory else (_GENERIC_READ | _FILE_READ_ATTRIBUTES)
    share = _FILE_SHARE_READ | _FILE_SHARE_WRITE
    flags = _R11_FILE_FLAG_OPEN_REPARSE_POINT | (
        _FILE_FLAG_BACKUP_SEMANTICS if directory else 0
    )
    _r11_require_w_argument(path)
    ctypes.set_last_error(0)
    handle = _kernel32().CreateFileW(
        path, desired, share, None, _OPEN_EXISTING, flags, None,
    )
    if handle == _INVALID_HANDLE_VALUE:
        error = int(ctypes.get_last_error())
        if root:
            raise R11TraversalDiagnostic(
                "TRAVERSAL_ROOT_OPEN", "open_root", winerror=error,
            )
        raise R11TraversalDiagnostic(
            "TRAVERSAL_CHILD_OPEN", "open_child",
            component_index=depth, path_token=token, winerror=error,
            expected_attributes=_R11_FILE_ATTRIBUTE_DIRECTORY if directory else 0,
            identity_before=parent_identity,
        )
    handle = int(handle)
    try:
        try:
            identity, attributes, size = _r11_query_handle(handle)
        except OSError as exc:
            error = exc.winerror if exc.winerror is not None else exc.errno
            if error is None:
                raise
            if root:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ROOT_OPEN", "open_root", winerror=int(error),
                ) from exc
            raise R11TraversalDiagnostic(
                "TRAVERSAL_CHILD_OPEN", "open_child",
                component_index=depth, path_token=token, winerror=int(error),
                expected_attributes=_R11_FILE_ATTRIBUTE_DIRECTORY if directory else 0,
                identity_before=parent_identity,
            ) from exc
        if attributes & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
            raise R11TraversalDiagnostic(
                "TRAVERSAL_ROOT_REPARSE" if root else "TRAVERSAL_CHILD_REPARSE",
                "validate_root" if root else "validate_open_child",
                component_index=None if root else depth,
                path_token=None if root else token,
                actual_attributes=attributes,
                identity_before=identity,
            )
        actual_directory = bool(attributes & _R11_FILE_ATTRIBUTE_DIRECTORY)
        if actual_directory != directory:
            raise R11TraversalDiagnostic(
                "TRAVERSAL_ROOT_NOT_DIRECTORY" if root else "TRAVERSAL_CHILD_TYPE_CHANGED",
                "validate_root" if root else "validate_open_child",
                component_index=None if root else depth,
                path_token=None if root else token,
                expected_attributes=_R11_FILE_ATTRIBUTE_DIRECTORY if directory else 0,
                actual_attributes=attributes,
                identity_before=identity,
            )
        return handle, identity, attributes, size
    except BaseException as primary:
        try:
            _r11_close_traversal_handle(
                handle,
                code="TRAVERSAL_ROOT_HANDLE_CLOSE" if root else "TRAVERSAL_HANDLE_CLOSE",
                operation="close_root" if root else "close_child",
                component_index=None if root else depth,
                path_token=None if root else token,
                identity_before=None,
            )
        except BaseException:
            pass
        raise primary


def _r11_open_executable_lease_handle(
    path: str,
    *,
    directory: bool,
    lease_token: str,
) -> dict[str, Any]:
    """Open one no-follow lease handle that denies write and delete sharing."""
    _r11_validate_filetoken(lease_token)
    _r11_require_w_argument(path)
    desired = (
        _FILE_READ_ATTRIBUTES
        if directory
        else _GENERIC_READ | _FILE_READ_ATTRIBUTES
    )
    flags = _R11_FILE_FLAG_OPEN_REPARSE_POINT | (
        _FILE_FLAG_BACKUP_SEMANTICS if directory else 0
    )
    ctypes.set_last_error(0)
    handle = _kernel32().CreateFileW(
        path,
        desired,
        _FILE_SHARE_READ,
        None,
        _OPEN_EXISTING,
        flags,
        None,
    )
    if handle == _INVALID_HANDLE_VALUE:
        error = int(ctypes.get_last_error())
        raise EvidenceFailure(
            "EXECUTABLE_LEASE_ACQUIRE",
            "strict executable lease handle open failed",
            operands={"lease_token": lease_token, "winerror": error},
        )
    handle = int(handle)
    try:
        identity, attributes, size = _r11_query_handle(handle)
        if attributes & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
            raise EvidenceFailure(
                "EXECUTABLE_LEASE_ACQUIRE",
                "strict executable lease selected a reparse point",
                operands={"lease_token": lease_token},
            )
        if bool(attributes & _R11_FILE_ATTRIBUTE_DIRECTORY) != directory:
            raise EvidenceFailure(
                "EXECUTABLE_LEASE_ACQUIRE",
                "strict executable lease selected the wrong object kind",
                operands={"lease_token": lease_token},
            )
        return {
            "handle": handle,
            "identity": identity,
            "attributes": attributes,
            "size": size if not directory else None,
            "byte_count": None,
            "sha256": None,
            "lease_token": lease_token,
            "directory": directory,
        }
    except BaseException as primary:
        ctypes.set_last_error(0)
        if not _kernel32().CloseHandle(handle):
            raise EvidenceFailure(
                "EXECUTABLE_LEASE_CLOSE",
                "failed executable lease acquisition could not close its handle",
                operands={
                    "lease_token": lease_token,
                    "winerror": int(ctypes.get_last_error()),
                },
            ) from primary
        raise primary


def _r11_read_executable_lease_handle(record: dict[str, Any]) -> bytes:
    """Read a leased leaf through its retained native handle without transfer."""
    if record["directory"] is not False or not record["handle"]:
        raise EvidenceFailure(
            "EXECUTABLE_LEASE_CONFLICT",
            "strict executable lease leaf is not readable",
            operands={"lease_token": record["lease_token"]},
        )
    new_position = ctypes.c_longlong()
    ctypes.set_last_error(0)
    if not _kernel32().SetFilePointerEx(
        record["handle"], 0, ctypes.byref(new_position), _R11_FILE_BEGIN,
    ):
        error = int(ctypes.get_last_error())
        raise EvidenceFailure(
            "EXECUTABLE_LEASE_CONFLICT",
            "strict executable lease seek failed",
            operands={"lease_token": record["lease_token"], "winerror": error},
        )
    output = bytearray()
    while True:
        buffer = ctypes.create_string_buffer(_R11_READ_CHUNK)
        read_count = wintypes.DWORD()
        ctypes.set_last_error(0)
        if not _kernel32().ReadFile(
            record["handle"], buffer, len(buffer), ctypes.byref(read_count), None,
        ):
            error = int(ctypes.get_last_error())
            raise EvidenceFailure(
                "EXECUTABLE_LEASE_CONFLICT",
                "strict executable lease read failed",
                operands={
                    "lease_token": record["lease_token"],
                    "winerror": error,
                },
            )
        count = int(read_count.value)
        if count == 0:
            break
        output.extend(buffer.raw[:count])
    return bytes(output)


def _r11_revalidate_executable_lease_record(record: dict[str, Any]) -> None:
    actual_identity, actual_attributes, actual_size = _r11_query_handle(
        record["handle"],
    )
    if (
        actual_identity != record["identity"]
        or actual_attributes != record["attributes"]
        or not record["directory"] and actual_size != record["size"]
    ):
        raise EvidenceFailure(
            "EXECUTABLE_LEASE_CONFLICT",
            "strict executable lease identity or attributes changed",
            operands={"lease_token": record["lease_token"]},
        )
    if record["directory"]:
        return
    raw = _r11_read_executable_lease_handle(record)
    after_identity, after_attributes, after_size = _r11_query_handle(
        record["handle"],
    )
    actual_sha256 = sha256_bytes(raw)
    if (
        after_identity != record["identity"]
        or after_attributes != record["attributes"]
        or after_size != record["size"]
        or len(raw) != record["byte_count"]
        or actual_sha256 != record["sha256"]
    ):
        raise EvidenceFailure(
            "EXECUTABLE_LEASE_CONFLICT",
            "strict executable lease bytes changed",
            operands={
                "lease_token": record["lease_token"],
                "expected_sha256": record["sha256"],
                "actual_sha256": actual_sha256,
            },
        )


def _r11_close_executable_lease_records_without_revalidation(
    records: Sequence[dict[str, Any]],
) -> None:
    first: EvidenceFailure | None = None
    for record in reversed(records):
        handle = record["handle"]
        record["handle"] = 0
        if not handle:
            continue
        ctypes.set_last_error(0)
        if not _kernel32().CloseHandle(handle) and first is None:
            first = EvidenceFailure(
                "EXECUTABLE_LEASE_CLOSE",
                "strict executable lease acquisition cleanup failed",
                operands={
                    "lease_token": record["lease_token"],
                    "winerror": int(ctypes.get_last_error()),
                },
            )
    if first is not None:
        raise first


class R11ExecutableLeaseSet:
    """One run-scoped strict cumulative lease set for Forge and Solc."""

    def __init__(self, records: list[dict[str, Any]]) -> None:
        self.records = records
        self.owned = True

    @staticmethod
    def _acquire_chain(
        path: Path,
        tool_token: str,
        expected_receipt: dict[str, Any],
    ) -> list[dict[str, Any]]:
        root_path, components, _ = _r11_absolute_parts(path)
        records: list[dict[str, Any]] = []
        try:
            root = _r11_open_executable_lease_handle(
                root_path,
                directory=True,
                lease_token=f"{tool_token}/ancestor-000",
            )
            records.append(root)
            parent_path = root_path
            for depth, component in enumerate(components):
                child_path = parent_path + (
                    "" if parent_path.endswith("\\") else "\\"
                ) + component
                directory = depth < len(components) - 1
                child = _r11_open_executable_lease_handle(
                    child_path,
                    directory=directory,
                    lease_token=(
                        f"{tool_token}/ancestor-{depth + 1:03d}"
                        if directory
                        else f"{tool_token}/leaf"
                    ),
                )
                for ancestor in reversed(records):
                    _r11_revalidate_executable_lease_record(ancestor)
                records.append(child)
                parent_path = child_path
            leaf = records[-1]
            if leaf["directory"]:
                raise EvidenceFailure(
                    "EXECUTABLE_LEASE_ACQUIRE",
                    "strict executable lease has no leaf",
                    operands={"lease_token": tool_token},
                )
            raw = _r11_read_executable_lease_handle(leaf)
            leaf["byte_count"] = len(raw)
            leaf["sha256"] = sha256_bytes(raw)
            _r11_revalidate_executable_lease_record(leaf)
            if any(
                (
                    str(path) != expected_receipt["path"],
                    leaf["identity"] != expected_receipt["identity"],
                    leaf["byte_count"] != expected_receipt["byte_count"],
                    leaf["sha256"] != expected_receipt["sha256"],
                )
            ):
                raise EvidenceFailure(
                    "EXECUTABLE_LEASE_ACQUIRE",
                    "strict executable lease differs from its static receipt",
                    operands={"lease_token": tool_token},
                )
            return records
        except BaseException as primary:
            try:
                _r11_close_executable_lease_records_without_revalidation(records)
            except BaseException as cleanup:
                raise cleanup from primary
            raise primary

    @classmethod
    def acquire(
        cls,
        forge_bin: Path,
        solc_bin: Path,
        static_receipts: dict[str, Any],
    ) -> "R11ExecutableLeaseSet":
        records: list[dict[str, Any]] = []
        try:
            records.extend(
                cls._acquire_chain(forge_bin, "forge-lease", static_receipts["forge"])
            )
            records.extend(
                cls._acquire_chain(solc_bin, "solc-lease", static_receipts["solc"])
            )
            return cls(records)
        except BaseException as primary:
            try:
                _r11_close_executable_lease_records_without_revalidation(records)
            except BaseException as cleanup:
                raise cleanup from primary
            raise primary

    def revalidate(self) -> None:
        if not self.owned:
            raise EvidenceFailure(
                "EXECUTABLE_LEASE_CONFLICT",
                "strict executable lease set is already closed",
            )
        for record in reversed(self.records):
            _r11_revalidate_executable_lease_record(record)

    def close(self) -> None:
        if not self.owned:
            return
        self.owned = False
        first: BaseException | None = None
        try:
            for record in reversed(self.records):
                try:
                    _r11_revalidate_executable_lease_record(record)
                except BaseException as exc:
                    if first is None:
                        first = exc
        finally:
            for record in reversed(self.records):
                handle = record["handle"]
                record["handle"] = 0
                if not handle:
                    continue
                ctypes.set_last_error(0)
                if not _kernel32().CloseHandle(handle) and first is None:
                    first = EvidenceFailure(
                        "EXECUTABLE_LEASE_CLOSE",
                        "strict executable lease handle close failed",
                        operands={
                            "lease_token": record["lease_token"],
                            "winerror": int(ctypes.get_last_error()),
                        },
                    )
        if first is not None:
            raise first


class R11ExecutionAuthority:
    """Single cleanup owner for one exact live R11 evidence execution."""

    def __init__(self, run_lock: WindowsDirectoryLock) -> None:
        self.run_lock = run_lock
        self.closed = False
        try:
            _r11_require_execution_authority(self)
        except BaseException as primary:
            self.close(primary)
            raise

    def require_live(self) -> None:
        _r11_require_execution_authority(self)

    def close(self, primary: BaseException | None = None) -> None:
        if self.closed:
            return
        self.closed = True
        try:
            self.run_lock.close()
        except BaseException as cleanup:
            if primary is not None:
                raise cleanup from primary
            raise


def _r11_require_execution_authority(
    authority: R11ExecutionAuthority,
) -> R11ExecutionAuthority:
    if type(authority) is not R11ExecutionAuthority or authority.closed:
        raise EvidenceFailure(
            "EXECUTION_AUTHORITY",
            "authoritative journal requires its exact live execution authority",
        )
    run_lock = authority.run_lock
    leases = run_lock.executable_leases
    if (
        type(run_lock) is not WindowsDirectoryLock
        or not run_lock.owned
        or run_lock not in _ACTIVE_EVIDENCE_LOCKS
        or type(leases) is not R11ExecutableLeaseSet
        or not leases.owned
        or not leases.records
        or any(not record["handle"] for record in leases.records)
    ):
        raise EvidenceFailure(
            "EXECUTION_AUTHORITY",
            "authoritative journal execution authority is not wholly owned",
        )
    return authority


def _r11_require_journal_execution_authority(
    journal: Any,
) -> R11ExecutionAuthority:
    authority = _r11_require_execution_authority(
        journal.execution_authority,
    )
    run_lock = authority.run_lock
    expected_evidence_identity = journal.static_receipts["evidence_dir"][
        "identity"
    ]
    if (
        str(run_lock.path) != str(journal.evidence_dir)
        or run_lock.identity != journal.held_evidence_directory_identity
        or run_lock.identity != expected_evidence_identity
    ):
        raise EvidenceFailure(
            "EXECUTION_AUTHORITY",
            "journal evidence directory differs from its owned run lock",
        )
    leaf_records = [
        record for record in run_lock.executable_leases.records
        if not record["directory"]
    ]
    leaves = {
        record["lease_token"].split("/", 1)[0]: record
        for record in leaf_records
    }
    if (
        len(leaf_records) != 2
        or set(leaves) != {"forge-lease", "solc-lease"}
    ):
        raise EvidenceFailure(
            "EXECUTION_AUTHORITY",
            "journal execution authority has an inexact executable leaf set",
        )
    for token, lease_token, path in (
        ("forge", "forge-lease", journal.forge_bin),
        ("solc", "solc-lease", journal.solc_bin),
    ):
        expected = journal.static_receipts[token]
        leaf = leaves[lease_token]
        if (
            str(path) != expected["path"]
            or leaf["identity"] != expected["identity"]
            or leaf["byte_count"] != expected["byte_count"]
            or leaf["sha256"] != expected["sha256"]
        ):
            raise EvidenceFailure(
                "EXECUTION_AUTHORITY",
                "journal compiler differs from its owned executable lease",
                operands={"lease_token": lease_token},
            )
    return authority


def _r11_read_fd(
    handle: int,
    *,
    depth: int,
    token: str,
    before_identity: dict[str, str],
    before_attributes: int,
    before_size: int,
    transfer_owner: Callable[[], None] | None = None,
    on_read_failure: Callable[
        ["R11TraversalDiagnostic", dict[str, Any] | None], BaseException
    ] | None = None,
) -> bytes:
    def bound_failure(
        diagnostic: R11TraversalDiagnostic,
        read_state: dict[str, Any] | None = None,
    ) -> BaseException:
        if on_read_failure is None:
            return diagnostic
        return on_read_failure(diagnostic, read_state)

    try:
        descriptor = msvcrt.open_osfhandle(handle, os.O_RDONLY | os.O_BINARY)
    except BaseException:
        raise
    if transfer_owner is not None:
        transfer_owner()
    primary: BaseException | None = None
    output = bytearray()
    try:
        while True:
            try:
                chunk = os.read(descriptor, _R11_READ_CHUNK)
            except OSError as exc:
                if exc.winerror is None:
                    raise
                raise bound_failure(
                    R11TraversalDiagnostic(
                        "TRAVERSAL_READ", "read_child",
                        component_index=depth, path_token=token,
                        winerror=int(exc.winerror),
                        identity_before=before_identity,
                    )
                ) from exc
            if not chunk:
                break
            output.extend(chunk)
        after_handle = int(msvcrt.get_osfhandle(descriptor))
        try:
            after_identity, attributes, after_size = _r11_query_handle(after_handle)
        except OSError:
            raise
        if (
            attributes != before_attributes
            or after_identity != before_identity
            or after_size != before_size
        ):
            raise bound_failure(
                R11TraversalDiagnostic(
                    "TRAVERSAL_IDENTITY_CHANGED", "revalidate_child",
                    component_index=depth, path_token=token,
                    expected_attributes=before_attributes,
                    actual_attributes=attributes,
                    identity_before=before_identity, identity_after=after_identity,
                ),
                {
                    "before_identity": dict(before_identity),
                    "after_identity": dict(after_identity),
                    "before_size": before_size,
                    "after_size": after_size,
                    "read_byte_count": len(output),
                },
            )
        if len(output) != before_size:
            raise bound_failure(
                R11TraversalDiagnostic(
                    "TRAVERSAL_READ", "read_child",
                    component_index=depth, path_token=token,
                    winerror=None, identity_before=before_identity,
                )
            )
        return bytes(output)
    except BaseException as exc:
        primary = exc
        raise
    finally:
        try:
            os.close(descriptor)
        except OSError as exc:
            if primary is None:
                close_error = exc.winerror or exc.errno
                if close_error is None:
                    raise
                raise bound_failure(
                    R11TraversalDiagnostic(
                        "TRAVERSAL_HANDLE_CLOSE", "close_child",
                        component_index=depth, path_token=token,
                        winerror=int(close_error),
                        identity_before=before_identity,
                    )
                ) from exc
        except BaseException:
            if primary is None:
                raise


def _r11_join_filetoken(parent: str, child: str) -> str:
    _r11_validate_filetoken(parent)
    _r11_validate_component(child)
    return _r11_validate_filetoken(parent + "/" + child)


def _r11_assert_directory_stable(
    handle: int,
    identity_before: dict[str, str],
    attributes_before: int,
    *,
    root: bool,
    component_index: int | None,
    path_token: str | None,
) -> None:
    identity_after, attributes, _ = _r11_query_handle(handle)
    if (
        identity_after != identity_before
        or attributes != attributes_before
    ):
        raise R11TraversalDiagnostic(
            "TRAVERSAL_ROOT_IDENTITY_CHANGED" if root else "TRAVERSAL_IDENTITY_CHANGED",
            "revalidate_root" if root else "revalidate_child",
            component_index=None if root else component_index,
            path_token=None if root else path_token,
            expected_attributes=attributes_before,
            actual_attributes=attributes,
            identity_before=identity_before,
            identity_after=identity_after,
        )


def _r11_walk_retained_directory(
    parent_path: str,
    parent_handle: int,
    parent_identity: dict[str, str],
    parent_attributes: int,
    parent_token: str,
    *,
    root: bool,
    component_index: int | None,
    relative_prefix: str,
    read_files: bool,
    output: list[dict[str, Any]],
    contents: dict[str, bytes],
) -> None:
    records = _r11_find_snapshot(
        parent_path,
        root=root,
        parent_token=parent_token,
        parent_identity=parent_identity,
        mode="inventory",
        requested_token=None if root else parent_token,
        requested_depth=None if root else component_index,
    )
    _r11_assert_directory_stable(
        parent_handle, parent_identity, parent_attributes, root=root,
        component_index=component_index, path_token=None if root else parent_token,
    )
    reparses = [
        record for record in records
        if record["attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT
    ]
    if reparses:
        rejected = reparses[0]
        raise R11TraversalDiagnostic(
            "TRAVERSAL_ENTRY_REPARSE", "validate_inventory_entry",
            component_index=rejected["raw_ordinal"],
            path_token=parent_token,
            actual_attributes=rejected["attributes"],
            identity_before=parent_identity,
        )
    for record in records:
        name = record["long_name"]
        relative = name if not relative_prefix else relative_prefix + "/" + name
        child_token = _r11_join_filetoken(parent_token, name)
        child_path = parent_path + ("" if parent_path.endswith("\\") else "\\") + name
        is_directory = bool(record["attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY)
        child_handle, child_identity, attributes, child_size = _r11_open_child(
            child_path,
            directory=is_directory,
            depth=record["raw_ordinal"],
            token=child_token,
            parent_identity=parent_identity,
        )
        primary: BaseException | None = None
        try:
            entry = {
                "name": relative,
                "path_token": child_token,
                "attributes": attributes,
                "record_key_sha256": sha256_bytes(record["record_key"]),
                "ordinal": record["raw_ordinal"],
            }
            output.append(entry)
            if is_directory:
                _r11_walk_retained_directory(
                    child_path, child_handle, child_identity, attributes, child_token,
                    root=False,
                    component_index=record["raw_ordinal"],
                    relative_prefix=relative,
                    read_files=read_files,
                    output=output,
                    contents=contents,
                )
            elif read_files:
                def transfer_child_owner() -> None:
                    nonlocal child_handle
                    child_handle = 0

                raw = _r11_read_fd(
                    child_handle,
                    depth=record["raw_ordinal"],
                    token=child_token,
                    before_identity=child_identity,
                    before_attributes=attributes,
                    before_size=child_size,
                    transfer_owner=transfer_child_owner,
                )
                contents[relative] = raw
            else:
                after_identity, after_attributes, after_size = _r11_query_handle(child_handle)
                if (
                    after_identity != child_identity
                    or after_attributes != attributes
                    or after_size != child_size
                ):
                    raise R11TraversalDiagnostic(
                        "TRAVERSAL_IDENTITY_CHANGED", "revalidate_child",
                        component_index=record["raw_ordinal"], path_token=child_token,
                        expected_attributes=attributes,
                        actual_attributes=after_attributes,
                        identity_before=child_identity, identity_after=after_identity,
                    )
        except BaseException as exc:
            primary = exc
            raise
        finally:
            if child_handle:
                try:
                    _r11_close_traversal_handle(
                        child_handle,
                        code="TRAVERSAL_HANDLE_CLOSE",
                        operation="close_child",
                        component_index=record["raw_ordinal"],
                        path_token=child_token,
                        identity_before=child_identity,
                    )
                except BaseException:
                    if primary is None:
                        raise
        _r11_assert_directory_stable(
            parent_handle, parent_identity, parent_attributes, root=root,
            component_index=component_index,
            path_token=None if root else parent_token,
        )


def _r11_retained_tree_snapshot(
    path: Path | str,
    retained_directory_token: str,
    *,
    read_files: bool,
) -> tuple[list[dict[str, Any]], dict[str, bytes]]:
    _r11_validate_filetoken(retained_directory_token)
    parent_path, parent_token, retained = _r11_open_directory_chain(
        path, retained_directory_token,
    )
    output: list[dict[str, Any]] = []
    contents: dict[str, bytes] = {}
    primary: BaseException | None = None
    try:
        _r11_walk_retained_directory(
            parent_path,
            retained[-1][0],
            retained[-1][1],
            retained[-1][2],
            parent_token,
            root=(len(retained) == 1),
            component_index=None if len(retained) == 1 else len(retained) - 2,
            relative_prefix="",
            read_files=read_files,
            output=output,
            contents=contents,
        )
        return output, contents
    except BaseException as exc:
        primary = exc
        raise
    finally:
        try:
            _r11_close_directory_chain(retained)
        except BaseException:
            if primary is None:
                raise


class R11RetainedTree:
    """One retained-handle FULL_TREE inventory and sorted same-handle reader."""

    def __init__(self, path: Path | str, retained_directory_token: str) -> None:
        _r11_validate_filetoken(retained_directory_token)
        parent_path, parent_token, retained = _r11_open_directory_chain(
            path, retained_directory_token,
        )
        self.path = path
        self.root_token = retained_directory_token
        self.owned: list[dict[str, Any]] = []
        ancestors: list[dict[str, Any]] = []
        for handle, identity, attributes, depth, token in retained:
            item = {
                "handle": handle,
                "identity": dict(identity),
                "attributes": attributes,
                "component_index": depth,
                "path_token": token,
                "root": depth is None,
                "directory": True,
                "ancestors": tuple(ancestors),
            }
            self.owned.append(item)
            ancestors.append(item)
        self.entries: list[dict[str, Any]] = []
        self.files: dict[str, dict[str, Any]] = {}
        self.read_count = 0
        self.read_order: list[str] = []
        try:
            self._collect(
                parent_path,
                ancestors[-1],
                parent_token,
                root=(len(retained) == 1),
                relative_prefix="",
                ancestors=tuple(ancestors),
            )
        except BaseException as primary:
            self.close(primary=primary)
            raise primary
        self.read_order = sorted(self.files)

    def _collect(
        self,
        parent_path: str,
        parent: dict[str, Any],
        parent_token: str,
        *,
        root: bool,
        relative_prefix: str,
        ancestors: tuple[dict[str, Any], ...],
    ) -> None:
        records = _r11_find_snapshot(
            parent_path,
            root=root,
            parent_token=parent_token,
            parent_identity=parent["identity"],
            mode="inventory",
            requested_token=None if root else parent_token,
            requested_depth=None if root else parent["component_index"],
        )
        _r11_assert_directory_stable(
            parent["handle"], parent["identity"], parent["attributes"], root=root,
            component_index=parent["component_index"],
            path_token=None if root else parent_token,
        )
        reparses = [
            record for record in records
            if record["attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT
        ]
        if reparses:
            rejected = reparses[0]
            raise R11TraversalDiagnostic(
                "TRAVERSAL_ENTRY_REPARSE", "validate_inventory_entry",
                component_index=rejected["raw_ordinal"],
                path_token=parent_token,
                actual_attributes=rejected["attributes"],
                identity_before=parent["identity"],
            )
        for record in records:
            name = record["long_name"]
            relative = name if not relative_prefix else relative_prefix + "/" + name
            child_token = _r11_join_filetoken(parent_token, name)
            child_path = parent_path + ("" if parent_path.endswith("\\") else "\\") + name
            directory = bool(record["attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY)
            handle, identity, attributes, size = _r11_open_child(
                child_path,
                directory=directory,
                depth=record["raw_ordinal"],
                token=child_token,
                parent_identity=parent["identity"],
            )
            child = {
                "handle": handle,
                "identity": dict(identity),
                "component_index": record["raw_ordinal"],
                "path_token": child_token,
                "root": False,
                "directory": directory,
                "attributes": attributes,
                "size": size,
                "relative": relative,
                "ancestors": ancestors,
            }
            self.owned.append(child)
            self.entries.append(
                {
                    "name": relative,
                    "path_token": child_token,
                    "attributes": attributes,
                    "record_key_sha256": sha256_bytes(record["record_key"]),
                    "ordinal": record["raw_ordinal"],
                }
            )
            if directory:
                self._collect(
                    child_path, child, child_token,
                    root=False,
                    relative_prefix=relative,
                    ancestors=ancestors + (child,),
                )
            else:
                after_identity, after_attributes, after_size = _r11_query_handle(handle)
                if (
                    after_identity != identity
                    or after_attributes != attributes
                    or after_size != size
                ):
                    raise R11TraversalDiagnostic(
                        "TRAVERSAL_IDENTITY_CHANGED", "revalidate_child",
                        component_index=record["raw_ordinal"], path_token=child_token,
                        expected_attributes=attributes,
                        actual_attributes=after_attributes,
                        identity_before=identity, identity_after=after_identity,
                    )
                self.files[relative] = child
            _r11_assert_directory_stable(
                parent["handle"], parent["identity"], parent["attributes"], root=root,
                component_index=parent["component_index"],
                path_token=None if root else parent_token,
            )

    def topology(self) -> list[tuple[str, str]]:
        return sorted(
            (
                entry["name"],
                "directory" if entry["attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY else "file",
            )
            for entry in self.entries
        )

    def select_read_order(
        self,
        names: Sequence[str],
        *,
        require_sorted: bool = True,
    ) -> None:
        selected = list(names)
        if self.read_count != 0:
            raise ValueError("retained read order is already active")
        if len(selected) != len(set(selected)) or (
            require_sorted and selected != sorted(selected)
        ):
            raise ValueError("retained read selection order is not exact")
        if any(name not in self.files for name in selected):
            raise ValueError("retained read selection includes a non-file")
        self.read_order = selected

    def read_file(
        self,
        relative: str,
        *,
        on_read_failure: Callable[
            ["R11TraversalDiagnostic", dict[str, Any] | None], BaseException
        ] | None = None,
    ) -> bytes:
        expected_order = self.read_order
        if self.read_count >= len(expected_order) or relative != expected_order[self.read_count]:
            raise ValueError("retained file reads must follow exact sorted FILETOKEN order")
        child = self.files[relative]
        if not child["handle"]:
            raise ValueError("retained file handle has no owner")

        def transfer() -> None:
            child["handle"] = 0

        raw = _r11_read_fd(
            child["handle"],
            depth=child["component_index"],
            token=child["path_token"],
            before_identity=child["identity"],
            before_attributes=child["attributes"],
            before_size=child["size"],
            transfer_owner=transfer,
            on_read_failure=on_read_failure,
        )
        try:
            for ancestor in reversed(child["ancestors"]):
                _r11_assert_directory_stable(
                    ancestor["handle"], ancestor["identity"], ancestor["attributes"],
                    root=ancestor["root"],
                    component_index=ancestor["component_index"],
                    path_token=None if ancestor["root"] else ancestor["path_token"],
                )
        except R11TraversalDiagnostic as diagnostic:
            if on_read_failure is None:
                raise
            raise on_read_failure(diagnostic, None)
        self.read_count += 1
        return raw

    def close(self, *, primary: BaseException | None = None) -> None:
        cleanup: BaseException | None = None
        for item in reversed(self.owned):
            handle = item["handle"]
            if not handle:
                continue
            item["handle"] = 0
            try:
                _r11_close_traversal_handle(
                    handle,
                    code="TRAVERSAL_ROOT_HANDLE_CLOSE" if item["root"] else "TRAVERSAL_HANDLE_CLOSE",
                    operation="close_root" if item["root"] else "close_child",
                    component_index=None if item["root"] else item["component_index"],
                    path_token=None if item["root"] else item["path_token"],
                    identity_before=item["identity"],
                )
            except BaseException as exc:
                if cleanup is None:
                    cleanup = exc
        if primary is None and cleanup is not None:
            raise cleanup

    def __enter__(self) -> "R11RetainedTree":
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: Any,
    ) -> None:
        del exc_type, traceback
        self.close(primary=exc)


def r11_native_read(
    path: Path | str,
    selected_file_token: str,
    *,
    on_lookup_failure: Callable[
        ["R11TraversalDiagnostic", dict[str, Any] | None], BaseException
    ] | None = None,
    on_read_failure: Callable[
        ["R11TraversalDiagnostic", dict[str, Any] | None], BaseException
    ] | None = None,
) -> tuple[bytes, str, dict[str, str]]:
    _r11_validate_filetoken(selected_file_token)
    root_path, components, _ = _r11_absolute_parts(path)
    if not components:
        raise R11TraversalDiagnostic("PATH_NOT_LOCAL_DRIVE_ABSOLUTE", "lexical_validate")
    retained: list[tuple[int, dict[str, str], int, int | None, str | None]] = []
    root_handle, root_identity, root_attributes, _ = _r11_open_child(
        root_path, directory=True, depth=None, token=None,
        parent_identity=None, root=True,
    )
    retained.append((root_handle, root_identity, root_attributes, None, None))
    parent_path = root_path
    parent_identity = root_identity
    parent_token = selected_file_token
    primary: BaseException | None = None
    read_boundary_started = False
    try:
        for depth, component in enumerate(components):
            requested_token = selected_file_token
            records = _r11_find_snapshot(
                parent_path, root=(depth == 0), parent_token=parent_token,
                parent_identity=parent_identity,
                mode="inventory" if depth == 0 else "lookup",
                requested_token=None if depth == 0 else requested_token,
                requested_depth=None if depth == 0 else depth,
            )
            _r11_assert_directory_stable(
                retained[-1][0], parent_identity, retained[-1][2], root=(depth == 0),
                component_index=None if depth == 0 else depth - 1,
                path_token=None if depth == 0 else parent_token,
            )
            record = _r11_lookup_record(
                records, component, requested_token=requested_token, depth=depth,
                parent_identity=parent_identity, parent_token=parent_token,
            )
            if record["attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ENTRY_REPARSE", "validate_selected_entry",
                    component_index=depth, path_token=requested_token,
                    actual_attributes=record["attributes"], identity_before=parent_identity,
                )
            child_path = parent_path + ("" if parent_path.endswith("\\") else "\\") + record["long_name"]
            expected_directory = depth < len(components) - 1
            child_handle, child_identity, child_attributes, child_size = _r11_open_child(
                child_path, directory=expected_directory, depth=depth,
                token=requested_token, parent_identity=parent_identity,
            )
            try:
                _r11_assert_directory_stable(
                    retained[-1][0], parent_identity, retained[-1][2],
                    root=(depth == 0),
                    component_index=None if depth == 0 else depth - 1,
                    path_token=None if depth == 0 else parent_token,
                )
            except BaseException as parent_failure:
                try:
                    _r11_close_traversal_handle(
                        child_handle, code="TRAVERSAL_HANDLE_CLOSE",
                        operation="close_child", component_index=depth,
                        path_token=requested_token, identity_before=child_identity,
                    )
                except BaseException:
                    pass
                raise parent_failure
            if expected_directory:
                retained.append((child_handle, child_identity, child_attributes, depth, requested_token))
                parent_path = child_path
                parent_identity = child_identity
                parent_token = requested_token
                continue
            leaf_handle = child_handle

            def transfer_leaf_owner() -> None:
                nonlocal leaf_handle
                leaf_handle = 0

            leaf_primary: BaseException | None = None
            try:
                read_boundary_started = True
                raw = _r11_read_fd(
                    leaf_handle, depth=depth, token=requested_token,
                    before_identity=child_identity,
                    before_attributes=child_attributes,
                    before_size=child_size,
                    transfer_owner=transfer_leaf_owner,
                    on_read_failure=on_read_failure,
                )
            except BaseException as exc:
                leaf_primary = exc
                raise
            finally:
                if leaf_handle:
                    try:
                        _r11_close_traversal_handle(
                            leaf_handle, code="TRAVERSAL_HANDLE_CLOSE",
                            operation="close_child", component_index=depth,
                            path_token=requested_token,
                            identity_before=child_identity,
                        )
                    except BaseException:
                        if leaf_primary is None:
                            raise
            try:
                _r11_assert_directory_stable(
                    retained[-1][0], parent_identity, retained[-1][2],
                    root=(depth == 0),
                    component_index=None if depth == 0 else depth - 1,
                    path_token=None if depth == 0 else parent_token,
                )
            except R11TraversalDiagnostic as diagnostic:
                if on_read_failure is None:
                    raise
                raise on_read_failure(diagnostic, None)
            return raw, selected_file_token, child_identity
        raise AssertionError("unreachable native leaf state")
    except BaseException as exc:
        if isinstance(exc, R11TraversalDiagnostic):
            if read_boundary_started and on_read_failure is not None:
                primary = on_read_failure(exc, None)
                raise primary
            if on_lookup_failure is not None:
                primary = on_lookup_failure(exc, None)
                raise primary
        primary = exc
        raise
    finally:
        cleanup: BaseException | None = None
        for handle, identity, _attributes, depth, token in reversed(retained):
            try:
                _r11_close_traversal_handle(
                    handle,
                    code="TRAVERSAL_ROOT_HANDLE_CLOSE" if depth is None else "TRAVERSAL_HANDLE_CLOSE",
                    operation="close_root" if depth is None else "close_child",
                    component_index=depth, path_token=token,
                    identity_before=identity,
                )
            except BaseException as exc:
                if cleanup is None:
                    cleanup = exc
        if primary is None and cleanup is not None:
            if not isinstance(cleanup, R11TraversalDiagnostic):
                raise cleanup
            if read_boundary_started and on_read_failure is not None:
                raise on_read_failure(cleanup, None)
            if on_lookup_failure is not None:
                raise on_lookup_failure(cleanup, None)
            raise cleanup


def r11_native_directory_receipt(
    path: Path | str,
    retained_directory_token: str,
) -> tuple[str, dict[str, str]]:
    _r11_validate_filetoken(retained_directory_token)
    root_path, components, _ = _r11_absolute_parts(path)
    retained: list[tuple[int, dict[str, str], int, int | None, str | None]] = []
    root_handle, root_identity, root_attributes, _ = _r11_open_child(
        root_path, directory=True, depth=None, token=None,
        parent_identity=None, root=True,
    )
    retained.append((root_handle, root_identity, root_attributes, None, None))
    parent_path = root_path
    parent_identity = root_identity
    parent_token = retained_directory_token
    primary: BaseException | None = None
    try:
        if not components:
            return retained_directory_token, root_identity
        for depth, component in enumerate(components):
            requested_token = retained_directory_token
            records = _r11_find_snapshot(
                parent_path, root=(depth == 0), parent_token=parent_token,
                parent_identity=parent_identity,
                mode="inventory" if depth == 0 else "lookup",
                requested_token=None if depth == 0 else requested_token,
                requested_depth=None if depth == 0 else depth,
            )
            _r11_assert_directory_stable(
                retained[-1][0], parent_identity, retained[-1][2], root=(depth == 0),
                component_index=None if depth == 0 else depth - 1,
                path_token=None if depth == 0 else parent_token,
            )
            record = _r11_lookup_record(
                records, component, requested_token=requested_token, depth=depth,
                parent_identity=parent_identity, parent_token=parent_token,
            )
            if record["attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
                raise R11TraversalDiagnostic(
                    "TRAVERSAL_ENTRY_REPARSE", "validate_selected_entry",
                    component_index=depth, path_token=requested_token,
                    actual_attributes=record["attributes"],
                    identity_before=parent_identity,
                )
            child_path = parent_path + ("" if parent_path.endswith("\\") else "\\") + record["long_name"]
            child_handle, child_identity, child_attributes, _ = _r11_open_child(
                child_path, directory=True, depth=depth,
                token=requested_token, parent_identity=parent_identity,
            )
            try:
                _r11_assert_directory_stable(
                    retained[-1][0], parent_identity, retained[-1][2],
                    root=(depth == 0),
                    component_index=None if depth == 0 else depth - 1,
                    path_token=None if depth == 0 else parent_token,
                )
            except BaseException as parent_failure:
                try:
                    _r11_close_traversal_handle(
                        child_handle, code="TRAVERSAL_HANDLE_CLOSE",
                        operation="close_child", component_index=depth,
                        path_token=requested_token, identity_before=child_identity,
                    )
                except BaseException:
                    pass
                raise parent_failure
            retained.append((child_handle, child_identity, child_attributes, depth, requested_token))
            parent_path = child_path
            parent_identity = child_identity
            parent_token = requested_token
        return retained_directory_token, parent_identity
    except BaseException as exc:
        primary = exc
        raise
    finally:
        cleanup: BaseException | None = None
        for handle, identity, _attributes, depth, token in reversed(retained):
            try:
                _r11_close_traversal_handle(
                    handle,
                    code="TRAVERSAL_ROOT_HANDLE_CLOSE" if depth is None
                    else "TRAVERSAL_HANDLE_CLOSE",
                    operation="close_root" if depth is None else "close_child",
                    component_index=depth, path_token=token,
                    identity_before=identity,
                )
            except BaseException as exc:
                if cleanup is None:
                    cleanup = exc
        if primary is None and cleanup is not None:
            raise cleanup


def windows_file_receipt(
    path: Path,
    label: str,
    *,
    directory: bool = False,
    path_token: str | None = None,
) -> dict[str, Any]:
    selected_token = _r11_validate_filetoken(label if path_token is None else path_token)
    if directory:
        token, identity = r11_native_directory_receipt(path, selected_token)
        return {
            "path": str(path), "identity": identity,
            "byte_count": None, "sha256": None, "path_token": token,
        }
    raw, token, identity = r11_native_read(path, selected_token)
    return {
        "path": str(path), "identity": identity,
        "byte_count": len(raw), "sha256": sha256_bytes(raw),
        "path_token": token,
    }


def validate_absolute_ordinary_path(
    value: Path,
    label: str,
    *,
    directory: bool,
) -> Path:
    _r11_absolute_parts(value)
    # The authoritative open/read follows the cumulative no-follow primitive;
    # this function preserves the lexical Path only and never normalizes it.
    return Path(str(value))


def _r11_key_authority(*keys: str) -> tuple[str, ...]:
    if any(type(key) is not str for key in keys):
        raise TypeError("mapping key authority contains a non-string key")
    authority = tuple(sorted(keys))
    if len(authority) != len(set(authority)):
        raise ValueError("mapping key authority contains a duplicate key")
    return authority


def _r11_validate_mapping_authority(
    value: Any,
    authority: tuple[str, ...],
    label: str,
) -> dict[str, Any]:
    if (
        not isinstance(value, dict)
        or any(type(key) is not str for key in value)
        or tuple(sorted(value)) != authority
    ):
        raise ValueError(f"{label} key schema mismatch")
    return value


R11_FORGE_VERSION_IDENTITY_SHA256 = (
    "sha256:4a226eb02b8228b5f324dcf749783a80ffccf62f7368a5512d2d1cf58c30eb68"
)
R11_RESULT_KEYS = _r11_key_authority(
    "groups",
    "source_union",
    "target_evaluations",
    "artifacts",
    "aggregates",
    "output_files",
    "output_installed",
    "output_quarantine_without_matching_go",
    "temporary_root",
)
R11_FIRST_RED_KEYS = _r11_key_authority(
    "phase",
    "code",
    "call_ordinal",
    "group_index",
    "group_string",
    "semantic_id",
    "target",
    "step_ordinal",
    "step_id",
    "operands",
)
R11_GROUP_INDEX_BY_SOURCE = {
    group["source"]: int(group["group"]) for group in R4_GROUPS
}
R11_TARGET_BY_NAME = {
    authority["target"]: authority for authority in R4_TARGET_AUTHORITIES
}
R11_BYTECODE_FALSE_CODES = {
    1: ("BC_CREATION_MISSING", "BC_CREATION_NOT_OBJECT"),
    2: ("BC_CREATION_OBJECT_MISSING", "BC_CREATION_OBJECT_NOT_STRING"),
    4: ("BC_CREATION_EMPTY",),
    5: ("BC_CREATION_ODD_LENGTH",),
    6: ("BC_CREATION_UNRESOLVED_PLACEHOLDER",),
    7: ("BC_CREATION_NON_HEX",),
    8: (
        "BC_CREATION_LINKS_MISSING", "BC_CREATION_LINKS_NOT_OBJECT",
        "BC_CREATION_LINKS_NONEMPTY",
    ),
    9: ("BC_RUNTIME_MISSING", "BC_RUNTIME_NOT_OBJECT"),
    10: ("BC_RUNTIME_OBJECT_MISSING", "BC_RUNTIME_OBJECT_NOT_STRING"),
    12: ("BC_RUNTIME_EMPTY",),
    13: ("BC_RUNTIME_ODD_LENGTH",),
    14: ("BC_RUNTIME_UNRESOLVED_PLACEHOLDER",),
    15: ("BC_RUNTIME_NON_HEX",),
    16: (
        "BC_RUNTIME_LINKS_MISSING", "BC_RUNTIME_LINKS_NOT_OBJECT",
        "BC_RUNTIME_LINKS_NONEMPTY",
    ),
    17: ("ABI_NOT_ARRAY", "ABI_CONSTRUCTOR_COUNT", "ABI_CONSTRUCTOR_TYPES_ORDER"),
    19: (
        "ABI_CONSTRUCTOR_SIGNATURE", "ABI_CONSTRUCTOR_WORDS",
        "ABI_CONSTRUCTOR_WIDTH",
    ),
    22: ("SIZE_INITCODE_LIMIT",),
    24: ("SIZE_RUNTIME_PACKET_LIMIT",),
    25: ("SIZE_RUNTIME_TARGET_CAP",),
}
R11_SERIALIZABLE_CODES = frozenset(
    {
        "COMPILER_IDENTITY_CHECKPOINT_MISMATCH",
        "FORGE_NONZERO_EXIT",
        "FORGE_VERSION_UTF8",
        "FORGE_VERSION_EMPTY",
        "FORGE_VERSION_FORMAT",
        "FORGE_VERSION_MISMATCH",
        "FORGE_VERSION_TIMESTAMP_COUNT",
        "GROUP_STRING_MISMATCH",
        "GROUP_CLOSURE_MISMATCH",
        "GROUP_SOURCE_CONTENT",
        "GROUP_SOURCE_BYTES_MISMATCH",
        "PORTABLE_INPUT_BUILD_INFO_COUNT",
        "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION",
        "PORTABLE_INPUT_BUILD_INFO_READ",
        "PORTABLE_INPUT_BUILD_INFO_JSON",
        "PORTABLE_INPUT_PATH_BINDING",
        "PORTABLE_INPUT_PATH_CANONICAL",
        "PORTABLE_INPUT_LANGUAGE",
        "PORTABLE_INPUT_SOURCES",
        "PORTABLE_INPUT_SOURCE_ENTRY",
        "PORTABLE_INPUT_SOURCE_PATH",
        "PORTABLE_INPUT_SOURCE_READ",
        "PORTABLE_INPUT_SOURCE_UTF8",
        "PORTABLE_INPUT_SOURCE_CONTENT",
        "PORTABLE_INPUT_VIA_IR",
        "PORTABLE_INPUT_EVM_VERSION",
        "PORTABLE_INPUT_OPTIMIZER",
        "PORTABLE_INPUT_METADATA",
        "OP_RETAINED_INPUT_WRITE_EXCEPTION",
        "ARTIFACT_FILE_READ",
        "ARTIFACT_FILE_IDENTITY_MISMATCH",
        "ARTIFACT_JSON_DECODE",
        "METADATA_TARGET_AND_PATH",
        "METADATA_ARTIFACT_OBJECT_AND_HASH",
        "METADATA_OBJECT",
        "METADATA_COMPILER_VERSION",
        "METADATA_COMPILATION_TARGET",
        "METADATA_VIA_IR",
        "METADATA_EVM_PARIS",
        "METADATA_OPTIMIZER_200",
        "METADATA_NO_HASH_NO_CBOR",
        "METADATA_SOURCE_BINDING",
        "METADATA_BUILD_BINDING",
        "SOURCE_UNION_CONFLICT",
        "SOURCE_UNION_MISMATCH",
        "AGGREGATE_MEMBER_MISSING",
        "AGG_G3_RUNTIME",
        "AGG_G3_DEPOSIT",
        "AGG_G7_RUNTIME",
        "AGG_G7_DEPOSIT",
        "AGG_G8_READ_RUNTIME",
        "AGG_G8_READ_DEPOSIT",
        "AGG_G8_EIGHT_RUNTIME",
        "AGG_G8_EIGHT_DEPOSIT",
        "AGG_G11_VERIFIER_RUNTIME",
        "AGG_G11_FULL_INITCODE",
        "AGG_G11_DEPOSIT",
        "STAGED_VALIDATION_FAILED",
        "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION",
        "OP_BUILD_TEMP_CLEANUP_EXCEPTION",
        "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION",
        "OP_INSTALLED_OUTPUT_READ_EXCEPTION",
        "OUTPUT_TOPOLOGY_MISMATCH",
        "OUTPUT_BYTES_MISMATCH",
    }
    | {code for codes in R11_BYTECODE_FALSE_CODES.values() for code in codes}
    | {
        f"OP_{BYTECODE_STEPS[index - 1]}_EXCEPTION"
        for index in (3, 11, 18, 20, 21, 23, 26)
    }
)


class R11BuilderFailure(EvidenceFailure):
    """A closed, context-complete builder NO_GO boundary."""

    def __init__(self, first_red: dict[str, Any]) -> None:
        _r11_validate_mapping_authority(
            first_red, R11_FIRST_RED_KEYS, "R11 first red",
        )
        super().__init__(
            require_string(first_red["code"], "first_red.code"),
            "closed R11 builder boundary failed",
            operands=require_dict(first_red["operands"], "first_red.operands"),
        )
        self.first_red = first_red


def _r11_first_red(
    code: str,
    phase: str,
    operands: dict[str, Any],
    *,
    call_ordinal: int | None = None,
    group_index: int | None = None,
    authority: dict[str, Any] | None = None,
    step_ordinal: int | None = None,
) -> R11BuilderFailure:
    if group_index is None and authority is not None:
        group_index = R11_GROUP_INDEX_BY_SOURCE[authority["source"]]
    group_string = (
        None if group_index is None else R4_GROUPS[group_index]["group_string"]
    )
    return R11BuilderFailure(
        {
            "phase": phase,
            "code": code,
            "call_ordinal": call_ordinal,
            "group_index": group_index,
            "group_string": group_string,
            "semantic_id": None if authority is None else authority["semantic_id"],
            "target": None if authority is None else authority["target"],
            "step_ordinal": step_ordinal,
            "step_id": None if step_ordinal is None else BYTECODE_STEPS[step_ordinal - 1],
            "operands": dict(operands),
        }
    )


def _r11_diagnostic_digest(diagnostic: R11TraversalDiagnostic) -> str:
    value = {"code": diagnostic.code, "operands": diagnostic.operands}
    return sha256_bytes(canonical_evidence_bytes(value))


def _r11_u53(value: Any) -> bool:
    return type(value) is int and 0 <= value <= 9_007_199_254_740_991


def _r11_dword(value: Any) -> bool:
    return type(value) is int and 0 <= value <= 0xFFFFFFFF


def _r11_identity_value(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and tuple(value) == ("volume_serial", "file_index")
        and isinstance(value["volume_serial"], str)
        and re.fullmatch(r"[0-9A-F]{8}", value["volume_serial"]) is not None
        and isinstance(value["file_index"], str)
        and re.fullmatch(r"[0-9A-F]{16}", value["file_index"]) is not None
    )


def _r11_durable_identity_value(value: Any) -> bool:
    try:
        identity = _r11_validate_mapping_authority(
            value,
            _r11_key_authority("volume_serial", "file_index"),
            "durable identity",
        )
    except ValueError:
        return False
    return (
        isinstance(identity["volume_serial"], str)
        and re.fullmatch(r"[0-9A-F]{8}", identity["volume_serial"]) is not None
        and isinstance(identity["file_index"], str)
        and re.fullmatch(r"[0-9A-F]{16}", identity["file_index"]) is not None
    )


_R11_DIAGNOSTIC_ROWS: dict[str, tuple[tuple[str, frozenset[str]], ...]] = {
    "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": (("lexical_validate", frozenset()),),
    "PATH_DEVICE_NAMESPACE": (("namespace_validate", frozenset()),),
    "PATH_UNSUPPORTED_DRIVE_TYPE": (("drive_type", frozenset(("expected_attributes", "actual_attributes"))),),
    "TRAVERSAL_ROOT_OPEN": (("open_root", frozenset(("winerror",))),),
    "TRAVERSAL_ROOT_REPARSE": (("validate_root", frozenset(("actual_attributes", "identity_before"))),),
    "TRAVERSAL_ROOT_NOT_DIRECTORY": (("validate_root", frozenset(("expected_attributes", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_ROOT_ENUM_OPEN": (("enum_root_open", frozenset(("winerror", "identity_before"))),),
    "TRAVERSAL_ROOT_ENUM_NEXT": (("enum_root_next", frozenset(("winerror", "identity_before"))),),
    "TRAVERSAL_ROOT_ENUM_CLOSE": (("enum_root_close", frozenset(("winerror", "identity_before"))),),
    "TRAVERSAL_ROOT_ENTRY_NAME": (("validate_root_entry", frozenset(("component_index", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_ROOT_ENTRY_COLLISION": (("validate_root_entry", frozenset(("component_index", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_ROOT_IDENTITY_CHANGED": (("revalidate_root", frozenset(("expected_attributes", "actual_attributes", "identity_before", "identity_after"))),),
    "TRAVERSAL_ROOT_HANDLE_CLOSE": (("close_root", frozenset(("winerror", "identity_before"))),),
    "TRAVERSAL_ENUM_OPEN": (
        ("enum_child_open", frozenset(("component_index", "path_token", "winerror", "identity_before"))),
    ),
    "TRAVERSAL_ENUM_NEXT": (
        ("enum_child_next", frozenset(("component_index", "path_token", "winerror", "identity_before"))),
    ),
    "TRAVERSAL_ENUM_CLOSE": (
        ("enum_child_close", frozenset(("component_index", "path_token", "winerror", "identity_before"))),
    ),
    "TRAVERSAL_ENTRY_NAME": (
        ("validate_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
        ("validate_inventory_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
    ),
    "TRAVERSAL_ENTRY_COLLISION": (
        ("validate_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
        ("validate_inventory_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
    ),
    "TRAVERSAL_COMPONENT_MISSING": (("resolve_component", frozenset(("component_index", "path_token", "identity_before"))),),
    "TRAVERSAL_COMPONENT_CASE_MISMATCH": (("resolve_component", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_COMPONENT_SHORT_ALIAS": (("resolve_component", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_ENTRY_REPARSE": (
        ("validate_selected_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
        ("validate_inventory_entry", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),
    ),
    "TRAVERSAL_CHILD_OPEN": (("open_child", frozenset(("component_index", "path_token", "winerror", "expected_attributes", "identity_before"))),),
    "TRAVERSAL_CHILD_REPARSE": (("validate_open_child", frozenset(("component_index", "path_token", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_CHILD_TYPE_CHANGED": (("validate_open_child", frozenset(("component_index", "path_token", "expected_attributes", "actual_attributes", "identity_before"))),),
    "TRAVERSAL_IDENTITY_CHANGED": (("revalidate_child", frozenset(("component_index", "path_token", "expected_attributes", "actual_attributes", "identity_before", "identity_after"))),),
    "TRAVERSAL_READ": (
        ("read_child", frozenset(("component_index", "path_token", "winerror", "identity_before"))),
        ("read_child", frozenset(("component_index", "path_token", "identity_before"))),
    ),
    "TRAVERSAL_HANDLE_CLOSE": (("close_child", frozenset(("component_index", "path_token", "winerror", "identity_before"))),),
}


_R11_RECORD_PROOF_CODES = frozenset(
    (
        "TRAVERSAL_ROOT_ENTRY_NAME",
        "TRAVERSAL_ROOT_ENTRY_COLLISION",
        "TRAVERSAL_ENTRY_NAME",
        "TRAVERSAL_ENTRY_COLLISION",
        "TRAVERSAL_COMPONENT_MISSING",
        "TRAVERSAL_COMPONENT_CASE_MISMATCH",
        "TRAVERSAL_COMPONENT_SHORT_ALIAS",
    )
)


def _r11_validate_attached_record_proof(
    diagnostic: R11TraversalDiagnostic,
) -> None:
    proof = diagnostic.record_proof
    if not isinstance(proof, R11CopiedRecordProof):
        raise ValueError("record-dependent diagnostic has no immutable copied proof")
    if proof.code != diagnostic.code or proof.operation != diagnostic.operands["operation"]:
        raise ValueError("record proof diagnostic binding differs")
    _r11_validate_requested_depth_authority(
        root=proof.root,
        inventory=proof.inventory,
        requested_depth=proof.requested_depth,
    )
    if (
        not proof.root
        and not proof.inventory
        and proof.requested_depth != diagnostic.operands["component_index"]
    ):
        raise ValueError("lookup record proof depth differs from diagnostic component")
    records = [_r11_thaw_copied_record(record) for record in proof.records]
    if proof.records_sha256 != _r11_copied_record_multiset_sha256(records):
        raise ValueError("record proof copied-record multiset commitment differs")
    parent_identity = {
        "volume_serial": proof.parent_identity[0],
        "file_index": proof.parent_identity[1],
    }
    if proof.code == "TRAVERSAL_COMPONENT_MISSING":
        if proof.winner is not None or proof.requested_component is None:
            raise ValueError("missing proof winner/component is not exact")
        expected = _r11_missing_record_diagnostic(
            records=records,
            requested_component=proof.requested_component,
            requested_depth=proof.requested_depth,
            requested_token=proof.requested_token,
            parent_token=proof.parent_token,
            parent_identity=parent_identity,
            _skip_proof_validation=True,
        )
    else:
        if proof.winner is None:
            raise ValueError("record proof has no winner")
        expected = _r11_record_backed_diagnostic(
            proof.code,
            proof.operation,
            records=records,
            winner=_r11_thaw_copied_record(proof.winner),
            root=proof.root,
            inventory=proof.inventory,
            requested_depth=proof.requested_depth,
            requested_token=proof.requested_token,
            parent_token=proof.parent_token,
            parent_identity=parent_identity,
            requested_component=proof.requested_component,
            observed_winner_token=proof.observed_winner_token,
            _skip_proof_validation=True,
        )
    if expected.operands != diagnostic.operands or expected.record_proof != proof:
        raise ValueError("record-dependent diagnostic does not reconstruct exactly")


def r11_validate_diagnostic(diagnostic: R11TraversalDiagnostic) -> None:
    if type(diagnostic) is not R11TraversalDiagnostic:
        raise TypeError("diagnostic must be the exact closed R11 type")
    operands = diagnostic.operands
    if type(operands) is not dict or tuple(operands) != (
        "operation", "component_index", "path_token", "winerror",
        "expected_attributes", "actual_attributes", "identity_before",
        "identity_after",
    ):
        raise ValueError("diagnostic operand schema mismatch")
    if type(operands["operation"]) is not str:
        raise ValueError("diagnostic operation is not an exact string")
    nonnull = frozenset(key for key, value in operands.items() if key != "operation" and value is not None)
    rows = _R11_DIAGNOSTIC_ROWS.get(diagnostic.code, ())
    if (operands["operation"], nonnull) not in rows:
        raise ValueError("diagnostic operation/nullability mismatch")
    index = operands["component_index"]
    if index is not None and not _r11_u53(index):
        raise ValueError("diagnostic component index is not U53")
    token = operands["path_token"]
    if token is not None:
        _r11_validate_filetoken(token)
    winerror = operands["winerror"]
    if winerror is not None and not (type(winerror) is int and 1 <= winerror <= 0xFFFFFFFF):
        raise ValueError("diagnostic Winerror is not a positive DWORD")
    for key in ("expected_attributes", "actual_attributes"):
        value = operands[key]
        if value is not None and not _r11_dword(value):
            raise ValueError("diagnostic attribute is not a DWORD")
    for key in ("identity_before", "identity_after"):
        value = operands[key]
        if value is not None and (
            type(value) is not dict or not _r11_identity_value(value)
        ):
            raise ValueError("diagnostic identity is malformed")
    if diagnostic.code in _R11_RECORD_PROOF_CODES:
        _r11_validate_attached_record_proof(diagnostic)
    elif diagnostic.record_proof is not None:
        raise ValueError("non-record diagnostic carries a copied-record proof")
    if diagnostic.code.startswith("TRAVERSAL_ROOT_"):
        if operands["path_token"] is not None:
            raise ValueError("root diagnostic cannot carry a path token")
        root_entry = diagnostic.code in (
            "TRAVERSAL_ROOT_ENTRY_NAME", "TRAVERSAL_ROOT_ENTRY_COLLISION",
        )
        if root_entry != (operands["component_index"] is not None):
            raise ValueError("root diagnostic index is not exact")
        if root_entry and operands["component_index"] != 0:
            raise ValueError("root invalid/collision diagnostic index is not frozen zero")
    if diagnostic.code == "PATH_UNSUPPORTED_DRIVE_TYPE" and operands["expected_attributes"] != _R11_DRIVE_FIXED:
        raise ValueError("drive diagnostic expected value is not DRIVE_FIXED")
    if diagnostic.code in ("TRAVERSAL_ROOT_NOT_DIRECTORY",) and operands["expected_attributes"] != _R11_FILE_ATTRIBUTE_DIRECTORY:
        raise ValueError("root kind diagnostic expected value is not DIRECTORY")
    if diagnostic.code in (
        "TRAVERSAL_ROOT_REPARSE", "TRAVERSAL_ENTRY_REPARSE", "TRAVERSAL_CHILD_REPARSE",
    ) and not operands["actual_attributes"] & _R11_FILE_ATTRIBUTE_REPARSE_POINT:
        raise ValueError("reparse diagnostic lacks the reparse attribute")
    if diagnostic.code == "TRAVERSAL_ROOT_NOT_DIRECTORY" and operands["actual_attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY:
        raise ValueError("root not-directory diagnostic reports a directory")
    if diagnostic.code == "TRAVERSAL_CHILD_TYPE_CHANGED":
        expected_directory = bool(operands["expected_attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY)
        actual_directory = bool(operands["actual_attributes"] & _R11_FILE_ATTRIBUTE_DIRECTORY)
        if expected_directory == actual_directory:
            raise ValueError("child type-change diagnostic has equal kinds")
    if diagnostic.code in (
        "TRAVERSAL_ROOT_IDENTITY_CHANGED", "TRAVERSAL_IDENTITY_CHANGED",
    ):
        expected = operands["expected_attributes"]
        actual = operands["actual_attributes"]
        if diagnostic.code == "TRAVERSAL_ROOT_IDENTITY_CHANGED" and (
            operands["identity_before"] == operands["identity_after"]
            and actual == expected
        ):
            raise ValueError("identity diagnostic describes no change")
    if diagnostic.code == "TRAVERSAL_READ":
        os_failure = operands["winerror"] is not None
        if os_failure != (nonnull == frozenset(("component_index", "path_token", "winerror", "identity_before"))):
            raise ValueError("read diagnostic Winerror branch is not exact")


_R11_BOUNDARY_STATE_KEYS = {
    "EVIDENCE_CONTROL": ("started", "candidate_terminal"),
    "PORTABLE_BUILD_INFO_LOOKUP": ("group_index", "count_complete", "actual_count"),
    "PORTABLE_BUILD_INFO_READ": ("group_index", "selected_file_token"),
    "PORTABLE_SOURCE_LOOKUP": ("group_index", "source_path"),
    "PORTABLE_SOURCE_READ": ("group_index", "source_path"),
    "ARTIFACT_LOOKUP": ("group_index", "semantic_id", "target", "metadata_evaluated", "item1_passed"),
    "ARTIFACT_READ": ("group_index", "semantic_id", "target", "item1_passed", "selected_artifact_token", "read_state"),
    "STAGED_OUTPUT_VALIDATE": ("prefix",),
    "OUTPUT_INSTALL": ("prefix",),
    "TEMP_CLEANUP": ("prefix",),
    "INSTALLED_INVENTORY": ("prefix", "selected_file_token"),
    "INSTALLED_READ": ("prefix", "selected_file_token"),
    "RECOVERY_INVENTORY": ("recovery",),
}


def _r11_validate_read_state(
    value: Any,
    diagnostic: R11TraversalDiagnostic,
) -> bool:
    if not isinstance(value, dict) or tuple(value) != (
        "before_identity", "after_identity", "before_size", "after_size",
        "read_byte_count",
    ):
        return False
    if not _r11_identity_value(value["before_identity"]) or not _r11_identity_value(value["after_identity"]):
        return False
    if not all(_r11_u53(value[key]) for key in ("before_size", "after_size", "read_byte_count")):
        return False
    operands = diagnostic.operands
    if (
        value["before_identity"] != operands["identity_before"]
        or value["after_identity"] != operands["identity_after"]
    ):
        return False
    return (
        value["before_identity"] != value["after_identity"]
        or value["before_size"] != value["after_size"]
        or value["read_byte_count"] != value["before_size"]
        or operands["expected_attributes"] != operands["actual_attributes"]
    )


def _r11_validate_boundary_state(boundary: str, state: dict[str, Any]) -> dict[str, Any] | None:
    if not isinstance(state, dict) or tuple(state) != _R11_BOUNDARY_STATE_KEYS[boundary]:
        raise ValueError("boundary state schema mismatch")
    if boundary == "EVIDENCE_CONTROL":
        if any(type(state[key]) is not bool for key in state):
            raise ValueError("EC state gates must be booleans")
        return None
    if boundary == "PORTABLE_BUILD_INFO_LOOKUP":
        if not _r11_u53(state["group_index"]) or state["group_index"] > 16:
            raise ValueError("BL group index is outside 0..16")
        if type(state["count_complete"]) is not bool:
            raise ValueError("BL count gate is not boolean")
        if state["count_complete"] != (state["actual_count"] is not None):
            raise ValueError("BL count nullability is not exact")
        if state["actual_count"] is not None and not _r11_u53(state["actual_count"]):
            raise ValueError("BL actual count is not U53")
        return None
    if boundary == "PORTABLE_BUILD_INFO_READ":
        if not _r11_u53(state["group_index"]) or state["group_index"] > 16:
            raise ValueError("BR group index is outside 0..16")
        selected = _r11_validate_filetoken(state["selected_file_token"])
        if not selected.startswith(f"build-info/{state['group_index']:03d}/"):
            raise ValueError("BR selected token is not joined to its group root")
        return None
    if boundary in ("PORTABLE_SOURCE_LOOKUP", "PORTABLE_SOURCE_READ"):
        group_index = state["group_index"]
        if not _r11_u53(group_index) or group_index > 16:
            raise ValueError("source group index is outside 0..16")
        if state["source_path"] != R4_GROUPS[group_index]["source"]:
            raise ValueError("source boundary is not joined to its group")
        return None
    if boundary in ("ARTIFACT_LOOKUP", "ARTIFACT_READ"):
        group_index = state["group_index"]
        if not _r11_u53(group_index) or group_index > 16:
            raise ValueError("artifact group index is outside 0..16")
        authority = next(
            (
                item for item in R4_TARGET_AUTHORITIES
                if item["semantic_id"] == state["semantic_id"]
                and item["target"] == state["target"]
            ),
            None,
        )
        if authority is None or R11_GROUP_INDEX_BY_SOURCE[authority["source"]] != group_index:
            raise ValueError("artifact boundary is not joined to one authority row")
        if boundary == "ARTIFACT_LOOKUP":
            if state["metadata_evaluated"] is not True or state["item1_passed"] is not False:
                raise ValueError("AL does not own the pre-item-1 state")
        else:
            if state["item1_passed"] is not True:
                raise ValueError("AR does not own the post-item-1 state")
            selected = _r11_validate_filetoken(state["selected_artifact_token"])
            if selected != f"artifact/{authority['semantic_id']}.json":
                raise ValueError("AR selected token is not joined to its authority")
            read_state = state["read_state"]
            if read_state is not None:
                if not isinstance(read_state, dict) or tuple(read_state) != (
                    "before_identity", "after_identity", "before_size",
                    "after_size", "read_byte_count",
                ):
                    raise ValueError("AR read state schema is not exact")
                if (
                    not _r11_identity_value(read_state["before_identity"])
                    or not _r11_identity_value(read_state["after_identity"])
                    or not all(
                        _r11_u53(read_state[key])
                        for key in ("before_size", "after_size", "read_byte_count")
                    )
                ):
                    raise ValueError("AR read state member type is not exact")
        return authority
    if boundary == "STAGED_OUTPUT_VALIDATE":
        if state["prefix"] != "DONE":
            raise ValueError("SV prefix is not DONE")
        return None
    if boundary == "OUTPUT_INSTALL":
        if state["prefix"] != "STAGED":
            raise ValueError("OI prefix is not STAGED")
        return None
    if boundary == "TEMP_CLEANUP":
        if state["prefix"] != "INSTALLED":
            raise ValueError("TC prefix is not INSTALLED")
        return None
    if boundary == "INSTALLED_INVENTORY":
        if state != {"prefix": "CLEAN", "selected_file_token": None}:
            raise ValueError("II state is not exact CLEAN preselection")
        return None
    if boundary == "INSTALLED_READ":
        if state["prefix"] not in ("CLEAN", "READ_PARTIAL"):
            raise ValueError("IR prefix is not exact")
        selected = _r11_validate_filetoken(state["selected_file_token"])
        if not selected.startswith("installed/"):
            raise ValueError("IR token is not a full installed token")
        return None
    if boundary == "RECOVERY_INVENTORY":
        if state["recovery"] is not True:
            raise ValueError("RV state is not exact")
        return None
    raise AssertionError("unhandled exact R11 boundary")


def r11_translate_diagnostic(
    diagnostic: R11TraversalDiagnostic,
    boundary: str,
    state: dict[str, Any],
) -> R11BuilderFailure | dict[str, Any]:
    if boundary not in R11_BOUNDARY_IDS:
        raise ValueError("unknown R11 semantic boundary")
    r11_validate_diagnostic(diagnostic)
    authority = _r11_validate_boundary_state(boundary, state)
    cell = R11_INDUCED_MATRIX[diagnostic.code][boundary]
    digest = _r11_diagnostic_digest(diagnostic)
    dx = {"exception_type": diagnostic.code, "message_sha256": digest}
    if cell in ("X", "V"):
        raise diagnostic
    if cell == "R":
        return {
            "status": "invalid",
            "exception_type": diagnostic.code,
            "message_sha256": digest,
        }
    group_index = state.get("group_index")
    call_ordinal = None if group_index is None else group_index + 1
    if cell == "BLD":
        if state["count_complete"] and state["actual_count"] != 1:
            return _r11_first_red(
                "PORTABLE_INPUT_BUILD_INFO_COUNT", "portable_input",
                {"expected_count": 1, "actual_count": state["actual_count"]},
                call_ordinal=call_ordinal, group_index=group_index,
            )
        return _r11_first_red(
            "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION", "portable_input", dx,
            call_ordinal=call_ordinal, group_index=group_index,
        )
    if cell == "BIR":
        path_token = state["selected_file_token"]
        return _r11_first_red(
            "PORTABLE_INPUT_BUILD_INFO_READ", "portable_input",
            {"path_token": path_token, **dx},
            call_ordinal=call_ordinal, group_index=group_index,
        )
    if cell in ("SPA", "SPC", "SRD"):
        source_path = state["source_path"]
        if cell in ("SPA", "SPC"):
            return _r11_first_red(
                "PORTABLE_INPUT_SOURCE_PATH", "portable_input",
                {"source_path": source_path, "reason": "absent" if cell == "SPA" else "case_mismatch"},
                call_ordinal=call_ordinal, group_index=group_index,
            )
        return _r11_first_red(
            "PORTABLE_INPUT_SOURCE_READ", "portable_input",
            {"source_path": source_path, **dx},
            call_ordinal=call_ordinal, group_index=group_index,
        )
    metadata_reason = {
        "AM": "artifact_path_missing",
        "AA": "artifact_path_ambiguous",
        "AO": "artifact_path_not_ordinary",
        "ALF": "artifact_path_lookup_failure",
    }
    if cell in metadata_reason:
        assert authority is not None
        return _r11_first_red(
            "METADATA_TARGET_AND_PATH", "metadata_admission",
            {"item": 1, "reason": metadata_reason[cell]},
            call_ordinal=R11_GROUP_INDEX_BY_SOURCE[authority["source"]] + 1,
            authority=authority,
        )
    if cell in ("AFR", "ARI"):
        assert authority is not None
        operands: dict[str, Any] = dx
        code = "ARTIFACT_FILE_READ"
        read_state = state["read_state"]
        if cell == "ARI" and _r11_validate_read_state(read_state, diagnostic):
            operands = {
                "before_identity_sha256": sha256_bytes(canonical_evidence_bytes(read_state["before_identity"])),
                "after_identity_sha256": sha256_bytes(canonical_evidence_bytes(read_state["after_identity"])),
                "before_size": read_state["before_size"],
                "after_size": read_state["after_size"],
                "read_byte_count": read_state["read_byte_count"],
            }
            code = "ARTIFACT_FILE_IDENTITY_MISMATCH"
        return _r11_first_red(
            code, "artifact_file_read", operands,
            call_ordinal=R11_GROUP_INDEX_BY_SOURCE[authority["source"]] + 1,
            authority=authority,
        )
    if cell == "STG":
        return _r11_first_red(
            "STAGED_VALIDATION_FAILED", "staged_validation",
            {"cause_type": diagnostic.code, "message_sha256": digest},
        )
    if cell == "OII":
        return _r11_first_red(
            "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION", "installed_readback", dx,
        )
    if cell == "OIR":
        path_token = state["selected_file_token"]
        return _r11_first_red(
            "OP_INSTALLED_OUTPUT_READ_EXCEPTION", "installed_readback",
            {"path_token": path_token, **dx},
        )
    raise diagnostic


def _r11_json_type(value: Any, *, present: bool = True) -> str | None:
    if not present:
        return None
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    raise EvidenceFailure("NON_IJSON_ARTIFACT", "artifact contains a non-I-JSON value")


def r11_default_target_evaluations() -> list[dict[str, Any]]:
    records = []
    for ordinal, authority in enumerate(R4_TARGET_AUTHORITIES, start=1):
        records.append(
            {
                "semantic_id": authority["semantic_id"],
                "target": authority["target"],
                "source": authority["source"],
                "size_ordinal": ordinal,
                "emitting_group": f"{R11_GROUP_INDEX_BY_SOURCE[authority['source']]:03d}",
                "file_read": False,
                "artifact_byte_count": None,
                "artifact_sha256": None,
                "artifact_json_decoded": False,
                "metadata_evaluated": False,
                "metadata_admitted": False,
                "bytecode_evaluated": False,
                "bytecode_completed": False,
                "bytecode_steps": [],
            }
        )
    return records


def r11_initial_results() -> dict[str, Any]:
    return {
        "groups": [],
        "source_union": None,
        "target_evaluations": r11_default_target_evaluations(),
        "artifacts": [],
        "aggregates": [],
        "output_files": [],
        "output_installed": False,
        "output_quarantine_without_matching_go": False,
        "temporary_root": None,
    }


def _r11_exact_keys(value: Any, keys: tuple[str, ...], label: str) -> dict[str, Any]:
    try:
        return _r11_validate_mapping_authority(
            value, _r11_key_authority(*keys), label,
        )
    except ValueError as exc:
        raise EvidenceFailure(
            "TERMINAL_RESULT_SCHEMA", f"{label} key schema mismatch",
        ) from exc


def _r11_sha(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None


def _r11_validate_source_receipt(value: Any, label: str) -> dict[str, Any]:
    record = _r11_exact_keys(value, ("path", "sha256", "byte_count"), label)
    _r11_validate_filetoken(record["path"])
    if not _r11_sha(record["sha256"]) or not _r11_u53(record["byte_count"]):
        raise EvidenceFailure("GROUP_RESULT_SCHEMA", f"{label} receipt type mismatch")
    return record


def _r11_validate_group_result(group: Any, index: int) -> None:
    value = _r11_exact_keys(
        group,
        ("group", "group_string", "source", "source_count", "aggregate_sha256", "sources"),
        f"group {index}",
    )
    authority = R4_GROUPS[index]
    if (
        value["group"] != authority["group"]
        or value["group_string"] != authority["group_string"]
        or value["source"] != authority["source"]
        or value["aggregate_sha256"] != authority["aggregate_sha256"]
    ):
        raise EvidenceFailure("GROUP_RESULT_JOIN", "group result authority mismatch")
    sources = value["sources"]
    if not isinstance(sources, list):
        raise EvidenceFailure("GROUP_RESULT_SCHEMA", "group sources are not an array")
    validated = [
        _r11_validate_source_receipt(record, f"group {index} source {position}")
        for position, record in enumerate(sources)
    ]
    if (
        value["source_count"] != len(validated)
        or [record["path"] for record in validated]
        != sorted(authority["sources"], key=str.casefold)
        or _source_closure_aggregate(validated) != authority["aggregate_sha256"]
    ):
        raise EvidenceFailure("GROUP_RESULT_CLOSURE", "group source closure is not exact")


_R11_STEP_OPERAND_KEYS: dict[int, tuple[str, ...]] = {
    ordinal: _r11_key_authority(*keys)
    for ordinal, keys in {
    1: ("target", "present", "actual_type"),
    2: ("target", "present", "actual_type"),
    3: ("target", "input_length", "input_sha256"),
    4: ("target", "length", "sha256"),
    5: ("target", "length", "sha256"),
    6: ("target", "length", "sha256"),
    7: ("target", "length", "sha256"),
    8: ("target", "present", "actual_type", "entry_count"),
    9: ("target", "present", "actual_type"),
    10: ("target", "present", "actual_type"),
    11: ("target", "input_length", "input_sha256"),
    12: ("target", "length", "sha256"),
    13: ("target", "length", "sha256"),
    14: ("target", "length", "sha256"),
    15: ("target", "length", "sha256"),
    16: ("target", "present", "actual_type", "entry_count"),
    17: (
        "target", "abi_present", "abi_type", "constructor_count",
        "inputs_present", "inputs_type", "actual_types", "expected_types",
    ),
    18: ("target", "input_types"),
    19: (
        "target", "actual_signature", "expected_signature", "actual_words",
        "expected_words", "actual_bytes", "expected_bytes",
    ),
    20: ("target", "input_length", "input_sha256"),
    21: ("target", "creation_bytes", "constructor_bytes"),
    22: ("target", "actual", "operator", "threshold"),
    23: ("target", "input_length", "input_sha256"),
    24: ("target", "actual", "operator", "threshold"),
    25: ("target", "actual", "operator", "threshold"),
    26: ("target", "runtime_bytes", "gas_per_byte"),
    }.items()
}
_R11_STEP_RESULT_KEYS: dict[int, tuple[str, ...]] = {
    ordinal: _r11_key_authority(*keys)
    for ordinal, keys in {
    3: ("input_length", "input_sha256", "output_length", "output_sha256", "prefix_removed"),
    11: ("input_length", "input_sha256", "output_length", "output_sha256", "prefix_removed"),
    18: ("signature", "words", "bytes"),
    20: ("byte_count", "sha256"),
    21: ("creation_bytes", "constructor_bytes", "full_initcode_bytes"),
    23: ("byte_count", "sha256"),
    26: ("runtime_bytes", "gas_per_byte", "code_deposit_gas"),
    }.items()
}
_R11_OPERATION_STEPS = frozenset(_R11_STEP_RESULT_KEYS)


def _r11_validate_step(
    step: Any,
    ordinal: int,
    authority: dict[str, Any],
) -> None:
    value = _r11_exact_keys(
        step,
        ("ordinal", "id", "kind", "status", "operands", "result", "error_code"),
        f"bytecode step {ordinal}",
    )
    if value["ordinal"] != ordinal or value["id"] != BYTECODE_STEPS[ordinal - 1]:
        raise EvidenceFailure("TARGET_TRACE_ORDER", "bytecode step order mismatch")
    operation = ordinal in _R11_OPERATION_STEPS
    if value["kind"] != ("operation" if operation else "predicate"):
        raise EvidenceFailure("TARGET_TRACE_KIND", "bytecode step kind mismatch")
    operands = _r11_exact_keys(
        value["operands"], _R11_STEP_OPERAND_KEYS[ordinal],
        f"bytecode step {ordinal} operands",
    )
    if operands["target"] != authority["target"]:
        raise EvidenceFailure("TARGET_TRACE_JOIN", "bytecode operand target mismatch")
    for key, member in operands.items():
        if key.endswith(("length", "count", "words", "bytes")) or key in (
            "actual", "threshold", "creation_bytes", "constructor_bytes",
            "runtime_bytes", "gas_per_byte", "actual_words", "expected_words",
            "actual_bytes", "expected_bytes",
        ):
            if member is not None and not _r11_u53(member):
                raise EvidenceFailure("TARGET_TRACE_RANGE", f"step {ordinal} U53 mismatch")
        if key.endswith("sha256") and not _r11_sha(member):
            raise EvidenceFailure("TARGET_TRACE_HASH", f"step {ordinal} hash mismatch")
    observed_types = (None, "null", "boolean", "integer", "string", "array", "object")
    for key in ("actual_type", "abi_type", "inputs_type"):
        if key in operands and operands[key] not in observed_types:
            raise EvidenceFailure("TARGET_TRACE_TYPE", f"step {ordinal} observed type mismatch")
    if ordinal in (1, 2, 8, 9, 10, 16):
        if type(operands["present"]) is not bool:
            raise EvidenceFailure("TARGET_TRACE_TYPE", f"step {ordinal} presence gate mismatch")
        if (operands["actual_type"] is None) != (not operands["present"]):
            raise EvidenceFailure("TARGET_TRACE_TYPE", f"step {ordinal} presence/type dependency mismatch")
    if ordinal in (8, 16):
        if (operands["entry_count"] is not None) != (operands["actual_type"] == "object"):
            raise EvidenceFailure("TARGET_TRACE_TYPE", f"step {ordinal} entry count dependency mismatch")
    if ordinal == 17:
        if type(operands["abi_present"]) is not bool:
            raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 ABI presence mismatch")
        if (operands["abi_type"] is None) != (not operands["abi_present"]):
            raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 ABI type dependency mismatch")
        abi_array = operands["abi_type"] == "array"
        if (operands["constructor_count"] is not None) != abi_array:
            raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 constructor count dependency mismatch")
        inspectable = abi_array and operands["constructor_count"] == 1
        if inspectable != (operands["inputs_present"] is not None):
            raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 inputs presence dependency mismatch")
        if not inspectable and any(
            operands[key] is not None for key in ("inputs_type", "actual_types")
        ):
            raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 unavailable input evidence is nonnull")
        if inspectable:
            if type(operands["inputs_present"]) is not bool:
                raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 input presence is not boolean")
            if (operands["inputs_type"] is None) != (not operands["inputs_present"]):
                raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 input type dependency mismatch")
            if (operands["actual_types"] is not None) != (operands["inputs_type"] == "array"):
                raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 actual type list dependency mismatch")
            if operands["actual_types"] is not None and (
                not isinstance(operands["actual_types"], list)
                or any(member is not None and not isinstance(member, str) for member in operands["actual_types"])
            ):
                raise EvidenceFailure("TARGET_TRACE_TYPE", "step 17 actual types mismatch")
        if operands["expected_types"] != list(authority["input_types"]):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 17 expected constructor types mismatch")
    if ordinal == 18 and operands["input_types"] != list(authority["input_types"]):
        raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 18 constructor inputs mismatch")
    if ordinal == 19 and (
        not isinstance(operands["actual_signature"], str)
        or operands["expected_signature"] != authority["signature"]
        or operands["expected_words"] != authority["words"]
        or operands["expected_bytes"] != authority["bytes"]
    ):
        raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 19 constructor authority mismatch")
    if ordinal in (22, 24, 25):
        expected_operator = "<=" if ordinal == 25 else "<"
        expected_threshold = (
            authority["runtime_cap"] if ordinal == 25
            else R4_RUNTIME_PACKET_LIMIT if ordinal == 24
            else R4_INITCODE_LIMIT
        )
        if operands["operator"] != expected_operator or operands["threshold"] != expected_threshold:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", f"step {ordinal} limit authority mismatch")
    if ordinal == 26 and operands["gas_per_byte"] != R4_CODE_DEPOSIT_GAS_PER_BYTE:
        raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 26 gas authority mismatch")
    if operation:
        if value["status"] == "exception":
            if value["result"] is not None or value["error_code"] != f"OP_{value['id']}_EXCEPTION":
                raise EvidenceFailure("TARGET_TRACE_TUPLE", "operation exception tuple mismatch")
            return
        if value["status"] != "pass" or value["error_code"] is not None:
            raise EvidenceFailure("TARGET_TRACE_TUPLE", "operation pass tuple mismatch")
        result = _r11_exact_keys(
            value["result"], _R11_STEP_RESULT_KEYS[ordinal],
            f"bytecode step {ordinal} result",
        )
        if "target" in result:
            raise EvidenceFailure("TARGET_TRACE_RESULT", "operation result contains target")
        for key, member in result.items():
            if key.endswith(("length", "count", "words", "bytes", "gas")) and not _r11_u53(member):
                raise EvidenceFailure("TARGET_TRACE_RANGE", "operation result is not U53")
            if key.endswith("sha256") and not _r11_sha(member):
                raise EvidenceFailure("TARGET_TRACE_HASH", "operation result hash mismatch")
        if ordinal in (3, 11) and (
            result["input_length"] != operands["input_length"]
            or result["input_sha256"] != operands["input_sha256"]
            or type(result["prefix_removed"]) is not bool
            or result["output_length"]
            != result["input_length"] - (2 if result["prefix_removed"] else 0)
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "normalization result mismatch")
        if ordinal == 18 and (
            result["signature"] != authority["signature"]
            or result["words"] != authority["words"]
            or result["bytes"] != authority["bytes"]
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "constructor metrics mismatch")
        if ordinal == 21 and (
            result["creation_bytes"] != operands["creation_bytes"]
            or result["constructor_bytes"] != operands["constructor_bytes"]
            or result["full_initcode_bytes"] != operands["creation_bytes"] + operands["constructor_bytes"]
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "full initcode arithmetic mismatch")
        if ordinal in (20, 23) and result["byte_count"] * 2 != operands["input_length"]:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "decoded byte length mismatch")
        if ordinal == 26 and (
            result["runtime_bytes"] != operands["runtime_bytes"]
            or result["gas_per_byte"] != R4_CODE_DEPOSIT_GAS_PER_BYTE
            or result["code_deposit_gas"] != operands["runtime_bytes"] * R4_CODE_DEPOSIT_GAS_PER_BYTE
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "deposit gas arithmetic mismatch")
        return
    allowed = R11_BYTECODE_FALSE_CODES.get(ordinal, ())
    expected_error: str | None = None
    if ordinal in (1, 9):
        expected_error = (
            allowed[0] if not operands["present"]
            else allowed[1] if operands["actual_type"] != "object" else None
        )
    elif ordinal in (2, 10):
        expected_error = (
            allowed[0] if not operands["present"]
            else allowed[1] if operands["actual_type"] != "string" else None
        )
    elif ordinal in (8, 16):
        expected_error = (
            allowed[0] if not operands["present"]
            else allowed[1] if operands["actual_type"] != "object"
            else allowed[2] if operands["entry_count"] != 0 else None
        )
    elif ordinal == 17:
        expected_error = (
            allowed[0] if operands["abi_type"] != "array"
            else allowed[1] if operands["constructor_count"] != 1
            else allowed[2] if operands["actual_types"] != operands["expected_types"] else None
        )
    elif ordinal == 19:
        expected_error = (
            allowed[0] if operands["actual_signature"] != operands["expected_signature"]
            else allowed[1] if operands["actual_words"] != operands["expected_words"]
            else allowed[2] if operands["actual_bytes"] != operands["expected_bytes"] else None
        )
    elif ordinal in (4, 12):
        expected_error = allowed[0] if operands["length"] == 0 else None
    elif ordinal in (5, 13):
        expected_error = allowed[0] if operands["length"] % 2 else None
    elif ordinal in (22, 24):
        expected_error = allowed[0] if operands["actual"] >= operands["threshold"] else None
    elif ordinal == 25:
        expected_error = allowed[0] if operands["actual"] > operands["threshold"] else None
    state_reconstructable = ordinal in (
        1, 2, 4, 5, 8, 9, 10, 12, 13, 16, 17, 19, 22, 24, 25,
    )
    if value["status"] == "pass":
        if (
            value["result"] is not True
            or value["error_code"] is not None
            or expected_error is not None
        ):
            raise EvidenceFailure("TARGET_TRACE_TUPLE", "predicate pass tuple mismatch")
    elif value["status"] == "false":
        if (
            value["result"] is not False
            or value["error_code"] not in allowed
            or state_reconstructable and expected_error is None
            or expected_error is not None and value["error_code"] != expected_error
        ):
            raise EvidenceFailure("TARGET_TRACE_TUPLE", "predicate false tuple mismatch")
    else:
        raise EvidenceFailure("TARGET_TRACE_TUPLE", "predicate status mismatch")


def _r11_validate_trace(
    trace: list[dict[str, Any]],
    authority: dict[str, Any],
    *,
    completed: bool,
) -> None:
    if len(trace) > 26:
        raise EvidenceFailure("TARGET_TRACE_COUNT", "bytecode trace exceeds 26 rows")
    for ordinal, step in enumerate(trace, start=1):
        _r11_validate_step(step, ordinal, authority)
        if step["status"] != "pass" and ordinal != len(trace):
            raise EvidenceFailure("TARGET_TRACE_PREFIX", "trace continues after first red")
    if completed != (
        len(trace) == 26 and all(step["status"] == "pass" for step in trace)
    ):
        raise EvidenceFailure("TARGET_TRACE_COMPLETION", "bytecode completion is not exact")
    if len(trace) >= 21 and trace[20]["status"] == "pass":
        if trace[20]["operands"]["creation_bytes"] != trace[19]["result"]["byte_count"]:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 21 creation dependency mismatch")
    if len(trace) >= 8:
        for index in range(3, 7):
            if (
                trace[index]["operands"]["length"] != trace[2]["result"]["output_length"]
                or trace[index]["operands"]["sha256"] != trace[2]["result"]["output_sha256"]
            ):
                raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "creation shape dependency mismatch")
    if len(trace) >= 16:
        for index in range(11, 15):
            if (
                trace[index]["operands"]["length"] != trace[10]["result"]["output_length"]
                or trace[index]["operands"]["sha256"] != trace[10]["result"]["output_sha256"]
            ):
                raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "runtime shape dependency mismatch")
    if len(trace) >= 18 and trace[17]["status"] == "pass":
        if trace[17]["operands"]["input_types"] != trace[16]["operands"]["expected_types"]:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "constructor input dependency mismatch")
    if len(trace) >= 19 and trace[18]["status"] == "pass":
        metrics = trace[17]["result"]
        metric_operands = trace[18]["operands"]
        if (
            metric_operands["actual_signature"] != metrics["signature"]
            or metric_operands["actual_words"] != metrics["words"]
            or metric_operands["actual_bytes"] != metrics["bytes"]
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "constructor metric dependency mismatch")
    if len(trace) >= 20 and trace[19]["status"] == "pass":
        if (
            trace[19]["operands"]["input_length"] != trace[2]["result"]["output_length"]
            or trace[19]["operands"]["input_sha256"] != trace[2]["result"]["output_sha256"]
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "creation decode dependency mismatch")
    if len(trace) >= 22 and trace[21]["operands"]["actual"] != trace[20]["result"]["full_initcode_bytes"]:
        raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "initcode limit dependency mismatch")
    if len(trace) >= 23 and trace[22]["status"] == "pass":
        if (
            trace[22]["operands"]["input_length"] != trace[10]["result"]["output_length"]
            or trace[22]["operands"]["input_sha256"] != trace[10]["result"]["output_sha256"]
        ):
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "runtime decode dependency mismatch")
    if len(trace) >= 25:
        for index in (23, 24):
            if trace[index]["operands"]["actual"] != trace[22]["result"]["byte_count"]:
                raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "runtime limit dependency mismatch")
        if trace[20]["operands"]["constructor_bytes"] != trace[17]["result"]["bytes"]:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 21 constructor dependency mismatch")
    if len(trace) >= 26 and trace[25]["status"] == "pass":
        if trace[25]["operands"]["runtime_bytes"] != trace[22]["result"]["byte_count"]:
            raise EvidenceFailure("TARGET_TRACE_DEPENDENCY", "step 26 runtime dependency mismatch")


def _r11_validate_result_state(
    results: dict[str, Any],
    *,
    first_red: dict[str, Any] | None = None,
) -> None:
    results = _r11_exact_keys(results, R11_RESULT_KEYS, "builder results")
    evaluations = results["target_evaluations"]
    defaults = r11_default_target_evaluations()
    groups = results["groups"]
    if not isinstance(groups, list) or len(groups) > 17:
        raise EvidenceFailure("GROUP_RESULT_PREFIX", "group result is not a bounded prefix")
    for index, group in enumerate(groups):
        _r11_validate_group_result(group, index)
    if results["source_union"] is not None and len(groups) != 17:
        raise EvidenceFailure("SOURCE_UNION_PREFIX", "source union transition is not exact")
    if results["source_union"] is not None:
        union = _r11_exact_keys(
            results["source_union"], ("count", "aggregate_sha256"),
            "source union",
        )
        expected_union = validate_evidence_source_union(groups)
        if union != expected_union:
            raise EvidenceFailure("SOURCE_UNION_MISMATCH", "source union does not reconstruct")
    if not isinstance(evaluations, list) or len(evaluations) != 19:
        raise EvidenceFailure("TARGET_STATE_COUNT", "target state must have 19 records")
    any_bytecode = False
    completed_artifacts = 0
    for index, (evaluation, default) in enumerate(zip(evaluations, defaults, strict=True)):
        evaluation = _r11_exact_keys(
            evaluation, tuple(default), f"target state {index}",
        )
        for immutable in ("semantic_id", "target", "source", "size_ordinal", "emitting_group"):
            if evaluation[immutable] != default[immutable]:
                raise EvidenceFailure("TARGET_STATE_JOIN", "target state authority join mismatch")
        boolean_fields = (
            "file_read", "artifact_json_decoded", "metadata_evaluated",
            "metadata_admitted", "bytecode_evaluated", "bytecode_completed",
        )
        if any(not isinstance(evaluation[field], bool) for field in boolean_fields):
            raise EvidenceFailure("TARGET_STATE_BOOLEAN", "target state has a non-boolean gate")
        artifact_byte_count_missing = evaluation["artifact_byte_count"] is None
        artifact_sha256_missing = evaluation["artifact_sha256"] is None
        if artifact_byte_count_missing ^ artifact_sha256_missing:
            raise EvidenceFailure(
                "TARGET_STATE_FILE_BINDING",
                "artifact receipt nullability is not paired",
            )
        file_fields_present = not artifact_byte_count_missing
        if evaluation["artifact_byte_count"] is not None and not _r11_u53(evaluation["artifact_byte_count"]):
            raise EvidenceFailure("TARGET_STATE_FILE_BINDING", "artifact byte count is not U53")
        if evaluation["artifact_sha256"] is not None and not _r11_sha(evaluation["artifact_sha256"]):
            raise EvidenceFailure("TARGET_STATE_FILE_BINDING", "artifact SHA is not canonical")
        if evaluation["file_read"] != file_fields_present:
            raise EvidenceFailure("TARGET_STATE_FILE_BINDING", "file receipt nullability mismatch")
        if evaluation["artifact_json_decoded"] and not evaluation["file_read"]:
            raise EvidenceFailure("TARGET_STATE_DECODE_ORDER", "decode precedes file receipt")
        if evaluation["file_read"] and not evaluation["metadata_evaluated"]:
            raise EvidenceFailure("TARGET_STATE_FILE_BINDING", "file receipt precedes metadata evaluation")
        if not evaluation["metadata_evaluated"] and any(
            evaluation[field]
            for field in (
                "file_read", "artifact_json_decoded", "metadata_admitted",
                "bytecode_evaluated", "bytecode_completed",
            )
        ):
            raise EvidenceFailure("TARGET_STATE_METADATA_ORDER", "target advanced before evaluation")
        if evaluation["metadata_admitted"] and not (
            evaluation["metadata_evaluated"] and evaluation["artifact_json_decoded"]
        ):
            raise EvidenceFailure("TARGET_STATE_METADATA_ORDER", "admission precedes metadata/read")
        trace = evaluation["bytecode_steps"]
        if not isinstance(trace, list):
            raise EvidenceFailure("TARGET_TRACE_TYPE", "bytecode trace is not an array")
        if evaluation["bytecode_evaluated"] != bool(trace):
            raise EvidenceFailure("TARGET_TRACE_GATE", "bytecode gate and trace disagree")
        _r11_validate_trace(
            trace, R4_TARGET_AUTHORITIES[index],
            completed=evaluation["bytecode_completed"],
        )
        any_bytecode = any_bytecode or evaluation["bytecode_evaluated"]
        completed_artifacts += int(evaluation["bytecode_completed"])
        if evaluation["bytecode_evaluated"] and index > completed_artifacts:
            raise EvidenceFailure("TARGET_TRACE_PREFIX", "bytecode targets are not a prefix")
    if any_bytecode and not all(item["metadata_admitted"] for item in evaluations):
        raise EvidenceFailure("TARGET_GLOBAL_ADMISSION", "bytecode began before all admissions")
    evaluation_by_target = {item["target"]: item for item in evaluations}
    metadata_order = [
        authority["target"]
        for group in R4_GROUPS
        for authority in R4_TARGET_AUTHORITIES
        if authority["source"] == group["source"]
    ]
    partial_seen = False
    for target_name in metadata_order:
        evaluation = evaluation_by_target[target_name]
        stage = (
            4 if evaluation["metadata_admitted"] else
            3 if evaluation["artifact_json_decoded"] else
            2 if evaluation["file_read"] else
            1 if evaluation["metadata_evaluated"] else 0
        )
        if partial_seen and stage != 0:
            raise EvidenceFailure("TARGET_STATE_PREFIX", "metadata targets are not a strict prefix")
        if stage < 4:
            partial_seen = True
    completed_groups = 0
    for group in R4_GROUPS:
        group_targets = [
            evaluation_by_target[authority["target"]]
            for authority in R4_TARGET_AUTHORITIES
            if authority["source"] == group["source"]
        ]
        if all(item["metadata_admitted"] for item in group_targets):
            completed_groups += 1
        else:
            break
    if len(groups) != completed_groups:
        raise EvidenceFailure("GROUP_RESULT_PREFIX", "group prefix disagrees with metadata admissions")
    if not isinstance(results["artifacts"], list) or len(results["artifacts"]) != completed_artifacts:
        raise EvidenceFailure("ARTIFACT_RESULT_PREFIX", "artifact result prefix mismatch")
    for index, artifact in enumerate(results["artifacts"]):
        artifact = _r11_exact_keys(
            artifact,
            (
                "semantic_id", "target", "creation_bytes", "creation_sha256",
                "constructor_signature", "constructor_words", "constructor_bytes",
                "full_initcode_bytes", "runtime_bytes", "runtime_sha256",
                "runtime_cap", "code_deposit_gas",
            ),
            f"artifact result {index}",
        )
        authority = R4_TARGET_AUTHORITIES[index]
        if (
            artifact.get("semantic_id") != authority["semantic_id"]
            or artifact.get("target") != authority["target"]
        ):
            raise EvidenceFailure("ARTIFACT_RESULT_PREFIX", "artifact result join mismatch")
        trace = evaluations[index]["bytecode_steps"]
        expected_artifact = {
            "semantic_id": authority["semantic_id"],
            "target": authority["target"],
            "creation_bytes": trace[19]["result"]["byte_count"],
            "creation_sha256": trace[19]["result"]["sha256"],
            "constructor_signature": trace[17]["result"]["signature"],
            "constructor_words": trace[17]["result"]["words"],
            "constructor_bytes": trace[17]["result"]["bytes"],
            "full_initcode_bytes": trace[20]["result"]["full_initcode_bytes"],
            "runtime_bytes": trace[22]["result"]["byte_count"],
            "runtime_sha256": trace[22]["result"]["sha256"],
            "runtime_cap": authority["runtime_cap"],
            "code_deposit_gas": trace[25]["result"]["code_deposit_gas"],
        }
        if artifact != expected_artifact:
            raise EvidenceFailure("ARTIFACT_RESULT_JOIN", "artifact does not reconstruct from trace")
    aggregates = results["aggregates"]
    if not isinstance(aggregates, list) or len(aggregates) > 11:
        raise EvidenceFailure("AGGREGATE_RESULT_PREFIX", "aggregate result is not a prefix")
    expected_aggregate_ids = [
        row[0] for trigger in (3, 7, 8, 11)
        for row in R4_AGGREGATE_GATES[trigger]
    ]
    if [item.get("gate") for item in aggregates if isinstance(item, dict)] != expected_aggregate_ids[:len(aggregates)]:
        raise EvidenceFailure("AGGREGATE_RESULT_PREFIX", "aggregate result order mismatch")
    expected_aggregates: list[dict[str, Any]] = []
    aggregate_failed = False
    for trigger in (3, 7, 8, 11):
        if len(results["artifacts"]) < trigger or aggregate_failed:
            break
        for gate_id, members, field, threshold in R4_AGGREGATE_GATES[trigger]:
            measurements = {
                artifact["semantic_id"]: artifact
                for artifact in results["artifacts"]
            }
            if any(member not in measurements for member in members):
                aggregate_failed = True
                break
            values = [measurements[member][field] for member in members]
            actual = sum(values)
            if actual > threshold:
                aggregate_failed = True
                break
            expected_aggregates.append(
                {
                    "gate": gate_id,
                    "members": list(members),
                    "field": field,
                    "operands": values,
                    "actual": actual,
                    "operator": "<=",
                    "threshold": threshold,
                    "passed": True,
                }
            )
    if aggregates != expected_aggregates:
        raise EvidenceFailure("AGGREGATE_RESULT_SCHEMA", "aggregate rows do not reconstruct")
    installed = results["output_installed"]
    quarantine = results["output_quarantine_without_matching_go"]
    if not isinstance(installed, bool) or not isinstance(quarantine, bool) or installed != quarantine:
        raise EvidenceFailure("OUTPUT_INSTALL_STATE", "install/quarantine gates disagree")
    output_files = results["output_files"]
    if not isinstance(output_files, list) or len(output_files) not in (0, 37):
        raise EvidenceFailure("OUTPUT_FILE_STATE", "output files are not empty or complete")
    previous_path: str | None = None
    for position, output_file in enumerate(output_files):
        value = _r11_exact_keys(
            output_file, ("path", "byte_count", "sha256"),
            f"output file {position}",
        )
        _r11_validate_filetoken(value["path"])
        if (
            not _r11_u53(value["byte_count"])
            or not _r11_sha(value["sha256"])
            or (previous_path is not None and value["path"] <= previous_path)
        ):
            raise EvidenceFailure("OUTPUT_FILE_SCHEMA", "output file receipt is not strict sorted")
        previous_path = value["path"]
    if output_files and (not installed or results["temporary_root"] is not None):
        raise EvidenceFailure("OUTPUT_FILE_STATE", "output readback precedes install/cleanup")
    temporary_root = results["temporary_root"]
    if temporary_root is not None and (
        not isinstance(temporary_root, str)
        or re.fullmatch(r"[A-Za-z]:\\(?:[^\\]+(?:\\[^\\]+)*)?", temporary_root) is None
    ):
        raise EvidenceFailure("TEMPORARY_ROOT_STATE", "temporary root is not plain absolute")
    if installed and (
        len(groups) != 17
        or results["source_union"] is None
        or completed_artifacts != 19
        or len(aggregates) != 11
    ):
        raise EvidenceFailure("OUTPUT_INSTALL_STATE", "install precedes complete semantic state")


def _r11_text_shape(value: str) -> dict[str, Any]:
    encoded = value.encode("utf-8", errors="strict")
    return {"length": len(value), "sha256": sha256_bytes(encoded)}


def _r11_record_step(
    trace: list[dict[str, Any]],
    ordinal: int,
    kind: str,
    status: str,
    operands: dict[str, Any],
    result: Any,
    error_code: str | None,
    observer: Callable[[str, dict[str, Any]], None] | None,
) -> None:
    record = {
        "ordinal": ordinal,
        "id": BYTECODE_STEPS[ordinal - 1],
        "kind": kind,
        "status": status,
        "operands": operands,
        "result": result,
        "error_code": error_code,
    }
    trace.append(record)
    if observer is not None:
        observer(record["id"], dict(record))


def _r11_predicate(
    trace: list[dict[str, Any]],
    ordinal: int,
    passed: bool,
    error_code: str,
    operands: dict[str, Any],
    observer: Callable[[str, dict[str, Any]], None] | None,
) -> None:
    _r11_record_step(
        trace, ordinal, "predicate", "pass" if passed else "false",
        operands, bool(passed), None if passed else error_code, observer,
    )
    if not passed:
        raise EvidenceFailure(error_code, "ordered bytecode predicate failed", operands=operands)


def _r11_operation(
    trace: list[dict[str, Any]],
    ordinal: int,
    operands: dict[str, Any],
    operation: Callable[[], dict[str, Any]],
    observer: Callable[[str, dict[str, Any]], None] | None,
    operation_hook: Callable[[str, dict[str, Any]], None] | None,
) -> dict[str, Any]:
    step_id = BYTECODE_STEPS[ordinal - 1]
    try:
        if operation_hook is not None:
            operation_hook(step_id, dict(operands))
        result = operation()
    except BaseException as exc:
        code = f"OP_{step_id}_EXCEPTION"
        _r11_record_step(
            trace, ordinal, "operation", "exception", operands, None, code, observer,
        )
        raise EvidenceFailure(code, "ordered bytecode operation failed", operands=operands) from exc
    _r11_record_step(trace, ordinal, "operation", "pass", operands, result, None, observer)
    return result


def _r11_decode_hex_result(value: str) -> dict[str, Any]:
    decoded = bytes.fromhex(value)
    return {"byte_count": len(decoded), "sha256": sha256_bytes(decoded)}


def validate_ordered_bytecode(
    artifact: dict[str, Any],
    target_authority: dict[str, Any],
    *,
    step_observer: Callable[[str, dict[str, Any]], None] | None = None,
    operation_hook: Callable[[str, dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    target = target_authority["target"]
    trace: list[dict[str, Any]] = []

    creation_present = "bytecode" in artifact
    bytecode = artifact.get("bytecode")
    creation_operands = {
        "target": target,
        "present": creation_present,
        "actual_type": _r11_json_type(bytecode, present=creation_present),
    }
    _r11_predicate(
        trace, 1, creation_present and isinstance(bytecode, dict),
        "BC_CREATION_MISSING" if not creation_present else "BC_CREATION_NOT_OBJECT",
        creation_operands, step_observer,
    )
    object_present = "object" in bytecode
    creation_object = bytecode.get("object")
    creation_object_operands = {
        "target": target,
        "present": object_present,
        "actual_type": _r11_json_type(creation_object, present=object_present),
    }
    _r11_predicate(
        trace, 2, object_present and isinstance(creation_object, str),
        "BC_CREATION_OBJECT_MISSING" if not object_present else "BC_CREATION_OBJECT_NOT_STRING",
        creation_object_operands, step_observer,
    )
    creation_input = creation_object.encode("utf-8", errors="strict")
    creation_normalized_text = (
        creation_object[2:] if creation_object.startswith(("0x", "0X")) else creation_object
    )
    normalized_creation = _r11_operation(
        trace, 3,
        {
            "target": target,
            "input_length": len(creation_object),
            "input_sha256": sha256_bytes(creation_input),
        },
        lambda: {
            "input_length": len(creation_object),
            "input_sha256": sha256_bytes(creation_input),
            "output_length": len(creation_normalized_text),
            "output_sha256": sha256_bytes(creation_normalized_text.encode("utf-8")),
            "prefix_removed": creation_normalized_text != creation_object,
        },
        step_observer, operation_hook,
    )
    creation_shape = {"target": target, **_r11_text_shape(creation_normalized_text)}
    _r11_predicate(trace, 4, normalized_creation["output_length"] > 0, "BC_CREATION_EMPTY", creation_shape, step_observer)
    _r11_predicate(trace, 5, normalized_creation["output_length"] % 2 == 0, "BC_CREATION_ODD_LENGTH", creation_shape, step_observer)
    _r11_predicate(trace, 6, re.search(r"__\$[0-9a-fA-F]{34}\$__", creation_normalized_text) is None, "BC_CREATION_UNRESOLVED_PLACEHOLDER", creation_shape, step_observer)
    _r11_predicate(trace, 7, re.fullmatch(r"[0-9A-Fa-f]*", creation_normalized_text) is not None, "BC_CREATION_NON_HEX", creation_shape, step_observer)
    creation_links_present = "linkReferences" in bytecode
    creation_links = bytecode.get("linkReferences")
    creation_link_operands = {
        "target": target,
        "present": creation_links_present,
        "actual_type": _r11_json_type(creation_links, present=creation_links_present),
        "entry_count": len(creation_links) if isinstance(creation_links, dict) else None,
    }
    creation_links_code = (
        "BC_CREATION_LINKS_MISSING" if not creation_links_present else
        "BC_CREATION_LINKS_NOT_OBJECT" if not isinstance(creation_links, dict) else
        "BC_CREATION_LINKS_NONEMPTY"
    )
    _r11_predicate(trace, 8, isinstance(creation_links, dict) and not creation_links, creation_links_code, creation_link_operands, step_observer)

    runtime_present = "deployedBytecode" in artifact
    runtime = artifact.get("deployedBytecode")
    runtime_operands = {
        "target": target,
        "present": runtime_present,
        "actual_type": _r11_json_type(runtime, present=runtime_present),
    }
    _r11_predicate(trace, 9, runtime_present and isinstance(runtime, dict), "BC_RUNTIME_MISSING" if not runtime_present else "BC_RUNTIME_NOT_OBJECT", runtime_operands, step_observer)
    runtime_object_present = "object" in runtime
    runtime_object = runtime.get("object")
    runtime_object_operands = {
        "target": target,
        "present": runtime_object_present,
        "actual_type": _r11_json_type(runtime_object, present=runtime_object_present),
    }
    _r11_predicate(trace, 10, runtime_object_present and isinstance(runtime_object, str), "BC_RUNTIME_OBJECT_MISSING" if not runtime_object_present else "BC_RUNTIME_OBJECT_NOT_STRING", runtime_object_operands, step_observer)
    runtime_input = runtime_object.encode("utf-8", errors="strict")
    runtime_normalized_text = runtime_object[2:] if runtime_object.startswith(("0x", "0X")) else runtime_object
    normalized_runtime = _r11_operation(
        trace, 11,
        {"target": target, "input_length": len(runtime_object), "input_sha256": sha256_bytes(runtime_input)},
        lambda: {
            "input_length": len(runtime_object),
            "input_sha256": sha256_bytes(runtime_input),
            "output_length": len(runtime_normalized_text),
            "output_sha256": sha256_bytes(runtime_normalized_text.encode("utf-8")),
            "prefix_removed": runtime_normalized_text != runtime_object,
        },
        step_observer, operation_hook,
    )
    runtime_shape = {"target": target, **_r11_text_shape(runtime_normalized_text)}
    _r11_predicate(trace, 12, normalized_runtime["output_length"] > 0, "BC_RUNTIME_EMPTY", runtime_shape, step_observer)
    _r11_predicate(trace, 13, normalized_runtime["output_length"] % 2 == 0, "BC_RUNTIME_ODD_LENGTH", runtime_shape, step_observer)
    _r11_predicate(trace, 14, re.search(r"__\$[0-9a-fA-F]{34}\$__", runtime_normalized_text) is None, "BC_RUNTIME_UNRESOLVED_PLACEHOLDER", runtime_shape, step_observer)
    _r11_predicate(trace, 15, re.fullmatch(r"[0-9A-Fa-f]*", runtime_normalized_text) is not None, "BC_RUNTIME_NON_HEX", runtime_shape, step_observer)
    runtime_links_present = "linkReferences" in runtime
    runtime_links = runtime.get("linkReferences")
    runtime_link_operands = {
        "target": target,
        "present": runtime_links_present,
        "actual_type": _r11_json_type(runtime_links, present=runtime_links_present),
        "entry_count": len(runtime_links) if isinstance(runtime_links, dict) else None,
    }
    runtime_links_code = (
        "BC_RUNTIME_LINKS_MISSING" if not runtime_links_present else
        "BC_RUNTIME_LINKS_NOT_OBJECT" if not isinstance(runtime_links, dict) else
        "BC_RUNTIME_LINKS_NONEMPTY"
    )
    _r11_predicate(trace, 16, isinstance(runtime_links, dict) and not runtime_links, runtime_links_code, runtime_link_operands, step_observer)

    abi_present = "abi" in artifact
    abi = artifact.get("abi")
    constructors = (
        [entry for entry in abi if isinstance(entry, dict) and entry.get("type") == "constructor"]
        if isinstance(abi, list) else []
    )
    inputs_present: bool | None = None
    inputs_type: str | None = None
    actual_types: list[str | None] | None = None
    if isinstance(abi, list) and len(constructors) == 1:
        inputs_present = "inputs" in constructors[0]
        inputs = constructors[0].get("inputs")
        inputs_type = _r11_json_type(inputs, present=inputs_present)
        if isinstance(inputs, list):
            actual_types = [
                item.get("type") if isinstance(item, dict) and isinstance(item.get("type"), str)
                else None for item in inputs
            ]
    expected_types = list(target_authority["input_types"])
    abi_operands = {
        "target": target,
        "abi_present": abi_present,
        "abi_type": _r11_json_type(abi, present=abi_present),
        "constructor_count": len(constructors) if isinstance(abi, list) else None,
        "inputs_present": inputs_present,
        "inputs_type": inputs_type,
        "actual_types": actual_types,
        "expected_types": expected_types,
    }
    abi_code = (
        "ABI_NOT_ARRAY" if not isinstance(abi, list) else
        "ABI_CONSTRUCTOR_COUNT" if len(constructors) != 1 else
        "ABI_CONSTRUCTOR_TYPES_ORDER"
    )
    _r11_predicate(trace, 17, actual_types == expected_types, abi_code, abi_operands, step_observer)
    metrics = _r11_operation(
        trace, 18, {"target": target, "input_types": expected_types},
        lambda: {
            "signature": f"constructor({','.join(expected_types)})",
            "words": len(expected_types),
            "bytes": len(expected_types) * 32,
        },
        step_observer, operation_hook,
    )
    metric_operands = {
        "target": target,
        "actual_signature": metrics["signature"],
        "expected_signature": target_authority["signature"],
        "actual_words": metrics["words"],
        "expected_words": target_authority["words"],
        "actual_bytes": metrics["bytes"],
        "expected_bytes": target_authority["bytes"],
    }
    metric_code = (
        "ABI_CONSTRUCTOR_SIGNATURE" if metrics["signature"] != target_authority["signature"] else
        "ABI_CONSTRUCTOR_WORDS" if metrics["words"] != target_authority["words"] else
        "ABI_CONSTRUCTOR_WIDTH"
    )
    _r11_predicate(trace, 19, all((metrics["signature"] == target_authority["signature"], metrics["words"] == target_authority["words"], metrics["bytes"] == target_authority["bytes"])), metric_code, metric_operands, step_observer)
    creation_decoded = _r11_operation(
        trace, 20,
        {"target": target, "input_length": len(creation_normalized_text), "input_sha256": sha256_bytes(creation_normalized_text.encode("utf-8"))},
        lambda: _r11_decode_hex_result(creation_normalized_text),
        step_observer, operation_hook,
    )
    full_initcode = _r11_operation(
        trace, 21,
        {"target": target, "creation_bytes": creation_decoded["byte_count"], "constructor_bytes": metrics["bytes"]},
        lambda: {
            "creation_bytes": creation_decoded["byte_count"],
            "constructor_bytes": metrics["bytes"],
            "full_initcode_bytes": creation_decoded["byte_count"] + metrics["bytes"],
        },
        step_observer, operation_hook,
    )
    _r11_predicate(trace, 22, full_initcode["full_initcode_bytes"] < R4_INITCODE_LIMIT, "SIZE_INITCODE_LIMIT", {"target": target, "actual": full_initcode["full_initcode_bytes"], "operator": "<", "threshold": R4_INITCODE_LIMIT}, step_observer)
    runtime_decoded = _r11_operation(
        trace, 23,
        {"target": target, "input_length": len(runtime_normalized_text), "input_sha256": sha256_bytes(runtime_normalized_text.encode("utf-8"))},
        lambda: _r11_decode_hex_result(runtime_normalized_text),
        step_observer, operation_hook,
    )
    runtime_bytes = runtime_decoded["byte_count"]
    _r11_predicate(trace, 24, runtime_bytes < R4_RUNTIME_PACKET_LIMIT, "SIZE_RUNTIME_PACKET_LIMIT", {"target": target, "actual": runtime_bytes, "operator": "<", "threshold": R4_RUNTIME_PACKET_LIMIT}, step_observer)
    _r11_predicate(trace, 25, runtime_bytes <= target_authority["runtime_cap"], "SIZE_RUNTIME_TARGET_CAP", {"target": target, "actual": runtime_bytes, "operator": "<=", "threshold": target_authority["runtime_cap"]}, step_observer)
    gas = _r11_operation(
        trace, 26,
        {"target": target, "runtime_bytes": runtime_bytes, "gas_per_byte": R4_CODE_DEPOSIT_GAS_PER_BYTE},
        lambda: {
            "runtime_bytes": runtime_bytes,
            "gas_per_byte": R4_CODE_DEPOSIT_GAS_PER_BYTE,
            "code_deposit_gas": runtime_bytes * R4_CODE_DEPOSIT_GAS_PER_BYTE,
        },
        step_observer, operation_hook,
    )
    if len(trace) != 26:
        raise AssertionError("R11 bytecode trace did not complete exactly 26 rows")
    return {
        "semantic_id": target_authority["semantic_id"],
        "target": target,
        "creation_bytes": creation_decoded["byte_count"],
        "creation_sha256": creation_decoded["sha256"],
        "constructor_signature": metrics["signature"],
        "constructor_words": metrics["words"],
        "constructor_bytes": metrics["bytes"],
        "full_initcode_bytes": full_initcode["full_initcode_bytes"],
        "runtime_bytes": runtime_bytes,
        "runtime_sha256": runtime_decoded["sha256"],
        "runtime_cap": target_authority["runtime_cap"],
        "code_deposit_gas": gas["code_deposit_gas"],
        "bytecode_steps": trace,
    }


def r11_validate_forge_version_bytes(stdout: bytes) -> str:
    stdout_receipt = {
        "byte_count": len(stdout),
        "sha256": sha256_bytes(stdout),
    }
    try:
        decoded = stdout.decode("utf-8", errors="strict")
    except UnicodeError as exc:
        raise EvidenceFailure("FORGE_VERSION_UTF8", "Forge version is not UTF-8", operands=stdout_receipt) from exc
    if decoded == "":
        raise EvidenceFailure("FORGE_VERSION_EMPTY", "Forge version is empty", operands=stdout_receipt)
    if "\r" in decoded or decoded != decoded.strip():
        raise EvidenceFailure("FORGE_VERSION_FORMAT", "Forge version grammar mismatch", operands=stdout_receipt)
    normalized = decoded
    line_pattern = re.compile(
        r"^forge Version: ([0-9]+\.[0-9]+\.[0-9]+)\n"
        r"Commit SHA: ([0-9a-f]{40})\n"
        r"((?:Build Timestamp: [\x20-\x7e]+\n)*)"
        r"Build Profile: ([A-Za-z0-9_.-]+)$"
    )
    match = line_pattern.fullmatch(normalized)
    if match is None or any(ord(character) < 0x20 and character != "\n" for character in normalized):
        raise EvidenceFailure("FORGE_VERSION_FORMAT", "Forge version grammar mismatch", operands=stdout_receipt)
    timestamp_block = match.group(3)
    timestamp_count = timestamp_block.count("Build Timestamp: ")
    portable = re.sub(
        r"^Build Timestamp: [\x20-\x7e]+$",
        PORTABLE_FORGE_BUILD_TIMESTAMP,
        normalized,
        flags=re.MULTILINE,
    )
    portable_sha256 = sha256_bytes(portable.encode("utf-8"))
    if timestamp_count != 1:
        raise EvidenceFailure(
            "FORGE_VERSION_TIMESTAMP_COUNT",
            "Forge version has the wrong timestamp count",
            operands={
                "timestamp_count": timestamp_count,
                "expected_count": 1,
                "normalized_sha256": portable_sha256,
            },
        )
    if portable_sha256 != R11_FORGE_VERSION_IDENTITY_SHA256:
        raise EvidenceFailure(
            "FORGE_VERSION_MISMATCH",
            "Forge version identity does not match the frozen pin",
            operands={
                "expected_sha256": R11_FORGE_VERSION_IDENTITY_SHA256,
                "actual_sha256": portable_sha256,
            },
        )
    return portable


def _r11_checkpoint(
    label: str,
    forge_bin: Path,
    solc_bin: Path,
    static_receipts: dict[str, Any],
) -> dict[str, Any]:
    checkpoint = {
        "label": label,
        "forge": windows_file_receipt(forge_bin, "Forge executable"),
        "solc": windows_file_receipt(solc_bin, "Solc executable"),
    }
    for token in ("forge", "solc"):
        expected = static_receipts[token]
        actual = checkpoint[token]
        comparable = ("path", "identity", "byte_count", "sha256")
        if any(actual.get(field) != expected.get(field) for field in comparable):
            raise EvidenceFailure(
                "COMPILER_IDENTITY_CHECKPOINT_MISMATCH",
                "compiler checkpoint does not match the authenticated receipt",
                operands={
                    "checkpoint_label": label,
                    "expected_sha256": expected["sha256"],
                    "actual_sha256": actual["sha256"],
                },
            )
    return checkpoint


def _r11_publish_preconstructed(
    directory: Path,
    name: str,
    value: dict[str, Any],
    expected_raw: bytes,
    expected_sha256: str,
) -> None:
    raw, digest = publish_json_no_replace(directory, name, value)
    if raw != expected_raw or digest != expected_sha256:
        raise EvidenceFailure("EVIDENCE_PUBLICATION_MISMATCH", "publisher changed preconstructed bytes")
    readback, token, _ = r11_native_read(directory / name, name)
    if token != name or readback != expected_raw or sha256_bytes(readback) != expected_sha256:
        raise EvidenceFailure("EVIDENCE_PUBLICATION_READBACK", "durable evidence readback mismatch")


def _r11_validate_receipt(
    value: Any,
    label: str,
    keys: tuple[str, ...] = (
        "path", "identity", "byte_count", "sha256", "path_token",
    ),
) -> None:
    receipt = _r11_exact_keys(value, keys, f"{label} receipt")
    if not isinstance(receipt["path"], str):
        raise EvidenceFailure("EVENT_SCHEMA", f"{label} receipt path is not text")
    if (
        receipt["identity"] is not None
        and not _r11_durable_identity_value(receipt["identity"])
    ):
        raise EvidenceFailure("EVENT_SCHEMA", f"{label} receipt identity mismatch")
    if receipt["byte_count"] is not None and not _r11_u53(receipt["byte_count"]):
        raise EvidenceFailure("EVENT_SCHEMA", f"{label} receipt count mismatch")
    if receipt["sha256"] is not None and not _r11_sha(receipt["sha256"]):
        raise EvidenceFailure("EVENT_SCHEMA", f"{label} receipt hash mismatch")
    _r11_validate_filetoken(receipt["path_token"])


def _r11_validate_checkpoint(value: Any, label: str) -> None:
    checkpoint = _r11_exact_keys(value, ("label", "forge", "solc"), label)
    if not isinstance(checkpoint["label"], str) or re.fullmatch(
        r"pre-started|invocation-(?:00[0-9]|01[0-7])-(?:before|after)",
        checkpoint["label"],
    ) is None:
        raise EvidenceFailure("CHECKPOINT_SCHEMA", "checkpoint label is not closed")
    for token in ("forge", "solc"):
        receipt = checkpoint[token]
        _r11_validate_receipt(receipt, f"checkpoint {token}")
        if receipt["identity"] is None or receipt["byte_count"] is None or receipt["sha256"] is None:
            raise EvidenceFailure("CHECKPOINT_SCHEMA", "checkpoint file receipt is incomplete")


def _r11_validate_checkpoint_authority(
    checkpoint: dict[str, Any],
    path_tokens: dict[str, Any],
) -> None:
    for token in ("forge", "solc"):
        if any(
            checkpoint[token][key] != path_tokens[token][key]
            for key in ("path", "identity", "byte_count", "sha256", "path_token")
        ):
            raise EvidenceFailure("CHECKPOINT_SCHEMA", "checkpoint receipt differs from STARTED")


def _r11_validate_started_operands(value: Any) -> None:
    operands = _r11_exact_keys(
        value,
        ("path_tokens", "held_evidence_directory_identity", "pre_started_checkpoint"),
        "STARTED operands",
    )
    path_tokens = operands["path_tokens"]
    expected_static = (
        "builder", "test", "config", "foundry_config", "forge", "solc",
        "repo_root", "evidence_dir", "output_dir", "source_aggregate",
    )
    expected_sources = tuple(f"source:{path}" for path in sorted(
        {path for group in R4_GROUPS for path in group["sources"]},
        key=str.casefold,
    ))
    _r11_exact_keys(
        path_tokens, expected_static + expected_sources, "STARTED path tokens",
    )
    for token, receipt in path_tokens.items():
        common = ("path", "identity", "byte_count", "sha256", "path_token")
        if token == "output_dir":
            expected_keys = common + ("kind", "initial_status")
        elif token == "source_aggregate":
            expected_keys = common + ("kind", "source_count")
        else:
            expected_keys = common + ("kind",)
        _r11_validate_receipt(receipt, f"STARTED {token}", expected_keys)
        if receipt["kind"] not in ("file", "directory"):
            raise EvidenceFailure("EVENT_SCHEMA", "STARTED receipt kind mismatch")
        if token == "output_dir":
            if (
                receipt["kind"] != "directory"
                or receipt["initial_status"] != "absent"
                or any(receipt[key] is not None for key in ("identity", "byte_count", "sha256"))
            ):
                raise EvidenceFailure("EVENT_SCHEMA", "STARTED absent output receipt mismatch")
        elif token == "source_aggregate":
            if (
                receipt["kind"] != "directory"
                or receipt["source_count"] != 31
                or receipt["sha256"] != "sha256:" + R4_SOURCE_AGGREGATE_SHA256.lower()
                or not _r11_u53(receipt["byte_count"])
                or receipt["identity"] is None
            ):
                raise EvidenceFailure("EVENT_SCHEMA", "STARTED source aggregate mismatch")
        elif receipt["kind"] == "file":
            if receipt["identity"] is None or receipt["byte_count"] is None or receipt["sha256"] is None:
                raise EvidenceFailure("EVENT_SCHEMA", "STARTED file receipt is incomplete")
        elif (
            receipt["identity"] is None
            or receipt["byte_count"] is not None
            or receipt["sha256"] is not None
        ):
            raise EvidenceFailure("EVENT_SCHEMA", "STARTED directory receipt mismatch")
    if not _r11_durable_identity_value(
        operands["held_evidence_directory_identity"]
    ):
        raise EvidenceFailure("EVENT_SCHEMA", "STARTED held identity mismatch")
    if (
        path_tokens["evidence_dir"]["identity"]
        != operands["held_evidence_directory_identity"]
    ):
        raise EvidenceFailure("EVENT_SCHEMA", "STARTED static/held evidence identity mismatch")
    _r11_validate_checkpoint(operands["pre_started_checkpoint"], "pre-started checkpoint")
    if operands["pre_started_checkpoint"]["label"] != "pre-started":
        raise EvidenceFailure("EVENT_SCHEMA", "STARTED checkpoint is not pre-started")
    for token in ("forge", "solc"):
        checkpoint_receipt = operands["pre_started_checkpoint"][token]
        static_receipt = path_tokens[token]
        if any(
            checkpoint_receipt[key] != static_receipt[key]
            for key in ("path", "identity", "byte_count", "sha256", "path_token")
        ):
            raise EvidenceFailure("EVENT_SCHEMA", "STARTED checkpoint/static receipt mismatch")


def _r11_invocation_id_from_started(operands: dict[str, Any]) -> str:
    path_tokens = operands["path_tokens"]
    return sha256_bytes(
        canonical_evidence_bytes(
            {
                "builder": path_tokens["builder"],
                "test": path_tokens["test"],
                "source_aggregate_sha256": R4_SOURCE_AGGREGATE_SHA256,
                "foundry_config_sha256": R4_FOUNDRY_CONFIG_SHA256,
                "target_config_sha256": R4_TARGET_CONFIG_SHA256,
                "group_map_sha256": R4_GROUP_MAP_SHA256,
                "constructor_map_sha256": R4_CONSTRUCTOR_MAP_SHA256,
                "forge": path_tokens["forge"],
                "solc": path_tokens["solc"],
                "repo_root": path_tokens["repo_root"],
                "output_dir": path_tokens["output_dir"],
                "evidence_dir": path_tokens["evidence_dir"],
                "held_evidence_directory_identity": operands["held_evidence_directory_identity"],
                "pre_started_checkpoint": operands["pre_started_checkpoint"],
            }
        )
    )


def _r11_validate_event(value: Any) -> None:
    event = _r11_exact_keys(
        value,
        (
            "schema", "invocation_id", "sequence", "previous_event_sha256",
            "event_type", "phase", "operands",
        ),
        "evidence event",
    )
    if event["schema"] != EVIDENCE_EVENT_SCHEMA or not _r11_sha(event["invocation_id"]):
        raise EvidenceFailure("EVENT_SCHEMA", "event schema/invocation mismatch")
    if not _r11_u53(event["sequence"]):
        raise EvidenceFailure("EVENT_SCHEMA", "event sequence is not U53")
    if event["previous_event_sha256"] is not None and not _r11_sha(event["previous_event_sha256"]):
        raise EvidenceFailure("EVENT_SCHEMA", "event predecessor hash mismatch")
    if event["event_type"] == "execution_started":
        if event["sequence"] != 0 or event["previous_event_sha256"] is not None or event["phase"] != "execution":
            raise EvidenceFailure("EVENT_SCHEMA", "STARTED event binding mismatch")
        _r11_validate_started_operands(event["operands"])
        if event["invocation_id"] != _r11_invocation_id_from_started(event["operands"]):
            raise EvidenceFailure("EVENT_SCHEMA", "STARTED invocation domain mismatch")
        return
    if event["event_type"] == "invocation_start":
        operands = _r11_exact_keys(
            event["operands"],
            (
                "ordinal", "group_string", "executable", "argv", "argv_sha256",
                "environment_sha256", "environment_entry_count", "cwd",
                "start_monotonic_ms", "checkpoint",
            ),
            "invocation start operands",
        )
        ordinal = operands["ordinal"]
        if not _r11_u53(ordinal) or ordinal > 17 or event["sequence"] != 1 + 2 * ordinal:
            raise EvidenceFailure("EVENT_SCHEMA", "invocation start ordinal mismatch")
        phase, group = ExecutionJournal._expected_binding(ordinal)
        if event["phase"] != phase or operands["group_string"] != group:
            raise EvidenceFailure("EVENT_SCHEMA", "invocation start phase/group mismatch")
        if (
            not isinstance(operands["executable"], str)
            or not isinstance(operands["argv"], list)
            or not operands["argv"]
            or any(not isinstance(member, str) for member in operands["argv"])
            or operands["argv"][0] != operands["executable"]
            or operands["argv_sha256"] != sha256_bytes(canonical_evidence_bytes(operands["argv"]))
            or not _r11_sha(operands["environment_sha256"])
            or not _r11_u53(operands["environment_entry_count"])
            or not isinstance(operands["cwd"], str)
            or not _r11_u53(operands["start_monotonic_ms"])
        ):
            raise EvidenceFailure("EVENT_SCHEMA", "invocation start operand type mismatch")
        _r11_validate_checkpoint(operands["checkpoint"], "start checkpoint")
        if operands["checkpoint"]["label"] != f"invocation-{ordinal:03d}-before":
            raise EvidenceFailure("EVENT_SCHEMA", "invocation start checkpoint label mismatch")
        return
    if event["event_type"] == "invocation_exit":
        operands = _r11_exact_keys(
            event["operands"],
            (
                "ordinal", "group_string", "launched", "exit_code",
                "start_monotonic_ms", "end_monotonic_ms", "stdout_byte_count",
                "stdout_sha256", "stderr_byte_count", "stderr_sha256",
                "exception_type", "exception_sha256", "checkpoint",
            ),
            "invocation exit operands",
        )
        ordinal = operands["ordinal"]
        if not _r11_u53(ordinal) or ordinal > 17 or event["sequence"] != 2 + 2 * ordinal:
            raise EvidenceFailure("EVENT_SCHEMA", "invocation exit ordinal mismatch")
        phase, group = ExecutionJournal._expected_binding(ordinal)
        if event["phase"] != phase or operands["group_string"] != group:
            raise EvidenceFailure("EVENT_SCHEMA", "invocation exit phase/group mismatch")
        if (
            operands["launched"] is not True
            or type(operands["exit_code"]) is not int
            or not -9_007_199_254_740_991 <= operands["exit_code"] <= 9_007_199_254_740_991
            or not _r11_u53(operands["start_monotonic_ms"])
            or not _r11_u53(operands["end_monotonic_ms"])
            or operands["end_monotonic_ms"] < operands["start_monotonic_ms"]
            or not _r11_u53(operands["stdout_byte_count"])
            or not _r11_sha(operands["stdout_sha256"])
            or not _r11_u53(operands["stderr_byte_count"])
            or not _r11_sha(operands["stderr_sha256"])
            or operands["exception_type"] is not None
            or operands["exception_sha256"] is not None
        ):
            raise EvidenceFailure("EVENT_SCHEMA", "invocation exit operand type mismatch")
        _r11_validate_checkpoint(operands["checkpoint"], "exit checkpoint")
        if operands["checkpoint"]["label"] != f"invocation-{ordinal:03d}-after":
            raise EvidenceFailure("EVENT_SCHEMA", "invocation exit checkpoint label mismatch")
        return
    raise EvidenceFailure("EVENT_SCHEMA", "unknown evidence event type")


def _r11_validate_call(value: Any, ordinal: int) -> None:
    if not _r11_u53(ordinal) or ordinal > 17:
        raise EvidenceFailure(
            "CALL_SCHEMA", "call ordinal is outside exact schedule",
        )
    call = _r11_exact_keys(
        value,
        (
            "ordinal", "phase", "group_string", "start_event_sha256",
            "exit_event_sha256", "argv_sha256", "environment_sha256",
            "launched", "exit_code", "stdout_byte_count", "stdout_sha256",
            "stderr_byte_count", "stderr_sha256", "exception_type",
            "exception_sha256",
        ),
        f"call {ordinal}",
    )
    phase, group = ExecutionJournal._expected_binding(ordinal)
    if call["ordinal"] != ordinal or call["phase"] != phase or call["group_string"] != group:
        raise EvidenceFailure("CALL_SCHEMA", "call binding mismatch")
    if (
        call["launched"] is not True
        or type(call["exit_code"]) is not int
        or not -9_007_199_254_740_991 <= call["exit_code"] <= 9_007_199_254_740_991
    ):
        raise EvidenceFailure("CALL_SCHEMA", "call launch/exit mismatch")
    for key in (
        "start_event_sha256", "exit_event_sha256", "argv_sha256",
        "environment_sha256", "stdout_sha256", "stderr_sha256",
    ):
        if not _r11_sha(call[key]):
            raise EvidenceFailure("CALL_SCHEMA", "call hash mismatch")
    for key in ("stdout_byte_count", "stderr_byte_count"):
        if not _r11_u53(call[key]):
            raise EvidenceFailure("CALL_SCHEMA", "call count mismatch")
    if call["exception_type"] is not None or call["exception_sha256"] is not None:
        raise EvidenceFailure("CALL_SCHEMA", "returned call cannot contain exception evidence")


_R11_FIRST_RED_PHASES = {
    "FORGE_VERSION_UTF8": "forge_version",
    "FORGE_VERSION_EMPTY": "forge_version",
    "FORGE_VERSION_FORMAT": "forge_version",
    "FORGE_VERSION_TIMESTAMP_COUNT": "forge_version",
    "FORGE_VERSION_MISMATCH": "forge_version",
    "GROUP_STRING_MISMATCH": "group_closure",
    "GROUP_CLOSURE_MISMATCH": "group_closure",
    "GROUP_SOURCE_CONTENT": "group_closure",
    "GROUP_SOURCE_BYTES_MISMATCH": "group_closure",
    "SOURCE_UNION_CONFLICT": "source_union",
    "SOURCE_UNION_MISMATCH": "source_union",
    "ARTIFACT_FILE_READ": "artifact_file_read",
    "ARTIFACT_FILE_IDENTITY_MISMATCH": "artifact_file_read",
    "ARTIFACT_JSON_DECODE": "artifact_json_decode",
    "STAGED_VALIDATION_FAILED": "staged_validation",
    "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION": "output_install",
    "OP_BUILD_TEMP_CLEANUP_EXCEPTION": "temp_cleanup",
    "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION": "installed_readback",
    "OP_INSTALLED_OUTPUT_READ_EXCEPTION": "installed_readback",
    "OUTPUT_TOPOLOGY_MISMATCH": "installed_readback",
    "OUTPUT_BYTES_MISMATCH": "installed_readback",
}
for _code in R11_SERIALIZABLE_CODES:
    if _code.startswith("PORTABLE_INPUT_") or _code in (
        "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION",
        "OP_RETAINED_INPUT_WRITE_EXCEPTION",
    ):
        _R11_FIRST_RED_PHASES.setdefault(_code, "portable_input")
    if _code.startswith("METADATA_"):
        _R11_FIRST_RED_PHASES.setdefault(_code, "metadata_admission")
    if _code.startswith("AGG_") or _code == "AGGREGATE_MEMBER_MISSING":
        _R11_FIRST_RED_PHASES.setdefault(_code, "aggregate")
    if _code in {item for values in R11_BYTECODE_FALSE_CODES.values() for item in values} or _code.startswith("OP_") and _code.endswith("_EXCEPTION") and _code.removeprefix("OP_").removesuffix("_EXCEPTION") in BYTECODE_STEPS:
        _R11_FIRST_RED_PHASES.setdefault(_code, "bytecode")


def _r11_validate_first_red(
    first_red: Any,
    results: dict[str, Any],
    calls: Sequence[dict[str, Any]],
) -> None:
    value = _r11_exact_keys(first_red, R11_FIRST_RED_KEYS, "builder first red")
    code = value["code"]
    phase = value["phase"]
    if code not in R11_SERIALIZABLE_CODES:
        raise EvidenceFailure("FIRST_RED_CODE", "builder code is outside the closed table")
    expected_phase = _R11_FIRST_RED_PHASES.get(code)
    if code in ("FORGE_NONZERO_EXIT", "COMPILER_IDENTITY_CHECKPOINT_MISMATCH"):
        if phase not in ("forge_version", "forge_build"):
            raise EvidenceFailure("FIRST_RED_PHASE", "Forge code phase mismatch")
    elif phase != expected_phase:
        raise EvidenceFailure("FIRST_RED_PHASE", "first-red code/phase mismatch")
    operands = value["operands"]
    if not isinstance(operands, dict):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red operands are not an object")
    canonical_evidence_bytes(operands)
    call = value["call_ordinal"]
    group_index = value["group_index"]
    group_string = value["group_string"]
    if group_index is None:
        if group_string is not None:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "null group has a group string")
    else:
        if not _r11_u53(group_index) or group_index > 16:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "group index is outside 0..16")
        if group_string != R4_GROUPS[group_index]["group_string"]:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "group string join mismatch")
    if call is not None and (not _r11_u53(call) or call > 17):
        raise EvidenceFailure("FIRST_RED_CONTEXT", "call ordinal is outside 0..17")
    semantic_id = value["semantic_id"]
    target = value["target"]
    authority: dict[str, Any] | None = None
    if semantic_id is None or target is None:
        if semantic_id is not None or target is not None:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "partial target context")
    else:
        authority = next(
            (
                item for item in R4_TARGET_AUTHORITIES
                if item["semantic_id"] == semantic_id and item["target"] == target
            ),
            None,
        )
        if authority is None:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "target authority join mismatch")
        expected_group = R11_GROUP_INDEX_BY_SOURCE[authority["source"]]
        if group_index != expected_group or group_string != R4_GROUPS[expected_group]["group_string"]:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "target group join mismatch")
    step_ordinal = value["step_ordinal"]
    step_id = value["step_id"]
    if phase == "bytecode":
        if authority is None or not _r11_u53(step_ordinal) or not 1 <= step_ordinal <= 26:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "bytecode step context mismatch")
        if step_id != BYTECODE_STEPS[step_ordinal - 1]:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "bytecode step ID mismatch")
        evaluation = next(item for item in results["target_evaluations"] if item["target"] == target)
        trace = evaluation["bytecode_steps"]
        if (
            len(trace) != step_ordinal
            or trace[-1]["error_code"] != code
            or trace[-1]["operands"] != operands
            or trace[-1]["status"] == "pass"
        ):
            raise EvidenceFailure("FIRST_RED_PREFIX", "bytecode first red does not match trace")
    elif step_ordinal is not None or step_id is not None:
        raise EvidenceFailure("FIRST_RED_CONTEXT", "non-bytecode red has step context")
    if phase == "forge_version" and call != 0:
        raise EvidenceFailure("FIRST_RED_CONTEXT", "Forge version red is not call zero")
    if phase in ("forge_build", "group_closure", "portable_input"):
        if group_index is None or call != group_index + 1:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "group call context mismatch")
    if phase in ("artifact_file_read", "artifact_json_decode", "metadata_admission", "bytecode"):
        if authority is None or call != group_index + 1:
            raise EvidenceFailure("FIRST_RED_CONTEXT", "target call context mismatch")
    if phase == "aggregate" and call is not None:
        raise EvidenceFailure("FIRST_RED_CONTEXT", "aggregate context must be call-free")
    if phase in (
        "staged_validation", "output_install", "temp_cleanup", "installed_readback",
        "source_union",
    ) and any(member is not None for member in (call, semantic_id, target, step_ordinal, step_id)):
        raise EvidenceFailure("FIRST_RED_CONTEXT", "global red has target/call context")
    call_count = len(calls)
    if phase == "forge_version":
        expected_calls = 0 if code == "COMPILER_IDENTITY_CHECKPOINT_MISMATCH" else 1
    elif phase == "forge_build":
        expected_calls = call if code == "COMPILER_IDENTITY_CHECKPOINT_MISMATCH" else call + 1
    elif phase in (
        "group_closure", "portable_input", "artifact_file_read",
        "artifact_json_decode", "metadata_admission",
    ):
        expected_calls = call + 1
    else:
        expected_calls = 18
    if call_count != expected_calls:
        raise EvidenceFailure("FIRST_RED_PREFIX", "first-red call prefix is not exact")
    if phase == "forge_version" and results != r11_initial_results():
        raise EvidenceFailure("FIRST_RED_PREFIX", "Forge-version result state is not initial")
    if phase == "source_union" and (
        len(results["groups"]) != 17
        or results["source_union"] is not None
        or results["artifacts"]
        or results["aggregates"]
    ):
        raise EvidenceFailure("FIRST_RED_PREFIX", "source-union prefix is not exact")
    if phase in (
        "forge_build", "group_closure", "portable_input", "artifact_file_read",
        "artifact_json_decode", "metadata_admission",
    ) and len(results["groups"]) != group_index:
        raise EvidenceFailure("FIRST_RED_PREFIX", "group result prefix is not exact")
    if phase in ("bytecode", "aggregate", "staged_validation", "output_install", "temp_cleanup", "installed_readback") and results["source_union"] is None:
        raise EvidenceFailure("FIRST_RED_PREFIX", "post-union phase lacks source authority")
    if phase in (
        "forge_build", "group_closure", "portable_input", "artifact_file_read",
        "artifact_json_decode", "metadata_admission", "source_union", "bytecode",
        "aggregate", "staged_validation", "output_install",
    ) and results["temporary_root"] is None:
        raise EvidenceFailure("FIRST_RED_PREFIX", "active-build phase has no temporary root")
    if phase in ("forge_build", "group_closure", "portable_input", "artifact_file_read", "artifact_json_decode", "metadata_admission", "source_union", "bytecode", "aggregate", "staged_validation", "output_install") and (
        results["output_installed"] or results["output_quarantine_without_matching_go"] or results["output_files"]
    ):
        raise EvidenceFailure("FIRST_RED_PREFIX", "pre-install phase claims installed output")
    if phase == "temp_cleanup" and (
        not results["output_installed"]
        or not results["output_quarantine_without_matching_go"]
        or results["temporary_root"] is None
        or results["output_files"]
    ):
        raise EvidenceFailure("FIRST_RED_PREFIX", "cleanup prefix is not INSTALLED")
    if phase == "installed_readback" and (
        not results["output_installed"]
        or not results["output_quarantine_without_matching_go"]
        or results["temporary_root"] is not None
        or results["output_files"]
    ):
        raise EvidenceFailure("FIRST_RED_PREFIX", "installed-read prefix is not clean")
    exact_operand_keys: dict[str, tuple[str, ...]] = {
        operand_code: _r11_key_authority(*operand_keys)
        for operand_code, operand_keys in {
        "COMPILER_IDENTITY_CHECKPOINT_MISMATCH": (
            "checkpoint_label", "expected_sha256", "actual_sha256",
        ),
        "FORGE_NONZERO_EXIT": (
            "returncode", "stdout_byte_count", "stdout_sha256",
            "stderr_byte_count", "stderr_sha256",
        ),
        "FORGE_VERSION_UTF8": ("byte_count", "sha256"),
        "FORGE_VERSION_EMPTY": ("byte_count", "sha256"),
        "FORGE_VERSION_FORMAT": ("byte_count", "sha256"),
        "FORGE_VERSION_TIMESTAMP_COUNT": ("timestamp_count", "expected_count", "normalized_sha256"),
        "FORGE_VERSION_MISMATCH": ("expected_sha256", "actual_sha256"),
        "GROUP_STRING_MISMATCH": (
            "expected_group_string", "actual_type", "actual_sha256",
        ),
        "GROUP_CLOSURE_MISMATCH": (
            "expected_count", "actual_count", "expected_set_sha256", "actual_set_sha256",
        ),
        "GROUP_SOURCE_CONTENT": ("source_path", "expected_sha256", "actual_sha256"),
        "GROUP_SOURCE_BYTES_MISMATCH": (
            "expected_byte_count", "actual_byte_count",
            "expected_aggregate_sha256", "actual_aggregate_sha256",
        ),
        "PORTABLE_INPUT_BUILD_INFO_COUNT": ("expected_count", "actual_count"),
        "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION": ("exception_type", "message_sha256"),
        "PORTABLE_INPUT_BUILD_INFO_READ": ("path_token", "exception_type", "message_sha256"),
        "PORTABLE_INPUT_BUILD_INFO_JSON": (
            "path_token", "byte_count", "sha256", "reason",
        ),
        "PORTABLE_INPUT_PATH_BINDING": (
            "field", "expected_sha256", "actual_type", "actual_sha256",
        ),
        "PORTABLE_INPUT_PATH_CANONICAL": ("field", "actual_sha256", "reason"),
        "PORTABLE_INPUT_LANGUAGE": ("expected", "actual_type", "actual_sha256"),
        "PORTABLE_INPUT_SOURCES": (
            "expected_count", "actual_type", "actual_count",
            "expected_set_sha256", "actual_set_sha256",
        ),
        "PORTABLE_INPUT_SOURCE_ENTRY": ("source_path", "actual_type"),
        "PORTABLE_INPUT_SOURCE_PATH": ("source_path", "reason"),
        "PORTABLE_INPUT_SOURCE_READ": ("source_path", "exception_type", "message_sha256"),
        "PORTABLE_INPUT_SOURCE_UTF8": ("source_path", "byte_count", "sha256"),
        "PORTABLE_INPUT_SOURCE_CONTENT": (
            "source_path", "expected_sha256", "actual_sha256",
        ),
        "PORTABLE_INPUT_VIA_IR": ("expected", "actual_type", "actual"),
        "PORTABLE_INPUT_EVM_VERSION": ("expected", "actual_type", "actual"),
        "PORTABLE_INPUT_OPTIMIZER": (
            "reason", "actual_type", "enabled", "runs",
        ),
        "PORTABLE_INPUT_METADATA": (
            "reason", "actual_type", "bytecode_hash", "append_cbor",
        ),
        "OP_RETAINED_INPUT_WRITE_EXCEPTION": (
            "path_token", "exception_type", "message_sha256",
        ),
        "ARTIFACT_FILE_READ": ("exception_type", "message_sha256"),
        "ARTIFACT_FILE_IDENTITY_MISMATCH": (
            "before_identity_sha256", "after_identity_sha256", "before_size",
            "after_size", "read_byte_count",
        ),
        "ARTIFACT_JSON_DECODE": ("artifact_byte_count", "artifact_sha256", "reason"),
        "METADATA_TARGET_AND_PATH": ("item", "reason"),
        "METADATA_ARTIFACT_OBJECT_AND_HASH": ("item", "reason"),
        "METADATA_OBJECT": ("item", "reason"),
        "METADATA_COMPILER_VERSION": ("item", "reason"),
        "METADATA_COMPILATION_TARGET": ("item", "reason"),
        "METADATA_VIA_IR": ("item", "reason"),
        "METADATA_EVM_PARIS": ("item", "reason"),
        "METADATA_OPTIMIZER_200": ("item", "reason"),
        "METADATA_NO_HASH_NO_CBOR": ("item", "reason"),
        "METADATA_SOURCE_BINDING": ("item", "reason"),
        "METADATA_BUILD_BINDING": ("item", "reason"),
        "SOURCE_UNION_CONFLICT": (
            "source_path", "first_group_index", "second_group_index",
            "first_sha256", "second_sha256",
        ),
        "SOURCE_UNION_MISMATCH": (
            "expected_count", "actual_count", "expected_aggregate_sha256",
            "actual_aggregate_sha256",
        ),
        "AGGREGATE_MEMBER_MISSING": (
            "aggregate_id", "member_semantic_id", "metric",
        ),
        "STAGED_VALIDATION_FAILED": ("cause_type", "message_sha256"),
        "OP_INSTALL_OUTPUT_NO_REPLACE_EXCEPTION": (
            "path_token", "exception_type", "message_sha256",
        ),
        "OP_BUILD_TEMP_CLEANUP_EXCEPTION": (
            "path_token", "exception_type", "message_sha256",
        ),
        "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION": ("exception_type", "message_sha256"),
        "OP_INSTALLED_OUTPUT_READ_EXCEPTION": ("path_token", "exception_type", "message_sha256"),
        "OUTPUT_TOPOLOGY_MISMATCH": (
            "expected_count", "actual_count", "expected_names_sha256", "actual_names_sha256",
        ),
        "OUTPUT_BYTES_MISMATCH": (
            "path_token", "expected_byte_count", "actual_byte_count",
            "expected_sha256", "actual_sha256",
        ),
        }.items()
    }
    for aggregate_code in (
        "AGG_G3_RUNTIME", "AGG_G3_DEPOSIT", "AGG_G7_RUNTIME", "AGG_G7_DEPOSIT",
        "AGG_G8_READ_RUNTIME", "AGG_G8_READ_DEPOSIT", "AGG_G8_EIGHT_RUNTIME",
        "AGG_G8_EIGHT_DEPOSIT", "AGG_G11_VERIFIER_RUNTIME",
        "AGG_G11_FULL_INITCODE", "AGG_G11_DEPOSIT",
    ):
        exact_operand_keys[aggregate_code] = _r11_key_authority(
            "aggregate_id", "member_semantic_ids", "metric", "values",
            "actual", "operator", "threshold",
        )
    schema = exact_operand_keys.get(code)
    if schema is None and phase != "bytecode":
        raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red code has no closed operand schema")
    if schema is not None:
        try:
            _r11_validate_mapping_authority(
                operands, schema, "first-red operands",
            )
        except ValueError as exc:
            raise EvidenceFailure(
                "FIRST_RED_OPERANDS", "first-red operand schema mismatch",
            ) from exc
    exception_pattern = re.compile(r"[A-Za-z_][A-Za-z0-9_.]{0,255}")
    observed_types = (None, "null", "boolean", "integer", "string", "array", "object")
    nullable_hashes = {
        ("GROUP_STRING_MISMATCH", "actual_sha256"),
        ("PORTABLE_INPUT_PATH_BINDING", "actual_sha256"),
        ("PORTABLE_INPUT_LANGUAGE", "actual_sha256"),
        ("PORTABLE_INPUT_SOURCES", "actual_set_sha256"),
    }
    nullable_u53 = {
        ("PORTABLE_INPUT_SOURCES", "actual_count"),
        ("BC_CREATION_LINKS_MISSING", "entry_count"),
        ("BC_CREATION_LINKS_NOT_OBJECT", "entry_count"),
        ("BC_RUNTIME_LINKS_MISSING", "entry_count"),
        ("BC_RUNTIME_LINKS_NOT_OBJECT", "entry_count"),
        ("ABI_NOT_ARRAY", "constructor_count"),
    }
    for key, member in operands.items():
        if key.endswith("sha256") and not (
            _r11_sha(member) or member is None and (code, key) in nullable_hashes
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red hash mismatch")
        if key.endswith("count") or key.endswith("size") or key.endswith("byte_count"):
            if not (
                _r11_u53(member)
                or member is None
                and (code, key) in nullable_u53
            ):
                raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red U53 mismatch")
        if key == "path_token":
            _r11_validate_filetoken(member)
        if key in ("exception_type", "cause_type") and (
            not isinstance(member, str) or exception_pattern.fullmatch(member) is None
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red exception type mismatch")
        if key == "actual_type" and member not in observed_types:
            raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red observed type mismatch")
        if key == "source_path" and member not in {
            source for group in R4_GROUPS for source in group["sources"]
        }:
            raise EvidenceFailure("FIRST_RED_OPERANDS", "first-red source path is not authoritative")
    if code == "FORGE_NONZERO_EXIT" and (
        type(operands["returncode"]) is not int
        or not -9_007_199_254_740_991 <= operands["returncode"] <= 9_007_199_254_740_991
        or operands["returncode"] == 0
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "Forge nonzero return code mismatch")
    if code == "COMPILER_IDENTITY_CHECKPOINT_MISMATCH":
        expected_label = (
            "pre-started" if call is None
            else f"invocation-{call:03d}-before"
        )
        if operands["checkpoint_label"] != expected_label:
            raise EvidenceFailure("FIRST_RED_OPERANDS", "checkpoint label/context mismatch")
    if code == "FORGE_VERSION_MISMATCH" and operands["expected_sha256"] != R11_FORGE_VERSION_IDENTITY_SHA256:
        raise EvidenceFailure("FIRST_RED_OPERANDS", "Forge pin authority mismatch")
    if code == "FORGE_VERSION_TIMESTAMP_COUNT" and (
        operands["expected_count"] != 1 or operands["timestamp_count"] == 1
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "timestamp cardinality mismatch")
    if code == "PORTABLE_INPUT_BUILD_INFO_COUNT" and (
        operands["expected_count"] != 1 or operands["actual_count"] == 1
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "build-info cardinality mismatch")
    if code == "PORTABLE_INPUT_BUILD_INFO_JSON" and operands["reason"] not in (
        "duplicate_key", "syntax", "non_ijson", "non_object",
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "build-info JSON reason is not exact")
    if code in (
        "PORTABLE_INPUT_BUILD_INFO_READ", "PORTABLE_INPUT_BUILD_INFO_JSON",
    ):
        try:
            path_token = _r11_validate_filetoken(operands["path_token"])
        except (TypeError, ValueError) as exc:
            raise EvidenceFailure(
                "FIRST_RED_OPERANDS", "build-info token is not a FILETOKEN"
            ) from exc
        if not path_token.startswith(f"build-info/{group_index:03d}/"):
            raise EvidenceFailure(
                "FIRST_RED_OPERANDS", "build-info token is not a full group token"
            )
    if code == "GROUP_STRING_MISMATCH":
        expected_group_string = R4_GROUPS[group_index]["group_string"]
        if (
            operands["expected_group_string"] != expected_group_string
            or (operands["actual_sha256"] is None) != (operands["actual_type"] != "string")
            or (
                operands["actual_type"] == "string"
                and operands["actual_sha256"]
                == sha256_bytes(expected_group_string.encode("utf-8"))
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "group-string failure is not exact")
    if code == "GROUP_CLOSURE_MISMATCH":
        expected_names = sorted(R4_GROUPS[group_index]["sources"], key=str.casefold)
        if (
            operands["expected_count"] != len(expected_names)
            or operands["expected_set_sha256"]
            != sha256_bytes(canonical_evidence_bytes(expected_names))
            or (
                operands["actual_count"] == operands["expected_count"]
                and operands["actual_set_sha256"] == operands["expected_set_sha256"]
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "group-closure failure is not exact")
    if code == "GROUP_SOURCE_CONTENT" and operands["source_path"] not in R4_GROUPS[group_index]["sources"]:
        raise EvidenceFailure("FIRST_RED_OPERANDS", "group source does not belong to its group")
    if code == "GROUP_SOURCE_CONTENT" and operands["expected_sha256"] == operands["actual_sha256"]:
        raise EvidenceFailure("FIRST_RED_OPERANDS", "group source content did not differ")
    if code == "GROUP_SOURCE_BYTES_MISMATCH" and (
        operands["expected_aggregate_sha256"]
        != "sha256:" + R4_GROUPS[group_index]["aggregate_sha256"].lower()
        or (
            operands["expected_byte_count"] == operands["actual_byte_count"]
            and operands["expected_aggregate_sha256"]
            == operands["actual_aggregate_sha256"]
        )
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "group-byte failure is not exact")
    if code == "SOURCE_UNION_CONFLICT" and (
        not _r11_u53(operands["first_group_index"])
        or not _r11_u53(operands["second_group_index"])
        or operands["second_group_index"] > 16
        or operands["first_group_index"] >= operands["second_group_index"]
        or operands["first_sha256"] == operands["second_sha256"]
        or operands["source_path"] not in R4_GROUPS[operands["first_group_index"]]["sources"]
        or operands["source_path"] not in R4_GROUPS[operands["second_group_index"]]["sources"]
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "source-union conflict is not exact")
    if code == "SOURCE_UNION_MISMATCH" and (
        operands["expected_count"] != 31
        or operands["expected_aggregate_sha256"]
        != "sha256:" + R4_SOURCE_AGGREGATE_SHA256.lower()
        or (
            operands["actual_count"] == operands["expected_count"]
            and operands["actual_aggregate_sha256"]
            == operands["expected_aggregate_sha256"]
        )
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "source-union mismatch is not exact")
    if code == "PORTABLE_INPUT_PATH_BINDING" and (
        operands["field"] not in ("out", "cache", "build_info")
        or (operands["actual_sha256"] is None) != (operands["actual_type"] is None)
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable path binding is not exact")
    if code == "PORTABLE_INPUT_PATH_CANONICAL" and (
        operands["field"] not in ("out", "cache", "build_info")
        or operands["reason"] not in (
            "not_absolute", "wrong_root", "separator", "dot_component",
            "case_mismatch",
        )
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable canonical path is not exact")
    if code == "PORTABLE_INPUT_LANGUAGE" and (
        operands["expected"] != "Solidity"
        or (operands["actual_sha256"] is None) != (operands["actual_type"] is None)
        or (
            operands["actual_type"] == "string"
            and operands["actual_sha256"] == canonical_json_sha256("Solidity")
        )
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable language row is not exact")
    if code == "PORTABLE_INPUT_SOURCES":
        object_observed = operands["actual_type"] == "object"
        expected_sources = sorted(R4_GROUPS[group_index]["sources"], key=str.casefold)
        expected_set_sha256 = sha256_bytes(canonical_evidence_bytes(expected_sources))
        if (
            (operands["actual_count"] is not None) != object_observed
            or (operands["actual_set_sha256"] is not None) != object_observed
            or operands["expected_count"] != len(expected_sources)
            or operands["expected_set_sha256"] != expected_set_sha256
            or object_observed and (
                operands["actual_count"] == operands["expected_count"]
                and operands["actual_set_sha256"] == expected_set_sha256
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "portable source set is not exact")
    if code == "PORTABLE_INPUT_SOURCE_ENTRY" and operands["actual_type"] in (None, "object"):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable source entry type is absent")
    if code == "PORTABLE_INPUT_SOURCE_PATH" and operands["reason"] not in (
        "absent", "not_forward_relative", "dot_component", "outside_root",
        "case_mismatch",
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable source path reason is not exact")
    if code in (
        "PORTABLE_INPUT_SOURCE_ENTRY", "PORTABLE_INPUT_SOURCE_PATH",
        "PORTABLE_INPUT_SOURCE_READ", "PORTABLE_INPUT_SOURCE_UTF8",
        "PORTABLE_INPUT_SOURCE_CONTENT",
    ) and operands["source_path"] not in R4_GROUPS[group_index]["sources"]:
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable source is outside its group")
    if code == "PORTABLE_INPUT_SOURCE_CONTENT" and (
        operands["expected_sha256"] == operands["actual_sha256"]
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable source content did not differ")
    if code == "PORTABLE_INPUT_VIA_IR" and (
        operands["expected"] is not True
        or (operands["actual"] is not None) != (operands["actual_type"] == "boolean")
        or operands["actual"] is True
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable via-IR row is not exact")
    if code == "PORTABLE_INPUT_EVM_VERSION" and (
        operands["expected"] != EVM_VERSION
        or (operands["actual"] is not None) != (operands["actual_type"] == "string")
        or operands["actual"] == EVM_VERSION
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "portable EVM row is not exact")
    if code == "PORTABLE_INPUT_OPTIMIZER":
        reason = operands["reason"]
        if reason not in ("missing", "not_object", "enabled_not_true", "runs_not_200"):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "portable optimizer reason is not exact")
        expected_shape = {
            "missing": (None, None, None),
            "not_object": (operands["actual_type"], None, None),
            "enabled_not_true": ("object", operands["enabled"], None),
            "runs_not_200": ("object", True, operands["runs"]),
        }[reason]
        if (
            (operands["actual_type"], operands["enabled"], operands["runs"])
            != expected_shape
            or reason == "not_object" and operands["actual_type"] in (None, "object")
            or reason == "enabled_not_true" and (
                operands["enabled"] is not None
                and type(operands["enabled"]) is not bool
                or operands["enabled"] is True
            )
            or reason == "runs_not_200" and (
                operands["runs"] is not None
                and not _r11_u53(operands["runs"])
                or operands["runs"] == OPTIMIZER_RUNS
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "portable optimizer state is not exact")
    if code == "PORTABLE_INPUT_METADATA":
        reason = operands["reason"]
        if reason not in (
            "missing", "not_object", "bytecode_hash_not_none", "append_cbor_not_false",
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "portable metadata reason is not exact")
        expected_shape = {
            "missing": (None, None, None),
            "not_object": (operands["actual_type"], None, None),
            "bytecode_hash_not_none": ("object", operands["bytecode_hash"], None),
            "append_cbor_not_false": ("object", "none", operands["append_cbor"]),
        }[reason]
        if (
            (operands["actual_type"], operands["bytecode_hash"], operands["append_cbor"])
            != expected_shape
            or reason == "not_object" and operands["actual_type"] in (None, "object")
            or reason == "bytecode_hash_not_none" and (
                operands["bytecode_hash"] is not None
                and not isinstance(operands["bytecode_hash"], str)
                or operands["bytecode_hash"] == "none"
            )
            or reason == "append_cbor_not_false" and (
                operands["append_cbor"] is not None
                and type(operands["append_cbor"]) is not bool
                or operands["append_cbor"] is False
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "portable metadata state is not exact")
    metadata_reasons = {
        "METADATA_TARGET_AND_PATH": (1, {
            "configured_target_tuple", "artifact_path_missing", "artifact_path_ambiguous",
            "artifact_path_not_ordinary", "artifact_path_lookup_failure",
        }),
        "METADATA_ARTIFACT_OBJECT_AND_HASH": (2, {"artifact_not_object", "artifact_hash_mismatch"}),
        "METADATA_OBJECT": (3, {"metadata_missing", "metadata_not_object", "metadata_json_invalid"}),
        "METADATA_COMPILER_VERSION": (4, {"compiler_missing", "compiler_not_object", "version_missing", "version_not_string", "version_mismatch"}),
        "METADATA_COMPILATION_TARGET": (5, {"settings_missing", "settings_not_object", "compilation_target_missing", "compilation_target_not_object", "compilation_target_mismatch"}),
        "METADATA_VIA_IR": (6, {"via_ir_not_true"}),
        "METADATA_EVM_PARIS": (7, {"evm_version_not_paris"}),
        "METADATA_OPTIMIZER_200": (8, {"optimizer_missing", "optimizer_not_object", "enabled_not_true", "runs_not_200"}),
        "METADATA_NO_HASH_NO_CBOR": (9, {"metadata_settings_missing", "metadata_settings_not_object", "bytecode_hash_not_none", "append_cbor_not_false"}),
        "METADATA_SOURCE_BINDING": (10, {"sources_missing", "sources_not_object", "sources_empty", "source_entry_not_object", "keccak_missing", "keccak_not_string", "source_path_invalid", "source_missing", "source_keccak_mismatch", "configured_source_absent"}),
        "METADATA_BUILD_BINDING": (11, {"source_set_mismatch", "source_receipt_mismatch", "compiler_input_binding_mismatch", "forge_argv_mismatch", "forge_environment_mismatch", "canonical_build_input_mismatch"}),
    }
    if code in metadata_reasons:
        item, reasons = metadata_reasons[code]
        if operands["item"] != item or operands["reason"] not in reasons:
            raise EvidenceFailure("FIRST_RED_OPERANDS", "metadata item/reason mismatch")
    if code == "ARTIFACT_JSON_DECODE" and operands["reason"] not in (
        "duplicate_key", "syntax", "non_ijson",
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "artifact JSON reason mismatch")
    if code == "OUTPUT_TOPOLOGY_MISMATCH":
        expected_output_names = sorted(
            [MANIFEST_FILENAME]
            + [
                f"compiler-inputs/{index:03d}-{Path(group['source']).stem}.json"
                for index, group in enumerate(R4_GROUPS)
            ]
            + [
                f"{Path(authority['source']).name}/{authority['target']}.json"
                for authority in R4_TARGET_AUTHORITIES
            ]
        )
        if (
            operands["expected_count"] != 37
            or operands["expected_names_sha256"]
            != sha256_bytes(canonical_evidence_bytes(expected_output_names))
            or (
                operands["actual_count"] == operands["expected_count"]
                and operands["actual_names_sha256"]
                == operands["expected_names_sha256"]
            )
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "output topology authority mismatch")
    if code == "OUTPUT_BYTES_MISMATCH" and (
        not operands["path_token"].startswith("installed/")
        or (
            operands["expected_byte_count"] == operands["actual_byte_count"]
            and operands["expected_sha256"] == operands["actual_sha256"]
        )
    ):
        raise EvidenceFailure("FIRST_RED_OPERANDS", "output byte mismatch is not exact")
    aggregate_rows = {
        gate_id: (trigger, members, metric, threshold)
        for trigger, rows in R4_AGGREGATE_GATES.items()
        for gate_id, members, metric, threshold in rows
    }
    if code == "AGGREGATE_MEMBER_MISSING":
        aggregate_id = operands["aggregate_id"]
        if aggregate_id not in aggregate_rows:
            raise EvidenceFailure("FIRST_RED_OPERANDS", "missing aggregate ID is unknown")
        trigger, members, metric, _ = aggregate_rows[aggregate_id]
        measurements = {
            artifact["semantic_id"]: artifact
            for artifact in results["artifacts"]
        }
        missing_members = [member for member in members if member not in measurements]
        if (
            not missing_members
            or operands["member_semantic_id"] != missing_members[0]
            or operands["metric"] != metric
            or authority != R4_TARGET_AUTHORITIES[trigger - 1]
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "missing aggregate member is not exact")
    if code in aggregate_rows:
        trigger, members, metric, threshold = aggregate_rows[code]
        measurements = {
            artifact["semantic_id"]: artifact
            for artifact in results["artifacts"]
        }
        if any(member not in measurements for member in members):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "aggregate members are unavailable")
        values = [measurements[member][metric] for member in members]
        trigger_authority = R4_TARGET_AUTHORITIES[trigger - 1]
        if (
            operands["aggregate_id"] != code
            or operands["member_semantic_ids"] != list(members)
            or operands["metric"] != metric
            or operands["values"] != values
            or operands["actual"] != sum(values)
            or operands["operator"] != "<="
            or operands["threshold"] != threshold
            or operands["actual"] <= threshold
            or authority != trigger_authority
        ):
            raise EvidenceFailure("FIRST_RED_OPERANDS", "aggregate failure does not reconstruct")


def _r11_decode_event(raw: bytes, name: str) -> tuple[dict[str, Any], bytes, str]:
    try:
        value = require_dict(load_json_bytes(raw, Path(name)), name)
    except ReleaseBuildError as exc:
        raise EvidenceFailure(
            "EVENT_SCHEMA", "event JSON/object decoding failed",
        ) from exc
    if canonical_evidence_bytes(value) != raw:
        raise EvidenceFailure("NONCANONICAL_EVIDENCE", "event bytes are not canonical")
    _r11_validate_event(value)
    return value, raw, sha256_bytes(raw)


def _r11_load_event(directory: Path, name: str) -> tuple[dict[str, Any], bytes, str]:
    raw, token, _ = r11_native_read(directory / name, name)
    if token != name:
        raise EvidenceFailure("EVENT_TOKEN_MISMATCH", "event token mismatch")
    return _r11_decode_event(raw, name)


def _r11_event_pair_call(
    start: dict[str, Any],
    start_sha256: str,
    exit_event: dict[str, Any],
    exit_sha256: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    _r11_validate_event(start)
    _r11_validate_event(exit_event)
    start_operands = require_dict(start["operands"], "start.operands")
    exit_operands = require_dict(exit_event["operands"], "exit.operands")
    if (
        start["event_type"] != "invocation_start"
        or exit_event["event_type"] != "invocation_exit"
        or exit_event["sequence"] != start["sequence"] + 1
        or exit_event["previous_event_sha256"] != start_sha256
        or exit_event["invocation_id"] != start["invocation_id"]
        or exit_event["phase"] != start["phase"]
        or exit_operands["ordinal"] != start_operands["ordinal"]
        or exit_operands["group_string"] != start_operands["group_string"]
        or exit_operands["start_monotonic_ms"] != start_operands["start_monotonic_ms"]
    ):
        raise EvidenceFailure("EVENT_PAIR_PARITY", "invocation event pair does not cross-bind")
    call = {
        "ordinal": start_operands["ordinal"],
        "phase": start["phase"],
        "group_string": start_operands["group_string"],
        "start_event_sha256": start_sha256,
        "exit_event_sha256": exit_sha256,
        "argv_sha256": start_operands["argv_sha256"],
        "environment_sha256": start_operands["environment_sha256"],
        "launched": exit_operands["launched"],
        "exit_code": exit_operands["exit_code"],
        "stdout_byte_count": exit_operands["stdout_byte_count"],
        "stdout_sha256": exit_operands["stdout_sha256"],
        "stderr_byte_count": exit_operands["stderr_byte_count"],
        "stderr_sha256": exit_operands["stderr_sha256"],
        "exception_type": exit_operands["exception_type"],
        "exception_sha256": exit_operands["exception_sha256"],
    }
    return call, start_operands["checkpoint"], exit_operands["checkpoint"]


_R11_TERMINAL_KEYS = _r11_key_authority(
    "schema", "invocation_id", "status", "first_red", "event_count",
    "event_head_sha256", "calls", "checkpoints", "results", "no_retry",
)


def _r11_validate_terminal_envelope(terminal: Any) -> dict[str, Any]:
    value = _r11_exact_keys(terminal, _R11_TERMINAL_KEYS, "terminal")
    if value["schema"] != EVIDENCE_TERMINAL_SCHEMA or not _r11_sha(value["invocation_id"]):
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal schema/invocation mismatch")
    if value["status"] not in ("GO", "NO_GO"):
        raise EvidenceFailure("TERMINAL_STATUS", "terminal status is not closed")
    if not _r11_u53(value["event_count"]) or value["event_count"] < 1 or value["event_count"] > R4_SUCCESS_EVENT_COUNT:
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal event count is outside 1..37")
    if value["event_count"] % 2 != 1 or not _r11_sha(value["event_head_sha256"]):
        raise EvidenceFailure("TERMINAL_SCHEMA", "builder terminal does not end on an even pair")
    if value["no_retry"] is not True:
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal no-retry marker is not literal true")
    if not isinstance(value["calls"], list) or not isinstance(value["checkpoints"], list):
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal calls/checkpoints are not arrays")
    for ordinal, call in enumerate(value["calls"]):
        _r11_validate_call(call, ordinal)
    if len(value["calls"]) != (value["event_count"] - 1) // 2:
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal call/event count mismatch")
    if len(value["checkpoints"]) != value["event_count"]:
        raise EvidenceFailure("TERMINAL_SCHEMA", "terminal checkpoint/event count mismatch")
    for index, checkpoint in enumerate(value["checkpoints"]):
        _r11_validate_checkpoint(checkpoint, f"terminal checkpoint {index}")
        expected_label = (
            "pre-started" if index == 0 else
            f"invocation-{(index - 1) // 2:03d}-{'before' if index % 2 else 'after'}"
        )
        if checkpoint["label"] != expected_label:
            raise EvidenceFailure("CHECKPOINT_SCHEMA", "checkpoint order mismatch")
    return value


def r11_validate_builder_terminal(terminal: Any) -> None:
    value = _r11_validate_terminal_envelope(terminal)
    results = _r11_exact_keys(value["results"], R11_RESULT_KEYS, "builder results")
    _r11_validate_result_state(results, first_red=value["first_red"])
    if value["status"] == "GO":
        if value["first_red"] is not None:
            raise EvidenceFailure("TERMINAL_GO_SCHEMA", "GO contains first-red")
        if (
            value["event_count"] != R4_SUCCESS_EVENT_COUNT
            or len(value["calls"]) != 18
            or len(value["checkpoints"]) != 37
            or len(results["groups"]) != 17
            or results["source_union"] != validate_evidence_source_union(results["groups"])
            or any(not item["bytecode_completed"] for item in results["target_evaluations"])
            or len(results["artifacts"]) != 19
            or len(results["aggregates"]) != 11
            or len(results["output_files"]) != 37
            or results["output_installed"] is not True
            or results["output_quarantine_without_matching_go"] is not True
            or results["temporary_root"] is not None
        ):
            raise EvidenceFailure("TERMINAL_GO_SCHEMA", "GO is not exact complete state")
        if any(call["exit_code"] != 0 for call in value["calls"]):
            raise EvidenceFailure("TERMINAL_GO_SCHEMA", "GO contains a nonzero invocation")
        return
    if value["first_red"] is None:
        raise EvidenceFailure("FIRST_RED_SCHEMA", "builder NO_GO has no first red")
    _r11_validate_first_red(value["first_red"], results, value["calls"])
    nonzero_ordinals = [
        call["ordinal"] for call in value["calls"] if call["exit_code"] != 0
    ]
    expected_nonzero = (
        [value["first_red"]["call_ordinal"]]
        if value["first_red"]["code"] == "FORGE_NONZERO_EXIT" else []
    )
    if nonzero_ordinals != expected_nonzero:
        raise EvidenceFailure("FIRST_RED_PREFIX", "nonzero invocation prefix mismatch")


def r11_validate_recovery_terminal(
    terminal: Any,
    *,
    expected_invocation_id: str,
    expected_sentinel_sha256: str,
    expected_event_count: int,
    expected_event_head_sha256: str,
) -> None:
    if (
        not _r11_sha(expected_invocation_id)
        or not _r11_sha(expected_sentinel_sha256)
        or not _r11_u53(expected_event_count)
        or not 1 <= expected_event_count <= R4_SUCCESS_EVENT_COUNT
        or not _r11_sha(expected_event_head_sha256)
    ):
        raise EvidenceFailure(
            "RECOVERY_RESULT_SCHEMA",
            "authenticated STARTED-prefix context is malformed",
        )
    value = _r11_exact_keys(terminal, _R11_TERMINAL_KEYS, "recovery terminal")
    if (
        value["schema"] != EVIDENCE_TERMINAL_SCHEMA
        or not _r11_sha(value["invocation_id"])
        or value["status"] != "NO_GO"
        or value["no_retry"] is not True
        or not _r11_u53(value["event_count"])
        or not 1 <= value["event_count"] <= R4_SUCCESS_EVENT_COUNT
        or not _r11_sha(value["event_head_sha256"])
        or value["calls"] != []
        or value["checkpoints"] != []
        or value["first_red"] != {"code": "interrupted_execution", "operands": {}}
    ):
        raise EvidenceFailure("RECOVERY_TERMINAL_SCHEMA", "recovery envelope is not exact")
    results = _r11_exact_keys(
        value["results"],
        (
            "recovery", "path_token_status", "anomalies", "sentinel_sha256",
            "predicates_evaluated", "subprocess_calls", "output_validated",
        ),
        "recovery results",
    )
    if (
        results["recovery"] is not True
        or results["path_token_status"] != []
        or not isinstance(results["anomalies"], list)
        or not _r11_sha(results["sentinel_sha256"])
        or results["predicates_evaluated"] != 0
        or results["subprocess_calls"] != 0
        or results["output_validated"] is not False
    ):
        raise EvidenceFailure("RECOVERY_RESULT_SCHEMA", "recovery results are not fixed negative state")
    if (
        value["invocation_id"] != expected_invocation_id
        or results["sentinel_sha256"] != expected_sentinel_sha256
        or value["event_count"] != expected_event_count
        or value["event_head_sha256"] != expected_event_head_sha256
    ):
        raise EvidenceFailure(
            "RECOVERY_RESULT_SCHEMA",
            "recovery terminal does not bind its authenticated STARTED prefix",
        )
    previous_token: str | None = None
    for anomaly in results["anomalies"]:
        item = _r11_exact_keys(
            anomaly,
            ("path_token", "status", "exception_type", "message_sha256"),
            "recovery anomaly",
        )
        _r11_validate_filetoken(item["path_token"])
        if previous_token is not None and item["path_token"] <= previous_token:
            raise EvidenceFailure("RECOVERY_RESULT_SCHEMA", "recovery anomalies are not strict sorted")
        previous_token = item["path_token"]
        if item["status"] == "invalid":
            if (
                item["exception_type"]
                not in set(R11_CANONICAL_DIAGNOSTICS) | {"EVENT_PREFIX_INVALID"}
                or not _r11_sha(item["message_sha256"])
            ):
                raise EvidenceFailure("RECOVERY_RESULT_SCHEMA", "invalid anomaly is malformed")
            if item["exception_type"] == "EVENT_PREFIX_INVALID" and item[
                "message_sha256"
            ] != sha256_bytes(
                canonical_evidence_bytes(
                    {
                        "code": "EVENT_PREFIX_INVALID",
                        "path_token": item["path_token"],
                    }
                )
            ):
                raise EvidenceFailure(
                    "RECOVERY_RESULT_SCHEMA",
                    "event-prefix anomaly hash does not reconstruct",
                )
        elif item["status"] == "unlinked":
            if item["exception_type"] is not None or item["message_sha256"] is not None:
                raise EvidenceFailure("RECOVERY_RESULT_SCHEMA", "unlinked anomaly is malformed")
        else:
            raise EvidenceFailure("RECOVERY_RESULT_SCHEMA", "unknown recovery anomaly status")


class ExecutionJournal:
    """R11 exception-atomic evidence journal with an immutable disk authority."""

    def __init__(
        self,
        evidence_dir: Path,
        invocation_id: str,
        static_receipts: dict[str, Any],
        forge_bin: Path,
        solc_bin: Path,
        *,
        held_evidence_directory_identity: dict[str, str] | None = None,
        pre_started_checkpoint: dict[str, Any] | None = None,
        execution_authority: R11ExecutionAuthority,
    ) -> None:
        self.execution_authority = execution_authority
        self.evidence_dir = evidence_dir
        self.invocation_id = invocation_id
        self.static_receipts = static_receipts
        self.forge_bin = forge_bin
        self.solc_bin = solc_bin
        self.held_evidence_directory_identity = (
            dict(held_evidence_directory_identity)
            if held_evidence_directory_identity is not None
            else dict(static_receipts["evidence_dir"]["identity"])
        )
        self.pre_started_checkpoint = (
            pre_started_checkpoint
            if pre_started_checkpoint is not None
            else _r11_checkpoint("pre-started", forge_bin, solc_bin, static_receipts)
        )
        self.sequence = -1
        self.event_head_sha256: str | None = None
        self.calls: list[dict[str, Any]] = []
        self.checkpoints: list[dict[str, Any]] = []
        self.terminal: dict[str, Any] | None = None
        self.state: str = "PRE_EVENT"
        self.guard: dict[str, Any] | None = None
        try:
            _r11_require_journal_execution_authority(self)
        except BaseException as primary:
            if type(execution_authority) is R11ExecutionAuthority:
                execution_authority.close(primary)
            raise

    def publish_started(self) -> dict[str, Any]:
        _r11_require_journal_execution_authority(self)
        if self.state != "PRE_EVENT" or self.sequence != -1:
            raise EvidenceFailure("STATE_NOT_EMPTY", "STARTED requires PRE_EVENT")
        operands = {
            "path_tokens": self.static_receipts,
            "held_evidence_directory_identity": self.held_evidence_directory_identity,
            "pre_started_checkpoint": self.pre_started_checkpoint,
        }
        event = {
            "schema": EVIDENCE_EVENT_SCHEMA,
            "invocation_id": self.invocation_id,
            "sequence": 0,
            "previous_event_sha256": None,
            "event_type": "execution_started",
            "phase": "execution",
            "operands": operands,
        }
        raw = canonical_evidence_bytes(event)
        digest = sha256_bytes(raw)
        _r11_publish_preconstructed(
            self.evidence_dir, "execution-started.json", event, raw, digest,
        )
        self.sequence = 0
        self.event_head_sha256 = digest
        self.checkpoints = [self.pre_started_checkpoint]
        self.state = "STARTED_IDLE"
        return event

    def _checkpoint(self, label: str) -> dict[str, Any]:
        return _r11_checkpoint(
            label, self.forge_bin, self.solc_bin, self.static_receipts,
        )

    @staticmethod
    def _expected_binding(ordinal: int) -> tuple[str, str | None]:
        if ordinal == 0:
            return "forge_version", None
        return "forge_build", R4_GROUPS[ordinal - 1]["group_string"]

    def invoke(
        self,
        ordinal: int,
        command: list[str],
        cwd: Path,
        *,
        phase: str,
        group_string: str | None,
    ) -> CommandResult:
        _r11_require_journal_execution_authority(self)
        if self.state != "STARTED_IDLE" or self.guard is not None:
            raise EvidenceFailure("STATE_NOT_IDLE", "invocation requires STARTED_IDLE")
        if ordinal != len(self.calls) or not 0 <= ordinal <= 17:
            raise EvidenceFailure("CALL_ORDINAL", "invocation ordinal is not adjacent")
        expected_phase, expected_group = self._expected_binding(ordinal)
        if phase != expected_phase or group_string != expected_group:
            raise EvidenceFailure("CALL_BINDING", "invocation phase/group binding mismatch")
        try:
            checkpoint_before = self._checkpoint(f"invocation-{ordinal:03d}-before")
        except EvidenceFailure as exc:
            if exc.code != "COMPILER_IDENTITY_CHECKPOINT_MISMATCH":
                raise
            raise _r11_first_red(
                exc.code,
                phase,
                exc.operands,
                call_ordinal=ordinal,
                group_index=None if ordinal == 0 else ordinal - 1,
            ) from exc
        environment = sanitized_forge_environment()
        environment_raw = canonical_evidence_bytes(environment)
        start_monotonic_ms = time.monotonic_ns() // 1_000_000
        sequence = self.sequence + 1
        start_event = {
            "schema": EVIDENCE_EVENT_SCHEMA,
            "invocation_id": self.invocation_id,
            "sequence": sequence,
            "previous_event_sha256": self.event_head_sha256,
            "event_type": "invocation_start",
            "phase": phase,
            "operands": {
                "ordinal": ordinal,
                "group_string": group_string,
                "executable": command[0],
                "argv": command,
                "argv_sha256": sha256_bytes(canonical_evidence_bytes(command)),
                "environment_sha256": sha256_bytes(environment_raw),
                "environment_entry_count": len(environment),
                "cwd": str(cwd),
                "start_monotonic_ms": start_monotonic_ms,
                "checkpoint": checkpoint_before,
            },
        }
        start_raw = canonical_evidence_bytes(start_event)
        start_sha256 = sha256_bytes(start_raw)
        self.guard = {
            "ordinal": ordinal,
            "phase": phase,
            "group_string": group_string,
            "start_event_sha256": start_sha256,
        }
        self.state = f"START_PUBLISHING({ordinal})"
        _r11_publish_preconstructed(
            self.evidence_dir,
            _event_filename(sequence),
            start_event,
            start_raw,
            start_sha256,
        )
        self.state = f"CALL_OPEN({ordinal})"
        result = _captured_subprocess(command, cwd, environment)
        if (
            result.launched is not True
            or result.returncode is None
            or not isinstance(result.stdout, bytes)
            or not isinstance(result.stderr, bytes)
        ):
            raise TypeError("only one returned binary completed process proves launch")
        checkpoint_after = self._checkpoint(f"invocation-{ordinal:03d}-after")
        end_monotonic_ms = time.monotonic_ns() // 1_000_000
        exit_event = {
            "schema": EVIDENCE_EVENT_SCHEMA,
            "invocation_id": self.invocation_id,
            "sequence": sequence + 1,
            "previous_event_sha256": start_sha256,
            "event_type": "invocation_exit",
            "phase": phase,
            "operands": {
                "ordinal": ordinal,
                "group_string": group_string,
                "launched": True,
                "exit_code": result.returncode,
                "start_monotonic_ms": start_monotonic_ms,
                "end_monotonic_ms": end_monotonic_ms,
                "stdout_byte_count": len(result.stdout),
                "stdout_sha256": sha256_bytes(result.stdout),
                "stderr_byte_count": len(result.stderr),
                "stderr_sha256": sha256_bytes(result.stderr),
                "exception_type": None,
                "exception_sha256": None,
                "checkpoint": checkpoint_after,
            },
        }
        exit_raw = canonical_evidence_bytes(exit_event)
        exit_sha256 = sha256_bytes(exit_raw)
        _r11_publish_preconstructed(
            self.evidence_dir,
            _event_filename(sequence + 1),
            exit_event,
            exit_raw,
            exit_sha256,
        )
        disk_start, disk_start_raw, disk_start_sha = _r11_load_event(
            self.evidence_dir, _event_filename(sequence),
        )
        disk_exit, disk_exit_raw, disk_exit_sha = _r11_load_event(
            self.evidence_dir, _event_filename(sequence + 1),
        )
        if (
            disk_start_raw != start_raw
            or disk_exit_raw != exit_raw
            or disk_start_sha != start_sha256
            or disk_exit_sha != exit_sha256
            or disk_exit["previous_event_sha256"] != disk_start_sha
        ):
            raise EvidenceFailure("EVENT_PAIR_PARITY", "durable event pair is not exact")
        call, before, after = _r11_event_pair_call(
            disk_start, disk_start_sha, disk_exit, disk_exit_sha,
        )
        self.sequence = sequence + 1
        self.event_head_sha256 = exit_sha256
        self.calls.append(call)
        self.checkpoints.extend((before, after))
        self.guard = None
        self.state = "STARTED_IDLE"
        if result.returncode != 0:
            raise _r11_first_red(
                "FORGE_NONZERO_EXIT",
                phase,
                {
                    "returncode": result.returncode,
                    "stdout_byte_count": len(result.stdout),
                    "stdout_sha256": sha256_bytes(result.stdout),
                    "stderr_byte_count": len(result.stderr),
                    "stderr_sha256": sha256_bytes(result.stderr),
                },
                call_ordinal=ordinal,
                group_index=None if ordinal == 0 else ordinal - 1,
            )
        return result

    def _disk_prefix(
        self,
        event_bytes: dict[str, bytes],
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], str]:
        events: list[dict[str, Any]] = []
        calls: list[dict[str, Any]] = []
        checkpoints = [self.pre_started_checkpoint]
        started_path_tokens: dict[str, Any] | None = None
        previous: str | None = None
        for sequence in range(self.sequence + 1):
            name = _event_filename(sequence)
            event, _, digest = _r11_decode_event(
                event_bytes[name], name,
            )
            if (
                event.get("sequence") != sequence
                or event.get("previous_event_sha256") != previous
                or event.get("invocation_id") != self.invocation_id
            ):
                raise EvidenceFailure("EVENT_CHAIN_MISMATCH", "disk event chain mismatch")
            events.append(event)
            previous = digest
            if sequence == 0:
                started_operands = event["operands"]
                started_path_tokens = started_operands["path_tokens"]
                if (
                    started_operands["path_tokens"] != self.static_receipts
                    or started_operands["held_evidence_directory_identity"]
                    != self.held_evidence_directory_identity
                    or started_operands["pre_started_checkpoint"] != self.pre_started_checkpoint
                    or event["invocation_id"] != self.invocation_id
                ):
                    raise EvidenceFailure(
                        "TERMINAL_DISK_STATE_MISMATCH",
                        "STARTED does not match the retained invocation authority",
                    )
            if sequence > 0 and sequence % 2 == 0:
                start = events[-2]
                call, before, after = _r11_event_pair_call(
                    start,
                    sha256_bytes(canonical_evidence_bytes(start)),
                    event,
                    digest,
                )
                _r11_validate_call(call, len(calls))
                _r11_validate_checkpoint(before, f"disk before {len(calls)}")
                _r11_validate_checkpoint(after, f"disk after {len(calls)}")
                if started_path_tokens is None:
                    raise EvidenceFailure("TERMINAL_DISK_STATE_MISMATCH", "STARTED authority is absent")
                _r11_validate_checkpoint_authority(before, started_path_tokens)
                _r11_validate_checkpoint_authority(after, started_path_tokens)
                calls.append(call)
                checkpoints.extend((before, after))
        return calls, checkpoints, require_string(previous, "event head")

    def _candidate_terminal_gate(self, terminal: dict[str, Any]) -> None:
        if self.state != "STARTED_IDLE" or self.guard is not None or self.sequence % 2 != 0:
            raise EvidenceFailure("TERMINAL_PARITY_VETO", "journal state is not an even idle prefix")
        expected_names = [_event_filename(sequence) for sequence in range(self.sequence + 1)]
        event_bytes: dict[str, bytes] = {}
        with R11RetainedTree(self.evidence_dir, "evidence") as evidence:
            actual_topology = evidence.topology()
            expected_topology = _r11_expected_topology(expected_names)
            if actual_topology != expected_topology:
                raise EvidenceFailure(
                    "TERMINAL_NAMESPACE_VETO",
                    "terminal candidate sees an ambiguous evidence namespace",
                    operands={
                        "expected_names_sha256": sha256_bytes(
                            canonical_evidence_bytes(sorted(expected_names))
                        ),
                        "actual_names_sha256": sha256_bytes(
                            canonical_evidence_bytes(sorted(evidence.files))
                        ),
                    },
                )
            for name in sorted(expected_names):
                event_bytes[name] = evidence.read_file(name)
        calls, checkpoints, head = self._disk_prefix(event_bytes)
        if calls != self.calls or checkpoints != self.checkpoints:
            raise EvidenceFailure("TERMINAL_DISK_STATE_MISMATCH", "terminal call/checkpoint state is not disk-derived")
        if (
            terminal["event_count"] != self.sequence + 1
            or terminal["event_head_sha256"] != head
            or terminal["calls"] != calls
            or terminal["checkpoints"] != checkpoints
        ):
            raise EvidenceFailure("TERMINAL_CANDIDATE_MISMATCH", "terminal candidate does not bind disk prefix")
        r11_validate_builder_terminal(terminal)

    def publish_terminal(
        self,
        status: str,
        first_red: dict[str, Any] | None,
        *,
        results: dict[str, Any],
    ) -> dict[str, Any]:
        authority = self.execution_authority
        if type(authority) is not R11ExecutionAuthority:
            raise EvidenceFailure(
                "EXECUTION_AUTHORITY",
                "authoritative terminal requires its exact execution authority",
            )
        primary: BaseException | None = None
        try:
            _r11_require_journal_execution_authority(self)
            if status not in ("GO", "NO_GO") or self.terminal is not None:
                raise EvidenceFailure("TERMINAL_STATUS", "invalid or duplicate terminal")
            terminal = {
                "schema": EVIDENCE_TERMINAL_SCHEMA,
                "invocation_id": self.invocation_id,
                "status": status,
                "first_red": first_red,
                "event_count": self.sequence + 1,
                "event_head_sha256": self.event_head_sha256,
                "calls": self.calls,
                "checkpoints": self.checkpoints,
                "results": results,
                "no_retry": True,
            }
            self._candidate_terminal_gate(terminal)
            raw = canonical_evidence_bytes(terminal)
            digest = sha256_bytes(raw)
            self.state = "TERMINAL"
            _r11_publish_preconstructed(
                self.evidence_dir, "terminal.json", terminal, raw, digest,
            )
            self.terminal = terminal
            return terminal
        except BaseException as exc:
            primary = exc
            raise
        finally:
            authority.close(primary)


def recover_interrupted(evidence_dir: Path) -> dict[str, Any]:
    recovery_boundary_owner = R11BoundaryOwner(
        "RECOVERY_INVENTORY",
        (("recovery", True),),
        None,
        None,
        lifecycle_token="evidence",
    )
    evidence = validate_absolute_ordinary_path(
        evidence_dir, "evidence directory", directory=True,
    )
    lock = WindowsDirectoryLock.acquire(evidence, recovery=True)
    try:
        evidence_bytes: dict[str, bytes] = {}
        read_failure: str | None = None
        inventory_anomalies: list[dict[str, Any]] = []
        try:
            with R11RetainedTree(evidence, "evidence") as retained:
                names = {entry["name"] for entry in retained.entries}
                file_names = set(retained.files)
                if "terminal.json" in names:
                    raise EvidenceFailure("TERMINAL", "recovery refuses a preexisting terminal")
                if "execution-started.json" not in file_names:
                    raise EvidenceFailure(
                        "EMPTY" if not names else "SENTINEL_MISSING",
                        "recovery requires canonical STARTED",
                    )
                selected_names = ["execution-started.json"]
                selected_sequence = 1
                while selected_sequence < R4_SUCCESS_EVENT_COUNT:
                    selected_name = _event_filename(selected_sequence)
                    if selected_name not in file_names:
                        break
                    selected_names.append(selected_name)
                    selected_sequence += 1
                retained.select_read_order(selected_names, require_sorted=False)
                for selected_name in selected_names:
                    try:
                        evidence_bytes[selected_name] = retained.read_file(selected_name)
                    except R11TraversalDiagnostic as diagnostic:
                        if selected_name == "execution-started.json":
                            raise
                        translated = recovery_boundary_owner.translate(
                            diagnostic, None,
                        )
                        if not isinstance(translated, dict):
                            raise AssertionError(
                                "recovery read diagnostic did not produce an anomaly"
                            )
                        inventory_anomalies.append(
                            {"path_token": selected_name, **translated}
                        )
                        read_failure = selected_name
                        break
        except R11TraversalDiagnostic as diagnostic:
            translated = recovery_boundary_owner.translate(diagnostic, None)
            if not isinstance(translated, dict):
                raise AssertionError("recovery diagnostic did not produce an anomaly")
            anomaly_token = diagnostic.operands["path_token"] or "evidence"
            _r11_validate_filetoken(anomaly_token)
            inventory_anomalies.append(
                {"path_token": anomaly_token, **translated}
            )
            sentinel_raw, _, _ = r11_native_read(
                evidence / "execution-started.json", "execution-started.json",
            )
            evidence_bytes["execution-started.json"] = sentinel_raw
            names = {"execution-started.json"}
            file_names = {"execution-started.json"}
        if "terminal.json" in names:
            raise EvidenceFailure("TERMINAL", "recovery refuses a preexisting terminal")
        sentinel, sentinel_raw, sentinel_digest = _r11_decode_event(
            evidence_bytes["execution-started.json"], "execution-started.json",
        )
        if (
            sentinel.get("schema") != EVIDENCE_EVENT_SCHEMA
            or sentinel.get("sequence") != 0
            or sentinel.get("previous_event_sha256") is not None
            or sentinel.get("event_type") != "execution_started"
            or sentinel.get("phase") != "execution"
        ):
            raise EvidenceFailure("SENTINEL_NONCANONICAL", "STARTED schema mismatch")
        operands = require_dict(sentinel.get("operands"), "STARTED operands")
        path_tokens = require_dict(operands["path_tokens"], "STARTED path tokens")
        static_identity = require_dict(
            require_dict(path_tokens["evidence_dir"], "evidence receipt")["identity"],
            "static evidence identity",
        )
        held_identity = require_dict(
            operands["held_evidence_directory_identity"], "held evidence identity",
        )
        if static_identity != held_identity or lock.identity != held_identity:
            raise EvidenceFailure("RECOVERY_EVIDENCE_IDENTITY", "recovery evidence identity differs")
        events = [sentinel]
        head = sentinel_digest
        anomalies: list[dict[str, Any]] = list(inventory_anomalies)
        sequence = 1
        while sequence < R4_SUCCESS_EVENT_COUNT:
            name = _event_filename(sequence)
            if name not in names:
                break
            if name == read_failure:
                break
            try:
                event, _, digest = _r11_decode_event(evidence_bytes[name], name)
                if (
                    event.get("sequence") != sequence
                    or event.get("previous_event_sha256") != head
                    or event.get("invocation_id") != sentinel.get("invocation_id")
                    or event.get("event_type") != (
                        "invocation_start" if sequence % 2 else "invocation_exit"
                    )
                ):
                    raise EvidenceFailure("EVENT_CHAIN_MISMATCH", "event prefix mismatch")
            except BaseException as exc:
                del exc
                anomalies.append(
                    {
                        "path_token": name,
                        "status": "invalid",
                        "exception_type": "EVENT_PREFIX_INVALID",
                        "message_sha256": sha256_bytes(
                            canonical_evidence_bytes(
                                {"code": "EVENT_PREFIX_INVALID", "path_token": name}
                            )
                        ),
                    }
                )
                break
            events.append(event)
            head = digest
            sequence += 1
        expected_prefix_names = {_event_filename(index) for index in range(len(events))}
        anomaly_names = {anomaly["path_token"] for anomaly in anomalies}
        for name in sorted(names - expected_prefix_names - anomaly_names):
            anomalies.append(
                {
                    "path_token": name,
                    "status": "unlinked",
                    "exception_type": None,
                    "message_sha256": None,
                }
            )
        terminal = {
            "schema": EVIDENCE_TERMINAL_SCHEMA,
            "invocation_id": require_string(sentinel["invocation_id"], "invocation_id"),
            "status": "NO_GO",
            "first_red": {"code": "interrupted_execution", "operands": {}},
            "event_count": len(events),
            "event_head_sha256": head,
            "calls": [],
            "checkpoints": [],
            "results": {
                "recovery": True,
                "path_token_status": [],
                "anomalies": sorted(anomalies, key=lambda item: item["path_token"]),
                "sentinel_sha256": sentinel_digest,
                "predicates_evaluated": 0,
                "subprocess_calls": 0,
                "output_validated": False,
            },
            "no_retry": True,
        }
        r11_validate_recovery_terminal(
            terminal,
            expected_invocation_id=require_string(
                sentinel["invocation_id"], "invocation_id",
            ),
            expected_sentinel_sha256=sentinel_digest,
            expected_event_count=len(events),
            expected_event_head_sha256=head,
        )
        raw = canonical_evidence_bytes(terminal)
        digest = sha256_bytes(raw)
        _r11_publish_preconstructed(evidence, "terminal.json", terminal, raw, digest)
        return terminal
    finally:
        lock.close()


def validate_authoritative_output(output: Path, evidence_dir: Path) -> dict[str, Any]:
    expected_evidence_names = [
        _event_filename(sequence) for sequence in range(R4_SUCCESS_EVENT_COUNT)
    ] + ["terminal.json"]
    evidence_contents: dict[str, bytes] = {}
    with R11RetainedTree(evidence_dir, "evidence") as evidence:
        expected_topology = _r11_expected_topology(expected_evidence_names)
        actual_topology = evidence.topology()
        if actual_topology != expected_topology:
            raise EvidenceFailure(
                "TERMINAL_NAMESPACE_VETO",
                "authoritative evidence namespace is not exact",
                operands={
                    "expected_names_sha256": sha256_bytes(
                        canonical_evidence_bytes(sorted(expected_evidence_names))
                    ),
                    "actual_names_sha256": sha256_bytes(
                        canonical_evidence_bytes(sorted(evidence.files))
                    ),
                },
            )
        for name in sorted(expected_evidence_names):
            evidence_contents[name] = evidence.read_file(name)
    terminal_raw = evidence_contents["terminal.json"]
    terminal = require_dict(
        load_json_bytes(terminal_raw, evidence_dir / "terminal.json"),
        "authoritative terminal",
    )
    if canonical_evidence_bytes(terminal) != terminal_raw:
        raise EvidenceFailure("TERMINAL_NONCANONICAL", "terminal bytes are not canonical")
    r11_validate_builder_terminal(terminal)
    if terminal["status"] != "GO":
        raise EvidenceFailure("TERMINAL_NOT_GO", "authoritative output requires GO")
    results = terminal["results"]
    previous: str | None = None
    events: list[dict[str, Any]] = []
    calls: list[dict[str, Any]] = []
    checkpoints: list[dict[str, Any]] = []
    started_path_tokens: dict[str, Any] | None = None
    for sequence in range(R4_SUCCESS_EVENT_COUNT):
        name = _event_filename(sequence)
        raw = evidence_contents[name]
        event = require_dict(load_json_bytes(raw, Path(name)), name)
        if canonical_evidence_bytes(event) != raw:
            raise EvidenceFailure("NONCANONICAL_EVIDENCE", "event bytes are not canonical")
        _r11_validate_event(event)
        digest = sha256_bytes(raw)
        if (
            event["sequence"] != sequence
            or event["previous_event_sha256"] != previous
            or event["invocation_id"] != terminal["invocation_id"]
        ):
            raise EvidenceFailure("EVENT_CHAIN_MISMATCH", "GO event chain is not gap-free")
        events.append(event)
        if sequence == 0:
            checkpoints.append(event["operands"]["pre_started_checkpoint"])
            started_path_tokens = event["operands"]["path_tokens"]
        elif sequence % 2 == 0:
            start = events[-2]
            call, before, after = _r11_event_pair_call(
                start,
                sha256_bytes(canonical_evidence_bytes(start)),
                event,
                digest,
            )
            calls.append(call)
            checkpoints.extend((before, after))
            if started_path_tokens is None:
                raise EvidenceFailure("EVENT_CHAIN_MISMATCH", "STARTED authority is absent")
            _r11_validate_checkpoint_authority(before, started_path_tokens)
            _r11_validate_checkpoint_authority(after, started_path_tokens)
        previous = digest
    if previous != terminal.get("event_head_sha256"):
        raise EvidenceFailure("EVENT_HEAD_MISMATCH", "GO event head differs")
    if calls != terminal["calls"] or checkpoints != terminal["checkpoints"]:
        raise EvidenceFailure("TERMINAL_DISK_STATE_MISMATCH", "GO terminal copies differ from events")
    expected_receipts = results["output_files"]
    manifest_raw: bytes | None = None
    with R11RetainedTree(output, "installed") as installed:
        _, contents = _r11_read_retained_output(installed, expected_receipts)
        manifest_raw = contents.get(MANIFEST_FILENAME)
    if manifest_raw is None:
        raise EvidenceFailure("OUTPUT_TOPOLOGY_MISMATCH", "installed manifest is absent")
    return require_dict(load_json_bytes(manifest_raw, output / MANIFEST_FILENAME), "manifest")


# Preserve the public compatibility aliases only after the complete R11 closure
# exists. The active build path calls the R11 implementation directly; the R4
# functions remain explicitly named for historical regression coverage.
_prepare_evidence_run = _prepare_evidence_run_r11
_build_release_output_evidence = _build_release_output_evidence_r11


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    raw_argv = list(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-config", type=Path, default=DEFAULT_FOUNDRY_CONFIG)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--forge-bin", default="forge")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--solc-bin", type=Path)
    parser.add_argument("--evidence-dir", type=Path)
    parser.add_argument("--recover-interrupted", action="store_true")
    args = parser.parse_args(raw_argv)
    provided_options = {
        token.split("=", 1)[0]
        for token in raw_argv
        if token.startswith("--")
    }
    if args.recover_interrupted:
        allowed = {"--recover-interrupted", "--evidence-dir"}
        forbidden = sorted(provided_options - allowed)
        if forbidden:
            parser.error(
                "--recover-interrupted accepts only --evidence-dir; forbidden: "
                + ", ".join(forbidden)
            )
        if args.evidence_dir is None:
            parser.error("--recover-interrupted requires --evidence-dir")
        if args.solc_bin is not None or args.check:
            parser.error("recovery forbids --solc-bin and --check")
        return args
    if (args.solc_bin is None) != (args.evidence_dir is None):
        parser.error("--solc-bin and --evidence-dir must be supplied together")
    if args.evidence_dir is not None and args.check:
        parser.error("authoritative evidence mode cannot be combined with --check")
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.recover_interrupted:
        try:
            terminal = recover_interrupted(args.evidence_dir)
        except (OSError, ReleaseBuildError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1
        print(
            "interrupted release build recorded as NO_GO "
            f"({terminal['event_count']} prefix events)"
        )
        return 1
    try:
        if args.evidence_dir is not None:
            repo_root = args.repo_root
            config_path = args.config
            foundry_config_path = args.foundry_config
            output_dir = args.output_dir
        else:
            repo_root = args.repo_root.resolve()
            config_path = resolve_repo_path(repo_root, args.config, "contract config")
            foundry_config_path = resolve_repo_path(
                repo_root,
                args.foundry_config,
                "Foundry config",
            )
            output_dir = resolve_canonical_output_path(repo_root, args.output_dir)
        if args.check:
            forge_version = read_forge_version(args.forge_bin, repo_root)
            manifest = validate_release_output(
                repo_root,
                config_path,
                foundry_config_path,
                output_dir,
                expected_forge_version=forge_version,
            )
            print(
                "canonical release build is current "
                f"({len(manifest['targets'])} isolated targets)"
            )
            return 0
        manifest = build_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
            args.forge_bin,
            solc_bin=args.solc_bin,
            evidence_dir=args.evidence_dir,
        )
    except (OSError, ReleaseBuildError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except (KeyboardInterrupt, SystemExit) as exc:
        if args.evidence_dir is None:
            raise
        print(f"error: {type(exc).__name__}", file=sys.stderr)
        return 1

    print(
        f"{normalize_path(output_dir, repo_root)}/{MANIFEST_FILENAME} "
        f"({len(manifest['targets'])} isolated targets)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
