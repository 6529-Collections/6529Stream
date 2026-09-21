"""Versioned object dossier retaining native V10 packets and conservation V2.

The fixed forty-nine requirements remain the acceptance denominator. A native
packet and a conservation family are concrete inputs, not a complete inventory
of every protocol host, packaging obligation or institutional acceptance act.
"""
import argparse
from pathlib import Path

from . import acquisition_canonical_v10 as acquisition
from . import conservation_dossier_v2 as conservation
from . import conservation_archive_v1 as archive
from . import canonical_composition_observations_v1 as observations
from . import canonical_packet_inputs_v1 as prior_inputs
from . import object_dossier as package
from . import object_dossier_inventory as inventory
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_OBJECT_DOSSIER_V3'
MODE = 'canonical_object_dossier_v3_assembly'
DOSSIER_PATH = 'dossier/object-dossier-v3.json'
CLAIMS = {'nativePacketReplayed': True, 'allNineteenPacketGroupsRetained': True,
    'allFortyNineRequirementsRetained': True, 'originalInputBytesRetained': True,
    'duplicateSourceOccurrencesRetained': True, 'completeCanonicalDossier': False,
    'globalHostInventoryProven': False, 'globalProtocolEventArchiveProven': False,
    'toolArchiveManifestPinProven': False, 'zeroOperatorRegenerationProven': False,
    'institutionalAcceptance': False, 'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('Additive object dossier V3 admits an exact native packet V10 through its concrete '
    'source replayers and optionally an exact conservation V2 documentary/semantic family. Original '
    'packet versions, native branches and source occurrences remain intact; none is converted to V1 '
    'record authority. The forty-nine adopted requirements remain visible. Source-family replay does '
    'not establish a global record/host/event inventory, all render bytes, registered packaging, '
    'preserved release tooling, zero-operator regeneration or named institutional acceptance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '3', 'mode': MODE,
    'packetProfileHash': acquisition.PROFILE_HASH, 'conservationProfileHash': conservation.PROFILE_HASH,
    'requirementInventoryHash': inventory.REQUIREMENTS_HASH, 'observationProfileHash': observations.PROFILE_HASH,
    'retention': 'Exact packet package below acquisition/; exact conservation package below conservation/.',
    'sourceOccurrences': 'Every original source query log, receipt log and native event occurrence retains its source and index. Equal events from different sources are not discarded.',
    'validation': 'Concrete source replay followed by full deterministic reconstruction.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _load(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _conservation_sources(files, provenance):
    prefix = 'source/input/source/'
    anchor = _load(files, prefix + 'anchor.json')
    transcript = _load(files, prefix + 'transcript.json')
    sources = [{'kind': 'rpc', 'name': 'conservation-v2/original', 'anchor': anchor,
        'transcript': transcript, 'runtimePins': prior_inputs._pins(anchor, transcript),
        'provenance': provenance}]
    # The frozen V2 package also has independently verified native Archive
    # observations. Reconstruct its concrete original preimages to recover the
    # actual pinned host/carrier set; do not scrape historical hash fields.
    originals = {path.removeprefix('source/'): raw for path, raw in files.items() if path.startswith('source/')}
    snapshot, dossier, refs, original_transcript = archive._load(originals)
    materials = _load(files, 'materials/input.json')
    native = archive._Originals(snapshot, original_transcript, materials['graph'])
    for row, occurrence in zip(materials['occurrences'], refs):
        proof = row['archive']
        if proof is None:
            continue
        raw = files['materials/data/' + row['materialPath']]
        artists, form, original = archive._reference_context(dossier, occurrence)
        original = original if occurrence['relation'] == 'interview_payload' else None
        canon = occurrence['hash']['canonicalizationId']
        if proof['backend'] == 'external':
            archive._external(proof, raw, canon, artists, form, original, native, materials['graph'])
        else:
            archive._onchain(proof, raw, canon, artists, native, materials['graph'], original)
    require(native.calls == materials['sourceBindings']['calls'],
        'object dossier V3 complete Archive observations differ')
    sources.append({'kind': 'native', 'name': 'conservation-v2/archive',
        'context': materials['context'], 'calls': native.calls, 'events': [],
        'runtimePins': native.pins, 'provenance': materials['sourceBindings']['provenance']})
    return sources


def _event_occurrences(sources):
    result = []
    for source in sources:
        if source['kind'] == 'native':
            for index, event in enumerate(source['events']):
                result.append({'source': source['name'], 'sourceKind': 'native',
                    'pointer': '/events/' + str(index), 'event': event['log'],
                    'timestamp': event['timestamp']})
            continue
        for index, row in enumerate(source['transcript']['calls']):
            if row['method'] == 'eth_getLogs' and 'result' in row:
                found, suffix = row['result'], '/result/'
            elif row['method'] == 'eth_getTransactionReceipt' and row.get('result') is not None:
                found, suffix = row['result']['logs'], '/result/logs/'
            else:
                continue
            for offset, event in enumerate(found):
                result.append({'source': source['name'], 'sourceKind': 'rpc',
                    'pointer': '/transcript/calls/' + str(index) + suffix + str(offset),
                    'event': event, 'timestamp': None})
    return result


def _assessment(packet, packet_raw, conservation_files):
    ref = inventory.EvidenceRef('acquisition/' + acquisition.PACKET_PATH,
        keccak256(packet_raw), '/sourceState')
    verified = {'identity': (ref,)}
    # Supplied hashes identify retained evidence for the wider requirement.
    # Successful bounded family verification is not promoted to global coverage.
    fields = {
        'OD-FINALITY-STATUS': 'finality', 'OD-CONTENT-ROOT-PROOF': 'contentRootProof',
        'OD-ENTROPY-PROVENANCE': 'entropy', 'OD-C2PA': 'c2pa',
        'OD-TOMBSTONE': 'tombstone', 'OD-SCRIPT-DRILL': 'scriptDrill',
        'OD-ATTRIBUTION': 'attribution', 'OD-TRANSFER-PROVENANCE': 'ownershipProvenance',
        'OD-TOKEN-LANE-HEADS': 'recordChainHeads', 'OD-OWNER-LANE-HEADS': 'recordChainHeads',
        'OD-INDEPENDENT-LANE-HEADS': 'recordChainHeads',
        'OD-RIGHTS-COLLECTION': 'rights', 'OD-RIGHTS-TOKEN': 'rights',
        'OD-RENDER-INVENTORY': 'preservation',
    }
    known = {row['code'] for row in inventory.REQUIREMENTS}
    require(set(fields) <= known, 'object dossier V3 requirement mapping differs')
    supplied = {code: (keccak256(dumps(packet[field])),) for code, field in fields.items()}
    if conservation_files is not None:
        digest = keccak256(conservation_files['manifest.json'])
        for code in ('OD-ARTIST-INTENT-OR-WAIVER', 'OD-INTERVIEW', 'SEM-EXPANDED-PACKAGE',
                'SEM-SOURCE-STATE', 'SEM-OFFLINE-DEPENDENCY-CLOSURE'):
            supplied[code] = (digest,)
    # Prior workClass is retained, but generic packet labels do not prove native
    # applicability. An unknown mode keeps conditional requirements unresolved.
    return inventory.assess('unknown', verified, supplied)


def _compose(packet_files, packet_hash, conservation_files, conservation_hash, disclosure):
    require(disclosure == 'public', 'object dossier V3 public disclosure required before reads')
    checked = acquisition.verify(packet_files, packet_hash)
    original = dict(checked.files)
    packet_raw = original[acquisition.PACKET_PATH]
    packet = _load(original, acquisition.PACKET_PATH)
    source_rows = _load(original, 'source-observations.json')
    conservation_result, conserved = None, None
    require((conservation_files is None) == (conservation_hash is None),
        'object dossier V3 conservation presence/pin differs')
    if conservation_files is not None:
        conservation_result = conservation.verify(dict(conservation_files), conservation_hash)
        conserved = dict(conservation_result.files)
        source_rows += _conservation_sources(conserved, conservation_result.report['sourceProvenance'])
        state = conservation_result.report['sourceState']
        require(all(value == checked.report['sourceState'][key] for key, value in state.items()
            if key in checked.report['sourceState']), 'object dossier V3 conservation source state differs')
    joined = observations.reconcile(checked.report['sourceState'], source_rows)
    assessment = _assessment(packet, packet_raw, conserved)
    require(assessment['counts']['total'] == 49 and len(assessment['results']) == 49,
        'object dossier V3 exact forty-nine requirement denominator')
    event_rows = _event_occurrences(source_rows)
    work_refs = _load(original, 'native-work-condition/work-condition/reference-occurrences.json')
    reference_rows = [{'source': 'native-work-condition', 'index': str(index), 'occurrence': row}
        for index, row in enumerate(work_refs)]
    if conserved is not None:
        conservation_refs = _load(conserved, 'source/conservation/reference-occurrences.json')['occurrences']
        reference_rows += [{'source': 'conservation-v2', 'index': str(index), 'occurrence': row}
            for index, row in enumerate(conservation_refs)]
    dossier = {'schema': NAME, 'version': 3, 'sourceState': checked.report['sourceState'],
        'citation': packet['citation'], 'subjectId': packet['subjectId'], 'acquisitionPacket': packet,
        'nativeFamilies': {field: packet[field]['current'] for field in acquisition.CHANGED.values()},
        'originalRecordChainHeads': packet['recordChainHeads'],
        'conservationFamily': None if conserved is None else _load(conserved, 'source/conservation/dossier.json'),
        'requirementAssessment': package._ref('dossier/requirements.json', dumps(assessment)),
        'referenceOccurrences': package._ref('dossier/reference-occurrences.json', dumps(reference_rows)),
        'eventOccurrences': package._ref('dossier/event-occurrences.json', dumps(event_rows)),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    report = {'profile': NAME, 'version': '3', 'profileHash': PROFILE_HASH,
        'sourceState': checked.report['sourceState'], 'packetManifestHash': packet_hash,
        'conservationManifestHash': conservation_hash, 'sourceReconciliation': joined,
        'packetRequirements': checked.report['items'], 'dossierRequirements': assessment,
        'conservationReport': None if conservation_result is None else conservation_result.report,
        'eventOccurrenceCount': str(len(event_rows)), 'referenceOccurrenceCount': str(len(reference_rows)),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'acquisition/' + path: raw for path, raw in original.items()}
    if conserved is not None:
        files.update({'conservation/' + path: raw for path, raw in conserved.items()})
    files.update({DOSSIER_PATH: dumps(dossier), 'dossier/requirements.json': dumps(assessment),
        'dossier/event-occurrences.json': dumps(event_rows), 'dossier/reference-occurrences.json': dumps(reference_rows),
        'definitions/dossier-profile.json': PROFILE_BYTES, 'definitions/requirements.json': inventory.REQUIREMENTS_BYTES,
        'report.json': dumps(report)})
    package._bounded(files)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '3', 'profileHash': PROFILE_HASH,
        'inputs': {'packet': packet_hash, 'conservation': conservation_hash}, 'disclosure': disclosure,
        'files': [package._ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'object dossier V3 manifest bound')
    files['manifest.json'] = manifest
    package._bounded(files)
    return package.Assembly(tuple(sorted(files.items())), manifest, report)


def compose(packet_files, packet_hash, *, conservation_files=None, conservation_hash=None, disclosure):
    try:
        return _compose(packet_files, packet_hash, conservation_files, conservation_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed object dossier V3 inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'object dossier V3 external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version', 'profileHash',
            'inputs', 'disclosure', 'files', 'claims', 'qualification'} and manifest['mode'] == MODE
            and manifest['profile'] == NAME and manifest['version'] == '3' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION
            and type(manifest['inputs']) is dict and set(manifest['inputs']) == {'packet', 'conservation'},
            'object dossier V3 closed manifest differs')
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'object dossier V3 file commitments differ')
        original = {p.removeprefix('acquisition/'): b for p, b in files.items() if p.startswith('acquisition/')}
        conserved = {p.removeprefix('conservation/'): b for p, b in files.items() if p.startswith('conservation/')}
        result = compose(original, manifest['inputs']['packet'], conservation_files=conserved or None,
            conservation_hash=manifest['inputs']['conservation'], disclosure=manifest['disclosure'])
        require(dict(result.files) == files, 'object dossier V3 full reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed object dossier V3 package') from exc


