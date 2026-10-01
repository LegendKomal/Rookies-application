# Rookies OTP login worker

A single small Cloudflare Worker (free tier is plenty) that lets the app sign
customers in with an MSG91 phone OTP. No panel, no UI, nothing to keep running —
deploy once.

The app sends and verifies the OTP itself through MSG91's OTP widget. This
worker only exists to hold the two secrets that must never ship inside the app
(the MSG91 authkey and the Shopify Admin token) and to exchange "MSG91 verified
this phone" for a Shopify customer access token. See the header of
[`src/index.js`](src/index.js) for the full flow.

## 1. MSG91: create a separate OTP widget for the app

Leave the website's existing **OTPLOGIN** widget exactly as it is (web
integration ON, Mobile Integration OFF). Turning on Mobile Integration makes a
widget mobile-only, so the app gets its own widget and both run side by side.

MSG91 dashboard → **OTP** → **Create New Widget**:

- Name it e.g. `OTPLOGIN_APP`, select **Login using OTP**.
- Channels: SMS (your DLT-approved OTP template + sender ID) with WhatsApp as
  fallback — the app offers "Resend via WhatsApp". The same sender/templates
  as the website are fine.
- In the widget's Settings, turn on **Mobile Integration** and choose your
  platform(s).
- Copy the **Widget ID** and **Token** into `lib/constant/shopify_constants.dart`
  (`msg91WidgetId`, `msg91TokenAuth`). These are meant to be in the app.
- Copy your **Authkey** (top bar → AuthKey) for step 3. This one is secret.

No redirect/webhook is needed: the app sends the MSG91 access token to this
worker, which validates it with MSG91 before issuing the Shopify session.

## 2. Shopify: Admin API token

Shopify Admin → Settings → Apps and sales channels → Develop apps → create an
app (or reuse one) with scopes `read_customers` and `write_customers`, install
it, and copy the `shpat_...` token.

## 3. Deploy

```bash
cd otp_login_worker
npm install
npx wrangler login
npx wrangler secret put MSG91_AUTH_KEY
npx wrangler secret put SHOPIFY_ADMIN_API_TOKEN
npx wrangler secret put SHOPIFY_STOREFRONT_TOKEN
npx wrangler secret put SESSION_SECRET
npm run deploy
```

- `SHOPIFY_STOREFRONT_TOKEN`: the same Storefront token the app uses.
- `SESSION_SECRET`: any long random string (e.g. `openssl rand -hex 32`).
- Optional, Shopify Plus only: `SHOPIFY_MULTIPASS_SECRET` (Settings → Customer
  accounts → Multipass). See below.

`npm run deploy` prints the worker URL — put it in `otpLoginUrl` in
`lib/constant/shopify_constants.dart`. `npm run logs` streams live logs if
something fails.

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
