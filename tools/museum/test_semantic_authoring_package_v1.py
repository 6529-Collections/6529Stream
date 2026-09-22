"""Concrete source replay and immutable draft-history package regressions.

All authoring artifacts remain draft previews. Source helpers use the actual
OwnerRecordSource and recorded-account package consumers, without verifier mocks.
"""
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from functools import lru_cache
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from . import object_dossier as package
from . import package_v2
from . import semantic_authoring as draft
from . import semantic_authoring_package_v1 as authoring
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .test_semantic_authoring import fixture, later_fixture


def parsed(files, path):
    return loads(files[path], maximum=package.MAX_BYTES, canonical=True)


@lru_cache(maxsize=2)
def source_case(kind):
    from .test_semantic_authoring_sources_v1 import owner_case, recorded_case
    return owner_case() if kind == 'owner' else recorded_case()


def options(case):
    return {'source_files': case['files'], 'source_plan_raw': case['plan_raw'],
        'source_plan_hash': case['plan_hash']}


def bound_case(kind='owner'):
    case = source_case(kind)
    result = authoring.start(dumps(later_fixture(case['citation'])),
        selection=case['selection'], **options(case), disclosure='public')
    return case, result


def revision(previous_raw, **changes):
    value = loads(previous_raw, maximum=draft.MAX_DRAFT_BYTES, canonical=True)
    value.update(revision=str(int(value['revision']) + 1), previousRevisionHash=keccak256(previous_raw),
        revisedAt='2026-09-17T09:00:00Z')
    value['relationships'][0]['rationale'] += ' Later mapping clarification.'
    value.update(changes)
    return value


def repin(files):
    """Recommit the entire transport; derived semantic checks must still reject."""
    result = dict(files)
    manifest = parsed(result, 'manifest.json')
    manifest['files'] = [package._ref(path, raw)
        for path, raw in sorted(result.items()) if path != 'manifest.json']
    result['manifest.json'] = dumps(manifest)
    return result, keccak256(result['manifest.json'])


