# Solidity caller contracts

- [Stream domain APIs](stream/README.md) are the public protocol interfaces.
- `standards/` contains ERC caller interfaces shared by protocol components.
- `compatibility/` retains the historical Core and compatibility boundaries.
- `stream/legacy/` contains the previous mint, auction, and entropy APIs.

External service protocols stay with their adapters under
[../integrations](../integrations). Vendored interfaces retain their original
identity under [../vendor](../vendor). Implementations belong in `domains/` or
`core/`; a shared caller interface should not be declared inside an implementation
file.
