"""Rehashed adversarial original reference evidence; no native execution."""
from copy import deepcopy
from hashlib import sha256
import socket
import unittest
from unittest.mock import patch

from . import view_preservation_reference_wire_v1 as w
from . import view_preservation_reference_types_v1 as t
from . import view_preservation_reference_inventory_v1 as inv
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, json_values
from .view_preservation_fixture_v1 import ViewPreservationFixtureV1
from .test_view_preservation_output_wire_v1 import reseal as seal_output, A, H
from .test_view_preservation_snapshot_wire_v1 import supplied as snapshot
from .test_view_preservation_root_wire_v1 import supplied as root


def inventory(rows,relative,c,g):
    raw=inv.files_bytes(rows,relative);host=g['viewReference']['address']
    parts=[]
    for start in range(0,len(rows),64):
        group=rows[start:start+64];body=inv.files_bytes(group,relative)
        parts.append({'partId':inv.part_id(group,relative,c['chainId'],host),
            'contentHash':keccak256(body),'byteLength':str(len(body)),'payload':'0x'+body.hex()})
    return {'relative':relative,'rows':json_values(rows),'inventoryId':inv.inventory_id(rows,relative,c['chainId'],host),
        'contentHash':keccak256(raw),'byteLength':str(len(raw)),'payload':'0x'+raw.hex(),'parts':parts}


def reseal(value,c,g):
    previous=chain=ZERO
    for index,row in enumerate(value['history']):
        p,r,s=row['publication'],row['receipt'],row['receipt'][1]
        p[1][2:4]=[previous,str(index)];s[4:6]=[previous,str(index+1)]
        p[1][6]=s[8]=w.source_hash(row['source'],value['dependencies'],c,g)
        raw=w.payload(p,r,row['source'],hex_bytes(row['environment']),c,g)
        row['payload']='0x'+raw.hex();s[6:8]=[keccak256(raw),str(len(raw))]
        s[0]=w.record_hash(p,r,c,g);s[1]=w.chain_hash(chain,r,c,g)
        row['recordReturn']='0x'+encode((t.PUBLICATION,t.RECEIPT),(w._v(t.PUBLICATION,p),w._v(t.RECEIPT,r))).hex()
        row['sourceReturn']='0x'+encode((t.SOURCE,),(w._v(t.SOURCE,row['source']),)).hex()
        previous,chain=s[0],s[1]
    value['current']=deepcopy(value['history'][-1]['receipt'])
    value['selectedRecordHash']=value['history'][0]['receipt'][1][0]
    if value['lock'][2]!=ZERO:value['lock'][:2]=[previous,str(len(value['history']))]
    for event,descriptor in zip(value.get('events',[]),w.expected_events(value,c,g)):
        event['log'].update(address=descriptor['address'],topics=list(descriptor['topics']),data=descriptor['data'])
    return value


