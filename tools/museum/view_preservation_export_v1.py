"""Join a pinned local VIEW source export to complete retained inventory evidence.

This adapter consumes the original exporter/loader's transport. It never
constructs missing publication histories, registered documents, getter returns,
archive admissions or events, and never upgrades fixture bytes to RPC evidence.
"""
import argparse
import hashlib
from pathlib import Path
import re
import sys

from . import view_preservation_inventory_v1 as consumer
from . import view_preservation_inventory_types_v1 as t
from . import view_preservation_inventory_sources_v1 as sources
from . import view_preservation_export_bindings_v1 as bindings
from . import view_preservation_reference_types_v1 as reference_types
from . import view_preservation_snapshot_types_v1 as snapshot_types
from . import view_preservation_output_types_v1 as output_types
from . import view_policy_adoption_types_v2 as adoption_types
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import encode, decode
from .independent_wire import json_values, require
from .native_finality_wire import from_json

SOURCE_SCHEMA = 'STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1'
SOURCE_SCHEMA_SHA256 = 'afa2776fc63bf96270d68f9f0800c0424a4bc9fddbfb76f4d53f99fbc5684d0b'
SOURCE_LOADER_REVISION = '6a960cdbca7e951a061a724d6a2930d749cad48c'
INVENTORY_PROFILE = '0x65fcf2d070984ddaae0930716990bd26ce67de69f1e946779be6050924c720b2'
MAX_SOURCE = 16 * 1024 * 1024
MAX_PACKET = consumer.MAX_INPUT
GRAPH_ROLES = {
    'CORE':'core', 'METADATA':'metadata', 'ROUTER':'router',
    'FINALITY':'finality', 'PROVIDER':'provider', 'ARTIST_REGISTRY':'artist',
    'SCHEMAS':'schemas', 'STORE':'store', 'DECLARATIONS':'views',
    'VIEW_REGISTRY':'rendererRegistry', 'VIEW_RENDERER':'renderer',
    'VIEW_SOURCE_SET':'entropySourceSet', 'PRESERVATION_RENDERER':'preservationRenderer',
    'CHECKPOINT':'checkpoint', 'OUTPUT_MANIFEST':'outputManifest', 'SNAPSHOT':'viewSnapshot',
    'REFERENCE':'viewReference', 'INVENTORY':'inventory', 'BUNDLE':'bundleCoverage',
    'ARTIFACT_COVERAGE':'coverage', 'EXTERNAL_COVERAGE':'externalCoverage',
    'SCOPE_MEMBERSHIP':'scopeMembership',
    'ARCHIVE':'artistArchive', 'GOVERNANCE_EXECUTOR':'authority',
    'SNAPSHOT_AUTHORITY':'authority',
}
CLAIMS = {'completeInventoryConsumerPassed':True, 'allExportedMemberBytesJoined':True,
    'independentSourceAndInventoryPinsRequired':True, 'fixturePromotedToRpcEvidence':False,
    'rpcProvenanceAuthenticated':False, 'fixtureExecutionProven':False,
    'browserExecutionProven':False, 'archiveCurrentnessProven':False, 'finalityProven':False}
PROFILE_BYTES = dumps({'name':'STREAM_MUSEUM_VIEW_LOCAL_EXPORT_INVENTORY_JOIN_V1','version':'1',
    'sourceSchema':SOURCE_SCHEMA,'sourceSchemaSHA256':SOURCE_SCHEMA_SHA256,
    'sourceLoaderRevision':SOURCE_LOADER_REVISION,
    'inventoryConsumerProfileHash':INVENTORY_PROFILE,'inventoryNativeSourceRevision':t.SOURCE_REVISION,
    'source':'Original local fixture export loader; exact compact emitted-order sourceHash, never JCS.',
    'pins':'Independent SHA256 of complete source.json and canonical full inventory packet are both mandatory.',
    'provenance':'Local fixture export and retained inventory observations keep separate origins. Neither authenticates itself.',
    'bindings':'Original basic and complete receipt hashes, immutable dependency joins and snapshot gas monotonicity. '
        'The exact source-export recipe requires reference getter hash equality with its saved admission. '
        'Capability preimage, complete worker set and governance action remain unverified.',
    'graphRolesJoined':list(GRAPH_ROLES),
    'bounds':{'sourceBytes':str(MAX_SOURCE),'inventoryPacketBytes':str(MAX_PACKET)},'claims':CLAIMS})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _pin(raw, expected, label):
    require(type(expected) is str and re.fullmatch('[0-9a-f]{64}', expected) is not None,
        label+' SHA256 must be 64 lowercase hex digits without 0x')
    require(_sha(raw)==expected, label+' independent SHA256 differs')


