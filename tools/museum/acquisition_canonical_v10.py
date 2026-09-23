"""Compose native current source families with exact V5 through V9 packets.

V10 keeps every earlier field and branch in its original authority vocabulary.
Seven groups carry both the original evidence and the concrete current native
projection. Verification replays every source; a JSON shape check is insufficient.
"""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from ..metadata.genesis_dossier_profile import PACKET_REQUIREMENTS
from . import acquisition_preservation_current_v1 as preservation
from . import acquisition_work_condition_v1 as work
from . import acquisition_recovery_sustainability_v1 as recovery
from . import canonical_packet_inputs_v1 as previous
from . import canonical_native_inputs_v1 as inputs
from . import canonical_composition_observations_v1 as observations
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_ACQUISITION_CANONICAL_V10'
MODE = 'acquisition_canonical_v10_assembly'
PACKET = 'STREAM_ACQUISITION_PACKET_V10'
PACKET_PATH = 'packet/acquisition-packet-v10.json'
CHANGED = {'8': 'preservation', '11': 'scriptDrill', '12': 'tombstone', '14': 'c2pa',
    '15': 'conditionReports', '17': 'recoveryLineage', '18': 'platformSustainability'}
BRANCHES = {key: 'native_current_' + key + '_v1' for key in CHANGED.values()}
CLAIMS = {'allNineteenGroupsRetained': True, 'originalInputBytesRetained': True,
    'concreteSourceConsumersReplayed': True, 'sharedObservationsReconciled': True,
    'nativeRecordsCastToLegacyAuthority': False, 'sourceAuthenticityProven': False,
    'globalRecordHostUniverseProven': False, 'completeCanonicalPacket': False,
    'institutionalAcceptance': False, 'releaseAcceptance': False, 'networkFetch': False}
