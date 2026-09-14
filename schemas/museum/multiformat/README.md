# Multi-format package fixture

The seven canonical JSON files under fixture/ are public synthetic inputs for tools.museum.package_v2, not registered schemas or actual chain records. They retain the existing four-media LIDO/IIIF/PREMIS/Linked Art fixture with an explicit issuer distinct from its creator.

source-state.json contains fixture records and exact schema bytes. selection.json and the four projection plans select the same state/profile. pins.json retains the caller pins and interpretation-policy hashes.

See [the package guide](../../../docs/museum-multiformat-package.md) for build and offline replay commands. Original schema versions and historical package/release evidence remain unchanged.

The separate recorded/pins.json references the unchanged actual local-EVM capture
in account-profile/local-fixture. Its source/publication/interpretation pins are
original transcript hashes, and its other pins select the registered account
profile and original plans. It introduces no fabricated captured records or new
registered schema. The recorded package retains Linked Art output and explicit
unsupported statuses for PREMIS/IIIF/LIDO.
