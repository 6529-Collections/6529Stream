"""Fresh synthetic Title/VIEW originals sharing one source state and Core.

Construction precedes every native capture and commitment. The real V10, V3,
canonical export and V4 verifiers run unchanged; this is an offline test
fixture, not evidence of a deployment or authenticated chain observations.
"""
from copy import deepcopy
from functools import lru_cache
from unittest.mock import patch

from .canonical import dumps, keccak256, loads
from . import acquisition_canonical_v10 as packet
from . import canonical_native_inputs_v1 as inputs
from . import canonical_semantic_sources_v2 as sources
from . import canonical_semantic_export_v2 as canonical
from . import canonical_object_dossier_v4 as dossier
from .test_canonical_semantic_sources_v2 import AllFamilyOwnerFixture, TOKEN
from .test_preservation_resources import RightsFixture, A, H
from .test_acquisition_work_condition_v1 import title_case
from .test_acquisition_recovery_sustainability_v1 import RecoverySustainabilityFixture
from . import test_acquisition_preservation_current_v1 as preservation_fixture
from .native_media_view_fixture_v1 import CORE_RUNTIME, supplied_raw_for


class SharedTitleFixture(AllFamilyOwnerFixture):
    """Mint precedes VIEW blocks 6..41; final Title records use block 42."""

    def __init__(self):
        original_init = RightsFixture.__init__

        def shared_runtime(value, **options):
            original_init(value, **options)
            value.codes[A(2)] = CORE_RUNTIME
            value.pins[A(2)] = keccak256(CORE_RUNTIME)
            for row in value.a['codePins']:
                if row['address'] == A(2):
                    row['runtimeHash'] = value.pins[A(2)]
            value.add(A(1), 'coreCodeHash()', (), (), ('bytes32',), (value.pins[A(2)],))

        self._shared_timeline = False
        with patch.object(RightsFixture, '__init__', shared_runtime):
            super().__init__()

    def _timeline(self):
        if not self._shared_timeline:
            assert all(not receipt['logs'] for receipt in self.receipts.values()), \
                'Title events must follow timeline construction'
            self.blocks[H(205)]['number'] = hex(42)
            self.blocks[H(205)]['parentHash'] = H(100000000 + 41)
            self.receipts[H(405)]['blockNumber'] = hex(42)
            self.a['blockNumber'] = '42'
            self._shared_timeline = True

    def event(self, *args, **kwargs):
        self._timeline()
        return super().event(*args, **kwargs)

    def append(self, *args, **kwargs):
        self._timeline()
        return super().append(*args, **kwargs)


@lru_cache(maxsize=1)
def supplied():
    """Complete genuine V4 replay with original received PNG and native WORK."""
    base = SharedTitleFixture()
    state = {key: str(TOKEN) if key == 'tokenId' else base.a[key]
        for key in packet.observations.STATE_KEYS}
    recovery = RecoverySustainabilityFixture(source_state=state, base=base, mode='empty')
    prior, evidence, kwargs = title_case(base)
    retrieval_raw = supplied_raw_for(state, deepcopy(base.blocks[state['blockHash']]),
        core_runtime=CORE_RUNTIME, token_serial=3)
    class EmptyPreservationTransport(preservation_fixture.Transport):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            # The standalone fixtures both used address 900 for different
            # hosts. Allocate this empty host before its first native read.
            self.host = A(890000)

    with patch.object(preservation_fixture, 'Transport', EmptyPreservationTransport):
        _, preservation = preservation_fixture.input_envelope(state,
            source_header=deepcopy(base.blocks[state['blockHash']]),
            retrieval_envelope=loads(retrieval_raw, maximum=dossier.MAX_BYTES, canonical=True))
    native, native_hash = inputs.create(dumps(preservation), dumps(evidence),
        kwargs['metadata_files'], recovery.envelope(), condition_files=kwargs['condition_files'])
    v10 = packet.compose(prior.files, prior.manifest_hash, native, native_hash, disclosure='public')
    v3 = sources.dossier.compose(v10.files, v10.manifest_hash, disclosure='public')
    plan = canonical.owner_definitions.prepare()
    options = {'plan_files': dict(plan.files), 'plan_hash': plan.manifest_hash}
    selection = canonical.prepare_selection(dict(v3.files), v3.manifest_hash,
        disclosure='public', **options)
    export = canonical.build(dict(v3.files), v3.manifest_hash, selection,
        keccak256(selection), disclosure='public', **options)
    original = dossier.compose(dict(export.files), export.manifest_hash, disclosure='public')
    from .test_native_work_lido_v1 import context_for
    inventory = loads(dict(original.files)['canonical/inputs/source-inventory.json'],
        maximum=dossier.MAX_BYTES, canonical=True)
    rows = [row for row in inventory['rows'] if row['family'] == 'WORK' and row['semantic'] is not None]
    lido_plan = {'version': '1', 'kind': 'native_work_lido',
        'sourceManifestHash': original.manifest_hash,
        'selected': [{'occurrenceId': row['occurrenceId'], 'selector': deepcopy(row['selector']),
            'context': context_for(row['semantic'])} for row in rows]}
    return original, dumps(lido_plan)
