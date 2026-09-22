"""Retain one exact source package with a reproducible field correspondence ledger.

Canonical native inventories and recorded-account format packages have distinct
admission routes. They are never joined by labels, IRIs or shared chain context.
"""
import argparse
from pathlib import Path

from . import canonical_field_inventory_v1 as native
from . import same_source_format_ledger_v1 as formats
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_SEMANTIC_FIELD_CORRESPONDENCE_V1'
MODE = 'semantic_field_correspondence_v1'
ROUTES = ('canonical_v4', 'account_formats_v2')
INVENTORY_PATH = 'conformance/source-field-inventory.json'
LEDGER_PATH = 'conformance/format-field-ledger.json'
IDENTITIES_PATH = 'conformance/shared-identity.json'
COMPARISONS_PATH = 'conformance/cross-format-comparisons.json'
ADAPTER_REPORT_PATH = 'conformance/adapter-report.json'
FORMAT_NAMES = ('linked-art', 'premis', 'iiif', 'lido')
CLAIMS = {'originalSourcePackageReplayed': True, 'originalSourceBytesRetained': True,
    'sourceInventoryPrecedesSelection': True, 'formatMappingsRequireLocalTargetEvidence': True,
    'differentSourcePackagesJoined': False, 'originalRequirementsPromoted': False,
    'fullMuseumScope': False, 'completeSemanticMappingProven': False,
    'sourceOriginAuthenticated': False, 'currentAuthorityProven': False,
    'institutionalAcceptance': False, 'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('One externally pinned original source package and its declared public scope. '
    'Canonical V4 inventory and original account four-format correspondence are separate routes. '
    'Native fields without a format adapter remain retained with unsupported applicability. '
    'Account format cells require their own provenance and actual target values; inherited '
    'coverage labels are not mapping evidence. Original records, authority, selection and '
    'environment remain unchanged. Exact source correspondence does not establish source '
    'origin, current authority, institutional acceptance or complete Museum mapping.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'routes': ROUTES, 'nativeInventoryProfileHash': native.PROFILE_HASH,
    'formatLedgerProfileHash': formats.PROFILE_HASH,
    'sourceDirectory': 'source/', 'referencePaths': 'package_relative',
    'retention': 'One complete original package, including its original manifest and dependencies.',
    'verification': 'Concrete source replay, recomputed denominator and local mappings, exact full-file reconstruction.',
    'limits': {'packageBytes': MAX_BYTES, 'manifestBytes': MAX_MANIFEST},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'field correspondence requires public disclosure before reads')


def _canonical_outputs(evidence):
    inventory = loads(evidence.inventory, maximum=MAX_BYTES, canonical=True)
    reference = package._ref(INVENTORY_PATH, evidence.inventory)
    # This envelope has no native-to-four-format adapter. Retention is not a
    # claim of format mapping or semantic irrelevance. The complete native
    # graph package remains inspectable in its original source directory.
    fields = inventory['fields']
    ledger = {'sourceFieldInventory': reference,
        'status': 'unsupported_native_four_format_adapter',
        'fields': [{'sourceFieldPointer': '/fields/' + str(index),
            'disposition': ('not_applicable' if field['presence'] == 'absent'
                else 'retained_stream_only'),
            'rule': ('urn:6529stream:museum:field-correspondence:absent-optional'
                if field['presence'] == 'absent' else
                'urn:6529stream:museum:field-correspondence:unsupported-native-format'),
            'formats': {name: {'status': 'unsupported_source_adapter', 'targets': []}
                for name in FORMAT_NAMES},
            'reason': ('The applicable optional source field is absent.' if field['presence'] == 'absent'
                else 'Original source retained; this route supplies no four-format mapping.')}
            for index, field in enumerate(fields)]}
    identities = {'sourceFieldInventory': reference,
        'status': 'unsupported_native_four_format_adapter', 'relationships': [],
        'reason': 'Original native occurrence selectors remain in the inventory; no format identities are inferred.'}
    comparisons = {'sourceFieldInventory': reference, 'comparisons': [],
        'status': 'unsupported_native_four_format_adapter',
        'reason': 'No native four-format outputs are admitted by this profile; no comparison is reported as passing.'}
    return evidence.inventory, dumps(ledger), dumps(identities), dumps(comparisons)


def _compose(source_files, source_hash, source_kind, disclosure):
    _public(disclosure)
    require(source_kind in ROUTES, 'field correspondence explicit supported source kind required')
    original = dict(source_files)
    package._bounded(original)
    require('manifest.json' in original and any(hex_bytes(source_hash, 32))
        and keccak256(original['manifest.json']) == source_hash,
        'field correspondence original manifest pin differs')
    adapter = native if source_kind == 'canonical_v4' else formats
    evidence = adapter.build(original, source_hash, disclosure=disclosure)
    artifacts = (_canonical_outputs(evidence) if source_kind == 'canonical_v4' else
        (evidence.inventory, evidence.ledger, evidence.identities, evidence.comparisons))
    output = {'source/' + path: raw for path, raw in original.items()}
    for path, raw in zip((INVENTORY_PATH, LEDGER_PATH, IDENTITIES_PATH, COMPARISONS_PATH), artifacts):
        output[path] = raw
    output[ADAPTER_REPORT_PATH] = dumps(evidence.report)
    output['definitions/profile.json'] = PROFILE_BYTES
    output['definitions/adapter-profile.json'] = adapter.PROFILE_BYTES
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceKind': source_kind,
        'sourceManifestHash': source_hash, 'sourceDirectory': 'source/',
        'referencePaths': 'package_relative',
        'inventory': package._ref(INVENTORY_PATH, artifacts[0]),
        'formatLedger': package._ref(LEDGER_PATH, artifacts[1]),
        'identities': package._ref(IDENTITIES_PATH, artifacts[2]),
        'comparisons': package._ref(COMPARISONS_PATH, artifacts[3]),
        'adapterReport': package._ref(ADAPTER_REPORT_PATH, output[ADAPTER_REPORT_PATH]),
        'nativeFourFormatAdapterAvailable': False,
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output['report.json'] = dumps(report)
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'sourceKind': source_kind, 'sourceManifestHash': source_hash, 'disclosure': disclosure,
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'field correspondence manifest bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(source_files, source_hash, *, source_kind, disclosure):
    try:
        return _compose(source_files, source_hash, source_kind, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, UnicodeError, RecursionError, OSError) as exc:
        raise MuseumError('malformed field correspondence input') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'field correspondence external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'sourceKind', 'sourceManifestHash', 'disclosure', 'files',
            'claims', 'qualification'} and manifest['mode'] == MODE
            and manifest['profile'] == NAME and manifest['version'] == '1'
            and manifest['profileHash'] == PROFILE_HASH and manifest['claims'] == CLAIMS
            and manifest['qualification'] == QUALIFICATION,
            'field correspondence closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'field correspondence file commitments differ')
        original = {path.removeprefix('source/'): body for path, body in files.items()
            if path.startswith('source/')}
        rebuilt = compose(original, manifest['sourceManifestHash'],
            source_kind=manifest['sourceKind'], disclosure=manifest['disclosure'])
        require(dict(rebuilt.files) == files, 'field correspondence full reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, UnicodeError, RecursionError, OSError) as exc:
        raise MuseumError('malformed field correspondence package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('assemble')
    create.add_argument('--source', type=Path, required=True)
    create.add_argument('--source-hash', required=True)
    create.add_argument('--source-kind', choices=ROUTES, required=True)
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            _destination(args.output, [args.source])
            result = compose(read_tree(args.source), args.source_hash,
                source_kind=args.source_kind, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.source])
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
