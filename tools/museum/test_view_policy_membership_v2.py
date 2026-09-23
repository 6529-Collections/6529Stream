"""Synthetic native VIEW membership/source tuples, never runtime acceptance."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import view_policy_membership_v2 as w
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, subject_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values
from .native_finality_wire import from_json, _hash
from .scoped_static_source_reads import _json


def A(n): return '0x' + format(n, '040x')
def H(s): return schema_id('VIEW membership test ' + str(s))


def reseal(value, context, graph, binding):
    """Rebuild native policy commitments after a controlled fixture mutation."""
    s = value['sourceSet']; e = list(from_json(w.POLICY_EVIDENCE, s['evidence']))
    b = list(from_json(w.VIEW_BINDING, binding)); scope = b[7]
    d = from_json(w.POLICY_DEPS, s['dependencies'])
    e[0] = w.policy_plan(scope, b[8], d, context)
    rows = []
    for raw in e[5]:
        row = list(raw); row[12] = w.policy_component(row, scope, context); rows.append(tuple(row))
    e[3:6] = [len(rows), True, tuple(rows)]
    e[1] = w.inventory_hash(e[0], tuple(map(int, value['membership']['tokens'])),
        s['tokenCoordinators'], e[5])
    e[2] = w.policy_chain(e, scope, d, context)
    s['evidence'] = json_values(e)
    s.update(w.source_set_commitments(scope, b[8], e, d, graph))
    b[9:13] = e[0:4]; binding[:] = json_values(b)


def supplied(count=3, *, modes=('disabled', 'legacy'), context=None, graph=None, recorded_at=100):
    if not 0 < count <= w.MAX_MEMBERS: raise ValueError('fixture VIEW member count')
    context = deepcopy(context) if context is not None else {
        'chainId': '31337', 'core': A(1), 'collectionId': '7', 'tokenId': '41',
        'timestamp': '1000', 'blockNumber': '10', 'blockHash': H('block')}
    roles = ('core', 'metadata', 'scopeMembership', 'coordinatorInventory', 'sourceFactory',
             'entropySourceSet', 'tokenInventory', 'store')
    graph = deepcopy(graph) if graph is not None else {role: {'address': A(i+1),
        'runtimeHash': keccak256(('synthetic VIEW ' + role).encode())} for i, role in enumerate(roles)}
    chain, cid, core = int(context['chainId']), int(context['collectionId']), context['core']
    tokens = tuple(range(int(context.get('tokenId', '41')), int(context.get('tokenId', '41')) + count))
    whole = encode(('uint256',)*count, tokens)
    parts = [whole[i:i+8192] for i in range(0, len(whole), 8192)]
    raw = encode(w.MEMBERSHIP_MANIFEST, (1, chain, core, cid, 4, count,
        keccak256(whole), tuple(keccak256(part) for part in parts)))
    digest = keccak256(raw)
    record = (schema_id('SCOPE_MEMBERSHIP'), subject_id('collection', str(chain), core, str(cid)),
        (1, hex_bytes(digest), w.neutral.MEMBERSHIP_CANON), 'ipfs://view-membership',
        w.neutral.MEMBERSHIP_SCHEMA, ZERO, (0, b'', ZERO), recorded_at)
    key = generic_hash(chain, graph['metadata']['address'], core, cid, A(80), record)
    receipt = (cid, A(80), 7, recorded_at, 0, H('metadata chain'), ZERO,
               w.neutral.MEMBERSHIP_SCHEMA_HASH, w.neutral.MEMBERSHIP_CANON_HASH)
    publication = (key, digest, w.neutral.MEMBERSHIP_SCHEMA, w.neutral.MEMBERSHIP_CANON,
                   A(81), keccak256(b'\0'+raw), recorded_at, receipt)
    scope = (4, cid, 0, _hash('6529STREAM_SCOPE_MEMBERSHIP_ID_V1',
        ('uint256', 'address', 'uint256', 'uint8', 'bytes32'), (chain, core, cid, 4, key)))
    facts = (w.scope_subject(scope, context), digest, key, count, keccak256(whole), ZERO, 0, ZERO)
    facts = (*facts[:5], w.membership_hash(facts, scope, context, graph), *facts[6:])
    member = {'facts': facts, 'publication': publication, 'progress': (True, True, count, count, len(parts), len(parts)),
        'metadataRecord': record, 'manifestBytes': '0x'+raw.hex(),
        'parts': [{'pointer': A(100+i), 'codeHash': keccak256(b'\0'+part), 'runtime': '0x'+(b'\0'+part).hex()}
                  for i, part in enumerate(parts)],
        'tokens': tokens, 'identities': [(True, cid, i+1, False) for i in range(count)],
        'lifecycles': [2]*count, 'inventoryTokens': tokens,
        'progressHistory': [(i+1, min((i+1)*256, count)) for i in range(len(parts))]}
    d = (tuple(graph[k]['address'] for k in w.POLICY_KEYS), tuple(graph[k]['runtimeHash'] for k in w.POLICY_KEYS),
         chain, 100000, 1000000)
    policies = []
    modes = modes[:min(count, len(modes))]
    if not modes: raise ValueError('fixture policy modes')
    for index, mode in enumerate(modes):
        if mode not in ('disabled', 'not_required', 'finalized', 'legacy'): raise ValueError(mode)
        explicit = mode != 'legacy'; policy_hash = H('policy'+str(index))
        policy = (True, True, True, 0 if mode == 'disabled' else 2, 0,
            1 if mode in ('disabled', 'not_required') else 0, 1, 0, policy_hash,
            _hash('6529STREAM_ENTROPY_CONFIGURATION_V1', ('bytes32', 'bool'), (policy_hash, True)),
            H('action'+str(index)), H('consent'+str(index))) if explicit else (
                False, False, False, 0, 0, 0, 0, 0, ZERO, ZERO, ZERO, ZERO)
        policies.append((A(200+index), H('coordinator code'+str(index)), index, True,
            H('module'+str(index)), H('manifest'+str(index)), H('schema'+str(index)), H('deployment'+str(index)),
            policy_hash, ZERO_ADDRESS if explicit else A(300+index), 0 if explicit else 1,
            ZERO if explicit else H('salt'+str(index)), ZERO, explicit, policy))
    coordinates = [policies[i % len(policies)][0] for i in range(count)]
    b = (core, graph['core']['runtimeHash'], graph['sourceFactory']['address'], graph['sourceFactory']['runtimeHash'],
        graph['entropySourceSet']['address'], graph['entropySourceSet']['runtimeHash'], chain, scope, facts,
        ZERO, ZERO, ZERO, len(policies))
    value = _json({'membership': member, 'sourceSet': {'dependencies': d,
        'evidence': (ZERO, ZERO, ZERO, len(policies), True, tuple(policies)),
        'tokenCoordinators': coordinates, 'manifestHash': ZERO, 'dataHash': ZERO}})
    binding = json_values(b)
    reseal(value, context, graph, binding)
    return value, context, graph, binding


class ReadHarness(w.ViewPolicyMembershipReads):
    """Actual read mixin over a closed local ABI response map."""
    def __init__(self, args):
        self.value, context, self.graph, self.binding = deepcopy(args)
        self.a = {**context, **{k:v['address'] for k,v in self.graph.items()}}
        self.reader = self; self.responses = {}; self.codes = {}; self.requested = []; self.installations = []
        m, s = self.value['membership'], self.value['sourceSet']
        b = from_json(w.VIEW_BINDING, self.binding); scope=b[7]; p=from_json(w.MEMBERSHIP_PUBLICATION,m['publication'])
        def add(role,sig,kinds,result,inputs=(),values=()):
            self.responses[(self.a[role],calldata(sig,inputs,values))]=encode(kinds,result)
            self.installations.append((self.a[role],sig,inputs,values,kinds,result))
        self.add=add
        suffix='((uint8,uint256,uint256,bytes32))'
        add('scopeMembership','scopeMembershipPublication'+suffix,(w.MEMBERSHIP_PUBLICATION,),(p,),(w.SCOPE,),(scope,))
        add('scopeMembership','scopeMembershipProgress'+suffix,(w.MEMBERSHIP_PROGRESS,),
            (from_json(w.MEMBERSHIP_PROGRESS,m['progress']),),(w.SCOPE,),(scope,))
        add('metadata','collectionRecord(bytes32)',(w.METADATA_RECORD,w.METADATA_RECEIPT),
            (from_json(w.METADATA_RECORD,m['metadataRecord']),p[7]),('bytes32',),(p[0],))
        add('metadata','recordHashAt(uint256,bytes32,uint256)',('bytes32',),(p[0],),
            ('uint256','bytes32','uint256'),(scope[1],schema_id('SCOPE_MEMBERSHIP'),p[7][4]))
        raw=hex_bytes(m['manifestBytes']); self.codes[p[4]]=b'\0'+raw
        add('metadata','recordPayload(bytes32)',('address','bytes'),(p[4],raw),('bytes32',),(p[0],))
        add('store','chunk(bytes32)',('address','uint32'),(p[4],len(raw)),('bytes32',),(p[1],))
        for part in m['parts']:
            raw=hex_bytes(part['runtime']);self.codes[part['pointer']]=raw
            add('store','chunk(bytes32)',('address','uint32'),(part['pointer'],len(raw)-1),('bytes32',),(keccak256(raw[1:]),))
        for index,token in enumerate(map(int,m['tokens'])):
            identity=from_json(('bool','uint256','uint256','bool'),m['identities'][index])
            add('scopeMembership','scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)',('uint256',),
                (token,),(w.SCOPE,'uint256'),(scope,index))
            add('core','tokenCollectionIdentity(uint256)',('bool','uint256','uint256','bool'),identity,('uint256',),(token,))
            add('core','tokenLifecycle(uint256)',('uint8',),(int(m['lifecycles'][index]),),('uint256',),(token,))
            add('core','coordinatorAtMint(uint256)',('address',),(s['tokenCoordinators'][index],),('uint256',),(token,))
            add('tokenInventory','collectionTokenBySerial(uint256,uint256)',('uint256',),(token,),
                ('uint256','uint256'),(scope[1],identity[2]))
        add('sourceFactory','scopedPolicyFactoryProfile()',('bytes32',),(w.FACTORY_PROFILE,))
        add('sourceFactory','dependencies()',(w.POLICY_DEPS,),(from_json(w.POLICY_DEPS,s['dependencies']),))
        for sig,role in (('core()','core'),('metadataHost()','metadata'),('scopeMembershipHost()','scopeMembership'),('coordinatorInventory()','coordinatorInventory')):
            add('sourceFactory',sig,('address',),(self.a[role],))
        add('sourceFactory','sourceSetForPlan(bytes32)',('address','bytes32'),(b[4],b[5]),('bytes32',),(b[9],))
        for sig,kind,value in (('factory()','address',b[2]),('core()','address',b[0]),('coreCodeHash()','bytes32',b[1]),
                ('SOURCE_SET_PROFILE()','bytes32',w.SOURCE_SET_PROFILE),('sourceScope()',w.SCOPE,scope),
                ('scopeMembershipFacts()',w.MEMBERSHIP_FACTS,b[8]),('inventoryPlan()','bytes32',b[9]),
                ('originalInventoryHash()','bytes32',b[10]),('originalPolicyChainHash()','bytes32',b[11]),
                ('sourceCount()','uint256',b[12]),('tokenInventory()','address',self.a['tokenInventory']),
                ('tokenInventoryCodeHash()','bytes32',self.graph['tokenInventory']['runtimeHash']),
                ('sourceSetManifestHash()','bytes32',s['manifestHash']),('sourceSetDataHash()','bytes32',s['dataHash'])):
            add('entropySourceSet',sig,(kind,),(value,))
        for index,row in enumerate(s['evidence'][5]):
            add('entropySourceSet','sourcePolicyAt(uint256)',(w.POLICY_ROW,),(from_json(w.POLICY_ROW,row),),('uint256',),(index,))
        for role in ('sourceFactory','entropySourceSet'):
            self.codes[self.a[role]]=('synthetic VIEW '+role).encode()

    def code(self,address):return '0x'+self.codes[address].hex()
    def _read(self,target,sig,outputs,inputs=(),values=(),maximum=65536):
        self.requested.append(sig)
        return decode(outputs,self.responses[(target,calldata(sig,inputs,values))],maximum=maximum)
    def _one(self,target,sig,output,inputs=(),values=(),**kwargs):
        return self._read(target,sig,(output,),inputs,values,**kwargs)[0]
    def _carrier(self,pointer,digest,maximum):
        raw=self.codes[pointer]
        w.require(raw[:1]==b'\0' and keccak256(raw)==digest and len(raw)-1<=maximum,'test carrier')
        return raw[1:]
    def _history(self,address,topics):
        from .public_chain_history import _matches
        return {'logs':[row for row in w.expected_events(self.value,self.a,self.graph,self.binding)
                        if _matches(row,{'address':address,'topics':topics})]}


def install_membership_reads(fixture, value, context, graph, binding):
    """Install original getters/carriers, preserving the parent's role runtimes.

    The fixture supplies add(target,signature,inputs,args,outputs,values), codes
    and pins. No event, header, timestamp or transaction is added here.
    """
    reads = ReadHarness((value, context, graph, binding))
    roles = {row['address'] for row in graph.values()}
    for pointer, runtime in reads.codes.items():
        if pointer in roles:
            continue
        digest = keccak256(runtime)
        w.require(pointer not in fixture.codes or fixture.codes[pointer] == runtime,
                  'VIEW fixture membership carrier collision')
        fixture.codes[pointer] = runtime
        fixture.pins[pointer] = digest
    for args in reads.installations:
        fixture.add(*args)


class ViewPolicyMembershipTests(unittest.TestCase):
    def test_exact_native_definitions_and_bindings(self):
        self.assertEqual([len(row['bytes']) for row in w.definitions()],[2047,1309])
        self.assertEqual(len(encode((w.VIEW_BINDING,),(from_json(w.VIEW_BINDING,supplied()[3]),))),736)
        v,c,g,b=supplied();r=w.validate(v,c,g,b)
        self.assertEqual(r['tokenIds'],['41','42','43'])
        self.assertEqual(len(r['policies']),2)
        self.assertFalse(r['claims']['currentEligibilityVerified'])

    def test_sealed_view_all_native_capacity_and_chunk_boundaries(self):
        for count in (1,256,257,16384):
            v,c,g,b=supplied(count);r=w.validate(v,c,g,b)
            self.assertEqual(len(r['tokenIds']),count)
            self.assertEqual(len(v['membership']['parts']),(count+255)//256)

    def test_later_burn_is_an_observation_not_original_hash(self):
        v,c,g,b=supplied();before=w.validate(v,c,g,b)
        v['membership']['identities'][0][3]=True;v['membership']['lifecycles'][0]='3'
        after=w.validate(v,c,g,b)
        self.assertEqual(before['facts'],after['facts']);self.assertEqual(before['inventoryHash'],after['inventoryHash'])
        self.assertTrue(after['identityObservations'][0]['burned'])

    def test_a_b_a_preserves_first_occurrence_not_intervals(self):
        v,c,g,b=supplied();r=w.validate(v,c,g,b)
        self.assertEqual(r['tokenCoordinators'],[A(200),A(201),A(200)])
        v['sourceSet']['evidence'][5][1][2]='2'
        with self.assertRaisesRegex(MuseumError,'first occurrence'):w.validate(v,c,g,b)

    def test_scope_and_native_metadata_authority_are_not_cast(self):
        for scope in ('0','1','2','3'):
            v,c,g,b=supplied();b[7][0]=scope
            with self.assertRaisesRegex(MuseumError,'membership scope'):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['membership']['publication'][7][2]='1'
        with self.assertRaisesRegex(MuseumError,'authority/definitions'):w.validate(v,c,g,b)

    def test_list_and_progress_omissions_never_truncate(self):
        v,c,g,b=supplied(257);v['membership']['parts'].pop()
        with self.assertRaisesRegex(MuseumError,'manifest fields'):w.validate(v,c,g,b)
        v,c,g,b=supplied(257);v['membership']['progressHistory'].pop()
        with self.assertRaisesRegex(MuseumError,'completion/hash'):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['membership']['tokens'].reverse()
        with self.assertRaisesRegex(MuseumError,'ordering'):w.validate(v,c,g,b)

    def test_carriers_and_original_receipt_time_are_exact(self):
        v,c,g,b=supplied();v['membership']['parts'][0]['runtime']+='00'
        with self.assertRaisesRegex(MuseumError,'carrier bytes/hash'):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['membership']['publication'][7][3]='1001'
        with self.assertRaisesRegex(MuseumError,'authority/definitions'):w.validate(v,c,g,b)

    def test_all_four_policy_branches_retain_full_originals(self):
        v,c,g,b=supplied(4,modes=('disabled','not_required','finalized','legacy'))
        self.assertEqual(len(w.validate(v,c,g,b)['policies']),4)
        v['sourceSet']['evidence'][5][3][14]=deepcopy(v['sourceSet']['evidence'][5][0][14])
        reseal(v,c,g,b)
        with self.assertRaisesRegex(MuseumError,'legacy policy'):w.validate(v,c,g,b)

    def test_rehashed_unfrozen_or_invalid_explicit_policy_refused(self):
        for index,new in ((3,False),(13,False)):
            v,c,g,b=supplied();v['sourceSet']['evidence'][5][0][index]=new;reseal(v,c,g,b)
            with self.assertRaises(MuseumError):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['sourceSet']['evidence'][5][0][14][3]='3';reseal(v,c,g,b)
        with self.assertRaisesRegex(MuseumError,'explicit original policy'):w.validate(v,c,g,b)

    def test_inventory_and_policy_hashes_reconstructed_independently(self):
        for index,error in ((1,'inventory hash'),(2,'policy chain')):
            v,c,g,b=supplied();v['sourceSet']['evidence'][index]=H('other');b[9+index]=H('other')
            e=from_json(w.POLICY_EVIDENCE,v['sourceSet']['evidence']);d=from_json(w.POLICY_DEPS,v['sourceSet']['dependencies'])
            v['sourceSet'].update(w.source_set_commitments(from_json(w.SCOPE,b[7]),from_json(w.MEMBERSHIP_FACTS,b[8]),e,d,g))
            with self.assertRaisesRegex(MuseumError,error):w.validate(v,c,g,b)

    def test_dependency_and_full_roster_substitutions(self):
        v,c,g,b=supplied();v['sourceSet']['dependencies'][0][1]=A(999)
        with self.assertRaisesRegex(MuseumError,'immutable dependencies'):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['sourceSet']['tokenCoordinators'][2]=A(999)
        with self.assertRaisesRegex(MuseumError,'outside original roster'):w.validate(v,c,g,b)
        v,c,g,b=supplied();v['sourceSet']['evidence'][5].append(deepcopy(v['sourceSet']['evidence'][5][0]))
        with self.assertRaisesRegex(MuseumError,'denominator/binding'):w.validate(v,c,g,b)

    def test_inventory_single_source_literal_domain_vector(self):
        v,c,g,b=supplied(1);row=from_json(w.POLICY_ROW,v['sourceSet']['evidence'][5][0]);plan=b[9]
        token_chain=keccak256(encode(('bytes32','bytes32'),
            (schema_id('6529STREAM_COORDINATOR_TOKEN_CHAIN_V1'),plan)))
        source_chain=keccak256(encode(('bytes32','bytes32'),
            (schema_id('6529STREAM_COORDINATOR_SOURCE_CHAIN_V1'),plan)))
        source_chain=keccak256(encode(('bytes32','bytes32','uint256',('address','bytes32','uint256')),
            (schema_id('6529STREAM_COORDINATOR_SOURCE_APPEND_V1'),source_chain,0,(row[0],row[1],0))))
        token_chain=keccak256(encode(('bytes32','bytes32','uint256','uint256','address','uint256'),
            (schema_id('6529STREAM_COORDINATOR_TOKEN_APPEND_V1'),token_chain,0,41,row[0],0)))
        expected=keccak256(encode(('bytes32','bytes32','uint256','uint256','bytes32','bytes32'),
            (schema_id('6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1'),plan,1,1,token_chain,source_chain)))
        self.assertEqual(w.validate(v,c,g,b)['inventoryHash'],expected)

    def test_impossible_shared_carrier_address_rejected(self):
        v,c,g,b=supplied(257)
        v['membership']['parts'][1]['pointer']=v['membership']['parts'][0]['pointer']
        with self.assertRaisesRegex(MuseumError,'runtime address conflict'):w.validate(v,c,g,b)

    def test_optional_full_output_identity_join(self):
        v,c,g,b=supplied(1);p=from_json(w.POLICY_ROW,v['sourceSet']['evidence'][5][0])
        row=(0,41,1,2,False,1,H('tokenData'),(p[0],p[1],p[8],True,p[14],1,ZERO,False,True),
             H('json'),H('html'),20,30)
        w.validate(v,c,g,b,[json_values(row)])
        changed=list(row);changed[1]=42
        with self.assertRaisesRegex(MuseumError,'output member/coordinator'):w.validate(v,c,g,b,[json_values(changed)])

    def test_every_output_serial_and_irreversible_burn_join(self):
        v,c,g,b=supplied(2,modes=('disabled',));p=from_json(w.POLICY_ROW,v['sourceSet']['evidence'][5][0])
        rows=[json_values((i,41+i,1+i,2,False,1,H('tokenData'+str(i)),
            (p[0],p[1],p[8],True,p[14],1,ZERO,False,True),H('json'),H('html'),20,30)) for i in range(2)]
        w.validate(v,c,g,b,rows)
        rows[1][2]='1'
        with self.assertRaisesRegex(MuseumError,'permanent collection serial'):w.validate(v,c,g,b,rows)
        rows[1][2]='2';rows[1][3:6]=['3',True,'2']
        with self.assertRaisesRegex(MuseumError,'burn cannot become live'):w.validate(v,c,g,b,rows)
        v['membership']['identities'][1][3]=True;v['membership']['lifecycles'][1]='3'
        w.validate(v,c,g,b,rows)
        # A saved live output can precede a later burn; it is not rewritten.
        rows[1][3:6]=['2',False,'1'];w.validate(v,c,g,b,rows)

    def test_exact_read_mixin_roundtrip_offline_no_current_getters(self):
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            for count in (1,3,257):
                f=ReadHarness(supplied(count))
                self.assertEqual(f._view_membership(f.binding),f.value)
                self.assertFalse(any('requireCurrent' in q or 'currentInventory' in q
                    or 'tokenEntropy' in q or 'requireScopeMembership' in q for q in f.requested))

    def test_reads_reject_roster_getter_runtime_and_bound_conflicts(self):
        f=ReadHarness(supplied());f.add('entropySourceSet','sourceCount()',('uint256',),(1,))
        with self.assertRaisesRegex(MuseumError,'sourceCount'):f._view_membership(f.binding)
        f=ReadHarness(supplied());f.codes[f.a['sourceFactory']]=b'changed'
        with self.assertRaisesRegex(MuseumError,'source runtime'):f._view_membership(f.binding)
        f=ReadHarness(supplied());f.binding[8][3]='16385'
        with self.assertRaisesRegex(MuseumError,'read bound'):f._view_membership(f.binding)
        self.assertEqual(f.requested,[])

    def test_installer_uses_original_timestamp_and_preserves_role_code(self):
        args=supplied(recorded_at=101);v,c,g,b=args
        class Fixture:
            def __init__(self):
                self.codes={row['address']:('synthetic VIEW '+role).encode() for role,row in g.items()}
                self.pins={row['address']:row['runtimeHash'] for row in g.values()};self.responses={}
            def add(self,target,sig,inputs,values,outputs,result):
                self.responses[(target,calldata(sig,inputs,values))]=encode(outputs,result)
        f=Fixture();before=deepcopy(f.codes)
        install_membership_reads(f,v,c,g,b)
        for address,raw in before.items():self.assertEqual(f.codes[address],raw)
        h=ReadHarness(args);h.codes=f.codes;h.responses=f.responses
        self.assertEqual(h._view_membership(b),v)
        self.assertEqual(v['membership']['publication'][7][3],'101')


if __name__=='__main__':unittest.main()