def complete(files, expected_hash):
    result = verify(files, expected_hash)
    missing = [r['code'] for r in result.report['dossierRequirements']['results'] if r['state'] != 'verified']
    raise MuseumError('complete canonical dossier unavailable; unresolved requirements: ' + ', '.join(missing))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    build = commands.add_parser('assemble')
    build.add_argument('--packet', type=Path, required=True)
    build.add_argument('--packet-hash', required=True)
    build.add_argument('--conservation', type=Path)
    build.add_argument('--conservation-hash')
    build.add_argument('--disclosure', required=True)
    build.add_argument('--output', type=Path, required=True)
    for name in ('verify', 'complete'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            message = {'profileHash': PROFILE_HASH, 'requirementsHash': inventory.REQUIREMENTS_HASH}
        elif args.command == 'assemble':
            require(args.disclosure == 'public', 'object dossier V3 public disclosure required before reads')
            from .repository_exchange import _destination, _publish
            sources = [args.packet] + ([args.conservation] if args.conservation is not None else [])
            _destination(args.output, sources)
            result = compose(read_tree(args.packet), args.packet_hash,
                conservation_files=read_tree(args.conservation) if args.conservation else None,
                conservation_hash=args.conservation_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
            message = {'manifestHash': result.manifest_hash, 'requirements': result.report['dossierRequirements']['counts']}
        else:
            result = (complete if args.command == 'complete' else verify)(read_tree(args.directory), args.manifest_hash)
            message = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(message).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
