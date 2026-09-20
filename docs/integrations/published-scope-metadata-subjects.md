# Publishing metadata for a release, season or view

Publish the original `SCOPE_MEMBERSHIP` record on the collection Metadata host,
then call `registerScopeSubject(membershipRecordHash)` on that same host. Any
account, including a Safe, can register the canonical subject. The returned hash
is the subject for subsequent scoped WORK, RIGHTS and other admitted records.

The host derives the scope type, collection and record-qualified scope ID from
the authenticated publication. Callers cannot supply another host, an arbitrary
subject or a replacement scope tuple. Registration reuses the membership
producer's original receipt, authorization-class, record-index, schema,
canonicalization, native payload and environment checks. The Core, schema and
Store runtimes must still match the Metadata host's immutable pins.

Registration only gives a name to the published scope. It does not grant record
writing permissions, confirm any token membership or establish Artist sanction
or finality. Existing family grants and Artist authorization continue to govern
every record. Membership consumers must separately require the original
membership host's completed validation. Registration can therefore precede
membership indexing or Finality deployment without a construction cycle.

The additive `IStreamMetadataPublishedScopeSubject` interface supports RELEASE,
SEASON and VIEW records. The original Metadata V1 interface identifier, token
registration, storage layout, record hashes and writer checks are unchanged.
Repeated registration of the same valid record is idempotent. Each successful
call emits `MetadataScopeSubjectRegistered` with the derived subject and source
record.

The focused regression source contains eleven cases using actual Metadata,
schema, Store, inventory and membership contracts. Core and governance are
explicit test boundaries. Two cases use original Safe 1.3.0 and 1.4.1 bytecode
and real threshold-signed calls. The 114-source type check passes; native
execution and full current-stack acceptance remain separate pending checks.
