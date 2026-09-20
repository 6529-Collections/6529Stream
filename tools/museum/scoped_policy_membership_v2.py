"""Original scoped membership for factory-policy V2 at e0b4d17.

The native membership format did not change. Its exact neutral validator and
immutable reads are reused without interpreting a STATIC snapshot or policy V1.
"""
from . import scoped_static_snapshot_wire as original
from .canonical import schema_id
from .chain_abi import encode
from .independent_wire import ZERO, json_values, require
from .native_finality_wire import from_json
from .scoped_static_types import SCOPE, MEMBERSHIP_FACTS, MEMBERSHIP_PUBLICATION
from .scoped_static_source_reads import ScopedStaticSourceReads, _json
from .scoped_static_snapshot_wire import _descriptor, _address, METADATA_RECORD

SOURCE_REVISION = 'e0b4d17bc548f778a379773234caee545658bcdc'
MAX_MEMBERS = 818
QUALIFICATION = [
    'Exact original TOKEN or sealed RELEASE/SEASON membership is retained; COLLECTION and VIEW are outside this profile.',
    'Original membership facts never contain the COLLECTION inventory prefix. Later observed burns do not rewrite the original membership hash.',
    'Metadata class7/8 membership publication is distinct from Artist or finality authority. Supplied checks do not authenticate execution, signature, provider completeness or consensus.',
    'Current identity/lifecycle and immutable carrier availability are observed separately; no current full-collection or current entropy gate supplies the historical denominator.',
]


def definitions():
    return tuple(row for row in original.definitions() if row['name'] in
        ('STREAM_SCOPE_MEMBERSHIP_V1','STREAM_SCOPE_MEMBERSHIP_ABI_V1'))


def validate(value, context, graph, scope, original_facts, token_ids):
    scope = original._scope(scope, context)
    facts = from_json(MEMBERSHIP_FACTS, original_facts)
    require(0 < facts[3] <= MAX_MEMBERS, 'scoped policy membership bound')
    require(type(value) is dict and type(value.get('tokens')) is list
            and len(value['tokens']) == facts[3], 'scoped policy membership original denominator')
    require(type(token_ids) in (tuple,list) and len(token_ids) == facts[3],
            'scoped policy output member denominator')
    found, tokens = original._membership(value, context, graph, scope)
    require(found == facts, 'scoped policy original membership facts differ')
    require(tokens == tuple(from_json('uint256',v) for v in token_ids),
            'scoped policy original output membership differs')
    observations = []
    for token,identity,lifecycle in zip(tokens,value['identities'],value['lifecycles']):
        identity=from_json(('bool','uint256','uint256','bool'),identity)
        observations.append({'tokenId':str(token),'collectionId':str(identity[1]),
            'collectionSerial':str(identity[2]),'lifecycle':str(from_json('uint8',lifecycle)),
            'burned':identity[3], 'observation':'source_block'})
    return {'facts':json_values(found),'tokenIds':[str(v) for v in tokens],
        'identityObservations':observations,'qualification':list(QUALIFICATION),
        'claims':{'originalMembershipCommitmentVerified':True,'historicalBurnStateReconstructed':False,
                  'historicalAuthorityVerified':False,'sourceAuthenticated':False}}


def expected_events(value, context, graph, scope):
    scope = original._scope(scope, context)
    m, out = value, []
    if scope[0] != 1:
        p = from_json(MEMBERSHIP_PUBLICATION, m['publication'])
        facts = from_json(MEMBERSHIP_FACTS, m['facts'])
        record = from_json(METADATA_RECORD, m['metadataRecord'])
        out.append(_descriptor('membership_recorded', _address(graph, 'metadata'), 'CollectionRecordRecorded',
            ('uint256', 'bytes32', 'bytes32', METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
            ('0x'+encode(('uint256',), (scope[1],)).hex(), record[0], record[1]),
            (METADATA_RECORD, 'bytes32', 'bytes32', 'address', 'bytes32', 'uint16'),
            (record, p[0], p[7][5], p[7][1], '0x'+encode(('uint8',), (p[7][2],)).hex(), 1)))
        out.append(_descriptor('membership_admitted', _address(graph, 'scopeMembership'), 'ScopeMembershipAdmitted',
            ('bytes32', 'uint256', 'uint8', 'bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'),
            (scope[3], '0x'+encode(('uint256',), (scope[1],)).hex(), '0x'+encode(('uint8',), (scope[0],)).hex()),
            ('bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'uint8'), (p[0], p[1], facts[4], facts[3], p[7][1], p[7][2])))
        for row in m['progressHistory']:
            parts, count = from_json(('uint256', 'uint256'), row)
            out.append(_descriptor('membership_progressed', _address(graph, 'scopeMembership'), 'ScopeMembershipProgressed',
                ('bytes32', 'uint256', 'uint256'), (scope[3],), ('uint256', 'uint256'), (parts, count)))
        out.append(_descriptor('membership_sealed', _address(graph, 'scopeMembership'), 'ScopeMembershipSealed',
            ('bytes32', 'bytes32', 'uint256'), (scope[3],), ('bytes32', 'uint256'), (facts[5], facts[3])))
    return out


class ScopedPolicyMembershipReads:
    """Parent supplies a/graph/reader and _read/_one/_carrier/_history."""
    _original_membership = ScopedStaticSourceReads._original_membership

    def _membership(self, scope, facts, tokenids):
        scope=original._scope(scope,self.a)
        facts=from_json(MEMBERSHIP_FACTS,facts)
        require(0 < facts[3] <= MAX_MEMBERS and len(tokenids) == facts[3],
                'scoped policy membership read bound')
        value=_json(self._original_membership(scope,facts))
        validate(value,self.a,self.graph,scope,facts,tokenids)
        return value
