# PentaRoute v3 — Full Primitive Catalog and OS Inventory

Canonical Phase 3 execution family. The same catalog is exposed to machines through `public.pentaroute_catalog_v3()` / the `penta-primitives` Edge Function and to humans through this document and `public.pentaroute_human_catalog_v3`.

## Active PentaRoute primitives (51)

PentaAudit, PentaAuth, PentaBeata, PentaBind, PentaCache, PentaCertify, PentaCompile, PentaCreate, PentaDelete, PentaDeploy, PentaDiscover, PentaDispatch, PentaEvent, PentaExport, PentaFetch, PentaGenerate, PentaGet, PentaHead, PentaHook, PentaImport, PentaIngest, PentaList, PentaLock, PentaObserve, PentaOptions, PentaParse, PentaPatch, PentaPost, PentaPut, PentaQuery, PentaQueue, PentaRead, PentaReconcile, PentaRelease, PentaResolve, PentaRetry, PentaRollback, PentaRoute, PentaSchedule, PentaSearch, PentaSign, PentaSnapshot, PentaStream, PentaSync, PentaTest, PentaTransform, PentaTun, PentaUpdate, PentaUpsert, PentaValidate, PentaVault.

Mutation-capable primitives do not grant authority. Exact operation/path certification and CHLOM risk controls remain authoritative. D3 remains human-governed; universal delete is not enabled.

## Penta identities independently found in the OS (not inferred from chat naming)

- PentaMedia — asset bindings, maintenance receipts, maintenance cycle, public status.
- PentaBooks — books, editions, assets, sources, bindings, standards, QA runs, events, canon facts, system state, public catalog; deployed `penta-books-control` and `penta-books-public`.
- PentaGeneration — assets, bindings, events, handoffs, horizons, proofs, system state; deployed `penta-generation`.
- PentaStudios — assets, provider bindings, routes; deployed `penta-studios-control` and `penta-studios-mcp`.
- Penta Federation — federation bindings, events, proofs, system state; deployed `penta-federation-control` and `penta-federation-mcp`.
- PentaFramework Factory — deployed `pentaframework-factory`.
- Penta Control — deployed `penta-control-v1`.
- Penta MCP — deployed `penta-mcp-v1`.
- PentaRoute — routing/transport family and receipts.

## Proprietary/branded system families present in the OS service registry

AdLuxe Network; CHLOM Core; CHLOM Proprietary Factory; CHLOM Public Resolver; CHLOM Wallet; CHLOM Wallet Continuity; Crown Credits; CrownLytics; CrownPulse Admin; CrownRewards; CrownThrive API Control; CrownThrive ID; CrownThrive Interoperability Plugin; CrownThrive IO; CrownThrive IO Product Sandbox; CrownThrive Services Stack; CrownThrive Sites Mesh; Framework Factory v2; Locticians; Shop Melanin Magic/Squarespace control; ThriveEvergreen; ThriveLedger; ThrivePush; ThriveTools OPT; ThriveTools SEO; Virality Commerce; Virality Music; CrownThrive IO cPanel control.

## Additional proprietary runtime families visible in deployed production functions

CrownThrive Autonomous OS v2; CrownThrive OS v2 Runtime; CrownThrive Asset Fabric; CrownThrive Continuity Compiler; Repository Federation Bus; Ecosystem Rollout Control; Developer Marketplace runtime/factory/delivery/review/QA family; Commercial Gap certification/sites/private-fulfillment family; Software Factory (`ct-software-factory-worker`, generator, compiler, test runner, deployer, provider certifier, provider adapters, blueprint planner, property binder); Framework Factory; CHLOM Mesh; CHLOM Project Control; CHLOM Publication Worker/Bridge; CHLOM Vault Gateway/Broker; CHLOM GitHub Executor Bridge; CHLOM Interoperability Control; CHLOM Agent Wallet; KJV Commerce; Credit Commerce; Virality Commerce; ThriveEvergreen production/fabric/commerce/storefront; ThriveBase queue/FTPS/self-diagnostic/self-heal surfaces; CrownThrive Sites Mesh/canary; CrownThrive IO CRUD/write/sandbox; Locticians API/public/MCP/cache/certification surfaces; Google Cloud/Functions/API Keys/Maps routing controls.

## Readability contract

- Human-readable: canonical names, roles, descriptions, risk class, runtime and state are exposed via `public.pentaroute_human_catalog_v3` and this document.
- Machine-readable: `public.pentaroute_catalog_v3()` returns the same canonical component records as JSON; the live `penta-primitives` endpoint exposes that JSON contract.
- Canonical authority: ThriveBase registry + CHLOM v3 operation certification. Documentation is a projection, not a second source of authority.
