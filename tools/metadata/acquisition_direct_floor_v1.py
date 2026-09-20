"""Standalone supplied DIRECT floor evidence; no capture replay or complete packet claim."""
import argparse
import copy
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from .acquisition_personhood_v1 import abi, array, closed, native, nullable, ref
from tools.museum import public_direct_conservation_source as source
from tools.museum import public_direct_conservation_capture as capture
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from tools.museum.chain_abi import encode
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, json_values, require

ROOT = Path(__file__).resolve().parents[2]
NAME = "STREAM_ACQUISITION_DIRECT_FLOOR_V1"
MAX_BYTES = 16777216
F = source.f
SOURCE_REF_FIELDS = ("manifestHash", "anchorHash", "transcriptHash", "snapshotHash", "sourceProfileHash", "captureProfileHash")
STATE_FIELDS = ("chainId", "core", "conservationFloor", "collectionId", "blockHash", "blockNumber", "timestamp", "environment")
QUALIFICATION = ("Prospective unregistered supplied-data DIRECT floor fragment. Original twelve-member DIRECT receipts, "
    "six-member adapter bindings, sixteen-member paid receipts, native FIRST/RELEASE/SOURCE facts and original "
    "manager/token observations remain distinct from universal settlement evidence. Exact supplied hashes, fields, "
    "source revisions, receipt positions and denominator correspondence are checked. Source references do not "
    "authenticate themselves; validation performs no RPC replay, runtime admission, signature verification, payment "
    "execution, token-to-operation proof, personhood or documentary-fact verification. Foreign universal receipts "
    "remain typed discovery observations; target universal or mixed histories are unsupported. No recorded target "
    "sale is not proof about free, unpaid, cancelled or no-bid operations. No supplemental, all-paid-route, consensus, "
    "native runtime acceptance or full acquisition packet claim is made. Packet versions V1–V4 remain unchanged.")
RULES = [
    "Numeric version1 identifies this standalone fragment; source and capture profile hashes are exact frozen DIRECT pins.",
    "Source state preserves the eight fields actually retained by the frozen source. Its anchor hash does not reveal omitted stateRoot or deployment evidence; capture replay owns that authentication.",
    "Full native structs retain original order. FIRST, RELEASE and DIRECT receipt hashes zero only receiptHash in their own domains; adapter keys and paid receipt hashes use the original six bindings and product kind.",
    "The complete supplied source catalogue and typed ledger denominator are bounded and ordered. Target originals must equal every target denominator occurrence; another collection never substitutes for the target.",
    "The source active when each original FIRST/RELEASE was recorded is retained. A later source admission does not rewrite historical facts; reused releases retain their original creator.",
    "Fixed-price creation time equals paid publication time; auction creation may be earlier. Manager used-state and completed token identity are supplied observations, not newly executed authority checks.",
    "Publication coordinates, known timestamps, immutable original adapter bindings, runtime commitments and repeated action/token observations must agree. No missing ancestry, receipt inclusion or provider log completeness is proved.",
]
SOURCE_FIELDS = ("metadata", "metadataCodeHash", "provider", "providerCodeHash", "configurationHash", "predecessor", "admittedAt", "actionId")
FIRST_FIELDS = ("receiptHash", "collectionId", "effectiveTier", "recorder", "settlementKey", "recordedAt", "sourceId", "sourceSetHash")
RELEASE_FIELDS = ("receiptHash", "releaseKey", "collectionId", "effectiveTier", "recorder", "settlementKey", "recordedAt", "sourceId", "sourceSetHash")
DIRECT_FIELDS = ("receiptHash", "adapter", "adapterCodeHash", "directKey", "authorizationId", "originalReceiptHash")
SPECS = {"first_sale": (F.FIRST, F.FIRST_DOMAIN, 1, 1), "release": (F.RELEASE, F.RELEASE_DOMAIN, 2, 1),
    "settlement": (F.SETTLEMENT, F.SETTLEMENT_DOMAIN, 7, 3), "direct": (source.DIRECT, source.DIRECT_DOMAIN, None, 3)}


def fields(names, kinds): return {name: abi(kind) for name, kind in zip(names, kinds, strict=True)}


