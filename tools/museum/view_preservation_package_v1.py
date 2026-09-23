"""Complete retained VIEW evidence in deterministic BagIt and OCFL transport."""
import argparse
from hashlib import sha256
from pathlib import Path
import re
import sys

from . import bagit, ocfl
from . import view_preservation_bagit_v1 as transport
from . import view_preservation_inventory_v1 as consumer
from . import view_preservation_inventory_types_v1 as native
from . import view_preservation_output_types_v1 as output
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode
from .independent_wire import ZERO, require
from .native_finality_wire import from_json

NAME = 'STREAM_MUSEUM_VIEW_PRESERVATION_PACKAGE_MANIFEST_V1'
INPUT_PATH = 'inventory/input.json'
REPORT_PATH = 'inventory/verification.json'
MANIFEST_PATH = 'evidence/manifest.json'
SCHEMA_PATH = 'interpretation/package-manifest-schema.json'
CONSUMER_PROFILE_PATH = 'interpretation/inventory-consumer-profile.json'
INVENTORY_PROFILE = '0x65fcf2d070984ddaae0930716990bd26ce67de69f1e946779be6050924c720b2'
SOURCE_NAMES = ('view_preservation_package_v1.py', 'view_preservation_bagit_v1.py')
CLAIMS = {'completeRetainedInventoryReplayed':True, 'allMemberBytesEmbedded':True,
    'originalEnvelopePreserved':True, 'rpcProvenanceAuthenticated':False,
    'nativeExecutionProven':False, 'archiveAuthorityProven':False,
    'completeObjectDossierConformance':False, 'currentFinalityProven':False,
    'browserExecutionProven':False, 'institutionalIngestProven':False,
    'registeredPackageProfile':False, 'completeRuntimeArchive':False, 'networkFetch':False}
QUALIFICATION = ('Complete embedding and replay of this retained VIEW inventory selection. '
    'Recorded observations keep their original provenance and do not authenticate themselves. '
    'The original consumer and optional bundle limitations remain. This is an unregistered '
    'evidence-package profile, not complete OBJECT_DOSSIER_V1 or STATE_EXPORT conformance. '
    'Normalized tool text is inert provenance, not an executable runtime archive or proof of execution.')


def _object(properties):
    return {'type':'object','properties':properties,'required':list(properties),'additionalProperties':False}


_HASH = {'type':'string','pattern':'^0x[0-9a-f]{64}$'}
_UINT = {'type':'string','pattern':'^(0|[1-9][0-9]*)$'}
_FILE = _object({'path':{'type':'string'},'bytes':_UINT,'sha256':_HASH,'keccak256':_HASH})
SCHEMA_BYTES = dumps({'$schema':'https://json-schema.org/draft/2020-12/schema',
    '$id':'urn:6529stream:schema:'+NAME,'title':NAME,
    **_object({'mode':{'const':'retained_view_preservation_evidence'},'version':{'const':'1'},
        'profileHash':{'const':transport.PROFILE_HASH},
        'inventoryConsumerProfileHash':{'const':INVENTORY_PROFILE},
        'nativeSourceRevision':{'const':native.SOURCE_REVISION},
        'inputSHA256':{'type':'string','pattern':'^[0-9a-f]{64}$'},'inputHash':_HASH,
        'scope':_object({'chainId':_UINT,'core':{'type':'string','pattern':'^0x[0-9a-f]{40}$'},
            'collectionId':_UINT,'scopeId':_HASH,'blockNumber':_UINT,'blockHash':_HASH}),
        'provenance':{'enum':['synthetic_fixture','externally_admitted_rpc']},
        'bundleIncluded':{'type':'boolean'},'planId':_HASH,'memberCount':_UINT,
        'members':{'type':'array','items':_object({'index':_UINT,'tokenId':_UINT,
            'collectionSerial':_UINT,'files':_object({key:_FILE for key in ('json','html','outputReturn','tokenData')})})},
        'claims':_object({key:{'const':value} for key,value in CLAIMS.items()}),
        'qualification':{'const':QUALIFICATION}})})


