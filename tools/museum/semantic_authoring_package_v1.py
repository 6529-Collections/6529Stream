"""Portable offline draft history with concrete source replay on every reopening."""
import argparse
from pathlib import Path

from . import semantic_authoring as authoring
from . import semantic_authoring_capture_v1 as capture
from . import semantic_authoring_sources_v1 as sources
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require

NAME = 'STREAM_MUSEUM_SEMANTIC_AUTHORING_PACKAGE_V1'
MODE = 'semantic_authoring_package_v1'
MAX_REVISIONS = 32
INDEX_PATH = 'authoring/revision-index.json'
BINDING_PATH = 'authoring/source-binding.json'
PLAN_PATH = 'inputs/source-plan.json'
FORM_PATH = 'inputs/capture-form.json'
CLAIMS = {'draftPreviewOnly': True, 'allRevisionsRetained': True,
    'sourceEvidenceReplayedWhenSupplied': True, 'originalAuthoringSchemaUnchanged': True,
    'confirmationScopeExpanded': False, 'sourceAuthorAuthenticated': False,
    'mapperOrReviewerAuthenticated': False, 'publicationAuthorized': False,
    'recordPublished': False, 'profileRegistered': False, 'recordedStreamDossier': False,
    'mediaReceived': False, 'currentOwnerProven': False, 'sourceOriginAuthenticated': False,
    'consensusOrFinalityProven': False, 'institutionalAcceptance': False, 'networkFetch': False}
QUALIFICATION = ('Offline draft history, not a recorded or conformant Museum dossier. '
    'Every reopening validates the unchanged authoring schema and complete revision lineage. '
    'Later documentation replays exact original recorded-account or selected OwnerRecords '
    'evidence and binds the original token citation. This does not authenticate the draft '
    'author, mapper or reviewer, confer current ownership or publication authority, or prove '
    'source-provider origin, consensus, finality, legal identity or institutional acceptance. '
    'Confirmation covers exact source-version text only. Structured enrichment and its reviews '
    'remain separately attributed. Described attachments are not received or uploaded media.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'draftSchemaHash': authoring.SCHEMA_HASH, 'sourceProfileHash': sources.PROFILE_HASH,
    'captureProfileHash': capture.PROFILE_HASH,
    'limits': {'revisions': MAX_REVISIONS, 'draftBytes': authoring.MAX_DRAFT_BYTES,
        'packageBytes': MAX_BYTES, 'manifestBytes': MAX_MANIFEST},
    'retention': 'All original revisions and source bytes; optional original plain-language form.',
    'verification': 'Replay concrete evidence, validate every original revision and transition, '
        'rebuild every preview and compare every package byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'authoring package public disclosure required before reads')


def _paired(files, plan, digest):
    require((files is None) == (plan is None) == (digest is None),
        'authoring source files, plan and plan pin must be supplied together')


def _selection(binding):
    return binding['recordSelector'] if binding['kind'] == 'recorded_semantic_source' else binding['recordHash']


def _options(evidence):
    return {} if evidence is None else {'source': evidence.source, 'source_hash': evidence.source_hash}


def _path(index, kind='drafts'):
    return kind + '/revision-' + str(index).zfill(4) + '.json'


def _compose(revisions, *, source_files, source_plan_raw, source_plan_hash,
             capture_form_raw, disclosure):
    _public(disclosure)
    _paired(source_files, source_plan_raw, source_plan_hash)
    require(type(revisions) in (list, tuple) and 1 <= len(revisions) <= MAX_REVISIONS,
        'authoring revision count bound')
    require(all(type(raw) is bytes and 0 < len(raw) <= authoring.MAX_DRAFT_BYTES for raw in revisions),
        'authoring revision byte bound')
    originals = None if source_files is None else dict(source_files)
    if originals is not None: package._bounded(originals)
    evidence = None if originals is None else sources.admit(originals, source_plan_raw,
        source_plan_hash, disclosure=disclosure)
    options = _options(evidence)
    values = [authoring.validate_draft(raw, **options) for raw in revisions]
    first = values[0]
    require(first['revision'] == '1' and first['previousRevisionHash'] is None,
        'authoring history must begin at original revision one')
    require((first['purpose'] == 'later_documentation') == (evidence is not None),
        'authoring source required only for later documentation')
    for before, after in zip(revisions, revisions[1:]):
        authoring.revise_draft(before, after, **options)
    if capture_form_raw is not None:
        expected = capture.capture(capture_form_raw)
        if evidence is not None:
            expected = authoring.bind_later_documentation(expected, evidence.source,
                _selection(first['recordBinding']), source_hash=evidence.source_hash)
        require(expected == revisions[0], 'authoring original capture form differs from first revision')
    output = {}
    if originals is not None:
        output.update({'source/' + path: raw for path, raw in originals.items()})
        output[PLAN_PATH] = source_plan_raw
    if capture_form_raw is not None: output[FORM_PATH] = capture_form_raw
    rows = []
    for number, (raw, value) in enumerate(zip(revisions, values), 1):
        draft_path, preview_path = _path(number), _path(number, 'previews')
        preview_raw = authoring.preview_bytes(raw, **options)
        output[draft_path], output[preview_path] = raw, preview_raw
        rows.append({'revision': str(number), 'draft': package._ref(draft_path, raw),
            'preview': package._ref(preview_path, preview_raw),
            'previousRevisionHash': value['previousRevisionHash']})
    output[INDEX_PATH] = dumps({'mode': authoring.MODE, 'draftId': first['draftId'],
        'workId': first['workId'], 'purpose': first['purpose'], 'revisions': rows,
        'latestRevision': str(len(rows)), 'historyPruned': False})
    output[BINDING_PATH] = dumps({'binding': first['recordBinding'],
        'source': None if evidence is None else evidence.report,
        'sourceAuthorConfirmationInferred': False, 'publicationAuthorityInferred': False})
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'mode': authoring.MODE,
        'draftId': first['draftId'], 'workId': first['workId'], 'purpose': first['purpose'],
        'revisionCount': str(len(rows)), 'latestDraftHash': keccak256(revisions[-1]),
        'sourceKind': None if evidence is None else evidence.report['kind'],
        'sourceEvidenceReplayed': evidence is not None,
        'captureFormRetained': capture_form_raw is not None,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output.update({'definitions/profile.json': PROFILE_BYTES,
        'definitions/draft-schema.json': authoring.SCHEMA_BYTES,
        'definitions/source-profile.json': sources.PROFILE_BYTES,
        'definitions/capture-profile.json': capture.PROFILE_BYTES,
        'report.json': dumps(report)})
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'disclosure': disclosure, 'revisionCount': str(len(rows)),
        'sourcePlanHash': source_plan_hash,
        'captureFormHash': None if capture_form_raw is None else keccak256(capture_form_raw),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'authoring manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(revisions, *, source_files=None, source_plan_raw=None, source_plan_hash=None,
            capture_form_raw=None, disclosure):
    try:
        return _compose(revisions, source_files=source_files, source_plan_raw=source_plan_raw,
            source_plan_hash=source_plan_hash, capture_form_raw=capture_form_raw, disclosure=disclosure)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, OSError, RecursionError) as exc:
        raise MuseumError('malformed authoring package input') from exc


