"""Explicit synthetic typed controls and separate genuine recorded-source absence replay."""
import copy
from dataclasses import replace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads, schema_id, subject_id
from .exhibitions import (NAME, FAMILY, PROFILE_BYTES, PROFILE_HASH, SCHEMA_BYTES, MODE, CLAIMS,
    admit, fields, project_recorded_exhibitions, render, validator)
from .recorded_semantic import JCS_ID
from .review import _selector
from .source import RecordSelector, RetainedSourceRecord
from .test_recorded_account import ROOT, load_source
from .test_package_recorded import inputs, pins
from .package_recorded import build_recorded_package
from .package import write_package
from .package_v2 import verify_package
from .exhibition_package import build_exhibition_package, verify_exhibition_package
from .test_package import changed

H = lambda n: '0x' + format(n, '064x')
A = lambda n: '0x' + format(n, '040x')


def reference(n=5):
    return {'uri': 'https://example.invalid/reference/' + str(n),
        'hash': {'algorithm': '1', 'digest': H(n), 'canonicalizationId': schema_id('RAW_BYTES')}}


def date(text='2026-09-12T10:00:00Z'):
    return {'expression': 'Recorded opening ' + text, 'precision': 'exact', 'calendar': 'gregorian',
        'timezone': 'UTC', 'earliest': text, 'latest': text}


def exhibition():
    return {'version': '1', 'exhibitionId': 'urn:test:exhibition', 'status': 'completed',
        'subject': {'kind': 'collection', 'collectionId': '1', 'tokenId': '0'},
        'institution': {'entityId': 'urn:test:institution', 'identity': {'kind': 'address', 'value': A(9)},
            'name': {'value': 'Named institution, not the recorder', 'language': 'en'}, 'reference': reference(1)},
        'venue': {'entityId': 'urn:test:venue', 'name': {'value': 'Exact venue Δ', 'language': None}, 'location': reference(2)},
        'title': {'name': {'value': 'Original title\r\n<&> 🧭', 'language': 'en'}, 'reference': reference(3)},
        'opening': date(), 'closing': date('2026-09-15T18:00:00Z'),
        'displayParameters': [{'parameter': 'urn:test:display:brightness', 'value': '115792089237316195423570985008687907853269984665640564039457584007913129639935', 'unit': 'urn:test:display-unit', 'reference': reference(4)}],
        'artistIntent': {'recordHash': H(16), 'reference': reference(6)},
        'catalogues': [reference(7), reference(8)], 'wallLabels': []}


class Control:
    """Synthetic typed adapter control. The production recorded entrypoint refuses this class."""
    def __init__(self, value=None):
        self.anchor = {'chainId': '31337', 'core': A(2)}
        self.records, self.canonicalizations = {}, {}
        self.selector = self.add(exhibition() if value is None else value)

    def add(self, value):
        raw = dumps(value); digest = keccak256(raw); scope = value['subject']
        sid = subject_id(scope['kind'], '31337', A(2), scope['collectionId'], token_id=scope['tokenId'])
        selector = RecordSelector(A(1), digest, sid, schema_id(NAME), keccak256(SCHEMA_BYTES), FAMILY,
            A(10), 'INDEPENDENT_ATTESTOR', str(len(self.records)), H(21))
        record = RetainedSourceRecord(selector, raw, digest, SCHEMA_BYTES,
            dumps({'mode': 'synthetic_control', 'recorder': A(10), 'institutionIdentityProven': False}), 'public')
        self.records[digest] = record; self.canonicalizations[digest] = JCS_ID
        return _selector(record, '')

    def record(self, selector):
        record = self.records.get(selector.get('recordHash'))
        if record is None or _selector(record, selector.get('pointer')) != selector: raise MuseumError('test exact recorded selector')
        return record

    def changed_record(self, **kw):
        r = replace(self.record(self.selector), **kw)
        self.records[r.selector.record_hash] = r; self.selector = _selector(r, '')