def supplied(count=3,mode='disabled',burned=False,locked=True,foreign_later=False,later_adoption=False):
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    fixture=ViewPreservationFixtureV1(count=count,mode=mode,burned=burned,later_adoption=later_adoption)
    c,g=fixture.context,fixture.graph
    if foreign_later:
        from .test_view_preservation_adoption_wire_v1 import _bind_original_registry
        history=fixture.adoption_value['history'];foreign=history.pop(0)
        foreign['record'][10]='115';foreign['event'][6]='15';foreign['event'][11]='115'
        foreign['event'][7]=H('foreign later block');foreign['event'][8]=H('foreign later tx')
        history.append(foreign)
        version=fixture.adoption_value['preservation']['registry']['version']
        _bind_original_registry(fixture.adoption_value,c,g,version[4],version[5])
    a=adoption.validate(fixture.adoption_value,c,g)
    m=membership.validate(fixture.member_value,c,g,fixture.binding)
    a={**a,'tokenIds':m['tokenIds'],'policies':m['policies']}
    html={}
    for row in fixture.output_value['checkpoint']['outputs']:
        body=('<html>original synthetic token '+row[1]+'</html>').encode();html[row[1]]=body
        row[9]=keccak256(body);row[11]=str(len(body))
    seal_output(fixture.output_value,c,g,a,coverage_timestamp=106)
    fixture.snapshot_value,_,_=snapshot(context=c,graph=g,output_value=fixture.output_value,
        adoption=a,membership=m,recorded_at=107)
    fixture.root_value,*_=root(context=c,graph=g,snapshot_value=fixture.snapshot_value,
        output_value=fixture.output_value,published_at=109)
    fixture.bundle.update(output=fixture.output_value,snapshot=fixture.snapshot_value,root=fixture.root_value)
    fixture._events()
    proof={'bundle':deepcopy(fixture.bundle),'events':deepcopy(fixture.view_events)}
    g={**g,'viewReference':{'address':A(79001),'runtimeHash':H('reference runtime')},
        'externalCoverage':{'address':A(79002),'runtimeHash':H('external coverage runtime')}}
    sr=fixture.snapshot_value['history'][0];rr=fixture.root_value['history'][-1]
    artist=sr['source'][2][3];objects=[]
    defs=t.definitions();named={row['name']:row for row in defs}
    def coverage(label,role,png=None):
        spec=named['STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1' if role=='zip' else 'STREAM_REFERENCE_PNG_OBJECT_V1']
        fmt=named['STREAM_REFERENCE_NATIVE_FORMATS_V1']
        obj=(artist,spec['id'],schema_id('RAW_BYTES'),H(label+' bytes'),png or H(label+' sha'),
            H(label+' arweave'),99,schema_id('IANA:application/zip' if role=='zip' else 'IANA:image/png'),fmt['id'],fmt['hash'])
        key=w._hash('6529STREAM_EXTERNAL_OBJECT_V1',('uint256','address','address',t.OBJECT),
            (int(c['chainId']),g['externalCoverage']['address'],c['core'],obj))
        cov=(ZERO,key,artist,*obj[3:7],*(H(label+' evidence '+str(i)) for i in range(7)),schema_id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1'))
        cov=(w._hash('6529STREAM_EXTERNAL_COVERAGE_V1',('uint256','address',t.COVERAGE),
            (int(c['chainId']),g['externalCoverage']['address'],cov)),*cov[1:])
        objects.append({'objectHash':key,'identity':json_values(obj)});return cov
    env_cov=coverage('environment','zip')
    env=(env_cov[1],env_cov[0],ZERO,0,'Synthetic engine','1',H('engine'),'Synthetic tool','1',H('tool'),
        'engine.exe','tool.py',(('engine.exe',1,H('engine')),('tool.py',1,H('tool'))),
        (('C:/Windows/synthetic.dll',1,H('platform')),),'Windows','synthetic','AMD64',800,600,1,'srgb',True,
        schema_id('STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1'),'No browser execution claim')
    env_raw=w.environment_bytes(env);env=(*env[:2],keccak256(env_raw),len(env_raw),*env[4:])
    captures,samples=[],[]
    for index in ([0] if count==1 else [0,count-1]):
        output=w._v(t.OUTPUT,fixture.output_value['checkpoint']['outputs'][index])
        body=html[str(output[1])];png=H('PNG '+str(index));cov=coverage('capture'+str(index),'png',png)
        captures.append((output[1],output[2],output[8],output[9],len(body),body,cov[1],cov[0],
            '0x'+sha256(body).hexdigest(),(png,png),env[2],120))
        samples.append((index,output,cov))
    p=(w._v(t.SCOPE,fixture.bundle['scope']),(int(c['collectionId']),H('reference ID'),ZERO,0,sr['receipt'][0],1,
        ZERO,tuple(captures),env,'ipfs://original-reference',125,H('reason')))
    r=(sr['receipt'][1],(ZERO,ZERO,int(c['collectionId']),p[1][1],ZERO,1,ZERO,0,ZERO,p[1][4],1,
        A(79003),3,1,125,130,p[1][11],t.SCHEMA_HASH,t.PROFILE_HASH,t.CANON_HASH))
    f=(r[0],w._v(snapshot_types.RECEIPT,sr['receipt']),w._v(snapshot_types.SOURCE,sr['source']),
        rr['recordHash'],w._v(snapshot_types.ROOT_RECORD,rr['record']),w._v(snapshot_types.ROOT_BINDING,rr['binding']),
        env_cov,tuple(samples))
    value={'sourceRevision':t.SOURCE_REVISION,'dependencies':json_values((tuple(g[k]['address'] for k in w.DEPENDENCY_ROLES),
        tuple(g[k]['runtimeHash'] for k in w.DEPENDENCY_ROLES),int(c['chainId']),100000,500000,1000000,100000)),
        'definitions':[{'id':d['id'],'kind':str(d['kind']),'status':'1','hash':d['hash'],'bytes':'0x'+d['bytes'].hex()} for d in defs],
        'scope':json_values(p[0]),'selectedRecordHash':ZERO,'current':json_values(r),'history':[{'publication':json_values(p),
        'receipt':json_values(r),'source':json_values(f),'recordReturn':'0x','sourceReturn':'0x','payload':'0x',
        'environment':'0x'+env_raw.hex(),'objects':objects,'fileInventories':{
            'package':inventory(env[12],True,c,g),'platform':inventory(env[13],False,c,g)},'sourceProof':proof}],
        'lock':[ZERO,'1',H('class2 reference lock'),'132'] if locked else [ZERO,'0',ZERO,'0'],'events':[]}
    reseal(value,c,g)
    for i,desc in enumerate(w.expected_events(value,c,g)):
        number=30 if i==0 else 32
        value['events'].append({'timestamp':str(100+number),'log':{'address':desc['address'],'topics':list(desc['topics']),
            'data':desc['data'],'blockNumber':hex(number),'blockHash':H('reference block '+str(number)),
            'transactionHash':H('reference tx '+str(number)),'transactionIndex':'0x0','logIndex':'0x0','removed':False}})
    return value,c,g


from . import view_preservation_snapshot_types_v1 as snapshot_types


def second_reference(v,c,g):
    second=deepcopy(v['history'][0])
    second['publication'][1][1]=second['receipt'][1][3]=H('second reference ID')
    second['publication'][1][10]=second['receipt'][1][14]='133'
    second['receipt'][1][15]='133';v['history'].append(second);v['lock'][3]='136'
    oldlock=v['events'].pop();new=deepcopy(v['events'][0])
    new['timestamp']='133';new['log'].update(blockNumber='0x21',blockHash=H('block33'),transactionHash=H('tx33'))
    oldlock['timestamp']='136';oldlock['log'].update(blockNumber='0x24',blockHash=H('block36'),transactionHash=H('tx36'))
    v['events'] += [new,oldlock];reseal(v,c,g)
    return v


class ViewPreservationReferenceTests(unittest.TestCase):
    def test_exact_source_proof_terminal_finalized_and_burned_samples(self):
        for count,mode,burned in ((1,'disabled',False),(3,'not_required',True),(3,'finalized',False),(65,'legacy',False)):
            v,c,g=supplied(count,mode,burned)
            result=w.validate(v,c,g)
            self.assertEqual(result['recordCount'],'1')
            self.assertTrue(result['claims']['completePreservationProofRequired'])
            self.assertFalse(result['claims']['finalityProven'])

    def test_no_optional_source_proof_or_sample_only_shortcut(self):
        for mutation in ('absent','rows','manifest','events'):
            v,c,g=supplied();proof=v['history'][0]['sourceProof']
            if mutation=='absent':v['history'][0].pop('sourceProof')
            elif mutation=='rows':proof['bundle']['output']['checkpoint']['outputs'].pop(1)
            elif mutation=='manifest':proof['bundle']['output']['manifest']['parts']=[]
            else:proof['events'].pop()
            with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_rehashed_source_cannot_substitute_foreign_snapshot_or_root(self):
        for field in (1,2,3,4,5):
            v,c,g=supplied();s=v['history'][0]['source']
            if field==1:s[field][7]=H('foreign snapshot source')
            elif field==2:s[field][2][3]=H('foreign Artist')
            elif field==3:s[field]=H('foreign root')
            elif field==4:s[field][7]=H('foreign index hash')
            else:s[field][13]=H('foreign manifest index')
            reseal(v,c,g)
            with self.assertRaisesRegex(MuseumError,'snapshot/root source proof'):w.validate(v,c,g)

    def test_rehashed_sample_must_match_entire_output_row(self):
        v,c,g=supplied();v['history'][0]['source'][7][0][1][6]=H('different token data')
        reseal(v,c,g)
        with self.assertRaisesRegex(MuseumError,'complete checkpoint row'):w.validate(v,c,g)

    def test_first_last_ordinal_denominator_and_order(self):
        for mutation in ('missing','reverse','middle'):
            v,c,g=supplied();row=v['history'][0]
            if mutation=='missing':row['source'][7].pop();row['publication'][1][7].pop()
            elif mutation=='reverse':row['source'][7].reverse();row['publication'][1][7].reverse()
            else:row['source'][7][1][0]='1'
            reseal(v,c,g)
            with self.assertRaisesRegex(MuseumError,'denominator|complete checkpoint row'):w.validate(v,c,g)

    def test_rehashed_html_and_repeated_png_hashes_cannot_drift(self):
        for mutation in ('html','sha','repeat','time','environment'):
            v,c,g=supplied();cap=v['history'][0]['publication'][1][7][0]
            if mutation=='html':cap[5]='0x'+b'changed'.hex()
            elif mutation=='sha':cap[8]=H('different SHA')
            elif mutation=='repeat':cap[9][1]=H('different PNG')
            elif mutation=='time':cap[11]='131'
            else:cap[10]=H('different environment')
            reseal(v,c,g)
            with self.assertRaisesRegex(MuseumError,'HTML/sample facts'):w.validate(v,c,g)

    def test_definition_bytes_status_and_profile_pin_are_exact(self):
        for mutation in ('status','bytes','revision'):
            v,c,g=supplied()
            if mutation=='status':v['definitions'][0]['status']='2'
            elif mutation=='bytes':v['definitions'][0]['bytes']+='20'
            else:v['sourceRevision']='e8a569b36927ed7f711a14a30ce5b09690694dd0'
            with self.assertRaisesRegex(MuseumError,'native definition|revision/graph'):w.validate(v,c,g)

    def test_native_abi_padding_and_tail_canonicality(self):
        for field in ('recordReturn','sourceReturn','payload'):
            v,c,g=supplied();v['history'][0][field]+='00'*32
            with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_payload_normalization_does_not_normalize_original_receipt(self):
        v,c,g=supplied();row=v['history'][0]
        decoded=w.decode_payload(row['payload'])
        self.assertEqual(decoded[3][1][6],ZERO)
        self.assertEqual(tuple(decoded[4][1][i] for i in (0,1,6)),(ZERO,ZERO,ZERO))
        self.assertEqual((decoded[4][1][7],decoded[4][1][15]),(0,0))
        row['receipt'][1][15]='0';reseal(v,c,g)
        with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_archive_object_role_and_denominator(self):
        for mutation in ('role','extra','missing'):
            v,c,g=supplied();objects=v['history'][0]['objects']
            if mutation=='role':objects[0]['identity'][7]=schema_id('IANA:image/png')
            elif mutation=='extra':objects.append(deepcopy(objects[0]))
            else:objects.pop()
            with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_inventory_bytes_part_identity_and_environment_join(self):
        for mutation in ('payload','part','rows'):
            v,c,g=supplied();item=v['history'][0]['fileInventories']['package']
            if mutation=='payload':item['payload']+='20'
            elif mutation=='part':item['parts'][0]['partId']=H('foreign part')
            else:item['rows'][0][1]='2'
            with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_reference_event_bijection_and_time(self):
        for mutation in ('missing','duplicate','time','record','removed'):
            v,c,g=supplied()
            if mutation=='missing':v['events'].pop()
            elif mutation=='duplicate':v['events'].append(deepcopy(v['events'][0]))
            elif mutation=='time':v['events'][0]['timestamp']='129'
            elif mutation=='record':v['events'][0]['log']['topics'][3]=H('wrong original')
            else:v['events'][0]['log']['removed']=True
            with self.assertRaises(MuseumError):w.validate(v,c,g)

    def test_lock_is_optional_but_cannot_lock_another_record(self):
        v,c,g=supplied(locked=False);self.assertIsNone(w.validate(v,c,g)['componentDataHash'])
        v,c,g=supplied();v['lock'][0]=H('foreign lock');reseal(v,c,g)
        v['lock'][0]=H('foreign lock')
        for event,desc in zip(v['events'],w.expected_events(v,c,g)):event['log']['data']=desc['data']
        with self.assertRaisesRegex(MuseumError,'lock/head/time'):w.validate(v,c,g)

    def test_complete_history_preserves_older_selected_record_and_final_head_lock(self):
        v,c,g=supplied();second_reference(v,c,g)
        result=w.validate(v,c,g)
        self.assertEqual(result['recordCount'],'2');self.assertNotEqual(result['selectedRecordHash'],result['head'])
        v['history'][1]['publication'][1][1]=v['history'][0]['publication'][1][1]
        v['history'][1]['receipt'][1][3]=v['history'][0]['receipt'][1][3];reseal(v,c,g)
        with self.assertRaisesRegex(MuseumError,'lineage/receipt'):w.validate(v,c,g)

    def test_snapshot_supersession_before_reference_fails_but_after_is_historical(self):
        from .test_view_preservation_snapshot_wire_v1 import reseal as seal_snapshot
        from . import view_preservation_snapshot_wire_v1 as sw
        for at,accepted in ((129,False),(131,True)):
            v,c,g=supplied();proof=v['history'][0]['sourceProof'];snap=proof['bundle']['snapshot']
            snap['lock']=[ZERO,'0',ZERO,'0']
            later=deepcopy(snap['history'][0]);later['publication'][1]=H('later snapshot')
            later['publication'][8]=later['receipt'][13]=str(at);snap['history'].append(later)
            seal_snapshot(snap,c,g)
            proof['events']=[e for e in proof['events'] if e['log']['topics'][0]!=sw.LOCKED]
            desc=sw.expected_events(snap,c,g)[1]
            proof['events'].append({'timestamp':str(at),'log':{'address':desc['address'],'topics':list(desc['topics']),
                'data':desc['data'],'blockNumber':hex(at-100),'blockHash':H('later block'+str(at)),
                'transactionHash':H('later tx'+str(at)),'transactionIndex':'0x0','logIndex':'0x0','removed':False}})
            proof['events'].sort(key=w._position)
            if accepted:self.assertEqual(w.validate(v,c,g)['recordCount'],'1')
            else:
                with self.assertRaisesRegex(MuseumError,'snapshot missing or superseded'):w.validate(v,c,g)

    def test_source_and_reference_events_must_share_block_identity(self):
        v,c,g=supplied();event=v['events'][0]
        source=v['history'][0]['sourceProof']['events'][-1]
        event['log']['blockNumber']=source['log']['blockNumber']
        event['log']['transactionIndex']='0x7';event['log']['logIndex']='0x7'
        with self.assertRaisesRegex(MuseumError,'block or transaction conflict'):w.validate(v,c,g)

    def test_adoption_currentness_is_per_view_scope(self):
        v,c,g=supplied(foreign_later=True)
        self.assertEqual(w.validate(v,c,g)['recordCount'],'1')
        v,c,g=supplied(later_adoption=True)
        with self.assertRaisesRegex(MuseumError,'adoption superseded'):w.validate(v,c,g)

    def test_individually_consistent_source_proofs_cannot_contradict_each_other(self):
        v,c,g=supplied();second_reference(v,c,g)
        proof=v['history'][1]['sourceProof']
        for event in proof['events']:
            if event['log']['blockNumber']=='0x7':event['log']['blockHash']=H('contradictory snapshot block')
        subgraph={key:g[key] for key in w.preservation.GRAPH_KEYS}
        w.preservation.validate_bundle(proof['bundle'],c,subgraph)
        w.preservation.validate_event_join(proof['bundle'],c,subgraph,proof['events'])
        with self.assertRaisesRegex(MuseumError,'global source/publication block'):w.validate(v,c,g)

    def test_global_log_index_is_unique_across_source_and_reference_transactions(self):
        v,c,g=supplied();original=v['history'][0]['sourceProof']['events'][-1]
        for tx in (original['log']['transactionIndex'],hex(int(original['log']['transactionIndex'],16)+1)):
            other=deepcopy(original);other['log']['address']=g['viewReference']['address']
            other['log']['transactionIndex']=tx
            if tx!=original['log']['transactionIndex']:other['log']['transactionHash']=H('another same-block tx')
            with self.assertRaisesRegex(MuseumError,'global source/publication block'):
                w._event_coherence([original,other],c)

    def test_peer_record_cannot_hide_source_supersession_from_earlier_reference(self):
        from .test_view_preservation_snapshot_wire_v1 import reseal as seal_snapshot
        from .test_view_preservation_root_wire_v1 import reseal as seal_root
        from . import view_preservation_snapshot_wire_v1 as sw,view_preservation_root_wire_v1 as rw
        v,c,g=supplied();second_reference(v,c,g)
        for row in v['history']:
            row['sourceProof']['bundle']['snapshot']['lock']=[ZERO,'0',ZERO,'0']
            row['sourceProof']['events']=[e for e in row['sourceProof']['events'] if e['log']['topics'][0]!=sw.LOCKED]
        row=v['history'][1];proof=row['sourceProof'];snap=proof['bundle']['snapshot'];roots=proof['bundle']['root']
        later=deepcopy(snap['history'][0]);later['publication'][1]=H('new snapshot before both references')
        later['publication'][8]=later['receipt'][13]='129';snap['history'].append(later);seal_snapshot(snap,c,g)
        snap['selectedRecordHash']=later['receipt'][0]
        newer=deepcopy(roots['history'][0]);record=newer['record']
        record[0][2:4]=[later['receipt'][0],later['receipt'][3]]
        record[3:5]=[later['receipt'][5],later['receipt'][7]]
        record[16]=H('new root consent');record[17]='129';roots['history'].append(newer);seal_root(roots,c,g)
        roots['selectedRecordHash']=newer['recordHash']
        row['publication'][1][4:6]=[later['receipt'][0],later['receipt'][3]]
        row['receipt'][1][9:11]=[later['receipt'][0],later['receipt'][3]]
        row['source'][1:6]=[deepcopy(later['receipt']),deepcopy(later['source']),newer['recordHash'],
            deepcopy(newer['record']),deepcopy(newer['binding'])]
        descriptors=[sw.expected_events(snap,c,g)[-1],*rw.expected_events(roots,c,g)[-2:]]
        for ordinal,desc in enumerate(descriptors):
            proof['events'].append({'timestamp':'129','log':{'address':desc['address'],'topics':list(desc['topics']),
                'data':desc['data'],'blockNumber':'0x1d','blockHash':H('shared new source block'),
                'transactionHash':H('shared new source tx'),'transactionIndex':'0x0','logIndex':hex(ordinal),'removed':False}})
        proof['events'].sort(key=w._position);reseal(v,c,g)
        subgraph={key:g[key] for key in w.preservation.GRAPH_KEYS}
        # Both supplied source proofs independently validate, including their own
        # complete denominators. Their union discloses first proof's omission.
        for item in v['history']:
            w.preservation.validate_bundle(item['sourceProof']['bundle'],c,subgraph)
            w.preservation.validate_event_join(item['sourceProof']['bundle'],c,subgraph,item['sourceProof']['events'])
        with self.assertRaisesRegex(MuseumError,'snapshot missing or superseded'):w.validate(v,c,g)

    def test_offline_and_no_authority_browser_or_finality_claim(self):
        v,c,g=supplied()
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):result=w.validate(v,c,g)
        for claim in ('rpcProvenanceAuthenticated','historicalAuthorityReauthorized','freshNativeObservationProven',
                'browserExecutionProven','zipMembershipVerified','archiveCurrentPairProven','governanceExecutionProven',
                'finalityProven','completeAcquisition'):
            self.assertFalse(result['claims'][claim])


if __name__ == '__main__':unittest.main()
