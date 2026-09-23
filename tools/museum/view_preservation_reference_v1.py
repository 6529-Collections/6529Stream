"""Verify bounded, supplied original VIEW reference evidence without network access."""
import argparse
from pathlib import Path
import sys

from . import view_preservation_reference_types_v1 as types
from . import view_preservation_reference_wire_v1 as wire
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require

PROFILE_BYTES = dumps({'name':'STREAM_MUSEUM_VIEW_PRESERVATION_REFERENCE_EVIDENCE_V1', 'version':'1',
    'sourceRevision':types.SOURCE_REVISION,
    'nativeDefinitions':[{'id':d['id'],'kind':str(d['kind']),'hash':d['hash'],'byteLength':str(len(d['bytes']))}
        for d in types.definitions()],
    'bounds':{'records':str(wire.MAX_HISTORY),'payloadBytes':str(wire.MAX_PAYLOAD),
        'evidenceBytes':str(wire.MAX_EVIDENCE),'captures':'2','htmlBytes':'262144','environmentFilesPerList':str(types.MAX_FILES)},
    'sourceProof':'Every original joins a complete retained preservation bundle and its event history. '
        'The snapshot, Router root and adoption selected immediately before each reference publication are required. '
        'The two separate native trace oracles are not source proof for a joined reference.',
    'history':'Supplied complete per-scope history, raw record/source returns, normalized payload and original receipt preimages. '
        'Reference and source event positions are joined; later source changes preserve historical records.',
    'inventories':'Original environment PackageFile rows, exact JSON, original whole identity and optional fixed64 parts. '
        'This is not the unfinished full-scope render-critical inventory.',
    'claims':wire.CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def verify(raw):
    value = loads(raw,maximum=wire.MAX_EVIDENCE,canonical=True)
    require(type(value) is dict and set(value) == {'profileHash','context','graph','evidence'},
        'VIEW reference verification input fields')
    require(value['profileHash'] == PROFILE_HASH,'VIEW reference consumer profile differs')
    report=wire.validate(value['evidence'],value['context'],value['graph'])
    return {'profileHash':PROFILE_HASH,'inputHash':keccak256(raw),**report}


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    commands.add_parser('profiles')
    check=commands.add_parser('verify');check.add_argument('input',type=Path)
    args=parser.parse_args(argv)
    try:
        if args.command=='profiles':
            result={'profileHash':PROFILE_HASH,'profile':loads(PROFILE_BYTES,maximum=len(PROFILE_BYTES))}
        else:
            require(args.input.stat().st_size<=wire.MAX_EVIDENCE,'VIEW reference input byte bound')
            result=verify(args.input.read_bytes())
        print(dumps(result).decode('utf-8'))
        return 0
    except (MuseumError,OSError) as exc:
        print(str(exc),file=sys.stderr)
        return 1


if __name__=='__main__':raise SystemExit(main())
