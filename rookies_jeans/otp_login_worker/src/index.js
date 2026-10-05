// Rookies phone-OTP login: a Cloudflare Worker with two endpoints.
//
// The app sends and verifies the OTP itself with the MSG91 OTP widget, which
// hands back a short-lived MSG91 access token. This worker exists only to
// hold the two secrets that must never ship inside the app -- the MSG91
// authkey and the Shopify Admin token -- and to turn "MSG91 confirms this
// phone was verified" into a Shopify customer access token (the same token
// email/password login returns, so orders, addresses and checkout work
// unchanged).
//
//   POST /login     {phone, accessToken}
//       -> {status: "signed_in", accessToken, expiresAt}
//        | {status: "profile_required", verificationToken, firstName, lastName}
//   POST /complete  {verificationToken, email, firstName, lastName}
//       -> {status: "signed_in", accessToken, expiresAt}
//
// "profile_required" means no Shopify customer with an email owns the phone
// yet; the app collects name + email and calls /complete with the ticket.
//
// Shopify classic accounts have no phone login, so the token is minted by:
//   - Multipass (Shopify Plus, SHOPIFY_MULTIPASS_SECRET set): password untouched.
//   - Password mode (default): the worker sets the customer's password to a
//     value only it can derive, then logs in with it. This REPLACES any
//     password the customer had chosen.

const TICKET_TTL_MS = 10 * 60 * 1000;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Cloudflare Workers entry point. Vercel uses api/[action].js, which calls
// the same handleRequest with process.env.
export default {
  fetch: (request, env) => handleRequest(request, env),
};

export async function handleRequest(request, env) {
  // Last path segment: "/login" on Cloudflare, "/api/login" on Vercel.
  const action = new URL(request.url).pathname.split('/').filter(Boolean).pop();
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (request.method === 'GET' && action === 'health') return health(env);
  if (request.method !== 'POST') return json({ error: 'Not found' }, 404);

  const missing = ['SHOPIFY_SHOP_DOMAIN', 'SHOPIFY_STOREFRONT_TOKEN',
    'MSG91_AUTH_KEY', 'SESSION_SECRET'].filter((k) => !env[k]);
  if (!env.SHOPIFY_ADMIN_API_TOKEN && !(env.SHOPIFY_CLIENT_ID && env.SHOPIFY_CLIENT_SECRET)) {
    missing.push('SHOPIFY_CLIENT_ID + SHOPIFY_CLIENT_SECRET');
  }
  if (missing.length > 0) {
    console.error('Missing configuration:', missing.join(', '));
    return json({ error: 'OTP login is not configured yet.' }, 503);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid request.' }, 400);
  }

  try {
    if (action === 'login') return await login(body, env);
    if (action === 'complete') return await complete(body, env);
    return json({ error: 'Not found' }, 404);
  } catch (e) {
    console.error(e);
    return json({ error: 'Could not complete sign in. Please try again.' }, 502);
  }
}

// ---------------------------------------------------------------------------
// Endpoints

// GET /health: can this deployment reach the Shopify Admin API? Reports only
// ok / failed, never tokens or customer data.
async function health(env) {
  try {
    const data = await adminGraphql('{ shop { name } }', {}, env);
    return json({ ok: true, shop: data.shop.name });
  } catch (e) {
    console.error('health:', e);
    return json({ ok: false, error: 'Shopify Admin API not reachable; see logs.' }, 503);
  }
}

async function login(body, env) {
  const claimed = normalizePhone(body?.phone);
  if (!claimed || typeof body?.accessToken !== 'string') {
    return json({ error: 'Invalid request.' }, 400);
  }

  const verified = await verifyMsg91Token(body.accessToken, env);
  if (!verified.ok) return json({ error: verified.error }, 401);

  // The phone is only trusted as MSG91 reports it; the app's copy just has to agree.
  if (verified.phone !== claimed) {
    console.error(`Phone mismatch: app sent ${claimed}, MSG91 verified ${verified.phone}`);
    return json({ error: 'Verification did not match this number. Please try again.' }, 401);
  }

  const customer = await findCustomerByPhone(claimed, env);
  if (customer?.email) return signedIn(customer, env);

  return json({
    status: 'profile_required',
    verificationToken: await createTicket(claimed, env),
    firstName: customer?.firstName || '',
    lastName: customer?.lastName || '',
  });
}

