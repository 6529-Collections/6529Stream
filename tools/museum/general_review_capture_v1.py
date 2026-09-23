"""Local General V2 signed/curator review capture from retained native products.

The Artist constructor fixture is explicitly typed and unused. No native Artist
statement, current whole-stack, institution identity or independent person is
claimed. Uses its own loopback EVM; no compiler or supplied remote RPC.
"""
from datetime import datetime, timezone
import hashlib
from pathlib import Path

from .account_profile import JCS_ID, JCS_NAME, account_iri
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .chain_rpc import RpcTransport
from .current_museum_capture import main as run_local
from .current_native_fixture import abi_kind
from .current_rights_capture import CurrentRightsFixture, METADATA
from .general_attestation_source import CURATORIAL, CURATOR_FAMILY, ESTATE, INSTITUTIONAL
from .general_attestation_source_v2 import GeneralAttestationSourceV2, PROFILE as SOURCE_PROFILE
from .general_publication_v1 import GeneralPublicationAdapterV1, EVENT_DATA, EVENT_TOPIC, GRANT_TOPIC, PROFILE as PUBLICATION_PROFILE
from .general_review_profile_v1 import (GeneralSemanticReviewProfileV1, ASSERTION_NAME,
    PROFILE_SCHEMA_NAME, REVIEW_MAPPING_RULE, REVIEW_RELATION, review_literal)
from .general_review_selection import NAME as POLICY, build, replay
from .general_semantic_source_v1 import selector
from .general_semantic_source_v2 import GeneralSemanticSourceV2, admission
from .independent_wire import RAW_BYTES, RAW_DEFINITION, ZERO, require, json_values

HOST = 'StreamGeneralAttestations'
BOUNDARY = 'GeneralArtistBoundary'
MAX_BYTES = 64 * 1024 * 1024
QUALIFICATION = ('Actual isolated local General V2 signed institutional/estate and configured '
    'CURATOR/class3 publication through real Metadata and Safe governance on explicitly '
    'qualified historical native products. GeneralArtistBoundary supplies only unused '
    'constructor bindings; the native Artist lane is empty. This is not whole-stack or '
    'current-source deployment, personhood, institution identity, independent-human review, '
    'consensus finality, truth, custody, title or accession evidence.')


def statement(profile, account, sid, prior, prior_raw, stamp, *, label='mapping',
              target=None, disposition='reviewed', authority=None):
    """New prospective wire, retaining a complete earlier General selector."""
    claim = {'id': 'urn:stream:general-review-fixture:' + label,
        'subject': 'urn:stream:general-review-fixture:work', 'relation': 'urn:stream:general-review-fixture:depicts',
        'object': {'entity': 'urn:stream:general-review-fixture:place'},
        'assertingAgent': account_iri('31337', account), 'createdAt': stamp,
        'evidence': [{'source': {'algorithm': '1', 'digest': keccak256(prior_raw),
            'canonicalizationId': prior['canonicalizationId']}, 'selectorType': 'whole_document',
            'selector': '', 'basis': 'documentary_evidence'}],
        'origin': 'human_mapping', 'reviewStatus': 'unreviewed',
        'mappingRule': 'urn:stream:general-review-fixture:mapping-rule',
        'rationale': 'Explicit local fixture statement; no institution or personhood inference.',
        'reviewEvidence': [], 'corrects': [], 'disputes': []}
    if target is not None:
        original = loads(prior_raw, maximum=24576, canonical=True)['assertions'][0]
        body = {'assertionRecord': target, 'assertionRevisionHash': keccak256(dumps(original)),
            'profileHash': profile.profile_hash, 'mappingRule': original['mappingRule'],
            'targetAuthority': authority, 'disposition': disposition}
        claim.update(subject=original['id'], relation=REVIEW_RELATION,
            object={'literal': review_literal(body)}, origin='direct_statement', mappingRule=REVIEW_MAPPING_RULE)
    return dumps({'profileSchemaId': schema_id(PROFILE_SCHEMA_NAME), 'profileHash': profile.profile_hash,
        'anchorSubject': {'kind': 'collection', 'subjectId': sid}, 'entities': [],
        'sourceRecords': [prior], 'authorityAlignments': [], 'assertions': [claim]})


