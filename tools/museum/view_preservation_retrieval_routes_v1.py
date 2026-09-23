"""Exact native attributed routes and original Arweave transaction joins.

Archive admission/currentness belongs to the caller's concrete consumer. The
required manifest callback repeats that consumer for every manifest occurrence.
This module never fetches, normalizes a path, or interprets manifest contents.
"""
from hashlib import sha256

from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_locator_wire_v1 as locator
from . import view_preservation_retrieval_types_v1 as t
from .canonical import MuseumError, hex_bytes, keccak256
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import from_json


def uri(value):
    """Renderer UTF-8/safety rules followed by the exact retrieval URI codec."""
    require(type(value) is str, 'VIEW retrieval URI type')
    try:
        raw = value.encode('utf-8')
    except UnicodeError as exc:
        raise MuseumError('VIEW retrieval URI UTF-8') from exc
    require(0 < len(raw) <= t.MAX_URI and all(c > 32 and c != 127 for c in raw),
        'VIEW retrieval URI byte bound/control')
    if raw.startswith(b'https://'):
        require(len(raw) > 8 and raw[8] not in b'/?#', 'VIEW retrieval HTTPS host')
        return 1, ZERO
    require(raw.startswith(b'ar://') and len(raw) >= 48, 'VIEW retrieval URI scheme')
    require(all(c < 128 for c in raw[:48]), 'VIEW retrieval Arweave root encoding')
    kind, transaction = locator.locator(raw[:48].decode('ascii'))
    require(kind == 2, 'VIEW retrieval Arweave root')
    if len(raw) == 48:
        return 2, transaction
    require(raw[48:49] == b'/' and len(raw) > 49, 'VIEW retrieval Arweave path')
    return 3, transaction


def shape(observation):
    """Check only the native ordered-route portion of a typed Observation."""
    o = from_json(t.OBSERVATION, observation)
    previous = o[0][9]
    uri(previous)
    require(uri(o[4])[0] != 3 and len(encode((t.OBSERVATION, 'bytes'), (o, b''))) <= t.MAX_BYTES,
        'VIEW retrieval incomplete final route or payload bound')
    for step in o[3]:
        from_kind, _ = uri(step[1])
        to_kind, _ = uri(step[2])
        require(step[1] == previous and step[1] != step[2], 'VIEW retrieval ordered route')
        if step[0] == 1:
            require(from_kind == 1 and step[3] in (301, 302, 303, 307, 308),
                'VIEW retrieval redirect status/source')
        elif step[0] == 2:
            require(from_kind != 3 and step[3] == 0, 'VIEW retrieval attributed mirror')
        elif step[0] == 3:
            require(from_kind == 3 and to_kind != 1 and step[3] == 0
                and step[4] != ZERO and step[5] != ZERO and step[6],
                'VIEW retrieval attributed manifest step')
        else:
            raise MuseumError('VIEW retrieval unknown route kind')
        require(step[0] == 3 or (step[4] == step[5] == ZERO and not step[6]),
            'VIEW retrieval non-manifest fields')
        previous = step[2]
    require(previous == o[4], 'VIEW retrieval exact route terminus')
    return o


def _transaction(configuration, coverage, evidence, transaction, originals):
    c = from_json(t.CONFIGURATION, configuration)
    coverage = from_json(t.COVERAGE, coverage)
    raw = hex_bytes(evidence['receipts'][0])
    require(len(raw) <= 65536, 'VIEW retrieval transaction receipt bound')
    r, identifier, signature = decode((archive.RECEIPT, 'bytes', 'bytes'), raw, maximum=65536)
    require(encode((archive.RECEIPT, 'bytes', 'bytes'), (r, identifier, signature)) == raw
        and len(identifier) == 32 and identifier == hex_bytes(transaction, 32)
        and r[0] == coverage[1] and r[1] == coverage[7] and r[5] == coverage[13]
        and r[2] == keccak256(identifier)
        and archive._domain('6529STREAM_EXTERNAL_RECEIPT_V1',
            ('uint256', 'address', archive.RECEIPT), (c[8], c[6], r)) == coverage[9],
        'VIEW retrieval original transaction receipt correspondence')
    originals.pin(c[6], c[7])
    data = calldata('receipt(bytes32)', ('bytes32',), (coverage[9],))
    result = '0x' + raw.hex()
    require(originals.answers.setdefault((c[6], data), result) == result,
        'VIEW retrieval conflicting transaction getter')
    originals.calls.append({'target': c[6], 'calldata': data, 'result': result})


def validate(observation, configuration, primary_admission, primary_evidence,
             manifest_evidences, originals, *, admit_manifest):
    """Join every manifest and final Arweave URI to its own admitted receipt.

    ``admit_manifest(evidence, source)`` must check the original and current
    Archive evidence in the same runtime/read map and return ``(object, admission)``.
    ``primary_admission`` is the caller's already checked raw native admission.
    """
    try:
        o = shape(observation)
        primary = from_json(t.ADMISSION, primary_admission)
        require(primary[0][0] == 1 and primary[3] == o[2]
            and from_json(t.OBJECT, primary_evidence['object']) == o[1],
            'VIEW retrieval primary Archive observation')
        steps = [step for step in o[3] if step[0] == 3]
        require(type(manifest_evidences) is list and len(manifest_evidences) == len(steps)
            and callable(admit_manifest), 'VIEW retrieval manifest occurrence denominator')
        manifests = []
        for index, (step, evidence) in enumerate(zip(steps, manifest_evidences)):
            obj, admission = admit_manifest(evidence, o[0])
            obj, admission = from_json(t.OBJECT, obj), from_json(t.ADMISSION, admission)
            require(admission[0] == (1, step[5], step[4]) and obj[0] == o[1][0]
                and obj[3] == keccak256(step[6]) and obj[4] == '0x' + sha256(step[6]).hexdigest()
                and obj[6] == len(step[6]), 'VIEW retrieval exact manifest bytes/Archive identity')
            transaction = uri(step[1])[1]
            _transaction(configuration, admission[3], evidence['sourceEvidence'], transaction, originals)
            manifests.append({'occurrence': index, 'objectHash': step[4], 'coverageHash': step[5],
                'byteLength': len(step[6]), 'transactionId': transaction})
        final_kind, transaction = uri(o[4])
        if final_kind == 2:
            _transaction(configuration, o[2], primary_evidence, transaction, originals)
        return json_values({'steps': len(o[3]), 'manifestOccurrences': manifests,
            'requestedURI': o[0][9], 'resolvedURI': o[4], 'finalTransactionId': transaction,
            'networkRetrievalPerformed': False, 'manifestPathInterpretationProven': False,
            'qualification': 'Route observations are attributed declarations. Whole manifest bytes '
                'and original transaction receipts correspond; paths remain literal and uninterpreted.'})
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError) as exc:
        raise MuseumError('malformed VIEW retrieval route evidence') from exc