async function complete(body, env) {
  const phone = await readTicket(body?.verificationToken, env);
  if (!phone) {
    return json({ error: 'Your verification expired. Please request a new OTP.' }, 401);
  }

  const email = String(body?.email ?? '').trim().toLowerCase();
  const firstName = String(body?.firstName ?? '').trim();
  const lastName = String(body?.lastName ?? '').trim();
  if (!EMAIL_RE.test(email)) return json({ error: 'Enter a valid email address.' }, 400);
  if (!firstName) return json({ error: 'Enter your first name.' }, 400);

  // Verifying a phone must never grant access to someone else's existing
  // email account, so an email already in use is refused rather than linked.
  const emailOwner = await findCustomerByEmail(email, env);
  let customer = await findCustomerByPhone(phone, env);

  if (emailOwner && emailOwner.id !== customer?.id) {
    return json({
      error: 'This email is already registered. Sign in with email & password instead.',
    }, 409);
  }

  if (customer) {
    customer = await updateCustomer(customer.id, { email, firstName, lastName }, env);
  } else {
    customer = await createCustomer({ phone, email, firstName, lastName }, env);
  }

  return signedIn(customer, env);
}

async function signedIn(customer, env) {
  const token = await issueCustomerAccessToken(customer, env);
  return json({
    status: 'signed_in',
    accessToken: token.accessToken,
    expiresAt: token.expiresAt,
  });
}

// ---------------------------------------------------------------------------
// MSG91

async function verifyMsg91Token(accessToken, env) {
  const res = await fetch('https://control.msg91.com/api/v5/widget/verifyAccessToken', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ authkey: env.MSG91_AUTH_KEY, 'access-token': accessToken }),
  });
  const data = await res.json().catch(() => ({}));

  if (!res.ok || data.type !== 'success') {
    console.error('MSG91 verifyAccessToken rejected:', res.status, JSON.stringify(data));
    return { ok: false, error: 'OTP verification failed or expired. Please request a new OTP.' };
  }

  const phone = phoneFromVerification(data, accessToken);
  if (!phone) {
    // Fail closed: without MSG91 naming the number we can't know whose it is.
    console.error('MSG91 verifyAccessToken: no phone in response:', JSON.stringify(data));
    return { ok: false, error: 'Could not confirm your number. Please try again.' };
  }
  return { ok: true, phone };
}

// MSG91 doesn't document this response's shape, so look in the places it has
// been seen to put the number. The token's own payload is only consulted
// after MSG91 has confirmed the token is genuine (above).
function phoneFromVerification(data, accessToken) {
  const candidates = [
    data.message, data.mobile, data.identifier,
    data.data?.mobile, data.data?.identifier, data.data?.phone,
  ];

  const parts = accessToken.split('.');
  if (parts.length === 3) {
    try {
      const claims = JSON.parse(new TextDecoder().decode(fromBase64Url(parts[1])));
      candidates.push(claims.identifier, claims.mobile, claims.phone,
        claims.data?.identifier, claims.data?.mobile);
    } catch {
      // Not a JWT; rely on the response body.
    }
  }

  for (const value of candidates) {
    const phone = typeof value === 'string' || typeof value === 'number'
      ? normalizePhone(String(value))
      : null;
    if (phone) return phone;
  }
  return null;
}

// Returns E.164 ("+919876543210") or null. Bare 10-digit numbers are Indian.
function normalizePhone(raw) {
  if (typeof raw !== 'string') return null;
  let digits = raw.trim().replace(/[\s()-]/g, '');
  if (!/^\+?\d+$/.test(digits)) return null;
  if (digits.startsWith('+')) digits = digits.slice(1);
  else if (digits.length === 10) digits = `91${digits}`;

  if (!/^\d{10,15}$/.test(digits)) return null;
  if (digits.startsWith('91') && !/^91[6-9]\d{9}$/.test(digits)) return null;
  return `+${digits}`;
}

// ---------------------------------------------------------------------------
// Verification ticket: proves "this phone passed OTP" to /complete without
// storage. HMAC-signed, expires after TICKET_TTL_MS.

async function createTicket(phone, env) {
  const payload = toBase64Url(new TextEncoder().encode(
    JSON.stringify({ phone, exp: Date.now() + TICKET_TTL_MS }),
  ));
  return `${payload}.${toBase64Url(await hmac(env.SESSION_SECRET, `otp-ticket:${payload}`))}`;
}

