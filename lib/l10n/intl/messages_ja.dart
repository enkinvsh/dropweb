// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(wait) => "リクエストが多すぎます。${wait}お待ちください";

  static String m1(n) => "${n} 時間";

  static String m2(n) => "${n} 分";

  static String m3(n) => "${n} 秒";

  static String m4(host) => "${host} を追加";

  static String m5(label) => "現在の${label}を削除してもよろしいですか？";

  static String m6(path) => "診断: ${path}";

  static String m7(label) => "${label}は空欄にできません";

  static String m8(label) => "現在の${label}は既に存在しています";

  static String m9(name) => "Route: ${name}. Open list";

  static String m10(slot) => "Color: ${slot}";

  static String m11(count) =>
      "${Intl.plural(count, one: '${count} day ago', other: '${count} days ago')}";

  static String m12(count) =>
      "${Intl.plural(count, one: '${count} hour ago', other: '${count} hours ago')}";

  static String m13(count) =>
      "${Intl.plural(count, one: '${count} minute ago', other: '${count} minutes ago')}";

  static String m14(version) => "Version ${version} is available";

  static String m15(version, core) => "Version ${version}, core ${core}";

  static String m16(n) => "Color ${n}";

  static String m17(n) => "Shade ${n}";

  static String m18(name) => "Delete “${name}”?";

  static String m19(count) =>
      "${Intl.plural(count, one: '${count} day left', other: '${count} days left')}";

  static String m20(traffic, term) => "${traffic} · ${term}";

  static String m21(left) => "${left} GB left";

  static String m22(used, total) => "${used} of ${total} GB";

  static String m23(date) => "until ${date}";

  static String m24(count) =>
      "${Intl.plural(count, one: '${count} group', other: '${count} groups')}";

  static String m25(version) => "Version ${version}";

  static String m26(percent) => "Downloading… ${percent}%";

  static String m27(version) => "dropweb ${version}";

  static String m28(count) =>
      "${Intl.plural(count, one: 'Updated ${count} day ago', other: 'Updated ${count} days ago')}";

  static String m29(count) =>
      "${Intl.plural(count, one: 'Updated ${count} hour ago', other: 'Updated ${count} hours ago')}";

  static String m30(count) =>
      "${Intl.plural(count, one: 'Updated ${count} minute ago', other: 'Updated ${count} minutes ago')}";

  static String m31(value) => "${value} GB";

  static String m32(value) => "${value} ms";

  static String m33(label) => "${label}は数字でなければなりません";

  static String m34(label) => "${label} は 1024 から 49151 の間でなければなりません";

  static String m35(count) => "${count} 項目が選択されています";

  static String m36(days) => "サブスクリプションは${days}日後に期限切れになります";

  static String m37(label) => "${label}はURLである必要があります";

  static String m38(date) => "${date}まで";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("について"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを許可",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリをVPNから除外",
    ),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "accountBiometricEnable": MessageLookupByLibrary.simpleMessage("オンにする"),
    "accountBiometricEnableReason": MessageLookupByLibrary.simpleMessage(
      "指紋でログインするには確認してください",
    ),
    "accountBiometricOfferText": MessageLookupByLibrary.simpleMessage(
      "アカウントを指紋で開けるようになります。",
    ),
    "accountBiometricOfferTitle": MessageLookupByLibrary.simpleMessage(
      "指紋でログインしますか？",
    ),
    "accountBiometricSwitch": MessageLookupByLibrary.simpleMessage("指紋でログイン"),
    "accountBiometricUnlockReason": MessageLookupByLibrary.simpleMessage(
      "アカウントへのログインを確認してください",
    ),
    "accountChangeEmail": MessageLookupByLibrary.simpleMessage("メールアドレスを変更"),
    "accountCodeLabel": MessageLookupByLibrary.simpleMessage("コード"),
    "accountEmailInvalid": MessageLookupByLibrary.simpleMessage(
      "メールアドレスを確認してください",
    ),
    "accountEmailLabel": MessageLookupByLibrary.simpleMessage("メールアドレス"),
    "accountErrorCodeExpired": MessageLookupByLibrary.simpleMessage(
      "コードの期限切れです。再送信してください",
    ),
    "accountErrorDisabled": MessageLookupByLibrary.simpleMessage(
      "ログインは一時的に利用できません",
    ),
    "accountErrorEmailRejected": MessageLookupByLibrary.simpleMessage(
      "このメールアドレスは使用できません",
    ),
    "accountErrorGeneric": MessageLookupByLibrary.simpleMessage("うまくいきませんでした"),
    "accountErrorInvalidCode": MessageLookupByLibrary.simpleMessage(
      "コードが正しくありません",
    ),
    "accountErrorNetwork": MessageLookupByLibrary.simpleMessage("サーバーに接続できません"),
    "accountErrorRateLimited": m0,
    "accountErrorRateLimitedLater": MessageLookupByLibrary.simpleMessage(
      "リクエストが多すぎます。後でお試しください",
    ),
    "accountGetCode": MessageLookupByLibrary.simpleMessage("コードを受け取る"),
    "accountLoggedOut": MessageLookupByLibrary.simpleMessage("ログアウトしました"),
    "accountLoginByEmail": MessageLookupByLibrary.simpleMessage("メールでログイン"),
    "accountLogout": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "accountNoSubscription": MessageLookupByLibrary.simpleMessage(
      "ログインしました。サブスクリプションはまだありません",
    ),
    "accountRemoveFromDevice": MessageLookupByLibrary.simpleMessage(
      "このデバイスから削除",
    ),
    "accountRemoveFromDeviceText": MessageLookupByLibrary.simpleMessage(
      "アカウントとそのサブスクリプションがこのデバイスから消えます。メールで再度サインインできます。",
    ),
    "accountRemoveFromDeviceTitle": MessageLookupByLibrary.simpleMessage(
      "このデバイスから削除しますか？",
    ),
    "accountRemovedFromDevice": MessageLookupByLibrary.simpleMessage(
      "このデバイスから削除しました",
    ),
    "accountResend": MessageLookupByLibrary.simpleMessage("もう一度送信"),
    "accountSignInWithCode": MessageLookupByLibrary.simpleMessage("コードでログイン"),
    "accountSubscriptionAlreadyPresent": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションはすでにアプリに追加されています",
    ),
    "accountSubscriptionImported": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを接続しました",
    ),
    "accountSyncFailed": MessageLookupByLibrary.simpleMessage(
      "ログインしました。サブスクリプションは未接続です",
    ),
    "accountSyncSubscription": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを更新",
    ),
    "accountUnlock": MessageLookupByLibrary.simpleMessage("ロックを解除"),
    "accountWaitHours": m1,
    "accountWaitMinutes": m2,
    "accountWaitSeconds": m3,
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addFromPhoneSubtitle": MessageLookupByLibrary.simpleMessage(
      "スマホでQRコードをスキャン",
    ),
    "addFromPhoneTitle": MessageLookupByLibrary.simpleMessage("スマホから追加"),
    "addNamedSubscription": m4,
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSubscription": MessageLookupByLibrary.simpleMessage("サブスクリプションを追加"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "ago": MessageLookupByLibrary.simpleMessage("前"),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリがVPNをバイパスすることを許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリがVPNをバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANを許可"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN経由でのプロキシアクセスを許可"),
    "alwaysOnVpn": MessageLookupByLibrary.simpleMessage("常時接続"),
    "alwaysOnVpnOpenFailed": MessageLookupByLibrary.simpleMessage(
      "VPN設定を開けませんでした",
    ),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション設定"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動更新チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "起動時に更新を自動チェック",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を自動閉じる",
    ),
    "autoFollowAccent": MessageLookupByLibrary.simpleMessage("自動（アクセントに追従）"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システムの自動起動に従う"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリ起動時に自動実行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("オートセットシステムDNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "backgroundOrbs": MessageLookupByLibrary.simpleMessage("背景オーブ"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "bind": MessageLookupByLibrary.simpleMessage("バインド"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("バイパスドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("システムプロキシ有効時のみ適用"),
    "cabinet": MessageLookupByLibrary.simpleMessage("マイページ"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "カメラの使用が許可されていません",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("全選択解除"),
    "changeServer": MessageLookupByLibrary.simpleMessage("サーバーを変更"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("アプリは最新版です"),
    "checkUpdateFailed": MessageLookupByLibrary.simpleMessage(
      "アップデートを確認できませんでした",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("確認中..."),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clearDataTip": MessageLookupByLibrary.simpleMessage(
      "これによりすべてのアプリデータが削除され、アプリケーションが再起動されます。よろしいですか？",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードにエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "close": MessageLookupByLibrary.simpleMessage("閉じる"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラースキーム"),
    "columns": MessageLookupByLibrary.simpleMessage("列"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "confirm": MessageLookupByLibrary.simpleMessage("確認"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("ログをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピー成功"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "country": MessageLookupByLibrary.simpleMessage("国"),
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dashboardEmptyHint": MessageLookupByLibrary.simpleMessage(
      "リンクを貼り付けるか、QRコードをスキャンしてください",
    ),
    "dashboardEmptyTitle": MessageLookupByLibrary.simpleMessage("サブスクリプションを追加"),
    "day": MessageLookupByLibrary.simpleMessage("日"),
    "days": MessageLookupByLibrary.simpleMessage("日"),
    "daysGenitive": MessageLookupByLibrary.simpleMessage("日"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNSサーバーの解決用",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteTip": m5,
    "desc": MessageLookupByLibrary.simpleMessage(
      "dropweb — シンプルで高速な VPN クライアント。オープンソース、広告なし。",
    ),
    "detectionTip": MessageLookupByLibrary.simpleMessage("サードパーティAPIに依存（参考値）"),
    "devAdbRemote": MessageLookupByLibrary.simpleMessage("adb リモート"),
    "devAdbRemoteReplies": MessageLookupByLibrary.simpleMessage(
      "応答: adb logcat -s dropweb-dbg",
    ),
    "devCopyAll": MessageLookupByLibrary.simpleMessage("すべてコピー"),
    "devDiagnostics": MessageLookupByLibrary.simpleMessage("診断"),
    "devDiagnosticsWritten": m6,
    "devEffectiveConfig": MessageLookupByLibrary.simpleMessage("最終設定"),
    "devEffectiveConfigEmpty": MessageLookupByLibrary.simpleMessage(
      "コアはまだ起動していません — 設定なし",
    ),
    "devSubscriptionHeaders": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションヘッダー",
    ),
    "devTakeDiagnostics": MessageLookupByLibrary.simpleMessage("診断情報を取得"),
    "developerMode": MessageLookupByLibrary.simpleMessage("デベロッパーモード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "デベロッパーモードが有効になりました。",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("新バージョンを発見"),
    "discovery": MessageLookupByLibrary.simpleMessage("新しいバージョンを発見"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS関連設定の更新"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("プロファイルを追加中"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "emptyTip": m7,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "entries": MessageLookupByLibrary.simpleMessage(" エントリ"),
    "errorTitle": MessageLookupByLibrary.simpleMessage("エラー"),
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから非表示"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "アプリがバックグラウンド時に最近のタスクから非表示",
    ),
    "existsTip": m8,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "expand": MessageLookupByLibrary.simpleMessage("標準"),
    "expiresOn": MessageLookupByLibrary.simpleMessage("有効期限"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとdropwebをポート9090で制御可能",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeipフィルター"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip範囲"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常はオフショアDNSを使用"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォントファミリー"),
    "fullTunnelTitle": MessageLookupByLibrary.simpleMessage("すべての通信をVPN経由"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("一般設定を変更"),
    "genericErrorMessage": MessageLookupByLibrary.simpleMessage("問題が発生しました"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとGeo低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIPコード"),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("移動"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("ホストを追加"),
    "hour": MessageLookupByLibrary.simpleMessage("時間"),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursGenitive": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursPlural": MessageLookupByLibrary.simpleMessage("時間"),
    "hwidFreeSlot": MessageLookupByLibrary.simpleMessage("デバイス枠を空ける"),
    "hwidLimitReached": MessageLookupByLibrary.simpleMessage(
      "デバイス数の上限に達しました\nプロバイダー側で枠を空けてから更新してください",
    ),
    "hwidRecovered": MessageLookupByLibrary.simpleMessage(
      "デバイスを登録しました\nサブスクリプションを更新しました",
    ),
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "importFromUrlHint": MessageLookupByLibrary.simpleMessage(
      "https://… — プロバイダーのサブスクリプションリンク",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("インテリジェント選択"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("インターバル"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidProfileUrl": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションのURLが無効です。http:// または https:// を使用してください",
    ),
    "ios27A11yJoy": MessageLookupByLibrary.simpleMessage(
      "Connection and country",
    ),
    "ios27A11yRoute": m9,
    "ios27AppearanceColors": MessageLookupByLibrary.simpleMessage("Colors"),
    "ios27AppearanceOwn": MessageLookupByLibrary.simpleMessage("Custom"),
    "ios27AppearanceProvider": MessageLookupByLibrary.simpleMessage("Provider"),
    "ios27AppearanceThemes": MessageLookupByLibrary.simpleMessage("テーマ"),
    "ios27ColorSheetLabel": m10,
    "ios27ColorSlotAccent": MessageLookupByLibrary.simpleMessage("Buttons"),
    "ios27ColorSlotOrb1": MessageLookupByLibrary.simpleMessage(
      "Background top",
    ),
    "ios27ColorSlotOrb2": MessageLookupByLibrary.simpleMessage(
      "Background bottom",
    ),
    "ios27DisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropwebはVPN構成を使ってVPNトンネルを作成します。構成の追加には、iPhoneが許可を求めます。通信はご利用のサブスクリプションのサーバーを経由します。dropwebがネットワーク上での操作を見たり記録したりすることはありません。サブスクリプションの提供元は、お使いのIPアドレスとデバイス識別子を受け取ります。",
    ),
    "ios27DisclosurePolicy": MessageLookupByLibrary.simpleMessage("プライバシーポリシー"),
    "ios27DisclosureTitle": MessageLookupByLibrary.simpleMessage("接続する前に"),
    "ios27GlassCapClear": MessageLookupByLibrary.simpleMessage("Clear"),
    "ios27GlassClearer": MessageLookupByLibrary.simpleMessage("Clearer"),
    "ios27GlassDenser": MessageLookupByLibrary.simpleMessage("Denser"),
    "ios27GlassStandard": MessageLookupByLibrary.simpleMessage("Standard"),
    "ios27GlassTinted": MessageLookupByLibrary.simpleMessage("Tinted"),
    "ios27GlassTitle": MessageLookupByLibrary.simpleMessage("Glass"),
    "ios27PresetBlue": MessageLookupByLibrary.simpleMessage("Blue"),
    "ios27PresetGraphite": MessageLookupByLibrary.simpleMessage("Graphite"),
    "ios27PresetGreen": MessageLookupByLibrary.simpleMessage("Green"),
    "ios27PresetOrange": MessageLookupByLibrary.simpleMessage("Orange"),
    "ios27PresetPink": MessageLookupByLibrary.simpleMessage("Pink"),
    "ios27PresetPurple": MessageLookupByLibrary.simpleMessage("Purple"),
    "ios27PresetRed": MessageLookupByLibrary.simpleMessage("Red"),
    "ios27PresetYellow": MessageLookupByLibrary.simpleMessage("Yellow"),
    "ios27StatCountry": MessageLookupByLibrary.simpleMessage("国"),
    "ios27ToastLink": MessageLookupByLibrary.simpleMessage(
      "Opens in the browser",
    ),
    "ios27ToastQr": MessageLookupByLibrary.simpleMessage(
      "The QR code camera will open here",
    ),
    "ios27UpdatedDaysAgo": m11,
    "ios27UpdatedHoursAgo": m12,
    "ios27UpdatedJustNow": MessageLookupByLibrary.simpleMessage("just now"),
    "ios27UpdatedMinutesAgo": m13,
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("有効化するとIPv6トラフィックを受信可能"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6インバウンドを許可"),
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "just": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リスン"),
    "loadingEllipsis": MessageLookupByLibrary.simpleMessage("読み込み中…"),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャット"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("無効化するとログエントリを非表示"),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsCopied": MessageLookupByLibrary.simpleMessage("ログをコピーしました"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loose": MessageLookupByLibrary.simpleMessage("疎"),
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
    "m3eAboutUpdateAvailable": m14,
    "m3eAboutVersion": m15,
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
    "m3eColorN": m16,
    "m3eColorShade": m17,
    "m3eColorTitle": MessageLookupByLibrary.simpleMessage("Other color"),
    "m3eDeleteBody": MessageLookupByLibrary.simpleMessage(
      "The paid subscription stays with your provider.",
    ),
    "m3eDeleteTitle": m18,
    "m3eDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb creates a VPN tunnel using Android\'s system VPN permission. Your traffic goes through your subscription\'s servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and device ID.",
    ),
    "m3eDisclosureTitle": MessageLookupByLibrary.simpleMessage(
      "Before connecting",
    ),
    "m3eEmptyPaste": MessageLookupByLibrary.simpleMessage("Paste link"),
    "m3eEmptyScanQr": MessageLookupByLibrary.simpleMessage("Scan QR code"),
    "m3eEmptyTitle": MessageLookupByLibrary.simpleMessage("Add a subscription"),
    "m3eLangSystem": MessageLookupByLibrary.simpleMessage("Same as system"),
    "m3eMsNoAnswer": MessageLookupByLibrary.simpleMessage("no response"),
    "m3ePlanDaysLeft": m19,
    "m3ePlanExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription expired",
    ),
    "m3ePlanForever": MessageLookupByLibrary.simpleMessage("no expiry"),
    "m3ePlanLine": m20,
    "m3ePlanTrafficLeft": m21,
    "m3ePlanTrafficOf": m22,
    "m3ePlanTrafficOut": MessageLookupByLibrary.simpleMessage("Out of traffic"),
    "m3ePlanUnlimited": MessageLookupByLibrary.simpleMessage("Unlimited"),
    "m3ePlanUntil": m23,
    "m3eRefresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "m3eRouteAllTraffic": MessageLookupByLibrary.simpleMessage(
      "All traffic through VPN",
    ),
    "m3eRouteAuto": MessageLookupByLibrary.simpleMessage("Auto"),
    "m3eRouteCountries": MessageLookupByLibrary.simpleMessage("Country"),
    "m3eRouteGroupsCount": m24,
    "m3eRouteTitle": MessageLookupByLibrary.simpleMessage("Route"),
    "m3eScanGallery": MessageLookupByLibrary.simpleMessage(
      "Choose from gallery",
    ),
    "m3eScanTorch": MessageLookupByLibrary.simpleMessage("Flashlight"),
    "m3eServersTitle": MessageLookupByLibrary.simpleMessage(
      "Servers and groups",
    ),
    "m3eSettingsAboutVersion": m25,
    "m3eStatCountry": MessageLookupByLibrary.simpleMessage("国"),
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
    "m3eUpdateDownloading": m26,
    "m3eUpdateFailed": MessageLookupByLibrary.simpleMessage("Update failed"),
    "m3eUpdateNotes": MessageLookupByLibrary.simpleMessage("What\'s new"),
    "m3eUpdateProgressLabel": MessageLookupByLibrary.simpleMessage(
      "Downloading update",
    ),
    "m3eUpdateReady": MessageLookupByLibrary.simpleMessage(
      "Downloaded, ready to install",
    ),
    "m3eUpdateTitle": m27,
    "m3eUpdateVerifying": MessageLookupByLibrary.simpleMessage("Verifying…"),
    "m3eUpdatedDaysAgo": m28,
    "m3eUpdatedHoursAgo": m29,
    "m3eUpdatedJustNow": MessageLookupByLibrary.simpleMessage(
      "Updated just now",
    ),
    "m3eUpdatedMinutesAgo": m30,
    "m3eValueGb": m31,
    "m3eValueMs": m32,
    "managedByProvider": MessageLookupByLibrary.simpleMessage(
      "これらの設定はプロバイダーによって管理されています",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "menu": MessageLookupByLibrary.simpleMessage("メニュー"),
    "min": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システムの終了イベントを変更",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("分"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合ポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "months": MessageLookupByLibrary.simpleMessage("月"),
    "more": MessageLookupByLibrary.simpleMessage("詳細"),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメイン解決用"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "対応するネームサーバーポリシーを指定",
    ),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連設定の変更"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("あなたのIPアドレス"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "noData": MessageLookupByLibrary.simpleMessage("データなし"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークなし"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワークなしアプリ"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。追加してください",
    ),
    "numberTip": m33,
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "onboardingClipboardImport": MessageLookupByLibrary.simpleMessage(
      "クリップボードから貼り付け",
    ),
    "onboardingImported": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを追加しました。タップして接続",
    ),
    "oneline": MessageLookupByLibrary.simpleMessage("オンライン"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシのみ統計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロキシトラフィックのみ統計",
    ),
    "openLogsFolder": MessageLookupByLibrary.simpleMessage("ログフォルダを開く"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "orbBlur": MessageLookupByLibrary.simpleMessage("ぼかし"),
    "orbOne": MessageLookupByLibrary.simpleMessage("上部のオーブ"),
    "orbTwo": MessageLookupByLibrary.simpleMessage("下部のオーブ"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルのDNS設定を上書き",
    ),
    "overrideNetworkSettings": MessageLookupByLibrary.simpleMessage(
      "ネットワーク設定を上書き",
    ),
    "overrideNetworkSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "プロバイダー設定のネットワーク設定を無視",
    ),
    "overrideProviderSettings": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideProviderSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "プロバイダーの設定を無視して手動で管理",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "personalCabinet": MessageLookupByLibrary.simpleMessage("マイページ"),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portTip": m34,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DOHのHTTP/3を優先使用"),
    "presetAmber": MessageLookupByLibrary.simpleMessage("アンバー"),
    "presetAmethyst": MessageLookupByLibrary.simpleMessage("アメジスト"),
    "presetCrimson": MessageLookupByLibrary.simpleMessage("真紅"),
    "presetEmerald": MessageLookupByLibrary.simpleMessage("ドロップ"),
    "presetFrost": MessageLookupByLibrary.simpleMessage("フロスト"),
    "presetMagma": MessageLookupByLibrary.simpleMessage("マグマ"),
    "presetStealth": MessageLookupByLibrary.simpleMessage("ステルス"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "privacyPolicy": MessageLookupByLibrary.simpleMessage("プライバシーポリシー"),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル一覧"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "providers": MessageLookupByLibrary.simpleMessage("プロバイダー"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("プロキシ設定"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノード解決用ドメイン",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("純黒モード"),
    "qrNotFound": MessageLookupByLibrary.simpleMessage("QRコードが見つかりません"),
    "qrScanFromImageUnsupported": MessageLookupByLibrary.simpleMessage(
      "画像からのQR読み取りには対応していません",
    ),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "receiveSubscriptionTitle": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションを受け取る",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "regExp": MessageLookupByLibrary.simpleMessage("正規表現"),
    "remaining": MessageLookupByLibrary.simpleMessage("残り"),
    "remainingPlural": MessageLookupByLibrary.simpleMessage("残り"),
    "remainingSingular": MessageLookupByLibrary.simpleMessage("残り"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("リネーム"),
    "renew": MessageLookupByLibrary.simpleMessage("更新"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットを確定"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルール尊重"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS接続がルールに従う（proxy-server-nameserverの設定が必要）",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("ルートアドレスを設定"),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートルートをバイパス",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "routeUndetected": MessageLookupByLibrary.simpleMessage("ルートを検出できません"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルールに従って"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルール対象"),
    "rules": MessageLookupByLibrary.simpleMessage("ルール"),
    "running": MessageLookupByLibrary.simpleMessage("実行中"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("QRコードをスキャン"),
    "schemeBright": MessageLookupByLibrary.simpleMessage("鮮やか"),
    "schemeCalm": MessageLookupByLibrary.simpleMessage("落ち着いた"),
    "schemeExpressive": MessageLookupByLibrary.simpleMessage("表現的"),
    "schemeMono": MessageLookupByLibrary.simpleMessage("モノクロ"),
    "schemeNeutral": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("プロファイルを選択"),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m35,
    "serversAndGroups": MessageLookupByLibrary.simpleMessage("サーバーとグループ"),
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "settingsSendDeviceDataSubtitle": MessageLookupByLibrary.simpleMessage(
      "デバイスID・アプリのバージョン・デバイス名をプロキシプロバイダーに送信します",
    ),
    "settingsSendDeviceDataTitle": MessageLookupByLibrary.simpleMessage(
      "HWIDを送信",
    ),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "shrink": MessageLookupByLibrary.simpleMessage("縮小"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("バックグラウンド起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("バックグラウンドで起動"),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "smart": MessageLookupByLibrary.simpleMessage("スマート"),
    "smartAuto": MessageLookupByLibrary.simpleMessage("自動"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socksポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並び替え"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを開始中..."),
    "startingVpnCore": MessageLookupByLibrary.simpleMessage("VPNコアを起動しています…"),
    "status": MessageLookupByLibrary.simpleMessage("ステータス"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("無効時はシステムDNSを使用"),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止中..."),
    "stopped": MessageLookupByLibrary.simpleMessage("停止中"),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルール"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "subscription": MessageLookupByLibrary.simpleMessage("サブスクリプション"),
    "subscriptionEternal": MessageLookupByLibrary.simpleMessage("無期限サブスクリプション"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションが期限切れになりました",
    ),
    "subscriptionExpiresInDays": m36,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "サブスクリプションは本日期限切れになります",
    ),
    "subscriptionLogo": MessageLookupByLibrary.simpleMessage("サブスクのロゴ"),
    "subscriptionTheme": MessageLookupByLibrary.simpleMessage("サブスクのテーマ"),
    "subscriptionUnlimited": MessageLookupByLibrary.simpleMessage(
      "無期限サブスクリプション",
    ),
    "support": MessageLookupByLibrary.simpleMessage("サポート"),
    "supportProject": MessageLookupByLibrary.simpleMessage("プロジェクトを支援"),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "HTTPプロキシをVpnServiceに接続",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP並列処理"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP並列処理を許可"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URLテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストスケーリング"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "themePresets": MessageLookupByLibrary.simpleMessage("テーマプリセット"),
    "tight": MessageLookupByLibrary.simpleMessage("密"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "toggle": MessageLookupByLibrary.simpleMessage("トグル"),
    "tooFrequentOperation": MessageLookupByLibrary.simpleMessage(
      "再度更新する前に15秒お待ちください",
    ),
    "tools": MessageLookupByLibrary.simpleMessage("設定"),
    "topUpTraffic": MessageLookupByLibrary.simpleMessage("トラフィックを追加"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxyポート"),
    "traffic": MessageLookupByLibrary.simpleMessage("トラフィック"),
    "trafficUnlimited": MessageLookupByLibrary.simpleMessage("無制限トラフィック"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック使用量"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("管理者モードでのみ有効"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を削除",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unnamed": MessageLookupByLibrary.simpleMessage("無題"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateCancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("ダウンロード中…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("更新に失敗しました"),
    "updateInstall": MessageLookupByLibrary.simpleMessage("インストール"),
    "updateLater": MessageLookupByLibrary.simpleMessage("後で"),
    "updateMandatoryNote": MessageLookupByLibrary.simpleMessage(
      "このアップデートを推奨します",
    ),
    "updateRetry": MessageLookupByLibrary.simpleMessage("再試行"),
    "updateSubscription": MessageLookupByLibrary.simpleMessage("更新"),
    "updateVerifying": MessageLookupByLibrary.simpleMessage("検証中…"),
    "updated": MessageLookupByLibrary.simpleMessage("更新しました"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m37,
    "useHosts": MessageLookupByLibrary.simpleMessage("ホストを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムホストを使用"),
    "validUntil": m38,
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "vpnDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb は Android の VPN 権限を使用して、ユーザーが制御するローカル VPN トンネルを作成します。ネットワーク通信は、選択した接続またはサブスクリプションに従ってルーティングされます。この画面または端末の VPN 設定からいつでも切断できます。診断、アカウント、キャビネットなどの任意機能はそれぞれ別個に提供され、該当箇所で説明されます。",
    ),
    "vpnDisclosureContinue": MessageLookupByLibrary.simpleMessage("続行"),
    "vpnDisclosureTitle": MessageLookupByLibrary.simpleMessage("接続する前に"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnService経由で全システムトラフィックをルーティング",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("変更はVPN再起動後に有効"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "workModeCountry": MessageLookupByLibrary.simpleMessage("国"),
    "workModeResetNotice": MessageLookupByLibrary.simpleMessage(
      "モードをスタンダードにリセットしました：更新後にこの設定は利用できません",
    ),
    "years": MessageLookupByLibrary.simpleMessage("年"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
  };
}
