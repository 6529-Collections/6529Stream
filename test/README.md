# Tests

Foundry tests belong in this directory.

The initial characterization tests are intentionally self-contained and do not
depend on `forge-std`. They use small local assertion helpers, a minimal
cheatcode interface, fixtures, and mocks so `forge test -vvv` works from a
fresh checkout after the documented Foundry setup.

These tests lock current behavior before P0 rewrites. Some asserted behavior is
known to be unsafe, such as `tx.origin`-based drop execution; those tests are
regression tripwires and should be updated only when the corresponding roadmap
fix changes the intended behavior.