def definitions():
    h, a = abi("bytes32"), abi("address")
    publication = closed({**fields(("blockHash", "transactionHash"), ("bytes32", "bytes32")),
        **fields(("blockNumber", "transactionIndex", "logIndex"), ("uint256",) * 3)})
    pins = {key: h for key in SOURCE_REF_FIELDS}
    pins.update(sourceProfileHash={"const": source.PROFILE_HASH}, captureProfileHash={"const": capture.PROFILE_HASH})
    d = {"publication": publication, "sourceRef": closed(pins), "governance": closed({"actionId": h,
        "action": abi(F.ACTION), "execution": ref("publication")})}
    d["sourceState"] = closed({key: a if key in ("core", "conservationFloor") else h if key == "blockHash" else
        {"enum": ["local_evm_fixture", "public_chain"]} if key == "environment" else abi("uint64" if key == "timestamp" else "uint256")
        for key in STATE_FIELDS})
    d["admission"] = closed({"publication": ref("publication"), "governance": ref("governance")})
    d["binding"] = closed({"ledger": a, "runtimeHash": h, **d["admission"]["properties"]})
    d["sourceMember"] = closed({**fields(SOURCE_FIELDS, F.SOURCE), "sourceId": abi("uint64"),
        "previousHead": h, "head": h, "source": abi(F.SOURCE), "admission": ref("admission")})
    d["catalogue"] = closed({"count": abi("uint64"), "head": h, "emptyHead": h,
        "sources": array(ref("sourceMember"), source.MAX_SOURCES)})
    for name, names, kinds, tier_index in (("firstSale", FIRST_FIELDS, F.FIRST, 2), ("release", RELEASE_FIELDS, F.RELEASE, 3)):
        properties = fields(names, kinds[:len(names)])
        properties[names[tier_index]] = {"enum": list(F.TIERS.values())}
        d[name] = closed({**properties, "receipt": abi(kinds), "publication": ref("publication")})
    d["originalSale"] = closed({"bindings": abi(source.BINDINGS), "receipt": abi(source.SALE), "receiptHash": h,
        "publication": ref("publication"), "event": closed({"topics": array(h, 4, 4), "data": abi((source.SALE, "uint16"))}),
        "managerState": closed({"core": a, "authorizationUsed": {"const": True}, "operationRootUsed": {"const": True}}),
        "tokenIdentity": closed({"exists": {"const": True}, "collectionId": abi("uint256"), "collectionSerial": abi("uint256"),
            "burned": {"type": "boolean"}, "lifecycle": {"enum": ["2", "3"]}}), "universalGetterEmpty": {"const": True}})
    d["directSale"] = closed({**fields(DIRECT_FIELDS, source.DIRECT[:6]), "productKind": {"enum": list(source.PRODUCTS)},
        "product": {"enum": list(source.PRODUCTS.values())}, "collectionId": abi("uint256"), "tokenId": abi("uint256"),
        "effectiveTier": {"enum": list(F.TIERS.values())}, "firstSaleReceiptHash": h, "releaseReceiptHash": h,
        "recordedAt": abi("uint64"), "receipt": abi(source.DIRECT), "publication": ref("publication"), "originalSale": ref("originalSale")})
    d["floor"] = closed({"status": {"enum": ["present", "none_recorded"]}, "firstSale": nullable(ref("firstSale")),
        "releases": array(ref("release"), source.MAX_RECEIPTS), "directSales": array(ref("directSale"), source.MAX_RECEIPTS)})
    d["ledgerEvent"] = {"oneOf": [closed({"kind": {"const": name}, "receipt": abi(spec[0]), "publication": ref("publication")})
        for name, spec in SPECS.items()]}
    d["discovery"] = closed({"ledgerReceiptEventCount": abi("uint64"), "targetReceiptEventCount": abi("uint64"),
        "ledgerReceiptEvents": array(ref("ledgerEvent"), source.MAX_RECEIPTS)})
    d["fragment"] = closed({"schema": {"const": NAME}, "version": {"const": 1}, "sourceRef": ref("sourceRef"),
        "sourceState": ref("sourceState"), "binding": ref("binding"), "catalogue": ref("catalogue"), "floor": ref("floor"),
        "discovery": ref("discovery"), "qualification": {"const": QUALIFICATION}})
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **ref("fragment"), "$defs": definitions(), "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def pos(row): return tuple(uint(row[k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
def tx(row): return tuple(row[k] for k in ("blockHash", "blockNumber", "transactionHash", "transactionIndex"))


