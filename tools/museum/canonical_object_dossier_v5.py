"""Retain exact Artist and General review packets beside unchanged unified V4."""
import argparse
from pathlib import Path

from . import canonical_dossier_observations_v4 as observations
from . import canonical_object_dossier_v4 as previous
from . import general_review_selection as general_review
from . import native_artist_review_dossier_v1 as artist_review
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_OBJECT_DOSSIER_V5'
MODE = 'canonical_object_dossier_v5_review_assembly'
PREFIXES = {'base': 'v4/', 'artist': 'artist-review/', 'general': 'general-review/'}
JOIN_PATH = 'dossier/review-joins.json'
REPORT_PATH = 'report.json'
CLAIMS = {
    'originalV4BytesAndNineteenFortyNineDenominatorRetained': True,
    'completeSuppliedReviewPacketsReplayed': True,
    'allSelectedAndWithheldReviewOccurrencesReferenced': True,
    'sameAnchorPositiveSourceContradictionsRejected': True,
    'distinctSourceStatesReported': True,
    'crossFamilyReviewerAuthorityGranted': False,
    'resourceIdentityMergedAcrossFamilies': False,
    'reviewPromotesDossierRequirement': False,
    'sourceOriginAuthenticated': False,
    'humanIndependenceProven': False,
    'institutionalStandingOrAcceptanceProven': False,
    'legalTitleOrCurrentCustodyProven': False,
    'completeCanonicalDossier': False,
    'profileRegistered': False,
    'networkFetch': False,
}
QUALIFICATION = (
    'V4 is verified and retained byte-for-byte as the sole original nineteen/forty-nine '
    'requirement denominator. Optional native Artist and General review packets are '
    'independently replayed and retained as distinct source families. Exact native '
    'occurrence selectors and original anchor subjects describe documentary links; '
    'same collection or entity text never proves token applicability, a shared '
    'person, independent reviewer, institutional standing, ownership, custody or '
    'physical performance. Different captures remain unjoined; positive original '
    'observations at the same source state must agree. Review packets never alter '
    'V4 selection, graphs or requirement decisions.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '5', 'mode': MODE,
    'baseProfileHash': previous.PROFILE_HASH,
    'artistReviewProfileHash': artist_review.PROFILE_HASH,
    'generalReviewSelectionProfile': general_review.NAME,
    'prefixes': PREFIXES,
    'retention': 'One complete verified V4 package and each complete supplied review '
        'packet, with original native snapshots, transcripts, diagnostics, selections '
        'and graph resources retained under distinct prefixes.',
    'joins': 'Version-local exact original selector, revision/profile, anchor subject '
        'and source-state classifications; no cross-family reviewer policy.',
    'verification': 'Replay all children, reconcile original observations, rebuild '
        'the join report and compare every wrapper file byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'object dossier V5 public disclosure required before reads')


def _paired(files, digest, name):
    require((files is None) == (digest is None),
        'object dossier V5 ' + name + ' files and pin required together')


def _bundle_hash(files):
    """External pin for General's closed replay bundle without a child manifest."""
    package._bounded(files)
    return keccak256(dumps([package._ref(path, raw) for path, raw in sorted(files.items())]))


def _subtree(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}


def _v4_sources(files):
    base = _subtree(files, previous.PREFIXES['canonical'])
    production = _subtree(files, previous.PREFIXES['production'])
    general = _subtree(files, previous.PREFIXES['general'])
    transfer = _subtree(files, previous.PREFIXES['transfer'])
    return observations.sources(base, production_files=production or None,
        general_files=general or None, transfer_files=transfer or None)


def _review_observations(artist, general):
    result = []
    if artist is not None:
        anchor = loads(artist['sources/metadata/anchor.json'], maximum=MAX_BYTES, canonical=True)
        config = observations._configuration(anchor)
        for name, path in (('metadata', 'sources/metadata/transcript.json'),
                           ('artist', 'sources/artist/transcript.json'),
                           ('semantics', 'semantics/transcript.json')):
            result.append(observations._rpc(artist, 'artist-review/' + name,
                'sources/metadata/anchor.json', path,
                loads(artist['manifest.json'], maximum=MAX_MANIFEST)['provenance'], config))
    if general is not None:
        anchor = loads(general['anchor.json'], maximum=MAX_BYTES, canonical=True)
        config = {key: anchor[key] for key in observations.CONFIGURATION}
        for name, path in (('general', 'general-transcript.json'),
                           ('publication', 'publication-transcript.json'),
                           ('semantics', 'semantic-transcript.json')):
            result.append(observations._rpc(general, 'general-review/' + name,
                'anchor.json', path, loads(general['semantic-source.json'], maximum=MAX_BYTES)['provenance'], config))
    return result


def _review_rows(artist, general):
    rows = []
    if artist is not None:
        source = loads(artist['semantics/snapshot.json'], maximum=MAX_BYTES, canonical=True)
        selected = loads(artist['graph/selection.json'], maximum=MAX_BYTES, canonical=True)
        anchor_raw = artist['sources/metadata/anchor.json']
        anchor = loads(anchor_raw, maximum=MAX_BYTES, canonical=True)
        require(source['anchorHash'] == keccak256(anchor_raw)
            and source['sourceScope'] == {key: anchor[key] for key in
                ('chainId', 'core', 'collectionId', 'artistRegistry', 'host')}
            and all(source['sourceState'][key] == anchor[key]
                for key in ('chainId', 'core', 'collectionId', 'blockHash')),
            'object dossier V5 Artist anchor/source state differs')
        originals = {dumps(row['source'] | {'pointer': entry['pointer']}):
            (row, index) for row in source['statements']
            for index, entry in enumerate(row['assertionInterpretations']) if entry['status'] == 'supported'}
        for disposition in ('selected', 'withheld'):
            for claim in selected[disposition]:
                reference = claim['source']; key = dumps(reference)
                require(key in originals, 'object dossier V5 Artist selected occurrence unavailable')
                original, index = originals[key]
                assertion = original['value']['assertions'][index]
                require(assertion == claim['assertion']
                    and claim['nativeAuthority'] == original['nativeAuthority']
                    and source['interpretationProfileHash'] == original['value']['profileHash']
                    and reference['subjectId'] == original['value']['anchorSubject']['subjectId'],
                    'object dossier V5 Artist original revision/profile/subject differs')
                rows.append({'family': 'artist', 'disposition': disposition, 'source': reference,
                    'revisionHash': keccak256(dumps(assertion)),
                    'profileHash': original['value']['profileHash'],
                    'anchorSubject': original['value']['anchorSubject'],
                    'sourceState': {key: anchor[key] for key in ('chainId', 'core', 'collectionId', 'blockHash')},
                    'reviewCount': str(len(claim['reviews']))})
    if general is not None:
        source = loads(general['semantic-source.json'], maximum=MAX_BYTES, canonical=True)
        selected = loads(general['selection-result.json'], maximum=MAX_BYTES, canonical=True)
        anchor_raw = general['anchor.json']
        anchor = loads(anchor_raw, maximum=MAX_BYTES, canonical=True)
        require(source['anchorHash'] == keccak256(anchor_raw)
            and all(source['sourceState'][key] == anchor[key]
                for key in ('chainId', 'core', 'collectionId', 'blockHash')),
            'object dossier V5 General anchor/source state differs')
        originals = {dumps(row['source'] | {'pointer': '/assertions/' + str(index)}):
            (row, index) for row in source['statements'] if row['status'] == 'supported'
            for index in range(len(row['value']['assertions']))
            if index not in row['ineligibleAssertionIndices']}
        for disposition in ('selected', 'withheld'):
            for claim in selected[disposition]:
                reference = claim['source']; key = dumps(reference)
                require(key in originals, 'object dossier V5 General selected occurrence unavailable')
                original, index = originals[key]
                assertion = original['value']['assertions'][index]
                require(assertion == claim['assertion']
                    and claim['originalProfileHash'] == original['value']['profileHash']
                        == source['interpretationProfileHash']
                    and claim['anchorSubject'] == original['value']['anchorSubject']
                    and reference['subjectId'] == original['value']['anchorSubject']['subjectId'],
                    'object dossier V5 General original revision/profile/subject differs')
                rows.append({'family': 'general', 'disposition': disposition, 'source': reference,
                    'revisionHash': keccak256(dumps(assertion)),
                    'profileHash': original['value']['profileHash'],
                    'anchorSubject': original['value']['anchorSubject'],
                    'sourceState': {key: anchor[key] for key in ('chainId', 'core', 'collectionId', 'blockHash')},
                    'reviewCount': str(len(claim['qualifyingReviews']))})
    return sorted(rows, key=lambda row: (row['family'], dumps(row['source'])))


def _links(v4_files, rows):
    supplemental = loads(v4_files[previous.SUPPLEMENTAL_PATH], maximum=MAX_BYTES, canonical=True)
    subjects = supplemental['subjects']
    families = {row['role']: row for row in supplemental['families'] if row['status'] == 'retained'}
    links = []
    for row in rows:
        roles = ('production',) if row['family'] == 'artist' else ('general', 'transfer')
        candidates = []
        for subject in subjects:
            role = subject['family']
            if role not in roles: continue
            family = families.get(role)
            if family is None: continue
            state = family['sourceState']; review_state = row['sourceState']
            same_scope = all(state[key] == review_state[key]
                for key in ('chainId', 'core', 'collectionId'))
            same_subject = subject['anchorSubject'] == row['anchorSubject']
            if not same_scope or not same_subject: continue
            same_state = state['blockHash'] == review_state['blockHash']
            exact_occurrence = same_state and subject['source'] == row['source']
            candidates.append({'role': role, 'source': subject['source'],
                'sourceStateEqual': same_state, 'exactOccurrence': exact_occurrence,
                'selectionDisposition': subject['selectionDisposition'],
                'documentarySubjectMatch': True,
                'tokenAuthorityEstablished': False})
        status = ('exact_original_occurrence' if any(x['exactOccurrence'] for x in candidates) else
            'same_subject_and_source_state_distinct_occurrence' if any(x['sourceStateEqual'] for x in candidates) else
            'same_documentary_subject_different_source_state' if candidates else 'unjoined')
        links.append({'reviewFamily': row['family'], 'disposition': row['disposition'],
            'source': row['source'], 'assertionRevisionHash': row['revisionHash'],
            'profileHash': row['profileHash'], 'anchorSubject': row['anchorSubject'],
            'sourceState': row['sourceState'], 'status': status,
            'v4Candidates': candidates, 'crossFamilyReviewerAuthority': False,
            'tokenAuthorityEstablished': False})
    return links


def _compose(v4_files, v4_hash, artist_files, artist_hash, general_files,
             general_hash, general_policy_hash, general_provenance, disclosure):
    _public(disclosure)
    _paired(artist_files, artist_hash, 'Artist')
    _paired(general_files, general_hash, 'General')
    require((general_files is None) == (general_policy_hash is None)
        and (general_files is None) == (general_provenance is None),
        'object dossier V5 General policy/provenance pins required together')
    base = previous.verify(dict(v4_files), v4_hash)
    artist = None if artist_files is None else artist_review.verify(dict(artist_files), artist_hash)
    if general_files is not None:
        require(any(hex_bytes(general_hash, 32)) and _bundle_hash(general_files) == general_hash,
            'object dossier V5 General external packet pin differs')
        require(any(hex_bytes(general_policy_hash, 32))
            and keccak256(general_files['selection.json']) == general_policy_hash,
            'object dossier V5 General external policy pin differs')
        require(general_provenance in ('synthetic_fixture', 'trusted_rpc'),
            'object dossier V5 General source provenance required')
        general_review.replay(dict(general_files), general_policy_hash,
            provenance=general_provenance, disclosure=disclosure)
    base_files, artist_data = dict(base.files), None if artist is None else dict(artist.files)
    reconciled = observations.reconcile(base.report['sourceState'],
        _v4_sources(base_files) + _review_observations(artist_data, general_files))
    occurrences = _review_rows(artist_data, general_files)
    links = _links(base_files, occurrences)
    output = {PREFIXES['base'] + path: raw for path, raw in base_files.items()}
    if artist_data is not None:
        output.update({PREFIXES['artist'] + path: raw for path, raw in artist_data.items()})
    if general_files is not None:
        output.update({PREFIXES['general'] + path: raw for path, raw in general_files.items()})
    join = {'profile': NAME, 'version': '5', 'v4ManifestHash': v4_hash,
        'artistManifestHash': artist_hash, 'generalPacketHash': general_hash,
        'generalPolicyHash': general_policy_hash,
        'sourceReconciliation': reconciled, 'occurrences': occurrences,
        'links': links, 'requirementPromotions': [], 'crossFamilyGraphMerge': False,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[JOIN_PATH] = dumps(join)
    output['definitions/profile.json'] = PROFILE_BYTES
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'version': '5',
        'v4ManifestHash': v4_hash, 'v4PacketRequirementCount': base.report['packetRequirementCount'],
        'v4DossierRequirementCount': base.report['dossierRequirementCount'],
        'artistReviewPresent': artist is not None, 'generalReviewPresent': general_files is not None,
        'selectedArtistAssertionCount': str(sum(row['family'] == 'artist' and row['disposition'] == 'selected'
            for row in occurrences)),
        'selectedGeneralAssertionCount': str(sum(row['family'] == 'general' and row['disposition'] == 'selected'
            for row in occurrences)),
        'requirementPromotions': [], 'claims': CLAIMS, 'qualification': QUALIFICATION}
    output[REPORT_PATH] = dumps(report)
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '5',
        'profileHash': PROFILE_HASH, 'inputs': {'v4': v4_hash, 'artist': artist_hash,
            'general': general_hash, 'generalPolicy': general_policy_hash,
            'generalProvenance': general_provenance}, 'disclosure': disclosure,
        'joins': package._ref(JOIN_PATH, output[JOIN_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'object dossier V5 manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(v4_files, v4_hash, *, artist_files=None, artist_hash=None,
            general_review_files=None, general_review_hash=None,
            general_review_policy_hash=None, general_review_provenance=None,
            disclosure):
    try:
        return _compose(v4_files, v4_hash, artist_files, artist_hash,
            general_review_files, general_review_hash, general_review_policy_hash,
            general_review_provenance, disclosure)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed object dossier V5 inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'object dossier V5 external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'inputs', 'disclosure', 'joins', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '5' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION
            and type(manifest['inputs']) is dict and set(manifest['inputs']) == {
                'v4', 'artist', 'general', 'generalPolicy', 'generalProvenance'},
            'object dossier V5 closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'object dossier V5 file commitments differ')
        children = {role: _subtree(files, prefix) for role, prefix in PREFIXES.items()}
        require(bool(children['artist']) == (manifest['inputs']['artist'] is not None)
            and bool(children['general']) == (manifest['inputs']['general'] is not None),
            'object dossier V5 child presence differs')
        rebuilt = compose(children['base'], manifest['inputs']['v4'],
            artist_files=children['artist'] or None, artist_hash=manifest['inputs']['artist'],
            general_review_files=children['general'] or None,
            general_review_hash=manifest['inputs']['general'],
            general_review_policy_hash=manifest['inputs']['generalPolicy'],
            general_review_provenance=manifest['inputs']['generalProvenance'],
            disclosure=manifest['disclosure'])
        require(dict(rebuilt.files) == files, 'object dossier V5 full reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed object dossier V5 package') from exc


def complete(files, expected_hash):
    verify(files, expected_hash)
    raise MuseumError('complete canonical dossier unavailable; V4 original requirements remain unresolved')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('assemble')
    create.add_argument('--v4', type=Path, required=True)
    create.add_argument('--v4-hash', required=True)
    create.add_argument('--artist', type=Path)
    create.add_argument('--artist-hash')
    create.add_argument('--general-review', type=Path)
    create.add_argument('--general-review-hash')
    create.add_argument('--general-review-policy-hash')
    create.add_argument('--general-review-provenance')
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    for name in ('verify', 'complete'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            answer = {'profileHash': PROFILE_HASH, 'v4ProfileHash': previous.PROFILE_HASH,
                'artistReviewProfileHash': artist_review.PROFILE_HASH}
        elif args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            sources = [args.v4]
            for role in ('artist', 'general_review'):
                path = getattr(args, role)
                _paired(path, getattr(args, role + '_hash'), role)
                if path is not None: sources.append(path)
            _destination(args.output, sources)
            built = compose(read_tree(args.v4), args.v4_hash,
                artist_files=None if args.artist is None else read_tree(args.artist),
                artist_hash=args.artist_hash,
                general_review_files=None if args.general_review is None else read_tree(args.general_review),
                general_review_hash=args.general_review_hash,
                general_review_policy_hash=args.general_review_policy_hash,
                general_review_provenance=args.general_review_provenance,
                disclosure=args.disclosure)
            _publish(dict(built.files), args.output, sources)
            answer = {'manifestHash': built.manifest_hash, 'report': built.report}
        else:
            built = verify(read_tree(args.directory), args.manifest_hash) if args.command == 'verify' else (
                complete(read_tree(args.directory), args.manifest_hash))
            answer = {'manifestHash': built.manifest_hash, 'report': built.report}
        print(dumps(answer).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'object dossier V5: ' + str(exc) + '\n')


if __name__ == '__main__': main()
