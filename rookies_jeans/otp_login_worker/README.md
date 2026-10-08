# Rookies OTP login backend

A tiny backend (OTP login + account deletion; Vercel or Cloudflare free tier is plenty) that
lets the app sign customers in with an MSG91 phone OTP. No panel, no UI,
nothing to keep running — deploy once.

The app sends and verifies the OTP itself through MSG91's OTP widget. This
worker only exists to hold the two secrets that must never ship inside the app
(the MSG91 authkey and the Shopify Admin token) and to exchange "MSG91 verified
this phone" for a Shopify customer access token. See the header of
[`src/index.js`](src/index.js) for the full flow.

## 1. MSG91: nothing to create

The app shares the website's existing **OTPLOGIN** widget. It calls the same
web widget endpoints (`/api/v5/widget/sendOtp`, `retryOtp`, `verifyOtp`) that
the site's widget script uses, so the widget stays exactly as it is (Mobile
Integration OFF — do not turn it on, that would make it mobile-only and break
the website). Its Widget ID and Token are already in
`lib/constant/shopify_constants.dart` (`msg91WidgetId`, `msg91TokenAuth`);
both are public, the storefront prints them on every page.

All you need from MSG91 is your **Authkey** (top bar → AuthKey) for step 3.
This one is secret.

No redirect/webhook is needed: the app sends the MSG91 access token to this
worker, which validates it with MSG91 before issuing the Shopify session.

## 2. Shopify: an app with customer access

Shopify no longer lets you create new apps under Settings → Apps → Develop
apps, so create one in the **Dev Dashboard** (dev.shopify.com, or Shopify
Admin → Settings → Apps → Develop apps → "Build apps in Dev Dashboard"):

1. **Create app** → name it e.g. `Rookies OTP Login`.
2. On the app's version, set **Access scopes** to `read_customers` and
   `write_customers` (plus `write_customer_data_erasure` for account
   deletion of customers who have orders), then **Release** the version.
3. **Install** the app on the Rookies store and approve the permissions.
4. **App settings** → copy the **Client ID** and **Client secret** for step 3.

The worker swaps these for a short-lived Admin API token (client credentials
grant, valid 24h, renewed automatically). If you already have an older
admin-created app with a `shpat_...` token, you can set that as
`SHOPIFY_ADMIN_API_TOKEN` instead and skip the client ID/secret.

## 3. Deploy

The same code runs on **Vercel** (`api/[action].js`) or **Cloudflare Workers**
(`src/index.js` + `wrangler.toml`). Either way it needs these secrets:

| Name | Value |
|---|---|
| `MSG91_AUTH_KEY` | MSG91 Authkey (step 1) |
| `SHOPIFY_CLIENT_ID` | Client ID (step 2) |
| `SHOPIFY_CLIENT_SECRET` | Client secret (step 2) |
| `SHOPIFY_STOREFRONT_TOKEN` | the same Storefront token the app uses |
| `SESSION_SECRET` | any long random string (e.g. `openssl rand -hex 32`) |

Optional, Shopify Plus only: `SHOPIFY_MULTIPASS_SECRET` (Settings → Customer
accounts → Multipass). See below.

### Vercel (from the dashboard, no terminal)

1. Push this folder to GitHub (it's in the Rookies-application repo).
2. vercel.com → **Add New… → Project** → import `Rookies-application`.
3. **Root Directory**: `rookies_jeans/otp_login_worker`. Framework preset:
   **Other**. Leave build settings empty.
4. **Environment Variables**: add the five secrets above.
5. **Deploy**. Put `https://<project>.vercel.app/api` in `otpLoginUrl` in
   `lib/constant/shopify_constants.dart` (the app adds `/login`, `/complete`, `/delete-account`).

Logs: the project's **Logs** tab. Changing a variable needs a **Redeploy**.

### Cloudflare Workers (terminal)

```bash
cd otp_login_worker
npm install
npx wrangler login
npx wrangler secret put MSG91_AUTH_KEY      # …and the other four secrets
npm run deploy
```

`npm run deploy` prints the worker URL — put it (no `/api`) in `otpLoginUrl`.
`npm run logs` streams live logs if something fails.

## How the Shopify login is created

Shopify classic customer accounts have no "log in by phone", so:

- **Multipass** (`SHOPIFY_MULTIPASS_SECRET` set, Shopify Plus): the customer's
  password is never touched.
- **Password mode** (default): the worker sets the customer's password to a
  secret value only it can derive, then logs in with it. This **replaces the
  password the customer chose**, so after their first OTP login, email +
  password sign-in needs "Forgot password" first.

A phone with no Shopify customer (or one without an email) gets asked for name
+ email in the app. An email that already belongs to another customer is
refused, so verifying a phone can never take over someone else's account.