class Observations:
    def __init__(self, state):
        self.state = state; n, h = state["blockNumber"], state["blockHash"]
        self.numbers, self.hashes, self.times = {n: h}, {h: n}, {uint(n): uint(state["timestamp"])}
        self.transactions, self.txslots, self.logs, self.code, self.actions, self.tokens, self.serials, self.adapters = {}, {}, {}, {}, {}, {}, {}, {}

    def runtime(self, address, digest):
        require(address != ZERO_ADDRESS and digest != ZERO and self.code.setdefault(address, digest) == digest,
            "DIRECT supplied runtime commitments differ")

    def event(self, row, identity, timestamp=None):
        n, index, log = pos(row); h, transaction = row["blockHash"], row["transactionHash"]
        require(n <= uint(self.state["blockNumber"]) and h != ZERO and transaction != ZERO, "DIRECT publication source bounds")
        require(self.numbers.setdefault(str(n), h) == h and self.hashes.setdefault(h, str(n)) == str(n), "DIRECT block mapping differs")
        require(self.transactions.setdefault(transaction, (n, h, index)) == (n, h, index)
            and self.txslots.setdefault((n, index), transaction) == transaction, "DIRECT transaction placement differs")
        require(self.logs.setdefault((n, log), (index, transaction, identity)) == (index, transaction, identity), "DIRECT event log collision")
        if timestamp is not None:
            require(0 < timestamp <= uint(self.state["timestamp"]) and self.times.setdefault(n, timestamp) == timestamp,
                "DIRECT observed block timestamp differs")

    def finish(self):
        previous = {}
        for (number, _), (index, _, _) in sorted(self.logs.items()):
            require(index >= previous.get(number, 0), "DIRECT transaction/log order differs"); previous[number] = index
        times = [stamp for _, stamp in sorted(self.times.items())]
        require(times == sorted(times), "DIRECT publication timestamps regress")
        for row in self.actions.values():
            stamp = self.times.get(uint(row["execution"]["blockNumber"]))
            if stamp is not None:
                action = native(F.ACTION, row["action"])
                require(action[9] <= stamp <= action[10], "DIRECT governance observed execution window differs")


def _governance(row, event, obs, stamp=None):
    action = native(F.ACTION, row["action"])
    require(len(encode((F.ACTION,), (action,))) <= source.MAX_ABI and row["actionId"] != ZERO
        and action[:2] == (3, 1) and action[11] != ZERO_ADDRESS and action[12] != ZERO_ADDRESS
        and action[9] <= action[10] and action[9] <= uint(obs.state["timestamp"]), "DIRECT governance original action differs")
    if stamp is not None: require(action[9] <= stamp <= action[10], "DIRECT governance execution window differs")
    require(tx(event) == tx(row["execution"]) and pos(event) < pos(row["execution"]), "DIRECT governance transaction/order differs")
    require(obs.actions.setdefault(row["actionId"], row) == row, "DIRECT repeated action observation differs")
    obs.event(row["execution"], ("action", row["actionId"], dumps(row["action"])), stamp)


def _catalogue(value, obs):
    state, binding, catalog = (value[k] for k in ("sourceState", "binding", "catalogue"))
    require(binding["ledger"] == state["conservationFloor"], "DIRECT ledger binding differs")
    obs.runtime(binding["ledger"], binding["runtimeHash"])
    obs.event(binding["publication"], ("binding", dumps(binding)))
    _governance(binding["governance"], binding["publication"], obs)
    previous, position = F.empty_head(state), pos(binding["publication"])
    require(catalog["emptyHead"] == previous and uint(catalog["count"], 64) == len(catalog["sources"]), "DIRECT source count/empty head differs")
    pair = None
    for index, member in enumerate(catalog["sources"], 1):
        row = native(F.SOURCE, member["source"])
        require(all(row[k] != ZERO for k in (1, 3, 4, 7)) and row[0] != ZERO_ADDRESS and row[2] != ZERO_ADDRESS
            and row[5] == index - 1 and uint(member["sourceId"], 64) == index and 0 < row[6] <= uint(state["timestamp"]),
            "DIRECT source member identity differs")
        require([member[key] for key in SOURCE_FIELDS] == json_values(row), "DIRECT source named fields differ")
        require(pair != (row[0], row[2]), "DIRECT duplicate adjacent source"); pair = (row[0], row[2])
        digest = F.next_head(previous, index, row)
        require(member["previousHead"] == previous and member["head"] == digest, "DIRECT source head differs")
        admission = member["admission"]; publication = admission["publication"]
        require(pos(publication) > position and admission["governance"]["actionId"] == row[7], "DIRECT source admission order/action differs")
        obs.event(publication, ("admission", str(index), dumps(member["source"])), row[6])
        _governance(admission["governance"], publication, obs, row[6])
        previous, position = digest, pos(publication)
    require(catalog["head"] == previous, "DIRECT final source head differs")


