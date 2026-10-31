// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
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
  String get localeName => 'zh_CN';

  static String m0(wait) => "操作过于频繁，请等待 ${wait}";

  static String m1(n) => "${n} 小时";

  static String m2(n) => "${n} 分钟";

  static String m3(n) => "${n} 秒";

  static String m4(host) => "添加 ${host}";

  static String m5(label) => "确定删除当前${label}吗？";

  static String m6(path) => "诊断：${path}";

  static String m7(label) => "${label}不能为空";

  static String m8(label) => "${label}当前已存在";

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

  static String m33(label) => "${label}必须为数字";

  static String m34(label) => "${label} 必须在 1024 到 49151 之间";

  static String m35(count) => "已选择 ${count} 项";

  static String m36(days) => "您的订阅将在${days}天后到期";

  static String m37(label) => "${label}必须为URL";

  static String m38(date) => "至 ${date}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "accessControl": MessageLookupByLibrary.simpleMessage("访问控制"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "只允许选中应用进入加速器",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "选中应用将会被排除在加速器之外",
    ),
    "account": MessageLookupByLibrary.simpleMessage("账号"),
    "accountBiometricEnable": MessageLookupByLibrary.simpleMessage("开启"),
    "accountBiometricEnableReason": MessageLookupByLibrary.simpleMessage(
      "请确认以使用指纹登录",
    ),
    "accountBiometricOfferText": MessageLookupByLibrary.simpleMessage(
      "以后将通过指纹打开账号。",
    ),
    "accountBiometricOfferTitle": MessageLookupByLibrary.simpleMessage(
      "使用指纹登录？",
    ),
    "accountBiometricSwitch": MessageLookupByLibrary.simpleMessage("指纹登录"),
    "accountBiometricUnlockReason": MessageLookupByLibrary.simpleMessage(
      "请确认登录账号",
    ),
    "accountChangeEmail": MessageLookupByLibrary.simpleMessage("更换邮箱"),
    "accountCodeLabel": MessageLookupByLibrary.simpleMessage("验证码"),
    "accountEmailInvalid": MessageLookupByLibrary.simpleMessage("请检查邮箱地址"),
    "accountEmailLabel": MessageLookupByLibrary.simpleMessage("邮箱"),
    "accountErrorCodeExpired": MessageLookupByLibrary.simpleMessage(
      "验证码已过期，请重新获取",
    ),
    "accountErrorDisabled": MessageLookupByLibrary.simpleMessage("登录暂时不可用"),
    "accountErrorEmailRejected": MessageLookupByLibrary.simpleMessage(
      "此邮箱无法使用",
    ),
    "accountErrorGeneric": MessageLookupByLibrary.simpleMessage("操作未成功"),
    "accountErrorInvalidCode": MessageLookupByLibrary.simpleMessage("验证码错误"),
    "accountErrorNetwork": MessageLookupByLibrary.simpleMessage("无法连接到服务器"),
    "accountErrorRateLimited": m0,
    "accountErrorRateLimitedLater": MessageLookupByLibrary.simpleMessage(
      "操作过于频繁，请稍后重试",
    ),
    "accountGetCode": MessageLookupByLibrary.simpleMessage("获取验证码"),
    "accountLoggedOut": MessageLookupByLibrary.simpleMessage("已退出登录"),
    "accountLoginByEmail": MessageLookupByLibrary.simpleMessage("通过邮箱登录"),
    "accountLogout": MessageLookupByLibrary.simpleMessage("退出登录"),
    "accountNoSubscription": MessageLookupByLibrary.simpleMessage("已登录，暂无订阅"),
    "accountRemoveFromDevice": MessageLookupByLibrary.simpleMessage("从此设备移除"),
    "accountRemoveFromDeviceText": MessageLookupByLibrary.simpleMessage(
      "账户及其订阅将从此设备上消失。您可以使用邮箱重新登录。",
    ),
    "accountRemoveFromDeviceTitle": MessageLookupByLibrary.simpleMessage(
      "从此设备移除？",
    ),
    "accountRemovedFromDevice": MessageLookupByLibrary.simpleMessage("已从此设备移除"),
    "accountResend": MessageLookupByLibrary.simpleMessage("重新发送"),
    "accountSignInWithCode": MessageLookupByLibrary.simpleMessage("使用验证码登录"),
    "accountSubscriptionAlreadyPresent": MessageLookupByLibrary.simpleMessage(
      "订阅已在应用中",
    ),
    "accountSubscriptionImported": MessageLookupByLibrary.simpleMessage(
      "订阅已连接",
    ),
    "accountSyncFailed": MessageLookupByLibrary.simpleMessage("已登录，订阅未连接"),
    "accountSyncSubscription": MessageLookupByLibrary.simpleMessage("更新订阅"),
    "accountUnlock": MessageLookupByLibrary.simpleMessage("解锁"),
    "accountWaitHours": m1,
    "accountWaitMinutes": m2,
    "accountWaitSeconds": m3,
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "addFromPhoneSubtitle": MessageLookupByLibrary.simpleMessage("用手机扫描二维码"),
    "addFromPhoneTitle": MessageLookupByLibrary.simpleMessage("从手机添加"),
    "addNamedSubscription": m4,
    "addProfile": MessageLookupByLibrary.simpleMessage("添加配置"),
    "addRule": MessageLookupByLibrary.simpleMessage("添加规则"),
    "addSubscription": MessageLookupByLibrary.simpleMessage("添加订阅"),
    "address": MessageLookupByLibrary.simpleMessage("地址"),
    "ago": MessageLookupByLibrary.simpleMessage("前"),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("允许应用绕过加速器"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage("开启后部分应用可绕过加速器"),
    "allowLan": MessageLookupByLibrary.simpleMessage("局域网代理"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("允许通过局域网访问代理"),
    "alwaysOnVpn": MessageLookupByLibrary.simpleMessage("始终开启"),
    "alwaysOnVpnOpenFailed": MessageLookupByLibrary.simpleMessage("无法打开系统设置"),
    "app": MessageLookupByLibrary.simpleMessage("应用"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("应用访问控制"),
    "application": MessageLookupByLibrary.simpleMessage("应用程序设置"),
    "auto": MessageLookupByLibrary.simpleMessage("自动"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自动检查更新"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage("应用启动时自动检查更新"),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("自动关闭连接"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "切换节点后自动关闭连接",
    ),
    "autoFollowAccent": MessageLookupByLibrary.simpleMessage("自动（跟随强调色）"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自启动"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("跟随系统自启动"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自动运行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("应用打开时自动运行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("自动设置系统DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自动更新"),
    "backgroundOrbs": MessageLookupByLibrary.simpleMessage("背景光球"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本配置"),
    "bind": MessageLookupByLibrary.simpleMessage("绑定"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("黑名单模式"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("排除域名"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("仅在系统代理启用时生效"),
    "cabinet": MessageLookupByLibrary.simpleMessage("个人中心"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("缓存已损坏，是否清空？"),
    "cameraPermissionDenied": MessageLookupByLibrary.simpleMessage("相机权限被拒绝"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("取消全选"),
    "changeServer": MessageLookupByLibrary.simpleMessage("切换服务器"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("检查更新"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("当前应用已经是最新版了"),
    "checkUpdateFailed": MessageLookupByLibrary.simpleMessage("无法检查更新"),
    "checking": MessageLookupByLibrary.simpleMessage("检测中..."),
    "clearData": MessageLookupByLibrary.simpleMessage("清除数据"),
    "clearDataTip": MessageLookupByLibrary.simpleMessage(
      "这将删除所有应用数据并重新启动应用程序。您确定吗？",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("导出剪贴板"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("剪贴板导入"),
    "close": MessageLookupByLibrary.simpleMessage("关闭"),
    "color": MessageLookupByLibrary.simpleMessage("颜色"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("配色方案"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compatible": MessageLookupByLibrary.simpleMessage("兼容模式"),
    "confirm": MessageLookupByLibrary.simpleMessage("确定"),
    "connections": MessageLookupByLibrary.simpleMessage("连接"),
    "connectivity": MessageLookupByLibrary.simpleMessage("连通性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copyLogs": MessageLookupByLibrary.simpleMessage("复制日志"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("复制成功"),
    "core": MessageLookupByLibrary.simpleMessage("内核"),
    "country": MessageLookupByLibrary.simpleMessage("区域"),
    "crashTest": MessageLookupByLibrary.simpleMessage("崩溃测试"),
    "create": MessageLookupByLibrary.simpleMessage("创建"),
    "cut": MessageLookupByLibrary.simpleMessage("剪切"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("仪表盘"),
    "dashboardEmptyHint": MessageLookupByLibrary.simpleMessage("粘贴链接或扫描二维码"),
    "dashboardEmptyTitle": MessageLookupByLibrary.simpleMessage("添加订阅"),
    "day": MessageLookupByLibrary.simpleMessage("天"),
    "days": MessageLookupByLibrary.simpleMessage("天"),
    "daysGenitive": MessageLookupByLibrary.simpleMessage("天"),
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("默认域名服务器"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析DNS服务器"),
    "defaultText": MessageLookupByLibrary.simpleMessage("默认"),
    "delay": MessageLookupByLibrary.simpleMessage("延迟"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "deleteTip": m5,
    "desc": MessageLookupByLibrary.simpleMessage("dropweb — 简洁高速的加速器。开源，无广告。"),
    "detectionTip": MessageLookupByLibrary.simpleMessage("依赖第三方api，仅供参考"),
    "devAdbRemote": MessageLookupByLibrary.simpleMessage("adb 遥控"),
    "devAdbRemoteReplies": MessageLookupByLibrary.simpleMessage(
      "回复：adb logcat -s dropweb-dbg",
    ),
    "devCopyAll": MessageLookupByLibrary.simpleMessage("全部复制"),
    "devDiagnostics": MessageLookupByLibrary.simpleMessage("诊断"),
    "devDiagnosticsWritten": m6,
    "devEffectiveConfig": MessageLookupByLibrary.simpleMessage("最终配置"),
    "devEffectiveConfigEmpty": MessageLookupByLibrary.simpleMessage(
      "内核尚未启动 — 暂无配置",
    ),
    "devSubscriptionHeaders": MessageLookupByLibrary.simpleMessage("订阅响应头"),
    "devTakeDiagnostics": MessageLookupByLibrary.simpleMessage("采集诊断信息"),
    "developerMode": MessageLookupByLibrary.simpleMessage("开发者模式"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage("开发者模式已启用。"),
    "direct": MessageLookupByLibrary.simpleMessage("直连"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "discovery": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("更新DNS相关设置"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS模式"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("添加配置文件从"),
    "domain": MessageLookupByLibrary.simpleMessage("域名"),
    "download": MessageLookupByLibrary.simpleMessage("下载"),
    "edit": MessageLookupByLibrary.simpleMessage("编辑"),
    "emptyTip": m7,
    "en": MessageLookupByLibrary.simpleMessage("英语"),
    "entries": MessageLookupByLibrary.simpleMessage("个条目"),
    "errorTitle": MessageLookupByLibrary.simpleMessage("错误"),
    "exclude": MessageLookupByLibrary.simpleMessage("从最近任务中隐藏"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage("应用在后台时,从最近任务中隐藏应用"),
    "existsTip": m8,
    "exit": MessageLookupByLibrary.simpleMessage("退出"),
    "expand": MessageLookupByLibrary.simpleMessage("标准"),
    "expiresOn": MessageLookupByLibrary.simpleMessage("到期日期"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("导出日志"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部控制器"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "开启后将可以通过9090端口控制dropweb",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部链接"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip过滤"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip范围"),
    "fallback": MessageLookupByLibrary.simpleMessage("回退"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("一般情况下使用境外DNS"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback过滤"),
    "file": MessageLookupByLibrary.simpleMessage("文件"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("查找进程"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("字体"),
    "fullTunnelTitle": MessageLookupByLibrary.simpleMessage("所有流量通过 VPN"),
    "general": MessageLookupByLibrary.simpleMessage("常规"),
    "generalDesc": MessageLookupByLibrary.simpleMessage("修改通用设置"),
    "genericErrorMessage": MessageLookupByLibrary.simpleMessage("出了点问题"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低内存模式"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage("开启将使用Geo低内存加载器"),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip代码"),
    "global": MessageLookupByLibrary.simpleMessage("全局"),
    "go": MessageLookupByLibrary.simpleMessage("前往"),
    "goDownload": MessageLookupByLibrary.simpleMessage("前往下载"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("追加Hosts"),
    "hour": MessageLookupByLibrary.simpleMessage("小时"),
    "hours": MessageLookupByLibrary.simpleMessage("小时"),
    "hoursGenitive": MessageLookupByLibrary.simpleMessage("小时"),
    "hoursPlural": MessageLookupByLibrary.simpleMessage("小时"),
    "hwidFreeSlot": MessageLookupByLibrary.simpleMessage("释放设备位"),
    "hwidLimitReached": MessageLookupByLibrary.simpleMessage(
      "已达到设备数量上限\n请先在服务商处释放名额，然后刷新订阅",
    ),
    "hwidRecovered": MessageLookupByLibrary.simpleMessage("设备已注册\n订阅已更新"),
    "icon": MessageLookupByLibrary.simpleMessage("图片"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("图标样式"),
    "import": MessageLookupByLibrary.simpleMessage("导入"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("从URL导入"),
    "importFromUrlHint": MessageLookupByLibrary.simpleMessage(
      "https://… — 您的提供商的订阅链接",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("通过URL导入"),
    "init": MessageLookupByLibrary.simpleMessage("初始化"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("智能选择"),
    "internet": MessageLookupByLibrary.simpleMessage("互联网"),
    "interval": MessageLookupByLibrary.simpleMessage("间隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("内网 IP"),
    "invalidProfileUrl": MessageLookupByLibrary.simpleMessage(
      "订阅链接无效,请使用 http:// 或 https://",
    ),
    "ios27A11yJoy": MessageLookupByLibrary.simpleMessage(
      "Connection and country",
    ),
    "ios27A11yRoute": m9,
    "ios27AppearanceColors": MessageLookupByLibrary.simpleMessage("Colors"),
    "ios27AppearanceOwn": MessageLookupByLibrary.simpleMessage("Custom"),
    "ios27AppearanceProvider": MessageLookupByLibrary.simpleMessage("Provider"),
    "ios27AppearanceThemes": MessageLookupByLibrary.simpleMessage("主题"),
    "ios27ColorSheetLabel": m10,
    "ios27ColorSlotAccent": MessageLookupByLibrary.simpleMessage("Buttons"),
    "ios27ColorSlotOrb1": MessageLookupByLibrary.simpleMessage(
      "Background top",
    ),
    "ios27ColorSlotOrb2": MessageLookupByLibrary.simpleMessage(
      "Background bottom",
    ),
    "ios27DisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb 通过 VPN 配置创建 VPN 隧道，iPhone 会请求您允许添加该配置。流量会经由您订阅的服务器传输。dropweb 不会查看或记录您在网络上的活动。订阅提供方会获取您的 IP 地址和设备标识符。",
    ),
    "ios27DisclosurePolicy": MessageLookupByLibrary.simpleMessage("隐私政策"),
    "ios27DisclosureTitle": MessageLookupByLibrary.simpleMessage("连接之前"),
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
    "ios27StatCountry": MessageLookupByLibrary.simpleMessage("国家"),
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
    "ipcidr": MessageLookupByLibrary.simpleMessage("IP/掩码"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("开启后将可以接收IPv6流量"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("允许IPv6入站"),
    "ja": MessageLookupByLibrary.simpleMessage("日语"),
    "just": MessageLookupByLibrary.simpleMessage("刚刚"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage("TCP保持活动间隔"),
    "key": MessageLookupByLibrary.simpleMessage("键"),
    "language": MessageLookupByLibrary.simpleMessage("语言"),
    "layout": MessageLookupByLibrary.simpleMessage("布局"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "list": MessageLookupByLibrary.simpleMessage("列表"),
    "listen": MessageLookupByLibrary.simpleMessage("监听"),
    "loadingEllipsis": MessageLookupByLibrary.simpleMessage("加载中…"),
    "local": MessageLookupByLibrary.simpleMessage("本地"),
    "logLevel": MessageLookupByLibrary.simpleMessage("日志等级"),
    "logcat": MessageLookupByLibrary.simpleMessage("日志捕获"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("禁用将会隐藏日志入口"),
    "logs": MessageLookupByLibrary.simpleMessage("日志"),
    "logsCopied": MessageLookupByLibrary.simpleMessage("日志已复制"),
    "loopback": MessageLookupByLibrary.simpleMessage("回环解锁工具"),
    "loose": MessageLookupByLibrary.simpleMessage("宽松"),
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
    "m3eStatCountry": MessageLookupByLibrary.simpleMessage("国家"),
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
    "managedByProvider": MessageLookupByLibrary.simpleMessage("这些设置由您的提供商管理"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("内存信息"),
    "menu": MessageLookupByLibrary.simpleMessage("菜单"),
    "min": MessageLookupByLibrary.simpleMessage("最小"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("退出时最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage("修改系统默认退出事件"),
    "minutes": MessageLookupByLibrary.simpleMessage("分钟"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合端口"),
    "mode": MessageLookupByLibrary.simpleMessage("模式"),
    "months": MessageLookupByLibrary.simpleMessage("月"),
    "more": MessageLookupByLibrary.simpleMessage("更多"),
    "name": MessageLookupByLibrary.simpleMessage("名称"),
    "nameserver": MessageLookupByLibrary.simpleMessage("域名服务器"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析域名"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("域名服务器策略"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage("指定对应域名服务器策略"),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("修改网络相关设置"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("您的IP地址"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("网络速度"),
    "noData": MessageLookupByLibrary.simpleMessage("暂无数据"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("无网络"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("无网络应用"),
    "noResolve": MessageLookupByLibrary.simpleMessage("不解析IP"),
    "none": MessageLookupByLibrary.simpleMessage("无"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("没有配置文件,请先添加配置文件"),
    "numberTip": m33,
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "onboardingClipboardImport": MessageLookupByLibrary.simpleMessage(
      "从剪贴板粘贴订阅",
    ),
    "onboardingImported": MessageLookupByLibrary.simpleMessage("订阅已添加，点按以连接"),
    "oneline": MessageLookupByLibrary.simpleMessage("单行"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("仅统计代理"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "开启后，将只统计代理流量",
    ),
    "openLogsFolder": MessageLookupByLibrary.simpleMessage("打开日志文件夹"),
    "options": MessageLookupByLibrary.simpleMessage("选项"),
    "orbBlur": MessageLookupByLibrary.simpleMessage("模糊"),
    "orbOne": MessageLookupByLibrary.simpleMessage("顶部光球"),
    "orbTwo": MessageLookupByLibrary.simpleMessage("底部光球"),
    "other": MessageLookupByLibrary.simpleMessage("其他"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("出站模式"),
    "override": MessageLookupByLibrary.simpleMessage("覆写"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("覆写DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage("开启后将覆盖配置中的DNS选项"),
    "overrideNetworkSettings": MessageLookupByLibrary.simpleMessage("覆盖网络设置"),
    "overrideNetworkSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "忽略提供商配置中的网络设置",
    ),
    "overrideProviderSettings": MessageLookupByLibrary.simpleMessage("覆盖"),
    "overrideProviderSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "忽略提供商设置并手动管理",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("调色板"),
    "password": MessageLookupByLibrary.simpleMessage("密码"),
    "paste": MessageLookupByLibrary.simpleMessage("粘贴"),
    "pasteFromClipboard": MessageLookupByLibrary.simpleMessage("粘贴"),
    "personalCabinet": MessageLookupByLibrary.simpleMessage("个人中心"),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "请输入管理员密码",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "请上传有效的二维码",
    ),
    "port": MessageLookupByLibrary.simpleMessage("端口"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("请输入不同的端口"),
    "portTip": m34,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("优先使用DOH的http/3"),
    "presetAmber": MessageLookupByLibrary.simpleMessage("琥珀"),
    "presetAmethyst": MessageLookupByLibrary.simpleMessage("紫晶"),
    "presetCrimson": MessageLookupByLibrary.simpleMessage("绯红"),
    "presetEmerald": MessageLookupByLibrary.simpleMessage("坠落"),
    "presetFrost": MessageLookupByLibrary.simpleMessage("霜冰"),
    "presetMagma": MessageLookupByLibrary.simpleMessage("熔岩"),
    "presetStealth": MessageLookupByLibrary.simpleMessage("隐影"),
    "preview": MessageLookupByLibrary.simpleMessage("预览"),
    "privacyPolicy": MessageLookupByLibrary.simpleMessage("隐私政策"),
    "profile": MessageLookupByLibrary.simpleMessage("配置"),
    "profiles": MessageLookupByLibrary.simpleMessage("配置"),
    "project": MessageLookupByLibrary.simpleMessage("项目"),
    "providers": MessageLookupByLibrary.simpleMessage("提供者"),
    "proxies": MessageLookupByLibrary.simpleMessage("代理"),
    "proxiesSetting": MessageLookupByLibrary.simpleMessage("代理设置"),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("代理域名服务器"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage("用于解析代理节点的域名"),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("代理提供者"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("纯黑模式"),
    "qrNotFound": MessageLookupByLibrary.simpleMessage("未找到二维码"),
    "qrScanFromImageUnsupported": MessageLookupByLibrary.simpleMessage(
      "不支持从图片扫描二维码",
    ),
    "qrcode": MessageLookupByLibrary.simpleMessage("二维码"),
    "receiveSubscriptionTitle": MessageLookupByLibrary.simpleMessage("接收订阅"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir端口"),
    "redo": MessageLookupByLibrary.simpleMessage("重做"),
    "regExp": MessageLookupByLibrary.simpleMessage("正则"),
    "remaining": MessageLookupByLibrary.simpleMessage("剩余"),
    "remainingPlural": MessageLookupByLibrary.simpleMessage("剩余"),
    "remainingSingular": MessageLookupByLibrary.simpleMessage("剩余"),
    "remote": MessageLookupByLibrary.simpleMessage("远程"),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rename": MessageLookupByLibrary.simpleMessage("重命名"),
    "renew": MessageLookupByLibrary.simpleMessage("续订"),
    "requests": MessageLookupByLibrary.simpleMessage("请求"),
    "reset": MessageLookupByLibrary.simpleMessage("重置"),
    "resetTip": MessageLookupByLibrary.simpleMessage("确定要重置吗?"),
    "resources": MessageLookupByLibrary.simpleMessage("资源"),
    "respectRules": MessageLookupByLibrary.simpleMessage("遵守规则"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS连接跟随rules,需配置proxy-server-nameserver",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("重启"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("路由地址"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("配置监听路由地址"),
    "routeMode": MessageLookupByLibrary.simpleMessage("路由模式"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage("绕过私有路由地址"),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("使用配置"),
    "routeUndetected": MessageLookupByLibrary.simpleMessage("无法识别路由"),
    "ru": MessageLookupByLibrary.simpleMessage("俄语"),
    "rule": MessageLookupByLibrary.simpleMessage("按规则"),
    "ruleName": MessageLookupByLibrary.simpleMessage("规则名称"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("规则提供者"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("规则目标"),
    "rules": MessageLookupByLibrary.simpleMessage("规则"),
    "running": MessageLookupByLibrary.simpleMessage("运行中"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("扫描二维码"),
    "schemeBright": MessageLookupByLibrary.simpleMessage("鲜艳"),
    "schemeCalm": MessageLookupByLibrary.simpleMessage("柔和"),
    "schemeExpressive": MessageLookupByLibrary.simpleMessage("鲜明个性"),
    "schemeMono": MessageLookupByLibrary.simpleMessage("单色"),
    "schemeNeutral": MessageLookupByLibrary.simpleMessage("中性"),
    "script": MessageLookupByLibrary.simpleMessage("脚本"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "selectAll": MessageLookupByLibrary.simpleMessage("全选"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("选择配置"),
    "selected": MessageLookupByLibrary.simpleMessage("已选择"),
    "selectedCountTitle": m35,
    "serversAndGroups": MessageLookupByLibrary.simpleMessage("服务器与分组"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "settingsSendDeviceDataSubtitle": MessageLookupByLibrary.simpleMessage(
      "向代理提供商发送设备标识符、应用版本和设备名称",
    ),
    "settingsSendDeviceDataTitle": MessageLookupByLibrary.simpleMessage(
      "发送 HWID",
    ),
    "show": MessageLookupByLibrary.simpleMessage("显示"),
    "shrink": MessageLookupByLibrary.simpleMessage("紧凑"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("静默启动"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("后台启动"),
    "size": MessageLookupByLibrary.simpleMessage("尺寸"),
    "smart": MessageLookupByLibrary.simpleMessage("智能"),
    "smartAuto": MessageLookupByLibrary.simpleMessage("自动"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks端口"),
    "sort": MessageLookupByLibrary.simpleMessage("排序"),
    "source": MessageLookupByLibrary.simpleMessage("来源"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("源IP"),
    "stackMode": MessageLookupByLibrary.simpleMessage("栈模式"),
    "standard": MessageLookupByLibrary.simpleMessage("标准"),
    "start": MessageLookupByLibrary.simpleMessage("启动"),
    "startVpn": MessageLookupByLibrary.simpleMessage("正在启动加速器..."),
    "startingVpnCore": MessageLookupByLibrary.simpleMessage("正在启动 VPN 核心…"),
    "status": MessageLookupByLibrary.simpleMessage("状态"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("关闭后将使用系统DNS"),
    "stop": MessageLookupByLibrary.simpleMessage("暂停"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("正在停止加速器..."),
    "stopped": MessageLookupByLibrary.simpleMessage("已停止"),
    "style": MessageLookupByLibrary.simpleMessage("风格"),
    "subRule": MessageLookupByLibrary.simpleMessage("子规则"),
    "submit": MessageLookupByLibrary.simpleMessage("提交"),
    "subscription": MessageLookupByLibrary.simpleMessage("订阅"),
    "subscriptionEternal": MessageLookupByLibrary.simpleMessage("永久订阅"),
    "subscriptionExpired": MessageLookupByLibrary.simpleMessage("您的订阅已过期"),
    "subscriptionExpiresInDays": m36,
    "subscriptionExpiresToday": MessageLookupByLibrary.simpleMessage(
      "您的订阅今天到期",
    ),
    "subscriptionLogo": MessageLookupByLibrary.simpleMessage("订阅徽标"),
    "subscriptionTheme": MessageLookupByLibrary.simpleMessage("订阅主题"),
    "subscriptionUnlimited": MessageLookupByLibrary.simpleMessage("永久订阅"),
    "support": MessageLookupByLibrary.simpleMessage("支持"),
    "supportProject": MessageLookupByLibrary.simpleMessage("支持项目"),
    "sync": MessageLookupByLibrary.simpleMessage("同步"),
    "system": MessageLookupByLibrary.simpleMessage("系统"),
    "systemApp": MessageLookupByLibrary.simpleMessage("系统应用"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage("设置系统代理"),
    "tab": MessageLookupByLibrary.simpleMessage("标签页"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("选项卡动画"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("仅在移动视图中有效"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP并发"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("开启后允许TCP并发"),
    "testUrl": MessageLookupByLibrary.simpleMessage("测速链接"),
    "textScale": MessageLookupByLibrary.simpleMessage("文本缩放"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "themeColor": MessageLookupByLibrary.simpleMessage("主题色彩"),
    "themeMode": MessageLookupByLibrary.simpleMessage("主题模式"),
    "themePresets": MessageLookupByLibrary.simpleMessage("主题预设"),
    "tight": MessageLookupByLibrary.simpleMessage("紧凑"),
    "time": MessageLookupByLibrary.simpleMessage("时间"),
    "tip": MessageLookupByLibrary.simpleMessage("提示"),
    "toggle": MessageLookupByLibrary.simpleMessage("切换"),
    "tooFrequentOperation": MessageLookupByLibrary.simpleMessage("请等待15秒后再次刷新"),
    "tools": MessageLookupByLibrary.simpleMessage("设置"),
    "topUpTraffic": MessageLookupByLibrary.simpleMessage("购买流量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy端口"),
    "traffic": MessageLookupByLibrary.simpleMessage("流量"),
    "trafficUnlimited": MessageLookupByLibrary.simpleMessage("不限流量"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("流量统计"),
    "tun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("仅在管理员模式生效"),
    "undo": MessageLookupByLibrary.simpleMessage("撤销"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("统一延迟"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage("去除握手等额外延迟"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unnamed": MessageLookupByLibrary.simpleMessage("未命名"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateCancel": MessageLookupByLibrary.simpleMessage("取消"),
    "updateDownloading": MessageLookupByLibrary.simpleMessage("正在下载…"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("更新失败"),
    "updateInstall": MessageLookupByLibrary.simpleMessage("安装"),
    "updateLater": MessageLookupByLibrary.simpleMessage("稍后"),
    "updateMandatoryNote": MessageLookupByLibrary.simpleMessage("建议更新到此版本"),
    "updateRetry": MessageLookupByLibrary.simpleMessage("重试"),
    "updateSubscription": MessageLookupByLibrary.simpleMessage("更新"),
    "updateVerifying": MessageLookupByLibrary.simpleMessage("正在校验…"),
    "updated": MessageLookupByLibrary.simpleMessage("已更新"),
    "upload": MessageLookupByLibrary.simpleMessage("上传"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlTip": m37,
    "useHosts": MessageLookupByLibrary.simpleMessage("使用Hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("使用系统Hosts"),
    "validUntil": m38,
    "value": MessageLookupByLibrary.simpleMessage("值"),
    "view": MessageLookupByLibrary.simpleMessage("查看"),
    "vpnDisclosureBody": MessageLookupByLibrary.simpleMessage(
      "dropweb 使用 Android 的 VPN 权限来创建由您控制的本地加速隧道。网络流量将按照您选择的连接或订阅进行路由。您可以随时通过此界面或系统设置断开连接。任何可选的诊断、账户或后台功能均为独立功能，将在相应位置进行说明。",
    ),
    "vpnDisclosureContinue": MessageLookupByLibrary.simpleMessage("继续"),
    "vpnDisclosureTitle": MessageLookupByLibrary.simpleMessage("连接之前"),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "通过VpnService自动路由系统所有流量",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("重启加速器后改变生效"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("白名单模式"),
    "workModeCountry": MessageLookupByLibrary.simpleMessage("国家"),
    "workModeResetNotice": MessageLookupByLibrary.simpleMessage(
      "模式已重置为标准：更新后该设置不可用",
    ),
    "years": MessageLookupByLibrary.simpleMessage("年"),
    "zh_CN": MessageLookupByLibrary.simpleMessage("中文简体"),
  };
}
