#!/usr/bin/env python3
"""Validate substantive current first 30 minutes documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/first-30-minutes.md')
REQUIRED_TERMS = ['Python **3.12**', 'foundryup --install 1.7.1', 'cold']
REQUIRED_LINKS = ['docs/tooling.md', 'SECURITY.md']
REQUIRED_COMMANDS = ['python scripts/dev.py doctor', 'python scripts/dev.py build', 'python scripts/dev.py test', 'python scripts/dev.py release']
SOURCE_TERMS = []

class First30MinutesError(ValueError):
    """Current documentation contract violation."""


def validate_guide(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise First30MinutesError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--guide', validate=validate_guide)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