class Exhibitions(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.model = validator(ROOT)

    def project(self, value=None):
        control = Control(value); rows = admit(control, [control.selector])
        return control, render(rows, self.model)

    def resources(self, files):
        return [loads(raw) for path, raw in files.items() if path.startswith('exhibitions/resources/')]

    def test_pinned_schema_and_profile_bytes_are_exact(self):
        self.assertEqual((ROOT / 'exhibition' / (NAME + '.json')).read_bytes(), SCHEMA_BYTES)
        self.assertEqual((ROOT / 'exhibition/profile.json').read_bytes(), PROFILE_BYTES)
        self.assertEqual(keccak256(PROFILE_BYTES), PROFILE_HASH)
        self.assertLess(len(dumps(exhibition())), 8192)

    def test_completed_exhibition_has_exact_entities_participant_venue_and_dates(self):
        with patch('socket.socket', side_effect=AssertionError('no network')):
            control, files = self.project()
        items = {r['type']: r for r in self.resources(files)}
        self.assertEqual(set(items), {'Activity', 'Group', 'Place'})
        event = items['Activity']; self.assertEqual(event['id'], 'urn:test:exhibition')
        self.assertEqual(event['identified_by'][0]['content'], exhibition()['title']['name']['value'])
        self.assertEqual(event['participant'], [{'id': 'urn:test:institution', 'type': 'Group'}])
        self.assertEqual(event['took_place_at'], [{'id': 'urn:test:venue', 'type': 'Place'}])
        self.assertNotIn('carried_out_by', event)
        self.assertEqual(event['timespan']['begin_of_the_begin'], exhibition()['opening']['earliest'])
        self.assertEqual(event['timespan']['end_of_the_end'], exhibition()['closing']['latest'])
        self.assertEqual(items['Group']['id'], 'urn:test:institution')
        self.assertNotEqual(items['Group']['id'], control.record(control.selector).selector.recorder)
        expanded = next(loads(raw)[0] for path,raw in files.items() if path.startswith('exhibitions/expanded/') and loads(raw)[0]['@id'] == 'urn:test:exhibition')
        self.assertEqual(expanded['@type'], ['http://www.cidoc-crm.org/cidoc-crm/E7_Activity'])
        self.assertFalse(any(loads(files['exhibitions/report.json'])['claims'].values()))

    def test_complete_original_values_references_names_languages_and_nulls_are_retained(self):
        control, files = self.project()
        sidecar = loads(files['exhibitions/sidecar.json'])[0]
        self.assertEqual(sidecar['exhibition'], exhibition())
        self.assertEqual(sidecar['source'], control.selector)
        coverage = loads(files['exhibitions/coverage.json'], maximum=1048576)
        self.assertEqual({r['sourcePath']:r['value'] for r in coverage}, dict(fields(exhibition())))
        self.assertIn('/wallLabels', {r['sourcePath'] for r in coverage})
        provenance = loads(files['exhibitions/provenance.json'], maximum=1048576)
        self.assertTrue(all(r['source'] == control.selector and r['sourcePaths'] and r['rule'] for r in provenance))
        self.assertEqual(loads(files['exhibitions/report.json'])['status'], 'complete_with_stream_extensions')

    def test_noncompleted_and_missing_names_never_invent_activity(self):
        for status in ('planned', 'cancelled', 'unknown'):
            value = exhibition(); value['status'] = status
            _, files = self.project(value)
            self.assertEqual(self.resources(files), [])
            self.assertEqual(loads(files['exhibitions/sidecar.json'])[0]['exhibition']['status'], status)
            self.assertEqual(loads(files['exhibitions/report.json'])['dispositions'][0]['disposition'], 'nonperformed_source')
        for field in ('title', 'institution', 'venue'):
            value = exhibition(); value[field]['name'] = None
            _, files = self.project(value)
            self.assertFalse(self.resources(files))
            report = loads(files['exhibitions/report.json'])
            self.assertEqual(report['status'], 'incomplete')
            self.assertEqual(report['dispositions'][0]['reasons'], [field + '_name_not_recorded'])

    def test_unknown_and_other_calendar_dates_keep_exact_source_without_fabricated_bounds(self):
        for calendar in ('gregorian', 'original-other-calendar'):
            value = exhibition()
            for field in ('opening','closing'):
                value[field] = {'expression': 'Unknown / original wording', 'precision': 'unknown', 'calendar': calendar,
                    'timezone': None, 'earliest': None, 'latest': None}
            _, files = self.project(value)
            span = next(r for r in self.resources(files) if r['type'] == 'Activity')['timespan']
            self.assertEqual(set(span), {'type','identified_by'})
            self.assertEqual(loads(files['exhibitions/sidecar.json'])[0]['exhibition'], value)
        value = exhibition(); value['opening'].update(precision='approximate', latest='2026-09-13T10:00:00Z')
        _,files=self.project(value)
        self.assertEqual(next(r for r in self.resources(files) if r['type']=='Activity')['timespan']['end_of_the_begin'], '2026-09-13T10:00:00Z')

    def test_dates_reject_contradiction_invalid_calendar_dates_and_exact_ranges(self):
        mutations = [lambda v:v['opening'].update(earliest='2026-02-30T00:00:00Z',latest='2026-02-30T00:00:00Z'),
            lambda v:v['opening'].update(latest='2026-09-13T10:00:00Z'),
            lambda v:v['opening'].update(precision='unknown'),
            lambda v:v['closing'].update(earliest='2025-01-01T00:00:00Z',latest='2025-01-01T00:00:00Z'),
            lambda v:v['opening'].update(earliest='2026-09-12T10:00:00Z\n'),
            lambda v:v['opening'].update(earliest=None)]
        for mutate in mutations:
            value=exhibition();mutate(value)
            with self.subTest(value=value['opening']), self.assertRaises(MuseumError): self.project(value)

    def test_original_family_class_schema_jcs_and_public_selector_are_required(self):
        changes = [dict(record_type=schema_id('INDEPENDENT_SEMANTIC_ASSERTION')),
            dict(authorization_class='OWNER_SIGNER'),dict(schema_id=H(90))]
        for change in changes:
            control=Control();control.changed_record(selector=replace(control.record(control.selector).selector, **change))
            with self.assertRaisesRegex(MuseumError,'family/schema/class/JCS'): admit(control,[control.selector])
        control=Control();control.canonicalizations[control.selector['recordHash']]=schema_id('RAW_BYTES')
        with self.assertRaises(MuseumError): admit(control,[control.selector])
        control=Control();control.changed_record(disclosure='restricted')
        with self.assertRaises(MuseumError): admit(control,[control.selector])
        control=Control(); bad={**control.selector,'pointer':'/title'}
        with self.assertRaises(MuseumError): admit(control,[bad])
        control=Control(); raw=SCHEMA_BYTES+b' '
        control.changed_record(schema=raw,selector=replace(control.record(control.selector).selector,schema_hash=keccak256(raw)))
        with self.assertRaises(MuseumError): admit(control,[control.selector])

    def test_identity_collision_and_account_equivalence_reject(self):
        value=exhibition();value['venue']['entityId']=value['institution']['entityId']
        with self.assertRaisesRegex(MuseumError,'identity'): self.project(value)
        value=exhibition();value['institution']['entityId']='urn:6529stream:account:eip155:31337:'+A(9)
        with self.assertRaisesRegex(MuseumError,'account equivalence'): self.project(value)
        control=Control();value=exhibition();value['exhibitionId']='urn:test:other-exhibition'
        value['institution']['name']['value']='Conflicting institution declaration'
        other=control.add(value)
        with self.assertRaisesRegex(MuseumError,'identity'): admit(control,[control.selector,other])

    def test_two_events_share_only_exact_same_kind_declarations_with_both_provenances(self):
        control=Control(); value=exhibition(); value['exhibitionId']='urn:test:second-exhibition'
        second=control.add(value)
        files=render(admit(control,[control.selector,second]),self.model)
        resources=self.resources(files)
        self.assertEqual(len(resources),4)
        self.assertEqual(sum(r['type']=='Activity' for r in resources),2)
        self.assertEqual(sum(r['type']=='Group' for r in resources),1)
        self.assertEqual(sum(r['type']=='Place' for r in resources),1)
        provenance=loads(files['exhibitions/provenance.json'],maximum=2097152)
        for shared in ('urn:test:institution','urn:test:venue'):
            rows=[r for r in provenance if r['entity']==shared]
            self.assertEqual({r['source']['recordHash'] for r in rows},
                {control.selector['recordHash'],second['recordHash']})
        for mutate in (lambda v:v['venue']['location'].update(uri='https://example.invalid/conflict'),
                lambda v:v['venue'].update(entityId='urn:test:institution'),
                lambda v:v.update(exhibitionId='urn:test:institution'),
                lambda v:v['title']['name'].update(value='Same event ID, different title')):
            control=Control(); value=exhibition()
            value['exhibitionId']='urn:test:second-exhibition'
            mutate(value)
            if value['title']['name']['value']=='Same event ID, different title': value['exhibitionId']='urn:test:exhibition'
            second=control.add(value)
            with self.assertRaisesRegex(MuseumError,'identity declaration|repeated event'):
                admit(control,[control.selector,second])

    def test_collection_token_scope_and_institution_identity_variants(self):
        for kind,value in (('address',A(9)),('did','did:example:source-institution'),('record',H(12))):
            original=exhibition();original['institution']['identity']={'kind':kind,'value':value}
            original['subject'].update(kind='token',tokenId='41')
            _,files=self.project(original)
            self.assertEqual(loads(files['exhibitions/sidecar.json'])[0]['exhibition']['subject']['tokenId'],'41')
        control=Control();control.changed_record(selector=replace(control.record(control.selector).selector,subject_id=H(12)))
        with self.assertRaisesRegex(MuseumError,'subject'): admit(control,[control.selector])

    def test_duplicate_bounds_references_and_loan_fields_fail_without_network(self):
        control=Control()
        with self.assertRaisesRegex(MuseumError,'duplicate'): admit(control,[control.selector]*2)
        with self.assertRaisesRegex(MuseumError,'bound'): admit(control,[control.selector]*65)
        for mutate in (lambda v:v['title']['reference']['hash'].update(digest=H(0)),
                lambda v:v['title']['reference']['hash'].update(algorithm='0'),
                lambda v:v['artistIntent'].update(recordHash=H(0)), lambda v:v.update(loan={'custody':'invented'})):
            value=exhibition();mutate(value)
            with self.assertRaises(MuseumError): self.project(value)

    def test_actual_recorded_source_requires_exact_state_plan_and_does_not_promote_controls(self):
        control=Control();plan=dumps({'version':'1','sourceStateHash':H(1),'records':[control.selector]})
        with self.assertRaisesRegex(MuseumError,'concrete recorded'):
            project_recorded_exhibitions(control,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,linked_art=self.model)
        source=load_source();record=next(iter(source.records.values()))
        plan=dumps({'version':'1','sourceStateHash':keccak256(source.state.identity),'records':[_selector(record,'')]})
        with self.assertRaisesRegex(MuseumError,'family/schema/class/JCS'):
            project_recorded_exhibitions(source,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,linked_art=self.model)
        plan=dumps({'version':'1','sourceStateHash':H(1),'records':[]})
        with self.assertRaisesRegex(MuseumError,'source-state'):
            project_recorded_exhibitions(source,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,linked_art=self.model)

    def test_existing_selected_graph_identity_cannot_be_redeclared_by_exhibition(self):
        from .exhibition_package import _check_identity_join
        _, projected = self.project()
        original = {'linked-art/entity-index.json': dumps([{'id':'urn:test:institution'}])}
        with self.assertRaisesRegex(MuseumError,'identity reuse'): _check_identity_join(projected, original)
        original = {'linked-art/entity-index.json': dumps([{'id':'urn:other:work'}])}
        _check_identity_join(projected, original)

    def test_recorded_package_retains_actual_source_and_replays_absence_offline(self):
        source=load_source();plan=dumps({'version':'1','sourceStateHash':keccak256(source.state.identity),'records':[]})
        original=build_recorded_package(inputs(),root=ROOT,disclosure='public',**pins())
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);write_package(original,root/'source')
            with patch('socket.socket',side_effect=AssertionError('network forbidden')):
                result=build_exhibition_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='public')
                self.assertEqual(dict(result.files)['source/manifest.json'],original.manifest)
                for name,raw in original.files:self.assertEqual(dict(result.files)['source/'+name],raw)
                report=loads(dict(result.files)['exhibitions/report.json'])
                self.assertEqual(report['reasonCode'],'no_selected_exhibition_records')
                write_package(result,root/'export')
                self.assertEqual(verify_package(root/'export',result.manifest_hash),result)
            altered=changed(result,'exhibitions/report.json',dumps({'claims':{'displayAuthorized':True}}))
            write_package(altered,root/'changed')
            with self.assertRaisesRegex(MuseumError,'semantic reconstruction'):
                verify_exhibition_package(root/'changed',altered.manifest_hash)
            with self.assertRaisesRegex(MuseumError,'public classification'):
                build_exhibition_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=PROFILE_HASH,disclosure='restricted')
            with self.assertRaisesRegex(MuseumError,'profile hash'):
                build_exhibition_package(root/'source',original.manifest_hash,plan,plan_hash=keccak256(plan),profile_hash=H(2),disclosure='public')


if __name__ == '__main__': unittest.main()