def start(draft_raw, *, selection=None, source_files=None, source_plan_raw=None,
          source_plan_hash=None, capture_form_raw=None, disclosure):
    _public(disclosure)
    _paired(source_files, source_plan_raw, source_plan_hash)
    if source_files is not None:
        require(selection is not None, 'authoring later start requires explicit original record selection')
        evidence = sources.admit(source_files, source_plan_raw, source_plan_hash, disclosure=disclosure)
        draft_raw = authoring.bind_later_documentation(draft_raw, evidence.source, selection,
            source_hash=evidence.source_hash)
    else:
        require(selection is None, 'authoring record selection requires source evidence')
    return compose([draft_raw], source_files=source_files, source_plan_raw=source_plan_raw,
        source_plan_hash=source_plan_hash, capture_form_raw=capture_form_raw, disclosure=disclosure)


def _inputs(files, manifest):
    original = {p.removeprefix('source/'): raw for p, raw in files.items() if p.startswith('source/')}
    return {'source_files': original if original or manifest['sourcePlanHash'] is not None else None,
        'source_plan_raw': files.get(PLAN_PATH), 'source_plan_hash': manifest['sourcePlanHash'],
        'capture_form_raw': files.get(FORM_PATH)}


def verify(files, expected_hash):
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'authoring external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'disclosure', 'revisionCount', 'sourcePlanHash', 'captureFormHash',
            'files', 'claims', 'qualification'} and manifest['mode'] == MODE
            and manifest['profile'] == NAME and manifest['version'] == '1'
            and manifest['profileHash'] == PROFILE_HASH and manifest['claims'] == CLAIMS
            and manifest['qualification'] == QUALIFICATION, 'authoring closed manifest differs')
        _public(manifest['disclosure'])
        count = uint(manifest['revisionCount'], 16)
        require(1 <= count <= MAX_REVISIONS, 'authoring revision count bound')
        require(manifest['files'] == [package._ref(p, body) for p, body in sorted(files.items())
            if p != 'manifest.json'], 'authoring file commitments differ')
        form = files.get(FORM_PATH)
        require(manifest['captureFormHash'] == (None if form is None else keccak256(form)),
            'authoring capture form commitment differs')
        result = compose([files[_path(i)] for i in range(1, count + 1)],
            **_inputs(files, manifest), disclosure=manifest['disclosure'])
        require(dict(result.files) == files, 'authoring full reconstruction differs')
        return result
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, OSError, RecursionError) as exc:
        raise MuseumError('malformed authoring package') from exc


