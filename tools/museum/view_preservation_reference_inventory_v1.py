"""Exact original reference environment file inventories at native df6363e5.

This is supplied-data correspondence with existing permissionless preparation,
not a new scope inventory, Store read, archive proof, or ZIP-file inspection.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id, uint
from .chain_abi import Array, encode
from .independent_wire import require

SOURCE_REVISION = 'df6363e571dbff8fb61c192b2282733ccb3f1af8'
PACKAGE_FILE = ('string', 'uint64', 'bytes32')
MAX_BYTES = 524288
PART_ROWS = 64
# Even the shortest admissible nonempty path makes an array at least 1+112*n
# bytes. This bound excludes no inventory retainable by the native byte store.
MAX_ROWS = (MAX_BYTES - 1) // 112
FILES = Array(PACKAGE_FILE, MAX_ROWS)
INVENTORY_DOMAIN = schema_id('6529STREAM_REFERENCE_FILE_INVENTORY_V1')
PART_DOMAIN = schema_id('6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1')
CLAIMS = {'suppliedDataConsistencyChecked': True, 'nativeCanonicalFileBytesChecked': True,
    'nativePreparationExecutionProven': False, 'publicationAuthorityVerified': False,
    'storeCarrierBytesVerified': False, 'archiveCoverageVerified': False,
    'zipMembershipVerified': False, 'actualFileDigestsMeasured': False}


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), 'reference inventory '+label+' shape')


def _uint(value, bits):
    if type(value) is int:
        require(0 <= value < 1 << bits, 'reference inventory unsigned overflow')
        return value
    return uint(value, bits)


def _rows(rows, relative):
    require(type(relative) is bool, 'reference inventory relative flag')
    require(type(rows) in (list, tuple) and len(rows) <= MAX_ROWS, 'reference inventory row bound')
    result = []
    for row in rows:
        require(type(row) in (list, tuple) and len(row) == 3 and type(row[0]) is str,
            'reference inventory original PackageFile shape')
        size = _uint(row[1], 64)
        hex_bytes(row[2], 32)
        try:
            path = row[0].encode('utf-8')
        except UnicodeError as exc:
            raise MuseumError('reference inventory invalid UTF-8') from exc
        require(0 < len(path) <= (1024 if relative else 2048), 'reference inventory path byte bound')
        result.append((row[0], size, row[2]))
    return tuple(result)


def _identity(domain, rows, relative, chain, host):
    rows = _rows(rows, relative)
    chain = _uint(chain, 256)
    require(chain > 0 and any(hex_bytes(host, 20)), 'reference inventory chain/host domain')
    return keccak256(encode(('bytes32', 'uint256', 'address', 'bool', FILES),
        (domain, chain, host, relative, rows)))


def inventory_id(rows, relative, chain, host):
    """Hash the complete original typed rows; this alone does not validate order."""
    return _identity(INVENTORY_DOMAIN, rows, relative, chain, host)


def part_id(rows, relative, chain, host):
    require(type(rows) in (list, tuple) and 0 < len(rows) <= PART_ROWS,
        'reference inventory part row bound')
    return _identity(PART_DOMAIN, rows, relative, chain, host)


def files_bytes(rows, relative):
    """Native fixed-key JSON and the actual <=524288 retained-byte limit.

    Absolute/platform paths are only nonempty valid UTF-8 with a 2048-byte
    bound; the native writer does not require a drive prefix or normalization.
    Relative package paths use the original printable ASCII rules. Sizes may
    be zero; executable membership has separate requirements outside this API.
    """
    rows = _rows(rows, relative)
    values, previous = [], None
    for path, size, digest in rows:
        raw = path.encode('utf-8')
        require(any(hex_bytes(digest, 32)) and (previous is None or previous < raw),
            'reference inventory digest/global UTF-8 order')
        if relative:
            require(all(32 <= value <= 126 and value not in b'\\:<>"|?*' for value in raw)
                and all(segment and not segment.endswith(('.', ' ')) for segment in path.split('/')),
                'reference inventory relative path')
        previous = raw
        # StreamRecordJson.quote uses these same JSON escapes, lowercase hex
        # controls and unescaped valid UTF-8. Fixed keys have this exact order.
        values.append({'byteSize': str(size), 'path': path, 'sha256Digest': digest})
    raw = dumps(values)
    require(len(raw) <= MAX_BYTES, 'reference inventory retained byte bound')
    return raw


def _descriptor(value, key, expected_id, expected):
    _closed(value, (key, 'contentHash', 'byteLength', 'payload'), 'retained descriptor')
    require(value[key] == expected_id and value['contentHash'] == keccak256(expected)
        and uint(value['byteLength'], 32) == len(expected)
        and type(value['payload']) is str and len(value['payload']) <= 2 + 2*MAX_BYTES
        and hex_bytes(value['payload']) == expected, 'reference inventory original bytes/identity differ')


def validate(value, context, host):
    """Check whole inventory and optional exact fixed64 original parts.

    ``parts=None`` retains a whole-only preparation without asserting parts
    were published. An array requires every fixed64 part in its native order;
    each descriptor carries exact original bytes, identity, hash and length.
    ``context`` supplies chainId; host is the original preparation host address.
    """
    try:
        _closed(value, ('relative', 'rows', 'inventoryId', 'contentHash', 'byteLength', 'payload', 'parts'),
            'whole')
        rows = _rows(value['rows'], value['relative'])
        raw = files_bytes(rows, value['relative'])
        key = inventory_id(rows, value['relative'], context['chainId'], host)
        _descriptor({k: value[k] for k in ('inventoryId', 'contentHash', 'byteLength', 'payload')},
            'inventoryId', key, raw)
        parts, ids = value['parts'], []
        expected_count = (len(rows) + PART_ROWS - 1) // PART_ROWS
        require(parts is None or (type(parts) is list and len(parts) == expected_count),
            'reference inventory fixed64 part denominator')
        pieces = []
        for index, start in enumerate(range(0, len(rows), PART_ROWS)):
            chunk = rows[start:start+PART_ROWS]
            digest = part_id(chunk, value['relative'], context['chainId'], host)
            body = files_bytes(chunk, value['relative'])
            ids.append(digest)
            pieces.append(body[1:-1])
            if parts is not None: _descriptor(parts[index], 'partId', digest, body)
        require(b'['+b','.join(pieces)+b']' == raw, 'reference inventory full native assembly differs')
        return {'inventoryId': key, 'contentHash': keccak256(raw), 'byteLength': str(len(raw)),
            'relative': value['relative'], 'rows': [[path, str(size), digest] for path, size, digest in rows],
            'bytes': raw, 'derivedPartIds': ids, 'suppliedPartsChecked': parts is not None,
            'claims': dict(CLAIMS), 'qualification':
                'Exact supplied original PackageFile commitments and canonical inventory bytes only. '
                'Derived part IDs do not establish that parts were prepared. File contents, Store '
                'carriers, archive coverage, publication authority and ZIP membership are not proved.'}
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
        raise MuseumError('malformed reference inventory evidence') from exc
