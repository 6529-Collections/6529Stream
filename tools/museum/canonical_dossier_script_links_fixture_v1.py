"""Concrete script-link fixtures built from original offline source maps.

The joined fixture installs the stable-script observations into the same
``AllFamilyOwnerFixture`` map before either child is captured.  It therefore
shares the canonical collection, block header, Core, Metadata, Router and
runtime observations without relabelling an independently captured package.
"""
from copy import deepcopy
from dataclasses import dataclass
from functools import lru_cache

from . import acquisition_canonical_v10 as acquisition
from . import canonical_native_inputs_v1 as native_inputs
from . import canonical_object_dossier_v4 as dossier_v4
from . import canonical_semantic_export_v2 as semantic
from . import canonical_semantic_sources_v2 as semantic_sources
from . import collection_script_package_v1 as script_package
from . import collection_script_source_v1 as script_source
from . import collection_script_wire_v1 as wire
from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .object_dossier import Assembly
from .test_acquisition_preservation_current_v1 import input_envelope
from .test_acquisition_recovery_sustainability_v1 import RecoverySustainabilityFixture
from .test_acquisition_work_condition_v1 import title_case
from .test_canonical_semantic_sources_v2 import AllFamilyOwnerFixture


def _native(kind, value):
    if isinstance(kind, tuple):
        return tuple(_native(item, child) for item, child in zip(kind, value))
    if kind.startswith('uint'):
        return int(value)
    if kind == 'bytes':
        return hex_bytes(value)
    return value


def _call(base, target, signature, output, value, inputs=(), arguments=(), *, replace=False):
    """Install one exact call and refuse accidental fixture-map collisions."""
    key = (target, calldata(signature, inputs, arguments))
    result = '0x' + encode((output,), (_native(output, value),)).hex()
    if key in base.responses and not replace and base.responses[key] != result:
        raise ValueError('shared script fixture response collision: ' + signature)
    base.responses[key] = result


def _upgrade_pointer(base, role):
    """Give an existing current pointer its actual admission descriptor fields.

    Older fixture readers ignored the interface/registry fields and stored
    zeros.  The current script reader validates the complete pointer.  The
    target and runtime commitment remain exactly the pre-existing ones.
    """
    key = (base.core, calldata('getSatellitePointer(bytes32)', ('bytes32',), (schema_id(role),)))
    row = list(decode((script_source.POINTER,), hex_bytes(base.responses[key]))[0])
    row[4] = '0x12345678'
    row[5] = base.configuration[0][6]
    row[6] = 1
    if row[7] == ZERO: row[7] = keccak256((role + ' fixture manifest').encode())
    if row[8] == ZERO: row[8] = keccak256((role + ' fixture deployment').encode())
    if not row[9]: row[9] = int(base.a['timestamp']) - 1
    base.responses[key] = '0x' + encode((script_source.POINTER,), (tuple(row),)).hex()