def _source_at(row, publication, catalog, *, waived=False):
    prior = [member for member in catalog["sources"] if pos(member["admission"]["publication"]) < pos(publication)]
    expected_head = prior[-1]["head"] if prior else catalog["emptyHead"]
    require(row[0] == (0 if waived else len(prior)) and (waived or prior) and row[1] == expected_head,
        "DIRECT historical source selection differs")


def _named(row, names, receipt, tier_index):
    expected = json_values(receipt[:len(names)]); expected[tier_index] = F.TIERS.get(receipt[tier_index])
    require([row[name] for name in names] == expected, "DIRECT named native receipt fields differ")


def _first_release(value, obs):
    state, catalog, floor = value["sourceState"], value["catalogue"], value["floor"]
    first = floor["firstSale"]
    if first is None:
        require(floor == {"status": "none_recorded", "firstSale": None, "releases": [], "directSales": []}, "DIRECT none-recorded fields differ")
        return
    require(floor["status"] == "present" and floor["directSales"], "DIRECT present floor has no paid originals")
    row = native(F.FIRST, first["receipt"]); facts = row[8]
    _named(first, FIRST_FIELDS, row, 2)
    require(row[2] in F.TIERS and row[3] != ZERO_ADDRESS and row[4] != ZERO, "DIRECT first sale identity differs")
    waived = row[2] == F.WAIVED
    _source_at(row[6:8], first["publication"], catalog, waived=waived)
    if waived: require(facts == (ZERO,) * 7 + (False,), "DIRECT waived collection facts differ")
    elif facts[7]: require(facts[:5] == (ZERO,) * 5 and facts[5] != ZERO and facts[6] == ZERO, "DIRECT platform collection facts differ")
    else: require(all(facts[k] != ZERO for k in (0, 1, 4, 5, 6)) and (facts[2] == ZERO) != (facts[3] == ZERO), "DIRECT collection facts differ")
    obs.event(first["publication"], ("first_sale", dumps(first["receipt"])), row[5])
    for release in floor["releases"]:
        r = native(F.RELEASE, release["receipt"]); context, facts = r[9:]
        _named(release, RELEASE_FIELDS, r, 3)
        require(r[3] in F.TIERS and r[3] != F.WAIVED and r[4] != ZERO_ADDRESS and r[5] != ZERO
            and all(context[k] != ZERO for k in (0, 1, 2, 4)) and context[5] == (context[3] != ZERO)
            and F.release_key(state, r[2], context) == r[1] and facts[0] == context[4] and facts[1] != ZERO
            and (r[3] != F.FULL or not context[5] or facts[2] != ZERO) and (context[5] or facts[2] == ZERO), "DIRECT release facts/key differ")
        _source_at(r[7:9], release["publication"], catalog)
        obs.event(release["publication"], ("release", dumps(release["receipt"])), r[6])