def _read(path, maximum):
    with Path(path).open('rb') as stream:
        raw=stream.read(maximum+1)
    require(len(raw)<=maximum, 'VIEW export adapter bounded file')
    return raw


def _loader():
    try:
        from tools.preservation.view_ceremony_inputs import validate_source
    except ModuleNotFoundError as exc:
        if exc.name=='tools.preservation.view_ceremony_inputs':
            raise MuseumError('original VIEW ceremony source loader is required; integrate its source batch first') from exc
        raise
    return validate_source


def _join_graph(source, graph):
    exported={row['role']:row for row in source['graph']}
    for role, name in GRAPH_ROLES.items():
        row=exported[role];target=graph[name]
        require((row['target'],row['runtimeHash'])==(target['address'],target['runtimeHash']),
            'VIEW export/inventory graph differs: '+role)
    return list(GRAPH_ROLES)


def _exact_abi(publication, name, kind, value):
    raw=hex_bytes(publication[name])
    require(raw==encode((kind,),(value,)), 'VIEW export original ABI differs: '+name)


def _join_publication(source, envelope):
    value=envelope['inventory'];context=envelope['context'];publication=source['publication']
    c=from_json(t.CONTEXT,value['context'])
    row,bundle,adopted,snapshot=sources.selected(value['reference'])
    original=from_json(reference_types.SOURCE,row['source'])
    require(source['fixture']['chainId']==context['chainId'], 'VIEW export original chain differs')
    require(uint(source['fixture']['initialBlockNumber'])<=uint(context['blockNumber'])
        and uint(source['fixture']['initialTimestamp'])<=uint(context['timestamp']),
        'VIEW export initial coordinates follow retained evidence anchor')
    scope=source['scope']
    require((scope['scopeType'],uint(scope['collectionId']),uint(scope['tokenId']),scope['scopeId'])==c[0],
        'VIEW export original scope differs')
    identities={'viewId':c[14],'adoptionRecord':c[13],'checkpoint':c[11],
        'outputManifest':c[12],'snapshotRecord':c[3][0],'rootRecord':c[9]}
    require(all(publication[name]==value for name,value in identities.items()),
        'VIEW export original publication identity differs')
    _exact_abi(publication,'adoptionABI',adoption_types.RECORD,
        from_json(adoption_types.RECORD,adopted['record']))
    _exact_abi(publication,'checkpointABI',output_types.CHECKPOINT_PLAN,original[2][4])
    _exact_abi(publication,'outputManifestABI',output_types.MANIFEST_PLAN,original[2][5])
    _exact_abi(publication,'snapshotReceiptABI',snapshot_types.RECEIPT,original[1])
    _exact_abi(publication,'rootRecordABI',snapshot_types.ROOT_RECORD,original[4])
    _exact_abi(publication,'rootBindingABI',snapshot_types.ROOT_BINDING,original[5])
    _exact_abi(publication,'referenceDependenciesABI',reference_types.DEPENDENCIES,
        from_json(reference_types.DEPENDENCIES,value['reference']['dependencies']))
    _exact_abi(publication,'inventoryDependenciesABI',t.DEPENDENCIES,from_json(t.DEPENDENCIES,value['dependencies']))
    # The optional bundle's dependency tuple is never invented from graph names.
    if envelope['bundle'] is not None:
        _exact_abi(publication,'bundleDependenciesABI',t.BUNDLE_DEPENDENCIES,
            from_json(t.BUNDLE_DEPENDENCIES,envelope['bundle']['dependencies']))
    return identities


