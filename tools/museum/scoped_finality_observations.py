"""Reconcile additive transaction observations without changing frozen history policy."""
from . import conservation_capture_join as history
from . import public_scoped_finality_rpc as rpc
from .canonical import dumps
from .independent_wire import require


def reconcile(source, calls, pins):
    ordinary, transactions, count = {}, {}, 0
    for role, rows in calls.items():
        ordinary[role] = []
        for row in rows:
            rpc._row(row)
            if row["method"] != "eth_getTransactionByHash":
                ordinary[role].append(row)
                continue
            count += 1
            digest, observation = row["params"][0], dumps(row["result"])
            require(digest not in transactions or transactions[digest] == observation,
                "scoped join original transaction observation differs")
            transactions[digest] = observation
    result = history._observations(source, ordinary, pins)
    return {"history": result, "originalTransactionRows": str(count),
        "distinctOriginalTransactions": str(len(transactions)),
        "originalTransactionReceiptAndHeaderBinding": "verified by scoped source replay and supplied fragment",
        "transactionSignaturesVerified": False, "sourceConsensusVerified": False}
