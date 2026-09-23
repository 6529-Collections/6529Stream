"""Replay exact prior packet versions before canonical composition.

No packet branch is converted to an earlier authority or finality vocabulary.
The selected prior consumer replays its complete original package first.
"""
from dataclasses import dataclass

from . import acquisition_title_v5 as title
from . import acquisition_finality_v6 as collection
from . import acquisition_finality_v7 as scoped
from . import acquisition_policy_finality_v8 as policy
from . import acquisition_scoped_policy_finality_v9 as scoped_policy
from . import canonical_composition_observations_v1 as observations
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODULES = (title, collection, scoped, policy, scoped_policy)
BY_MODE = {module.MODE: module for module in MODULES}
PROFILE_BYTES = dumps({'name': 'STREAM_MUSEUM_CANONICAL_PACKET_INPUTS_V1', 'version': '1',
    'accepted': [{'mode': module.MODE, 'profileHash': module.PROFILE_HASH,
        'packetPath': module.PACKET_PATH} for module in MODULES],
    'retention': 'Every original path and byte is preserved in the containing input namespace.',
    'replay': 'Exact version dispatcher; original concrete consumer reconstructs its package. '
        'No native finality, authority or record is cast to an older profile.',
    'observations': observations.PROFILE_HASH,
    'qualification': 'Original source coverage and trust limits remain unchanged. '
        'Dispatch does not upgrade a supplied packet to complete canonical evidence.'})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class PacketInput:
    files: tuple
    packet: dict
    report: dict
    reference: dict
    observations: list
    profile_hash: str
    manifest_hash: str
    packet_path: str


def _source_prefix(path):
    return (path == 'source/anchor.json' or path.endswith('/source/anchor.json')
        or path.endswith('/sources/owner/anchor.json')
        or path.endswith('/sources/ownership/anchor.json'))


def _pins(anchor, transcript):
    result = {}

    def put(address, digest):
        require(any(hex_bytes(address, 20)) and any(hex_bytes(digest, 32)),
            'canonical packet input invalid runtime pin')
        require(result.setdefault(address, digest) == digest,
            'canonical packet input runtime pin differs from retained code')

    if 'coreRuntimeHash' in anchor: put(anchor['core'], anchor['coreRuntimeHash'])
    for row in anchor.get('codePins', []): put(row['address'], row['runtimeHash'])
    for row in transcript['calls']:
        if row['method'] == 'eth_getCode':
            put(row['params'][0], keccak256(hex_bytes(row['result'])))
    return result


def admit(files, expected_hash):
    """Return original packet data and computed cross-source observations."""
    try:
        supplied = dict(files)
        package._bounded(supplied)
        raw = supplied.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'canonical packet input external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and manifest.get('mode') in BY_MODE,
            'canonical packet input unsupported prior version')
        module = BY_MODE[manifest['mode']]
        verified = module.verify(supplied, expected_hash)
        originals = dict(verified.files)
        packet = loads(originals[module.PACKET_PATH], maximum=MAX_BYTES, canonical=True)
        observed = verified.report['sourceReconciliation']['sourceState']
        reference = {key: packet['sourceState']['tokenId'] if key == 'tokenId' else observed[key]
            for key in observations.STATE_KEYS}
        for key in ('chainId', 'core', 'collectionId', 'tokenId', 'blockHash', 'blockNumber'):
            require(reference[key] == packet['sourceState'][key],
                'canonical packet input original source identity differs')
        provenance = verified.report['sourceProvenance']
        sources = []
        for path, anchor_raw in sorted(originals.items()):
            if not _source_prefix(path): continue
            prefix = path.removesuffix('anchor.json')
            transcript_raw = originals[prefix + 'transcript.json']
            anchor = loads(anchor_raw, maximum=524288, canonical=True)
            transcript = loads(transcript_raw, maximum=64 * 1024 * 1024, canonical=True)
            sources.append({'kind': 'rpc', 'name': 'prior/' + prefix,
                'anchor': anchor, 'transcript': transcript,
                'runtimePins': _pins(anchor, transcript), 'provenance': provenance})
        require(sources, 'canonical packet input original sources missing')
        observations.reconcile(reference, sources)
        return PacketInput(tuple(sorted(originals.items())), packet, verified.report,
            reference, sources, module.PROFILE_HASH, expected_hash, module.PACKET_PATH)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical packet source input') from exc
