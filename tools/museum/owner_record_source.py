"""Original OwnerRecords wire and selected historical receipt capture/replay.

The externally pinned host authenticates the token owner at publication. This reader never
replaces that fact with today's ownerOf, nor proves legal title or RPC consensus.
"""
from types import MappingProxyType

from .canonical import dumps, hex_bytes, keccak256, loads, record_chain, schema_id, subject_id, uint
from .chain_abi import decode, encode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import HASH_REF, RAW_BYTES, ZERO, ZERO_ADDRESS, generic_hash, json_values, require

PROFILE = "STREAM_MUSEUM_OWNER_RECORD_SOURCE_V1"
OWNER_RECORD = ("bytes32", "bytes32", "bytes32", HASH_REF, "string", "bytes", "uint64")
RECEIPT = ("uint256", "address", "uint64", "uint64", "bytes32", "bool", "bytes32", "uint256", "uint64",
           "bytes32", "bytes32", "bytes32", "bytes32")
TYPE_HASH = "0x9c8c4f8b7ec1e8731277f53e36271ebf92fc96425f0c082143042400814c6b05"
FAMILIES = tuple(schema_id(n) for n in ("LOAN", "VALUATION", "CONDITION_REPORT"))


def domain(chain, host):
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
        (schema_id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
         schema_id("6529StreamOwnerRecords"), schema_id("1"), chain, host)))


def words(record, receipt):
    rt, sid, schema, content, uri, payload, effective = record
    return encode(("bytes32", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint16", "bytes32",
        "bytes32", "bytes32", "bytes32", "uint64", "uint256", "uint64"),
        (TYPE_HASH, receipt[1], receipt[0], sid, rt, schema, content[0], keccak256(content[1]), content[2],
         keccak256(uri.encode()), keccak256(payload), effective, receipt[7], receipt[8]))


def native_hash(chain, host, core, record, receipt):
    rt, sid, schema, content, uri, _, effective = record
    generic = (rt, sid, content, uri, schema, receipt[11], (1, hex_bytes(receipt[12]), RAW_BYTES), effective)
    return generic_hash(chain, host, core, receipt[0], receipt[1], generic)


def verify_wire(chain, host, core, timestamp, expected, token, record, receipt, bundle, *, families=FAMILIES):
    rt, sid, schema, content, uri, payload, effective = record
    require(receipt[0] == token and token > 0 and receipt[1] != ZERO_ADDRESS
        and 0 < receipt[2] <= timestamp and effective > 0 and rt in families
        and sid == subject_id("token", str(chain), core, "0", token_id=str(token))
        and schema != ZERO and receipt[9] != ZERO and receipt[10] != ZERO,
        "owner original receipt/family/subject differs")
    # This exporter needs actual embedded bytes and supported hash implementations;
    # opaque URI-only owner records remain outside this explicit source profile.
    require(0 < len(payload) <= 8192 and content[0] == 1 and len(content[1]) == 32
        and content[2] != ZERO and keccak256(payload) == "0x" + content[1].hex()
        and len(uri.encode()) <= 2048, "owner embedded keccak payload required")
    require(0 < len(bundle) <= 8192 and keccak256(bundle) == receipt[12], "owner signature bundle commitment")
    if not receipt[5]:
        require(receipt[6] == ZERO and receipt[7] == 0 and receipt[8] == 0 and receipt[11] == schema_id("DIRECT")
            and bundle == encode(("bytes32", "address", "bytes32"),
                (schema_id("DIRECT"), receipt[1], keccak256(payload))), "owner direct receipt/bundle differs")
    else:
        saved_domain, saved_words, signed = decode(("bytes32", ("bytes32",) * 14, "bytes"), bundle, maximum=8192)
        require(receipt[8] >= receipt[2] and len(signed) <= 4096
            and receipt[11] in (schema_id("EIP712"), schema_id("ERC1271")), "owner relayed signature/deadline")
        if receipt[11] == schema_id("EIP712"): require(len(signed) in (64,65), "owner EOA signature shape")
        body = words(record, receipt)
        require(saved_domain == domain(chain, host) and encode(("bytes32",) * 14, saved_words) == body
            and receipt[6] == keccak256(b"\x19\x01" + hex_bytes(saved_domain) + hex_bytes(keccak256(body))),
            "owner original signed tuple/domain differs")
    require(native_hash(chain, host, core, record, receipt) == expected, "owner original record hash differs")


