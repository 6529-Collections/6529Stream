"""Add one registered native token-script requirement to unchanged current V1."""
import argparse
from pathlib import Path

from . import canonical_current_assessment_v1 as previous
from . import canonical_dossier_observations_v4 as observations
from . import object_dossier as package
from . import object_dossier_inventory as inventory
from . import token_script_registered_capture_v1 as script_capture
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CURRENT_REQUIREMENT_ASSESSMENT_V2'
MODE = 'canonical_current_assessment_v2_script'
PREFIX = {'previous': 'current-v1/', 'script': 'script/'}
ASSESSMENT_PATH = 'assessment/current-requirements.json'
COMPARISON_PATH = 'assessment/previous-comparison.json'
SCRIPT_CODE = 'OD-SCRIPT-MANIFEST'
STATE_KEYS = previous.STATE_KEYS
CLAIMS = {'originalV4AndCurrentV1BytesRetained': True,
    'originalNineteenFortyNineDenominatorRetained': True,
    'completeRegisteredTokenScriptReplayedWhenSupplied': True,
    'sameAnchorPositiveObservationsReconciled': True,
    'onlyNativeTokenScriptCodeNewlyEligible': True,
    'negativeWorkClassInferredFromAbsence': False, 'providerCompletenessAssumed': True,
    'sourceOriginAuthenticated': False, 'chainConsensusProven': False,
    'historicalWriterGrantProven': False, 'rendererExecuted': False,
    'physicalFactsProven': False, 'institutionalAcceptance': False,
    'completeCanonicalDossier': False, 'networkFetch': False}
QUALIFICATION = ('The verified current V1 assessment and every original child byte are retained. '
    'A separately replayed, same-token and same-state registered native script capture may establish '
    'positive script work class. OD-SCRIPT-MANIFEST is verified only with complete selected script '
    'and dependency bytes or authenticated empty dependency, and exact current ACTIVE registered '
    'interpretation documents. Unknown selection or incomplete dependency remains unresolved. '
    'This does not prove a non-script class, provider origin, consensus, historical writer grants, '
    'renderer execution, other dossier requirements or institutional acceptance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'mode': MODE,
    'previousProfileHash': previous.PROFILE_HASH,
    'registeredScriptCaptureProfileHash': script_capture.PROFILE_HASH,
    'requirementInventoryHash': inventory.REQUIREMENTS_HASH,
    'sourceStateKeys': STATE_KEYS, 'prefixes': PREFIX,
    'eligibleCodes': [SCRIPT_CODE],
    'verification': 'Replay both complete originals, compare exact target/state and current '
        'Core/Metadata runtime, reconcile all same-anchor positive RPC observations, '
        'reconstruct every requirement row and wrapper byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _sub(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items()
        if path.startswith(prefix)}


def _ref(path, raw, selector):
    return inventory.EvidenceRef(path, keccak256(raw), selector)


def _script_refs(files, source, previous_files):
    snapshot = _json(files, 'token/source/snapshot.json')
    state = snapshot['sourceState']
    require(type(state) is dict and all(state.get(key) == source[key]
        for key in STATE_KEYS), 'current V2 script exact token/source state differs')
    anchor = _json(files, 'token/source/anchor.json')
    require(all(anchor.get(key) == source[key] for key in STATE_KEYS),
        'current V2 script anchor target/state differs')
    registry = _json(files, 'registry/source/snapshot.json')
    require(all(source.get(key) == value for key, value in
        registry['sourceState'].items()),
        'current V2 script Registry source state differs')
    metadata_anchor = _json(previous_files,
        'v4/canonical/input/acquisition/inputs/work/metadata/anchor.json')
    pins = {row['address']: row['runtimeHash'] for row in metadata_anchor['codePins']}
    graph = snapshot['graph']
    registered_graph = registry['graph']
    registered_pins = {row['address']: row['runtimeHash'] for row in
        registered_graph['runtimePins']}
    require(graph['metadata']['address'] == metadata_anchor['host'] and
        graph['metadata']['runtimeHash'] == pins.get(metadata_anchor['host']) and
        graph['core']['address'] == source['core'] and
        graph['core']['runtimeHash'] == pins.get(source['core']) and
        registered_graph['schemaRegistry'] == metadata_anchor['schemas'] and
        registered_graph['chunkStore'] == metadata_anchor['store'] and
        registered_pins.get(metadata_anchor['schemas']) == pins.get(metadata_anchor['schemas']) and
        registered_pins.get(metadata_anchor['store']) == pins.get(metadata_anchor['store']),
        'current V2 script selected Core/Metadata/Registry runtime differs from V4')
    if snapshot['positiveScriptClassification'] is not True:
        require(_json(files, 'report.json')['currentVerifiedCodes'] == [],
            'current V2 zero script selection promoted')
    report = _json(files, 'report.json')
    require(report['sourceState'] == state and
        report['currentVerifiedCodes'] in ([], [SCRIPT_CODE]) and
        report['workClass'] == snapshot['workClass'],
        'current V2 script child report differs')
    if report['currentVerifiedCodes'] != [SCRIPT_CODE]:
        return report['workClass'], {}
    interpretation = snapshot['interpretation']
    require(snapshot['positiveScriptClassification'] is True and
        interpretation['report']['completeScriptBytes'] is True and
        interpretation['report']['completeDependencyBytes'] is True and
        interpretation['report']['dependency']['status'] in
            ('complete', 'authenticated_empty') and
        'token/payloads/script.bin' in files,
        'current V2 script/dependency requirement incomplete')
    return 'script', {SCRIPT_CODE: (
        _ref(PREFIX['script'] + 'token/source/snapshot.json',
            files['token/source/snapshot.json'], '/interpretation'),
        _ref(PREFIX['script'] + 'token/payloads/script.bin',
            files['token/payloads/script.bin'], '$'),
        _ref(PREFIX['script'] + 'registry/source/snapshot.json',
            files['registry/source/snapshot.json'], '/documents'))}


