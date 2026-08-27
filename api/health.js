export default function handler(request, response) {
  const environment = process.env.VERCEL_ENV || 'local';
  const providerReadback = environment !== 'local';

  response.setHeader('Cache-Control', 'no-store, max-age=0');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');

  if (!['GET', 'HEAD'].includes(request.method)) {
    return response.status(405).json({
      schema: 'ct.penta.error.v1',
      service: 'chlom-protocol',
      status: 'WRITE_GATED',
      pass_manufactured: false
    });
  }

  return response.status(200).json({
    schema: 'ct.chlom.vercel.health.20260827.v1',
    service: 'chlom-protocol',
    role: 'rights_rules_roles_revenue_records_remedies_authority',
    status: 'OPERATIONAL',
    release: environment === 'production' ? 'production' : 'candidate',
    environment,
    provider_state: providerReadback ? `BOUND_${environment.toUpperCase()}` : 'BINDING_REQUIRED',
    project_id: 'prj_HewLgMjUiVBNCl0FADFbSggSp2QN',
    repository: 'crownthrive1/chlom-protocol',
    build_sha: process.env.VERCEL_GIT_COMMIT_SHA || 'local-candidate',
    deployment_id: process.env.VERCEL_DEPLOYMENT_ID || null,
    capabilities: [
      'identity-and-rights-boundary',
      'policy-and-governance-contracts',
      'consent-and-provenance',
      'licensing-and-revenue-rules',
      'penta-authority-constraints'
    ],
    provider_readback: providerReadback,
    write_state: 'GATED',
    pass_manufactured: false,
    observed_at: new Date().toISOString()
  });
}