def _ref(path, raw):
    return {'path':path,'bytes':str(len(raw)),'sha256':'0x'+sha256(raw).hexdigest(),
        'keccak256':keccak256(raw)}


def _bounded(files):
    files = dict(files)
    bagit._paths(files)
    require(all(type(raw) is bytes for raw in files.values()), 'VIEW package byte strings required')
    require(len(files)<=bagit.MAX_FILES and sum(map(len,files.values()))<=bagit.MAX_BYTES,
        'VIEW package aggregate transport bound')
    return files


def _snapshot(supplied=None):
    names = {'tool/'+name+'.txt' for name in SOURCE_NAMES}
    if supplied is None:
        supplied = {'tool/'+name+'.txt':Path(__file__).with_name(name).read_bytes().replace(b'\r\n',b'\n')
            for name in SOURCE_NAMES}
    require(type(supplied) is dict and set(supplied)==names, 'VIEW package inert tool text inventory')
    for raw in supplied.values():
        require(type(raw) is bytes and 0<len(raw)<=bagit.MAX_MANIFEST and b'\r' not in raw,
            'VIEW package inert tool text bounds')
        raw.decode('utf-8')
    result = dict(supplied)
    result['tool/source-index.json'] = dumps({'normalization':'UTF-8 with LF line endings',
        'completeRuntimeArchive':False,'executedSourceProven':False,
        'files':[_ref(name,raw) for name,raw in sorted(supplied.items())]})
    return result


def _build(inventory_raw, expected_inventory_sha256, *, disclosure, bagging_date,
           predecessor=ZERO, tool_snapshot=None):
    require(disclosure=='public', 'VIEW package requires explicit public disclosure')
    require(type(inventory_raw) is bytes and len(inventory_raw)<=bagit.MAX_BYTES,
        'VIEW package input transport byte bound')
    require(type(expected_inventory_sha256) is str and re.fullmatch('[0-9a-f]{64}',expected_inventory_sha256)
        and sha256(inventory_raw).hexdigest()==expected_inventory_sha256,
        'VIEW package independent inventory SHA256 differs')
    require(consumer.PROFILE_HASH==INVENTORY_PROFILE, 'VIEW package frozen consumer profile differs')
    report = consumer.verify(inventory_raw)
    envelope = loads(inventory_raw,maximum=bagit.MAX_BYTES,canonical=True)
    value, context = envelope['inventory'], envelope['context']
    scope = from_json(native.CONTEXT,value['context'])[0]
    require(scope[0]==4 and scope[2]==0, 'VIEW package original VIEW scope required')
    source_scope = {'chainId':context['chainId'],'core':context['core'],
        'collectionId':str(scope[1]),'scopeId':scope[3],
        'blockNumber':context['blockNumber'],'blockHash':context['blockHash']}
    files = {INPUT_PATH:inventory_raw,REPORT_PATH:dumps(report),
        CONSUMER_PROFILE_PATH:consumer.PROFILE_BYTES,SCHEMA_PATH:SCHEMA_BYTES}
    members = []
    for index, member in enumerate(value['members']):
        row = decode((output.OUTPUT,),hex_bytes(member['outputReturn']),maximum=992)[0]
        member_files = {}
        for name, extension in (('json','.json'),('html','.html'),('outputReturn','.output.abi'),('tokenData','.token-data.bin')):
            path = 'members/member-'+format(index,'020d')+extension
            raw = hex_bytes(member[name]); files[path] = raw; member_files[name] = _ref(path,raw)
        members.append({'index':str(index),'tokenId':str(row[1]),'collectionSerial':str(row[2]),'files':member_files})
    manifest = {'mode':'retained_view_preservation_evidence','version':'1','profileHash':transport.PROFILE_HASH,
        'inventoryConsumerProfileHash':INVENTORY_PROFILE,'nativeSourceRevision':native.SOURCE_REVISION,
        'inputSHA256':expected_inventory_sha256,'inputHash':keccak256(inventory_raw),
        'scope':source_scope,'provenance':report['inventory']['provenance'],
        'bundleIncluded':envelope['bundle'] is not None,'planId':report['inventory']['planId'],
        'memberCount':str(len(members)),'members':members,'claims':CLAIMS,'qualification':QUALIFICATION}
    files[MANIFEST_PATH] = dumps(manifest)
    require(len(files[MANIFEST_PATH])<=bagit.MAX_MANIFEST, 'VIEW package evidence manifest bound')
    files.update(_snapshot(tool_snapshot)); _bounded(files)
    description = {'mode':transport.INPUT_MODE,'version':'1','bundleKind':'VIEW_PRESERVATION_EVIDENCE_V1',
        'sourceMode':manifest['provenance'],'disclosure':'public','externalIdentifier':transport.external_identifier(source_scope),
        'scope':source_scope,'baggingDate':bagging_date,'predecessor':predecessor,
        'bundleManifest':{'path':MANIFEST_PATH,'hash':keccak256(files[MANIFEST_PATH])},
        'schema':{'path':SCHEMA_PATH,'id':schema_id(NAME),'hash':keccak256(SCHEMA_BYTES)},
        'recordChainHeads':[], 'tool':{'name':'6529Stream retained VIEW evidence packaging','version':'1',
            'sourceHash':keccak256(files['tool/source-index.json'])},
        'semanticPackages':[],
        'payloads':[{**_ref(name,raw),'renderCritical':True,'delivery':{'kind':'embedded'}} for name,raw in sorted(files.items())]}
    return transport.build_bag(dumps(description),files)