def _previous_rows(files):
    assessment = _json(files, previous.ASSESSMENT_PATH)
    require(assessment['counts']['total'] == 49 and
        [row['code'] for row in assessment['results']] ==
            [row['code'] for row in inventory.REQUIREMENTS] and
        assessment['workClass'] == 'unknown',
        'current V2 previous forty-nine assessment differs')
    verified, supplied = {}, {}
    for row in assessment['results']:
        code = row['code']
        if row['state'] == 'verified':
            refs = []
            for ref in row['evidenceRefs']:
                path = ref['source']
                require(path in files and keccak256(files[path]) == ref['contentHash'],
                    'current V2 previous evidence ref differs')
                refs.append(_ref(PREFIX['previous'] + path, files[path],
                    ref['selector']))
            verified[code] = tuple(refs)
        elif row['suppliedHashes']:
            supplied[code] = tuple(row['suppliedHashes'])
    require(set(verified) == set(_json(files, 'report.json')['currentVerifiedCodes'])
        and set(verified) <= set(previous.CODES),
        'current V2 previous verified scope differs')
    return assessment, verified, supplied


def _available_rpc(files, name, anchor_path, transcript_path, provenance, config):
    """Omit only replay-validated unavailable eth_call rows from positive joins."""
    transcript = _json(files, transcript_path)
    available = dict(transcript, calls=[row for row in transcript['calls']
        if 'unavailable' not in row])
    derived = dict(files, **{transcript_path: dumps(available)})
    return observations._rpc(derived, name, anchor_path, transcript_path,
        provenance, config)


def _reconcile_sources(old_files, script_files, source):
    base = _sub(old_files, previous.PREFIX['v4'])
    observed = previous.joined_dossier._v4_sources(base)
    config = observed[0]['configuration']
    for name in ('finality', 'entropy'):
        child = _sub(old_files, previous.PREFIX[name])
        if child:
            observed.append(observations._rpc(child, 'current-v1/' + name,
                'source/anchor.json', 'source/transcript.json',
                _json(child, 'manifest.json')['provenance'], config))
    if script_files is not None:
        token = _json(script_files, 'token/source/snapshot.json')
        registry = _json(script_files, 'registry/source/snapshot.json')
        observed.append(_available_rpc(script_files, 'current-v2/token-script',
            'token/source/anchor.json', 'token/source/transcript.json',
            token['provenance'], config))
        observed.append(_available_rpc(script_files, 'current-v2/script-registry',
            'registry/source/anchor.json', 'registry/source/transcript.json',
            registry['provenance'], config))
    positive_reads = {}
    for item in observed:
        if item['kind'] != 'rpc':
            continue
        for row in item['transcript']['calls']:
            if row['method'] not in ('eth_call', 'eth_getCode') or 'result' not in row:
                continue
            key = dumps([row['method'], row['params']])
            before, before_source = positive_reads.setdefault(
                key, (row['result'], item['name']))
            require(before == row['result'],
                'current V2 overlapping positive read differs: ' + row['method'] +
                ' ' + (row['params'][0]['to'] if row['method'] == 'eth_call'
                    else row['params'][0]) +
                (' ' + row['params'][0]['data'] if row['method'] == 'eth_call' else '') +
                ' ' + before_source + ' vs ' + item['name'])
    return observations.reconcile(source, observed)


