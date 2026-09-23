"""Concrete five-slot evidence-link retention and replay controls."""
from contextlib import redirect_stderr, redirect_stdout
from functools import lru_cache
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import canonical_dossier_evidence_links_v2 as links
from . import canonical_dossier_script_links_v1 as script_links
from . import package_v2
from . import premis_retained
from . import script_dependency_rpc_v1 as script_rpc
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .canonical_dossier_script_links_fixture_v1 import complete_joined_case
from .object_dossier import _ref
from .test_collection_script_package_v1 import build as build_script
from .test_collection_script_source_v1 import CollectionScriptFixture
from .test_premis_retained import Fixture as PremisFixture


class EmptyPropertiesFixture(PremisFixture):
    """Same complete native catalogue with explicit empty property arrays."""

    def _object(self, *args, **kwargs):
        value = super()._object(*args, **kwargs)
        value['significantProperties'] = []
        return value


def _retained(fixture, *, include_files=True):
    artifacts = fixture.artifacts()
    files = artifacts['files'] if include_files else {}
    pins = {'anchor_hash': artifacts['anchorHash'],
        'transcript_hash': artifacts['transcriptHash'], 'source_hash': artifacts['sourceHash'],
        'plan_hash': artifacts['planHash'], 'profile_hash': artifacts['profileHash'],
        'provenance': 'synthetic_fixture', 'disclosure': 'public'}
    result = premis_retained.build(artifacts['anchor'], artifacts['transcript'],
        artifacts['plan'], files, **pins)
    digest = keccak256(result['manifest.json'])
    premis_retained.verify(result, digest)
    return result, digest


@lru_cache(maxsize=1)
def _properties():
    return _retained(PremisFixture())


@lru_cache(maxsize=1)
def _empty_properties():
    return _retained(EmptyPropertiesFixture())


@lru_cache(maxsize=1)
def _missing_local_files():
    return _retained(PremisFixture(), include_files=False)


@lru_cache(maxsize=1)
def _mismatching_properties():
    return _retained(PremisFixture(byte_size_override=999))


@lru_cache(maxsize=1)
def _unavailable_scripts():
    return build_script(CollectionScriptFixture(mode='chunked', registry=True,
        unavailable='registry'))[0]


def _repin(files):
    manifest = loads(files['manifest.json'], maximum=links.MAX_MANIFEST, canonical=True)
    manifest['files'] = [_ref(path, raw) for path, raw in sorted(files.items())
        if path != 'manifest.json']
    files['manifest.json'] = dumps(manifest)
    return keccak256(files['manifest.json'])