async function readTicket(ticket, env) {
  if (typeof ticket !== 'string') return null;
  const [payload, signature] = ticket.split('.');
  if (!payload || !signature) return null;

  const key = await hmacKey(env.SESSION_SECRET, ['verify']);
  let valid = false;
  try {
    valid = await crypto.subtle.verify(
      'HMAC', key, fromBase64Url(signature), new TextEncoder().encode(`otp-ticket:${payload}`),
    );
  } catch {
    return null;
  }
  if (!valid) return null;

  try {
    const { phone, exp } = JSON.parse(new TextDecoder().decode(fromBase64Url(payload)));
    return typeof phone === 'string' && Date.now() < exp ? phone : null;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Shopify

const CUSTOMER_FIELDS = 'id email phone firstName lastName';

// Admin API token. Dev Dashboard apps (Shopify no longer allows new
// admin-created custom apps) get one from the client credentials grant; it
// lasts 24h, so it's cached per worker instance and renewed a few minutes
// early. A legacy permanent SHOPIFY_ADMIN_API_TOKEN (shpat_...) still wins.
let cachedAdminToken = null; // { token, expiresAt }

async function adminToken(env) {
  if (env.SHOPIFY_ADMIN_API_TOKEN) return env.SHOPIFY_ADMIN_API_TOKEN;
  if (cachedAdminToken && Date.now() < cachedAdminToken.expiresAt) {
    return cachedAdminToken.token;
  }

  const res = await fetch(`https://${env.SHOPIFY_SHOP_DOMAIN}/admin/oauth/access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: env.SHOPIFY_CLIENT_ID,
      client_secret: env.SHOPIFY_CLIENT_SECRET,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) {
    throw new Error(`Shopify client credentials grant failed (${res.status}): ${JSON.stringify(data)}`);
  }

  const lifetimeMs = (Number(data.expires_in) || 86399) * 1000;
  cachedAdminToken = {
    token: data.access_token,
    expiresAt: Date.now() + lifetimeMs - 5 * 60 * 1000,
  };
  return cachedAdminToken.token;
}

async function adminGraphql(query, variables, env) {
  const res = await fetch(
    `https://${env.SHOPIFY_SHOP_DOMAIN}/admin/api/${apiVersion(env)}/graphql.json`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': await adminToken(env),
      },
      body: JSON.stringify({ query, variables }),
    },
  );
  const json = await res.json();
  if (!res.ok || json.errors) {
    throw new Error(`Shopify Admin API: ${json.errors?.[0]?.message || res.status}`);
  }
  return json.data;
}

async function storefrontGraphql(query, variables, env) {
  const res = await fetch(
    `https://${env.SHOPIFY_SHOP_DOMAIN}/api/${apiVersion(env)}/graphql.json`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': env.SHOPIFY_STOREFRONT_TOKEN,
      },
      body: JSON.stringify({ query, variables }),
    },
  );
  const json = await res.json();
  if (!res.ok || json.errors) {
    throw new Error(`Shopify Storefront API: ${json.errors?.[0]?.message || res.status}`);
  }
  return json.data;
}

const apiVersion = (env) => env.SHOPIFY_API_VERSION || '2026-04';

function assertNoUserErrors(errors, context) {
  if (errors && errors.length > 0) {
    throw new Error(`${context}: ${errors.map((e) => e.message).join('; ')}`);
  }
}

// Search values are quoted so "+" and "@" aren't parsed as query syntax.
const quoted = (value) => `"${value.replace(/["\\]/g, '')}"`;

async function findCustomerByPhone(phone, env) {
  const data = await adminGraphql(
    `query ($q: String!) { customers(first: 1, query: $q) { nodes { ${CUSTOMER_FIELDS} } } }`,
    { q: `phone:${quoted(phone)}` },
    env,
  );
  const customer = data.customers.nodes[0] || null;
  // Shopify's search is fuzzy; only trust an exact match.
  return customer && customer.phone === phone ? customer : null;
}

async function findCustomerByEmail(email, env) {
  const data = await adminGraphql(
    `query ($q: String!) { customers(first: 1, query: $q) { nodes { ${CUSTOMER_FIELDS} } } }`,
    { q: `email:${quoted(email)}` },
    env,
  );
  const customer = data.customers.nodes[0] || null;
  return customer && customer.email?.toLowerCase() === email ? customer : null;
}

