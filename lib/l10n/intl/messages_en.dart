// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(wait) => "Too many attempts, wait ${wait}";

  static String m1(n) => "${n} h";

  static String m2(n) => "${n} min";

  static String m3(n) => "${n} s";

  static String m4(host) => "Add ${host}";

  static String m5(label) =>
      "Are you sure you want to delete the current ${label}?";

  static String m6(path) => "Diagnostics: ${path}";

  static String m7(label) => "${label} cannot be empty";

  static String m8(label) => "Current ${label} already exists";

  static String m9(version) => "Version ${version} is available";

  static String m10(version, core) => "Version ${version}, core ${core}";

  static String m11(n) => "Color ${n}";

  static String m12(n) => "Shade ${n}";

  static String m13(name) => "Delete “${name}”?";

  static String m14(count) =>
      "${Intl.plural(count, one: '${count} day left', other: '${count} days left')}";

  static String m15(traffic, term) => "${traffic} · ${term}";

  static String m16(left) => "${left} GB left";

  static String m17(used, total) => "${used} of ${total} GB";

  static String m18(date) => "until ${date}";

  static String m19(count) =>
      "${Intl.plural(count, one: '${count} group', other: '${count} groups')}";

  static String m20(version) => "Version ${version}";

  static String m21(percent) => "Downloading… ${percent}%";

  static String m22(version) => "dropweb ${version}";

  static String m23(count) =>
      "${Intl.plural(count, one: 'Updated ${count} day ago', other: 'Updated ${count} days ago')}";

  static String m24(count) =>
      "${Intl.plural(count, one: 'Updated ${count} hour ago', other: 'Updated ${count} hours ago')}";

  static String m25(count) =>
      "${Intl.plural(count, one: 'Updated ${count} minute ago', other: 'Updated ${count} minutes ago')}";

  static String m26(value) => "${value} GB";

  static String m27(value) => "${value} ms";

  static String m28(label) => "${label} must be a number";

  static String m29(label) => "${label} must be between 1024 and 49151";

  static String m30(count) => "${count} items have been selected";

  static String m31(days) => "Your subscription expires in ${days} day(s)";

  static String m32(label) => "${label} must be a url";

  static String m33(date) => "until ${date}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("AccessControl"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only allow selected app to enter VPN",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "The selected application will be excluded from VPN",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "accountBiometricEnable": MessageLookupByLibrary.simpleMessage("Turn on"),
    "accountBiometricEnableReason": MessageLookupByLibrary.simpleMessage(
      "Confirm to sign in with your fingerprint",
    ),
    "accountBiometricOfferText": MessageLookupByLibrary.simpleMessage(
      "Your account will open with your fingerprint.",
    ),
    "accountBiometricOfferTitle": MessageLookupByLibrary.simpleMessage(
      "Sign in with your fingerprint?",
    ),
    "accountBiometricSwitch": MessageLookupByLibrary.simpleMessage(
      "Fingerprint sign-in",
    ),
    "accountBiometricUnlockReason": MessageLookupByLibrary.simpleMessage(
      "Confirm signing in to your account",
    ),
    "accountChangeEmail": MessageLookupByLibrary.simpleMessage("Change email"),
    "accountCodeLabel": MessageLookupByLibrary.simpleMessage("Code"),
    "accountEmailInvalid": MessageLookupByLibrary.simpleMessage(
      "Check the email address",
    ),
    "accountEmailLabel": MessageLookupByLibrary.simpleMessage("Email"),
    "accountErrorCodeExpired": MessageLookupByLibrary.simpleMessage(
      "Code expired — request a new one",
    ),
    "accountErrorDisabled": MessageLookupByLibrary.simpleMessage(
      "Sign-in temporarily unavailable",
    ),
    "accountErrorEmailRejected": MessageLookupByLibrary.simpleMessage(
      "This email can\'t be used",
    ),
    "accountErrorGeneric": MessageLookupByLibrary.simpleMessage(
      "Something went wrong",
    ),
    "accountErrorInvalidCode": MessageLookupByLibrary.simpleMessage(
      "Incorrect code",
    ),
    "accountErrorNetwork": MessageLookupByLibrary.simpleMessage(
      "Can\'t reach the server",
    ),
    "accountErrorRateLimited": m0,
    "accountErrorRateLimitedLater": MessageLookupByLibrary.simpleMessage(
      "Too many attempts, try later",
    ),
    "accountGetCode": MessageLookupByLibrary.simpleMessage("Get code"),
    "accountLoggedOut": MessageLookupByLibrary.simpleMessage("Signed out"),
    "accountLoginByEmail": MessageLookupByLibrary.simpleMessage(
      "Sign in with email",
    ),
    "accountLogout": MessageLookupByLibrary.simpleMessage("Sign out"),
    "accountNoSubscription": MessageLookupByLibrary.simpleMessage(
      "Signed in, no subscription yet",
    ),
    "accountRemoveFromDevice": MessageLookupByLibrary.simpleMessage(
      "Remove from this device",
    ),
    "accountRemoveFromDeviceText": MessageLookupByLibrary.simpleMessage(
      "The account and its subscription will disappear from this device. You can sign in again with your email.",
    ),
    "accountRemoveFromDeviceTitle": MessageLookupByLibrary.simpleMessage(
      "Remove from this device?",
    ),
    "accountRemovedFromDevice": MessageLookupByLibrary.simpleMessage(
      "Removed from this device",
    ),
    "accountResend": MessageLookupByLibrary.simpleMessage("Send again"),
    "accountSignInWithCode": MessageLookupByLibrary.simpleMessage(
      "Sign in with a code",
    ),
    "accountSubscriptionAlreadyPresent": MessageLookupByLibrary.simpleMessage(
      "The subscription is already in the app",
    ),
    "accountSubscriptionImported": MessageLookupByLibrary.simpleMessage(
      "Subscription connected",
    ),
    "accountSyncFailed": MessageLookupByLibrary.simpleMessage(
      "Signed in, subscription not connected",
    ),
    "accountSyncSubscription": MessageLookupByLibrary.simpleMessage(
      "Update subscription",
    ),
    "accountUnlock": MessageLookupByLibrary.simpleMessage("Unlock"),
    "accountWaitHours": m1,
    "accountWaitMinutes": m2,
    "accountWaitSeconds": m3,
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addFromPhoneSubtitle": MessageLookupByLibrary.simpleMessage(
      "Scan QR code with phone",
    ),
    "addFromPhoneTitle": MessageLookupByLibrary.simpleMessage("Add from Phone"),
    "addNamedSubscription": m4,
    "addProfile": MessageLookupByLibrary.simpleMessage("Add Profile"),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addSubscription": MessageLookupByLibrary.simpleMessage("Add subscription"),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "ago": MessageLookupByLibrary.simpleMessage(" Ago"),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Allow applications to bypass VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Some apps can bypass VPN when turned on",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("AllowLan"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Allow access proxy through the LAN",
    ),
    "alwaysOnVpn": MessageLookupByLibrary.simpleMessage("Always-on"),
    "alwaysOnVpnOpenFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t open VPN settings",
    ),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application Settings"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto check updates",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Auto check for updates when the app starts",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto close connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Auto close connections after change node",
    ),
    "autoFollowAccent": MessageLookupByLibrary.simpleMessage(
      "Auto (follows accent)",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Auto launch"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Follow the system self startup",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("AutoRun"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Auto run when the application is opened",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "backgroundOrbs": MessageLookupByLibrary.simpleMessage("Background orbs"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Basic configuration"),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass domain"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Only takes effect when the system proxy is enabled",
    ),
    "cabinet": MessageLookupByLibrary.simpleMessage("Cabinet"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "The cache is corrupt. Do you want to clear it?",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Camera permission denied",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Cancel select all",
    ),
    "changeServer": MessageLookupByLibrary.simpleMessage("Change Server"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "The current application is already the latest version",
    ),
    "checkUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t check for updates. Check your connection and try again",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Checking..."),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear Data"),
    "clearDataTip": MessageLookupByLibrary.simpleMessage(
      "This will delete all app data and restart the application. Are you sure?",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("Export clipboard"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("Clipboard import"),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Color schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity："),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("Copy logs"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copy success"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "country": MessageLookupByLibrary.simpleMessage("Country"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "dashboardEmptyHint": MessageLookupByLibrary.simpleMessage(
      "Paste a link or scan a QR code",
    ),
    "dashboardEmptyTitle": MessageLookupByLibrary.simpleMessage(
      "Add a subscription",
    ),
    "day": MessageLookupByLibrary.simpleMessage("day"),
    "days": MessageLookupByLibrary.simpleMessage("days"),
    "daysGenitive": MessageLookupByLibrary.simpleMessage("days"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving DNS server",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteTip": m5,
    "desc": MessageLookupByLibrary.simpleMessage(
      "dropweb — fast, simple VPN client. Open-source and ad-free.",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Relying on third-party api is for reference only",
    ),
    "devAdbRemote": MessageLookupByLibrary.simpleMessage("adb remote"),
    "devAdbRemoteReplies": MessageLookupByLibrary.simpleMessage(
      "Replies: adb logcat -s dropweb-dbg",
    ),
    "devCopyAll": MessageLookupByLibrary.simpleMessage("Copy all"),
    "devDiagnostics": MessageLookupByLibrary.simpleMessage("Diagnostics"),
    "devDiagnosticsWritten": m6,
    "devEffectiveConfig": MessageLookupByLibrary.simpleMessage(
      "Effective config",
    ),
    "devEffectiveConfigEmpty": MessageLookupByLibrary.simpleMessage(
      "The core has not been set up yet — no config",
    ),
    "devSubscriptionHeaders": MessageLookupByLibrary.simpleMessage(
      "Subscription headers",
    ),
    "devTakeDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Capture diagnostics",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("New version"),
    "discovery": MessageLookupByLibrary.simpleMessage(
      "Discovery a new version",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Update DNS related settings",
    ),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Adding profile from",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "emptyTip": m7,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "errorTitle": MessageLookupByLibrary.simpleMessage("Error"),
    "exclude": MessageLookupByLibrary.simpleMessage("Hidden from recent tasks"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "When the app is in the background, the app is hidden from the recent task",
    ),
    "existsTip": m8,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "expand": MessageLookupByLibrary.simpleMessage("Standard"),
    "expiresOn": MessageLookupByLibrary.simpleMessage("Expires on"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "ExternalController",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Once enabled, the VPN core can be controlled on port 9090",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip range"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Generally use offshore DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("FontFamily"),
    "fullTunnelTitle": MessageLookupByLibrary.simpleMessage(
      "All traffic through VPN",
    ),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalDesc": MessageLookupByLibrary.simpleMessage(
      "Modify general settings",
    ),
    "genericErrorMessage": MessageLookupByLibrary.simpleMessage(
      "Something went wrong. Please try again.",
    ),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo Low Memory Mode",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling will use the Geo low memory loader",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip code"),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Go to download"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Add Hosts"),
    "hour": MessageLookupByLibrary.simpleMessage("hour"),
    "hours": MessageLookupByLibrary.simpleMessage("Hours"),
    "hoursGenitive": MessageLookupByLibrary.simpleMessage("hours"),
    "hoursPlural": MessageLookupByLibrary.simpleMessage("hours"),
    "hwidFreeSlot": MessageLookupByLibrary.simpleMessage(
      "Free up a device slot",
    ),
    "hwidRecovered": MessageLookupByLibrary.simpleMessage(
      "Device registered\nSubscription updated",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importFromUrlHint": MessageLookupByLibrary.simpleMessage(
      "https://… — your provider\'s subscription link",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Intelligent selection",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidProfileUrl": MessageLookupByLibrary.simpleMessage(
      "Invalid subscription URL. Use http:// or https://",
    ),
    "ipcidr": MessageLookupByLibrary.simpleMessage("Ipcidr"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "When turned on it will be able to receive IPv6 traffic",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Allow IPv6 inbound",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Japanese"),
    "just": MessageLookupByLibrary.simpleMessage("Just"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Tcp keep alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "loadingEllipsis": MessageLookupByLibrary.simpleMessage("Loading…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "logLevel": MessageLookupByLibrary.simpleMessage("LogLevel"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Disabling will hide the log entry",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsCopied": MessageLookupByLibrary.simpleMessage("Logs copied"),
    "loopback": MessageLookupByLibrary.simpleMessage("Loopback unlock tool"),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "m3eA11yBack": MessageLookupByLibrary.simpleMessage("Back"),
    "m3eA11yCancel": MessageLookupByLibrary.simpleMessage("Cancel connecting"),
    "m3eA11yCard": MessageLookupByLibrary.simpleMessage(
      "Connection and subscription",
    ),
    "m3eA11yConnect": MessageLookupByLibrary.simpleMessage("Connect VPN"),
    "m3eA11yDisconnect": MessageLookupByLibrary.simpleMessage("Disconnect VPN"),
    "m3eA11yJoy": MessageLookupByLibrary.simpleMessage("Connection and route"),
    "m3eA11yRetry": MessageLookupByLibrary.simpleMessage("Retry connecting"),
    "m3eA11yRoute": MessageLookupByLibrary.simpleMessage("Choose route"),
    "m3eA11ySettings": MessageLookupByLibrary.simpleMessage("Open settings"),
    "m3eA11ySubs": MessageLookupByLibrary.simpleMessage("Open subscriptions"),
    "m3eAboutPrivacy": MessageLookupByLibrary.simpleMessage("Privacy policy"),
    "m3eAboutSite": MessageLookupByLibrary.simpleMessage("Project website"),
    "m3eAboutTitle": MessageLookupByLibrary.simpleMessage("About"),
    "m3eAboutUpdate": MessageLookupByLibrary.simpleMessage("Update"),
    "m3eAboutUpdateAvailable": m9,
    "m3eAboutVersion": m10,
    "m3eAddFieldError": MessageLookupByLibrary.simpleMessage(
      "The link must start with https://",
    ),
    "m3eAddFieldLabel": MessageLookupByLibrary.simpleMessage(
      "Subscription link",
    ),
    "m3eAppearanceBasicColors": MessageLookupByLibrary.simpleMessage(
      "Basic colors",
    ),
    "m3eAppearanceGroupLabel": MessageLookupByLibrary.simpleMessage(
      "App color",
    ),
    "m3eAppearanceOwn": MessageLookupByLibrary.simpleMessage("Custom color"),
    "m3eAppearanceOwnSub": MessageLookupByLibrary.simpleMessage(
      "Choose from the palette",
    ),
    "m3eAppearanceProvider": MessageLookupByLibrary.simpleMessage(
      "Provider color",
    ),
    "m3eAppearanceProviderSub": MessageLookupByLibrary.simpleMessage(
      "As in the subscription",
    ),
    "m3eAppearanceTitle": MessageLookupByLibrary.simpleMessage("Appearance"),
    "m3eColorN": m11,
    "m3eColorShade": m12,
    "m3eColorTitle": MessageLookupByLibrary.simpleMessage("Other color"),
    "m3eDeleteBody": MessageLookupByLibrary.simpleMessage(
      "The paid subscription stays with your provider.",
    ),
    "m3eDeleteTitle": m13,
    "m3eDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb creates a VPN tunnel using Android\'s system VPN permission. Your traffic goes through your subscription\'s servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and, unless disabled in settings, your device ID.",
    ),
    "m3eDisclosureTitle": MessageLookupByLibrary.simpleMessage(
      "Before connecting",
    ),
    "m3eEmptyPaste": MessageLookupByLibrary.simpleMessage("Paste link"),
    "m3eEmptyScanQr": MessageLookupByLibrary.simpleMessage("Scan QR code"),
    "m3eEmptyTitle": MessageLookupByLibrary.simpleMessage("Add a subscription"),
    "m3eLangSystem": MessageLookupByLibrary.simpleMessage("Same as system"),
    "m3eMsNoAnswer": MessageLookupByLibrary.simpleMessage("no response"),
    "m3ePlanDaysLeft": m14,
    "m3ePlanExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription expired",
    ),
    "m3ePlanForever": MessageLookupByLibrary.simpleMessage("no expiry"),
    "m3ePlanLine": m15,
    "m3ePlanTrafficLeft": m16,
    "m3ePlanTrafficOf": m17,
    "m3ePlanTrafficOut": MessageLookupByLibrary.simpleMessage("Out of traffic"),
    "m3ePlanUnlimited": MessageLookupByLibrary.simpleMessage("Unlimited"),
    "m3ePlanUntil": m18,
    "m3eRefresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "m3eRouteAllTraffic": MessageLookupByLibrary.simpleMessage(
      "All traffic through VPN",
    ),
    "m3eRouteAuto": MessageLookupByLibrary.simpleMessage("Auto"),
    "m3eRouteCountries": MessageLookupByLibrary.simpleMessage("Country"),
    "m3eRouteGroupsCount": m19,
    "m3eRouteTitle": MessageLookupByLibrary.simpleMessage("Route"),
    "m3eScanGallery": MessageLookupByLibrary.simpleMessage(
      "Choose from gallery",
    ),
    "m3eScanTorch": MessageLookupByLibrary.simpleMessage("Flashlight"),
    "m3eServersTitle": MessageLookupByLibrary.simpleMessage(
      "Servers and groups",
    ),
    "m3eSettingsAboutVersion": m20,
    "m3eStatIp": MessageLookupByLibrary.simpleMessage("IP address"),
    "m3eStatNone": MessageLookupByLibrary.simpleMessage("—"),
    "m3eStatPing": MessageLookupByLibrary.simpleMessage("Ping"),
    "m3eStatTraffic": MessageLookupByLibrary.simpleMessage("Traffic"),
    "m3eStatusConnected": MessageLookupByLibrary.simpleMessage("Connected"),
    "m3eStatusConnecting": MessageLookupByLibrary.simpleMessage("Connecting…"),
    "m3eStatusDisconnected": MessageLookupByLibrary.simpleMessage(
      "Not connected",
    ),
    "m3eStatusError": MessageLookupByLibrary.simpleMessage(
      "Server not responding",
    ),
    "m3eStatusOffline": MessageLookupByLibrary.simpleMessage("No network"),
    "m3eStatusSwitching": MessageLookupByLibrary.simpleMessage("Switching…"),
    "m3eSubAll": MessageLookupByLibrary.simpleMessage("All subscriptions"),
    "m3eSubDelete": MessageLookupByLibrary.simpleMessage("Delete subscription"),
    "m3eSubListLabel": MessageLookupByLibrary.simpleMessage("Subscriptions"),
    "m3eSubSupport": MessageLookupByLibrary.simpleMessage("Help"),
    "m3eSubTitle": MessageLookupByLibrary.simpleMessage("Subscription"),
    "m3eToastInstaller": MessageLookupByLibrary.simpleMessage(
      "Opening the Android installer",
    ),
    "m3eToastRefreshFail": MessageLookupByLibrary.simpleMessage(
      "Can\'t reach the server",
    ),
    "m3eToastRefreshed": MessageLookupByLibrary.simpleMessage(
      "Subscription updated",
    ),
    "m3eToastSupport": MessageLookupByLibrary.simpleMessage("Opening help"),
    "m3eUpdateDownloading": m21,
    "m3eUpdateFailed": MessageLookupByLibrary.simpleMessage("Update failed"),
    "m3eUpdateNotes": MessageLookupByLibrary.simpleMessage("What\'s new"),
    "m3eUpdateProgressLabel": MessageLookupByLibrary.simpleMessage(
      "Downloading update",
    ),
    "m3eUpdateReady": MessageLookupByLibrary.simpleMessage(
      "Downloaded, ready to install",
    ),
    "m3eUpdateTitle": m22,
    "m3eUpdateVerifying": MessageLookupByLibrary.simpleMessage("Verifying…"),
    "m3eUpdatedDaysAgo": m23,
    "m3eUpdatedHoursAgo": m24,
    "m3eUpdatedJustNow": MessageLookupByLibrary.simpleMessage(
      "Updated just now",
    ),
    "m3eUpdatedMinutesAgo": m25,
    "m3eValueGb": m26,
    "m3eValueMs": m27,
    "managedByProvider": MessageLookupByLibrary.simpleMessage(
      "These settings are managed by your provider",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "menu": MessageLookupByLibrary.simpleMessage("MENU"),
    "min": MessageLookupByLibrary.simpleMessage("Min"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the default system exit event",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("Minutes"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed Port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "months": MessageLookupByLibrary.simpleMessage("Months"),
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving domain",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Specify the corresponding nameserver policy",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Modify network-related settings",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("Your IP Address"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No network APP"),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolve IP"),
    "none": MessageLookupByLibrary.simpleMessage("none"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "No profile, Please add a profile",
    ),
    "numberTip": m28,
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "onboardingClipboardImport": MessageLookupByLibrary.simpleMessage(
      "Paste subscription from clipboard",
    ),
    "onboardingImported": MessageLookupByLibrary.simpleMessage(
      "Subscription added. Tap to connect",
    ),
    "oneline": MessageLookupByLibrary.simpleMessage("Oneline"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Count only proxy traffic",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "When turned on, only proxy traffic will be counted in statistics",
    ),
    "openLogsFolder": MessageLookupByLibrary.simpleMessage("Open logs folder"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "orbBlur": MessageLookupByLibrary.simpleMessage("Blur"),
    "orbOne": MessageLookupByLibrary.simpleMessage("Top orbs"),
    "orbTwo": MessageLookupByLibrary.simpleMessage("Bottom orb"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override Dns"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Turning it on will override the DNS options in the profile",
    ),
    "overrideNetworkSettings": MessageLookupByLibrary.simpleMessage(
      "Override network settings",
    ),
    "overrideNetworkSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Ignore network settings from provider config",
    ),
    "overrideProviderSettings": MessageLookupByLibrary.simpleMessage(
      "Override",
    ),
    "overrideProviderSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Ignore provider settings and manage manually",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Palette"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("Paste"),
    "personalCabinet": MessageLookupByLibrary.simpleMessage("Personal cabinet"),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter the admin password",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portTip": m29,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prioritize the use of DOH\'s http/3",
    ),
    "presetAmber": MessageLookupByLibrary.simpleMessage("Amber"),
    "presetAmethyst": MessageLookupByLibrary.simpleMessage("Amethyst"),
    "presetCrimson": MessageLookupByLibrary.simpleMessage("Crimson"),
    "presetEmerald": MessageLookupByLibrary.simpleMessage("Drop"),
    "presetFrost": MessageLookupByLibrary.simpleMessage("Frost"),
    "presetMagma": MessageLookupByLibrary.simpleMessage("Magma"),
    "presetStealth": MessageLookupByLibrary.simpleMessage("Stealth"),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "privacyPolicy": MessageLookupByLibrary.simpleMessage("Privacy Policy"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "providers": MessageLookupByLibrary.simpleMessage("Providers"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("Proxies setting"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Domain for resolving proxy nodes",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrNotFound": MessageLookupByLibrary.simpleMessage("QR code not found"),
    "qrScanFromImageUnsupported": MessageLookupByLibrary.simpleMessage(
      "Scanning a QR code from an image isn\'t supported on this platform. Use the subscription URL instead.",
    ),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "receiveSubscriptionTitle": MessageLookupByLibrary.simpleMessage(
      "Receive Subscription",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir Port"),
    "redo": MessageLookupByLibrary.simpleMessage("redo"),
    "regExp": MessageLookupByLibrary.simpleMessage("RegExp"),
    "remaining": MessageLookupByLibrary.simpleMessage("Remaining"),
    "remainingPlural": MessageLookupByLibrary.simpleMessage("Remaining"),
    "remainingSingular": MessageLookupByLibrary.simpleMessage("Remaining"),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "renew": MessageLookupByLibrary.simpleMessage("Renew"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetTip": MessageLookupByLibrary.simpleMessage("Make sure to reset"),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS connection following rules, need to configure proxy-server-nameserver",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route address"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Config listen route address",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Route mode"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Bypass private route address",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("Use config"),
    "routeUndetected": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t detect the route",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Russian"),
    "rule": MessageLookupByLibrary.simpleMessage("By rule"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Rule name"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "rules": MessageLookupByLibrary.simpleMessage("Rules"),
    "running": MessageLookupByLibrary.simpleMessage("Running"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("Scan QR code"),
    "schemeBright": MessageLookupByLibrary.simpleMessage("Bright"),
    "schemeCalm": MessageLookupByLibrary.simpleMessage("Calm"),
    "schemeExpressive": MessageLookupByLibrary.simpleMessage("Expressive"),
    "schemeMono": MessageLookupByLibrary.simpleMessage("Mono"),
    "schemeNeutral": MessageLookupByLibrary.simpleMessage("Neutral"),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("Seconds"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("Select Profile"),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "selectedCountTitle": m30,
    "serversAndGroups": MessageLookupByLibrary.simpleMessage(
      "Servers & groups",
    ),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsSendDeviceDataSubtitle": MessageLookupByLibrary.simpleMessage(
      "Send device identifier, app version and device name to proxy provider server",
    ),
    "settingsSendDeviceDataTitle": MessageLookupByLibrary.simpleMessage(
      "Send HWID",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "shrink": MessageLookupByLibrary.simpleMessage("Shrink"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("SilentLaunch"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start in the background",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "smart": MessageLookupByLibrary.simpleMessage("Smart"),
    "smartAuto": MessageLookupByLibrary.simpleMessage("Auto"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks Port"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN..."),
    "startingVpnCore": MessageLookupByLibrary.simpleMessage(
      "Starting VPN core…",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "System DNS will be used when turned off",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN..."),
    "stopped": MessageLookupByLibrary.simpleMessage("Stopped"),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "subRule": MessageLookupByLibrary.simpleMessage("Sub rule"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "subscription": MessageLookupByLibrary.simpleMessage("Subscription"),
    "subscriptionEternal": MessageLookupByLibrary.simpleMessage(
      "Lifetime Subscription",
    ),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Your subscription has expired",
    ),
    "subscriptionExpiresInDays": m31,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "Your subscription expires today",
    ),
    "subscriptionLogo": MessageLookupByLibrary.simpleMessage(
      "Logo from subscription",
    ),
    "subscriptionTheme": MessageLookupByLibrary.simpleMessage(
      "Theme from subscription",
    ),
    "subscriptionUnlimited": MessageLookupByLibrary.simpleMessage(
      "Lifetime Subscription",
    ),
    "support": MessageLookupByLibrary.simpleMessage("Support"),
    "supportProject": MessageLookupByLibrary.simpleMessage(
      "Support the project",
    ),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System APP"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Attach HTTP proxy to VpnService",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Tab animation"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Effective only in mobile view",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling it will allow TCP concurrency",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test url"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text Scaling"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "themePresets": MessageLookupByLibrary.simpleMessage("Theme presets"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "tip": MessageLookupByLibrary.simpleMessage("tip"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tooFrequentOperation": MessageLookupByLibrary.simpleMessage(
      "Please wait 15 seconds before refreshing again",
    ),
    "tools": MessageLookupByLibrary.simpleMessage("Settings"),
    "topUpTraffic": MessageLookupByLibrary.simpleMessage("Top up traffic"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy Port"),
    "traffic": MessageLookupByLibrary.simpleMessage("Traffic"),
    "trafficUnlimited": MessageLookupByLibrary.simpleMessage(
      "Unlimited Traffic",
    ),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic usage"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "only effective in administrator mode",
    ),
    "undo": MessageLookupByLibrary.simpleMessage("undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Remove extra delays such as handshaking",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("Downloading…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Update failed"),
    "updateInstall": MessageLookupByLibrary.simpleMessage("Install"),
    "updateLater": MessageLookupByLibrary.simpleMessage("Later"),
    "updateMandatoryNote": MessageLookupByLibrary.simpleMessage(
      "This update is recommended",
    ),
    "updateRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "updateSubscription": MessageLookupByLibrary.simpleMessage("Update"),
    "updateVerifying": MessageLookupByLibrary.simpleMessage("Verifying…"),
    "updated": MessageLookupByLibrary.simpleMessage("Updated"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m32,
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "validUntil": m33,
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "vpnDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb uses Android\'s VPN permission to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers\' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address and, unless you turn it off in Settings, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device\'s VPN settings.",
    ),
    "vpnDisclosureBodyIos": MessageLookupByLibrary.simpleMessage(
      "dropweb adds a VPN configuration to your iPhone to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers\' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address and, unless you turn it off in Settings, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device\'s VPN settings.",
    ),
    "vpnDisclosureContinue": MessageLookupByLibrary.simpleMessage("Continue"),
    "vpnDisclosureTitle": MessageLookupByLibrary.simpleMessage(
      "Before you connect",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Auto routes all system traffic through VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Changes take effect after restarting the VPN",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "workModeCountry": MessageLookupByLibrary.simpleMessage("Country"),
    "workModeResetNotice": MessageLookupByLibrary.simpleMessage(
      "Mode reset to Standard: settings unavailable after subscription update.",
    ),
    "years": MessageLookupByLibrary.simpleMessage("Years"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
  };
}