def _direct(row, obs):
    r = native(source.DIRECT, row["receipt"]); b, sale = r[6:8]; original = row["originalSale"]; state = obs.state
    require([row[k] for k in DIRECT_FIELDS] == json_values(r[:6]) and r[6] == native(source.BINDINGS, original["bindings"])
        and r[7] == native(source.SALE, original["receipt"]) and row["originalReceiptHash"] == original["receiptHash"], "DIRECT original named receipt differs")
    require(b[0] == state["core"] and b[4] == uint(state["chainId"]) and b[5] in source.PRODUCTS and r[4] != ZERO
        and r[8] in F.TIERS and r[9] != ZERO, "DIRECT adapter bindings/identity differ")
    require(row["productKind"] == b[5] and row["product"] == source.PRODUCTS[b[5]] and row["collectionId"] == str(sale[1])
        and row["tokenId"] == str(sale[2]) and row["effectiveTier"] == F.TIERS[r[8]]
        and (row["firstSaleReceiptHash"], row["releaseReceiptHash"], row["recordedAt"]) == (r[9], r[10], str(r[11])), "DIRECT original projection differs")
    require(all(sale[k] != ZERO for k in (0, 3, 4, 5, 6, 7)) and sale[1] > 0 and sale[2] > 0
        and all(sale[k] != ZERO_ADDRESS for k in (8, 11, 13)) and 0 < sale[9] <= r[11] and sale[12] > 0 and sale[15] > 0
        and (sale[14] != ZERO_ADDRESS if b[5] == source.ERC20 else sale[14] == ZERO_ADDRESS)
        and (b[5] == source.AUCTION or sale[9] == r[11]), "DIRECT original paid fields/time differ")
    require(r[3] == source.direct_key(b, r[1], r[4]) and r[5] == source.original_hash(b, r[1], r[4], sale), "DIRECT original key/hash differs")
    for address, digest in ((r[1], r[2]), (b[0], b[1]), (b[2], b[3])): obs.runtime(address, digest)
    require(obs.adapters.setdefault(r[1], b) == b, "DIRECT immutable adapter bindings differ")
    require(original["managerState"]["core"] == state["core"], "DIRECT manager Core differs")
    identity = original["tokenIdentity"]
    require(uint(identity["collectionId"]) == sale[1] and uint(identity["collectionSerial"]) > 0
        and identity["burned"] == (identity["lifecycle"] == "3"), "DIRECT completed token identity differs")
    require(obs.tokens.setdefault(sale[2], identity) == identity and obs.serials.setdefault((sale[1], uint(identity["collectionSerial"])), sale[2]) == sale[2],
        "DIRECT token/serial observation differs")
    require(original["event"]["topics"] == [source.ORIGINAL_EVENT, r[4], r[5], F._topic("uint256", sale[2])]
        and native((source.SALE, "uint16"), original["event"]["data"]) == (sale, 1)
        and tx(original["publication"]) == tx(row["publication"])
        and pos(original["publication"]) == (*pos(row["publication"])[:2], pos(row["publication"])[2] + 1), "DIRECT original paid event differs")
    obs.event(row["publication"], ("direct", dumps(row["receipt"])), r[11])
    obs.event(original["publication"], ("original_sale", r[1], r[4], dumps(original["event"])), r[11])


def _ledger(value, obs):
    discovery, floor, state = value["discovery"], value["floor"], value["sourceState"]
    events = discovery["ledgerReceiptEvents"]; seen, keys, targets, previous = set(), set(), [], None
    require(uint(discovery["ledgerReceiptEventCount"], 64) == len(events), "DIRECT ledger event count differs")
    for event in events:
        name = event["kind"]; kind, domain, cid_index, key_index = SPECS[name]; row = native(kind, event["receipt"])
        cid = row[7][1] if name == "direct" else row[cid_index]
        key = row[key_index]; position = pos(event["publication"])
        require(cid > 0 and row[0] != ZERO and F.receipt_hash(state, domain, kind, row) == row[0]
            and (name, key) not in seen and position > pos(value["binding"]["publication"])
            and (previous is None or previous < position), "DIRECT ledger native hash/key/order differs")
        if name in ("direct", "settlement"):
            require(key != ZERO and key not in keys, "DIRECT shared sale key collision"); keys.add(key)
        seen.add((name, key)); previous = position
        obs.event(event["publication"], (name, dumps(event["receipt"])))
        if cid == uint(state["collectionId"]):
            require(name != "settlement", "DIRECT target universal/mixed history unsupported")
            targets.append(event)
    expected = ([] if floor["firstSale"] is None else [{"kind": "first_sale", **{k: floor["firstSale"][k] for k in ("receipt", "publication")}}])
    expected += [{"kind": kind, "receipt": row["receipt"], "publication": row["publication"]}
        for kind, rows in (("release", floor["releases"]), ("direct", floor["directSales"])) for row in rows]
    expected.sort(key=lambda event: pos(event["publication"]))
    require(targets == expected and uint(discovery["targetReceiptEventCount"], 64) == len(targets), "DIRECT target denominator differs")
    for rows in (floor["releases"], floor["directSales"]):
        positions = [pos(row["publication"]) for row in rows]
        require(positions == sorted(set(positions)), "DIRECT target receipt order/duplicate differs")


