"""Concrete synthetic policy V2 source capture; no live RPC or native execution."""
from copy import deepcopy
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import public_scoped_policy_finality_capture_v2 as capture
from . import public_scoped_policy_finality_source_v2 as source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, decode, encode
from .scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


def repin(files):
    files = dict(files)
    value = loads(files['manifest.json'], maximum=1048576)
    value['files'] = [capture.base._ref(path, raw) for path, raw in sorted(files.items()) if path != 'manifest.json']
    files['manifest.json'] = dumps(value)
    return files, keccak256(files['manifest.json'])


class PublicPolicyFinalityCaptureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = ScopedPolicyFinalityFixtureV2(scope_type=2,count=3)
        adapter = cls.fixture.policy_source()
        cls.snapshot_raw = adapter.snapshot()
        cls.snapshot = loads(cls.snapshot_raw, maximum=source.MAX_OUTPUT)
        transcript = adapter.transcript()
        cls.inputs = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes), source.PROFILE_HASH,
            transcript, keccak256(transcript))
        cls.result = capture.replay(*cls.inputs, provenance='synthetic_fixture', disclosure='public')

    def transcript(self):
        return loads(self.inputs[3], maximum=source.MAX_OUTPUT)

    def replay_calls(self, value):
        raw = dumps(value)
        return capture.replay(*self.inputs[:3], raw, keccak256(raw), provenance='synthetic_fixture', disclosure='public')

    def test_exact_original_triplet_and_nineteen_native_definitions(self):
        files = dict(self.result.files)
        self.assertEqual(files['source/anchor.json'], self.inputs[0])
        self.assertEqual(files['source/transcript.json'], self.inputs[3])
        self.assertEqual(files['source/snapshot.json'], self.snapshot_raw)
        definitions = source.wire.definitions()
        self.assertEqual(len(definitions), 19)
        self.assertEqual(len({r['id'] for r in definitions}), 19)
        for row in definitions:
            self.assertEqual(files['definitions/native/'+row['name']+'.json'], row['bytes'])
        self.assertGreater(max(len(r['bytes']) for r in definitions), 24576)
        fragment = loads(files['scoped-policy-finality/fragment.json'], maximum=source.MAX_OUTPUT)
        self.assertEqual(fragment['bundle'], self.snapshot['bundle'])
        self.assertEqual(fragment['sourceRef']['snapshotHash'], keccak256(self.snapshot_raw))
        self.assertNotIn('captureManifestHash', fragment['sourceRef'])

    def test_native_proof_and_preserved_partial_claims(self):
        proof = loads(dict(self.result.files)['scoped-policy-finality/token-proof.json'])
        self.assertEqual(proof['kind'], 'native_scoped_policy_token_content_proof_v2')
        self.assertEqual(proof['leaf'][0], self.snapshot['identity']['tokenId'])
        self.assertEqual(proof['leafCount'], '3')
        source.neutral.verify_proof(proof['leafHash'], int(proof['leafIndex']), int(proof['leafCount']), proof['proof'], proof['root'])
        self.assertEqual(self.snapshot['historicalCoreFacts']['status'], 'hash_only')
        self.assertIsNone(self.snapshot['historicalCoreFacts']['preimage'])
        for key in ('completeAuthority','historicalCoreFactsPreimageRecovered','currentArchiveLivenessChecked',
                    'actualChainAcceptance','canonicalPacketCompatible','completeCanonicalPacket'):
            self.assertFalse(self.result.report['claims'][key])

    def test_current_burn_does_not_rewrite_original_inventory_or_outputs(self):
        original = ScopedPolicyFinalityFixtureV2(count=1).policy_result()
        burned = ScopedPolicyFinalityFixtureV2(count=1,burned=True).policy_result()
        self.assertFalse(original['identity']['burned'])
        self.assertTrue(burned['identity']['burned'])
        self.assertEqual(burned['identity']['lifecycle'], '3')
        for group in ('snapshot','reference','content'):
            self.assertEqual(original['bundle'][group], burned['bundle'][group])
        self.assertEqual(original['bundle']['membership']['facts'], burned['bundle']['membership']['facts'])
        self.assertNotEqual(original['bundle']['membership']['lifecycles'], burned['bundle']['membership']['lifecycles'])

    def test_no_current_policy_or_archive_getter_substitutes_originals(self):
        forbidden = ('currentInventoryPlan((uint8,uint256,uint256,bytes32))','requireCurrentSourceSet()',
            'tokenEntropyReadiness(uint256)','requireCoverage(bytes32)',
            'computeCollectionCoreFactsHash(uint256)','verifyFinality(uint256)')
        selectors = {schema_id(sig)[:10] for sig in forbidden}
        rows = self.transcript()['calls']
        self.assertEqual(sum(r['method']=='eth_getTransactionByHash' for r in rows), 2)
        for row in rows:
            if row['method']=='eth_call': self.assertNotIn(row['params'][0]['data'][:10], selectors)

    def test_missing_indirect_and_noncanonical_inputs_remain_partial(self):
        for mode, reason in (('missing','transaction_unavailable'),('indirect','outer_recipient_not_executor'),
                             ('noncanonical','unsupported_noncanonical_input')):
            with self.subTest(mode=mode):
                value = self.transcript()
                tx_hashes = set()
                for row in value['calls']:
                    if row['method'] != 'eth_getTransactionByHash': continue
                    tx_hashes.add(row['params'][0])
                    if mode=='missing': row['result'] = None
                    elif mode=='indirect': row['result']['to'] = self.snapshot['graph']['roles']['address']
                    else: row['result']['input'] += '00'
                if mode=='indirect':
                    for row in value['calls']:
                        if row['method']=='eth_getTransactionReceipt' and row['params'][0] in tx_hashes:
                            row['result']['to'] = self.snapshot['graph']['roles']['address']
                result = self.replay_calls(value)
                snapshot = loads(dict(result.files)['source/snapshot.json'], maximum=source.MAX_OUTPUT)
                report = snapshot['reconstruction']
                self.assertEqual(report['status'], 'partial')
                self.assertFalse(report['claims']['bothOriginalTransactionInputsDecoded'])
                self.assertTrue(any(reason in item for item in report['reasons']))
                self.assertEqual(capture.verify(result.files,result.manifest_hash).files,result.files)

    def test_original_factory_recipe_and_stored_graph_cannot_be_swapped(self):
        from . import scoped_policy_factory_v2 as factory
        for method in ('recipeHash()','graphForPlan(bytes32)'):
            value=self.transcript()
            row=next(r for r in value['calls'] if r['method']=='eth_call' and
                r['params'][0]['to']==self.snapshot['graph']['publicationFactory']['address'] and
                r['params'][0]['data'][:10]==schema_id(method)[:10])
            if method=='recipeHash()':row['result']='0x'+encode(('bytes32',),(schema_id('different original recipe'),)).hex()
            else:
                original=list(decode((factory.GRAPH,),hex_bytes(row['result']))[0]);original[2]=self.snapshot['graph']['core']['address']
                row['result']='0x'+encode((factory.GRAPH,),(original,)).hex()
            with self.subTest(method=method),self.assertRaises(MuseumError):self.replay_calls(value)

    def test_transcript_omission_extra_and_original_bytes_tampering(self):
        for mode in ('omission','extra','code','transaction'):
            with self.subTest(mode=mode):
                value = self.transcript()
                if mode=='omission': value['calls'].pop(0)
                elif mode=='extra': value['calls'].append(deepcopy(value['calls'][-1]))
                elif mode=='code': next(r for r in value['calls'] if r['method']=='eth_getCode')['result'] = '0x00'
                else:
                    row = next(r for r in value['calls'] if r['method']=='eth_getTransactionByHash')
                    row['result']['blockHash'] = schema_id('different original block')
                with self.assertRaises(MuseumError): self.replay_calls(value)

    def test_repinned_native_definition_and_derivatives_require_exact_rebuild(self):
        paths = ('definitions/native/'+source.wire.definitions()[0]['name']+'.json',
            'scoped-policy-finality/fragment.json','scoped-policy-finality/token-proof.json','source/snapshot.json','capture/report.json')
        for path in paths:
            with self.subTest(path=path):
                files = dict(self.result.files)
                files[path] = files[path]+b'\n'
                files,digest = repin(files)
                with self.assertRaisesRegex(MuseumError,'reconstruction differs'): capture.verify(files,digest)

    def test_offline_exact_replay_and_common_package_dispatch(self):
        from .package_v2 import verify_package
        with patch('socket.socket',side_effect=AssertionError('network forbidden')):
            self.assertEqual(capture.verify(self.result.files,self.result.manifest_hash).files,self.result.files)
            with TemporaryDirectory() as directory:
                output = Path(directory)/'policy'
                write_tree(dict(self.result.files),output)
                self.assertEqual(verify_package(output,self.result.manifest_hash).files,self.result.files)

    def test_public_disclosure_and_runtime_admission_precede_rpc(self):
        wrong = schema_id('wrong external pin')
        with self.assertRaisesRegex(MuseumError,'public disclosure'):
            capture.replay(None,wrong,wrong,None,wrong,provenance='synthetic_fixture',disclosure='private')
        with patch.object(capture,'_read_input',side_effect=AssertionError('input read before disclosure')):
            with self.assertRaisesRegex(MuseumError,'public disclosure'):
                capture.main(['capture','--anchor','missing','--anchor-hash',wrong,'--source-profile-hash',wrong,
                    '--rpc-env','POLICY_TEST_RPC','--disclosure','private','--output','new'])
        with TemporaryDirectory() as directory:
            anchor = Path(directory)/'anchor.json'; anchor.write_bytes(self.inputs[0])
            original_get = capture.os.environ.get
            def guarded(key,*args):
                if key=='POLICY_TEST_RPC': raise AssertionError('endpoint before runtime admission')
                return original_get(key,*args)
            with patch.object(capture.os.environ,'get',side_effect=guarded):
                with self.assertRaisesRegex(MuseumError,'runtime admission'):
                    capture.main(['capture','--anchor',str(anchor),'--anchor-hash',self.inputs[1],
                        '--source-profile-hash',source.PROFILE_HASH,'--rpc-env','POLICY_TEST_RPC',
                        '--disclosure','public','--output',str(Path(directory)/'capture')])

    def test_explicit_external_admission_does_not_claim_actual_chain_acceptance(self):
        anchor = loads(self.inputs[0]); anchor['runtimeAdmission']['kind'] = 'externally_admitted_runtime'
        raw = dumps(anchor); transport = capture.PublicRpcTransport('https://example.invalid/never-requested')
        with patch.object(transport,'request',side_effect=self.fixture.request), \
                patch('socket.socket',side_effect=AssertionError('synthetic transport only')):
            result = capture.capture(raw,keccak256(raw),source.PROFILE_HASH,transport,disclosure='public')
        self.assertEqual(result.report['provenance'],'trusted_rpc')
        self.assertFalse(result.report['claims']['actualChainAcceptance'])
        self.assertEqual(loads(dict(result.files)['source/anchor.json'])['runtimeAdmission'],anchor['runtimeAdmission'])

    def test_external_pins_and_cli_atomic_replay(self):
        with self.assertRaisesRegex(MuseumError,'external source profile'):
            capture.replay(self.inputs[0],self.inputs[1],schema_id('old profile'),*self.inputs[3:],
                provenance='synthetic_fixture',disclosure='public')
        with self.assertRaisesRegex(MuseumError,'external manifest pin'):
            capture.verify(self.result.files,schema_id('other manifest'))
        with TemporaryDirectory() as directory, patch('socket.socket',side_effect=AssertionError('offline only')):
            root = Path(directory); anchor,transcript,output = root/'anchor.json',root/'transcript.json',root/'capture'
            anchor.write_bytes(self.inputs[0]); transcript.write_bytes(self.inputs[3])
            args = ['replay','--anchor',str(anchor),'--anchor-hash',self.inputs[1],
                '--source-profile-hash',source.PROFILE_HASH,'--transcript',str(transcript),
                '--transcript-hash',self.inputs[4],'--provenance','synthetic_fixture','--disclosure','public','--output',str(output)]
            with redirect_stdout(io.StringIO()): capture.main(args)
            self.assertEqual(read_tree(output),dict(self.result.files))
            with self.assertRaises((MuseumError,FileExistsError)): capture.main(args)
            self.assertEqual(read_tree(output),dict(self.result.files))


if __name__ == '__main__': unittest.main()