class GeneralReviewCapture(CurrentRightsFixture):
    def deploy(self, name, values=()):
        artifact = self.products[name]
        constructor = next((r for r in artifact['abi'] if r['type'] == 'constructor'), {'inputs': []})
        arguments = encode(tuple(abi_kind(c) for c in constructor['inputs']), values)
        require((len(artifact['bytecode']['object'].removeprefix('0x')) // 2) + len(arguments) <= 49152,
            'General capture full constructor size exceeds EIP3860')
        return super().deploy(name, values)

    def typed_signature(self, request):
        fields = [('attester','address'),('collectionId','uint256'),('subjectId','bytes32'),
            ('attestationType','bytes32'),('attesterDID','string'),('schemaId','bytes32'),
            ('canonicalizationId','bytes32'),('statementURI','string'),('payload','bytes'),
            ('supersedes','bytes32'),('artistAuthorizationRecordHash','bytes32'),
            ('effectiveAt','uint64'),('nonce','uint256'),('deadline','uint64')]
        message = {name: ('0x'+value.hex() if type(value) is bytes else str(value) if type(value) is int else value)
            for (name, _), value in zip(fields, request)}
        typed = {'types': {'EIP712Domain': [{'name': n, 'type': t} for n,t in
            [('name','string'),('version','string'),('chainId','uint256'),('verifyingContract','address')]],
            'StreamGeneralAttestation': [{'name':n,'type':t} for n,t in fields]},
            'primaryType':'StreamGeneralAttestation', 'domain': {'name':'6529StreamGeneralAttestations',
                'version':'1','chainId':'31337','verifyingContract':self.addresses[HOST]}, 'message':message}
        return hex_bytes(self.rpc('eth_signTypedData_v4', [request[0], typed]), 65)

    def publish_general(self, raw, schema, canonical, nonce, account, family, *, attester=None):
        require(type(raw) is bytes and 0 < len(raw) <= 24576, 'General capture payload bound')
        subject = (0,1,0,ZERO)
        sid, = self.call(HOST, 'deriveSubject', (subject,))
        now = int(self.rpc('eth_getBlockByNumber',['latest',False])['timestamp'],16)
        old, = self.call(HOST,'latestAttestationHashFor',(1,family,sid,account))
        request = (attester or account,1,sid,family,'did:example:unsigned-display-label',schema,canonical,
            'https://example.org/general-review/original.json',raw,old,ZERO,now,nonce,now+86400)
        if family == CURATORIAL:
            data=self.data(HOST,'recordOperatorAttestation',(subject,request))
        else:
            signature=self.typed_signature(request)
            data=self.data(HOST,'recordSignedAttestation',(subject,request,signature))
        tx=self.send(data,self.addresses[HOST],account)
        events=[e for e in tx['logs'] if e['address']==self.addresses[HOST] and e['topics'] and e['topics'][0]==EVENT_TOPIC]
        require(len(events)==1,'General capture exact original event')
        digest=decode(EVENT_DATA,hex_bytes(events[0]['data']))[0]
        value, receipt=self.call(HOST,'attestation',(digest,))
        require(receipt[0]==account,'General original recorder differs')
        if family==CURATORIAL:
            require(receipt[1:3]==(2,2) and receipt[14:18]==(CURATOR_FAMILY,3,1,1), 'General original curator authority differs')
        else:
            require(receipt[1:3]==(1,1) and any(hex_bytes(receipt[6],32)), 'General original signed authority differs')
        row={'recordHash':digest,'value':json_values(value),'receipt':json_values(receipt)}
        return selector(row,{'chainId':'31337','host':self.addresses[HOST]}),sid

    def build_general(self):
        self.foundation()
        core,executor=(self.addresses[n] for n in ('StreamCore','StreamGovernanceExecutor'))
        artist=self.deploy(BOUNDARY,(core,))
        self.deploy(METADATA,((core,executor,self.schemas,artist,self.deployment,
            'https://example.org/general-review/metadata.json',schema_id('local General Metadata'),
            ('METADATA_DEPENDENCY_READ_GAS',400000,50000,2),('METADATA_ARTIST_READ_GAS',400000,150000,2)),))
        self.select_metadata()
        self.extend_actions(METADATA,['setFamilyWriter'])
        self.publisher,self.reviewer,self.curator,self.unsigned_label=self.rpc('eth_accounts',[])[:4]
        grant=(1,CURATOR_FAMILY,3,self.curator,True)
        self.governed(METADATA,'setFamilyWriter',grant,self.call(METADATA,'familyWriterTransition',grant))
        require(self.call(METADATA,'familyWriter',grant[:-1])==(True,1),'General capture actual curator grant missing')
        self.grant_transaction=next(r['transactionHash'] for r in reversed(self.receipts)
            if any(e['address']==self.addresses[METADATA] and e['topics'] and e['topics'][0]==GRANT_TOPIC
                for e in r['receipt']['logs']))
        self.deploy(HOST,((core,self.schemas,self.addresses[METADATA],artist,artist,executor,self.deployment,
            'https://example.org/general-review/host.json',schema_id('local General V2 host'),
            ('METADATA_ERC1271_VERIFY_GAS',400000,90000,2),('METADATA_DEPENDENCY_READ_GAS',400000,50000,2)),))
        self.register_document('RAW_BYTES',1,RAW_DEFINITION)
        seed_schema=self.register_document('STREAM_LOCAL_GENERAL_REVIEW_SEED_V1',0,b'{"type":"object"}')
        profile=self.review_profile
        for name in [JCS_NAME]+[n for n in profile.documents if n!=JCS_NAME]:
            kind,raw=profile.documents[name]
            self.register_document(name,kind,raw,RAW_BYTES if name==JCS_NAME else JCS_ID)
        seed=dumps({'statement':'A retained actual local General documentary seed.'})
        prior,sid=self.publish_general(seed,seed_schema,RAW_BYTES,100,self.publisher,INSTITUTIONAL)
        now=int(self.rpc('eth_getBlockByNumber',['latest',False])['timestamp'],16)
        stamp=datetime.fromtimestamp(now,timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        raw=statement(profile,self.publisher,sid,prior,seed,stamp)
        schema=schema_id(ASSERTION_NAME)
        original,_=self.publish_general(raw,schema,JCS_ID,101,self.publisher,INSTITUTIONAL)
        target={**original,'pointer':'/assertions/0'}
        authority={'principal':account_iri('31337',self.publisher),'collectionId':'1','subjectId':sid,
            'recordType':INSTITUTIONAL,'verificationClass':'SIGNER_VERIFIED',
            'authorityQualification':'GENERAL_SIGNER_CLAIM','grantRevision':'0'}
        self.choices={'mapping':target}
        for label,family,actor,disposition,nonce in (
                ('signed_approval',ESTATE,self.reviewer,'reviewed',100),
                ('curator_approval',CURATORIAL,self.curator,'reviewed',100),
                ('curator_rejection',CURATORIAL,self.curator,'rejected',101),
                ('self_review',INSTITUTIONAL,self.publisher,'reviewed',102)):
            payload=statement(profile,actor,sid,original,raw,stamp,label=label,target=target,
                disposition=disposition,authority=authority)
            ref,_=self.publish_general(payload,schema,JCS_ID,nonce,actor,family,
                attester=self.unsigned_label if family==CURATORIAL else None)
            self.choices[label]={**ref,'pointer':'/assertions/0'}
        # Historical grant evidence must survive a real later revocation.
        revoked=(*grant[:-1],False)
        self.governed(METADATA,'setFamilyWriter',revoked,self.call(METADATA,'familyWriterTransition',revoked))
        require(self.call(METADATA,'familyWriter',grant[:-1])==(False,2),'General later curator revocation missing')
        block=self.rpc('eth_getBlockByNumber',['latest',False])
        evidence=dumps({'kind':'local_evm_fixture','workflow':'general_review_signed_curator_v1',
            'nativeManifestSha256':hashlib.sha256(self.manifest_raw).hexdigest(),
            'nativeReuseAuditHash':keccak256(self.native_reuse_audit),
            'artifacts':self.artifact_rows,'transactions':self.receipts,'safeFixture':self.manifest['safeFixture'],
            'safeComponents':self.safe_components,'safeAccounts':self.safe_accounts,
            'boundaries':[{'contract':BOUNDARY,'address':artist,'role':'unused Artist constructor binding only',
                'nativeArtistStatementsExecuted':False}],
            'publisher':self.publisher,'reviewer':self.reviewer,'curator':self.curator,
            'unsignedAttesterLabel':self.unsigned_label,'curatorGrantTransaction':self.grant_transaction,
            'curatorGrantRevokedAfterPublication':True,'qualification':QUALIFICATION})
        addresses=sorted({core,self.schemas,self.store,self.addresses[METADATA],artist,self.addresses[HOST],executor})
        anchor=dumps({'profile':SOURCE_PROFILE,'chainId':'31337','blockHash':block['hash'],
            'blockNumber':str(int(block['number'],16)),'timestamp':str(int(block['timestamp'],16)),
            'stateRoot':block['stateRoot'],'environment':'local_evm_fixture','deploymentEvidenceHash':keccak256(evidence),
            'host':self.addresses[HOST],'core':core,'schemas':self.schemas,'store':self.store,
            'metadata':self.addresses[METADATA],'artistRegistry':artist,'artistAttribution':artist,
            'collectionId':'1','codePins':[{'address':a,'runtimeHash':keccak256(hex_bytes(self.rpc('eth_getCode',[a,'latest'])))} for a in addresses]})
        return anchor,evidence


def policy_for(source, choices, reviewers, *, allow_self=False):
    rows={r['source']['recordHash']:r for r in loads(source.snapshot(),maximum=MAX_BYTES)['statements']}
    def entry(label):
        ref=choices[label]
        return {'source':ref,'authority':admission(rows[ref['recordHash']],source.a)}
    return dumps({'profile':POLICY,'sourceSnapshotHash':keccak256(source.snapshot()),
        'sourceAuthoritySet':[entry('mapping')],'reviewerAuthoritySet':[entry(label) for label in reviewers],
        'allowAuthorSelfReview':allow_self,'singleValuedRelations':[]})


def capture(fixture,output):
    output.joinpath('native-reuse-audit.json').write_bytes(fixture.native_reuse_audit)
    anchor,evidence=fixture.build_general()
    output.joinpath('deployment-evidence.json').write_bytes(evidence)
    general=GeneralAttestationSourceV2(anchor,RpcTransport(fixture.endpoint),provenance='trusted_rpc')
    originals=loads(general.snapshot(),maximum=MAX_BYTES)
    hints=[]; grants=[]
    for tx in fixture.receipts:
        for event in tx['receipt']['logs']:
            if event['address']==fixture.addresses[HOST] and event['topics'] and event['topics'][0]==EVENT_TOPIC:
                digest=decode(EVENT_DATA,hex_bytes(event['data']))[0]
                hints.append({'recordHash':digest,'transactionHash':tx['transactionHash']})
                if event['topics'][2]==CURATORIAL:
                    grants.append({'recordHash':digest,'transactionHash':fixture.grant_transaction})
    hints_raw=dumps({'profile':PUBLICATION_PROFILE,'records':hints,'curatorGrants':grants})
    publication=GeneralPublicationAdapterV1(general,hints_raw,RpcTransport(fixture.endpoint),provenance='trusted_rpc')
    source=GeneralSemanticSourceV2(general,publication,RpcTransport(fixture.endpoint),profile=fixture.review_profile)
    policy=policy_for(source,fixture.choices,['signed_approval','curator_approval'])
    files=build(source,policy,keccak256(policy),disclosure='public')
    replay(files,keccak256(policy),provenance='trusted_rpc',disclosure='public')
    for name,raw in files.items(): output.joinpath(name).write_bytes(raw)
    cases=dumps({'profileHash':fixture.review_profile.profile_hash,'selectors':fixture.choices,
        'qualification':QUALIFICATION,'actualArtistLaneExecuted':False,'actualWholeStack':False})
    output.joinpath('cases.json').write_bytes(cases)
    require(len(originals['records'])==6,'General capture exact original six records')
    result=loads(files['selection-result.json'],maximum=MAX_BYTES)
    require(len(result['selected'])==1 and len(result['selected'][0]['qualifyingReviews'])==2,
        'General actual signed/curator selection differs')
    from .general_review_fixture_v1 import verify_capture, FILES
    packet={name:output.joinpath(name).read_bytes() for name in FILES}
    verified=verify_capture(packet,fixture.review_profile)
    pins=dumps({'files':{name:keccak256(raw) for name,raw in packet.items()},'result':verified})
    output.joinpath('capture-pins.json').write_bytes(pins)
    return keccak256(pins)


def main():
    def configure(parser):
        parser.add_argument('--native-reuse-audit',type=Path,required=True)
        parser.add_argument('--native-reuse-audit-sha256',required=True)
    def prepare(args):
        args.audit_raw=args.native_reuse_audit.read_bytes()
        require(len(args.audit_raw)<=MAX_BYTES and hashlib.sha256(args.audit_raw).hexdigest()==args.native_reuse_audit_sha256,
            'General capture native audit differs')
        audit=loads(args.audit_raw,maximum=MAX_BYTES,canonical=True)
        require(audit['manifestSha256']==args.native_manifest_sha256 and audit['status']=='QUALIFIED_HISTORICAL_INPUTS',
            'General capture native manifest is not qualified')
    def setup(fixture,args):
        fixture.native_reuse_audit=args.audit_raw
        fixture.review_profile=GeneralSemanticReviewProfileV1()
    run_local(fixture_type=GeneralReviewCapture,capture_function=capture,configure_parser=configure,
        prepare_arguments=prepare,configure_fixture=setup)


if __name__=='__main__': main()