def revise(previous_files, previous_hash, revised_raw, *, disclosure):
    _public(disclosure)
    previous = verify(previous_files, previous_hash)
    files = dict(previous.files)
    manifest = loads(previous.manifest, maximum=MAX_MANIFEST, canonical=True)
    count = uint(manifest['revisionCount'], 16)
    return compose([files[_path(i)] for i in range(1, count + 1)] + [revised_raw],
        **_inputs(files, manifest), disclosure=disclosure)


def _read(path, maximum, expected_hash=None):
    require(not path.is_symlink() and not (hasattr(path, 'is_junction') and path.is_junction())
        and path.is_file(), 'authoring input must be regular file')
    with path.open('rb') as handle: raw = handle.read(maximum + 1)
    require(0 < len(raw) <= maximum, 'authoring input byte bound')
    if expected_hash is not None:
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'authoring input external pin differs')
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('assemble', 'bind', 'capture'):
        cmd = commands.add_parser(name)
        cmd.add_argument('--form' if name == 'capture' else '--draft', type=Path, required=True)
        if name == 'capture': cmd.add_argument('--form-hash', required=True)
        for flag in ('source', 'source-plan'):
            cmd.add_argument('--' + flag, type=Path)
        cmd.add_argument('--source-plan-hash')
        cmd.add_argument('--selection', type=Path)
        cmd.add_argument('--selection-hash')
    cmd = commands.add_parser('revise')
    cmd.add_argument('--draft', type=Path, required=True)
    cmd = commands.add_parser('confirm')
    cmd.add_argument('--version-id', required=True)
    cmd.add_argument('--confirmed-by', required=True)
    cmd.add_argument('--confirmed-at', required=True)
    cmd.add_argument('--revised-at', required=True)
    cmd = commands.add_parser('review')
    cmd.add_argument('--review', type=Path, required=True)
    cmd.add_argument('--review-hash', required=True)
    cmd.add_argument('--revised-at', required=True)
    for name in ('revise', 'confirm', 'review'):
        cmd = commands.choices[name]
        cmd.add_argument('--package', type=Path, required=True)
        cmd.add_argument('--package-hash', required=True)
    for name in ('assemble', 'bind', 'capture', 'revise', 'confirm', 'review'):
        cmd = commands.choices[name]
        cmd.add_argument('--disclosure', required=True)
        cmd.add_argument('--output', type=Path, required=True)
    for name in ('verify', 'preview'):
        cmd = commands.add_parser(name)
        cmd.add_argument('directory', type=Path)
        cmd.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command in ('verify', 'preview'):
            result = verify(read_tree(args.directory), args.manifest_hash)
            if args.command == 'preview':
                print(dict(result.files)[_path(uint(result.report['revisionCount']), 'previews')].decode('utf-8'))
                return
        else:
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            if args.command in ('assemble', 'bind', 'capture'):
                _paired(args.source, args.source_plan, args.source_plan_hash)
                require((args.selection is None) == (args.selection_hash is None),
                    'authoring selection and pin required together')
                source_paths = [p for p in (args.source, args.source_plan, args.selection) if p is not None]
                source_paths.append(args.form if args.command == 'capture' else args.draft)
                _destination(args.output, source_paths)
                options = {'source_files': None if args.source is None else read_tree(args.source),
                    'source_plan_raw': None if args.source_plan is None else _read(args.source_plan,
                        authoring.MAX_DRAFT_BYTES, args.source_plan_hash),
                    'source_plan_hash': args.source_plan_hash, 'disclosure': args.disclosure}
                form = None if args.command != 'capture' else _read(args.form,
                    authoring.MAX_DRAFT_BYTES, args.form_hash)
                raw = _read(args.draft, authoring.MAX_DRAFT_BYTES) if form is None else capture.capture(form)
                selection = None if args.selection is None else loads(_read(args.selection,
                    authoring.MAX_DRAFT_BYTES, args.selection_hash), canonical=True)
                if args.command == 'assemble':
                    require(selection is None, 'use bind for an original record selection')
                    result = compose([raw], **options)
                else:
                    require(args.command != 'bind' or args.source is not None,
                        'authoring bind requires source evidence')
                    result = start(raw, selection=selection, capture_form_raw=form, **options)
            else:
                source_paths = [args.package]
                if args.command == 'revise': source_paths.append(args.draft)
                if args.command == 'review': source_paths.append(args.review)
                _destination(args.output, source_paths)
                files = read_tree(args.package)
                previous = verify(files, args.package_hash)
                current = dict(previous.files)[_path(uint(previous.report['revisionCount']))]
                if args.command == 'revise': raw = _read(args.draft, authoring.MAX_DRAFT_BYTES)
                elif args.command == 'confirm':
                    raw = capture.confirm(current, args.version_id, confirmed_by=args.confirmed_by,
                        confirmed_at=args.confirmed_at, revised_at=args.revised_at)
                else:
                    review = loads(_read(args.review, authoring.MAX_DRAFT_BYTES, args.review_hash), canonical=True)
                    raw = capture.review(current, review, revised_at=args.revised_at)
                result = revise(files, args.package_hash, raw, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, source_paths)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__': main()