def build(inventory_raw, expected_inventory_sha256, *, disclosure, bagging_date,
          predecessor=ZERO, tool_snapshot=None):
    try:
        return _build(inventory_raw,expected_inventory_sha256,disclosure=disclosure,
            bagging_date=bagging_date,predecessor=predecessor,tool_snapshot=tool_snapshot)
    except MuseumError: raise
    except (ValueError,TypeError,KeyError,IndexError,OverflowError,UnicodeError) as exc:
        raise MuseumError('invalid retained VIEW preservation package') from exc


def verify_files(files, expected_manifest_hash):
    """Rebuild all semantics, never stop at attacker-recomputed transport fixity."""
    files = _bounded(files)
    bag = transport.verify_files_transport(files,expected_manifest_hash)
    d = loads(bag.manifest,maximum=bagit.MAX_MANIFEST,canonical=True)['input']
    payloads = {name[5:]:raw for name,raw in files.items() if name.startswith('data/')}
    try:
        manifest = loads(payloads[MANIFEST_PATH],maximum=bagit.MAX_MANIFEST,canonical=True)
        rebuilt = build(payloads[INPUT_PATH],manifest['inputSHA256'],disclosure=d['disclosure'],
            bagging_date=d['baggingDate'],predecessor=d['predecessor'],
            tool_snapshot={name:raw for name,raw in payloads.items() if name in {'tool/'+s+'.txt' for s in SOURCE_NAMES}})
    except (KeyError,TypeError,ValueError) as exc:
        raise MuseumError('VIEW package reconstruction inputs missing or invalid') from exc
    require(rebuilt.manifest==bag.manifest and dict(rebuilt.files)==files,
        'VIEW package complete semantic reconstruction differs')
    return rebuilt


def verify(directory, expected_manifest_hash):
    return verify_files(bagit.read_tree(directory),expected_manifest_hash)


