"""Fast local-measurement and publication-recipe controls; no native deployment."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, loads, keccak256, schema_id
from .current_media_inputs import PF, PREFIX, image_bytes
from .current_preservation_capture import (CurrentPreservationFixture, measure_file, copy_and_measure, SCHEMAS,
    FIXITY_REPORT, AGENT_ID, OBJECT_ID, capture, main)
from .current_museum_capture import CurrentMuseumFixture
from .recorded_semantic import JCS_ID
from .schemas import NAMES


def selected(number):
    h='0x'+format(number,'064x');a='0x'+'12'*20
    return {'host':a,'recordHash':h,'subjectId':h,'schemaId':schema_id(NAMES[1]),'schemaHash':h,
        'recordType':schema_id('INDEPENDENT_SEMANTIC_ASSERTION'),'recorder':a,'authorizationClass':'INDEPENDENT_ATTESTOR',
        'recordIndex':'0','recordChainHash':h,'pointer':''}


class CurrentPreservationCapture(unittest.TestCase):
    def expected(self,raw):
        return {'digest':'0x'+hashlib.sha256(raw).hexdigest(),'size':str(len(raw)),
            'source':[selected(1)],'pointers':{'digest':{**selected(1),'pointer':'/digest'}}}

    def test_actual_bytes_produce_success_or_failure_without_promoting_file_time(self):
        with tempfile.TemporaryDirectory() as folder:
            file=Path(folder)/'input.png';raw=image_bytes();file.write_bytes(raw)
            expected=self.expected(raw)
            observed,report=measure_file(file,expected,schema_id('check'),clock=lambda:1790001234)
            self.assertEqual(observed,raw);self.assertEqual(report['outcome'],schema_id('SUCCESS'))
            self.assertEqual(report['checkedAt'],'1790001234')
            detail=loads(report['detail'].encode(),canonical=True)
            self.assertEqual(detail['clock'],'host_utc');self.assertEqual(detail['expectedDeclaration'],expected['source'])
            file.write_bytes(raw+b'x')
            _,changed=measure_file(file,expected,schema_id('changed'),clock=lambda:1790001235)
            self.assertEqual(changed['outcome'],schema_id('FAILED'))
            self.assertEqual(changed['expectedDigest'],report['expectedDigest'])
            self.assertNotEqual(changed['observedDigest'],report['observedDigest'])
            self.assertEqual(changed['observedByteSize'],str(len(raw)+1))

    def test_actual_copy_is_read_back_and_existing_destination_is_never_replaced(self):
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'source';dest=Path(folder)/'copy';source.write_bytes(b'actual local bytes')
            result=copy_and_measure(source,dest,self.expected(source.read_bytes()),clock=lambda:1790002345)
            self.assertEqual(dest.read_bytes(),source.read_bytes());self.assertTrue(result['equal'])
            self.assertEqual(result['sourceSha256'],result['destinationSha256'])
            self.assertEqual(result['performedAt'],'1790002345')
            with self.assertRaisesRegex(MuseumError,'already exists'):
                copy_and_measure(source,dest,self.expected(source.read_bytes()))
            self.assertEqual(dest.read_bytes(),b'actual local bytes')

    def fixture(self,duplicate=False,tamper=False):
        fixture=object.__new__(CurrentPreservationFixture);fixture.attestor='0x'+'12'*20
        fields=[('digest','ab'*32),('size','7'),('puid','fmt/11')]
        if duplicate:fields.append(fields[0])
        fixture.published=[selected(i+1) for i in range(len(fields))]
        raw={}
        for row,(field,value) in zip(fixture.published,fields):
            raw[row['recordHash']]=dumps({'assertions':[{'subject':PREFIX+'image','relation':PF[field],
                'object':{'literal':{'lexicalValue':value}}}]})
        def call(name,method,args):
            payload=raw[args[0]]
            if method=='collectionRecord':
                digest=bytes.fromhex(keccak256(payload)[2:])
                return (None,None,(1,digest,JCS_ID)),(None,fixture.attestor)
            self.assertEqual(method,'recordPayload')
            return '0x'+'34'*20,payload+(b' ' if tamper else b'')
        fixture.call=call
        return fixture

    def test_expectations_are_read_from_each_actual_prior_payload_and_full_selector(self):
        fixture=self.fixture();facts=fixture._expectations()
        self.assertEqual(facts['digest'],'0x'+'ab'*32);self.assertEqual(facts['size'],'7')
        self.assertEqual(facts['puid'],'fmt/11');self.assertEqual(facts['source'],fixture.published)
        self.assertEqual(facts['pointers']['digest']['recordHash'],selected(1)['recordHash'])
        with self.assertRaisesRegex(MuseumError,'ambiguous duplicate'): self.fixture(duplicate=True)._expectations()
        with self.assertRaisesRegex(MuseumError,'facts changed'): self.fixture(tamper=True)._expectations()

    def test_original_capture_default_hooks_add_no_lanes_or_evidence(self):
        fixture=object.__new__(CurrentMuseumFixture)
        self.assertIsNone(fixture.after_media_publications());self.assertEqual(fixture.extra_capture_evidence(),{})
        self.assertEqual(fixture.capture_lanes(),[{'scopeKey':'1','recordType':schema_id('INDEPENDENT_SEMANTIC_ASSERTION')}])
        self.assertEqual(len(object.__new__(CurrentPreservationFixture).capture_lanes()),3)

    def test_files_exist_before_any_native_publication_and_incomplete_capture_is_not_exported(self):
        with tempfile.TemporaryDirectory() as folder:
            fixture=object.__new__(CurrentPreservationFixture)
            def run(actual,out):
                self.assertEqual(actual,fixture)
                self.assertEqual((actual.observation_directory/'declared.png').read_bytes(),image_bytes())
                self.assertNotEqual((actual.observation_directory/'mutated.bin').read_bytes(),image_bytes())
                raise RuntimeError('explicit aborted native publication')
            with patch('tools.museum.current_preservation_capture.capture_media',side_effect=run), \
                patch('tools.museum.current_preservation_capture.export_preservation') as export:
                with self.assertRaisesRegex(RuntimeError,'aborted'): capture(fixture,Path(folder))
                export.assert_not_called()

    def test_owned_process_stops_even_when_execution_journal_cannot_be_written(self):
        import io
        import sys
        from types import SimpleNamespace
        from unittest.mock import Mock
        from .current_museum_capture import main as shared_main
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); manifest=root/'manifest.json'; raw=b'{}'; manifest.write_bytes(raw)
            original=Path.write_bytes; process=Mock(); fixture=SimpleNamespace(receipts=[],artifact_rows={})
            def write(path,data):
                if path.name=='execution-journal.json': raise OSError('explicit journal write failure')
                return original(path,data)
            with patch.object(sys,'argv',['capture','--native-manifest',str(manifest),
                    '--native-manifest-sha256',hashlib.sha256(raw).hexdigest(),
                    '--output',str(root/'output'),'--disclosure','public']), \
                    patch('tools.museum.current_museum_capture.socket.socket') as socket, \
                    patch('tools.museum.current_museum_capture.subprocess.Popen',return_value=process), \
                    patch.object(Path,'write_bytes',write),patch.object(sys,'stdout',io.StringIO()):
                socket.return_value.__enter__.return_value.getsockname.return_value=('127.0.0.1',17321)
                with self.assertRaisesRegex(OSError,'journal write failure'):
                    shared_main(fixture_type=lambda *a,**k:fixture,capture_function=lambda *a:'complete')
                process.terminate.assert_called_once()
                process.wait.assert_called_once_with(timeout=10)

    def test_separate_cli_selects_the_real_native_fixture_and_closure_export(self):
        with patch('tools.museum.current_preservation_capture.run_main') as run:
            main();run.assert_called_once_with(fixture_type=CurrentPreservationFixture,capture_function=capture)


if __name__=='__main__': unittest.main()