def _join_members(export, source, value):
    members=value['members']
    require(len(source['members'])==len(members), 'VIEW export complete member denominator differs')
    for index,(original,retained) in enumerate(zip(source['members'],members)):
        output=decode((output_types.OUTPUT,),hex_bytes(retained['outputReturn']),maximum=992)[0]
        require((uint(original['index']),uint(original['tokenId']),uint(original['collectionSerial']))==output[:3],
            'VIEW export original member identity differs')
        for key,maximum in (('outputReturn',992),('tokenData',16384),('json',262144),('html',262144)):
            description=original[key];raw=_read(export/description['path'],maximum)
            require(raw==hex_bytes(retained[key]) and len(raw)==uint(description['byteLength'])
                and keccak256(raw)==description['keccak256'] and '0x'+_sha(raw)==description['sha256'],
                'VIEW export exact retained member bytes differ: '+str(index)+'/'+key)
    return len(members)


def verify(export, expected_source_sha256, expected_revision, inventory_raw, expected_inventory_sha256):
    """Verify correspondence without changing or supplying any frozen evidence."""
    try:
        require(consumer.PROFILE_HASH==INVENTORY_PROFILE, 'VIEW export adapter frozen inventory profile changed')
        require(type(inventory_raw) is bytes and len(inventory_raw)<=MAX_PACKET, 'VIEW export inventory packet bound')
        _pin(inventory_raw,expected_inventory_sha256,'inventory packet')
        export=Path(export)
        source_raw=_read(export/'source.json',MAX_SOURCE)
        _pin(source_raw,expected_source_sha256,'source export')
        source=_loader()(export,expected_source_sha256,expected_revision)
        require(source['schema']==SOURCE_SCHEMA, 'VIEW export adapter source schema differs')
        envelope=loads(inventory_raw,maximum=MAX_PACKET,canonical=True)
        report=consumer.verify(inventory_raw)
        graph_roles=_join_graph(source,envelope['graph'])
        identities=_join_publication(source,envelope)
        binding_report=bindings.validate(source,envelope)
        count=_join_members(export,source,envelope['inventory'])
        require(_read(export/'source.json',MAX_SOURCE)==source_raw, 'VIEW source export changed during verification')
        return {'profileHash':PROFILE_HASH,'sourceExport':{'kind':'local_fixture_export',
            'sha256':expected_source_sha256,'sourceHash':source['sourceHash'],
            'sourceRevision':source['fixture']['sourceRevision'],'fixture':source['fixture']},
            'retainedInventory':{'sha256':expected_inventory_sha256,
                'provenance':report['inventory']['provenance'],'environment':envelope['context']['environment'],
                'report':report},'joined':{'memberCount':str(count),'graphRoles':graph_roles,
                'publicationIdentities':identities,'bindings':binding_report},
            'exportOnlyGraphPins':[row for row in source['graph'] if row['role'] not in GRAPH_ROLES],
            'claims':dict(CLAIMS),
            'qualification':'Exact byte and identity correspondence between independently pinned inputs. '
                'The local export remains fixture transport; retained RPC provenance is an independent caller admission. '
                'Missing native histories, original source records, documents, getter observations or events are never synthesized. '
                'Export-only Discovery, Role Registry and Safe pins have no matching retained runtime proof. '
                'Fixture execution, current archive authority, browser execution and finality remain unproven.'}
    except MuseumError:
        raise
    except (OSError,ValueError,TypeError,KeyError,IndexError,OverflowError) as exc:
        raise MuseumError('invalid VIEW export/inventory join') from exc


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    commands.add_parser('profiles')
    command=commands.add_parser('verify')
    command.add_argument('export',type=Path);command.add_argument('inventory',type=Path)
    command.add_argument('--source-sha256',required=True)
    command.add_argument('--source-revision',required=True)
    command.add_argument('--inventory-sha256',required=True)
    args=parser.parse_args(argv)
    try:
        if args.command=='profiles':report={'profileHash':PROFILE_HASH,'profile':loads(PROFILE_BYTES)}
        else:report=verify(args.export,args.source_sha256,args.source_revision,
            _read(args.inventory,MAX_PACKET),args.inventory_sha256)
        print(dumps(json_values(report)).decode('utf-8'));return 0
    except (MuseumError,OSError) as exc:
        print(str(exc),file=sys.stderr);return 1


if __name__=='__main__':raise SystemExit(main())
