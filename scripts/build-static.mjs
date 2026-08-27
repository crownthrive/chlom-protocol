import { access, readFile, writeFile } from 'node:fs/promises';
import { constants } from 'node:fs';

const required = [
  'public/index.html',
  'public/styles.css',
  'public/app.js',
  'api/health.js',
  'api/rpc.js',
  'api/analytics.js',
  'api/attest.js',
  'api/mcp.js',
];

for (const file of required) {
  await access(file, constants.R_OK);
}

const index = await readFile('public/index.html', 'utf8');
if (!index.includes('CHLOM Chain Evidence Fabric')) {
  throw new Error('Static control surface identity validation failed.');
}

await writeFile(
  'public/build.json',
  JSON.stringify(
    {
      schema: 'ct.chlom.static-build.v1',
      service: 'chlom-chain-evidence-fabric',
      version: '1.1.0',
      buildSha: process.env.VERCEL_GIT_COMMIT_SHA || null,
      environment: process.env.VERCEL_ENV || 'local',
    },
    null,
    2,
  ) + '\n',
);

console.log('CHLOM_STATIC_FUNCTION_RUNTIME_BUILD_PASS');
