#!/usr/bin/env python3
"""Validate substantive current metadata rendering documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/metadata-rendering.md')
REQUIRED_TERMS = ['tokenURI', 'coordinatorAtMint', 'requestEntropy', 'metadata_state', 'animation_url', 'sandbox', '65,536']
REQUIRED_LINKS = ['docs/integrations/events-and-indexing.md', 'smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol']
REQUIRED_COMMANDS = []
SOURCE_TERMS = []

class MetadataRenderingError(ValueError):
    """Current documentation contract violation."""


def validate_metadata_rendering(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise MetadataRenderingError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--metadata-rendering', validate=validate_metadata_rendering)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
