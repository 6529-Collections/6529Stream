"""Concrete offline source admission for the existing draft-binding APIs.

Externally pinned retained observations are replayed, not authenticated as an
independent source of chain truth. No input provenance or environment is changed.
"""
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory

from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, _paths, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .independent_wire import require
from .owner_record_source import OwnerRecordSource
from .package_recorded import INPUT_FILES, verify_recorded_package
from .recorded_projection import replay_source_bytes
from .recorded_semantic import RecordedSemanticSource

NAME = 'STREAM_MUSEUM_SEMANTIC_AUTHORING_SOURCES_V1'
MAX_PLAN = 524288
MAX_FILE = MAX_TRANSCRIPT
OWNER_FILES = frozenset(('anchor.json', 'transcript.json', 'snapshot.json'))
OWNER_KEYS = frozenset(('version', 'kind', 'provenance', 'anchorHash', 'transcriptHash', 'snapshotHash'))
RECORDED_KEYS = frozenset(('version', 'kind', 'manifestHash', 'sourceStateHash'))
CLAIMS = {'originalSourceBytesReplayed': True, 'externalPinsChecked': True,
    'sourceOriginAuthenticated': False, 'consensusProof': False, 'currentOwnerProven': False,
    'legalTitleProven': False, 'artistConfirmationProven': False, 'publicationAuthorityGranted': False,
    'fullOwnerCatalogueProven': False, 'sourceProvenancePromoted': False, 'networkFetch': False}