class SharedStableScriptFixture:
    """A stable script observation installed into a canonical Title map."""

    def __init__(self, base):
        self.base = base
        self.core = base.core
        self.metadata = base.configuration[0][1]
        self.router = base.configuration[0][7]
        self.store = base.configuration[0][3]
        self.renderer = base.configuration[0][4]
        for role in ('COLLECTION_METADATA', 'METADATA_ROUTER'):
            _upgrade_pointer(base, role)

        serving_key = (self.router, calldata('collectionServingSource(uint256)', ('uint256',), (1,)))
        serving = decode((script_source.SERVING_SOURCE,), hex_bytes(base.responses[serving_key]))[0]
        payload = serving[4].encode('utf-8')
        context = {'chainId': base.a['chainId'], 'core': self.core,
            'collectionId': base.a['collectionId'], 'metadata': self.metadata,
            'metadataRuntimeHash': base.pins[self.metadata], 'router': self.router,
            'routerRuntimeHash': base.pins[self.router]}
        manifest = {'scriptHash': keccak256(payload),
            'rendererCompatibility': wire.STABLE_PROFILE, 'sourceType': '1',
            'libraryURI': '', 'scriptURI': '', 'sourcePointer': '',
            'mimeType': 'application/javascript', 'chunkCount': '1', 'executable': True}
        digest = wire._stable_hash(context, manifest, manifest['scriptHash'])
        self.value = {'selection': {'host': self.metadata,
                'codeHash': base.pins[self.metadata], 'manifestHash': digest},
            'manifest': manifest, 'stable': {'servingScriptBytes': '0x' + payload.hex(),
                'chunkOutcome': {'status': 'available', 'value': '0x' + payload.hex()}},
            'script': None, 'library': None}

        cid = int(base.a['collectionId'])
        selection = tuple(self.value['selection'][key] for key in script_source.NAMES['selection'])
        _call(base, self.router, 'selectedCollectionManifest(uint256,uint8)',
            script_source.SELECTION, selection, ('uint256', 'uint8'), (cid, 2))
        _call(base, self.router, 'collectionScriptBundle(uint256)',
            script_source.BUNDLE_SELECTION, (ZERO_ADDRESS, ZERO, ZERO, ZERO), ('uint256',), (cid,))
        facts = (wire.STABLE_PROFILE, True, schema_id('ONCHAIN'), self.renderer,
            base.pins[self.renderer], manifest['scriptHash'], len(payload),
            keccak256(serving[2].encode('utf-8')), keccak256(serving[3].encode('utf-8')),
            False, False, False, True, False, False, False)
        _call(base, self.router, 'collectionServingFacts(uint256)',
            script_source.SERVING_FACTS, facts, ('uint256',), (cid,))
        _call(base, self.metadata, 'recordedScriptManifest(bytes32)', script_source.MANIFEST,
            tuple(manifest[key] for key in script_source.NAMES['manifest']), ('bytes32',), (digest,))
        _call(base, self.metadata, 'recordedScriptBundle(bytes32)', 'bytes32', ZERO,
            ('bytes32',), (digest,))
        _call(base, self.metadata, 'scriptChunk(uint256,uint256)', 'bytes', '0x' + payload.hex(),
            ('uint256', 'uint256'), (cid, 0))

        bridge = {'kind': 'synthetic_fixture',
            'note': 'opaque admitted runtime bridge; not execution or runtime evidence'}
        self.runtime_bridge_raw = dumps(bridge)
        common = {key: base.a[key] for key in script_source.COMMON}
        self.anchor = {**common, 'profile': script_source.PROFILE,
            'coreRuntimeHash': base.pins[self.core],
            'codePins': [{'address': address, 'runtimeHash': digest}
                for address, digest in sorted({key: base.pins[key] for key in
                    (self.core, self.metadata, self.router, self.store, self.renderer)}.items())],
            'runtimeAdmission': {'sourceCommit': script_source.SOURCE_REVISION,
                'kind': 'synthetic_fixture', 'artifactHash': keccak256(self.runtime_bridge_raw)}}
        self.anchor_raw = dumps(self.anchor)

    def capture(self):
        reader = script_source.CollectionScriptSource(self.anchor_raw, self.base)
        return reader.snapshot(), reader.transcript()

    def package(self):
        snapshot, transcript = self.capture()
        result = script_package.assemble(self.anchor_raw, keccak256(self.anchor_raw),
            transcript, keccak256(transcript), self.runtime_bridge_raw,
            keccak256(self.runtime_bridge_raw), provenance='synthetic_fixture', disclosure='public')
        return result, snapshot, transcript


def _canonical_v4(base):
    """Build the unchanged canonical V4 path from the already extended map."""
    state = {key: ('41' if key == 'tokenId' else base.a[key])
        for key in acquisition.observations.STATE_KEYS}
    recovery = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
    prior, evidence, kwargs = title_case(base)
    _, preservation = input_envelope(state, source_header=deepcopy(base.blocks[state['blockHash']]))
    raw, digest = native_inputs.create(dumps(preservation), dumps(evidence), kwargs['metadata_files'],
        recovery.envelope(), condition_files=kwargs['condition_files'])
    v10 = acquisition.compose(prior.files, prior.manifest_hash, raw, digest, disclosure='public')
    v3 = semantic_sources.dossier.compose(v10.files, v10.manifest_hash, disclosure='public')
    plan = semantic.owner_definitions.prepare()
    definitions = {'plan_files': dict(plan.files), 'plan_hash': plan.manifest_hash}
    selection = semantic.prepare_selection(dict(v3.files), v3.manifest_hash,
        disclosure='public', **definitions)
    canonical = semantic.build(dict(v3.files), v3.manifest_hash, selection,
        keccak256(selection), disclosure='public', **definitions)
    return dossier_v4.compose(dict(canonical.files), canonical.manifest_hash, disclosure='public')


@dataclass(frozen=True)
class ScriptLinksCase:
    dossier: Assembly
    scripts: Assembly
    script_fixture: object

    def inputs(self):
        return (dict(self.dossier.files), self.dossier.manifest_hash,
            dict(self.scripts.files), self.scripts.manifest_hash)


@lru_cache(maxsize=1)
def complete_joined_case():
    """Genuine same-map collection-1 stable-script and canonical V4 children."""
    base = AllFamilyOwnerFixture()
    fixture = SharedStableScriptFixture(base)
    # Canonical construction appends original WORK transactions to this same
    # source header. Capture the script child only after the shared map has its
    # final header and receipt denominator.
    canonical = _canonical_v4(base)
    scripts, _, _ = fixture.package()
    return ScriptLinksCase(canonical, scripts, fixture)


def independent_case(mode='stable', **options):
    """The existing collection-7/block-42 source, retained as unjoined input."""
    from .test_collection_script_package_v1 import build
    from .test_collection_script_source_v1 import CollectionScriptFixture
    fixture = CollectionScriptFixture(mode=mode, **options)
    scripts, _, _ = build(fixture)
    # This canonical package has already replayed its own distinct map.
    from .canonical_object_dossier_fixture_v4 import canonical_case
    canonical = canonical_case()
    return ScriptLinksCase(dossier_v4.compose(dict(canonical.files), canonical.manifest_hash,
        disclosure='public'), scripts, fixture)