class CanonicalDossierEvidenceLinksV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.case = complete_joined_case()
        cls.properties, cls.properties_hash = _properties()
        cls.result = links.compose(dict(cls.case.dossier.files), cls.case.dossier.manifest_hash,
            script_files=dict(cls.case.scripts.files), script_hash=cls.case.scripts.manifest_hash,
            properties_files=cls.properties, properties_hash=cls.properties_hash,
            disclosure='public')
        cls.files = dict(cls.result.files)
        cls.ledger = loads(cls.files[links.LINKS_PATH], maximum=links.MAX_BYTES, canonical=True)
        cls.observations = loads(cls.files[links.OBSERVATIONS_PATH],
            maximum=links.MAX_BYTES, canonical=True)
        cls.observed_sources = {row['family']: row for row in cls.observations['sources']}
        cls.by_code = {row['requirementCode']: row for row in cls.ledger['requirementLinks']}

    def test_exact_children_and_five_supplemental_slots_preserve_nineteen_fortynine(self):
        self.assertEqual(set(self.by_code), set(links.CODES))
        self.assertEqual(self.ledger['packetRequirementCount'], '19')
        self.assertEqual(self.ledger['dossierRequirementCount'], '49')
        self.assertEqual(len(self.ledger['untouchedRequirementCodes']), 44)
        self.assertEqual(self.ledger['requirementPromotions'], [])
        for prefix, child in (('dossier/', dict(self.case.dossier.files)),
                ('scripts/', dict(self.case.scripts.files)), ('properties/', self.properties)):
            for path, raw in child.items(): self.assertEqual(self.files[prefix + path], raw)
        original = dict(self.case.dossier.files)
        for path in ('canonical/input/report.json', 'canonical/input/dossier/requirements.json'):
            self.assertEqual(self.files['dossier/' + path], original[path])
        self.assertTrue(all(not row['requirementAccepted'] and row['requirementPromotions'] == []
            for row in self.by_code.values()))

    def test_script_rows_are_v1_compatible_without_assessment_promotion(self):
        v1 = script_links.compose(*self.case.inputs(), disclosure='public')
        old = {row['requirementCode']: row for row in loads(dict(v1.files)[script_links.LINKS_PATH],
            maximum=script_links.MAX_BYTES)['requirementLinks']}
        for code in script_links.CODES:
            self.assertEqual(self.by_code[code]['occurrences'], old[code]['occurrences'])
            self.assertEqual(self.by_code[code]['status'], 'observed')
        self.assertEqual(self.observed_sources['scripts']['status'], 'joined')
        self.assertEqual(self.result.report['requirementPromotions'], [])

    def test_native_media_and_prospective_render_occurrences_reference_nested_originals(self):
        media = self.by_code['OD-MEDIA-MANIFEST']
        render = self.by_code['OD-RENDER-INVENTORY']
        self.assertEqual(media['status'], 'retained_occurrences')
        self.assertEqual(render['status'], 'retained_occurrences')
        media_kinds = {row['kind'] for row in media['occurrences']}
        render_kinds = {row['kind'] for row in render['occurrences']}
        self.assertTrue({'media_context', 'media_manifest', 'media_manifest_selection',
            'media_slot', 'media_original_record'} <= media_kinds)
        self.assertTrue({'prospective_source_context', 'prospective_reference',
            'prospective_capture'} <= render_kinds)
        captures = [row for row in render['occurrences'] if row['kind'] == 'prospective_capture']
        self.assertTrue(captures)
        self.assertTrue(all(row['status'] == 'retained_html_and_execution_declaration'
            and row['value']['receivedByteRoles'] == ['animationHTML', 'executionDeclaration']
            and row['value']['pngBytesRetained'] is False for row in captures))
        for family in (media, render):
            self.assertTrue(family['sourceReferences'])
            for reference in family['sourceReferences']:
                self.assertTrue(reference['path'].startswith('dossier/'))
                self.assertEqual(reference['keccak256'], keccak256(self.files[reference['path']]))
        self.assertFalse(self.result.report['claims']['authoritativeRenderInventory'])
        self.assertFalse(self.result.report['claims']['postMintRenderExecutionProven'])

    def test_retained_properties_preserve_objects_fields_and_local_matches(self):
        row = self.by_code['OD-SIGNIFICANT-PROPERTIES']
        self.assertEqual(row['status'], 'retained_occurrences')
        kinds = [item['kind'] for item in row['occurrences']]
        self.assertIn('retained_premis_object', kinds)
        self.assertIn('retained_premis_significant_property', kinds)
        objects = [item for item in row['occurrences'] if item['kind'] == 'retained_premis_object']
        properties = [item for item in row['occurrences']
            if item['kind'] == 'retained_premis_significant_property']
        self.assertEqual(len(objects), 2); self.assertEqual(len(properties), 2)
        self.assertTrue(all(item['value']['localComparison']['status'] == 'matches'
            for item in objects))
        self.assertEqual([item['value']['propertyIndex'] for item in properties], ['0', '0'])
        self.assertFalse(self.result.report['claims']['completeSignificantPropertiesInventory'])
        self.assertEqual(self.observed_sources['properties']['status'], 'unjoined')

    def test_mismatching_local_property_bytes_remain_declared_occurrences(self):
        child, digest = _mismatching_properties()
        result = links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            properties_files=child, properties_hash=digest, disclosure='public')
        row = loads(dict(result.files)[links.LINKS_PATH], maximum=links.MAX_BYTES)[
            'requirementLinks'][-1]
        objects = [item for item in row['occurrences'] if item['kind'] == 'retained_premis_object']
        properties = [item for item in row['occurrences']
            if item['kind'] == 'retained_premis_significant_property']
        self.assertTrue(objects); self.assertTrue(properties)
        self.assertTrue(all(item['value']['localComparison']['status'] == 'mismatch'
            for item in objects))
        self.assertTrue(all(item['status'] == 'mismatch' for item in properties))
        self.assertEqual(row['status'], 'retained_occurrences')

    def test_script_unavailability_keeps_original_indices_and_partial_occurrence(self):
        child = _unavailable_scripts()
        result = links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            script_files=dict(child.files), script_hash=child.manifest_hash, disclosure='public')
        files = dict(result.files)
        observed = loads(files[links.OBSERVATIONS_PATH], maximum=links.MAX_BYTES)
        self.assertTrue(observed['scriptUnavailable'])
        original = loads(files['scripts/source/transcript.json'], maximum=script_rpc.MAX_TRANSCRIPT)
        self.assertTrue(all('unavailable' in original['calls'][row['transcriptIndex']]
            for row in observed['scriptUnavailable']))
        ledger = loads(files[links.LINKS_PATH], maximum=links.MAX_BYTES)
        dependency = ledger['requirementLinks'][1]['occurrences'][0]
        self.assertEqual(dependency['wireStatus'], 'partial_unavailable')
        self.assertFalse(dependency['wireBytesComplete'])
        self.assertFalse(result.report['claims']['scriptExecuted'])

    def test_optional_sources_missing_and_empty_or_missing_local_properties_stay_distinct(self):
        absent = links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            disclosure='public')
        self.assertEqual(absent.report['optionalPackages'], {'scripts': False, 'properties': False})
        self.assertEqual(absent.report['familyStatus']['OD-SCRIPT-MANIFEST'], 'not_supplied')
        self.assertEqual(absent.report['familyStatus']['OD-DEPENDENCY-MANIFEST'], 'not_supplied')
        self.assertEqual(absent.report['familyStatus']['OD-SIGNIFICANT-PROPERTIES'], 'source_missing')
        observed = {row['family']: row for row in absent.report['sourceReconciliation']['sources']}
        self.assertEqual(observed['scripts']['status'], 'absent')
        self.assertEqual(observed['properties']['status'], 'absent')
        empty, digest = _empty_properties()
        empty_result = links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            properties_files=empty, properties_hash=digest, disclosure='public')
        empty_row = loads(dict(empty_result.files)[links.LINKS_PATH], maximum=links.MAX_BYTES)[
            'requirementLinks'][-1]
        self.assertEqual(empty_row['status'], 'retained_empty')
        self.assertTrue(any(item['kind'] == 'retained_premis_object'
            and item['value']['propertyCount'] == '0' for item in empty_row['occurrences']))
        self.assertFalse(any(item['kind'] == 'retained_premis_significant_property'
            for item in empty_row['occurrences']))
        missing, missing_hash = _missing_local_files()
        missing_result = links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
            properties_files=missing, properties_hash=missing_hash, disclosure='public')
        missing_row = loads(dict(missing_result.files)[links.LINKS_PATH], maximum=links.MAX_BYTES)[
            'requirementLinks'][-1]
        objects = [item for item in missing_row['occurrences'] if item['kind'] == 'retained_premis_object']
        self.assertTrue(objects)
        self.assertTrue(all(item['value']['localComparison']['status'] == 'missing' for item in objects))

    def test_optional_children_are_paired_before_any_dossier_read(self):
        wrong = '0x' + '11' * 32
        cases = ({'script_files': {}, 'script_hash': None},
            {'script_files': None, 'script_hash': wrong},
            {'properties_files': {}, 'properties_hash': None},
            {'properties_files': None, 'properties_hash': wrong})
        with patch.object(links.dossier, 'verify', side_effect=AssertionError('dossier read')):
            for options in cases:
                with self.subTest(options=options), self.assertRaisesRegex(MuseumError, 'supplied together'):
                    links.compose({}, wrong, disclosure='public', **options)
            with self.assertRaisesRegex(MuseumError, 'public disclosure'):
                links.compose({}, wrong, disclosure='restricted')

    def test_rehashed_derived_extra_and_wrong_child_pins_reject(self):
        for path in (links.LINKS_PATH, links.OBSERVATIONS_PATH, 'report.json'):
            with self.subTest(path=path):
                files = dict(self.files); value = loads(files[path], maximum=links.MAX_BYTES)
                value['inventedAcceptance'] = True; files[path] = dumps(value)
                with self.assertRaises(MuseumError): links.verify(files, _repin(files))
        files = dict(self.files); files['invented.bin'] = b'invented'
        with self.assertRaises(MuseumError): links.verify(files, _repin(files))
        for role, child in (('scripts', dict(self.case.scripts.files)),
                ('properties', self.properties)):
            options = ({'script_files': child, 'script_hash': keccak256(b'wrong child pin')}
                if role == 'scripts' else
                {'properties_files': child, 'properties_hash': keccak256(b'wrong child pin')})
            with self.subTest(role=role), self.assertRaisesRegex(MuseumError, 'external manifest'):
                links.compose(dict(self.case.dossier.files), self.case.dossier.manifest_hash,
                    disclosure='public', **options)

    def test_full_verify_generic_dispatch_cli_public_and_no_overwrite(self):
        self.assertEqual(links.verify(self.files, self.result.manifest_hash), self.result)
        with TemporaryDirectory(prefix='stream-evidence-links-v2-') as temporary, \
                patch('socket.socket', side_effect=AssertionError('network used')):
            root = Path(temporary); output = root/'out'; args = []
            for role, child, digest in (('dossier', dict(self.case.dossier.files), self.case.dossier.manifest_hash),
                    ('scripts', dict(self.case.scripts.files), self.case.scripts.manifest_hash),
                    ('properties', self.properties, self.properties_hash)):
                path = root/role; write_tree(child, path)
                args += ['--' + role, str(path), '--' + role + '-hash', digest]
            command = ['assemble', *args, '--disclosure', 'public', '--output', str(output)]
            with redirect_stdout(StringIO()):
                links.main(command)
                self.assertEqual(read_tree(output), self.files)
                links.main(['verify', str(output), '--manifest-hash', self.result.manifest_hash])
            self.assertEqual(package_v2.verify_package(output, self.result.manifest_hash), self.result)
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit): links.main(command)


if __name__ == '__main__': unittest.main()
