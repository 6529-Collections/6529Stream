#!/usr/bin/env python3
"""Validate substantive current wallet signature flows documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/wallets-and-signatures.md')
REQUIRED_TERMS = ['6529StreamFixedPriceSale', '6529StreamEnglishAuction', 'authorizationDigest', 'ERC-1271', '100,000', 'signerEpoch']
REQUIRED_LINKS = ['docs/integrations/contract-flows.md', 'SECURITY.md']
REQUIRED_COMMANDS = []
SOURCE_TERMS = []

class WalletSignatureFlowsError(ValueError):
    """Current documentation contract violation."""


def validate_wallet_signature_flows(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=True)
    except ValueError as exc:
        raise WalletSignatureFlowsError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--wallet-signature-flows', validate=validate_wallet_signature_flows)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
