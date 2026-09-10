#!/usr/bin/env python3
"""Validate substantive current integrations readme documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/README.md')
REQUIRED_TERMS = ['StreamFixedPriceSaleAdapter.buy', 'legacy']
REQUIRED_LINKS = ['docs/integrations/contract-flows.md', 'docs/integrations/wallets-and-signatures.md', 'SECURITY.md']
REQUIRED_COMMANDS = []
SOURCE_TERMS = []

class IntegrationsReadmeError(ValueError):
    """Current documentation contract violation."""


def validate_integrations_readme(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise IntegrationsReadmeError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--readme', validate=validate_integrations_readme)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
