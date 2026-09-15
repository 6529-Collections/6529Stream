# Artist and Metadata publication after hydration

`StreamArtistMetadataPublicationJoinTest` joins the actual Artist Registry,
Coordinator, seven owners and Archive with the same actual
`StreamCollectionMetadataV1`, schema registry, byte store and threshold Safe.
The source suite publishes and consumes both detached intent (kind 7) and
statement (kind 8) approvals before replacement. The successor executes the
original history-root operation 55, both lane verifications under operation 56,
the original Registry seal under operation 57, and the explicit complete
publication hydration profile under operation 60.

The three authored cases cover:

- Fresh kind 7 and kind 8 approvals signed in the successor Registry domain,
  consumed through the original Metadata host. Independent original op24 and
  Metadata record preimages, complete stored bytes and receipts, original spent
  permits, and the actual Safe caller in the consumption event are checked.
- A sealed history without completed authority hydration remains unavailable;
  an original Registry signature cannot authorize the fresh successor write.
- An injected late Archive failure rolls back owner roots, stored carriers and
  Safe nonce. The exact signed operation retries after restoration. A wrong
  current Metadata pointer also preserves the fresh permit and Safe nonce,
  allowing the identical Metadata transaction after restoration.

The positive case invokes the actual fixed Artist candidate reader after cooling
both suites, their current proof dependencies and the selected payload. Its
original governed callback budget remains 400,000 gas. This is an authored
integration assertion until the frozen native cohort executes; an ABI check
does not establish its gas outcome.

The original seven publication-hydration test bodies are unchanged. Their common
helpers are extracted into `ArtistPublicationHydrationFixture` with protected
visibility so the joined cases use the same original operations and complete
source input construction. The shared `ArtistOnboardingFixture` is unchanged.

Core pointer administration, governance execution and the separate Metadata
router remain explicit typed test boundaries. Positive paths do not inject
Artist permits, owner completion markers, history or candidate responses. This
is not an actual Core/Executor deployment, a broadcast, or a full-system
acceptance claim. No native campaign was launched for this source handoff.
