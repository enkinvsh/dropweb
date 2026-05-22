# Google Play Data Safety Draft

Status: owner review required before Play Console entry.

## Data types to disclose

1. Device or other IDs: HWID or device headers used for subscription or cabinet requests.
2. App activity or diagnostics: only if logs or support diagnostics are uploaded by the user.
3. Personal info: OWNER_INPUT_REQUIRED if account email, phone, Telegram identity, or payment account data is processed by Dropweb backend or cabinet.
4. Financial info: OWNER_INPUT_REQUIRED if payments are handled inside the cabinet flow or linked service.

## Purpose

1. App functionality: authenticate subscriptions, fetch profiles, connect VPN, provide support.
2. Fraud prevention and security: OWNER_INPUT_REQUIRED if device binding or abuse prevention uses HWID.
3. Analytics: OWNER_INPUT_REQUIRED. Mark no analytics if none are present.

## Sharing

OWNER_INPUT_REQUIRED: list backend providers, payment processors, support tools, and hosting providers.

## Retention and deletion

OWNER_INPUT_REQUIRED: align with `docs/play/privacy-policy.md` and `docs/play/account-deletion.md`.
