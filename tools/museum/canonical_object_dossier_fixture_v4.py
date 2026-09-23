"""Concrete offline V4 inputs with explicit independent capture states.

The canonical target is the original TitleV5-derived collection 1/token 41.
Production and General/transfer share one original collection 7 source map.
Their different canonical-target anchor remains unjoined: this fixture does
not relabel historical blocks, native subjects or provider provenance.
"""
from dataclasses import dataclass
from functools import lru_cache
from unittest.mock import patch

from . import canonical_semantic_export_v2 as canonical
from . import general_semantic_dossier_v1 as general
from . import general_semantic_fixture_v1 as general_fixture
from . import recorded_physical_production_v1 as production
from . import recorded_physical_production_fixture_v1 as production_fixture
from . import recorded_physical_transfer_v1 as transfer
from . import recorded_physical_transfer_fixture_v1 as transfer_fixture
from .canonical import dumps, keccak256
from .object_dossier import Assembly
from .test_canonical_semantic_sources_v2 import complete_case


@dataclass(frozen=True)
class DossierV4Case:
    canonical: Assembly
    production: Assembly
    general: Assembly
    transfer: Assembly

    def inputs(self, *, production_present=True, general_present=True,
               transfer_present=True):
        """Exact original file maps and external pins for the V4 composer."""
        result = {'disclosure': 'public'}
        for name, present in (('production', production_present),
                              ('general', general_present), ('transfer', transfer_present)):
            value = getattr(self, name)
            result[name + '_files'] = dict(value.files) if present else None
            result[name + '_hash'] = value.manifest_hash if present else None
        return dict(self.canonical.files), self.canonical.manifest_hash, result


@lru_cache(maxsize=1)
def canonical_case():
    original = complete_case()
    plan = canonical.owner_definitions.prepare()
    args = {'plan_files': dict(plan.files), 'plan_hash': plan.manifest_hash}
    selection = canonical.prepare_selection(dict(original.files), original.manifest_hash,
        disclosure='public', **args)
    return canonical.build(dict(original.files), original.manifest_hash, selection,
        keccak256(selection), disclosure='public', **args)


def supplements(*, shared_object_iri=True, transfer_status='completed',
                transfer_selection=None):
    """Build real production and transfer packages on one original response map.

    Only synthetic fixture factories are substituted. Concrete source readers,
    wire hashes, native receipt/getter construction and package verifiers run
    unchanged. All General definition/chunk additions finish before either
    production or transfer capture is made.
    """
    native_factory = production_fixture.Fixture
    transfer_case = None

    def construct_native(**kwargs):
        nonlocal transfer_case
        native = native_factory(**kwargs)

        class SharedGeneralFixture(general_fixture.OfflineGeneralSemanticFixture):
            def __init__(self, **options):
                with patch.object(general_fixture, 'NativeFixture', lambda: native):
                    super().__init__(**options)
                # The General constructor retains the original Artist map and
                # extends it. Use that final map for both concrete readers.
                native.responses = self.general_fixture.responses

        def physical_identity(value, body):
            if not shared_object_iri:
                return
            entity = value['entities'][0]
            entity['id'] = production_fixture.OBJECT_ID
            body['physicalObject'] = {'id': entity['id'], 'pointer': '/entities/0',
                'hash': keccak256(dumps(entity))}
            value['assertions'][0]['subject'] = entity['id']

        with patch.object(transfer_fixture, 'OfflineGeneralSemanticFixture', SharedGeneralFixture):
            transfer_case = transfer_fixture.build_case(status=transfer_status,
                selection_indices=transfer_selection, mutate=physical_identity)
        return native

    with patch.object(production_fixture, 'Fixture', construct_native):
        original_production = production_fixture.supplied()
    general_package = general.verify(transfer_case.source_files, transfer_case.source_hash)
    production_package = production.build(original_production['source_files'],
        original_production['source_hash'], disclosure='public')
    transfer_package = transfer.build(transfer_case.source_files,
        transfer_case.source_hash, disclosure='public')
    return production_package, general_package, transfer_package


@lru_cache(maxsize=1)
def complete_case_v4():
    """All complete packages; supplementary state remains explicitly independent."""
    p, g, t = supplements()
    return DossierV4Case(canonical_case(), p, g, t)


def supplied(**kwargs):
    """Uncached variant constructor for original status/selection controls."""
    p, g, t = supplements(**kwargs)
    return DossierV4Case(canonical_case(), p, g, t)
