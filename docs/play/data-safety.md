# Google Play Data Safety Draft

Status: Pre-submission draft. Not ready for Google Play submission until every OWNER_ACTION_REQUIRED item is resolved.

## Data types to disclose

1. Device or other IDs: HWID or device headers used for subscription or cabinet requests.
2. App activity or diagnostics: only if logs or support diagnostics are uploaded by the user.
3. Personal info: OWNER_ACTION_REQUIRED: confirm whether account email, phone, Telegram identity, cabinet account data, or payment account data is processed by Dropweb backend or cabinet.
4. Financial info: OWNER_ACTION_REQUIRED: confirm whether payments are handled inside the cabinet flow or linked service.

## Purpose

1. App functionality: authenticate subscriptions, fetch profiles, connect VPN, provide support.
2. Fraud prevention and security: OWNER_ACTION_REQUIRED: confirm whether device binding or abuse prevention uses HWID.
3. Analytics: OWNER_ACTION_REQUIRED: confirm whether analytics exist. Mark no analytics only if none are present.

## Sharing

OWNER_ACTION_REQUIRED: list backend providers, payment processors, support tools, hosting providers, and any sharing with service providers.

## Retention and deletion

OWNER_ACTION_REQUIRED: align retention and deletion answers with `docs/play/privacy-policy.md` and `docs/play/account-deletion.md` after backend facts are confirmed.
