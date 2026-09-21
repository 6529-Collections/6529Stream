from pathlib import Path
import argparse, hashlib, json

def sha(b): return hashlib.sha256(b).hexdigest()
def canonical(v): return json.dumps(v,sort_keys=True,separators=(',',':')).encode()
def code(v): return v.removeprefix('0x')

p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--build-id',required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--products',type=Path)
p.add_argument('--helpers',type=Path)
p.add_argument('--out',type=Path)
p.add_argument('--cache-path',type=Path)
p.add_argument('--compiler-capture',type=Path)
p.add_argument('--compiler-admission',type=Path)
p.add_argument('--capture-kind', choices=('scoped-paired','partition-native'), default='scoped-paired')
p.add_argument('--partition-provenance',type=Path)
a=p.parse_args()
if (a.compiler_admission or a.partition_provenance or a.capture_kind != 'scoped-paired') and not a.compiler_capture:
    p.error('--compiler-admission requires --compiler-capture')
base=a.out or a.project/'out/current'
cache_path=(a.cache_path or a.project/'cache/current')/'solidity-files-cache.json'
cache_raw=cache_path.read_bytes();cache=json.loads(cache_raw)
current_path=base/'build-info'/(a.build_id+'.json');current_raw=current_path.read_bytes();current=json.loads(current_raw)
assert current['id']==a.build_id and current['solcVersion']=='0.8.19'
capture_evidence=None
if a.compiler_capture:
    import sys
    sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
    from tools.build.scoped_standard_json import forge_ast_transport, forge_storage_transport, forge_abi_transport
    from tools.build.native_capture import bind_native_capture
    current,_,capture_evidence=bind_native_capture(current,a.compiler_capture,kind=a.capture_kind,provenance=a.partition_provenance,admission=a.compiler_admission)
products=json.loads((a.products or a.project/'projection-products.json').read_bytes())
helpers={'StreamNativeAssemblyCreation':'test/helpers/StreamNativeAssemblyCreation.sol', 'StreamNativeFinalityAssemblyTest':'test/current/StreamNativeFinalityAssembly.t.sol'}
if a.helpers: helpers=json.loads(a.helpers.read_bytes())
products.update(helpers)
prior_builds={};exports={}
report={'currentBuildInfo':str(current_path),'currentBuildInfoSha256':sha(current_raw),
        'currentCompilerInputSha256':sha(canonical(current['input'])),
        'cacheSha256':sha(cache_raw),'generatorSha256':sha(Path(__file__).read_bytes()),
        'priorBuilds':{},'products':{},'compilerCapture':capture_evidence,
        'qualification':'Complete product exports copied from retained current native compiler output. Original cached physical artifacts are untouched and authenticated against their exact cache-named original full compilations. Differences are explicit; no cached/current executable equivalence is inferred. No compiler or runtime is executed here.'}
