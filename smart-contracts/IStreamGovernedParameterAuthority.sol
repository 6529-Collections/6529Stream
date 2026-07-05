// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Narrow wiring seam between Governed Gas/Time Parameter hosts and the
///         canonical governance action executor of `docs/adr/0004-admin-governance.md`
///         [GOV-ACTION-ID]/[GOV-WINDOWS].
/// @dev    WIRING SEAM (W1-GGP <-> W1-GOV). The parameter hosts in this wave
///         (`StreamGasParameterHost`, `StreamTimeParameterHost`) accept one authority
///         address at construction and gate every governed entry point
///         (`raiseGasParameter`, `emergencyRaiseGasParameter`, `lowerGasParameter`,
///         `raiseTimeParameter`, `lowerTimeParameter`) on `msg.sender == authority`.
///         The real executor — built by the governance wave — must:
///           1. schedule staged raises and lowers on the normal delay class and the
///              emergency raise on the emergency class, per [GOV-WINDOWS];
///           2. call the host entry point at execution time, passing the canonical
///              [GOV-ACTION-ID] `actionId` of the executing action, which the host
///              echoes verbatim into the canonical `GasParameterUpdated` /
///              `TimeParameterUpdated` change event;
///           3. treat the host as the execution-recheck locus: the host re-verifies
///              floors, per-action bounds, and probe records at execution time, so a
///              staged action whose probe obligation has gone stale reverts here.
///         Hosts never verify `actionId` derivation — the [GOV-ACTION-ID] preimage is
///         owned by the governance contract and restating it is nonconformant.
interface IStreamGovernedParameterAuthority {
    /// @notice Returns true for deployment-time wiring validation.
    function isStreamGovernedParameterAuthority() external view returns (bool);
}