def _compose(previous_files, previous_hash, script_files, script_hash, disclosure):
    require(disclosure == 'public', 'current V2 public disclosure required before reads')
    require((script_files is None) == (script_hash is None),
        'current V2 script files and pin required together')
    old = previous.verify(dict(previous_files), previous_hash)
    old_files = dict(old.files)
    script = None if script_files is None else script_capture.verify(
        dict(script_files), script_hash)
    new_files = None if script is None else dict(script.files)
    source = old.report['sourceState']
    old_assessment, verified, supplied = _previous_rows(old_files)
    work_class = 'unknown'
    if new_files is not None:
        work_class, added = _script_refs(new_files, source, old_files)
        require(set(added) <= {SCRIPT_CODE} and SCRIPT_CODE not in verified,
            'current V2 script promotion scope differs')
        verified.update(added)
        for code in added: supplied.pop(code, None)
    reconciliation = _reconcile_sources(old_files, new_files, source)
    current = inventory.assess(work_class, verified, supplied)
    codes = [row['code'] for row in inventory.REQUIREMENTS if row['code'] in verified]
    comparison = {'previousAssessment': package._ref(PREFIX['previous'] +
            previous.ASSESSMENT_PATH, old_files[previous.ASSESSMENT_PATH]),
        'previousRequirementCount': '49', 'currentRequirementCount': '49',
        'workClass': work_class, 'currentVerifiedCodes': codes,
        'rows': [{'code': before['code'], 'previousState': before['state'],
            'currentState': after['state']} for before, after in
            zip(old_assessment['results'], current['results'])],
        'sourceReconciliation': reconciliation,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output = {PREFIX['previous'] + path: raw for path, raw in old_files.items()}
    if new_files is not None:
        output.update({PREFIX['script'] + path: raw for path, raw in new_files.items()})
    output[ASSESSMENT_PATH] = dumps(current)
    output[COMPARISON_PATH] = dumps(comparison)
    output['definitions/profile.json'] = PROFILE_BYTES
    report = {'profile': NAME, 'profileHash': PROFILE_HASH,
        'previousManifestHash': previous_hash, 'scriptManifestHash': script_hash,
        'sourceState': source, 'workClass': work_class,
        'originalPacketGroupCount': old.report['originalPacketGroupCount'],
        'originalRequirementCount': '49',
        'previousRequirementCounts': old_assessment['counts'],
        'currentRequirementCounts': current['counts'],
        'currentVerifiedCodes': codes, 'previousAssessmentChanged': False,
        'complete': current['complete'], 'claims': CLAIMS, 'qualification': QUALIFICATION}
    output['report.json'] = dumps(report)
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'profileHash': PROFILE_HASH,
        'version': '2', 'inputs': {'previous': previous_hash, 'script': script_hash},
        'disclosure': disclosure,
        'assessment': package._ref(ASSESSMENT_PATH, output[ASSESSMENT_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'current V2 manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(previous_files, previous_hash, *, script_files=None, script_hash=None,
        disclosure):
    try:
        return _compose(previous_files, previous_hash, script_files, script_hash,
            disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError,
            RecursionError, OSError) as exc:
        raise MuseumError('malformed current V2 assessment inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'current V2 external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile',
            'profileHash', 'version', 'inputs', 'disclosure', 'assessment', 'files',
            'claims', 'qualification'} and manifest['mode'] == MODE and
            manifest['profile'] == NAME and manifest['profileHash'] == PROFILE_HASH
            and manifest['version'] == '2' and manifest['claims'] == CLAIMS and
            manifest['qualification'] == QUALIFICATION,
            'current V2 closed manifest differs')
        require(manifest['files'] == [package._ref(path, body)
            for path, body in sorted(files.items()) if path != 'manifest.json'],
            'current V2 file commitments differ')
        inputs = manifest['inputs']
        require(type(inputs) is dict and set(inputs) == {'previous', 'script'},
            'current V2 input pins differ')
        children = {name: _sub(files, prefix) for name, prefix in PREFIX.items()}
        require(bool(children['script']) == (inputs['script'] is not None),
            'current V2 script child presence differs')
        rebuilt = compose(children['previous'], inputs['previous'],
            script_files=children['script'] or None, script_hash=inputs['script'],
            disclosure=manifest['disclosure'])
        require(dict(rebuilt.files) == files,
            'current V2 deterministic reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError,
            RecursionError, OSError) as exc:
        raise MuseumError('malformed current V2 assessment package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('assemble')
    create.add_argument('--current-v1', type=Path, required=True)
    create.add_argument('--current-v1-hash', required=True)
    create.add_argument('--script', type=Path)
    create.add_argument('--script-hash')
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            require(args.disclosure == 'public',
                'current V2 public disclosure required before reads')
            from .repository_exchange import _destination, _publish
            sources = [args.current_v1] + ([args.script] if args.script else [])
            _destination(args.output, sources)
            result = compose(read_tree(args.current_v1), args.current_v1_hash,
                script_files=None if args.script is None else read_tree(args.script),
                script_hash=args.script_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash,
            'report': result.report}).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'current V2 assessment: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
