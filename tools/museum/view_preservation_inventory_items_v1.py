"""Exact fd861 item constructors from supplied bytes; no retrieval or execution."""
import base64

from .canonical import hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .current_rights_source import DOCUMENT_FACTS
from .independent_wire import ZERO, require
from .native_finality_wire import _bytes, _closed, from_json

RAW = schema_id('RAW_BYTES')


def role_hash(role):
    return role if role.startswith('0x') else schema_id(role)


def empty(kind, role, source, record, index):
    return (kind,role_hash(role),source,record,index,0,ZERO,b'','',0,*([ZERO]*7))


def bytes_item(kind, role, source, record, index, raw):
    require(type(raw) is bytes and len(raw) <= 524288, 'VIEW inventory item byte bound')
    row=list(empty(9 if kind==0 and not raw else kind,role,source,record,index))
    row[5:10]=(1,RAW,hex_bytes(keccak256(raw)),'',len(raw))
    return tuple(row)


def absent(role, source, record, index):
    return empty(7,role,source,record,index)


def runtime(role, source, record, index, runtimes, pin=None):
    raw=_bytes(runtimes[source],131072,'VIEW inventory supplied runtime')
    require(raw and (pin is None or keccak256(raw)==pin), 'VIEW inventory runtime pin/bytes')
    return bytes_item(1,role,source,record,index,raw)


def document(identifier, expected_hash, schemas, documents):
    entry=documents[identifier]
    _closed(entry,('facts','chunks'),'VIEW inventory document evidence')
    facts=from_json(DOCUMENT_FACTS,entry['facts'])
    require(facts[0] and facts[2]==1 and facts[3]!=ZERO and facts[6]>0
        and 0<facts[7]<=64 and (expected_hash==ZERO or expected_hash==facts[3]),
        'VIEW inventory ACTIVE document facts')
    require(type(entry['chunks']) is list and len(entry['chunks'])==facts[7],
        'VIEW inventory complete document chunk denominator')
    chunks=[]
    for chunk in entry['chunks']:
        _closed(chunk,('hash','bytes'),'VIEW inventory document chunk')
        raw=_bytes(chunk['bytes'],8192,'VIEW inventory document chunk')
        require(raw and keccak256(raw)==chunk['hash'],'VIEW inventory document chunk bytes')
        chunks.append(raw)
    raw=b''.join(chunks)
    require(len(raw)==facts[6] and keccak256(raw)==facts[3],'VIEW inventory complete document bytes')
    row=list(bytes_item(3,'REGISTERED_INTERPRETATION_DOCUMENT',schemas,identifier,0,raw))
    row[12:14]=(identifier,facts[3]);row[16]=keccak256(encode((DOCUMENT_FACTS,),(facts,)))
    return tuple(row)


def media(source, record, uri):
    if uri=='':return absent('VIEW_OPTIONAL_IMAGE',source,record,0)
    require(type(uri) is str and len(uri)==66 and uri.startswith('ipfs://b')
        and all(ch in 'abcdefghijklmnopqrstuvwxyz234567' for ch in uri[8:]),
        'VIEW inventory unsupported media URI: canonical raw CIDv1 SHA256 required')
    raw=base64.b32decode(uri[8:].upper()+'======')
    require(len(raw)==36 and raw[:4]==b'\x01\x55\x12\x20' and any(raw[4:])
        and base64.b32encode(raw).decode().lower().rstrip('=')==uri[8:],
        'VIEW inventory media CID codec/digest/canonical padding')
    row=list(empty(4,'VIEW_CONTENT_ADDRESSED_IMAGE',source,record,0))
    row[5:9]=(2,RAW,raw[4:],uri)
    return tuple(row)
