#!/usr/bin/env python3
"""Validate substantive current auction flows documentation boundaries."""
from __future__ import annotations
import sys
from pathlib import Path
from tools.docs.doc_contract import run, validate_document

DEFAULT_DOC = Path('docs/integrations/auction-flows.md')
REQUIRED_TERMS = ['createAuction', 'minimumBid', 'setDeliveryRecipient', 'claimNoBidNFT', 'withdrawRefund', 'totalBidEscrow']
REQUIRED_LINKS = ['docs/integrations/wallets-and-signatures.md', 'docs/integrations/withdrawals-and-credits.md']
REQUIRED_COMMANDS = []
SOURCE_TERMS = [('smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol', ['function cancel(uint256 tokenId)', 'function withdrawRefund('])]

class AuctionFlowsError(ValueError):
    """Current documentation contract violation."""


def validate_auction_flows(repo_root, document_path):
    try:
        validate_document(repo_root, document_path, terms=REQUIRED_TERMS,
                          links=REQUIRED_LINKS, commands=REQUIRED_COMMANDS,
                          source_terms=SOURCE_TERMS, sale_schema=False)
    except ValueError as exc:
        raise AuctionFlowsError(str(exc)) from exc


def main(argv=None):
    return run(argv or [], default=DEFAULT_DOC, option='--auction-flows', validate=validate_auction_flows)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
