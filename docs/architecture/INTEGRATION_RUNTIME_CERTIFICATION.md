# Integration Runtime Certification

`ct.mesh.integration-runtime-certification.v1` is the machine-readable runtime evidence ledger for integrations registered in `ct.mesh.integrations.v1`.

The certification model separates four states that must never be collapsed:

1. **Registered** — the integration exists in the canonical mesh contract.
2. **Transport reachable** — DNS/TLS/HTTP reachability was observed from the scheduled GitHub runtime.
3. **Authenticated/provider verified** — a connected provider or authenticated runtime successfully returned current provider state.
4. **Mutation certified** — write/delete/admin behavior has been separately proven within its declared scope and governance class.

A 2xx/401/403/404 response can prove transport reachability, but only authenticated evidence can prove credentialed API authority. A provider limit or founder-declared contract is institutional configuration, not proof of endpoint authentication.

The scheduled workflow `.github/workflows/integration-runtime-certification.yml` runs every six hours and on relevant registry/runtime changes. It refreshes `registry/integration-runtime-certification.json`, commits state changes, and opens a degradation issue when a registered endpoint is unreachable.

The runtime certifier never stores secret values and never bypasses provider authentication, rate limits, access controls, circuit breakers, or CHLOM governance.
