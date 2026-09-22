"""Offline recorded-account projection with externally supplied source/profile commitments."""

from pathlib import Path

from .account_profile import AccountProjectionProfile
from .canonical import dumps, keccak256
from .chain_rpc import ReplayTransport
from .independent_publication import IndependentPublicationAdapter
from .independent_source import IndependentSourceAdapter
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .recorded_selection import project_recorded


REPLAY_INPUTS = ("anchor.json", "transcript.json", "publication-hints.json",
                 "publication-transcript.json", "interpretation-transcript.json")


def replay_source_bytes(root, inputs, *, source_hash, publication_hash, interpretation_hash, profile_hash):
    """Replay one retained byte snapshot; never reread mutable input paths during export."""
    source = IndependentSourceAdapter(inputs["anchor.json"],
        ReplayTransport(inputs["transcript.json"], source_hash), provenance="trusted_rpc")
    publication = IndependentPublicationAdapter(source, inputs["publication-hints.json"],
        ReplayTransport(inputs["publication-transcript.json"], publication_hash), provenance="trusted_rpc")
    profile = AccountProjectionProfile(root)
    if profile.profile_hash != profile_hash:
        from .typed_authority_profile import TypedAuthorityProfile
        profile = TypedAuthorityProfile(root)
        if profile.profile_hash != profile_hash:
            from .declaration_lineage_profile import DeclarationLineageProfile
            profile = DeclarationLineageProfile(root, expected_hash=profile_hash)
    interpretation = RegisteredInterpretationCapture(publication, profile,
        ReplayTransport(inputs["interpretation-transcript.json"], interpretation_hash))
    return RecordedSemanticSource(interpretation, profile_hash=profile_hash)


def replay_source(root, directory, **pins):
    return replay_source_bytes(root, {name: (directory / name).read_bytes() for name in REPLAY_INPUTS}, **pins)


def output_files(result):
    files = {name + ".json": getattr(result, name) for name in ("sidecar", "coverage", "provenance", "report")}
    for index, resource in enumerate(result.resources):
        files["resource-" + str(index) + ".json"] = resource.content
        files["expanded-" + str(index) + ".json"] = resource.expanded
    return files


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    for name in ("source", "publication", "interpretation", "profile", "selection", "plan"):
        parser.add_argument("--" + name + "-hash", required=True)
    args = parser.parse_args()
    source = replay_source(Path(__file__).resolve().parents[2] / "schemas/museum", args.input,
        source_hash=args.source_hash, publication_hash=args.publication_hash,
        interpretation_hash=args.interpretation_hash, profile_hash=args.profile_hash)
    result = project_recorded(source, (args.input / "selection.json").read_bytes(), (args.input / "plan.json").read_bytes(),
        selection_hash=args.selection_hash, plan_hash=args.plan_hash)
    args.output.mkdir(parents=True, exist_ok=False)
    files = output_files(result)
    for name, raw in files.items():
        (args.output / name).write_bytes(raw)
    print(dumps({"mode": "recorded_account_resource_projection", "environment": source.anchor["environment"],
        "files": {name: keccak256(raw) for name, raw in files.items()}, "profileHash": source.profile_hash,
        "cryptographicStateProof": False, "humanIndependenceEstablished": False}).decode())


if __name__ == "__main__":
    main()
