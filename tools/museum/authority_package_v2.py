"""Replayable typed authority packages under the explicitly versioned profile."""
from .authority_package import _build_authority_package, _verify_authority_package, main as _main


def build_authority_package(directory, expected_manifest_hash, request_bytes, selection_bytes, snapshots, *,
                            request_hash, selection_hash, profile_hash, disclosure):
    return _build_authority_package(directory, expected_manifest_hash, request_bytes, selection_bytes, snapshots,
        request_hash=request_hash, selection_hash=selection_hash, profile_hash=profile_hash, disclosure=disclosure, version="2")


def verify_authority_package(directory, expected_manifest_hash):
    return _verify_authority_package(directory, expected_manifest_hash, version="2")


if __name__ == "__main__": _main(version="2")