def verify_ocfl_files(files, expected_inventory_hash):
    result = ocfl.verify_object_files(files,expected_inventory_hash)
    inventory = loads(result.inventory,maximum=bagit.MAX_MANIFEST,canonical=True)
    retained = dict(result.files)
    for version in inventory['versions'].values():
        manifest_digest = next(digest for digest,names in version['state'].items()
            if 'bag/stream-manifest.json' in names)
        manifest = retained[inventory['manifest'][manifest_digest][0]]
        d = loads(manifest,maximum=bagit.MAX_MANIFEST,canonical=True)['input']
        require(d['mode']==transport.INPUT_MODE, 'VIEW package OCFL history has another package profile')
        # Generic bag dispatch already performs this profile's full replay.
    return result


def build_ocfl(bag, *, created, message, previous=None, previous_inventory_hash=None):
    bag = verify_files(bag.files,bag.manifest_hash)
    if previous is not None:
        require(previous_inventory_hash is not None, 'VIEW package original OCFL pin required')
        previous = verify_ocfl_files(previous.files,previous_inventory_hash)
    return ocfl.build_version(bag,created=created,message=message,
        previous=previous,previous_inventory_hash=previous_inventory_hash)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command',required=True)
    sub.add_parser('profiles')
    make = sub.add_parser('build'); make.add_argument('inventory',type=Path); make.add_argument('output',type=Path)
    make.add_argument('--inventory-sha256',required=True); make.add_argument('--disclosure',required=True)
    make.add_argument('--bagging-date',required=True); make.add_argument('--predecessor',default=ZERO)
    check = sub.add_parser('verify'); check.add_argument('directory',type=Path); check.add_argument('--manifest-hash',required=True)
    version = sub.add_parser('ocfl'); version.add_argument('bag',type=Path); version.add_argument('output',type=Path)
    version.add_argument('--manifest-hash',required=True); version.add_argument('--created',required=True)
    version.add_argument('--message',required=True); version.add_argument('--previous',type=Path)
    version.add_argument('--previous-inventory-hash')
    history = sub.add_parser('verify-ocfl'); history.add_argument('directory',type=Path); history.add_argument('--inventory-hash',required=True)
    args = parser.parse_args(argv)
    try:
        if args.command=='profiles':
            print(dumps({'profileHash':transport.PROFILE_HASH,'profile':loads(transport.PROFILE_BYTES),
                'manifestSchemaHash':keccak256(SCHEMA_BYTES),'manifestSchema':loads(SCHEMA_BYTES)}).decode()); return 0
        if args.command=='build':
            require(args.disclosure=='public', 'VIEW package requires explicit public disclosure')
            with args.inventory.open('rb') as handle: raw=handle.read(bagit.MAX_BYTES+1)
            result=build(raw,args.inventory_sha256,disclosure=args.disclosure,
                bagging_date=args.bagging_date,predecessor=args.predecessor)
            bagit.write_tree(result.files,args.output)
        elif args.command=='verify': result=verify(args.directory,args.manifest_hash)
        elif args.command=='ocfl':
            require((args.previous is None)==(args.previous_inventory_hash is None), 'VIEW package previous path/pin must be paired')
            previous=None if args.previous is None else verify_ocfl_files(bagit.read_tree(args.previous),args.previous_inventory_hash)
            result=build_ocfl(verify(args.bag,args.manifest_hash),created=args.created,message=args.message,
                previous=previous,previous_inventory_hash=args.previous_inventory_hash)
            bagit.write_tree(result.files,args.output)
        else: result=verify_ocfl_files(bagit.read_tree(args.directory),args.inventory_hash)
        print(dumps({'manifestHash' if hasattr(result,'manifest_hash') else 'inventoryHash':
            result.manifest_hash if hasattr(result,'manifest_hash') else result.inventory_hash,
            'claims':CLAIMS,'qualification':QUALIFICATION}).decode()); return 0
    except (MuseumError,OSError,ValueError,TypeError,KeyError) as exc:
        print(str(exc),file=sys.stderr); return 1


if __name__=='__main__': raise SystemExit(main())