for name,source in sorted(products.items()):
    path=base/Path(source).name/(name+'.json');raw=path.read_bytes();physical=json.loads(raw)
    matches=[v for v in cache['files'][source]['artifacts'][name]['0.8.19'].values()
             if Path(v['path'].replace('\\','/'))==path.relative_to(base)]
    assert len(matches)==1, (name,'unambiguous cache coordinate')
    ident=matches[0]['build_id']
    if ident not in prior_builds:
        bp=base/'build-info'/(ident+'.json');br=bp.read_bytes();build=json.loads(br)
        assert build['id']==ident and build['solcVersion']=='0.8.19'
        assert all(k in build['input']['sources'] for k in build['output']['sources'])
        if a.compiler_capture and ident==a.build_id:
            build,_,_=bind_native_capture(build,a.compiler_capture,kind=a.capture_kind,provenance=a.partition_provenance,admission=a.compiler_admission)
        prior_builds[ident]=build
        report['priorBuilds'][ident]={'path':str(bp),'sha256':sha(br),
            'compilerInputSha256':sha(canonical(build['input'])),
            'literalSourceHashes':{k:sha(v['content'].encode()) for k,v in build['input']['sources'].items()}}
    old=prior_builds[ident];native_old=old['output']['contracts'][source][name]
    assert set(physical)==({'abi','bytecode','deployedBytecode','methodIdentifiers','rawMetadata','metadata','ast','id'} | ({'storageLayout'} if 'storageLayout' in native_old else set()))
    physical_transports=[]
    if a.compiler_capture and ident==a.build_id:
        physical_transports.extend(forge_abi_transport(native_old['abi'],physical['abi']))
    else:
        assert physical['abi']==native_old['abi']
    assert json.loads(physical['rawMetadata'])==json.loads(native_old['metadata'])
    assert physical['metadata']['settings']['compilationTarget']=={source:name}
    assert physical['methodIdentifiers']==native_old['evm']['methodIdentifiers']
    # Non-emission is not evidence of an empty storage layout.
    if 'storageLayout' in native_old:
        if a.compiler_capture and ident==a.build_id:
            physical_transports.extend(forge_storage_transport(native_old['storageLayout'],physical['storageLayout']))
        else:
            assert physical['storageLayout']==native_old['storageLayout']
    if a.compiler_capture and ident==a.build_id:
        physical_transports.extend(forge_ast_transport(old['output']['sources'][source]['ast'],physical['ast']))
    else:
        assert physical['ast']==old['output']['sources'][source]['ast']
    assert physical['id']==old['output']['sources'][source]['id']
    for field in ['bytecode','deployedBytecode']:
        x,y=physical[field],native_old['evm'][field]
        assert set(x).issubset({'object','sourceMap','linkReferences','immutableReferences'})
        assert code(x['object'])==code(y['object'])
        assert x['sourceMap']==y['sourceMap'] and x['linkReferences']==y['linkReferences']
        assert x.get('immutableReferences',{})==y.get('immutableReferences',{})
    native=current['output']['contracts'][source][name]
    if name in helpers:
        assert json.loads(physical['rawMetadata'])==json.loads(native['metadata'])
        if a.compiler_capture and ident==a.build_id:
            forge_abi_transport(native['abi'],physical['abi'])
        else:
            assert physical['abi']==native['abi']
        assert physical['methodIdentifiers']==native['evm']['methodIdentifiers']
        for field in ['bytecode','deployedBytecode']:
            assert code(physical[field]['object'])==code(native['evm'][field]['object']), (name,field,'current literal helper code')
            assert physical[field]['linkReferences']==native['evm'][field]['linkReferences'], (name,field,'current literal helper links')
            assert physical[field].get('immutableReferences',{})==native['evm'][field].get('immutableReferences',{}), (name,field,'current literal helper immutable ranges')
    exported={'abi':native['abi'],'bytecode':{},'deployedBytecode':{},
              'methodIdentifiers':native['evm']['methodIdentifiers'],'rawMetadata':native['metadata'],
              'metadata':json.loads(native['metadata']),
              'ast':current['output']['sources'][source]['ast'],
              'id':current['output']['sources'][source]['id']}
    if 'storageLayout' in native:
        exported['storageLayout']=native['storageLayout']
    for field in ['bytecode','deployedBytecode']:
        v=native['evm'][field]
        exported[field]={'object':'0x'+code(v['object']),'sourceMap':v['sourceMap'],'linkReferences':v['linkReferences']}
        if field=='deployedBytecode':exported[field]['immutableReferences']=v.get('immutableReferences',{})
    payload=canonical(exported);relative=Path(source).name+'/'+name+'.json';exports[relative]=payload
    comparison={k:physical[k]==exported[k] for k in ['abi','methodIdentifiers','ast','id']}
    comparison['storageLayout']=(('storageLayout' in physical)==('storageLayout' in exported) and physical.get('storageLayout')==exported.get('storageLayout'))
    comparison['rawMetadata']=json.loads(physical['rawMetadata'])==json.loads(native['metadata'])
    for field in ['bytecode','deployedBytecode']:
        for key in ['object','sourceMap','linkReferences','immutableReferences']:
            left,right=physical[field].get(key,{}),exported[field].get(key,{})
            if key=='object':left,right=code(left),code(right)
            comparison[field+'.'+key]=left==right
    report['products'][name]={'source':source,'physicalPath':str(path),'originalPhysicalArtifactSha256':sha(raw),
        'originalAuthorityBuildId':ident,'currentBuildId':a.build_id,'physicalVsCurrent':comparison,
        'currentExport':relative,'currentNativeExportSha256':sha(payload),
        'storageLayoutEmitted':{'physical':'storageLayout' in physical,'current':'storageLayout' in native},
        'physicalSerializationTransports':physical_transports,
        'creationBytes':len(code(native['evm']['bytecode']['object']))//2,
        'runtimeBytes':len(code(native['evm']['deployedBytecode']['object']))//2}
a.output.mkdir(parents=True,exist_ok=False)
for name,raw in exports.items():
    path=a.output/name;path.parent.mkdir(exist_ok=True);path.write_bytes(raw)
(a.output/'manifest.json').write_bytes(canonical(report))
print(json.dumps({'products':len(exports),'priorBuildIds':list(prior_builds),
                  'differingExecutableProducts':[n for n,v in report['products'].items()
                    if not(v['physicalVsCurrent']['bytecode.object'] and v['physicalVsCurrent']['deployedBytecode.object'])],
                  'manifestSha256':sha(canonical(report))}))