QUALIFICATION = ('All nineteen packet groups survive with exact version-local prior evidence. '
    'Current preservation, WORK/C2PA/condition, recovery and state-export facts are reconstructed '
    'by their concrete source consumers and joined at one observed state. Original selected heads, '
    'histories, record occurrences and qualifications are retained. Current native facts never '
    'authenticate earlier authority or generic assertions. Unknown global host/history denominators, '
    'missing typed cycle/drill semantics, historical authority, institutional acceptance and genuine '
    'release funding/drill obligations remain separate. A replayable export is not complete acquisition acceptance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '10', 'mode': MODE, 'packet': PACKET,
    'priorProfileHash': previous.PROFILE_HASH, 'inputProfileHash': inputs.PROFILE_HASH,
    'observationProfileHash': observations.PROFILE_HASH,
    'consumerProfiles': {'preservation': preservation.PROFILE_HASH,
        'workCondition': work.PROFILE_HASH, 'recoverySustainability': recovery.PROFILE_HASH},
    'requirements': PACKET_REQUIREMENTS, 'changedGroups': CHANGED, 'branches': BRANCHES,
    'retention': 'Every original prior and native input path is preserved beneath prior/ and inputs/.',
    'validation': 'Exact source replay and byte-for-byte full reconstruction; never trust report flags.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _load(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _work_observations(result):
    sources = []
    for index, source in enumerate(result.observations['rpcSources']):
        sources.append({'kind': 'rpc', 'name': 'work-condition/rpc/' + str(index),
            'anchor': source['anchor'],
            'transcript': loads(source['transcriptBytes'], maximum=MAX_BYTES, canonical=True),
            'runtimePins': {row['address']: row['runtimeHash'] for row in source['runtimePins']},
            'provenance': source['provenance']})
    seam = result.observations['nativeSeam']
    sources.append({'kind': 'native', 'name': 'work-condition/native', 'context': seam['context'],
        'calls': seam['getterCalls'], 'events': seam['eventRows'],
        'runtimePins': {row['address']: row['runtimeHash'] for row in seam['runtimePins']},
        'provenance': seam['provenance']})
    return sources


def _preservation_fields(result):
    # These are deterministic outputs of the concrete consumer, not supplied reports.
    return {field: _load(result.files, path) for field, path in (
        ('preservation', preservation.PRESERVATION_PATH), ('scriptDrill', preservation.DRILL_PATH))}


def _derive(prior, preserved, worked, recovered):
    projections = _preservation_fields(preserved)
    projections.update({field: _load(worked.files, 'work-condition/' + name + '.json')
        for field, name in (('tombstone', 'work'), ('c2pa', 'c2pa'), ('conditionReports', 'condition'))})
    r = recovered.report
    projections['recoveryLineage'] = {'governanceActions': r['governanceActions'],
        'recoveries': r['recoveries'], 'historyCoverage': r['historyCoverage']}
    projections['platformSustainability'] = {'stateExports': r['stateExports'],
        'currentStateExport': r['currentStateExport'], 'releaseEvidence': r['sustainability']}
    packet = deepcopy(prior.packet)
    packet['schema'], packet['version'] = PACKET, 10
    for field, current in projections.items():
        packet[field] = {'kind': BRANCHES[field], 'priorEvidence': packet[field], 'current': current}
    require(set(packet) == set(prior.packet), 'canonical V10 original packet key denominator differs')
    for fields in PACKET_REQUIREMENTS.values():
        require(all(field in packet for field in fields), 'canonical V10 missing packet requirement')
    require(all(packet[key] == value for key, value in prior.packet.items()
        if key not in set(CHANGED.values()) | {'schema', 'version'}), 'canonical V10 unrelated group changed')
    return packet


def _compose(packet_files, packet_hash, source_files, source_hash, disclosure):
    require(disclosure == 'public', 'canonical V10 public disclosure required before reads')
    prior = previous.admit(packet_files, packet_hash)
    sources, metadata, condition, condition_hash = inputs.admit(source_files, source_hash)
    envelope = _load(sources, 'preservation/input.json')
    require(type(envelope) is dict and set(envelope) == {'context', 'graph', 'evidence'},
        'canonical V10 closed preservation input')
    preserved = preservation.consume(prior.packet, envelope['evidence'],
        context=envelope['context'], graph=envelope['graph'])
    worked = work.verify(sources['work/evidence.json'], metadata_files=metadata,
        metadata_pins=loads(metadata['pins.json'], maximum=MAX_MANIFEST, canonical=True),
        condition_files=condition, condition_manifest_hash=condition_hash)
    raw = sources['recovery/evidence.json']
    recovered = recovery.validate(raw, keccak256(raw))
    source_observations = prior.observations + preserved.observations + _work_observations(worked) + recovered.observations
    joined = observations.reconcile(prior.reference, source_observations)
    identity = recovered.report['identity']
    require(identity['collectionSerial'] == prior.packet['sourceState']['collectionSerial']
        and identity['burned'] == prior.packet['sourceState']['burned'],
        'canonical V10 recovered token identity differs')
    packet = _derive(prior, preserved, worked, recovered)
    packet_raw = dumps(packet)
    items = deepcopy(prior.report['items'])
    require([row['item'] for row in items] == list(PACKET_REQUIREMENTS),
        'canonical V10 exact nineteen source coverage rows')
    family = {'8': 'preservation', '11': 'preservation', '12': 'work-condition',
        '14': 'work-condition', '15': 'work-condition', '17': 'recovery', '18': 'recovery'}
    for row in items:
        row['priorCoverage'] = deepcopy(row)
        row['evidence'] = ['prior/' + path for path in row.get('evidence', [])]
        if row['item'] in CHANGED:
            row['sourceCoverage'] = 'partial'
            row['evidence'].append(PACKET_PATH)
            row['nativeConsumer'] = family[row['item']]
            row['remaining'] = 'See exact native consumer report and retained prior coverage; source-local history is not global completeness.'
    report = {'profile': NAME, 'version': '10', 'profileHash': PROFILE_HASH,
        'packetSchema': PACKET, 'packetPath': PACKET_PATH, 'packetHash': keccak256(packet_raw),
        'sourceState': prior.reference, 'sourceProvenance': prior.report['sourceProvenance'],
        'originalPacket': {'schema': prior.packet['schema'], 'path': 'prior/' + prior.packet_path,
            'manifestHash': packet_hash, 'profileHash': prior.profile_hash},
        'sourceReconciliation': joined, 'items': items,
        'consumers': {'preservation': preserved.report, 'workCondition': worked.report,
            'recoverySustainability': recovered.report},
        'unresolvedSourceItems': [row['item'] for row in items
            if row['sourceCoverage'] != 'derived_within_source_profile'],
        'canonicalPacketReady': False, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'prior/' + path: raw for path, raw in prior.files}
    files.update({'inputs/' + path: raw for path, raw in sources.items()})
    for prefix, result in (('native-preservation/', preserved), ('native-work-condition/', worked),
            ('native-recovery/', recovered)):
        files.update({prefix + path: raw for path, raw in result.files.items()})
    files.update({PACKET_PATH: packet_raw, 'report.json': dumps(report),
        'source-observations.json': dumps(source_observations),
        'definitions/composition-profile.json': PROFILE_BYTES,
        'definitions/input-profile.json': inputs.PROFILE_BYTES,
        'definitions/observation-profile.json': observations.PROFILE_BYTES})
    package._bounded(files)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '10', 'profileHash': PROFILE_HASH,
        'inputs': {'packet': packet_hash, 'nativeSources': source_hash}, 'disclosure': disclosure,
        'packet': package._ref(PACKET_PATH, packet_raw),
        'files': [package._ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'canonical V10 manifest bound')
    files['manifest.json'] = manifest
    package._bounded(files)
    return package.Assembly(tuple(sorted(files.items())), manifest, report)


def compose(packet_files, packet_hash, source_files, source_hash, *, disclosure):
    try:
        return _compose(packet_files, packet_hash, source_files, source_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical V10 source input') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'canonical V10 external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'inputs', 'disclosure', 'packet', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME and manifest['version'] == '10'
            and manifest['profileHash'] == PROFILE_HASH and manifest['claims'] == CLAIMS
            and manifest['qualification'] == QUALIFICATION and type(manifest['inputs']) is dict
            and set(manifest['inputs']) == {'packet', 'nativeSources'}, 'canonical V10 closed manifest differs')
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'canonical V10 file commitments differ')
        original = {path.removeprefix('prior/'): body for path, body in files.items() if path.startswith('prior/')}
        native = {path.removeprefix('inputs/'): body for path, body in files.items() if path.startswith('inputs/')}
        result = compose(original, manifest['inputs']['packet'], native, manifest['inputs']['nativeSources'],
            disclosure=manifest['disclosure'])
        require(dict(result.files) == files, 'canonical V10 full reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical V10 package') from exc


