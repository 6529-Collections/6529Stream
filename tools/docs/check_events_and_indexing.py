#!/usr/bin/env python3
"""Validate substantive current events and indexing documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/events-and-indexing.md')
REQUIRED_TERMS = ['NativeSaleSettled', 'SaleParticipants', 'blockHash', 'logIndex', 'coordinatorAtMint', 'tokenSeed', 'tokenEntropyStatus']
REQUIRED_LINKS = ['docs/integrations/metadata-rendering.md', 'SECURITY.md']
REQUIRED_COMMANDS = []
SOURCE_TERMS = []

class EventsAndIndexingError(ValueError):
    """Current documentation contract violation."""


def validate_events_and_indexing(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise EventsAndIndexingError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--events-and-indexing', validate=validate_events_and_indexing)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