QUALIFICATION = ('Exact original source replay for offline draft binding. trusted_rpc is the caller-admitted provenance '
    'of retained observations, not proof of endpoint origin, consensus or current authority. Original local-EVM/public-chain '
    'environment and source mode are preserved. Owner input covers its explicitly selected historical receipts only, not '
    'a complete catalogue or current ownership. Recorded account input retains its original declared lanes and separate '
    'account authority. No token relationship, Artist confirmation, legal title or permission to publish is inferred.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'status': 'prospective_unregistered_local_adapter',
    'routes': {'owner_record_source': 'Exact original anchor/transcript/snapshot; concrete OwnerRecordSource with explicit trusted_rpc provenance, complete ordered replay and byte-identical recorded_state snapshot.',
        'recorded_account_package': 'Complete original package_recorded V2 package including manifest and retained dependencies; verify_recorded_package then reconstruct exact RecordedSemanticSource from retained inputs and pins.'},
    'bindingPins': {'owner_record_source': 'snapshotHash', 'recorded_account_package': 'source.state.commitment'},
    'disclosure': 'Explicit public before input inspection or temporary writes; no redaction or restricted export.',
    'references': 'originals paths are relative to enclosing authoring package source/ directory.',
    'limits': {'planBytes': str(MAX_PLAN), 'fileBytes': str(MAX_FILE), 'files': str(MAX_FILES),
        'aggregateBytes': str(MAX_BYTES), 'manifestBytes': str(MAX_MANIFEST)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Evidence:
    source: OwnerRecordSource | RecordedSemanticSource
    source_hash: str
    report: dict


def _pin(raw, digest, maximum, label):
    require(type(raw) is bytes and 0 < len(raw) <= maximum and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'authoring source ' + label + ' pin/bound differs')


def _files(files):
    require(type(files) is dict and 0 < len(files) <= MAX_FILES
        and all(type(p) is str and type(raw) is bytes and len(raw) <= MAX_FILE for p, raw in files.items())
        and sum(map(len, files.values())) <= MAX_BYTES, 'authoring source file/aggregate bounds')
    _paths(files)
    return dict(files)


def _owner(files, plan):
    require(set(files) == OWNER_FILES, 'authoring source exact owner file set')
    require(plan['provenance'] == 'trusted_rpc', 'authoring source owner explicit trusted_rpc provenance required')
    for name, key, maximum in (('anchor.json', 'anchorHash', MAX_PLAN),
            ('transcript.json', 'transcriptHash', MAX_TRANSCRIPT), ('snapshot.json', 'snapshotHash', MAX_TRANSCRIPT)):
        _pin(files[name], plan[key], maximum, name)
    source = OwnerRecordSource(files['anchor.json'], ReplayTransport(files['transcript.json'], plan['transcriptHash']),
        provenance=plan['provenance'])
    raw = source.snapshot()
    require(raw == files['snapshot.json'] and source.reader.transcript() == files['transcript.json'],
        'authoring source original owner replay differs')
    snapshot = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
    require(snapshot['mode'] == 'recorded_state', 'authoring source synthetic owner mode cannot be promoted')
    return source, plan['snapshotHash'], source.a, snapshot['mode'], len(snapshot['records'])


def _recorded(files, plan):
    require('manifest.json' in files, 'authoring source recorded manifest missing')
    _pin(files['manifest.json'], plan['manifestHash'], MAX_MANIFEST, 'recorded manifest')
    require(any(hex_bytes(plan['sourceStateHash'], 32)), 'authoring source empty state commitment')
    # Only this bounded immutable snapshot is materialized. The frozen verifier
    # replays the source and reconstructs every retained package byte.
    with TemporaryDirectory(prefix='stream-authoring-source-') as temporary:
        root = Path(temporary) / 'package'
        write_tree(files, root)
        checked = verify_recorded_package(root, plan['manifestHash'])
        require(checked.manifest == files['manifest.json']
            and dict(checked.files) == {p: raw for p, raw in files.items() if p != 'manifest.json'},
            'authoring source original recorded package differs')
        manifest = loads(checked.manifest, maximum=MAX_MANIFEST, canonical=True)
        inputs = {name: files['inputs/' + name] for name in INPUT_FILES}
        source = replay_source_bytes(root / 'dependencies', inputs,
            **{name + '_hash': manifest['pins'][name] for name in ('source', 'publication', 'interpretation', 'profile')})
        require(type(source) is RecordedSemanticSource and source.state.mode == 'recorded_state'
            and source.state.commitment == plan['sourceStateHash'] == manifest['sourceStateHash'],
            'authoring source original recorded state differs')
        # Construction has retained the exact state, source bytes and profile
        # documents in memory; draft binding needs no later dependency reads.
        return source, source.state.commitment, dict(source.anchor), source.state.mode, len(source.state.records)


def admit(files, plan_raw, plan_hash, *, disclosure):
    """Admit concrete retained originals without changing the frozen source APIs."""
    require(disclosure == 'public', 'authoring source explicit public disclosure required before reads')
    try:
        _pin(plan_raw, plan_hash, MAX_PLAN, 'plan')
        plan = loads(plan_raw, maximum=MAX_PLAN, canonical=True)
        require(type(plan) is dict and plan.get('version') == '1', 'authoring source plan version/shape')
        kind = plan.get('kind')
        require(kind in ('owner_record_source', 'recorded_account_package')
            and set(plan) == (OWNER_KEYS if kind == 'owner_record_source' else RECORDED_KEYS),
            'authoring source closed plan kind/shape')
        originals = _files(files)
        source, digest, anchor, mode, count = (_owner(originals, plan) if kind == 'owner_record_source'
            else _recorded(originals, plan))
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'kind': kind, 'planHash': plan_hash,
            'sourceHash': digest, 'sourceMode': mode, 'sourceProvenance': 'trusted_rpc',
            'environment': anchor['environment'], 'anchor': deepcopy(anchor), 'recordCount': str(count),
            'originals': [package._ref('source/' + path, raw) for path, raw in sorted(originals.items())],
            'claims': dict(CLAIMS), 'qualification': QUALIFICATION}
        require(len(dumps(report)) <= MAX_BYTES, 'authoring source report bound')
        return Evidence(source, digest, report)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, UnicodeError, RecursionError, OSError) as exc:
        raise MuseumError('malformed semantic authoring source input') from exc
