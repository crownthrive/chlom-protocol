import { getVercelOidcToken } from "@vercel/oidc";
import {
  ExternalAccountClient,
  GoogleAuth,
  type AuthClient,
} from "google-auth-library";
import { ChlomError } from "./errors";

const BIGQUERY_SCOPES = ["https://www.googleapis.com/auth/bigquery"];
let cachedClient: AuthClient | undefined;

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new ChlomError(
      "CHLOM_GCP_CONFIGURATION_INCOMPLETE",
      `Missing required Google Cloud configuration: ${name}`,
      503,
    );
  }
  return value;
}

async function createVercelFederatedClient(): Promise<AuthClient> {
  const projectNumber = requiredEnvironment("GCP_PROJECT_NUMBER");
  const serviceAccountEmail = requiredEnvironment(
    "GCP_SERVICE_ACCOUNT_EMAIL",
  );
  const poolId = requiredEnvironment("GCP_WORKLOAD_IDENTITY_POOL_ID");
  const providerId = requiredEnvironment(
    "GCP_WORKLOAD_IDENTITY_POOL_PROVIDER_ID",
  );

  const audiencePath =
    `//iam.googleapis.com/projects/${projectNumber}` +
    `/locations/global/workloadIdentityPools/${poolId}` +
    `/providers/${providerId}`;
  const tokenAudience = `https:${audiencePath}`;

  const client = ExternalAccountClient.fromJSON({
    type: "external_account",
    audience: audiencePath,
    subject_token_type: "urn:ietf:params:oauth:token-type:jwt",
    token_url: "https://sts.googleapis.com/v1/token",
    service_account_impersonation_url:
      "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/" +
      `${serviceAccountEmail}:generateAccessToken`,
    scopes: BIGQUERY_SCOPES,
    subject_token_supplier: {
      getSubjectToken: () =>
        getVercelOidcToken({ audience: tokenAudience }),
    },
  });

  if (!client) {
    throw new ChlomError(
      "CHLOM_GCP_FEDERATION_CLIENT_FAILED",
      "Google external-account client could not be initialized.",
      503,
    );
  }

  return client;
}

async function createLocalAdcClient(): Promise<AuthClient> {
  const auth = new GoogleAuth({ scopes: BIGQUERY_SCOPES });
  return auth.getClient();
}

export async function getGoogleAuthClient(): Promise<AuthClient> {
  if (cachedClient) {
    return cachedClient;
  }

  cachedClient = process.env.VERCEL
    ? await createVercelFederatedClient()
    : await createLocalAdcClient();

  return cachedClient;
}

export async function getGoogleAccessToken(): Promise<string> {
  const client = await getGoogleAuthClient();
  const token = await client.getAccessToken();

  if (!token.token) {
    throw new ChlomError(
      "CHLOM_GCP_ACCESS_TOKEN_FAILED",
      "Google Cloud did not issue an access token.",
      502,
    );
  }

  return token.token;
}
