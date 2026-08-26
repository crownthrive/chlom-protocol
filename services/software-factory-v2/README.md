# CrownThrive™ Autonomous Software Factory v2

Production control-plane software for CrownThrive, LLC. The runtime is governed by ThriveBase and executes the contract-first pipeline Discover → Architect → Generate → Security → Test → Package → Deploy → Assurance. Successful runs are constrained to one production release package and must carry source, test, security, rights, deployment, rollback, and SHA-256 evidence.

## Production implementation

- Project key: `crownthrive-os-v2-factory`
- Control plane: ThriveBase / Supabase
- Scheduler: `ct-software-factory-dispatch-v3` (internal pg_cron, every minute)
- Worker: `ct-software-factory-worker` v5, Vault-authenticated custom dispatch
- Generator: `ct-factory-generator` v2
- Test runner: `ct-factory-test-runner` v2
- Deployer: `ct-factory-deployer` v2
- Production release: `2.0.1`
- Release SHA-256: `83cb59ca376fc9bec480b9e5a8413d17772021ef916011a02ed4cafd6b97b7bb`
- First fully implemented run: `3b895dd6-db66-4259-8ac9-1715c2f2bf4a`

All eight lanes passed in the production run. The initial package-lane contract failure was corrected and replayed without rerunning already-passed lanes.

## Rights and marks

Copyright © 2026 CrownThrive, LLC. All rights reserved. CrownThrive™, CrownThrive Autonomous Software Factory™, ThriveBase™, and CHLOM™ are used as claimed common-law marks in this software and its generated manifests. The ™ symbol and this repository notice do not represent USPTO registration; federal registration, if desired, requires a separate trademark filing and legal process.

## Runtime security

The worker is not anonymously invokable. Dispatch uses a Vault-resident runtime token validated through `ct_factory_authorize_worker`; raw token material is not persisted in factory artifacts. The deployment ledger has RLS enabled and runtime writes occur through the service-role control plane.
