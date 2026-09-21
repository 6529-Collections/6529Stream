"""Synthetic transport boundaries only; no compiler, replay, or EVM execution."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.build import current_native_execution_view as view
from tools.build import current_graph_owners as owners
from tools.build.prepare_current_graph import helper_coordinate, host_coordinate, prepare
from tools.build.scoped_standard_json import canonical
from tools.development import run_native_execution_view as runner


class CacheTransportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = 'test/current/Host.t.sol'
        self.library = 'smart-contracts/Lib.sol'
        self.assignments = {self.source + ':Host': 'one', self.library + ':Lib': 'two'}
        self.contexts = {}
        for label, identity, source, name in [('one', 'a'*64, self.source, 'Host'), ('two', 'b'*64, self.library, 'Lib')]:
            folder = self.root / label; (folder/'out/build-info').mkdir(parents=True)
            build = {'id': 'same-short-id', 'language': 'Solidity', 'source_id_to_path': {'0': source},
                     'input': {'sources': {source: {'content': '// fixture'}}},
                     'output': {'sources': {source: {'id': 0, 'ast': {'absolutePath': source, 'nodes': []}}}}}
            raw = canonical(build); path = folder/'out/build-info/same-short-id.json'; path.write_bytes(raw)
            artifact = folder/'out'/Path(source).name/(name+'.json'); artifact.parent.mkdir(); artifact.write_bytes(b'{}')
            cache = {'_format':'', 'paths':{'artifacts':str(folder/'out'), 'build_infos':str(folder/'out/build-info'),
                                          'sources':'smart-contracts','tests':'test/current','scripts':'script/current','libraries':['lib']},
                     'builds':['same-short-id'], 'profiles':{'default':{'viaIR':True}}, 'preprocessed':False, 'mocks':[],
                     'files':{source:{'lastModificationDate':123,'contentHash':'nativehash','interfaceReprHash':None,
                              'sourceName':source,'imports':[],'versionRequirement':'=0.8.19','seenByCompiler':True,
                              'artifacts':{name:{'0.8.19':{'default':{'path':Path(source).name+'/'+name+'.json','build_id':'same-short-id'}}}}}}}
            self.contexts[label]={'identity':identity,'buildId':'same-short-id','build':build,'analysis':None,'roots':{source},
                                  'cacheRaw':canonical(cache),'raw':raw,'path':path,'out':folder/'out'}

    def transport(self):
        return view.cache_transport(self.contexts, self.assignments, self.root/'view')

    def mutate_cache(self, label, fn):
        c=json.loads(self.contexts[label]['cacheRaw']);fn(c);self.contexts[label]['cacheRaw']=canonical(c)

    def test_colliding_short_ids_keep_separate_byte_identical_build_contexts(self):
        cache,copies,_=self.transport()
        self.assertEqual(cache['builds'],['a'*64,'b'*64])
        self.assertEqual(len(copies),4)
        for source,name,identity in [(self.source,'Host','a'*64),(self.library,'Lib','b'*64)]:
            self.assertEqual(cache['files'][source]['artifacts'][name]['0.8.19']['default']['build_id'],identity)
            self.assertEqual(json.loads(copies['build-info/'+identity+'.json'].read_bytes())['id'],'same-short-id')
        self.assertNotEqual(copies['build-info/'+'a'*64+'.json'].read_bytes(),copies['build-info/'+'b'*64+'.json'].read_bytes())

    def test_cache_profile_difference_refuses(self):
        self.mutate_cache('two',lambda c:c['profiles']['default'].update(viaIR=False))
        with self.assertRaisesRegex(ValueError,'profiles/settings'):self.transport()

    def test_foreign_cache_owner_refuses(self):
        self.mutate_cache('one',lambda c:c['files'][self.source]['artifacts']['Host']['0.8.19']['default'].update(build_id='other'))
        with self.assertRaisesRegex(ValueError,'Foreign cached'):self.transport()

    def test_multiple_profile_owners_refuse_even_same_short_id(self):
        def change(c):
            row=c['files'][self.source]['artifacts']['Host']['0.8.19'];row['other']=copy.deepcopy(row['default'])
        self.mutate_cache('one',change)
        with self.assertRaisesRegex(ValueError,'Ambiguous artifact profile'):self.transport()

    def test_original_source_id_context_mismatch_refuses(self):
        raw=json.loads(self.contexts['two']['raw']);raw['source_id_to_path']={'0':self.source};self.contexts['two']['raw']=canonical(raw)
        with self.assertRaisesRegex(ValueError,'BuildContext differs'):self.transport()

    def test_same_source_content_hash_conflict_refuses(self):
        first=json.loads(self.contexts['one']['cacheRaw'])['files'][self.source]
        ctx=self.contexts['two'];ctx['build']['input']['sources'][self.source]={'content':'// fixture'}
        ctx['build']['output']['sources'][self.source]={'id':1,'ast':{'absolutePath':self.source,'nodes':[]}};ctx['roots'].add(self.source)
        def change(c):c['files'][self.source]=dict(first,contentHash='different',artifacts={})
        self.mutate_cache('two',change)
        with self.assertRaisesRegex(ValueError,'Conflicting cached source'):self.transport()

    def test_case_insensitive_artifact_destination_collision_refuses(self):
        ctx=self.contexts['two'];source='smart-contracts/host.t.sol';name='host'
        ctx['build']['input']['sources']={source:{'content':'// fixture'}}
        ctx['build']['output']['sources']={source:{'id':0,'ast':{'absolutePath':source,'nodes':[]}}};ctx['roots']={source}
        def change(c):
            entry=c['files'].pop(self.library);entry['sourceName']=source
            entry['artifacts']={name:{'0.8.19':{'default':{'path':'host.t.sol/host.json','build_id':'same-short-id'}}}};c['files'][source]=entry
        self.mutate_cache('two',change);self.assignments={self.source+':Host':'one',source+':host':'two'}
        with self.assertRaisesRegex(ValueError,'Colliding physical artifact'):self.transport()

    def test_uncompiled_source_and_preprocessed_cache_refuse(self):
        for label,mutator in [('one',lambda c:c['files'][self.source].update(seenByCompiler=False)),
                              ('two',lambda c:c.update(preprocessed=True))]:
            original=self.contexts[label]['cacheRaw'];self.mutate_cache(label,mutator)
            with self.assertRaises(ValueError):self.transport()
            self.contexts[label]['cacheRaw']=original

    def test_representation_transport_does_not_allow_routing_changes(self):
        cache,_,_=self.transport(); changed=copy.deepcopy(cache)
        changed['files'][self.source]['artifacts']['Host']['0.8.19']['default']['path']='Host.t.sol\\Host.json'
        self.assertEqual(view.routing_cache_hash(cache),view.routing_cache_hash(changed))
        changed['files'][self.source]['artifacts']['Host']['0.8.19']['default']['build_id']='b'*64
        self.assertNotEqual(view.routing_cache_hash(cache),view.routing_cache_hash(changed))

    def test_explicit_profile_transport_preserves_native_semantics_and_records_source_owner(self):
        settings={'viaIR':True,'optimizer':{'enabled':True,'runs':200},'evmVersion':'paris'}
        for label in self.contexts:
            self.contexts[label]['build']['input']['settings']=copy.deepcopy(settings)
            def change(c):
                c['profiles']={'default':{'solc':dict(settings,outputSelection={'*':{}})}}
                if label=='two':
                    c['paths']['tests']='test/unit'
                    c['profiles']['other']=c['profiles'].pop('default')
                    entry=c['files'][self.library]['artifacts']['Lib']['0.8.19']
                    entry['other']=entry.pop('default')
            self.mutate_cache(label,change)
        with self.assertRaisesRegex(ValueError,'profiles/settings'):self.transport()
        cache,_,_=view.cache_transport(self.contexts,self.assignments,self.root/'view',routing={'context':'one','profile':'default'})
        self.assertEqual(set(cache['files'][self.library]['artifacts']['Lib']['0.8.19']),{'default'})
        self.assertEqual(cache['paths']['tests'],'test/current')
        self.contexts['two']['build']['input']['settings']['evmVersion']='shanghai'
        with self.assertRaisesRegex(ValueError,'native compiler settings'):
            view.cache_transport(self.contexts,self.assignments,self.root/'view',routing={'context':'one','profile':'default'})

    def test_view_copy_original_and_input_rechecks(self):
        cache,copies,_=self.transport(); destination=self.root/'view';(destination/'out').mkdir(parents=True);(destination/'cache').mkdir()
        for rel,path in copies.items():
            target=destination/'out'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(path.read_bytes())
        cache_path=destination/'cache/solidity-files-cache.json';cache_path.write_bytes(canonical(cache))
        input_file=self.root/'input';input_file.write_bytes(b'fixture')
        snapshot={'view':str(destination),'protectedDirectories':{str(self.root/'one'):view.file_inventory(self.root/'one')},
                  'inputFiles':{str(input_file):view.file_hash(input_file)},'viewArtifacts':view.file_inventory(destination/'out'),
                  'viewCache':view.file_inventory(destination/'cache'),'routingCacheSha256':view.routing_cache_hash(cache)}
        cache_path.write_text(json.dumps(cache,indent=4),encoding='utf-8');view.recheck(snapshot)
        for path in (input_file,next(iter(copies.values())),destination/'out/Host.t.sol/Host.json'):
            raw=path.read_bytes();path.write_bytes(raw+b'change')
            with self.assertRaises(ValueError):view.recheck(snapshot)
            path.write_bytes(raw)
        cache['builds']=['same-short-id'];cache_path.write_bytes(canonical(cache))
        with self.assertRaisesRegex(ValueError,'routing changed'):view.recheck(snapshot)

    def test_source_only_rows_require_current_literal_and_transitive_imports(self):
        context=self.contexts['one']; cache=json.loads(context['cacheRaw'])
        extras=[('smart-contracts/Unused.sol',[]),('smart-contracts/Stale.sol',[]),
                ('smart-contracts/Importer.sol',['smart-contracts/Stale.sol'])]
        for ident,(source,imports) in enumerate(extras,1):
            context['build']['input']['sources'][source]={'content':'// old literal'}
            context['build']['output']['sources'][source]={'id':ident,'ast':{'absolutePath':source,'nodes':[
                {'nodeType':'ImportDirective','absolutePath':target} for target in imports]}}
            cache['files'][source]={'lastModificationDate':123,'contentHash':'native-cache-hash','interfaceReprHash':None,
                'sourceName':source,'imports':imports,'versionRequirement':'=0.8.19','seenByCompiler':True,
                'artifacts':{'Unowned':{'0.8.19':{'default':{'path':'unowned.json','build_id':'same-short-id'}}}}}
        context['cacheRaw']=canonical(cache)
        original=json.loads(context['raw']);original['source_id_to_path']={str(v['id']):s for s,v in context['build']['output']['sources'].items()}
        context['raw']=canonical(original)
        for ctx in self.contexts.values():
            for source,item in ctx['build']['input']['sources'].items():
                path=self.root/source;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(item['content'],encoding='utf-8')
        (self.root/'smart-contracts/Stale.sol').write_text('// changed',encoding='utf-8')
        result,_,sources=view.cache_transport(self.contexts,self.assignments,self.root/'view',project=self.root)
        self.assertEqual(result['files']['smart-contracts/Unused.sol']['artifacts'],{})
        self.assertIn('smart-contracts/Unused.sol',sources)
        self.assertNotIn('smart-contracts/Stale.sol',result['files'])
        self.assertNotIn('smart-contracts/Importer.sol',result['files'])
        self.assertEqual(sources['smart-contracts/Unused.sol'],view.file_hash(self.root/'smart-contracts/Unused.sol'))

    def test_destination_cannot_overlap_original(self):
        for destination in (self.root/'one',self.root/'one/out/view',self.root):
            with self.assertRaisesRegex(ValueError,'overlaps'):view.require_disjoint(destination,[self.root/'one/out'])


class EntrypointAndRosterTests(unittest.TestCase):
    def test_explicit_helpers_and_scripts_do_not_relax_test_host_contract(self):
        for value in ('test/helpers/Scenario.sol:Scenario','script/current/Bootstrap.sol:Bootstrap'):
            self.assertEqual(':'.join(helper_coordinate(value)),value)
            with self.assertRaises(ValueError):host_coordinate(value)
        for value in ('test/current/Host.t.sol:Host','smart-contracts/Thing.sol:Thing','test/helpers/../Host.sol:Host'):
            with self.assertRaises(ValueError):helper_coordinate(value)

    def test_helper_only_preparation_does_not_add_default_test_hosts(self):
        helper=('test/helpers/Scenario.sol','Scenario')
        with tempfile.TemporaryDirectory() as temp,mock.patch.object(owners,'prepare_owned',return_value={'ok':True}) as called:
            root=Path(temp)
            prepare(root,root/'products',owners_path=root/'owners',selected_entrypoints=(helper,))
            self.assertEqual(called.call_args.args[3],(helper,))

    def test_cases_include_inherited_abi_fuzz_and_invariants(self):
        abi=[{'type':'function','name':n,'inputs':inputs} for n,inputs in
             [('testInherited',[]),('testFuzz',[{'type':'tuple[]','components':[{'type':'uint256'},{'type':'address'}]}]),('invariant_count',[])]]
        self.assertEqual(view.abi_cases(abi),['invariant_count()','testFuzz((uint256,address)[])','testInherited()'])

    def test_listing_rejects_omissions_wrong_host_duplicates_and_overloads(self):
        coord='test/current/Host.t.sol:Host';good={'test/current/Host.t.sol':{'Host':['testOne','testFuzz']}}
        runner.validate_listing(good,coord,['testOne()','testFuzz(uint256)'])
        for data in ({'test/current/Host.t.sol':{'Host':['testOne']}},{'test/current/Host.t.sol':{'Wrong':['testOne','testFuzz']}},
                     {'test/current/Host.t.sol':{'Host':['testOne','testOne','testFuzz']}}):
            with self.assertRaises(ValueError):runner.validate_listing(data,coord,['testOne()','testFuzz(uint256)'])
        with self.assertRaisesRegex(ValueError,'Overloaded'):runner.validate_listing(good,coord,['testOne()','testOne(uint256)'])

    def test_commands_are_deny_compiler_offline_exact_host_without_test_filter(self):
        args=runner.commands(Path('forge'),Path('project'),Path('view'),Path('deny'),
                             'test/current/Host.t.sol:Host',list_only=False)
        self.assertEqual(args[args.index('--use')+1],'deny');self.assertIn('--offline',args)
        self.assertEqual(args[args.index('--match-contract')+1],'^Host$');self.assertNotIn('--match-test',args)
        self.assertEqual(args[args.index('--fuzz-runs')+1],'256');self.assertIn('0x6529',args)
        self.assertNotIn('--force',args);self.assertNotIn('--no-cache',args)
        traced=runner.commands(Path('forge'),Path('project'),Path('view'),Path('deny'),
                               'test/current/Host.t.sol:Host',list_only=False,verbosity=5)
        self.assertIn('-vvvvv',traced)
        self.assertNotIn('-vvvvv',args)

    def test_environment_cannot_inherit_filters_or_compiler_overrides(self):
        with mock.patch.dict('os.environ',{'FOUNDRY_MATCH_TEST':'one','foundry_solc':'real','DAPP_TEST_GAS':'1','KEEP':'yes'},clear=True):
            self.assertEqual(runner.clean_environment('current',31337),{'KEEP':'yes','FOUNDRY_PROFILE':'current','FOUNDRY_CHAIN_ID':'31337'})

    def test_rpc_fork_chain_and_isolate_configuration_refuse(self):
        good={'chain_id':'anvil-hardhat','isolate':False}
        runner.validate_local_config(good,31337)
        for key,value in [('eth_rpc_url','https://example.invalid'),('fork_url','https://example.invalid'),
                          ('fork_block_number',0),('chain_id',1),('isolate',True)]:
            with self.subTest(key=key),self.assertRaises(ValueError):runner.validate_local_config(dict(good,**{key:value}),31337)
        with self.assertRaises(ValueError):runner.clean_environment('current',None)

    def test_forge_process_timeout_retains_failure_and_kills_only_owned_process(self):
        process=mock.Mock();process.pid=7654321;process.poll.return_value=None
        process.wait.side_effect=[runner.subprocess.TimeoutExpired(['forge'],1),-1]
        with tempfile.TemporaryDirectory() as temp,mock.patch.object(runner.subprocess,'Popen',return_value=process),mock.patch.object(runner.subprocess,'run') as kill:
            folder=Path(temp)/'attempt'
            with self.assertRaises(runner.subprocess.TimeoutExpired):runner.invoke(['forge'],folder,Path(temp),{},1)
            self.assertEqual(json.loads((folder/'process-result.json').read_bytes())['status'],'TIMEOUT')
            if runner.os.name=='nt':self.assertEqual(kill.call_args.args[0],['taskkill','/PID','7654321','/T','/F'])
            else:process.kill.assert_called_once()



class PreparedViewIntegrationTests(unittest.TestCase):
    """Feed the real preparer/exporter synthetic inputs; never launch a compiler."""
    def setUp(self):
        from tools.build.test_current_graph_owners import NativeOwnerTests, HOST
        from tools.build import scoped_standard_json as scoped
        fixture = NativeOwnerTests(); fixture.setUp(); self.addCleanup(fixture.doCleanups)
        self.fixture = fixture; self.host = HOST[0] + ':' + HOST[1]
        (fixture.root / 'foundry.toml').write_text('[profile.current]\n', encoding='utf-8')
        for label, row in fixture.data['contexts'].items():
            out = Path(row['out']); folder = Path(row['compilerCapture'])
            native = json.loads((folder / 'codegen-output.json').read_bytes())
            if label == 'hosts':
                abi = [{'type':'function','name':'testOne','inputs':[],'outputs':[],'stateMutability':'nonpayable'}]
                native['contracts'][HOST[0]][HOST[1]]['abi'] = abi
                path = out / Path(HOST[0]).name / (HOST[1] + '.json')
                physical = json.loads(path.read_bytes()); physical['abi'] = abi; fixture.write(path, physical)
                fixture.write(folder / 'codegen-output.json', native)
            build_path = out / 'build-info/same-short-id.json'; build = json.loads(build_path.read_bytes())
            build.update(language='Solidity', source_id_to_path={str(v['id']):k for k,v in native['sources'].items()}, output=native)
            fixture.write(build_path, build)
            ao = json.loads((folder / 'analysis-output.json').read_bytes()); ai = json.loads((folder / 'analysis-input.json').read_bytes())
            ni = json.loads((folder / 'codegen-input.json').read_bytes())
            fixture.write(folder / 'verification.json', scoped.verify_pair(ai, ao, ni, native))
            record = json.loads((folder / 'record.json').read_bytes())
            record['files'] = {f.name:view.file_hash(f) for f in folder.iterdir() if f.name != 'record.json'}
            fixture.write(folder / 'record.json', record)
            row['buildInfoSha256'] = view.file_hash(build_path); row['nativeOutputSha256'] = view.file_hash(folder / 'codegen-output.json')
            cache_path = Path(row['cache']) / 'solidity-files-cache.json'; cache = json.loads(cache_path.read_bytes())
            cache.update(_format='', paths={'artifacts':str(out),'build_infos':str(out/'build-info'),
                'sources':'smart-contracts','tests':'test/current','scripts':'script/current','libraries':[]},
                builds=['same-short-id'], profiles={'default':{'viaIR':True}}, preprocessed=False, mocks=[])
            for source, content in fixture.sources.items():
                entry = cache['files'].setdefault(source, {'artifacts':{}})
                entry.update(lastModificationDate=123, contentHash=view.sha(content['content'].encode())[:16],
                             interfaceReprHash=None, sourceName=source, imports=[], versionRequirement='=0.8.19', seenByCompiler=True)
            fixture.write(cache_path, cache)
        fixture.run_prepare()
        self.preparation = fixture.root / 'artifacts/current-graph/preparation.json'
        self.preparation_hash = view.file_hash(self.preparation)

    def prepare(self):
        f = self.fixture
        return view.prepare_view(f.root, f.products, f.config, self.preparation, self.preparation_hash,
                                 f.root/'execution-view', {self.host:'test'})

    def test_separate_owner_prepared_view_copies_exact_products_and_namespaced_contexts(self):
        result = self.prepare()
        self.assertEqual(result['status'], 'PREPARED_EXECUTION_VIEW')
        self.assertEqual(result['expectedCases'], {self.host:['testOne()']})
        self.assertEqual(len(result['artifacts']), 5)
        for row in result['artifacts'].values():
            self.assertEqual(view.file_hash(Path(row['original'])), row['sha256'])
        cache = json.loads((Path(result['view'])/'cache/solidity-files-cache.json').read_bytes())
        self.assertEqual(len(cache['builds']),2)
        self.assertNotIn('same-short-id',cache['builds'])
        view.recheck(result)

    def test_generic_owner_only_preparation_needs_no_native_assembly_or_flat_projections(self):
        f=self.fixture
        before=view.file_inventory(f.root/'artifacts/current-graph/compiled')
        del f.data['owners']['test/helpers/StreamNativeAssemblyCreation.sol:StreamNativeAssemblyCreation']
        f.save_config();f.write(f.products,{})
        prepare(f.root,f.products,owners_path=f.config,selected_hosts=(tuple(self.host.split(':')),),owners_only=True)
        self.preparation_hash=view.file_hash(self.preparation)
        result=self.prepare()
        self.assertNotIn('test/helpers/StreamNativeAssemblyCreation.sol:StreamNativeAssemblyCreation',result['artifacts'])
        self.assertEqual(view.file_inventory(f.root/'artifacts/current-graph/compiled'),before)
        self.assertEqual(result['expectedCases'],{self.host:['testOne()']})

    def test_changed_physical_export_projection_source_and_preparation_are_rejected(self):
        f = self.fixture; proof = json.loads(self.preparation.read_bytes())
        export = Path(next(iter(proof['compilerContexts'].values()))['nativeExports'])
        paths = [Path(f.data['contexts']['products']['out'])/'Product.sol/Product.json',
                 next(p for p in export.rglob('*.json') if p.name != 'manifest.json'),
                 f.root/'artifacts/current-graph/compiled/Product.json',
                 f.root/'smart-contracts/Product.sol', self.preparation]
        for path in paths:
            with self.subTest(path=path):
                raw=path.read_bytes();path.write_bytes(raw+b'change')
                with self.assertRaises((ValueError,KeyError,AssertionError)):self.prepare()
                path.write_bytes(raw)
                self.assertFalse((f.root/'execution-view').exists())


class EmptyCodeDebugTransportTests(unittest.TestCase):
    def test_exact_omitted_empty_native_code_debug_fields_only(self):
        from tools.build.scoped_standard_json import forge_output_transport
        native={'sources':{},'contracts':{'A.sol':{'A':{'evm':{
            'bytecode':{'object':'00','generatedSources':[],'functionDebugData':{}},
            'deployedBytecode':{'object':'00','generatedSources':[]}}}}}}
        serialized=copy.deepcopy(native)
        del serialized['contracts']['A.sol']['A']['evm']['bytecode']['generatedSources']
        del serialized['contracts']['A.sol']['A']['evm']['bytecode']['functionDebugData']
        del serialized['contracts']['A.sol']['A']['evm']['deployedBytecode']['generatedSources']
        self.assertEqual(len(forge_output_transport(native,serialized)),3)
        for field,key,value in [('bytecode','generatedSources',[{'id':4}]),
                                ('bytecode','functionDebugData',{'f':{'entryPoint':1}}),
                                ('deployedBytecode','generatedSources',[{'id':5}]),
                                ('bytecode','object','01')]:
            bad=copy.deepcopy(native);bad['contracts']['A.sol']['A']['evm'][field][key]=value
            with self.subTest(field=field,key=key),self.assertRaises(ValueError):forge_output_transport(bad,serialized)
        for value in (None,{},False):
            bad=copy.deepcopy(native);bad['contracts']['A.sol']['A']['evm']['bytecode']['generatedSources']=value
            with self.assertRaises(ValueError):forge_output_transport(bad,serialized)


class CaptureDispatchTests(unittest.TestCase):
    def test_explicit_partition_dispatch_and_scoped_default_are_separate(self):
        from tools.build.native_capture import bind_native_capture, native_filenames, validate_capture_options
        marker=({}, {}, {'kind':'original'})
        with mock.patch('tools.build.partition_native_capture.bind_partition_build_capture',return_value=marker) as partition:
            self.assertIs(bind_native_capture({'id':'x'},Path('original'),kind='partition-native',provenance=Path('proof')),marker)
            partition.assert_called_once_with({'id':'x'},Path('original'),provenance=Path('proof'))
        with mock.patch('tools.build.scoped_standard_json.bind_build_capture',return_value=marker) as scoped:
            self.assertIs(bind_native_capture({'id':'x'},Path('original'),admission=Path('admit')),marker)
            scoped.assert_called_once_with({'id':'x'},Path('original'),admission=Path('admit'))
        self.assertEqual(native_filenames('partition-native'),('input.json','output.json'))
        self.assertEqual(native_filenames('scoped-paired'),('codegen-input.json','codegen-output.json'))
        for kind,provenance,admission in [('partition-native',None,None),('partition-native',Path('p'),Path('a')),
                                         ('scoped-paired',Path('p'),None),('guess-from-record',None,None)]:
            with self.assertRaises(ValueError):validate_capture_options(kind,provenance,admission)

    def test_owner_manifest_requires_explicit_partition_provenance(self):
        data={'version':1,'contexts':{'p':{'out':'out','cache':'cache','buildId':'one','compilerCapture':'capture',
              'buildInfoSha256':'a'*64,'nativeInputSha256':'b'*64,'nativeOutputSha256':'c'*64,
              'captureKind':'partition-native','partitionProvenance':'provenance.json'}},
              'owners':{'test/current/Host.t.sol:Host':'p'}}
        owners.owner_manifest(data,{},(('test/current/Host.t.sol','Host'),),None)
        for edit in ('missing','admission','implicit'):
            changed=copy.deepcopy(data)
            if edit=='missing':del changed['contexts']['p']['partitionProvenance']
            elif edit=='admission':changed['contexts']['p']['compilerAdmission']='a'
            else:del changed['contexts']['p']['captureKind']
            with self.assertRaises(ValueError):owners.owner_manifest(changed,{},(('test/current/Host.t.sol','Host'),),None)

if __name__=='__main__':
    unittest.main()