def export_packet(files, expected_hash):
    return dict(verify(files, expected_hash).files)[PACKET_PATH]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError('complete canonical packet unavailable; unresolved items: '
        + ', '.join(result.report['unresolvedSourceItems']))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    build = commands.add_parser('assemble')
    for role in ('packet', 'sources'):
        build.add_argument('--' + role, type=Path, required=True)
        build.add_argument('--' + role + '-hash', required=True)
    build.add_argument('--disclosure', required=True)
    build.add_argument('--output', type=Path, required=True)
    for name in ('verify', 'export-packet', 'complete-packet'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            message = {'profileHash': PROFILE_HASH, 'packetSchema': PACKET}
        elif args.command == 'assemble':
            require(args.disclosure == 'public', 'canonical V10 public disclosure required before reads')
            from .repository_exchange import _destination, _publish
            _destination(args.output, [args.packet, args.sources])
            result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.sources),
                args.sources_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.packet, args.sources])
            message = {'manifestHash': result.manifest_hash, 'packetHash': result.report['packetHash']}
        elif args.command == 'export-packet':
            sys.stdout.buffer.write(export_packet(read_tree(args.directory), args.manifest_hash) + b'\n')
            return
        else:
            function = complete_packet if args.command == 'complete-packet' else verify
            result = function(read_tree(args.directory), args.manifest_hash)
            message = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(message).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