class OwnerRecordSource:
    profile = PROFILE
    families = FAMILIES
    _read = IndependentSourceAdapter._read
    _block = IndependentSourceAdapter._block
    _chunk = IndependentSourceAdapter._chunk
    _document = IndependentSourceAdapter._document

    def _capture_extra(self, records):
        return None

    def _validate_predecessor(self, record, receipt):
        pass

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
            (provenance != "trusted_rpc" or type(transport) in (ReplayTransport, RpcTransport)), "owner source provenance")
        a = loads(anchor_bytes, maximum=524288, canonical=True)
        require(isinstance(a,dict) and set(a) == {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
            "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store", "codePins", "records"}
            and a["profile"] == self.profile and a["environment"] in ("local_evm_fixture", "public_chain"), "owner anchor shape")
        for f in ("chainId", "blockNumber", "timestamp"): uint(a[f], 64 if f == "timestamp" else 256)
        for f in ("blockHash", "stateRoot", "deploymentEvidenceHash"): require(hex_bytes(a[f],32) != bytes(32), "owner anchor commitment")
        for f in ("host", "core", "schemas", "store"): require(hex_bytes(a[f],20) != bytes(20), "owner dependency address")
        require(isinstance(a["codePins"],list) and 4 <= len(a["codePins"]) <= 64, "owner runtime pin bound")
        pins={}
        for pin in a["codePins"]:
            require(isinstance(pin,dict) and set(pin)=={"address","runtimeHash"}, "owner pin shape")
            hex_bytes(pin["address"],20)
            require(hex_bytes(pin["runtimeHash"],32) != bytes(32) and pin["address"] not in pins, "owner duplicate/empty pin")
            pins[pin["address"]]=pin["runtimeHash"]
        require(all(a[f] in pins for f in ("host","core","schemas","store")), "owner missing pin")
        require(isinstance(a["records"],list) and len(a["records"]) <= 128, "owner selected receipt bound")
        seen=set()
        for row in a["records"]:
            require(isinstance(row,dict) and set(row)=={"recordHash","tokenId"}
                and uint(row["tokenId"]) > 0 and hex_bytes(row["recordHash"],32) != bytes(32)
                and row["recordHash"] not in seen, "owner duplicate/invalid selection")
            seen.add(row["recordHash"])
        self.anchor_bytes,self.a,self.pins,self.provenance=anchor_bytes,a,pins,provenance
        self.reader=RecordingReader(transport,a["blockHash"])
        self.documents,self.document_stack,self.chunks={},set(),{}
        self.document_bytes,self._started,self._snapshot=0,False,None
        self.records=MappingProxyType({})

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(not self._started,"owner failed capture cannot resume");self._started=True
        a=self.a;self._block()
        require(quantity(self.reader.request("eth_chainId",[]))==uint(a["chainId"]),"owner chain differs")
        for address,digest in self.pins.items():
            code=hex_bytes(self.reader.code(address))
            require(0<len(code)<=24576 and keccak256(code)==digest,"owner runtime differs")
        for key,getter in (("core","core()"),("schemas","schemaRegistry()"),("store","chunkStore()")):
            _,(v,)=self._read(a["host"],getter,outputs=("address",));require(v==a[key],"owner host dependency differs")
        for key,getter in (("core","coreCodeHash()"),("schemas","schemaRegistryCodeHash()"),("store","chunkStoreCodeHash()")):
            _,(v,)=self._read(a["host"],getter,outputs=("bytes32",));require(v==self.pins[a[key]],"owner saved runtime differs")
        _,(store,)=self._read(a["schemas"],"chunkStore()",outputs=("address",));require(store==a["store"],"owner schema store differs")
        for getter,expected in (("streamModuleType()",schema_id("OWNER_RECORDS")),("streamModuleVersion()",schema_id("6529stream.owner-records.v1"))):
            _,(v,)=self._read(a["host"],getter,outputs=("bytes32",));require(v==expected,"owner module identity differs")
        records={}
        for chosen in a["records"]:
            h,token=chosen["recordHash"],uint(chosen["tokenId"])
            _,(r,t)=self._read(a["host"],"ownerRecord(bytes32)",("bytes32",),(h,),(OWNER_RECORD,RECEIPT))
            _,(pointer,bundle)=self._read(a["host"],"ownerRecordSignatureBundle(bytes32)",("bytes32",),(h,),("address","bytes"))
            verify_wire(uint(a["chainId"]),a["host"],a["core"],uint(a["timestamp"]),h,token,r,t,bundle,families=self.families)
            require(self._chunk(t[12],pointer)==bundle and self._chunk(keccak256(r[5]))==r[5],"owner stored payload differs")
            self._document(r[2],0,t[9]);self._document(r[3][2],1,t[10])
            if t[5]:
                _,(used,)=self._read(a["host"],"isOwnerRecordNonceUsed(address,uint256)",("address","uint256"),(t[1],t[7]),("bool",))
                require(used,"owner accepted nonce not consumed")
            _,(indexed,)=self._read(a["host"],"recordHashAt(uint256,bytes32,uint256)",("uint256","bytes32","uint256"),(token,r[0],t[3]),("bytes32",))
            require(indexed==h,"owner record index differs")
            previous=ZERO
            if t[3]:
                _,(prior,)=self._read(a["host"],"recordHashAt(uint256,bytes32,uint256)",("uint256","bytes32","uint256"),(token,r[0],t[3]-1),("bytes32",))
                _,(pr,pt)=self._read(a["host"],"ownerRecord(bytes32)",("bytes32",),(prior,),(OWNER_RECORD,RECEIPT))
                require(prior!=ZERO and pt[0]==token and pt[3]+1==t[3] and pr[0]==r[0]
                    and native_hash(uint(a["chainId"]),a["host"],a["core"],pr,pt)==prior,"owner immediate predecessor differs")
                self._validate_predecessor(pr, pt)
                previous=pt[4]
            require(record_chain(a["chainId"],a["host"],str(token),r[0],previous,h,str(t[3]))==t[4],"owner receipt chain differs")
            records[h]={"recordHash":h,"record":json_values(r),"receipt":json_values(t),"selection":chosen,
                "payloadHex":"0x"+r[5].hex(),"signatureBundleHex":"0x"+bundle.hex(),
                "authority":{"mode":"historical_owner_receipt","owner":t[1],"relayed":t[5],"recordedAt":str(t[2]),
                    "currentOwnerProven":False,"legalTitleProven":False,"custodyTransferProven":False}}
        extra = self._capture_extra(records)
        self._block()
        if type(self.reader.transport) is ReplayTransport:self.reader.transport.finish()
        self.records=MappingProxyType(records)
        snapshot={"profile":self.profile,"version":"1","mode":"recorded_state" if self.provenance=="trusted_rpc" else "synthetic_fixture",
            "anchorHash":keccak256(self.anchor_bytes),"transcriptHash":keccak256(self.reader.transcript()),"records":list(records.values()),
            "documents":[{"documentId":k,"payloadHex":"0x"+raw.hex()} for k,(_,raw,_) in self.documents.items()],
            "claims":{"selectedHistoricalReceiptsChecked":True,"fullLaneHistory":False,"hostSelectionAuthorityProven":False,
                "currentOwnerProven":False,"legalTitleProven":False,"cryptographicStateProof":False}}
        if extra is not None: snapshot["additionalEvidence"] = extra
        self._snapshot=dumps(snapshot)
        return self._snapshot
