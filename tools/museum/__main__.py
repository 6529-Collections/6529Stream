"""python -m tools.museum export-fixture|verify-fixture (offline only)."""

import argparse
from pathlib import Path

from .canonical import MuseumError
from .preview import fixture_package, verify_fixture_package, write_package


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser("export-fixture")
    export.add_argument("--schema", type=Path, required=True)
    export.add_argument("--source", type=Path, required=True)
    export.add_argument("--output", type=Path, required=True)
    verify = commands.add_parser("verify-fixture")
    verify.add_argument("package", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "export-fixture":
            for path in (args.schema, args.source):
                if path.stat().st_size > 24576:
                    raise MuseumError("fixture input byte limit")
            write_package(args.output, fixture_package(args.schema.read_bytes(), args.source.read_bytes()))
            verify_fixture_package(args.output)
        else:
            verify_fixture_package(args.package)
    except (MuseumError, OSError, KeyError) as exc:
        parser.exit(1, str(exc) + "\n")
    print("Fixture package verified; onchain, Linked Art and institutional conformance not evaluated.")


if __name__ == "__main__":
    main()
