"""Verify a complete retained VIEW inventory and optional original bundle offline."""
import argparse
from pathlib import Path
import sys

from . import view_preservation_inventory_types_v1 as types
from . import view_preservation_inventory_wire_v1 as inventory
from . import view_preservation_bundle_wire_v1 as bundle
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import json_values, require

MAX_INPUT=256*1024*1024
PROFILE_BYTES=dumps({'name':'STREAM_MUSEUM_VIEW_PRESERVATION_FULL_INVENTORY_EVIDENCE_V1','version':'1',
    'sourceRevision':types.SOURCE_REVISION,'inventoryProfile':types.PROFILE,'bundleProfile':types.BUNDLE_PROFILE,
    'definitions':[{'id':row['id'],'hash':row['hash']} for row in types.definitions()],
    'stages':types.STAGES,'source':'Complete original reference/preservation proof, every member output byte string, '
        'original typed metadata/Artist preimages, complete ordered registered documents and runtime bytes. '
        'Retained inventory getter calls and events are mandatory externally admitted observations.',
    'media':'Only empty image or canonical lowercase raw CIDv1 SHA256 supported by this frozen native profile.',
    'typedPayloadValidation':'Exact canonical payload bytes and inactive tagged-union fields; existing WORK, RIGHTS '
        'and conservation interpretation validators. Conservation language tags must also be valid against '
        'the pinned 2026-08-08 IANA registry, a stricter consumer condition than native syntax alone.',
    'coverage':'Optional complete original bundle admission preimages and ordered archive/verifier binding getters, '
        'with explicit retained native observation trust. '
        'Neither recorded current calls nor original archive commitments authenticate their own provenance.',
    'bounds':{'inputBytes':str(MAX_INPUT),'inventoryBytes':str(inventory.MAX_EVIDENCE),
        'members':str(types.MAX_MEMBERS),'segments':str(inventory.MAX_SEGMENTS),'items':str(inventory.MAX_ITEMS),
        'itemsPerSegment':'1024','bundleItems':str(bundle.MAX_ITEMS),'bundleOriginalBytes':str(bundle.MAX_TOTAL),
        'gasPerSourceRead':str(inventory.MAX_GAS)},'claims':inventory.CLAIMS})
PROFILE_HASH=keccak256(PROFILE_BYTES)


def verify(raw):
    value=loads(raw,maximum=MAX_INPUT,canonical=True)
    require(type(value) is dict and set(value)=={'profileHash','context','graph','inventory','bundle'},
        'VIEW full inventory input fields')
    require(value['profileHash']==PROFILE_HASH,'VIEW full inventory consumer profile')
    checked=inventory.validate(value['inventory'],value['context'],value['graph'])
    coverage=None if value['bundle'] is None else bundle.validate(value['bundle'],value['context'],value['graph'],checked)
    # Do not return all member bytes a second time in the report. Native item,
    # segment and evidence hashes retain the exact verified denominator.
    report={key:checked[key] for key in ('sourceRevision','scope','planId','dependencyHash','evidence','provenance','claims','qualification')}
    report.update(itemCount=str(len(checked['items'])),segmentCount=str(len(checked['segments'])))
    return json_values({'profileHash':PROFILE_HASH,'inputHash':keccak256(raw),'inventory':report,'bundle':coverage})


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);commands=parser.add_subparsers(dest='command',required=True)
    commands.add_parser('profiles');check=commands.add_parser('verify');check.add_argument('input',type=Path)
    args=parser.parse_args(argv)
    try:
        if args.command=='profiles':result={'profileHash':PROFILE_HASH,'profile':loads(PROFILE_BYTES,maximum=len(PROFILE_BYTES))}
        else:
            with args.input.open('rb') as stream:raw=stream.read(MAX_INPUT+1)
            require(len(raw)<=MAX_INPUT,'VIEW full inventory input byte bound');result=verify(raw)
        print(dumps(result).decode('utf-8'));return 0
    except (MuseumError,OSError) as exc:
        print(str(exc),file=sys.stderr);return 1


if __name__=='__main__':raise SystemExit(main())
