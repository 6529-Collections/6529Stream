#!/usr/bin/env python3
"""Validate substantive current withdrawals credits flow documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/withdrawals-and-credits.md')
REQUIRED_TERMS = ['releasable', 'wallet.release', 'refundCredit', 'withdrawRefund', 'msg.sender == account', '1,000,000']
REQUIRED_LINKS = ['docs/integrations/auction-flows.md', 'smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol']
REQUIRED_COMMANDS = []
SOURCE_TERMS = [('smart-contracts/domains/revenue/StreamSplitWallet.sol', ['function release(', 'function releasable('])]

class WithdrawalsCreditsFlowError(ValueError):
    """Current documentation contract violation."""


def validate_withdrawals_credits_flow(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise WithdrawalsCreditsFlowError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--doc', validate=validate_withdrawals_credits_flow)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