def _links(floor):
    first, releases, sales = floor["firstSale"], floor["releases"], floor["directSales"]
    if first is None: return
    def created(evidence, sale):
        require(evidence["settlementKey"] == sale["directKey"] and evidence["recorder"] == sale["adapter"]
            and tx(evidence["publication"]) == tx(sale["publication"]) and pos(evidence["publication"]) < pos(sale["publication"])
            and evidence["recordedAt"] == sale["recordedAt"] and evidence["effectiveTier"] == sale["effectiveTier"], "DIRECT evidence creating sale differs")
    created(first, sales[0]); by_key = {s["directKey"]: s for s in sales}; by_hash = {r["receiptHash"]: r for r in releases}
    require(len(by_key) == len(sales) and len(by_hash) == len(releases), "DIRECT duplicate sale/release identity")
    for release in releases:
        require(release["settlementKey"] in by_key, "DIRECT release creator missing")
        sale = by_key[release["settlementKey"]]; created(release, sale)
        require(sale["releaseReceiptHash"] == release["receiptHash"] and pos(release["publication"])[2] + 1 == pos(sale["publication"])[2],
            "DIRECT release creating hash/order differs")
    first_release = next((r for r in releases if r["settlementKey"] == first["settlementKey"]), None)
    require(pos(first["publication"])[2] + 1 == pos((first_release or sales[0])["publication"])[2], "DIRECT first receipt order differs")
    for sale in sales:
        require(sale["firstSaleReceiptHash"] == first["receiptHash"] and sale["effectiveTier"] == first["effectiveTier"], "DIRECT first sale link/tier differs")
        if sale["effectiveTier"] == F.TIERS[F.WAIVED]: require(sale["releaseReceiptHash"] == ZERO and not releases, "DIRECT waived release differs")
        else:
            require(sale["releaseReceiptHash"] in by_hash, "DIRECT original release missing")
            release = by_hash[sale["releaseReceiptHash"]]
            require(release["effectiveTier"] == sale["effectiveTier"] and pos(release["publication"]) < pos(sale["publication"]), "DIRECT historical release order/tier differs")


def validate(raw):
    """Validate only the closed supplied fragment, never authenticate source references."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        Draft202012Validator(loads(SCHEMA_BYTES, maximum=MAX_BYTES)).validate(value)
        state = value["sourceState"]
        require(all(any(hex_bytes(value["sourceRef"][key], 32)) for key in SOURCE_REF_FIELDS), "DIRECT empty source reference")
        require(uint(state["chainId"]) > 0 and uint(state["collectionId"]) > 0 and state["blockHash"] != ZERO
            and state["core"] != ZERO_ADDRESS and state["conservationFloor"] != ZERO_ADDRESS
            and state["core"] != state["conservationFloor"], "DIRECT nonzero distinct source identity")
        uint(state["blockNumber"]); uint(state["timestamp"], 64)
        obs = Observations(state); _catalogue(value, obs); _ledger(value, obs); _first_release(value, obs)
        for row in value["floor"]["directSales"]: _direct(row, obs)
        _links(value["floor"]); obs.finish()
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied DIRECT floor fragment") from exc


def semanticProjection(snapshot, sourceRef):
    require(type(snapshot) is dict and snapshot.get("profile") == source.PROFILE and snapshot.get("profileHash") == source.PROFILE_HASH
        and snapshot.get("version") == "1" and snapshot.get("sourceReviewCommit") == source.SOURCE_REVISION
        and snapshot.get("coreSourceReviewCommit") == source.CORE_REVISION, "DIRECT projection source profile differs")
    require(type(sourceRef) is dict and set(sourceRef) == set(SOURCE_REF_FIELDS)
        and sourceRef["sourceProfileHash"] == source.PROFILE_HASH and sourceRef["captureProfileHash"] == capture.PROFILE_HASH
        and sourceRef["snapshotHash"] == keccak256(dumps(snapshot)) and sourceRef["anchorHash"] == snapshot["anchorHash"]
        and sourceRef["transcriptHash"] == snapshot["transcriptHash"], "DIRECT projection source commitments differ")
    value = {"schema": NAME, "version": 1, "sourceRef": copy.deepcopy(sourceRef),
        **{k: copy.deepcopy(snapshot[k]) for k in ("sourceState", "binding", "catalogue", "floor")},
        "discovery": {k: copy.deepcopy(snapshot["historyCoverage"][k]) for k in ("ledgerReceiptEventCount", "targetReceiptEventCount", "ledgerReceiptEvents")},
        "qualification": QUALIFICATION}
    return validate(dumps(value))


def documents(): return {NAME: SCHEMA_BYTES}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv); path = ROOT / "schemas/records" / (NAME + ".json")
    if args.check: require(path.is_file() and path.read_bytes() == SCHEMA_BYTES, "DIRECT generated definition differs")
    else: path.write_bytes(SCHEMA_BYTES)
    print("Standalone supplied DIRECT floor definition matches; no capture or full-packet proof.")


if __name__ == "__main__": main()
