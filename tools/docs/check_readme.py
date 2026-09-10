#!/usr/bin/env python3
"""Validate substantive current readme documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('README.md')
REQUIRED_TERMS = ['StreamCore', 'StreamMintManager']
REQUIRED_LINKS = ['docs/first-30-minutes.md', 'docs/integrations/README.md', 'SECURITY.md']
REQUIRED_COMMANDS = ['python scripts/dev.py doctor', 'python scripts/dev.py build', 'python scripts/dev.py test']
SOURCE_TERMS = []

class ReadmeError(ValueError):
    """Current documentation contract violation."""


def validate_readme(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise ReadmeError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--readme', validate=validate_readme)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
