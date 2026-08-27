import { GOOGLE_RPC_SUNSET } from "@/lib/chlom/constants";
import { runtimeReadiness } from "@/lib/chlom/config";

export const dynamic = "force-dynamic";

export default function Home() {
  const readiness = runtimeReadiness();
  const coreReady =
    readiness.apiTokenConfigured &&
    (readiness.googleAnalyticsConfigured ||
      readiness.configuredRpcChains.length > 0);

  return (
    <main>
      <div className="eyebrow">CrownThrive · CHLOM · Phase 3 Execute</div>
      <h1>Chain Evidence Fabric</h1>
      <p className="lead">
        A governed, provider-neutral blockchain evidence plane. It combines
        bounded JSON-RPC reads, Google Blockchain Analytics through BigQuery,
        deterministic evidence envelopes, DAIL projections, REST contracts,
        and a stateless MCP surface.
      </p>

      <section className="grid" aria-label="Runtime readiness">
        <article className="card">
          <div className={`status ${coreReady ? "" : "hold"}`}>
            {coreReady ? "Runtime ready" : "Configuration hold"}
          </div>
          <h2>Authority boundary</h2>
          <p>
            Read operations are allowlisted. Broadcast remains fail-closed
            unless CHLOM governance is promoted and an exact ECAC digest is
            present.
          </p>
        </article>

        <article className="card">
          <div
            className={`status ${
              readiness.googleAnalyticsConfigured ? "" : "hold"
            }`}
          >
            Google analytics{" "}
            {readiness.googleAnalyticsConfigured ? "configured" : "pending"}
          </div>
          <h2>Durable Google lane</h2>
          <p>
            BigQuery-backed Blockchain Analytics is the durable Google
            integration. Query templates are bounded and bytes-billed are
            capped.
          </p>
        </article>

        <article className="card">
          <div
            className={`status ${
              readiness.configuredRpcChains.length ? "" : "hold"
            }`}
          >
            RPC {readiness.configuredRpcChains.length ? "configured" : "pending"}
          </div>
          <h2>Provider-neutral RPC</h2>
          <p>
            Configured chains:{" "}
            {readiness.configuredRpcChains.join(", ") || "none"}. Google RPC,
            when present, is marked transitional with a {GOOGLE_RPC_SUNSET}{" "}
            sunset.
          </p>
        </article>

        <article className="card">
          <div className="status">MCP registered</div>
          <h2>Agent interoperability</h2>
          <ul>
            <li>Provider status</li>
            <li>Governed chain reads</li>
            <li>Transaction verification</li>
            <li>Blockchain Analytics queries</li>
            <li>Evidence anchor preparation</li>
          </ul>
        </article>

        <article className="card">
          <div className="status">Evidence active</div>
          <h2>DAIL projection</h2>
          <p>
            Each successful operation returns request, payload, and evidence
            digests plus a deterministic DAIL idempotency key.
          </p>
        </article>

        <article className="card">
          <div className="status hold">Broadcast hold</div>
          <h2>Money and mutation</h2>
          <p>
            No private keys are accepted or stored. Raw transaction broadcast
            is inaccessible unless explicit runtime policy and ECAC evidence
            converge.
          </p>
        </article>
      </section>

      <section className="endpoint">
        MCP endpoint: <code>/api/mcp</code>
        <br />
        REST health: <code>/api/health</code>
        <br />
        Governed RPC: <code>/api/v1/rpc</code>
        <br />
        Google analytics: <code>/api/v1/analytics</code>
      </section>

      <footer>
        CHLOM governs Rights, Rules, Roles, Revenue, Records, and Remedies.
        Technical capability never creates institutional authority.
      </footer>
    </main>
  );
}