async function createCustomer(input, env) {
  const data = await adminGraphql(
    `mutation ($input: CustomerInput!) {
      customerCreate(input: $input) { customer { ${CUSTOMER_FIELDS} } userErrors { message } }
    }`,
    { input },
    env,
  );
  assertNoUserErrors(data.customerCreate.userErrors, 'customerCreate');
  return data.customerCreate.customer;
}

async function updateCustomer(id, fields, env) {
  const data = await adminGraphql(
    `mutation ($input: CustomerInput!) {
      customerUpdate(input: $input) { customer { ${CUSTOMER_FIELDS} } userErrors { message } }
    }`,
    { input: { id, ...fields } },
    env,
  );
  assertNoUserErrors(data.customerUpdate.userErrors, 'customerUpdate');
  return data.customerUpdate.customer;
}

function unwrapToken(result, context) {
  const errors = result.customerUserErrors || [];
  if (errors.length > 0 || !result.customerAccessToken) {
    throw new Error(`${context}: ${errors.map((e) => e.message).join('; ') || 'no token'}`);
  }
  return result.customerAccessToken;
}

async function issueCustomerAccessToken(customer, env) {
  if (env.SHOPIFY_MULTIPASS_SECRET) {
    const data = await storefrontGraphql(
      `mutation ($token: String!) {
        customerAccessTokenCreateWithMultipass(multipassToken: $token) {
          customerAccessToken { accessToken expiresAt }
          customerUserErrors { message }
        }
      }`,
      { token: await multipassToken(customer, env.SHOPIFY_MULTIPASS_SECRET) },
      env,
    );
    return unwrapToken(data.customerAccessTokenCreateWithMultipass, 'Multipass login');
  }

  // Shopify caps classic-account passwords at 40 characters.
  const password = toBase64Url(
    await hmac(env.SESSION_SECRET, `shopify-customer:${customer.id}`),
  ).slice(0, 40);
  const numericId = customer.id.split('/').pop();

  const res = await fetch(
    `https://${env.SHOPIFY_SHOP_DOMAIN}/admin/api/${apiVersion(env)}/customers/${numericId}.json`,
    {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': await adminToken(env),
      },
      body: JSON.stringify({
        customer: { id: Number(numericId), password, password_confirmation: password },
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`Setting customer password failed (${res.status}): ${await res.text()}`);
  }

  const data = await storefrontGraphql(
    `mutation ($input: CustomerAccessTokenCreateInput!) {
      customerAccessTokenCreate(input: $input) {
        customerAccessToken { accessToken expiresAt }
        customerUserErrors { message }
      }
    }`,
    { input: { email: customer.email, password } },
    env,
  );
  return unwrapToken(data.customerAccessTokenCreate, 'Password login');
}

// https://shopify.dev/docs/api/multipass
async function multipassToken(customer, secret) {
  const keyMaterial = new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret)),
  );
  const encryptionKey = await crypto.subtle.importKey(
    'raw', keyMaterial.slice(0, 16), 'AES-CBC', false, ['encrypt'],
  );

  const payload = JSON.stringify({
    email: customer.email,
    first_name: customer.firstName || undefined,
    last_name: customer.lastName || undefined,
    created_at: new Date().toISOString(),
  });

  const iv = crypto.getRandomValues(new Uint8Array(16));
  const encrypted = new Uint8Array(await crypto.subtle.encrypt(
    { name: 'AES-CBC', iv }, encryptionKey, new TextEncoder().encode(payload),
  ));
  const ciphertext = concat(iv, encrypted);
  const signature = await hmacBytes(keyMaterial.slice(16, 32), ciphertext);

  return toBase64Url(concat(ciphertext, signature));
}

// ---------------------------------------------------------------------------
// Bytes & crypto helpers

// The Flutter web build calls this from a browser, which needs CORS. Any
// origin is fine: no cookies are used and every call is gated by the OTP.
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Accept',
  'Access-Control-Max-Age': '86400',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function hmacKey(secret, usages) {
  return crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, usages,
  );
}

async function hmac(secret, message) {
  const key = await hmacKey(secret, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)));
}

async function hmacBytes(keyBytes, data) {
  const key = await crypto.subtle.importKey(
    'raw', keyBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, data));
}

function concat(a, b) {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function toBase64Url(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(text) {
  const base64 = text.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}
