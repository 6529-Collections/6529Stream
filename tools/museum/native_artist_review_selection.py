"""Explicit account-qualified Artist review selection; no institutional credentials."""
from .canonical import dumps, keccak256, loads, uint
from .chain_rpc import MAX_TRANSCRIPT
from .independent_wire import require
from .native_artist_review_source import NativeArtistReviewSource
from .review import _validate

PROFILE = 'STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_SELECTION_V1'


def _assertions(snapshot):
    result = {}
    for row in snapshot['statements']:
        if row['status'] != 'supported': continue
        for index, assertion in enumerate(row['value']['assertions']):
            if row['assertionInterpretations'][index]['status'] != 'supported': continue
            reference = row['source'] | {'pointer': '/assertions/' + str(index)}
            key = dumps(reference)
            require(key not in result, 'Artist review duplicate original assertion selector')
            result[key] = (reference, assertion, row)
    return result


def _select(snapshot, policy_raw, policy_hash):
    """Pure internal policy engine; public entry always constructs a concrete source."""
    from .native_artist_review_profile import (BODY_SCHEMA_BYTES, CLAIMS, QUALIFICATION,
        REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION)
    require(keccak256(policy_raw) == policy_hash, 'Artist review external policy pin differs')
    policy = loads(policy_raw, maximum=524288, canonical=True)
    require(type(policy) is dict and set(policy) == {'profile', 'interpretationProfileHash', 'sourceSnapshotHash',
        'sourceAuthoritySet', 'reviewerAuthoritySet', 'singleValuedRelations', 'allowSelfReview',
        'independentHumanReviewRequired'} and policy['profile'] == PROFILE
        and policy['interpretationProfileHash'] == snapshot['interpretationProfileHash']
        and policy['sourceSnapshotHash'] == keccak256(dumps(snapshot))
        and type(policy['allowSelfReview']) is bool and type(policy['independentHumanReviewRequired']) is bool,
        'Artist review policy shape/profile/source differs')
    require(not policy['independentHumanReviewRequired'], 'Artist review independent human authority unavailable')
    for name in ('sourceAuthoritySet', 'reviewerAuthoritySet', 'singleValuedRelations'):
        values = policy[name]
        require(type(values) is list and len(values) <= 512 and len({dumps(v) for v in values}) == len(values),
            'Artist review policy duplicate/bound')
    require(all(type(v) is str for v in policy['singleValuedRelations']), 'Artist review relation shape')
    assertions = _assertions(snapshot); sources, reviewers = {}, {}
    for name, chosen in (('sourceAuthoritySet', sources), ('reviewerAuthoritySet', reviewers)):
        for reference in policy[name]:
            key = dumps(reference)
            require(key in assertions, 'Artist review selected original unavailable or invalid')
            chosen[key] = assertions[key]
    require(not set(sources) & set(reviewers), 'Artist review source/reviewer roles overlap')
    require(all(assertion['relation'] != REVIEW_RELATION for _, assertion, _ in sources.values()),
        'Artist review statement cannot be an ordinary source assertion')
    dispositions = {key: [] for key in sources}; review_rows, diagnostics = [], []
    for reference, review, row in reviewers.values():
        require(review['relation'] == REVIEW_RELATION and review['mappingRule'] == REVIEW_MAPPING_RULE
            and review['origin'] == 'direct_statement', 'Artist review selected review type differs')
        literal = review['object'].get('literal')
        require(type(literal) is dict and literal['datatype'] == REVIEW_DATATYPE
            and all(literal[key] is None for key in ('language', 'unit', 'precision')),
            'Artist review literal datatype/qualifier differs')
        body = _validate(BODY_SCHEMA_BYTES, literal['lexicalValue'].encode('utf-8'))
        original_key = dumps(body['assertionRecord'])
        require(original_key in assertions, 'Artist review exact target unavailable or invalid')
        original_selector, original, original_row = assertions[original_key]
        require(body['sourceScope'] == snapshot['sourceScope']
            and body['assertionAuthority'] == original_row['nativeAuthority']
            and body['assertionRevisionHash'] == keccak256(dumps(original))
            and body['profileHash'] == original_row['value']['profileHash'] == row['value']['profileHash']
                == snapshot['interpretationProfileHash']
            and body['mappingRule'] == original['mappingRule'] and review['subject'] == original['id']
            and original['relation'] != REVIEW_RELATION,
            'Artist review original scope/authority/revision/profile/rule differs')
        require(row['source']['subjectId'] == original_selector['subjectId']
            and row['source']['host'] == original_selector['host'] == snapshot['sourceScope']['host']
            and row['value']['anchorSubject'] == original_row['value']['anchorSubject'],
            'Artist review source and target publication scope differs')
        require(tuple(map(uint, original_row['publicationPosition'])) < tuple(map(uint, row['publicationPosition'])),
            'Artist review must follow original native publication')
        old, new = original_row['nativeAuthority'], row['nativeAuthority']
        same_artist, same_account = old['artistId'] == new['artistId'], old['signer'] == new['signer']
        self_review = same_artist or same_account
        resolved = {'reviewRecord': reference, 'assertionRecord': original_selector,
            'assertionRevisionHash': body['assertionRevisionHash'], 'profileHash': body['profileHash'],
            'mappingRule': body['mappingRule'], 'reviewer': review['assertingAgent'],
            'reviewedAt': review['createdAt'], 'selfReview': self_review,
            'sameArtistIdentity': same_artist, 'sameSigningAccount': same_account,
            'qualification': 'SELF' if self_review else 'distinct_native_artist_and_signing_account',
            'independentHumanReviewProven': False, 'institutionalAuthorityProven': False,
            'disposition': body['disposition'], 'assertionAuthority': old, 'reviewerAuthority': new,
            'sourceScope': body['sourceScope'], 'reviewPublicationPosition': row['publicationPosition'],
            'currentQualification': row['currentQualification']}
        for backlink in original['reviewEvidence']:
            if backlink['reviewRecord'] == reference:
                require(all(key in resolved and resolved[key] == value for key, value in backlink.items()),
                    'Artist review forged recorder backlink')
        review_rows.append(resolved)
        if original_key not in sources:
            diagnostics.append({'source': reference, 'reason': 'review_target_unselected'})
        elif self_review and not policy['allowSelfReview']:
            diagnostics.append({'source': reference, 'reason': 'SELF_review_not_enabled'})
        elif review['reviewStatus'] in ('disputed', 'withdrawn'):
            diagnostics.append({'source': reference, 'reason': 'review_revision_disputed_or_withdrawn'})
        else:
            dispositions[original_key].append(resolved)
    selected, withheld = [], []
    for key, (reference, assertion, row) in sorted(sources.items()):
        reviews = dispositions[key]; reasons = []; direct = assertion['origin'] == 'direct_statement'
        if assertion['reviewStatus'] in ('disputed', 'withdrawn'):
            reasons.append('selected_original_revision_disputed_or_withdrawn')
        if not direct:
            if not any(review['disposition'] == 'reviewed' for review in reviews):
                reasons.append('mapping_requires_selected_native_review')
            if any(review['disposition'] == 'rejected' for review in reviews):
                reasons.append('selected_native_review_rejected')
        row_result = {'source': reference, 'assertion': assertion, 'nativeAuthority': row['nativeAuthority'],
            'historicalAuthority': row['historicalAuthority'], 'currentQualification': row['currentQualification'],
            'basis': 'historical_native_direct_statement' if direct else 'explicit_selected_native_review',
            'reviews': reviews, 'reasons': reasons}
        (withheld if reasons else selected).append(row_result)
    groups = {}
    for row in selected:
        assertion = row['assertion']
        if assertion['relation'] in policy['singleValuedRelations']:
            key = (row['source']['subjectId'], assertion['subject'], assertion['relation'])
            groups.setdefault(key, []).append(row)
    conflicted = set()
    for group in groups.values():
        if len({dumps(row['assertion']['object']) for row in group}) > 1:
            for row in group:
                row['reasons'].append('conflicting_selected_source_values'); conflicted.add(dumps(row['source']))
    withheld.extend(row for row in selected if dumps(row['source']) in conflicted)
    selected = [row for row in selected if dumps(row['source']) not in conflicted]
    return {'profile': PROFILE, 'policyHash': policy_hash, 'sourceSnapshotHash': policy['sourceSnapshotHash'],
        'interpretationProfileHash': snapshot['interpretationProfileHash'], 'sourceScope': snapshot['sourceScope'],
        'sourceMode': snapshot['mode'], 'selected': selected, 'withheld': withheld, 'reviews': review_rows,
        'diagnostics': diagnostics, 'interpretationDiagnostics': [{'source': row['source'], 'status': row['status'],
            'reason': row['reasonCode']} for row in snapshot['statements'] if row['status'] != 'supported'] + [
            {'source': row['source'] | {'pointer': entry['pointer']}, 'status': entry['status'],
                'reason': entry['reasonCode']} for row in snapshot['statements']
            for entry in row['assertionInterpretations'] if entry['status'] != 'supported'],
        'claims': CLAIMS, 'qualification': QUALIFICATION}


def select_artist_reviews(source, policy_raw, policy_hash):
    require(type(source) is NativeArtistReviewSource, 'concrete Artist review source required')
    snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
    return _select(snapshot, policy_raw, policy_hash)
