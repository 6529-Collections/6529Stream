"""Concrete synthetic OwnerRecords dossier for an exhibition location join.

This fixture appends a native EXHIBITION before any capture.  It retains the
complete existing all-family catalogue, including unsupported originals.  A
location HashRef declares correspondence to supplied bytes; it does not prove
the venue, geography, institution, or declaration authority.
"""
from copy import deepcopy

from . import acquisition_canonical_v10 as packet
from . import canonical_native_inputs_v1 as inputs
from . import canonical_semantic_sources_v2 as sources
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .independent_wire import require
from .test_acquisition_preservation_current_v1 import input_envelope
from .test_acquisition_recovery_sustainability_v1 import RecoverySustainabilityFixture
from .test_acquisition_work_condition_v1 import title_case
from .test_canonical_semantic_sources_v2 import AllFamilyOwnerFixture, samples
from .title_v5_fixture import TOKEN


def build_owner_case(declaration_payload: bytes, *, venue_id: str,
                     status='completed', location_hash=None):
    """Return ``(canonical V3 Assembly, exact appended EXHIBITION identity)``.

    The declaration must already be exact RFC8785 JSON bytes. ``location_hash``
    deliberately permits a different bytes32 commitment for negative join
    controls; the OwnerRecords payload and all native hashes still agree.
    Native publication is at the source block (5), after the existing owner
    records.  A declaration authority fixture can publish before that position.
    Every capture and composition uses the real production verifier.
    """
    require(type(declaration_payload) is bytes, 'fixture declaration must be bytes')
    loads(declaration_payload, maximum=524288, canonical=True)
    require(type(venue_id) is str and bool(venue_id), 'fixture venue identity required')
    require(type(status) is str, 'fixture exhibition status must be a string')
    payload_hash = keccak256(declaration_payload)
    digest = payload_hash if location_hash is None else location_hash
    require(type(digest) is str and len(hex_bytes(digest)) == 32,
        'fixture location hash must be bytes32')

    base = AllFamilyOwnerFixture()
    value = deepcopy(samples()['EXHIBITION'])
    value.update(exhibitionId='urn:synthetic:exhibition-geography:' + payload_hash[2:],
        status=status, subject={'kind': 'token', 'collectionId': base.a['collectionId'],
            'tokenId': str(TOKEN)})
    value['venue']['entityId'] = venue_id
    value['venue']['location'] = {
        'uri': 'ipfs://synthetic-exhibition-geography/' + payload_hash[2:],
        'hash': {'algorithm': '1', 'digest': digest,
            'canonicalizationId': schema_id('RFC8785_JCS')},
    }
    record_hash = base.append_family('EXHIBITION', value)
    base._title_lane_state()

    state = {key: str(TOKEN) if key == 'tokenId' else base.a[key]
        for key in packet.observations.STATE_KEYS}
    recovery = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
    prior, evidence, kwargs = title_case(base)
    _, preservation = input_envelope(state,
        source_header=deepcopy(base.blocks[state['blockHash']]))
    native, native_hash = inputs.create(dumps(preservation), dumps(evidence),
        kwargs['metadata_files'], recovery.envelope(), condition_files=kwargs['condition_files'])
    v10 = packet.compose(prior.files, prior.manifest_hash, native, native_hash,
        disclosure='public')
    assembly = sources.dossier.compose(v10.files, v10.manifest_hash, disclosure='public')

    snapshot_path = sources.OWNER_PREFIX + 'sources/owner/snapshot.json'
    snapshot = loads(dict(assembly.files)[snapshot_path], maximum=sources.dossier.MAX_BYTES)
    index, original = next((index, row) for index, row in enumerate(snapshot['records'])
        if row['recordHash'] == record_hash)
    identity = {
        'chainId': state['chainId'], 'core': state['core'], 'host': base.title_host,
        'collectionId': state['collectionId'], 'tokenId': str(TOKEN),
        'subjectId': original['record'][1], 'recordHash': record_hash,
        'recordIndex': original['receipt'][3], 'recordChainHash': original['receipt'][4],
        'sourceState': deepcopy(state), 'sourceHeader': deepcopy(base.blocks[state['blockHash']]),
        'publication': deepcopy(original['publication']),
        'publicationLog': deepcopy(base.owner_events[record_hash]),
        'snapshotPath': snapshot_path, 'originalPointer': '/records/' + str(index),
        'original': deepcopy(original), 'payload': deepcopy(value),
        'declarationPayloadHash': payload_hash, 'locationHash': digest,
        'venueId': venue_id, 'provenance': 'synthetic_fixture',
    }
    return assembly, identity


def admit_owner_case(declaration_payload: bytes, *, venue_id: str,
                     status='completed', location_hash=None):
    """Build, replay SourceV2 admission, and return ``(checked, identity, inventory)``."""
    assembly, identity = build_owner_case(declaration_payload, venue_id=venue_id,
        status=status, location_hash=location_hash)
    checked, inventory = sources.admit(dict(assembly.files), assembly.manifest_hash)
    matches = [row for row in inventory['rows'] if row['selector']['kind'] == 'native_owner_family'
        and row['selector']['host'] == identity['host']
        and row['selector']['recordHash'] == identity['recordHash']]
    require(len(matches) == 1, 'fixture appended exhibition occurrence missing')
    identity['occurrenceId'] = matches[0]['occurrenceId']
    return checked, identity, inventory
