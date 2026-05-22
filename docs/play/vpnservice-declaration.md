# Google Play VpnService Declaration Draft

Status: Pre-submission draft. Not ready for Google Play submission until every OWNER_ACTION_REQUIRED item is resolved.

OWNER_ACTION_REQUIRED: create and verify the Play Console organization, IP account, or physical-person account before submission.

OWNER_ACTION_REQUIRED: provide D-U-N-S details if the organization path requires them.

OWNER_ACTION_REQUIRED: record and provide the VpnService demo video URL before submitting this declaration.

## Core purpose

Dropweb is a VPN client. VPN functionality is the app's core user-facing purpose.

## VpnService use

Dropweb uses Android `VpnService` to create a device VPN tunnel, route traffic through user-selected proxy profiles, and provide split tunneling where configured by the user.

## User disclosure

The app must show clear in-app information that enabling the main connection starts a VPN tunnel. Store listing text must also say Dropweb is a VPN client.

## Permissions needing explanation

1. `android.permission.BIND_VPN_SERVICE`: required by the VPN service.
2. `android.permission.QUERY_ALL_PACKAGES`: confirm this permission is absent. If the execution branch declares it, document the exact per-app VPN app-selection need, justify it honestly for Play, or remove it before submission.
3. Foreground service permissions: used to keep the VPN session active.
4. `POST_NOTIFICATIONS`: used for VPN status notifications on Android 13 and later.
5. `RECEIVE_BOOT_COMPLETED`: OWNER_ACTION_REQUIRED: confirm this permission is absent or document the Play-safe auto-start or reconnect need if enabled.
6. `USE_FULL_SCREEN_INTENT`: OWNER_ACTION_REQUIRED: confirm this permission is absent. Remove it if no user-visible Play-safe need remains.

## Not used for prohibited behavior

Dropweb must not use `VpnService` to collect user traffic for sale, manipulate ads, bypass other apps' monetization, or mislead users about traffic handling.
