function metric(label, value) {
  const item = document.createElement('div');
  item.className = 'metric';
  const name = document.createElement('span');
  name.textContent = label;
  const data = document.createElement('strong');
  data.textContent = value;
  item.append(name, data);
  return item;
}

async function hydrateHealth() {
  const state = document.getElementById('runtime-state');
  const observed = document.getElementById('runtime-observed');
  const dot = document.getElementById('runtime-dot');
  const grid = document.getElementById('readiness-grid');

  try {
    const response = await fetch('/api/health', { cache: 'no-store' });
    const payload = await response.json();
    const providerState = payload.status || `HTTP ${response.status}`;
    const readinessState = payload.readinessStatus || payload.readiness_status || payload.status;
    state.textContent = `${providerState} · ${readinessState}`;
    const observedAt = payload.observedAt || payload.observed_at;
    observed.textContent = observedAt ? `Observed ${observedAt}` : '';
    dot.className = providerState === 'OPERATIONAL' && readinessState === 'READY' ? 'dot' : 'dot hold';
    const readiness = payload.readiness || {};
    grid.replaceChildren(
      metric('API perimeter', readiness.apiTokenConfigured ? 'Configured' : 'Pending'),
      metric('Google Analytics', readiness.googleAnalyticsConfigured ? 'Configured' : 'Pending'),
      metric('RPC chains', (readiness.configuredRpcChains || []).join(', ') || 'None configured'),
      metric('RPC providers', (readiness.configuredRpcProviders || []).join(', ') || 'None configured'),
      metric('Governance', readiness.governanceState || 'hold'),
      metric('Chain broadcast', readiness.chainWriteEnabled ? 'Enabled by policy' : 'Disabled'),
    );
  } catch (error) {
    state.textContent = 'READBACK_FAILED';
    observed.textContent = String(error?.message || error);
    dot.className = 'dot bad';
    grid.replaceChildren(metric('Runtime readback', 'Failed'));
  }
}

hydrateHealth();
