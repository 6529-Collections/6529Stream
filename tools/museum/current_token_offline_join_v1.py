"""Check one pinned current V4 dossier across assessment and native exports.

This is a read-only operator check, not a new dossier or acceptance profile.
Every supplied package is independently replayed before its retained V4 bytes
are compared. The check cannot authenticate an RPC provider or source origin.
"""
import argparse
from pathlib import Path

from . import canonical_current_assessment_v2 as assessment
from . import canonical_object_dossier_v4 as dossier
from . import canonical_object_dossier_v5 as reviewed
from . import canonical_native_inputs_v1 as native_inputs
from . import native_multiformat_ledger_v2 as ledger
from . import native_multiformat_package_v2 as formats
from . import object_dossier_inventory as inventory
from .bagit import MAX_BYTES, read_tree
from .canonical import MuseumError, dumps, loads
from .independent_wire import require


def _subtree(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items()
        if path.startswith(prefix)}


def check(native_files, native_hash, v4_files, v4_hash, assessment_files,
          assessment_hash, format_files, format_hash, *, v5_files=None,
          v5_hash=None):
    """Replay pinned children and return a qualified, non-persisted join report."""
    require((v5_files is None) == (v5_hash is None),
        'current offline join V5 package and pin required together')
    retained, _, _, _ = native_inputs.admit(dict(native_files), native_hash)
    base = dossier.verify(dict(v4_files), v4_hash)
    current = assessment.verify(dict(assessment_files), assessment_hash)
    exported = formats.verify(dict(format_files), format_hash)
    extra = None if v5_files is None else reviewed.verify(dict(v5_files), v5_hash)
    original = dict(base.files)
    require(_subtree(original, 'canonical/input/acquisition/inputs/') == retained,
        'current offline join original V10 native input bytes differ')
    require(_subtree(dict(current.files), 'current-v1/v4/') == original,
        'current offline join assessment retained V4 differs')
    require(_subtree(dict(exported.files), 'source/') == original,
        'current offline join four-format retained V4 differs')
    if extra is not None:
        require(_subtree(dict(extra.files), 'v4/') == original,
            'current offline join reviewed dossier retained V4 differs')
    require(current.report['sourceState'] == base.report['sourceState'],
        'current offline join assessment source state differs')
    require(base.report['packetRequirementCount'] == '19'
        and base.report['dossierRequirementCount'] == '49'
        and current.report['originalPacketGroupCount'] == '19'
        and current.report['originalRequirementCount'] == '49',
        'current offline join original denominator differs')
    original_rows = loads(original['canonical/input/dossier/requirements.json'],
        maximum=MAX_BYTES, canonical=True)['results']
    current_rows = loads(dict(current.files)[assessment.ASSESSMENT_PATH],
        maximum=MAX_BYTES, canonical=True)['results']
    codes = [row['code'] for row in inventory.REQUIREMENTS]
    require(len(original_rows) == len(current_rows) == len(codes) == 49
        and [row['code'] for row in original_rows] == codes
        and [row['code'] for row in current_rows] == codes,
        'current offline join exact 49 requirement codes differ')
    native = loads(dict(exported.files)[ledger.INVENTORY_PATH],
        maximum=MAX_BYTES, canonical=True)
    coverage = loads(dict(exported.files)[ledger.LEDGER_PATH],
        maximum=MAX_BYTES, canonical=True)
    require(len(coverage['rows']) == len(native['fields']),
        'current offline join original field coverage differs')
    prior_provenance = loads(original[
        'canonical/input/acquisition/report.json'],
        maximum=MAX_BYTES, canonical=True)['sourceProvenance']
    return {
        'v4ManifestHash': v4_hash,
        'v5ManifestHash': v5_hash,
        'assessmentManifestHash': assessment_hash,
        'nativeMultiformatManifestHash': format_hash,
        'v10NativeInputsManifestHash': native_hash,
        'sourceState': base.report['sourceState'],
        'v10PriorSourceProvenance': prior_provenance,
        'originalPacketGroups': '19',
        'originalRequirementRows': '49',
        'currentRequirementRows': '49',
        'currentVerifiedCodes': current.report['currentVerifiedCodes'],
        'originalFieldRows': str(len(native['fields'])),
        'fourFormatFieldRows': str(len(coverage['rows'])),
        'fourFormats': {name: exported.report['adapters'][name]['status']
            if 'status' in exported.report['adapters'][name] else 'reported'
            for name in formats.ADAPTERS},
        'sourceOriginAuthenticated': False,
        'chainConsensusProven': False,
        'currentAuthorityProven': False,
        'institutionalAcceptance': False,
        'actualCurrentCaptureAcceptance': False,
        'qualification': 'Exact pinned V4 bytes and original 19/49 decisions are retained '
        'across the independently replayed assessment, native four-format package '
        'and optional V5 review wrapper. The separately pinned original V10 native '
        'input bytes are retained in V4. Source provenance is a supplied claim; '
        'this offline check does not authenticate original RPC origin, current '
        'authority, media retrieval or institutional acceptance.',
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('native-inputs', 'v4', 'assessment', 'formats'):
        parser.add_argument('--' + role, type=Path, required=True)
        parser.add_argument('--' + role + '-hash', required=True)
    parser.add_argument('--v5', type=Path)
    parser.add_argument('--v5-hash')
    args = parser.parse_args(argv)
    try:
        report = check(read_tree(args.native_inputs), args.native_inputs_hash,
            read_tree(args.v4), args.v4_hash,
            read_tree(args.assessment), args.assessment_hash,
            read_tree(args.formats), args.formats_hash,
            v5_files=None if args.v5 is None else read_tree(args.v5),
            v5_hash=args.v5_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(2, 'current offline join: ' + str(exc) + '\n')
    print(dumps(report).decode('utf-8'))


if __name__ == '__main__':
    main()
