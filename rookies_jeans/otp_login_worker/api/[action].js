// Vercel entry point: POST /api/login and POST /api/complete run the same
// handler as the Cloudflare Worker (src/index.js). Secrets come from the
// project's Environment Variables in Vercel, never from this repo.
import { handleRequest } from '../src/index.js';

// Non-secret settings (wrangler.toml [vars] on Cloudflare).
const defaults = {
  SHOPIFY_SHOP_DOMAIN: 'rookies-jeans.myshopify.com',
  SHOPIFY_API_VERSION: '2026-04',
};

// Values pasted into the dashboard can carry stray tabs/spaces/newlines.
const trimmedEnv = () => Object.fromEntries(
  Object.entries(process.env).map(([k, v]) => [k, typeof v === 'string' ? v.trim() : v]),
);

export function POST(request) {
  return handleRequest(request, { ...defaults, ...trimmedEnv() });
}

// GET /api/health only; OPTIONS is the browser's CORS preflight (web build).
export const GET = POST;
export const OPTIONS = POST;