def cli(argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        authoring.main(argv)
    return loads(out.getvalue().strip().encode('utf-8'), maximum=package.MAX_BYTES), err.getvalue()


class SemanticAuthoringPackageTests(unittest.TestCase):
    def test_initial_exact_preview_and_no_recorded_conformance_claim(self):
        raw = dumps(fixture())
        result = authoring.start(raw, disclosure='public')
        files = dict(result.files)
        self.assertEqual(files['drafts/revision-0001.json'], raw)
        preview = parsed(files, 'previews/revision-0001.json')
        self.assertEqual(preview, draft.preview(raw))
        self.assertEqual(preview['mode'], 'draft_preview')
        self.assertFalse(any(preview['claims'].values()))
        self.assertEqual(preview['sourceVersions'][0]['originalText'],
            'Original e\u0301 artist text.\r\nSecond line.')
        self.assertEqual(files['definitions/draft-schema.json'], draft.SCHEMA_BYTES)
        self.assertFalse(any(path.startswith('source/') for path in files))
        self.assertNotIn('inputs/source-plan.json', files)
        self.assertEqual(dict(authoring.verify(files, result.manifest_hash).files), files)

    def test_initial_revision_keeps_all_original_bytes_and_historical_review(self):
        first_raw = dumps(fixture())
        first = authoring.start(first_raw, disclosure='public')
        next_raw = dumps(revision(first_raw))
        second = authoring.revise(dict(first.files), first.manifest_hash, next_raw, disclosure='public')
        files = dict(second.files)
        self.assertEqual(files['drafts/revision-0001.json'], first_raw)
        self.assertEqual(files['drafts/revision-0002.json'], next_raw)
        self.assertEqual(files['previews/revision-0001.json'], dict(first.files)['previews/revision-0001.json'])
        self.assertEqual(parsed(files, 'previews/revision-0002.json')['reviewDispositions'][0]['application'],
            'historical_target')
        self.assertEqual(dict(authoring.compose([first_raw, next_raw], disclosure='public').files), files)
        self.assertEqual(dict(authoring.verify(files, second.manifest_hash).files), files)

    def test_actual_owner_binding_and_revision_retain_complete_original_source(self):
        case, first = bound_case('owner')
        files = dict(first.files)
        bound_raw = files['drafts/revision-0001.json']
        binding = parsed(files, 'drafts/revision-0001.json')['recordBinding']
        self.assertEqual(binding['kind'], 'owner_record_source')
        self.assertEqual(binding['recordHash'], case['selection'])
        self.assertEqual(binding['workCitation'], case['citation'])
        self.assertEqual(files['inputs/source-plan.json'], case['plan_raw'])
        self.assertEqual({p.removeprefix('source/'): raw for p, raw in files.items()
            if p.startswith('source/')}, dict(case['files']))
        revised = authoring.revise(files, first.manifest_hash, dumps(revision(bound_raw)), disclosure='public')
        later = dict(revised.files)
        self.assertEqual(parsed(later, 'drafts/revision-0002.json')['recordBinding'], binding)
        for path, raw in case['files'].items(): self.assertEqual(later['source/' + path], raw)
        self.assertEqual(later['drafts/revision-0001.json'], bound_raw)
        self.assertEqual(dict(authoring.verify(later, revised.manifest_hash).files), later)

    def test_later_capture_confirm_replays_owner_and_retains_exact_form_source_binding(self):
        from . import semantic_authoring_capture_v1 as capture
        from .test_semantic_authoring_capture_v1 import form
        case = source_case('owner')
        value = form(purpose='later_documentation')
        value['workId'] = case['citation']
        form_raw = dumps(value)
        first = authoring.start(capture.capture(form_raw), selection=case['selection'],
            capture_form_raw=form_raw, **options(case), disclosure='public')
        first_files = dict(first.files)
        first_raw = first_files['drafts/revision-0001.json']
        original = parsed(first_files, 'drafts/revision-0001.json')
        binding = original['recordBinding']
        self.assertEqual(binding['recordHash'], case['selection'])
        self.assertEqual(binding['workCitation'], case['citation'])
        self.assertTrue(all(row['status'] == 'draft' for row in original['sourceVersions']))
        version_id = value['sourceVersionIds']['originalText']
        revised_raw = capture.confirm(first_raw, version_id,
            confirmed_by=value['sourceAuthor']['entityId'], confirmed_at='2026-09-22T10:05:00Z',
            revised_at='2026-09-22T10:06:00Z')
        revised = authoring.revise(first_files, first.manifest_hash, revised_raw, disclosure='public')
        files = dict(revised.files)
        current = parsed(files, 'drafts/revision-0002.json')
        self.assertEqual(current['recordBinding'], binding)
        self.assertEqual(files['drafts/revision-0001.json'], first_raw)
        self.assertEqual(files['inputs/capture-form.json'], form_raw)
        self.assertEqual(files['inputs/source-plan.json'], case['plan_raw'])
        self.assertEqual({p.removeprefix('source/'): raw for p, raw in files.items()
            if p.startswith('source/')}, dict(case['files']))
        before = {row['versionId']: row for row in original['sourceVersions']}
        for row in current['sourceVersions']:
            if row['versionId'] == version_id:
                self.assertEqual(row['status'], 'confirmed')
                self.assertEqual(row['originalText'], value['originalText'])
                self.assertEqual(row['versionHash'], draft.source_version_hash(row))
                self.assertEqual(row['confirmation']['scope'], 'exact_source_version_only')
            else:
                self.assertEqual(row, before[row['versionId']])
        self.assertEqual(current['relationships'], [])
        self.assertEqual(dict(authoring.verify(files, revised.manifest_hash).files), files)

    def test_actual_recorded_account_binding_and_offline_full_rebuild(self):
        with mock.patch('socket.socket', side_effect=AssertionError('network disabled')):
            case, result = bound_case('recorded')
            files = dict(result.files)
            binding = parsed(files, 'drafts/revision-0001.json')['recordBinding']
            self.assertEqual(binding['kind'], 'recorded_semantic_source')
            self.assertEqual(binding['recordSelector'], case['selection'])
            self.assertEqual(binding['workCitation'], case['citation'])
            self.assertEqual({p.removeprefix('source/'): raw for p, raw in files.items()
                if p.startswith('source/')}, dict(case['files']))
            self.assertEqual(dict(authoring.verify(files, result.manifest_hash).files), files)
        preview = parsed(files, 'previews/revision-0001.json')
        self.assertFalse(preview['claims']['recordedStreamDossier'])
        self.assertFalse(preview['claims']['signaturePresent'])
        self.assertFalse(preview['claims']['mediaIngested'])

    def test_confirmed_text_cannot_change_even_with_valid_new_confirmation_hash(self):
        raw = dumps(fixture())
        first = authoring.start(raw, disclosure='public')
        revised = revision(raw)
        revised['sourceVersions'][0]['originalText'] += ' Rewritten confirmed source.'
        revised['sourceVersions'][0]['versionHash'] = draft.source_version_hash(revised['sourceVersions'][0])
        draft.inspect_draft(dumps(revised))
        with self.assertRaisesRegex(MuseumError, 'confirmed source version'):
            authoring.revise(dict(first.files), first.manifest_hash, dumps(revised), disclosure='public')

    def test_review_retarget_and_stable_entity_id_retyping_reject(self):
        raw = dumps(fixture())
        first = authoring.start(raw, disclosure='public')
        for mode in ('review', 'entity'):
            revised = revision(raw)
            if mode == 'review':
                revised['reviews'][0]['targetSnapshot'] = deepcopy(revised['relationships'][0])
                revised['reviews'][0]['targetHash'] = keccak256(dumps(revised['reviews'][0]['targetSnapshot']))
            else: revised['entities'][0]['kind'] = 'place'
            draft.inspect_draft(dumps(revised))
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, 'stable identity retargeted'):
                authoring.revise(dict(first.files), first.manifest_hash, dumps(revised), disclosure='public')

    def test_lineage_missing_reordered_and_wrong_source_binding_reject(self):
        first_raw = dumps(fixture())
        second_raw = dumps(revision(first_raw))
        for rows in ([], [second_raw], [second_raw, first_raw], [first_raw, first_raw]):
            with self.subTest(rows=len(rows)), self.assertRaises(MuseumError):
                authoring.compose(rows, disclosure='public')
        case, first = bound_case()
        raw = dict(first.files)['drafts/revision-0001.json']
        revised = revision(raw)
        revised['recordBinding']['recordHash'] = schema_id('foreign original record')
        with self.assertRaises(MuseumError):
            authoring.revise(dict(first.files), first.manifest_hash, dumps(revised), disclosure='public')
        foreign = later_fixture(case['citation'] + '/foreign')
        foreign['entities'][0]['entityId'] = foreign['workId']
        with self.assertRaises(MuseumError):
            authoring.start(dumps(foreign), selection=case['selection'], **options(case), disclosure='public')

    def test_revision_count_bound_rejects_before_replaying_repeated_drafts(self):
        raw = dumps(fixture())
        with self.assertRaisesRegex(MuseumError, 'revision count'):
            authoring.compose([raw] * (authoring.MAX_REVISIONS + 1), disclosure='public')

    def test_rehashed_preview_index_report_definition_and_extra_file_reject(self):
        result = authoring.start(dumps(fixture()), disclosure='public')
        original = dict(result.files)
        for path in ('previews/revision-0001.json', 'authoring/revision-index.json',
                'report.json', 'definitions/draft-schema.json', 'unexpected.json'):
            files = dict(original)
            files[path] = b'{}'
            files, digest = repin(files)
            with self.subTest(path=path), self.assertRaises(MuseumError): authoring.verify(files, digest)

    def test_rehashed_original_source_or_source_plan_does_not_gain_admission(self):
        _, result = bound_case()
        original = dict(result.files)
        files = dict(original)
        snapshot = parsed(files, 'source/snapshot.json')
        snapshot['inventedField'] = 'not original'
        files['source/snapshot.json'] = dumps(snapshot)
        plan = parsed(files, 'inputs/source-plan.json')
        plan['snapshotHash'] = keccak256(files['source/snapshot.json'])
        files['inputs/source-plan.json'] = dumps(plan)
        manifest = parsed(files, 'manifest.json')
        manifest['sourcePlanHash'] = keccak256(files['inputs/source-plan.json'])
        files['manifest.json'] = dumps(manifest)
        files, digest = repin(files)
        with self.assertRaisesRegex(MuseumError, 'original owner replay'):
            authoring.verify(files, digest)
        files = dict(original)
        del files['source/transcript.json']
        files, digest = repin(files)
        with self.assertRaises(MuseumError): authoring.verify(files, digest)

    def test_later_requires_exact_source_pairs_and_initial_cannot_smuggle_source(self):
        case = source_case('owner')
        raw = dumps(later_fixture(case['citation']))
        valid = options(case)
        for omitted in ('source_files', 'source_plan_raw', 'source_plan_hash'):
            args = dict(valid); args[omitted] = None
            with self.subTest(omitted=omitted), self.assertRaises(MuseumError):
                authoring.start(raw, selection=case['selection'], **args, disclosure='public')
        with self.assertRaises(MuseumError): authoring.start(raw, disclosure='public')
        with self.assertRaises(MuseumError):
            authoring.start(dumps(fixture()), selection=case['selection'], **valid, disclosure='public')
        with self.assertRaises(MuseumError):
            authoring.start(raw, selection=case['selection'], **dict(valid,
                source_plan_hash=schema_id('wrong plan')), disclosure='public')

    def test_restricted_cli_preflight_before_any_path_open(self):
        argv = ['bind', '--draft', 'must-not-open.json', '--selection', 'selection.json',
            '--selection-hash', schema_id('selection'), '--source', 'source',
            '--source-plan', 'plan.json', '--source-plan-hash', schema_id('plan'),
            '--disclosure', 'restricted', '--output', 'unused-output']
        err = io.StringIO()
        with mock.patch.object(Path, 'open', side_effect=AssertionError('file read before public guard')):
            with redirect_stderr(err), self.assertRaises(SystemExit) as caught: authoring.main(argv)
        self.assertEqual(caught.exception.code, 2)
        self.assertIn('public', err.getvalue())

    def test_cli_capture_confirm_explicit_mapping_and_review_keep_exact_history(self):
        from .test_semantic_authoring_capture_v1 import form
        value = form(); form_raw = dumps(value)
        with tempfile.TemporaryDirectory() as temp, mock.patch('socket.socket',
                side_effect=AssertionError('network disabled')):
            root = Path(temp)
            form_path = root / 'form.json'; form_path.write_bytes(form_raw)
            captured_dir = root / 'captured'
            captured, _ = cli(['capture', '--form', str(form_path), '--form-hash', keccak256(form_raw),
                '--disclosure', 'public', '--output', str(captured_dir)])
            first_raw = (captured_dir / 'drafts/revision-0001.json').read_bytes()
            first = loads(first_raw, canonical=True)
            self.assertEqual(first['relationships'], [])
            self.assertTrue(all(row['status'] == 'draft' for row in first['sourceVersions']))
            self.assertEqual((captured_dir / 'inputs/capture-form.json').read_bytes(), form_raw)
            confirmed_dir = root / 'confirmed'
            confirmed, _ = cli(['confirm', '--package', str(captured_dir), '--package-hash', captured['manifestHash'],
                '--version-id', value['sourceVersionIds']['originalText'], '--confirmed-by', value['sourceAuthor']['entityId'],
                '--confirmed-at', '2026-09-22T10:05:00Z', '--revised-at', '2026-09-22T10:06:00Z',
                '--disclosure', 'public', '--output', str(confirmed_dir)])
            second_raw = (confirmed_dir / 'drafts/revision-0002.json').read_bytes()
            second = loads(second_raw, canonical=True)
            confirmed_rows = [row for row in second['sourceVersions'] if row['status'] == 'confirmed']
            self.assertEqual(len(confirmed_rows), 1)
            self.assertEqual(confirmed_rows[0]['originalText'], value['originalText'])
            self.assertEqual(confirmed_rows[0]['confirmation']['scope'], 'exact_source_version_only')
            self.assertEqual(second['relationships'], [])

            mapped = deepcopy(second)
            mapped.update(revision='3', previousRevisionHash=keccak256(second_raw), revisedAt='2026-09-22T10:07:00Z')
            relation = deepcopy(fixture()['relationships'][0])
            relation.update(subjectId=value['workId'], objectId=value['sourceAuthor']['entityId'],
                mappedBy=value['sourceAuthor']['entityId'], sourceVersionId=value['sourceVersionIds']['originalText'])
            mapped['relationships'].append(relation)
            mapped_raw = dumps(mapped)
            mapped_path = root / 'mapped.json'; mapped_path.write_bytes(mapped_raw)
            mapped_dir = root / 'mapped'
            mapping, _ = cli(['revise', '--package', str(confirmed_dir), '--package-hash', confirmed['manifestHash'],
                '--draft', str(mapped_path), '--disclosure', 'public', '--output', str(mapped_dir)])
            request = {'reviewId': 'urn:test:review:captured-mapping', 'reviewer': fixture()['reviewers'][0],
                'targetKind': 'relationship', 'targetId': relation['relationshipId'], 'status': 'accepted',
                'reviewedAt': '2026-09-22T10:08:00Z', 'rationale': 'The exact stated mapping was reviewed.'}
            request_raw = dumps(request); request_path = root / 'review.json'; request_path.write_bytes(request_raw)
            reviewed_dir = root / 'reviewed'
            reviewed, _ = cli(['review', '--package', str(mapped_dir), '--package-hash', mapping['manifestHash'],
                '--review', str(request_path), '--review-hash', keccak256(request_raw),
                '--revised-at', '2026-09-22T10:09:00Z', '--disclosure', 'public', '--output', str(reviewed_dir)])
            files = read_tree(reviewed_dir)
            for number, raw in enumerate((first_raw, second_raw, mapped_raw), 1):
                self.assertEqual(files[f'drafts/revision-{number:04d}.json'], raw)
            fourth = parsed(files, 'drafts/revision-0004.json')
            self.assertEqual(fourth['reviews'][0]['targetSnapshot'], relation)
            self.assertEqual(fourth['reviews'][0]['targetHash'], keccak256(dumps(relation)))
            self.assertEqual(files['inputs/capture-form.json'], form_raw)
            preview = parsed(files, 'previews/revision-0004.json')
            self.assertEqual(preview['mode'], 'draft_preview')
            self.assertFalse(any(preview['claims'].values()))
            self.assertEqual(dict(authoring.verify(files, reviewed['manifestHash']).files), files)

            changed_form = deepcopy(value); changed_form['title'] += ' Changed after capture.'
            files['inputs/capture-form.json'] = dumps(changed_form)
            manifest = parsed(files, 'manifest.json')
            manifest['captureFormHash'] = keccak256(files['inputs/capture-form.json'])
            files['manifest.json'] = dumps(manifest)
            files, digest = repin(files)
            with self.assertRaisesRegex(MuseumError, 'capture form'):
                authoring.verify(files, digest)

    def test_cli_initial_bind_revise_verify_dispatch_and_no_overwrite(self):
        case = source_case('owner')
        with tempfile.TemporaryDirectory() as temp, mock.patch('socket.socket',
                side_effect=AssertionError('network disabled')):
            root = Path(temp)
            initial_path = root / 'initial.json'; initial_path.write_bytes(dumps(fixture()))
            first_dir = root / 'initial-package'
            created, _ = cli(['assemble', '--draft', str(initial_path), '--disclosure', 'public', '--output', str(first_dir)])
            first_hash = created['manifestHash']
            self.assertEqual(dict(package_v2.verify_package(first_dir, first_hash).files), read_tree(first_dir))
            before = read_tree(first_dir)
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                authoring.main(['assemble', '--draft', str(initial_path), '--disclosure', 'public', '--output', str(first_dir)])
            self.assertEqual(read_tree(first_dir), before)
            source_dir = root / 'original-source'; write_tree(case['files'], source_dir)
            plan_path = root / 'source-plan.json'; plan_path.write_bytes(case['plan_raw'])
            selection_path = root / 'selection.json'; selection_raw = dumps(case['selection']); selection_path.write_bytes(selection_raw)
            draft_path = root / 'later.json'; draft_path.write_bytes(dumps(later_fixture(case['citation'])))
            bound_dir = root / 'bound'
            bound, _ = cli(['bind', '--draft', str(draft_path), '--selection', str(selection_path),
                '--selection-hash', keccak256(selection_raw), '--source', str(source_dir), '--source-plan', str(plan_path),
                '--source-plan-hash', case['plan_hash'], '--disclosure', 'public', '--output', str(bound_dir)])
            bound_raw = (bound_dir / 'drafts/revision-0001.json').read_bytes()
            revised_path = root / 'revised.json'; revised_path.write_bytes(dumps(revision(bound_raw)))
            revised_dir = root / 'revised'
            revised, _ = cli(['revise', '--package', str(bound_dir), '--package-hash', bound['manifestHash'],
                '--draft', str(revised_path), '--disclosure', 'public', '--output', str(revised_dir)])
            checked, _ = cli(['verify', str(revised_dir), '--manifest-hash', revised['manifestHash']])
            self.assertEqual(checked['manifestHash'], revised['manifestHash'])
            self.assertEqual((revised_dir / 'drafts/revision-0001.json').read_bytes(), bound_raw)
            self.assertEqual((revised_dir / 'drafts/revision-0002.json').read_bytes(), revised_path.read_bytes())


if __name__ == '__main__':
    unittest.main()
