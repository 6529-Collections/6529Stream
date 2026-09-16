"""Versioned original-owner source for accession, disposition, citation and claims.

V1 loan/valuation source bytes keep their original meaning. V2 additionally
requires complete selected redemption lanes; membership and order come from the
pinned host, never from a submitted list's order or its publication timestamp.
"""
from .canonical import keccak256, record_chain, schema_id, uint
from .independent_wire import ZERO, require
from .owner_record_source import OwnerRecordSource

PROFILE = "STREAM_MUSEUM_INSTITUTIONAL_OWNER_SOURCE_V1"
NEW_FAMILIES = ("ACCESSION", "DEACCESSION", "REDEMPTION_CLAIM", "CITATION")


class InstitutionalOwnerSource(OwnerRecordSource):
    profile = PROFILE
    # Only this profile's closed public payloads may enter its retained source
    # closure. Unrelated owner lanes use their own disclosure-aware exporters.
    families = tuple(schema_id(name) for name in NEW_FAMILIES)

    def _validate_predecessor(self, record, receipt):
        from .institutional import JCS_ID, NAMES, SCHEMAS, validate_payload
        family = next((name for name in NEW_FAMILIES if schema_id(name) == record[0]), None)
        require(family is not None and record[2] == schema_id(NAMES[family])
            and receipt[9] == keccak256(SCHEMAS[family]) and record[3][2] == JCS_ID,
            "institutional predecessor public schema required")
        validate_payload(family, record[5])

    def _capture_extra(self, records):
        from .institutional import _admit_row
        for row in records.values():
            family = next(name for name in NEW_FAMILIES if schema_id(name) == row["record"][0])
            _admit_row(self, row, family)
        family = schema_id("REDEMPTION_CLAIM")
        tokens = sorted({r["receipt"][0] for r in records.values() if r["record"][0] == family}, key=uint)
        lanes = {}
        for token in tokens:
            _, (head, count) = self._read(self.a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (uint(token), family), ("bytes32", "uint64"))
            require(0 < count <= 128, "institutional complete redemption lane bound")
            hashes, previous = [], ZERO
            for index in range(count):
                _, (digest,) = self._read(self.a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (uint(token), family, index), ("bytes32",))
                require(digest in records and digest not in hashes, "institutional complete redemption selection missing")
                row = records[digest]
                require(row["record"][0] == family and row["receipt"][0] == token
                    and uint(row["receipt"][3]) == index, "institutional redemption lane differs")
                previous = record_chain(self.a["chainId"], self.a["host"], token, family, previous, digest, str(index))
                require(previous == row["receipt"][4], "institutional redemption full chain differs")
                hashes.append(digest)
            require(previous == head, "institutional redemption head differs")
            lanes[token] = {"records": hashes, "head": head, "count": str(count)}
        self.redemption_lanes = lanes
        return {"redemptionLanes": lanes, "qualification": "Complete selected token redemption lanes at the pinned host/block; no fulfillment or legal title proof."}
