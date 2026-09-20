"""Synthetic supplied commitments, not runtime execution or public-chain evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import scoped_static_snapshot_wire as w
from .canonical import MuseumError, keccak256, schema_id, subject_id, hex_bytes
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values
from .native_finality_wire import from_json, _hash
from .scoped_static_types import *
from .scoped_static_source_reads import ScopedStaticSourceReads, SCOPE_SIGNATURE


def H(value): return schema_id('scoped snapshot test ' + str(value))
def A(value): return '0x' + format(value, '040x')


def jsonify(value):
    if isinstance(value, dict): return {k:jsonify(v) for k,v in value.items()}
    if isinstance(value, (list,tuple)): return [jsonify(v) for v in value]
    return json_values(value)


def supplied(scope_type=1, count=1, *, context=None, graph=None, artist=None,
             recorded_at=200, locked_at=201):
    if scope_type == 1: count = 1
    context = deepcopy(context) if context is not None else {'chainId': '31337', 'core': A(1), 'collectionId': '7', 'tokenId': '41',
               'timestamp': '1000', 'blockNumber': '10', 'blockHash': H('block')}
    names = (*w.DEPENDENCY_KEYS, 'tokenInventory', 'scopedSnapshot', 'artist')
    graph = deepcopy(graph) if graph is not None else {name: {'address': A(i+1), 'runtimeHash': H('code'+name)} for i, name in enumerate(names)}
    core, cid, chain = context['core'], int(context['collectionId']), int(context['chainId'])
    target = int(context['tokenId'])
    tokens = tuple(range(target, target+count))
    part_bytes = encode(('uint256',)*count, tokens)
    scope = (scope_type, cid, target if scope_type == 1 else 0, ZERO)
    member = {'publication': None, 'progress': None, 'metadataRecord': None, 'manifestBytes': None,
              'parts': [], 'tokens': tokens, 'identities': [(True, cid, i+1, False) for i in range(count)],
              'lifecycles': [2]*count, 'inventoryTokens': [] if scope_type == 1 else tokens, 'progressHistory': []}
    manifest_hash = record_hash = ZERO
    if scope_type != 1:
        chunks = tuple(part_bytes[i:i+8192] for i in range(0, len(part_bytes), 8192))
        raw = encode(MEMBERSHIP_MANIFEST, (1, chain, core, cid, scope_type, count, keccak256(part_bytes), tuple(keccak256(c) for c in chunks)))
        manifest_hash = keccak256(raw)
        record = (schema_id('SCOPE_MEMBERSHIP'), subject_id('collection', str(chain), core, str(cid)),
                  (1, hex_bytes(manifest_hash), w.MEMBERSHIP_CANON), 'ipfs://membership', w.MEMBERSHIP_SCHEMA,
                  ZERO, (0, b'', ZERO), 100)
        record_hash = generic_hash(chain, graph['metadata']['address'], core, cid, A(80), record)
        receipt = (cid, A(80), 7, 100, 0, H('metadata-chain'), ZERO, w.MEMBERSHIP_SCHEMA_HASH, w.MEMBERSHIP_CANON_HASH)
        publication = (record_hash, manifest_hash, w.MEMBERSHIP_SCHEMA, w.MEMBERSHIP_CANON, A(81), keccak256(b'\x00'+raw), 100, receipt)
        scope = (scope_type, cid, 0, _hash('6529STREAM_SCOPE_MEMBERSHIP_ID_V1', ('uint256','address','uint256','uint8','bytes32'), (chain,core,cid,scope_type,record_hash)))
        member.update(publication=publication, progress=(True,True,count,count,len(chunks),len(chunks)),
            metadataRecord=record, manifestBytes='0x'+raw.hex(),
            parts=[{'pointer':A(100+i),'codeHash':keccak256(b'\x00'+c),'runtime':'0x'+(b'\x00'+c).hex()} for i,c in enumerate(chunks)],
            progressHistory=[(i+1,min((i+1)*256,count)) for i in range(len(chunks))])
    facts = (w.scope_subject(scope,context),manifest_hash,record_hash,count,keccak256(part_bytes),ZERO,0,ZERO)
    facts = (*facts[:5],w.membership_hash(facts,scope,context,graph),*facts[6:])
    member['facts'] = facts
    sources = (core,graph['router']['address'],graph['metadata']['address'],A(92),ZERO_ADDRESS,ZERO_ADDRESS)
    hashes = (graph['core']['runtimeHash'],graph['router']['runtimeHash'],graph['metadata']['runtimeHash'],H('coordinator-code'),ZERO,ZERO)
    selected = (A(90),H('registry-code'),H('renderer-key'),A(91),H('renderer-code'),H('renderer-id'),H('renderer-version'),H('context'),H('schema'),H('readset'),H('registration'))
    rows = [(token,H('config'+str(token)),H('confighash'+str(token)),H('source'+str(token)),H('rawsource'+str(token)),selected,sources,hashes) for token in tokens]
    folded = ZERO
    for i,row in enumerate(rows):
        folded = _hash('6529STREAM_STATIC_SELECTION_CHAIN_V1', ('bytes32','uint256','bytes32'), (folded,i,w.selection_row_hash(row,context,graph)))
    selection_plan = (scope,facts[5],H('collection-state'),count,count,folded)
    selection_id = w.selection_id(selection_plan,context,graph)
    content = (selection_id,keccak256(encode((SELECTION_PLAN,),(selection_plan,))),scope,count,count,H('leaf-chain'),H('content-root'),H('output-root'))
    artist = tuple(artist) if artist is not None else (True,graph['artist']['address'],graph['artist']['runtimeHash'],H('artist'),1,H('binding'),A(93),H('identity'),H('acceptance'),120,130,H('artist-snapshot'))
    outputs = (H('checkpoint'),keccak256(encode((CONTENT_PLAN,),(content,))),H('artifact'),H('coverage'),artist[3],content[6],content[7],H('manifest'),scope,count,480+288*count)
    deps = (tuple(graph[k]['address'] for k in w.DEPENDENCY_KEYS),tuple(graph[k]['runtimeHash'] for k in w.DEPENDENCY_KEYS),chain,100000,1000000,1000000)
    policy_plan = _hash('6529STREAM_COORDINATOR_INVENTORY_PLAN_V1',('uint256','address','address','bytes32','address','bytes32',SCOPE,MEMBERSHIP_FACTS),
        (chain,graph['coordinatorInventory']['address'],core,graph['core']['runtimeHash'],graph['scopeMembership']['address'],graph['scopeMembership']['runtimeHash'],scope,facts))
    policy = (A(92),H('coordinator-code'),0,True,H('module-version'),H('module-manifest'),H('module-schema'),H('deployment'),H('policy'),A(94),1,H('salt'),ZERO)
    component = _hash('6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1',('uint256','address','address',SCOPE,'bytes32','address','uint32','bytes32'),(chain,core,policy[0],scope,policy[8],policy[9],policy[10],policy[11]))
    policy = (*policy[:-1],component)
    policy_chain = _hash('6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V1',('uint256',('address',)*4,('bytes32',)*4,SCOPE,'bytes32','bytes32','uint256'),
        (chain,tuple(deps[0][i] for i in (0,1,5,10)),tuple(deps[1][i] for i in (0,1,5,10)),scope,policy_plan,H('inventory'),1))
    policy_chain = _hash('6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V1',('bytes32','uint256',COORDINATOR_POLICY),(policy_chain,0,policy))
    source = (scope,facts,artist,selection_plan,content,outputs,(policy_plan,H('inventory'),policy_chain,1,True,(policy,)))
    sh = w.source_hash(source,deps,context,graph)
    publication = (scope,H('snapshot-id'),ZERO,0,H('output-record'),policy_plan,sh,'ipfs://snapshot',recorded_at,H('reason'))
    receipt = (ZERO,facts[0],ZERO,1,ZERO,ZERO,0,sh,A(80),7,1,8,2,recorded_at,w.SNAPSHOT_SCHEMA_HASH,w.SNAPSHOT_PROFILE_HASH,w.SOLIDITY_ABI_HASH)
    raw = w.snapshot_payload(publication,receipt,source,deps,context,graph)
    receipt = (*receipt[:5],keccak256(raw),len(raw),*receipt[7:])
    receipt = (w.snapshot_hash(publication,receipt,context,graph),*receipt[1:])
    receipt = (*receipt[:4],w.snapshot_chain(scope,ZERO,receipt,context,graph),*receipt[5:])
    bundle = {'membership':member,'selection':{'id':selection_id,'plan':selection_plan,'rows':rows},
              'snapshot':{'dependencies':deps,'history':[{'publication':publication,'receipt':receipt,'payload':'0x'+raw.hex()}],
                          'head':receipt[0],'lock':(receipt[0],1,H('action'),locked_at)}}
    statement = (scope,H('Core-hash-only'),content[6],count,H('root-schema'),receipt[5],H('reference'),
                 (H('root'),receipt[0],H('reference-record'),H('intent'),ZERO,H('interview'),H('rights'),H('description'),H('render-critical'),H('bundle')),
                 (),0,0,0)
    return jsonify(bundle),context,graph,json_values(statement)


def resnapshot(bundle, context, graph, statement, *, source=None, uri=None, append=False):
    """Rehash exact supplied publication after a controlled semantic mutation."""
    old = bundle['snapshot']['history'][-1]
    previous = from_json(SNAPSHOT_RECEIPT, old['receipt'])
    source = source or decode(SNAPSHOT_ENVELOPE, hex_bytes(old['payload']), maximum=w.MAX_PAYLOAD)[-1]
    deps = from_json(SNAPSHOT_DEPS, bundle['snapshot']['dependencies'])
    p = list(from_json(SNAPSHOT_PUBLICATION, old['publication']))
    r = list(previous)
    if append:
        p[1:4] = [H('snapshot revision '+str(previous[3]+1)), previous[0], previous[3]]
        r[2:4] = [previous[0], previous[3]+1]
        r[13] += 1
    p[6] = r[7] = w.source_hash(source,deps,context,graph)
    if uri is not None: p[7] = uri
    raw = w.snapshot_payload(tuple(p),tuple(r),source,deps,context,graph)
    r[5:7] = [keccak256(raw),len(raw)]
    r[0] = w.snapshot_hash(tuple(p),tuple(r),context,graph)
    r[4] = w.snapshot_chain(p[0], previous[4] if append else ZERO, tuple(r), context, graph)
    entry = jsonify({'publication':p,'receipt':r,'payload':'0x'+raw.hex()})
    if append: bundle['snapshot']['history'].append(entry)
    else: bundle['snapshot']['history'][-1] = entry
    bundle['snapshot']['head'] = r[0]
    bundle['snapshot']['lock'] = json_values((r[0],r[3],H('action'),max(r[13],int(bundle['snapshot']['lock'][3]))))
    statement[7][1],statement[5] = r[0],r[5]


def reselection(bundle, context, graph):
    source=list(decode(SNAPSHOT_ENVELOPE,hex_bytes(bundle['snapshot']['history'][-1]['payload']),maximum=w.MAX_PAYLOAD)[-1])
    p=list(from_json(SELECTION_PLAN,bundle['selection']['plan'])); folded=ZERO
    for i,row in enumerate(bundle['selection']['rows']):
        h=w.selection_row_hash(from_json(SELECTION_ROW,row),context,graph)
        folded=_hash('6529STREAM_STATIC_SELECTION_CHAIN_V1',('bytes32','uint256','bytes32'),(folded,i,h))
    p[5]=folded
    bundle['selection']['plan']=json_values(tuple(p))
    bundle['selection']['id']=w.selection_id(tuple(p),context,graph)
    source[3]=tuple(p)
    content=list(source[4]);content[:2]=[bundle['selection']['id'],keccak256(encode((SELECTION_PLAN,),(tuple(p),)))]
    source[4]=tuple(content)
    output=list(source[5]);output[1]=keccak256(encode((CONTENT_PLAN,),(tuple(content),)))
    source[5]=tuple(output)
    return source


class ScopedSnapshotWireTest(unittest.TestCase):
    def test_exact_definition_pins(self):
        self.assertEqual((len(w.SNAPSHOT_SCHEMA_BYTES),w.SNAPSHOT_SCHEMA_HASH),(6108,'0x499f3da8e9edac9c6fc724c2416768ec04333b31a128aed36b16b5364d91c68f'))
        self.assertEqual((len(w.SNAPSHOT_PROFILE_BYTES),w.SNAPSHOT_PROFILE_HASH),(1454,'0xa8863cf6dac274c227895b49ab106c43176ce1f3bc9120e81229d16027352135'))
        self.assertEqual((len(w.MEMBERSHIP_SCHEMA_BYTES),w.MEMBERSHIP_SCHEMA_HASH),(2047,'0x70c79fbabc4dc32259b4f3958da52f8c9d27814e9202e1ab2b1c0b75acd3d2cb'))
        self.assertEqual((len(w.MEMBERSHIP_CANON_BYTES),w.MEMBERSHIP_CANON_HASH),(1309,'0x3a8f6aa2c183ea43dff145064f8175f2a7c4bc7c2b65633d0fdfdc36fdeaab5e'))

    def test_token_release_season_offline(self):
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            for kind,count in ((1,1),(2,3),(3,257)):
                args=supplied(kind,count)
                result=w.validate(*args)
                self.assertEqual(len(result['tokens']),count)
                self.assertFalse(result['claims']['fullRenderedBytesReconstructed'])
                events=w.expected_events(*args)
                self.assertEqual(sum(e['kind']=='selection_appended' for e in events),count)
                self.assertEqual(events[-1]['kind'],'snapshot_locked')

    def test_later_burn_preserves_original_snapshot(self):
        b,c,g,s=supplied(2,2)
        before=w.validate(b,c,g,s)
        b['membership']['identities'][0][3]=True
        b['membership']['lifecycles'][0]='3'
        self.assertEqual(w.validate(b,c,g,s)['selectedReceipt'],before['selectedReceipt'])

    def test_view_not_original_static(self):
        b,c,g,s=supplied(2,2);s[0][0]='4'
        with self.assertRaisesRegex(MuseumError,'scope unsupported'):w.validate(b,c,g,s)

    def test_membership_corruption_and_order(self):
        for change in ('part','order','inventory','identity','progress'):
            b,c,g,s=supplied(2,257);m=b['membership']
            if change=='part':m['parts'][1]['runtime']='0x0001'
            if change=='order':m['tokens'][0],m['tokens'][1]=m['tokens'][1],m['tokens'][0]
            if change=='inventory':m['inventoryTokens'][0]='999'
            if change=='identity':m['identities'][0][1]='8'
            if change=='progress':m['progressHistory'][0][1]='255'
            with self.assertRaises(MuseumError):w.validate(b,c,g,s)

    def test_original_membership_authority_and_definitions(self):
        for index,value in ((2,'1'),(6,H('Artist-authority')),(7,H('wrong-schema'))):
            b,c,g,s=supplied(2,2);b['membership']['publication'][7][index]=value
            with self.assertRaisesRegex(MuseumError,'original authority'):w.validate(b,c,g,s)

    def test_selection_permutation_and_runtime_conflict(self):
        b,c,g,s=supplied(2,2);b['selection']['rows'].reverse()
        with self.assertRaisesRegex(MuseumError,'original row'):w.validate(b,c,g,s)
        b,c,g,s=supplied(2,2);b['selection']['rows'][1][5][4]=H('other-runtime')
        with self.assertRaisesRegex(MuseumError,'runtime contradiction'):w.validate(b,c,g,s)

    def test_snapshot_trailing_bytes_and_source_tamper(self):
        b,c,g,s=supplied();b['snapshot']['history'][0]['payload']+='00'*32
        with self.assertRaises(MuseumError):w.validate(b,c,g,s)
        b,c,g,s=supplied();b['snapshot']['history'][0]['receipt'][7]=H('bad-source')
        with self.assertRaises(MuseumError):w.validate(b,c,g,s)

    def test_receipt_domain_authority_and_lock(self):
        for change in ('domain','authority','display','chain','lock'):
            b,c,g,s=supplied();r=b['snapshot']['history'][0]['receipt']
            if change=='domain':c['chainId']='1'
            if change=='authority':r[9]='1'
            if change=='display':r[11]='3'
            if change=='chain':r[4]=H('bad-chain')
            if change=='lock':b['snapshot']['lock'][1]='2'
            with self.assertRaises(MuseumError):w.validate(b,c,g,s)

    def test_statement_scope_and_original_snapshot(self):
        for index in (2,3,5):
            b,c,g,s=supplied();s[index]='2' if index==3 else H('other')
            with self.assertRaisesRegex(MuseumError,'statement/content'):w.validate(b,c,g,s)
        b,c,g,s=supplied();s[7][1]=H('unretained')
        with self.assertRaisesRegex(MuseumError,'selection/history'):w.validate(b,c,g,s)

    def test_content_crossjoin(self):
        b,c,g,s=supplied();r=w.validate(b,c,g,s);source=r['source']
        content={'contentPlan':source[4],'outputManifest':source[5],
                 'manifestRecordHash':b['snapshot']['history'][0]['publication'][4],
                 'selectionRowHashes':r['selectionRowHashes'],'tokenIds':r['tokens']}
        w.validate(b,c,g,s,content)
        content['selectionRowHashes']=[H('bad')]
        with self.assertRaisesRegex(MuseumError,'verified output'):w.validate(b,c,g,s,content)

    def test_native_empty_and_invalid_snapshot_uris(self):
        for uri in ('','https://host/x','ipfs://x','ar://x'):
            b,c,g,s=supplied();resnapshot(b,c,g,s,uri=uri);w.validate(b,c,g,s)
        for uri in ('https:///x','ipfs://','http://x','ipfs://x\n','ar://x\x7f'):
            b,c,g,s=supplied();resnapshot(b,c,g,s,uri=uri)
            with self.assertRaisesRegex(MuseumError,'manifest URI'):w.validate(b,c,g,s)

    def test_full_snapshot_revision_chain(self):
        b,c,g,s=supplied(2,2);resnapshot(b,c,g,s,append=True)
        self.assertEqual(w.validate(b,c,g,s)['selectedReceipt'][3],'2')
        self.assertEqual(sum(e['kind']=='snapshot_published' for e in w.expected_events(b,c,g,s)),2)
        b['snapshot']['history'].pop(0)
        with self.assertRaisesRegex(MuseumError,'publication'):w.validate(b,c,g,s)

    def test_rehashed_policy_selection_contradiction(self):
        b,c,g,s=supplied(2,3)
        b['selection']['rows'][1][6][3]=A(95)
        b['selection']['rows'][1][7][3]=H('B code')
        source=reselection(b,c,g)
        resnapshot(b,c,g,s,source=tuple(source))
        with self.assertRaisesRegex(MuseumError,'coordinator inventory/selection'):w.validate(b,c,g,s)

    def test_original_coordinator_recurrence(self):
        b,c,g,s=supplied(2,3)
        b['selection']['rows'][1][6][3]=A(95)
        b['selection']['rows'][1][7][3]=H('B code')
        source=reselection(b,c,g)
        e=list(source[6]);p=list(e[5][0]);p[:3]=[A(95),H('B code'),1]
        p[12]=_hash('6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1',('uint256','address','address',SCOPE,'bytes32','address','uint32','bytes32'),
            (int(c['chainId']),c['core'],p[0],source[0],p[8],p[9],p[10],p[11]))
        e[3]=2;e[5]=(*e[5],tuple(p))
        d=from_json(SNAPSHOT_DEPS,b['snapshot']['dependencies'])
        chain=_hash('6529STREAM_ORIGINAL_COORDINATOR_POLICIES_V1',('uint256',('address',)*4,('bytes32',)*4,SCOPE,'bytes32','bytes32','uint256'),
            (int(c['chainId']),tuple(d[0][i] for i in (0,1,5,10)),tuple(d[1][i] for i in (0,1,5,10)),source[0],e[0],e[1],2))
        for i,p in enumerate(e[5]):chain=_hash('6529STREAM_ORIGINAL_COORDINATOR_POLICY_APPEND_V1',('bytes32','uint256',COORDINATOR_POLICY),(chain,i,p))
        e[2]=chain;source[6]=tuple(e)
        resnapshot(b,c,g,s,source=tuple(source))
        w.validate(b,c,g,s)


class ReadHarness(ScopedStaticSourceReads):
    """Unit harness for exact getter selection; no public history/provenance claim."""
    def __init__(self, args):
        self.b,self.a,self.graph,self.s=args
        self.a=self.a | {key:row['address'] for key,row in self.graph.items()}
        self.scope=from_json(SCOPE,self.s[0]);self.requested=[]
        self.codes={p['pointer']:p['runtime'] for p in self.b['membership']['parts']}
        self.reader=self
    def code(self,pointer):return self.codes[pointer]
    def _one(self,target,sig,output,inputs=(),values=(),**kwargs):
        return self._read(target,sig,(output,),inputs,values,**kwargs)[0]
    def _read(self,target,sig,outputs,inputs=(),values=(),**kwargs):
        self.requested.append(sig);b=self.b;m=b['membership'];snap=b['snapshot'];selected=b['selection']
        prefix=sig.split('(')[0]
        if prefix=='dependencies': result=(from_json(SNAPSHOT_DEPS,snap['dependencies']),)
        elif prefix=='snapshotCount':result=(len(snap['history']),)
        elif prefix=='snapshotAt':result=(snap['history'][values[1]]['receipt'][0],)
        elif prefix in ('snapshotRecord','snapshotPayload'):
            row=next(r for r in snap['history'] if r['receipt'][0]==values[0])
            result=(from_json(SNAPSHOT_PUBLICATION,row['publication']),from_json(SNAPSHOT_RECEIPT,row['receipt'])) if prefix=='snapshotRecord' else (hex_bytes(row['payload']),)
        elif prefix=='currentSnapshot':result=(from_json(SNAPSHOT_RECEIPT,snap['history'][-1]['receipt']),)
        elif prefix=='snapshotLock':result=(from_json(SNAPSHOT_LOCK,snap['lock']),)
        elif prefix=='checkpoint':result=(from_json(SELECTION_PLAN,selected['plan']),)
        elif prefix=='selectionAt':result=(from_json(SELECTION_ROW,selected['rows'][values[1]]),)
        elif prefix=='scopeMembershipPublication':result=(from_json(MEMBERSHIP_PUBLICATION,m['publication']),)
        elif prefix=='scopeMembershipProgress':result=(from_json(MEMBERSHIP_PROGRESS,m['progress']),)
        elif prefix=='collectionRecord':result=(from_json(w.METADATA_RECORD,m['metadataRecord']),from_json(MEMBERSHIP_PUBLICATION,m['publication'])[7])
        elif prefix=='recordHashAt':result=(m['publication'][0],)
        elif prefix=='recordPayload':result=(m['publication'][4],hex_bytes(m['manifestBytes']))
        elif prefix=='chunk':
            raw=hex_bytes(m['manifestBytes'])
            if values[0]==keccak256(raw):result=(m['publication'][4],len(raw))
            else:
                p=next(p for p in m['parts'] if keccak256(hex_bytes(p['runtime'])[1:])==values[0])
                result=(p['pointer'],len(hex_bytes(p['runtime']))-1)
        elif prefix=='scopeTokenAt':result=(int(m['tokens'][values[1]]),)
        elif prefix in ('tokenCollectionIdentity','tokenLifecycle'):
            i=m['tokens'].index(str(values[0]))
            result=from_json(('bool','uint256','uint256','bool'),m['identities'][i]) if prefix=='tokenCollectionIdentity' else (int(m['lifecycles'][i]),)
        elif prefix=='collectionTokenBySerial':
            i=next(i for i,r in enumerate(m['identities']) if int(r[2])==values[1]);result=(int(m['inventoryTokens'][i]),)
        else:raise AssertionError('unexpected current/historical read '+sig)
        return decode(outputs,encode(outputs,result),maximum=kwargs.get('maximum',65536))
    def _carrier(self,pointer,digest,maximum):
        raw=hex_bytes(self.b['membership']['manifestBytes'])
        if digest!=keccak256(b'\0'+raw):raise MuseumError('harness carrier mismatch')
        return raw
    def _history(self,address,topics):
        return {'logs':[e for e in w.expected_events(self.b,self.a,self.graph,self.s)
                        if e['address']==address and e['topics'][0] in (topics[0] if isinstance(topics[0],list) else [topics[0]])]}


class ScopedSnapshotSourceReadsTest(unittest.TestCase):
    def test_original_read_groups_three_scopes(self):
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            for kind in (1,2,3):
                h=ReadHarness(supplied(kind,3))
                got=h._snapshot_membership(h.s,None)
                self.assertEqual(got,h.b)
                self.assertFalse(any('requireCurrent' in q or 'requireScopeMembership' in q for q in h.requested))
                self.assertEqual(any('collectionTokenBySerial' in q for q in h.requested),kind!=1)
    def test_read_later_burn_preserves_payload(self):
        args=supplied();args[0]['membership']['identities'][0][3]=True;args[0]['membership']['lifecycles'][0]='3'
        h=ReadHarness(args)
        self.assertEqual(h._snapshot_membership(h.s,None)['snapshot'],h.b['snapshot'])
    def test_original_read_hash_disagreement(self):
        args=supplied();args[0]['snapshot']['history'][0]['payload']+='00'
        h=ReadHarness(args)
        with self.assertRaisesRegex(MuseumError,'original payload'):h._snapshot_membership(h.s,None)


if __name__=='__main__':unittest.main()
