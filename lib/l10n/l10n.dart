// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `Invalid subscription URL. Use http:// or https://`
  String get invalidProfileUrl {
    return Intl.message(
      'Invalid subscription URL. Use http:// or https://',
      name: 'invalidProfileUrl',
      desc: '',
      args: [],
    );
  }

  /// `By rule`
  String get rule {
    return Intl.message('By rule', name: 'rule', desc: '', args: []);
  }

  /// `Global`
  String get global {
    return Intl.message('Global', name: 'global', desc: '', args: []);
  }

  /// `Direct`
  String get direct {
    return Intl.message('Direct', name: 'direct', desc: '', args: []);
  }

  /// `Smart`
  String get smart {
    return Intl.message('Smart', name: 'smart', desc: '', args: []);
  }

  /// `Rules`
  String get rules {
    return Intl.message('Rules', name: 'rules', desc: '', args: []);
  }

  /// `Dashboard`
  String get dashboard {
    return Intl.message('Dashboard', name: 'dashboard', desc: '', args: []);
  }

  /// `Proxies`
  String get proxies {
    return Intl.message('Proxies', name: 'proxies', desc: '', args: []);
  }

  /// `Profile`
  String get profile {
    return Intl.message('Profile', name: 'profile', desc: '', args: []);
  }

  /// `Profiles`
  String get profiles {
    return Intl.message('Profiles', name: 'profiles', desc: '', args: []);
  }

  /// `Subscription`
  String get subscription {
    return Intl.message(
      'Subscription',
      name: 'subscription',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get tools {
    return Intl.message('Settings', name: 'tools', desc: '', args: []);
  }

  /// `Logs`
  String get logs {
    return Intl.message('Logs', name: 'logs', desc: '', args: []);
  }

  /// `Resources`
  String get resources {
    return Intl.message('Resources', name: 'resources', desc: '', args: []);
  }

  /// `Traffic usage`
  String get trafficUsage {
    return Intl.message(
      'Traffic usage',
      name: 'trafficUsage',
      desc: '',
      args: [],
    );
  }

  /// `Network speed`
  String get networkSpeed {
    return Intl.message(
      'Network speed',
      name: 'networkSpeed',
      desc: '',
      args: [],
    );
  }

  /// `Outbound mode`
  String get outboundMode {
    return Intl.message(
      'Outbound mode',
      name: 'outboundMode',
      desc: '',
      args: [],
    );
  }

  /// `Your IP Address`
  String get networkDetection {
    return Intl.message(
      'Your IP Address',
      name: 'networkDetection',
      desc: '',
      args: [],
    );
  }

  /// `Upload`
  String get upload {
    return Intl.message('Upload', name: 'upload', desc: '', args: []);
  }

  /// `Download`
  String get download {
    return Intl.message('Download', name: 'download', desc: '', args: []);
  }

  /// `No profile, Please add a profile`
  String get nullProfileDesc {
    return Intl.message(
      'No profile, Please add a profile',
      name: 'nullProfileDesc',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Default`
  String get defaultText {
    return Intl.message('Default', name: 'defaultText', desc: '', args: []);
  }

  /// `More`
  String get more {
    return Intl.message('More', name: 'more', desc: '', args: []);
  }

  /// `Other`
  String get other {
    return Intl.message('Other', name: 'other', desc: '', args: []);
  }

  /// `About`
  String get about {
    return Intl.message('About', name: 'about', desc: '', args: []);
  }

  /// `English`
  String get en {
    return Intl.message('English', name: 'en', desc: '', args: []);
  }

  /// `Japanese`
  String get ja {
    return Intl.message('Japanese', name: 'ja', desc: '', args: []);
  }

  /// `Russian`
  String get ru {
    return Intl.message('Russian', name: 'ru', desc: '', args: []);
  }

  /// `Simplified Chinese`
  String get zh_CN {
    return Intl.message(
      'Simplified Chinese',
      name: 'zh_CN',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Override`
  String get override {
    return Intl.message('Override', name: 'override', desc: '', args: []);
  }

  /// `AllowLan`
  String get allowLan {
    return Intl.message('AllowLan', name: 'allowLan', desc: '', args: []);
  }

  /// `Allow access proxy through the LAN`
  String get allowLanDesc {
    return Intl.message(
      'Allow access proxy through the LAN',
      name: 'allowLanDesc',
      desc: '',
      args: [],
    );
  }

  /// `TUN`
  String get tun {
    return Intl.message('TUN', name: 'tun', desc: '', args: []);
  }

  /// `only effective in administrator mode`
  String get tunDesc {
    return Intl.message(
      'only effective in administrator mode',
      name: 'tunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Minimize on exit`
  String get minimizeOnExit {
    return Intl.message(
      'Minimize on exit',
      name: 'minimizeOnExit',
      desc: '',
      args: [],
    );
  }

  /// `Modify the default system exit event`
  String get minimizeOnExitDesc {
    return Intl.message(
      'Modify the default system exit event',
      name: 'minimizeOnExitDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto launch`
  String get autoLaunch {
    return Intl.message('Auto launch', name: 'autoLaunch', desc: '', args: []);
  }

  /// `Follow the system self startup`
  String get autoLaunchDesc {
    return Intl.message(
      'Follow the system self startup',
      name: 'autoLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `SilentLaunch`
  String get silentLaunch {
    return Intl.message(
      'SilentLaunch',
      name: 'silentLaunch',
      desc: '',
      args: [],
    );
  }

  /// `Start in the background`
  String get silentLaunchDesc {
    return Intl.message(
      'Start in the background',
      name: 'silentLaunchDesc',
      desc: '',
      args: [],
    );
  }

  /// `AutoRun`
  String get autoRun {
    return Intl.message('AutoRun', name: 'autoRun', desc: '', args: []);
  }

  /// `Auto run when the application is opened`
  String get autoRunDesc {
    return Intl.message(
      'Auto run when the application is opened',
      name: 'autoRunDesc',
      desc: '',
      args: [],
    );
  }

  /// `Override`
  String get overrideProviderSettings {
    return Intl.message(
      'Override',
      name: 'overrideProviderSettings',
      desc: '',
      args: [],
    );
  }

  /// `Ignore provider settings and manage manually`
  String get overrideProviderSettingsDesc {
    return Intl.message(
      'Ignore provider settings and manage manually',
      name: 'overrideProviderSettingsDesc',
      desc: '',
      args: [],
    );
  }

  /// `These settings are managed by your provider`
  String get managedByProvider {
    return Intl.message(
      'These settings are managed by your provider',
      name: 'managedByProvider',
      desc: '',
      args: [],
    );
  }

  /// `Override network settings`
  String get overrideNetworkSettings {
    return Intl.message(
      'Override network settings',
      name: 'overrideNetworkSettings',
      desc: '',
      args: [],
    );
  }

  /// `Ignore network settings from provider config`
  String get overrideNetworkSettingsDesc {
    return Intl.message(
      'Ignore network settings from provider config',
      name: 'overrideNetworkSettingsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Logcat`
  String get logcat {
    return Intl.message('Logcat', name: 'logcat', desc: '', args: []);
  }

  /// `Disabling will hide the log entry`
  String get logcatDesc {
    return Intl.message(
      'Disabling will hide the log entry',
      name: 'logcatDesc',
      desc: '',
      args: [],
    );
  }

  /// `Auto check updates`
  String get autoCheckUpdate {
    return Intl.message(
      'Auto check updates',
      name: 'autoCheckUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Auto check for updates when the app starts`
  String get autoCheckUpdateDesc {
    return Intl.message(
      'Auto check for updates when the app starts',
      name: 'autoCheckUpdateDesc',
      desc: '',
      args: [],
    );
  }

  /// `AccessControl`
  String get accessControl {
    return Intl.message(
      'AccessControl',
      name: 'accessControl',
      desc: '',
      args: [],
    );
  }

  /// `Application Settings`
  String get application {
    return Intl.message(
      'Application Settings',
      name: 'application',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `OK`
  String get ok {
    return Intl.message('OK', name: 'ok', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Add subscription`
  String get addSubscription {
    return Intl.message(
      'Add subscription',
      name: 'addSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Scan QR code`
  String get scanQrCode {
    return Intl.message('Scan QR code', name: 'scanQrCode', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `Years`
  String get years {
    return Intl.message('Years', name: 'years', desc: '', args: []);
  }

  /// `Months`
  String get months {
    return Intl.message('Months', name: 'months', desc: '', args: []);
  }

  /// `Hours`
  String get hours {
    return Intl.message('Hours', name: 'hours', desc: '', args: []);
  }

  /// `day`
  String get day {
    return Intl.message('day', name: 'day', desc: '', args: []);
  }

  /// `days`
  String get days {
    return Intl.message('days', name: 'days', desc: '', args: []);
  }

  /// `days`
  String get daysGenitive {
    return Intl.message('days', name: 'daysGenitive', desc: '', args: []);
  }

  /// `hour`
  String get hour {
    return Intl.message('hour', name: 'hour', desc: '', args: []);
  }

  /// `hours`
  String get hoursPlural {
    return Intl.message('hours', name: 'hoursPlural', desc: '', args: []);
  }

  /// `hours`
  String get hoursGenitive {
    return Intl.message('hours', name: 'hoursGenitive', desc: '', args: []);
  }

  /// `Minutes`
  String get minutes {
    return Intl.message('Minutes', name: 'minutes', desc: '', args: []);
  }

  /// `Seconds`
  String get seconds {
    return Intl.message('Seconds', name: 'seconds', desc: '', args: []);
  }

  /// ` Ago`
  String get ago {
    return Intl.message(' Ago', name: 'ago', desc: '', args: []);
  }

  /// `Just`
  String get just {
    return Intl.message('Just', name: 'just', desc: '', args: []);
  }

  /// `QR code`
  String get qrcode {
    return Intl.message('QR code', name: 'qrcode', desc: '', args: []);
  }

  /// `URL`
  String get url {
    return Intl.message('URL', name: 'url', desc: '', args: []);
  }

  /// `File`
  String get file {
    return Intl.message('File', name: 'file', desc: '', args: []);
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Auto update`
  String get autoUpdate {
    return Intl.message('Auto update', name: 'autoUpdate', desc: '', args: []);
  }

  /// `Theme mode`
  String get themeMode {
    return Intl.message('Theme mode', name: 'themeMode', desc: '', args: []);
  }

  /// `Theme color`
  String get themeColor {
    return Intl.message('Theme color', name: 'themeColor', desc: '', args: []);
  }

  /// `Theme presets`
  String get themePresets {
    return Intl.message(
      'Theme presets',
      name: 'themePresets',
      desc: '',
      args: [],
    );
  }

  /// `Drop`
  String get presetEmerald {
    return Intl.message('Drop', name: 'presetEmerald', desc: '', args: []);
  }

  /// `Frost`
  String get presetFrost {
    return Intl.message('Frost', name: 'presetFrost', desc: '', args: []);
  }

  /// `Amethyst`
  String get presetAmethyst {
    return Intl.message('Amethyst', name: 'presetAmethyst', desc: '', args: []);
  }

  /// `Crimson`
  String get presetCrimson {
    return Intl.message('Crimson', name: 'presetCrimson', desc: '', args: []);
  }

  /// `Magma`
  String get presetMagma {
    return Intl.message('Magma', name: 'presetMagma', desc: '', args: []);
  }

  /// `Amber`
  String get presetAmber {
    return Intl.message('Amber', name: 'presetAmber', desc: '', args: []);
  }

  /// `Stealth`
  String get presetStealth {
    return Intl.message('Stealth', name: 'presetStealth', desc: '', args: []);
  }

  /// `Background orbs`
  String get backgroundOrbs {
    return Intl.message(
      'Background orbs',
      name: 'backgroundOrbs',
      desc: '',
      args: [],
    );
  }

  /// `Top orbs`
  String get orbOne {
    return Intl.message('Top orbs', name: 'orbOne', desc: '', args: []);
  }

  /// `Bottom orb`
  String get orbTwo {
    return Intl.message('Bottom orb', name: 'orbTwo', desc: '', args: []);
  }

  /// `Blur`
  String get orbBlur {
    return Intl.message('Blur', name: 'orbBlur', desc: '', args: []);
  }

  /// `Auto (follows accent)`
  String get autoFollowAccent {
    return Intl.message(
      'Auto (follows accent)',
      name: 'autoFollowAccent',
      desc: '',
      args: [],
    );
  }

  /// `Preview`
  String get preview {
    return Intl.message('Preview', name: 'preview', desc: '', args: []);
  }

  /// `Auto`
  String get auto {
    return Intl.message('Auto', name: 'auto', desc: '', args: []);
  }

  /// `Light`
  String get light {
    return Intl.message('Light', name: 'light', desc: '', args: []);
  }

  /// `Dark`
  String get dark {
    return Intl.message('Dark', name: 'dark', desc: '', args: []);
  }

  /// `Import from URL`
  String get importFromURL {
    return Intl.message(
      'Import from URL',
      name: 'importFromURL',
      desc: '',
      args: [],
    );
  }

  /// `Submit`
  String get submit {
    return Intl.message('Submit', name: 'submit', desc: '', args: []);
  }

  /// `Adding profile from`
  String get doYouWantToPass {
    return Intl.message(
      'Adding profile from',
      name: 'doYouWantToPass',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get create {
    return Intl.message('Create', name: 'create', desc: '', args: []);
  }

  /// `Please upload a valid QR code`
  String get pleaseUploadValidQrcode {
    return Intl.message(
      'Please upload a valid QR code',
      name: 'pleaseUploadValidQrcode',
      desc: '',
      args: [],
    );
  }

  /// `Blacklist mode`
  String get blacklistMode {
    return Intl.message(
      'Blacklist mode',
      name: 'blacklistMode',
      desc: '',
      args: [],
    );
  }

  /// `Whitelist mode`
  String get whitelistMode {
    return Intl.message(
      'Whitelist mode',
      name: 'whitelistMode',
      desc: '',
      args: [],
    );
  }

  /// `Select all`
  String get selectAll {
    return Intl.message('Select all', name: 'selectAll', desc: '', args: []);
  }

  /// `Cancel select all`
  String get cancelSelectAll {
    return Intl.message(
      'Cancel select all',
      name: 'cancelSelectAll',
      desc: '',
      args: [],
    );
  }

  /// `App access control`
  String get appAccessControl {
    return Intl.message(
      'App access control',
      name: 'appAccessControl',
      desc: '',
      args: [],
    );
  }

  /// `Only allow selected app to enter VPN`
  String get accessControlAllowDesc {
    return Intl.message(
      'Only allow selected app to enter VPN',
      name: 'accessControlAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `The selected application will be excluded from VPN`
  String get accessControlNotAllowDesc {
    return Intl.message(
      'The selected application will be excluded from VPN',
      name: 'accessControlNotAllowDesc',
      desc: '',
      args: [],
    );
  }

  /// `Selected`
  String get selected {
    return Intl.message('Selected', name: 'selected', desc: '', args: []);
  }

  /// `Port`
  String get port {
    return Intl.message('Port', name: 'port', desc: '', args: []);
  }

  /// `LogLevel`
  String get logLevel {
    return Intl.message('LogLevel', name: 'logLevel', desc: '', args: []);
  }

  /// `Show`
  String get show {
    return Intl.message('Show', name: 'show', desc: '', args: []);
  }

  /// `Restart`
  String get restart {
    return Intl.message('Restart', name: 'restart', desc: '', args: []);
  }

  /// `Exit`
  String get exit {
    return Intl.message('Exit', name: 'exit', desc: '', args: []);
  }

  /// `System proxy`
  String get systemProxy {
    return Intl.message(
      'System proxy',
      name: 'systemProxy',
      desc: '',
      args: [],
    );
  }

  /// `Project`
  String get project {
    return Intl.message('Project', name: 'project', desc: '', args: []);
  }

  /// `Support the project`
  String get supportProject {
    return Intl.message(
      'Support the project',
      name: 'supportProject',
      desc: '',
      args: [],
    );
  }

  /// `Core`
  String get core {
    return Intl.message('Core', name: 'core', desc: '', args: []);
  }

  /// `Tab animation`
  String get tabAnimation {
    return Intl.message(
      'Tab animation',
      name: 'tabAnimation',
      desc: '',
      args: [],
    );
  }

  /// `dropweb — fast, simple VPN client. Open-source and ad-free.`
  String get desc {
    return Intl.message(
      'dropweb — fast, simple VPN client. Open-source and ad-free.',
      name: 'desc',
      desc: '',
      args: [],
    );
  }

  /// `Starting VPN...`
  String get startVpn {
    return Intl.message(
      'Starting VPN...',
      name: 'startVpn',
      desc: '',
      args: [],
    );
  }

  /// `Stopping VPN...`
  String get stopVpn {
    return Intl.message('Stopping VPN...', name: 'stopVpn', desc: '', args: []);
  }

  /// `Discovery a new version`
  String get discovery {
    return Intl.message(
      'Discovery a new version',
      name: 'discovery',
      desc: '',
      args: [],
    );
  }

  /// `Compatibility mode`
  String get compatible {
    return Intl.message(
      'Compatibility mode',
      name: 'compatible',
      desc: '',
      args: [],
    );
  }

  /// `tip`
  String get tip {
    return Intl.message('tip', name: 'tip', desc: '', args: []);
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Bind`
  String get bind {
    return Intl.message('Bind', name: 'bind', desc: '', args: []);
  }

  /// `Connectivity：`
  String get connectivity {
    return Intl.message(
      'Connectivity：',
      name: 'connectivity',
      desc: '',
      args: [],
    );
  }

  /// `Address`
  String get address {
    return Intl.message('Address', name: 'address', desc: '', args: []);
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Check for updates`
  String get checkUpdate {
    return Intl.message(
      'Check for updates',
      name: 'checkUpdate',
      desc: '',
      args: [],
    );
  }

  /// `New version`
  String get discoverNewVersion {
    return Intl.message(
      'New version',
      name: 'discoverNewVersion',
      desc: '',
      args: [],
    );
  }

  /// `The current application is already the latest version`
  String get checkUpdateError {
    return Intl.message(
      'The current application is already the latest version',
      name: 'checkUpdateError',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't check for updates`
  String get checkUpdateFailed {
    return Intl.message(
      'Couldn\'t check for updates',
      name: 'checkUpdateFailed',
      desc: '',
      args: [],
    );
  }

  /// `Go to download`
  String get goDownload {
    return Intl.message(
      'Go to download',
      name: 'goDownload',
      desc: '',
      args: [],
    );
  }

  /// `Downloading…`
  String get updateDownloading {
    return Intl.message(
      'Downloading…',
      name: 'updateDownloading',
      desc: '',
      args: [],
    );
  }

  /// `Verifying…`
  String get updateVerifying {
    return Intl.message(
      'Verifying…',
      name: 'updateVerifying',
      desc: '',
      args: [],
    );
  }

  /// `Install`
  String get updateInstall {
    return Intl.message('Install', name: 'updateInstall', desc: '', args: []);
  }

  /// `Later`
  String get updateLater {
    return Intl.message('Later', name: 'updateLater', desc: '', args: []);
  }

  /// `Cancel`
  String get updateCancel {
    return Intl.message('Cancel', name: 'updateCancel', desc: '', args: []);
  }

  /// `Update failed`
  String get updateFailed {
    return Intl.message(
      'Update failed',
      name: 'updateFailed',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get updateRetry {
    return Intl.message('Retry', name: 'updateRetry', desc: '', args: []);
  }

  /// `This update is recommended`
  String get updateMandatoryNote {
    return Intl.message(
      'This update is recommended',
      name: 'updateMandatoryNote',
      desc: '',
      args: [],
    );
  }

  /// `Unknown`
  String get unknown {
    return Intl.message('Unknown', name: 'unknown', desc: '', args: []);
  }

  /// `Checking...`
  String get checking {
    return Intl.message('Checking...', name: 'checking', desc: '', args: []);
  }

  /// `Country`
  String get country {
    return Intl.message('Country', name: 'country', desc: '', args: []);
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Allow applications to bypass VPN`
  String get allowBypass {
    return Intl.message(
      'Allow applications to bypass VPN',
      name: 'allowBypass',
      desc: '',
      args: [],
    );
  }

  /// `Some apps can bypass VPN when turned on`
  String get allowBypassDesc {
    return Intl.message(
      'Some apps can bypass VPN when turned on',
      name: 'allowBypassDesc',
      desc: '',
      args: [],
    );
  }

  /// `ExternalController`
  String get externalController {
    return Intl.message(
      'ExternalController',
      name: 'externalController',
      desc: '',
      args: [],
    );
  }

  /// `Once enabled, the VPN core can be controlled on port 9090`
  String get externalControllerDesc {
    return Intl.message(
      'Once enabled, the VPN core can be controlled on port 9090',
      name: 'externalControllerDesc',
      desc: '',
      args: [],
    );
  }

  /// `When turned on it will be able to receive IPv6 traffic`
  String get ipv6Desc {
    return Intl.message(
      'When turned on it will be able to receive IPv6 traffic',
      name: 'ipv6Desc',
      desc: '',
      args: [],
    );
  }

  /// `App`
  String get app {
    return Intl.message('App', name: 'app', desc: '', args: []);
  }

  /// `General`
  String get general {
    return Intl.message('General', name: 'general', desc: '', args: []);
  }

  /// `Attach HTTP proxy to VpnService`
  String get systemProxyDesc {
    return Intl.message(
      'Attach HTTP proxy to VpnService',
      name: 'systemProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Unified delay`
  String get unifiedDelay {
    return Intl.message(
      'Unified delay',
      name: 'unifiedDelay',
      desc: '',
      args: [],
    );
  }

  /// `Remove extra delays such as handshaking`
  String get unifiedDelayDesc {
    return Intl.message(
      'Remove extra delays such as handshaking',
      name: 'unifiedDelayDesc',
      desc: '',
      args: [],
    );
  }

  /// `TCP concurrent`
  String get tcpConcurrent {
    return Intl.message(
      'TCP concurrent',
      name: 'tcpConcurrent',
      desc: '',
      args: [],
    );
  }

  /// `Enabling it will allow TCP concurrency`
  String get tcpConcurrentDesc {
    return Intl.message(
      'Enabling it will allow TCP concurrency',
      name: 'tcpConcurrentDesc',
      desc: '',
      args: [],
    );
  }

  /// `Geo Low Memory Mode`
  String get geodataLoader {
    return Intl.message(
      'Geo Low Memory Mode',
      name: 'geodataLoader',
      desc: '',
      args: [],
    );
  }

  /// `Enabling will use the Geo low memory loader`
  String get geodataLoaderDesc {
    return Intl.message(
      'Enabling will use the Geo low memory loader',
      name: 'geodataLoaderDesc',
      desc: '',
      args: [],
    );
  }

  /// `Requests`
  String get requests {
    return Intl.message('Requests', name: 'requests', desc: '', args: []);
  }

  /// `Find process`
  String get findProcessMode {
    return Intl.message(
      'Find process',
      name: 'findProcessMode',
      desc: '',
      args: [],
    );
  }

  /// `Init`
  String get init {
    return Intl.message('Init', name: 'init', desc: '', args: []);
  }

  /// `Connections`
  String get connections {
    return Intl.message('Connections', name: 'connections', desc: '', args: []);
  }

  /// `Intranet IP`
  String get intranetIP {
    return Intl.message('Intranet IP', name: 'intranetIP', desc: '', args: []);
  }

  /// `View`
  String get view {
    return Intl.message('View', name: 'view', desc: '', args: []);
  }

  /// `Cut`
  String get cut {
    return Intl.message('Cut', name: 'cut', desc: '', args: []);
  }

  /// `Copy`
  String get copy {
    return Intl.message('Copy', name: 'copy', desc: '', args: []);
  }

  /// `Paste`
  String get paste {
    return Intl.message('Paste', name: 'paste', desc: '', args: []);
  }

  /// `Test url`
  String get testUrl {
    return Intl.message('Test url', name: 'testUrl', desc: '', args: []);
  }

  /// `Sync`
  String get sync {
    return Intl.message('Sync', name: 'sync', desc: '', args: []);
  }

  /// `Hidden from recent tasks`
  String get exclude {
    return Intl.message(
      'Hidden from recent tasks',
      name: 'exclude',
      desc: '',
      args: [],
    );
  }

  /// `When the app is in the background, the app is hidden from the recent task`
  String get excludeDesc {
    return Intl.message(
      'When the app is in the background, the app is hidden from the recent task',
      name: 'excludeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Standard`
  String get expand {
    return Intl.message('Standard', name: 'expand', desc: '', args: []);
  }

  /// `Shrink`
  String get shrink {
    return Intl.message('Shrink', name: 'shrink', desc: '', args: []);
  }

  /// `Min`
  String get min {
    return Intl.message('Min', name: 'min', desc: '', args: []);
  }

  /// `Oneline`
  String get oneline {
    return Intl.message('Oneline', name: 'oneline', desc: '', args: []);
  }

  /// `Tab`
  String get tab {
    return Intl.message('Tab', name: 'tab', desc: '', args: []);
  }

  /// `List`
  String get list {
    return Intl.message('List', name: 'list', desc: '', args: []);
  }

  /// `Delay`
  String get delay {
    return Intl.message('Delay', name: 'delay', desc: '', args: []);
  }

  /// `Style`
  String get style {
    return Intl.message('Style', name: 'style', desc: '', args: []);
  }

  /// `Size`
  String get size {
    return Intl.message('Size', name: 'size', desc: '', args: []);
  }

  /// `Sort`
  String get sort {
    return Intl.message('Sort', name: 'sort', desc: '', args: []);
  }

  /// `Columns`
  String get columns {
    return Intl.message('Columns', name: 'columns', desc: '', args: []);
  }

  /// `Proxies setting`
  String get proxiesSetting {
    return Intl.message(
      'Proxies setting',
      name: 'proxiesSetting',
      desc: '',
      args: [],
    );
  }

  /// `Go`
  String get go {
    return Intl.message('Go', name: 'go', desc: '', args: []);
  }

  /// `External link`
  String get externalLink {
    return Intl.message(
      'External link',
      name: 'externalLink',
      desc: '',
      args: [],
    );
  }

  /// `Auto close connections`
  String get autoCloseConnections {
    return Intl.message(
      'Auto close connections',
      name: 'autoCloseConnections',
      desc: '',
      args: [],
    );
  }

  /// `Auto close connections after change node`
  String get autoCloseConnectionsDesc {
    return Intl.message(
      'Auto close connections after change node',
      name: 'autoCloseConnectionsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Count only proxy traffic`
  String get onlyStatisticsProxy {
    return Intl.message(
      'Count only proxy traffic',
      name: 'onlyStatisticsProxy',
      desc: '',
      args: [],
    );
  }

  /// `When turned on, only proxy traffic will be counted in statistics`
  String get onlyStatisticsProxyDesc {
    return Intl.message(
      'When turned on, only proxy traffic will be counted in statistics',
      name: 'onlyStatisticsProxyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Theme from subscription`
  String get subscriptionTheme {
    return Intl.message(
      'Theme from subscription',
      name: 'subscriptionTheme',
      desc: '',
      args: [],
    );
  }

  /// `Logo from subscription`
  String get subscriptionLogo {
    return Intl.message(
      'Logo from subscription',
      name: 'subscriptionLogo',
      desc: '',
      args: [],
    );
  }

  /// `Pure black mode`
  String get pureBlackMode {
    return Intl.message(
      'Pure black mode',
      name: 'pureBlackMode',
      desc: '',
      args: [],
    );
  }

  /// `Tcp keep alive interval`
  String get keepAliveIntervalDesc {
    return Intl.message(
      'Tcp keep alive interval',
      name: 'keepAliveIntervalDesc',
      desc: '',
      args: [],
    );
  }

  /// ` entries`
  String get entries {
    return Intl.message(' entries', name: 'entries', desc: '', args: []);
  }

  /// `Local`
  String get local {
    return Intl.message('Local', name: 'local', desc: '', args: []);
  }

  /// `Remote`
  String get remote {
    return Intl.message('Remote', name: 'remote', desc: '', args: []);
  }

  /// `Mode`
  String get mode {
    return Intl.message('Mode', name: 'mode', desc: '', args: []);
  }

  /// `Time`
  String get time {
    return Intl.message('Time', name: 'time', desc: '', args: []);
  }

  /// `Source`
  String get source {
    return Intl.message('Source', name: 'source', desc: '', args: []);
  }

  /// `Action`
  String get action {
    return Intl.message('Action', name: 'action', desc: '', args: []);
  }

  /// `Intelligent selection`
  String get intelligentSelected {
    return Intl.message(
      'Intelligent selection',
      name: 'intelligentSelected',
      desc: '',
      args: [],
    );
  }

  /// `Clipboard import`
  String get clipboardImport {
    return Intl.message(
      'Clipboard import',
      name: 'clipboardImport',
      desc: '',
      args: [],
    );
  }

  /// `Export clipboard`
  String get clipboardExport {
    return Intl.message(
      'Export clipboard',
      name: 'clipboardExport',
      desc: '',
      args: [],
    );
  }

  /// `Layout`
  String get layout {
    return Intl.message('Layout', name: 'layout', desc: '', args: []);
  }

  /// `Tight`
  String get tight {
    return Intl.message('Tight', name: 'tight', desc: '', args: []);
  }

  /// `Standard`
  String get standard {
    return Intl.message('Standard', name: 'standard', desc: '', args: []);
  }

  /// `Loose`
  String get loose {
    return Intl.message('Loose', name: 'loose', desc: '', args: []);
  }

  /// `Start`
  String get start {
    return Intl.message('Start', name: 'start', desc: '', args: []);
  }

  /// `Stop`
  String get stop {
    return Intl.message('Stop', name: 'stop', desc: '', args: []);
  }

  /// `Running`
  String get running {
    return Intl.message('Running', name: 'running', desc: '', args: []);
  }

  /// `Stopped`
  String get stopped {
    return Intl.message('Stopped', name: 'stopped', desc: '', args: []);
  }

  /// `Update DNS related settings`
  String get dnsDesc {
    return Intl.message(
      'Update DNS related settings',
      name: 'dnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Key`
  String get key {
    return Intl.message('Key', name: 'key', desc: '', args: []);
  }

  /// `Value`
  String get value {
    return Intl.message('Value', name: 'value', desc: '', args: []);
  }

  /// `Add Hosts`
  String get hostsDesc {
    return Intl.message('Add Hosts', name: 'hostsDesc', desc: '', args: []);
  }

  /// `Changes take effect after restarting the VPN`
  String get vpnTip {
    return Intl.message(
      'Changes take effect after restarting the VPN',
      name: 'vpnTip',
      desc: '',
      args: [],
    );
  }

  /// `Auto routes all system traffic through VpnService`
  String get vpnEnableDesc {
    return Intl.message(
      'Auto routes all system traffic through VpnService',
      name: 'vpnEnableDesc',
      desc: '',
      args: [],
    );
  }

  /// `Options`
  String get options {
    return Intl.message('Options', name: 'options', desc: '', args: []);
  }

  /// `Loopback unlock tool`
  String get loopback {
    return Intl.message(
      'Loopback unlock tool',
      name: 'loopback',
      desc: '',
      args: [],
    );
  }

  /// `Providers`
  String get providers {
    return Intl.message('Providers', name: 'providers', desc: '', args: []);
  }

  /// `Proxy providers`
  String get proxyProviders {
    return Intl.message(
      'Proxy providers',
      name: 'proxyProviders',
      desc: '',
      args: [],
    );
  }

  /// `Rule providers`
  String get ruleProviders {
    return Intl.message(
      'Rule providers',
      name: 'ruleProviders',
      desc: '',
      args: [],
    );
  }

  /// `Override Dns`
  String get overrideDns {
    return Intl.message(
      'Override Dns',
      name: 'overrideDns',
      desc: '',
      args: [],
    );
  }

  /// `Turning it on will override the DNS options in the profile`
  String get overrideDnsDesc {
    return Intl.message(
      'Turning it on will override the DNS options in the profile',
      name: 'overrideDnsDesc',
      desc: '',
      args: [],
    );
  }

  /// `Status`
  String get status {
    return Intl.message('Status', name: 'status', desc: '', args: []);
  }

  /// `System DNS will be used when turned off`
  String get statusDesc {
    return Intl.message(
      'System DNS will be used when turned off',
      name: 'statusDesc',
      desc: '',
      args: [],
    );
  }

  /// `Prioritize the use of DOH's http/3`
  String get preferH3Desc {
    return Intl.message(
      'Prioritize the use of DOH\'s http/3',
      name: 'preferH3Desc',
      desc: '',
      args: [],
    );
  }

  /// `Respect rules`
  String get respectRules {
    return Intl.message(
      'Respect rules',
      name: 'respectRules',
      desc: '',
      args: [],
    );
  }

  /// `DNS connection following rules, need to configure proxy-server-nameserver`
  String get respectRulesDesc {
    return Intl.message(
      'DNS connection following rules, need to configure proxy-server-nameserver',
      name: 'respectRulesDesc',
      desc: '',
      args: [],
    );
  }

  /// `DNS mode`
  String get dnsMode {
    return Intl.message('DNS mode', name: 'dnsMode', desc: '', args: []);
  }

  /// `Fakeip range`
  String get fakeipRange {
    return Intl.message(
      'Fakeip range',
      name: 'fakeipRange',
      desc: '',
      args: [],
    );
  }

  /// `Fakeip filter`
  String get fakeipFilter {
    return Intl.message(
      'Fakeip filter',
      name: 'fakeipFilter',
      desc: '',
      args: [],
    );
  }

  /// `Default nameserver`
  String get defaultNameserver {
    return Intl.message(
      'Default nameserver',
      name: 'defaultNameserver',
      desc: '',
      args: [],
    );
  }

  /// `For resolving DNS server`
  String get defaultNameserverDesc {
    return Intl.message(
      'For resolving DNS server',
      name: 'defaultNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver`
  String get nameserver {
    return Intl.message('Nameserver', name: 'nameserver', desc: '', args: []);
  }

  /// `For resolving domain`
  String get nameserverDesc {
    return Intl.message(
      'For resolving domain',
      name: 'nameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Use hosts`
  String get useHosts {
    return Intl.message('Use hosts', name: 'useHosts', desc: '', args: []);
  }

  /// `Use system hosts`
  String get useSystemHosts {
    return Intl.message(
      'Use system hosts',
      name: 'useSystemHosts',
      desc: '',
      args: [],
    );
  }

  /// `Nameserver policy`
  String get nameserverPolicy {
    return Intl.message(
      'Nameserver policy',
      name: 'nameserverPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Specify the corresponding nameserver policy`
  String get nameserverPolicyDesc {
    return Intl.message(
      'Specify the corresponding nameserver policy',
      name: 'nameserverPolicyDesc',
      desc: '',
      args: [],
    );
  }

  /// `Proxy nameserver`
  String get proxyNameserver {
    return Intl.message(
      'Proxy nameserver',
      name: 'proxyNameserver',
      desc: '',
      args: [],
    );
  }

  /// `Domain for resolving proxy nodes`
  String get proxyNameserverDesc {
    return Intl.message(
      'Domain for resolving proxy nodes',
      name: 'proxyNameserverDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fallback`
  String get fallback {
    return Intl.message('Fallback', name: 'fallback', desc: '', args: []);
  }

  /// `Generally use offshore DNS`
  String get fallbackDesc {
    return Intl.message(
      'Generally use offshore DNS',
      name: 'fallbackDesc',
      desc: '',
      args: [],
    );
  }

  /// `Fallback filter`
  String get fallbackFilter {
    return Intl.message(
      'Fallback filter',
      name: 'fallbackFilter',
      desc: '',
      args: [],
    );
  }

  /// `Geoip code`
  String get geoipCode {
    return Intl.message('Geoip code', name: 'geoipCode', desc: '', args: []);
  }

  /// `Ipcidr`
  String get ipcidr {
    return Intl.message('Ipcidr', name: 'ipcidr', desc: '', args: []);
  }

  /// `Domain`
  String get domain {
    return Intl.message('Domain', name: 'domain', desc: '', args: []);
  }

  /// `Reset`
  String get reset {
    return Intl.message('Reset', name: 'reset', desc: '', args: []);
  }

  /// `Agree`
  String get agree {
    return Intl.message('Agree', name: 'agree', desc: '', args: []);
  }

  /// `Remove`
  String get remove {
    return Intl.message('Remove', name: 'remove', desc: '', args: []);
  }

  /// `No network`
  String get noNetwork {
    return Intl.message('No network', name: 'noNetwork', desc: '', args: []);
  }

  /// `Allow IPv6 inbound`
  String get ipv6InboundDesc {
    return Intl.message(
      'Allow IPv6 inbound',
      name: 'ipv6InboundDesc',
      desc: '',
      args: [],
    );
  }

  /// `Export logs`
  String get exportLogs {
    return Intl.message('Export logs', name: 'exportLogs', desc: '', args: []);
  }

  /// `Icon style`
  String get iconStyle {
    return Intl.message('Icon style', name: 'iconStyle', desc: '', args: []);
  }

  /// `Stack mode`
  String get stackMode {
    return Intl.message('Stack mode', name: 'stackMode', desc: '', args: []);
  }

  /// `Network`
  String get network {
    return Intl.message('Network', name: 'network', desc: '', args: []);
  }

  /// `Modify network-related settings`
  String get networkDesc {
    return Intl.message(
      'Modify network-related settings',
      name: 'networkDesc',
      desc: '',
      args: [],
    );
  }

  /// `Bypass domain`
  String get bypassDomain {
    return Intl.message(
      'Bypass domain',
      name: 'bypassDomain',
      desc: '',
      args: [],
    );
  }

  /// `Only takes effect when the system proxy is enabled`
  String get bypassDomainDesc {
    return Intl.message(
      'Only takes effect when the system proxy is enabled',
      name: 'bypassDomainDesc',
      desc: '',
      args: [],
    );
  }

  /// `Make sure to reset`
  String get resetTip {
    return Intl.message(
      'Make sure to reset',
      name: 'resetTip',
      desc: '',
      args: [],
    );
  }

  /// `RegExp`
  String get regExp {
    return Intl.message('RegExp', name: 'regExp', desc: '', args: []);
  }

  /// `Icon`
  String get icon {
    return Intl.message('Icon', name: 'icon', desc: '', args: []);
  }

  /// `No data`
  String get noData {
    return Intl.message('No data', name: 'noData', desc: '', args: []);
  }

  /// `FontFamily`
  String get fontFamily {
    return Intl.message('FontFamily', name: 'fontFamily', desc: '', args: []);
  }

  /// `Toggle`
  String get toggle {
    return Intl.message('Toggle', name: 'toggle', desc: '', args: []);
  }

  /// `System`
  String get system {
    return Intl.message('System', name: 'system', desc: '', args: []);
  }

  /// `Route mode`
  String get routeMode {
    return Intl.message('Route mode', name: 'routeMode', desc: '', args: []);
  }

  /// `Bypass private route address`
  String get routeMode_bypassPrivate {
    return Intl.message(
      'Bypass private route address',
      name: 'routeMode_bypassPrivate',
      desc: '',
      args: [],
    );
  }

  /// `Use config`
  String get routeMode_config {
    return Intl.message(
      'Use config',
      name: 'routeMode_config',
      desc: '',
      args: [],
    );
  }

  /// `Route address`
  String get routeAddress {
    return Intl.message(
      'Route address',
      name: 'routeAddress',
      desc: '',
      args: [],
    );
  }

  /// `Config listen route address`
  String get routeAddressDesc {
    return Intl.message(
      'Config listen route address',
      name: 'routeAddressDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the admin password`
  String get pleaseInputAdminPassword {
    return Intl.message(
      'Please enter the admin password',
      name: 'pleaseInputAdminPassword',
      desc: '',
      args: [],
    );
  }

  /// `Memory info`
  String get memoryInfo {
    return Intl.message('Memory info', name: 'memoryInfo', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Copy success`
  String get copySuccess {
    return Intl.message(
      'Copy success',
      name: 'copySuccess',
      desc: '',
      args: [],
    );
  }

  /// `The cache is corrupt. Do you want to clear it?`
  String get cacheCorrupt {
    return Intl.message(
      'The cache is corrupt. Do you want to clear it?',
      name: 'cacheCorrupt',
      desc: '',
      args: [],
    );
  }

  /// `Relying on third-party api is for reference only`
  String get detectionTip {
    return Intl.message(
      'Relying on third-party api is for reference only',
      name: 'detectionTip',
      desc: '',
      args: [],
    );
  }

  /// `Please wait 15 seconds before refreshing again`
  String get tooFrequentOperation {
    return Intl.message(
      'Please wait 15 seconds before refreshing again',
      name: 'tooFrequentOperation',
      desc: '',
      args: [],
    );
  }

  /// `Listen`
  String get listen {
    return Intl.message('Listen', name: 'listen', desc: '', args: []);
  }

  /// `undo`
  String get undo {
    return Intl.message('undo', name: 'undo', desc: '', args: []);
  }

  /// `redo`
  String get redo {
    return Intl.message('redo', name: 'redo', desc: '', args: []);
  }

  /// `none`
  String get none {
    return Intl.message('none', name: 'none', desc: '', args: []);
  }

  /// `Basic configuration`
  String get basicConfig {
    return Intl.message(
      'Basic configuration',
      name: 'basicConfig',
      desc: '',
      args: [],
    );
  }

  /// `{count} items have been selected`
  String selectedCountTitle(Object count) {
    return Intl.message(
      '$count items have been selected',
      name: 'selectedCountTitle',
      desc: '',
      args: [count],
    );
  }

  /// `Add rule`
  String get addRule {
    return Intl.message('Add rule', name: 'addRule', desc: '', args: []);
  }

  /// `Rule name`
  String get ruleName {
    return Intl.message('Rule name', name: 'ruleName', desc: '', args: []);
  }

  /// `Content`
  String get content {
    return Intl.message('Content', name: 'content', desc: '', args: []);
  }

  /// `Sub rule`
  String get subRule {
    return Intl.message('Sub rule', name: 'subRule', desc: '', args: []);
  }

  /// `Rule target`
  String get ruleTarget {
    return Intl.message('Rule target', name: 'ruleTarget', desc: '', args: []);
  }

  /// `Source IP`
  String get sourceIp {
    return Intl.message('Source IP', name: 'sourceIp', desc: '', args: []);
  }

  /// `No resolve IP`
  String get noResolve {
    return Intl.message('No resolve IP', name: 'noResolve', desc: '', args: []);
  }

  /// `Modify general settings`
  String get generalDesc {
    return Intl.message(
      'Modify general settings',
      name: 'generalDesc',
      desc: '',
      args: [],
    );
  }

  /// `Effective only in mobile view`
  String get tabAnimationDesc {
    return Intl.message(
      'Effective only in mobile view',
      name: 'tabAnimationDesc',
      desc: '',
      args: [],
    );
  }

  /// `Color schemes`
  String get colorSchemes {
    return Intl.message(
      'Color schemes',
      name: 'colorSchemes',
      desc: '',
      args: [],
    );
  }

  /// `Calm`
  String get schemeCalm {
    return Intl.message('Calm', name: 'schemeCalm', desc: '', args: []);
  }

  /// `Bright`
  String get schemeBright {
    return Intl.message('Bright', name: 'schemeBright', desc: '', args: []);
  }

  /// `Mono`
  String get schemeMono {
    return Intl.message('Mono', name: 'schemeMono', desc: '', args: []);
  }

  /// `Neutral`
  String get schemeNeutral {
    return Intl.message('Neutral', name: 'schemeNeutral', desc: '', args: []);
  }

  /// `Expressive`
  String get schemeExpressive {
    return Intl.message(
      'Expressive',
      name: 'schemeExpressive',
      desc: '',
      args: [],
    );
  }

  /// `Palette`
  String get palette {
    return Intl.message('Palette', name: 'palette', desc: '', args: []);
  }

  /// `Developer mode`
  String get developerMode {
    return Intl.message(
      'Developer mode',
      name: 'developerMode',
      desc: '',
      args: [],
    );
  }

  /// `Developer mode is enabled.`
  String get developerModeEnableTip {
    return Intl.message(
      'Developer mode is enabled.',
      name: 'developerModeEnableTip',
      desc: '',
      args: [],
    );
  }

  /// `Crash test`
  String get crashTest {
    return Intl.message('Crash test', name: 'crashTest', desc: '', args: []);
  }

  /// `Clear Data`
  String get clearData {
    return Intl.message('Clear Data', name: 'clearData', desc: '', args: []);
  }

  /// `This will delete all app data and restart the application. Are you sure?`
  String get clearDataTip {
    return Intl.message(
      'This will delete all app data and restart the application. Are you sure?',
      name: 'clearDataTip',
      desc: '',
      args: [],
    );
  }

  /// `Text Scaling`
  String get textScale {
    return Intl.message('Text Scaling', name: 'textScale', desc: '', args: []);
  }

  /// `Internet`
  String get internet {
    return Intl.message('Internet', name: 'internet', desc: '', args: []);
  }

  /// `System APP`
  String get systemApp {
    return Intl.message('System APP', name: 'systemApp', desc: '', args: []);
  }

  /// `No network APP`
  String get noNetworkApp {
    return Intl.message(
      'No network APP',
      name: 'noNetworkApp',
      desc: '',
      args: [],
    );
  }

  /// `{label} cannot be empty`
  String emptyTip(Object label) {
    return Intl.message(
      '$label cannot be empty',
      name: 'emptyTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a url`
  String urlTip(Object label) {
    return Intl.message(
      '$label must be a url',
      name: 'urlTip',
      desc: '',
      args: [label],
    );
  }

  /// `{label} must be a number`
  String numberTip(Object label) {
    return Intl.message(
      '$label must be a number',
      name: 'numberTip',
      desc: '',
      args: [label],
    );
  }

  /// `Interval`
  String get interval {
    return Intl.message('Interval', name: 'interval', desc: '', args: []);
  }

  /// `Current {label} already exists`
  String existsTip(Object label) {
    return Intl.message(
      'Current $label already exists',
      name: 'existsTip',
      desc: '',
      args: [label],
    );
  }

  /// `Are you sure you want to delete the current {label}?`
  String deleteTip(Object label) {
    return Intl.message(
      'Are you sure you want to delete the current $label?',
      name: 'deleteTip',
      desc: '',
      args: [label],
    );
  }

  /// `Script`
  String get script {
    return Intl.message('Script', name: 'script', desc: '', args: []);
  }

  /// `Color`
  String get color {
    return Intl.message('Color', name: 'color', desc: '', args: []);
  }

  /// `Rename`
  String get rename {
    return Intl.message('Rename', name: 'rename', desc: '', args: []);
  }

  /// `Unnamed`
  String get unnamed {
    return Intl.message('Unnamed', name: 'unnamed', desc: '', args: []);
  }

  /// `Mixed Port`
  String get mixedPort {
    return Intl.message('Mixed Port', name: 'mixedPort', desc: '', args: []);
  }

  /// `Socks Port`
  String get socksPort {
    return Intl.message('Socks Port', name: 'socksPort', desc: '', args: []);
  }

  /// `Redir Port`
  String get redirPort {
    return Intl.message('Redir Port', name: 'redirPort', desc: '', args: []);
  }

  /// `Tproxy Port`
  String get tproxyPort {
    return Intl.message('Tproxy Port', name: 'tproxyPort', desc: '', args: []);
  }

  /// `{label} must be between 1024 and 49151`
  String portTip(Object label) {
    return Intl.message(
      '$label must be between 1024 and 49151',
      name: 'portTip',
      desc: '',
      args: [label],
    );
  }

  /// `Please enter a different port`
  String get portConflictTip {
    return Intl.message(
      'Please enter a different port',
      name: 'portConflictTip',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get import {
    return Intl.message('Import', name: 'import', desc: '', args: []);
  }

  /// `Import from URL`
  String get importUrl {
    return Intl.message(
      'Import from URL',
      name: 'importUrl',
      desc: '',
      args: [],
    );
  }

  /// `Auto set system DNS`
  String get autoSetSystemDns {
    return Intl.message(
      'Auto set system DNS',
      name: 'autoSetSystemDns',
      desc: '',
      args: [],
    );
  }

  /// `Change Server`
  String get changeServer {
    return Intl.message(
      'Change Server',
      name: 'changeServer',
      desc: '',
      args: [],
    );
  }

  /// `Add Profile`
  String get addProfile {
    return Intl.message('Add Profile', name: 'addProfile', desc: '', args: []);
  }

  /// `Starting VPN core…`
  String get startingVpnCore {
    return Intl.message(
      'Starting VPN core…',
      name: 'startingVpnCore',
      desc: '',
      args: [],
    );
  }

  /// `Traffic`
  String get traffic {
    return Intl.message('Traffic', name: 'traffic', desc: '', args: []);
  }

  /// `Unlimited Traffic`
  String get trafficUnlimited {
    return Intl.message(
      'Unlimited Traffic',
      name: 'trafficUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `All traffic through VPN`
  String get fullTunnelTitle {
    return Intl.message(
      'All traffic through VPN',
      name: 'fullTunnelTitle',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't detect the route`
  String get routeUndetected {
    return Intl.message(
      'Couldn\'t detect the route',
      name: 'routeUndetected',
      desc: '',
      args: [],
    );
  }

  /// `Loading…`
  String get loadingEllipsis {
    return Intl.message(
      'Loading…',
      name: 'loadingEllipsis',
      desc: '',
      args: [],
    );
  }

  /// `until {date}`
  String validUntil(Object date) {
    return Intl.message(
      'until $date',
      name: 'validUntil',
      desc: '',
      args: [date],
    );
  }

  /// `Cabinet`
  String get cabinet {
    return Intl.message('Cabinet', name: 'cabinet', desc: '', args: []);
  }

  /// `Lifetime Subscription`
  String get subscriptionEternal {
    return Intl.message(
      'Lifetime Subscription',
      name: 'subscriptionEternal',
      desc: '',
      args: [],
    );
  }

  /// `Expires on`
  String get expiresOn {
    return Intl.message('Expires on', name: 'expiresOn', desc: '', args: []);
  }

  /// `Remaining`
  String get remaining {
    return Intl.message('Remaining', name: 'remaining', desc: '', args: []);
  }

  /// `Remaining`
  String get remainingSingular {
    return Intl.message(
      'Remaining',
      name: 'remainingSingular',
      desc: '',
      args: [],
    );
  }

  /// `Remaining`
  String get remainingPlural {
    return Intl.message(
      'Remaining',
      name: 'remainingPlural',
      desc: '',
      args: [],
    );
  }

  /// `QR code not found`
  String get qrNotFound {
    return Intl.message(
      'QR code not found',
      name: 'qrNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Camera permission denied`
  String get cameraPermissionDenied {
    return Intl.message(
      'Camera permission denied',
      name: 'cameraPermissionDenied',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get errorTitle {
    return Intl.message('Error', name: 'errorTitle', desc: '', args: []);
  }

  /// `Copy logs`
  String get copyLogs {
    return Intl.message('Copy logs', name: 'copyLogs', desc: '', args: []);
  }

  /// `Logs copied`
  String get logsCopied {
    return Intl.message('Logs copied', name: 'logsCopied', desc: '', args: []);
  }

  /// `Add from Phone`
  String get addFromPhoneTitle {
    return Intl.message(
      'Add from Phone',
      name: 'addFromPhoneTitle',
      desc: '',
      args: [],
    );
  }

  /// `Scan QR code with phone`
  String get addFromPhoneSubtitle {
    return Intl.message(
      'Scan QR code with phone',
      name: 'addFromPhoneSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Paste`
  String get pasteFromClipboard {
    return Intl.message(
      'Paste',
      name: 'pasteFromClipboard',
      desc: '',
      args: [],
    );
  }

  /// `Lifetime Subscription`
  String get subscriptionUnlimited {
    return Intl.message(
      'Lifetime Subscription',
      name: 'subscriptionUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `Updated`
  String get updated {
    return Intl.message('Updated', name: 'updated', desc: '', args: []);
  }

  /// `Select Profile`
  String get selectProfile {
    return Intl.message(
      'Select Profile',
      name: 'selectProfile',
      desc: '',
      args: [],
    );
  }

  /// `Support`
  String get support {
    return Intl.message('Support', name: 'support', desc: '', args: []);
  }

  /// `Free up a device slot`
  String get hwidFreeSlot {
    return Intl.message(
      'Free up a device slot',
      name: 'hwidFreeSlot',
      desc: '',
      args: [],
    );
  }

  /// `Device registered\nSubscription updated`
  String get hwidRecovered {
    return Intl.message(
      'Device registered\nSubscription updated',
      name: 'hwidRecovered',
      desc: '',
      args: [],
    );
  }

  /// `Device limit reached\nFree up a slot with your provider and refresh`
  String get hwidLimitReached {
    return Intl.message(
      'Device limit reached\nFree up a slot with your provider and refresh',
      name: 'hwidLimitReached',
      desc: '',
      args: [],
    );
  }

  /// `Personal cabinet`
  String get personalCabinet {
    return Intl.message(
      'Personal cabinet',
      name: 'personalCabinet',
      desc: '',
      args: [],
    );
  }

  /// `MENU`
  String get menu {
    return Intl.message('MENU', name: 'menu', desc: '', args: []);
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Open logs folder`
  String get openLogsFolder {
    return Intl.message(
      'Open logs folder',
      name: 'openLogsFolder',
      desc: '',
      args: [],
    );
  }

  /// `Receive Subscription`
  String get receiveSubscriptionTitle {
    return Intl.message(
      'Receive Subscription',
      name: 'receiveSubscriptionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Send HWID`
  String get settingsSendDeviceDataTitle {
    return Intl.message(
      'Send HWID',
      name: 'settingsSendDeviceDataTitle',
      desc: '',
      args: [],
    );
  }

  /// `Send device identifier, app version and device name to proxy provider server`
  String get settingsSendDeviceDataSubtitle {
    return Intl.message(
      'Send device identifier, app version and device name to proxy provider server',
      name: 'settingsSendDeviceDataSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Your subscription expires in {days} day(s)`
  String subscriptionExpiresInDays(Object days) {
    return Intl.message(
      'Your subscription expires in $days day(s)',
      name: 'subscriptionExpiresInDays',
      desc: '',
      args: [days],
    );
  }

  /// `Your subscription expires today`
  String get subscriptionExpiresToday {
    return Intl.message(
      'Your subscription expires today',
      name: 'subscriptionExpiresToday',
      desc: '',
      args: [],
    );
  }

  /// `Your subscription has expired`
  String get subscriptionExpired {
    return Intl.message(
      'Your subscription has expired',
      name: 'subscriptionExpired',
      desc: '',
      args: [],
    );
  }

  /// `Renew`
  String get renew {
    return Intl.message('Renew', name: 'renew', desc: '', args: []);
  }

  /// `Top up traffic`
  String get topUpTraffic {
    return Intl.message(
      'Top up traffic',
      name: 'topUpTraffic',
      desc: '',
      args: [],
    );
  }

  /// `Privacy Policy`
  String get privacyPolicy {
    return Intl.message(
      'Privacy Policy',
      name: 'privacyPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Before you connect`
  String get vpnDisclosureTitle {
    return Intl.message(
      'Before you connect',
      name: 'vpnDisclosureTitle',
      desc: '',
      args: [],
    );
  }

  /// `dropweb uses Android's VPN permission to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device's VPN settings.`
  String get vpnDisclosureBody {
    return Intl.message(
      'dropweb uses Android\'s VPN permission to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers\' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device\'s VPN settings.',
      name: 'vpnDisclosureBody',
      desc: '',
      args: [],
    );
  }

  /// `dropweb adds a VPN configuration to your iPhone to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device's VPN settings.`
  String get vpnDisclosureBodyIos {
    return Intl.message(
      'dropweb adds a VPN configuration to your iPhone to create a VPN tunnel on your device. Your network traffic is sent through the servers listed in the subscription or configuration that you added yourself, and those servers\' operators handle it under their own policies. dropweb does not inspect, record or upload the contents of your traffic or the sites you visit, and it has no ads or analytics. When you add or refresh a subscription, its provider receives your IP address, a device identifier (HWID) and the device model. You can disconnect at any time from this screen or your device\'s VPN settings.',
      name: 'vpnDisclosureBodyIos',
      desc: '',
      args: [],
    );
  }

  /// `Continue`
  String get vpnDisclosureContinue {
    return Intl.message(
      'Continue',
      name: 'vpnDisclosureContinue',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get updateSubscription {
    return Intl.message(
      'Update',
      name: 'updateSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Country`
  String get workModeCountry {
    return Intl.message('Country', name: 'workModeCountry', desc: '', args: []);
  }

  /// `Auto`
  String get smartAuto {
    return Intl.message('Auto', name: 'smartAuto', desc: '', args: []);
  }

  /// `Servers & groups`
  String get serversAndGroups {
    return Intl.message(
      'Servers & groups',
      name: 'serversAndGroups',
      desc: '',
      args: [],
    );
  }

  /// `Mode reset to Standard: settings unavailable after subscription update.`
  String get workModeResetNotice {
    return Intl.message(
      'Mode reset to Standard: settings unavailable after subscription update.',
      name: 'workModeResetNotice',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get genericErrorMessage {
    return Intl.message(
      'Something went wrong',
      name: 'genericErrorMessage',
      desc: '',
      args: [],
    );
  }

  /// `QR scan from an image isn't supported`
  String get qrScanFromImageUnsupported {
    return Intl.message(
      'QR scan from an image isn\'t supported',
      name: 'qrScanFromImageUnsupported',
      desc: '',
      args: [],
    );
  }

  /// `Always-on`
  String get alwaysOnVpn {
    return Intl.message('Always-on', name: 'alwaysOnVpn', desc: '', args: []);
  }

  /// `Couldn't open VPN settings`
  String get alwaysOnVpnOpenFailed {
    return Intl.message(
      'Couldn\'t open VPN settings',
      name: 'alwaysOnVpnOpenFailed',
      desc: '',
      args: [],
    );
  }

  /// `Paste subscription from clipboard`
  String get onboardingClipboardImport {
    return Intl.message(
      'Paste subscription from clipboard',
      name: 'onboardingClipboardImport',
      desc: '',
      args: [],
    );
  }

  /// `Add {host}`
  String addNamedSubscription(Object host) {
    return Intl.message(
      'Add $host',
      name: 'addNamedSubscription',
      desc: '',
      args: [host],
    );
  }

  /// `Subscription added. Tap to connect`
  String get onboardingImported {
    return Intl.message(
      'Subscription added. Tap to connect',
      name: 'onboardingImported',
      desc: '',
      args: [],
    );
  }

  /// `Add a subscription`
  String get dashboardEmptyTitle {
    return Intl.message(
      'Add a subscription',
      name: 'dashboardEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `Paste a link or scan a QR code`
  String get dashboardEmptyHint {
    return Intl.message(
      'Paste a link or scan a QR code',
      name: 'dashboardEmptyHint',
      desc: '',
      args: [],
    );
  }

  /// `https://… — your provider's subscription link`
  String get importFromUrlHint {
    return Intl.message(
      'https://… — your provider\'s subscription link',
      name: 'importFromUrlHint',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics`
  String get devDiagnostics {
    return Intl.message(
      'Diagnostics',
      name: 'devDiagnostics',
      desc: '',
      args: [],
    );
  }

  /// `Capture diagnostics`
  String get devTakeDiagnostics {
    return Intl.message(
      'Capture diagnostics',
      name: 'devTakeDiagnostics',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostics: {path}`
  String devDiagnosticsWritten(Object path) {
    return Intl.message(
      'Diagnostics: $path',
      name: 'devDiagnosticsWritten',
      desc: '',
      args: [path],
    );
  }

  /// `Effective config`
  String get devEffectiveConfig {
    return Intl.message(
      'Effective config',
      name: 'devEffectiveConfig',
      desc: '',
      args: [],
    );
  }

  /// `The core has not been set up yet — no config`
  String get devEffectiveConfigEmpty {
    return Intl.message(
      'The core has not been set up yet — no config',
      name: 'devEffectiveConfigEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Subscription headers`
  String get devSubscriptionHeaders {
    return Intl.message(
      'Subscription headers',
      name: 'devSubscriptionHeaders',
      desc: '',
      args: [],
    );
  }

  /// `Copy all`
  String get devCopyAll {
    return Intl.message('Copy all', name: 'devCopyAll', desc: '', args: []);
  }

  /// `adb remote`
  String get devAdbRemote {
    return Intl.message('adb remote', name: 'devAdbRemote', desc: '', args: []);
  }

  /// `Replies: adb logcat -s dropweb-dbg`
  String get devAdbRemoteReplies {
    return Intl.message(
      'Replies: adb logcat -s dropweb-dbg',
      name: 'devAdbRemoteReplies',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with email`
  String get accountLoginByEmail {
    return Intl.message(
      'Sign in with email',
      name: 'accountLoginByEmail',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get accountEmailLabel {
    return Intl.message('Email', name: 'accountEmailLabel', desc: '', args: []);
  }

  /// `Check the email address`
  String get accountEmailInvalid {
    return Intl.message(
      'Check the email address',
      name: 'accountEmailInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Get code`
  String get accountGetCode {
    return Intl.message('Get code', name: 'accountGetCode', desc: '', args: []);
  }

  /// `Code`
  String get accountCodeLabel {
    return Intl.message('Code', name: 'accountCodeLabel', desc: '', args: []);
  }

  /// `Send again`
  String get accountResend {
    return Intl.message(
      'Send again',
      name: 'accountResend',
      desc: '',
      args: [],
    );
  }

  /// `Change email`
  String get accountChangeEmail {
    return Intl.message(
      'Change email',
      name: 'accountChangeEmail',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect code`
  String get accountErrorInvalidCode {
    return Intl.message(
      'Incorrect code',
      name: 'accountErrorInvalidCode',
      desc: '',
      args: [],
    );
  }

  /// `Code expired — request a new one`
  String get accountErrorCodeExpired {
    return Intl.message(
      'Code expired — request a new one',
      name: 'accountErrorCodeExpired',
      desc: '',
      args: [],
    );
  }

  /// `Too many attempts, wait {wait}`
  String accountErrorRateLimited(Object wait) {
    return Intl.message(
      'Too many attempts, wait $wait',
      name: 'accountErrorRateLimited',
      desc: '',
      args: [wait],
    );
  }

  /// `Too many attempts, try later`
  String get accountErrorRateLimitedLater {
    return Intl.message(
      'Too many attempts, try later',
      name: 'accountErrorRateLimitedLater',
      desc: '',
      args: [],
    );
  }

  /// `This email can't be used`
  String get accountErrorEmailRejected {
    return Intl.message(
      'This email can\'t be used',
      name: 'accountErrorEmailRejected',
      desc: '',
      args: [],
    );
  }

  /// `Can't reach the server`
  String get accountErrorNetwork {
    return Intl.message(
      'Can\'t reach the server',
      name: 'accountErrorNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Sign-in temporarily unavailable`
  String get accountErrorDisabled {
    return Intl.message(
      'Sign-in temporarily unavailable',
      name: 'accountErrorDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get accountErrorGeneric {
    return Intl.message(
      'Something went wrong',
      name: 'accountErrorGeneric',
      desc: '',
      args: [],
    );
  }

  /// `Subscription connected`
  String get accountSubscriptionImported {
    return Intl.message(
      'Subscription connected',
      name: 'accountSubscriptionImported',
      desc: '',
      args: [],
    );
  }

  /// `The subscription is already in the app`
  String get accountSubscriptionAlreadyPresent {
    return Intl.message(
      'The subscription is already in the app',
      name: 'accountSubscriptionAlreadyPresent',
      desc: '',
      args: [],
    );
  }

  /// `Signed in, no subscription yet`
  String get accountNoSubscription {
    return Intl.message(
      'Signed in, no subscription yet',
      name: 'accountNoSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Signed in, subscription not connected`
  String get accountSyncFailed {
    return Intl.message(
      'Signed in, subscription not connected',
      name: 'accountSyncFailed',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with your fingerprint?`
  String get accountBiometricOfferTitle {
    return Intl.message(
      'Sign in with your fingerprint?',
      name: 'accountBiometricOfferTitle',
      desc: '',
      args: [],
    );
  }

  /// `Your account will open with your fingerprint.`
  String get accountBiometricOfferText {
    return Intl.message(
      'Your account will open with your fingerprint.',
      name: 'accountBiometricOfferText',
      desc: '',
      args: [],
    );
  }

  /// `Turn on`
  String get accountBiometricEnable {
    return Intl.message(
      'Turn on',
      name: 'accountBiometricEnable',
      desc: '',
      args: [],
    );
  }

  /// `Confirm signing in to your account`
  String get accountBiometricUnlockReason {
    return Intl.message(
      'Confirm signing in to your account',
      name: 'accountBiometricUnlockReason',
      desc: '',
      args: [],
    );
  }

  /// `Confirm to sign in with your fingerprint`
  String get accountBiometricEnableReason {
    return Intl.message(
      'Confirm to sign in with your fingerprint',
      name: 'accountBiometricEnableReason',
      desc: '',
      args: [],
    );
  }

  /// `Fingerprint sign-in`
  String get accountBiometricSwitch {
    return Intl.message(
      'Fingerprint sign-in',
      name: 'accountBiometricSwitch',
      desc: '',
      args: [],
    );
  }

  /// `Update subscription`
  String get accountSyncSubscription {
    return Intl.message(
      'Update subscription',
      name: 'accountSyncSubscription',
      desc: '',
      args: [],
    );
  }

  /// `Sign out`
  String get accountLogout {
    return Intl.message('Sign out', name: 'accountLogout', desc: '', args: []);
  }

  /// `Signed out`
  String get accountLoggedOut {
    return Intl.message(
      'Signed out',
      name: 'accountLoggedOut',
      desc: '',
      args: [],
    );
  }

  /// `Remove from this device`
  String get accountRemoveFromDevice {
    return Intl.message(
      'Remove from this device',
      name: 'accountRemoveFromDevice',
      desc: '',
      args: [],
    );
  }

  /// `Remove from this device?`
  String get accountRemoveFromDeviceTitle {
    return Intl.message(
      'Remove from this device?',
      name: 'accountRemoveFromDeviceTitle',
      desc: '',
      args: [],
    );
  }

  /// `The account and its subscription will disappear from this device. You can sign in again with your email.`
  String get accountRemoveFromDeviceText {
    return Intl.message(
      'The account and its subscription will disappear from this device. You can sign in again with your email.',
      name: 'accountRemoveFromDeviceText',
      desc: '',
      args: [],
    );
  }

  /// `Removed from this device`
  String get accountRemovedFromDevice {
    return Intl.message(
      'Removed from this device',
      name: 'accountRemovedFromDevice',
      desc: '',
      args: [],
    );
  }

  /// `Unlock`
  String get accountUnlock {
    return Intl.message('Unlock', name: 'accountUnlock', desc: '', args: []);
  }

  /// `Sign in with a code`
  String get accountSignInWithCode {
    return Intl.message(
      'Sign in with a code',
      name: 'accountSignInWithCode',
      desc: '',
      args: [],
    );
  }

  /// `{n} s`
  String accountWaitSeconds(Object n) {
    return Intl.message(
      '$n s',
      name: 'accountWaitSeconds',
      desc: '',
      args: [n],
    );
  }

  /// `{n} min`
  String accountWaitMinutes(Object n) {
    return Intl.message(
      '$n min',
      name: 'accountWaitMinutes',
      desc: '',
      args: [n],
    );
  }

  /// `{n} h`
  String accountWaitHours(Object n) {
    return Intl.message('$n h', name: 'accountWaitHours', desc: '', args: [n]);
  }

  /// `IP address`
  String get m3eStatIp {
    return Intl.message('IP address', name: 'm3eStatIp', desc: '', args: []);
  }

  /// `Country`
  String get m3eStatCountry {
    return Intl.message('Country', name: 'm3eStatCountry', desc: '', args: []);
  }

  /// `Traffic`
  String get m3eStatTraffic {
    return Intl.message('Traffic', name: 'm3eStatTraffic', desc: '', args: []);
  }

  /// `Ping`
  String get m3eStatPing {
    return Intl.message('Ping', name: 'm3eStatPing', desc: '', args: []);
  }

  /// `—`
  String get m3eStatNone {
    return Intl.message('—', name: 'm3eStatNone', desc: '', args: []);
  }

  /// `{value} GB`
  String m3eValueGb(Object value) {
    return Intl.message(
      '$value GB',
      name: 'm3eValueGb',
      desc: '',
      args: [value],
    );
  }

  /// `{value} ms`
  String m3eValueMs(Object value) {
    return Intl.message(
      '$value ms',
      name: 'm3eValueMs',
      desc: '',
      args: [value],
    );
  }

  /// `Connecting…`
  String get m3eStatusConnecting {
    return Intl.message(
      'Connecting…',
      name: 'm3eStatusConnecting',
      desc: '',
      args: [],
    );
  }

  /// `Switching…`
  String get m3eStatusSwitching {
    return Intl.message(
      'Switching…',
      name: 'm3eStatusSwitching',
      desc: '',
      args: [],
    );
  }

  /// `No network`
  String get m3eStatusOffline {
    return Intl.message(
      'No network',
      name: 'm3eStatusOffline',
      desc: '',
      args: [],
    );
  }

  /// `Connected`
  String get m3eStatusConnected {
    return Intl.message(
      'Connected',
      name: 'm3eStatusConnected',
      desc: '',
      args: [],
    );
  }

  /// `Server not responding`
  String get m3eStatusError {
    return Intl.message(
      'Server not responding',
      name: 'm3eStatusError',
      desc: '',
      args: [],
    );
  }

  /// `Not connected`
  String get m3eStatusDisconnected {
    return Intl.message(
      'Not connected',
      name: 'm3eStatusDisconnected',
      desc: '',
      args: [],
    );
  }

  /// `Unlimited`
  String get m3ePlanUnlimited {
    return Intl.message(
      'Unlimited',
      name: 'm3ePlanUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `{used} of {total} GB`
  String m3ePlanTrafficOf(Object used, Object total) {
    return Intl.message(
      '$used of $total GB',
      name: 'm3ePlanTrafficOf',
      desc: '',
      args: [used, total],
    );
  }

  /// `until {date}`
  String m3ePlanUntil(Object date) {
    return Intl.message(
      'until $date',
      name: 'm3ePlanUntil',
      desc: '',
      args: [date],
    );
  }

  /// `no expiry`
  String get m3ePlanForever {
    return Intl.message(
      'no expiry',
      name: 'm3ePlanForever',
      desc: '',
      args: [],
    );
  }

  /// `{traffic} · {term}`
  String m3ePlanLine(Object traffic, Object term) {
    return Intl.message(
      '$traffic · $term',
      name: 'm3ePlanLine',
      desc: '',
      args: [traffic, term],
    );
  }

  /// `Subscription expired`
  String get m3ePlanExpired {
    return Intl.message(
      'Subscription expired',
      name: 'm3ePlanExpired',
      desc: '',
      args: [],
    );
  }

  /// `Out of traffic`
  String get m3ePlanTrafficOut {
    return Intl.message(
      'Out of traffic',
      name: 'm3ePlanTrafficOut',
      desc: '',
      args: [],
    );
  }

  /// `{count, plural, one{{count} day left} other{{count} days left}}`
  String m3ePlanDaysLeft(num count) {
    return Intl.plural(
      count,
      one: '$count day left',
      other: '$count days left',
      name: 'm3ePlanDaysLeft',
      desc: '',
      args: [count],
    );
  }

  /// `{left} GB left`
  String m3ePlanTrafficLeft(Object left) {
    return Intl.message(
      '$left GB left',
      name: 'm3ePlanTrafficLeft',
      desc: '',
      args: [left],
    );
  }

  /// `Refresh`
  String get m3eRefresh {
    return Intl.message('Refresh', name: 'm3eRefresh', desc: '', args: []);
  }

  /// `Updated just now`
  String get m3eUpdatedJustNow {
    return Intl.message(
      'Updated just now',
      name: 'm3eUpdatedJustNow',
      desc: '',
      args: [],
    );
  }

  /// `{count, plural, one{Updated {count} minute ago} other{Updated {count} minutes ago}}`
  String m3eUpdatedMinutesAgo(num count) {
    return Intl.plural(
      count,
      one: 'Updated $count minute ago',
      other: 'Updated $count minutes ago',
      name: 'm3eUpdatedMinutesAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{Updated {count} hour ago} other{Updated {count} hours ago}}`
  String m3eUpdatedHoursAgo(num count) {
    return Intl.plural(
      count,
      one: 'Updated $count hour ago',
      other: 'Updated $count hours ago',
      name: 'm3eUpdatedHoursAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{Updated {count} day ago} other{Updated {count} days ago}}`
  String m3eUpdatedDaysAgo(num count) {
    return Intl.plural(
      count,
      one: 'Updated $count day ago',
      other: 'Updated $count days ago',
      name: 'm3eUpdatedDaysAgo',
      desc: '',
      args: [count],
    );
  }

  /// `Connection and subscription`
  String get m3eA11yCard {
    return Intl.message(
      'Connection and subscription',
      name: 'm3eA11yCard',
      desc: '',
      args: [],
    );
  }

  /// `Connection and route`
  String get m3eA11yJoy {
    return Intl.message(
      'Connection and route',
      name: 'm3eA11yJoy',
      desc: '',
      args: [],
    );
  }

  /// `Open settings`
  String get m3eA11ySettings {
    return Intl.message(
      'Open settings',
      name: 'm3eA11ySettings',
      desc: '',
      args: [],
    );
  }

  /// `Open subscriptions`
  String get m3eA11ySubs {
    return Intl.message(
      'Open subscriptions',
      name: 'm3eA11ySubs',
      desc: '',
      args: [],
    );
  }

  /// `Choose route`
  String get m3eA11yRoute {
    return Intl.message(
      'Choose route',
      name: 'm3eA11yRoute',
      desc: '',
      args: [],
    );
  }

  /// `Connect VPN`
  String get m3eA11yConnect {
    return Intl.message(
      'Connect VPN',
      name: 'm3eA11yConnect',
      desc: '',
      args: [],
    );
  }

  /// `Disconnect VPN`
  String get m3eA11yDisconnect {
    return Intl.message(
      'Disconnect VPN',
      name: 'm3eA11yDisconnect',
      desc: '',
      args: [],
    );
  }

  /// `Cancel connecting`
  String get m3eA11yCancel {
    return Intl.message(
      'Cancel connecting',
      name: 'm3eA11yCancel',
      desc: '',
      args: [],
    );
  }

  /// `Retry connecting`
  String get m3eA11yRetry {
    return Intl.message(
      'Retry connecting',
      name: 'm3eA11yRetry',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get m3eA11yBack {
    return Intl.message('Back', name: 'm3eA11yBack', desc: '', args: []);
  }

  /// `Add a subscription`
  String get m3eEmptyTitle {
    return Intl.message(
      'Add a subscription',
      name: 'm3eEmptyTitle',
      desc: '',
      args: [],
    );
  }

  /// `Paste link`
  String get m3eEmptyPaste {
    return Intl.message(
      'Paste link',
      name: 'm3eEmptyPaste',
      desc: '',
      args: [],
    );
  }

  /// `Scan QR code`
  String get m3eEmptyScanQr {
    return Intl.message(
      'Scan QR code',
      name: 'm3eEmptyScanQr',
      desc: '',
      args: [],
    );
  }

  /// `Opening help`
  String get m3eToastSupport {
    return Intl.message(
      'Opening help',
      name: 'm3eToastSupport',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get m3eAboutTitle {
    return Intl.message('About', name: 'm3eAboutTitle', desc: '', args: []);
  }

  /// `Version {version}, core {core}`
  String m3eAboutVersion(Object version, Object core) {
    return Intl.message(
      'Version $version, core $core',
      name: 'm3eAboutVersion',
      desc: '',
      args: [version, core],
    );
  }

  /// `Update`
  String get m3eAboutUpdate {
    return Intl.message('Update', name: 'm3eAboutUpdate', desc: '', args: []);
  }

  /// `Version {version} is available`
  String m3eAboutUpdateAvailable(Object version) {
    return Intl.message(
      'Version $version is available',
      name: 'm3eAboutUpdateAvailable',
      desc: '',
      args: [version],
    );
  }

  /// `Project website`
  String get m3eAboutSite {
    return Intl.message(
      'Project website',
      name: 'm3eAboutSite',
      desc: '',
      args: [],
    );
  }

  /// `Privacy policy`
  String get m3eAboutPrivacy {
    return Intl.message(
      'Privacy policy',
      name: 'm3eAboutPrivacy',
      desc: '',
      args: [],
    );
  }

  /// `Before connecting`
  String get m3eDisclosureTitle {
    return Intl.message(
      'Before connecting',
      name: 'm3eDisclosureTitle',
      desc: '',
      args: [],
    );
  }

  /// `dropweb creates a VPN tunnel using Android's system VPN permission. Your traffic goes through your subscription's servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and device ID.`
  String get m3eDisclosureBody {
    return Intl.message(
      'dropweb creates a VPN tunnel using Android\'s system VPN permission. Your traffic goes through your subscription\'s servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and device ID.',
      name: 'm3eDisclosureBody',
      desc: '',
      args: [],
    );
  }

  /// `Route`
  String get m3eRouteTitle {
    return Intl.message('Route', name: 'm3eRouteTitle', desc: '', args: []);
  }

  /// `Auto`
  String get m3eRouteAuto {
    return Intl.message('Auto', name: 'm3eRouteAuto', desc: '', args: []);
  }

  /// `Country`
  String get m3eRouteCountries {
    return Intl.message(
      'Country',
      name: 'm3eRouteCountries',
      desc: '',
      args: [],
    );
  }

  /// `All traffic through VPN`
  String get m3eRouteAllTraffic {
    return Intl.message(
      'All traffic through VPN',
      name: 'm3eRouteAllTraffic',
      desc: '',
      args: [],
    );
  }

  /// `{count, plural, one{{count} group} other{{count} groups}}`
  String m3eRouteGroupsCount(num count) {
    return Intl.plural(
      count,
      one: '$count group',
      other: '$count groups',
      name: 'm3eRouteGroupsCount',
      desc: '',
      args: [count],
    );
  }

  /// `no response`
  String get m3eMsNoAnswer {
    return Intl.message(
      'no response',
      name: 'm3eMsNoAnswer',
      desc: '',
      args: [],
    );
  }

  /// `Servers and groups`
  String get m3eServersTitle {
    return Intl.message(
      'Servers and groups',
      name: 'm3eServersTitle',
      desc: '',
      args: [],
    );
  }

  /// `Subscription`
  String get m3eSubTitle {
    return Intl.message(
      'Subscription',
      name: 'm3eSubTitle',
      desc: '',
      args: [],
    );
  }

  /// `Help`
  String get m3eSubSupport {
    return Intl.message('Help', name: 'm3eSubSupport', desc: '', args: []);
  }

  /// `All subscriptions`
  String get m3eSubAll {
    return Intl.message(
      'All subscriptions',
      name: 'm3eSubAll',
      desc: '',
      args: [],
    );
  }

  /// `Subscriptions`
  String get m3eSubListLabel {
    return Intl.message(
      'Subscriptions',
      name: 'm3eSubListLabel',
      desc: '',
      args: [],
    );
  }

  /// `Delete subscription`
  String get m3eSubDelete {
    return Intl.message(
      'Delete subscription',
      name: 'm3eSubDelete',
      desc: '',
      args: [],
    );
  }

  /// `Delete “{name}”?`
  String m3eDeleteTitle(Object name) {
    return Intl.message(
      'Delete “$name”?',
      name: 'm3eDeleteTitle',
      desc: '',
      args: [name],
    );
  }

  /// `The paid subscription stays with your provider.`
  String get m3eDeleteBody {
    return Intl.message(
      'The paid subscription stays with your provider.',
      name: 'm3eDeleteBody',
      desc: '',
      args: [],
    );
  }

  /// `Subscription link`
  String get m3eAddFieldLabel {
    return Intl.message(
      'Subscription link',
      name: 'm3eAddFieldLabel',
      desc: '',
      args: [],
    );
  }

  /// `The link must start with https://`
  String get m3eAddFieldError {
    return Intl.message(
      'The link must start with https://',
      name: 'm3eAddFieldError',
      desc: '',
      args: [],
    );
  }

  /// `Version {version}`
  String m3eSettingsAboutVersion(Object version) {
    return Intl.message(
      'Version $version',
      name: 'm3eSettingsAboutVersion',
      desc: '',
      args: [version],
    );
  }

  /// `Same as system`
  String get m3eLangSystem {
    return Intl.message(
      'Same as system',
      name: 'm3eLangSystem',
      desc: '',
      args: [],
    );
  }

  /// `Appearance`
  String get m3eAppearanceTitle {
    return Intl.message(
      'Appearance',
      name: 'm3eAppearanceTitle',
      desc: '',
      args: [],
    );
  }

  /// `Provider color`
  String get m3eAppearanceProvider {
    return Intl.message(
      'Provider color',
      name: 'm3eAppearanceProvider',
      desc: '',
      args: [],
    );
  }

  /// `Custom color`
  String get m3eAppearanceOwn {
    return Intl.message(
      'Custom color',
      name: 'm3eAppearanceOwn',
      desc: '',
      args: [],
    );
  }

  /// `As in the subscription`
  String get m3eAppearanceProviderSub {
    return Intl.message(
      'As in the subscription',
      name: 'm3eAppearanceProviderSub',
      desc: '',
      args: [],
    );
  }

  /// `Choose from the palette`
  String get m3eAppearanceOwnSub {
    return Intl.message(
      'Choose from the palette',
      name: 'm3eAppearanceOwnSub',
      desc: '',
      args: [],
    );
  }

  /// `App color`
  String get m3eAppearanceGroupLabel {
    return Intl.message(
      'App color',
      name: 'm3eAppearanceGroupLabel',
      desc: '',
      args: [],
    );
  }

  /// `Basic colors`
  String get m3eAppearanceBasicColors {
    return Intl.message(
      'Basic colors',
      name: 'm3eAppearanceBasicColors',
      desc: '',
      args: [],
    );
  }

  /// `Color {n}`
  String m3eColorN(Object n) {
    return Intl.message('Color $n', name: 'm3eColorN', desc: '', args: [n]);
  }

  /// `Other color`
  String get m3eColorTitle {
    return Intl.message(
      'Other color',
      name: 'm3eColorTitle',
      desc: '',
      args: [],
    );
  }

  /// `Shade {n}`
  String m3eColorShade(Object n) {
    return Intl.message('Shade $n', name: 'm3eColorShade', desc: '', args: [n]);
  }

  /// `dropweb {version}`
  String m3eUpdateTitle(Object version) {
    return Intl.message(
      'dropweb $version',
      name: 'm3eUpdateTitle',
      desc: '',
      args: [version],
    );
  }

  /// `What's new`
  String get m3eUpdateNotes {
    return Intl.message(
      'What\'s new',
      name: 'm3eUpdateNotes',
      desc: '',
      args: [],
    );
  }

  /// `Downloading update`
  String get m3eUpdateProgressLabel {
    return Intl.message(
      'Downloading update',
      name: 'm3eUpdateProgressLabel',
      desc: '',
      args: [],
    );
  }

  /// `Downloading… {percent}%`
  String m3eUpdateDownloading(Object percent) {
    return Intl.message(
      'Downloading… $percent%',
      name: 'm3eUpdateDownloading',
      desc: '',
      args: [percent],
    );
  }

  /// `Verifying…`
  String get m3eUpdateVerifying {
    return Intl.message(
      'Verifying…',
      name: 'm3eUpdateVerifying',
      desc: '',
      args: [],
    );
  }

  /// `Downloaded, ready to install`
  String get m3eUpdateReady {
    return Intl.message(
      'Downloaded, ready to install',
      name: 'm3eUpdateReady',
      desc: '',
      args: [],
    );
  }

  /// `Update failed`
  String get m3eUpdateFailed {
    return Intl.message(
      'Update failed',
      name: 'm3eUpdateFailed',
      desc: '',
      args: [],
    );
  }

  /// `Subscription updated`
  String get m3eToastRefreshed {
    return Intl.message(
      'Subscription updated',
      name: 'm3eToastRefreshed',
      desc: '',
      args: [],
    );
  }

  /// `Can't reach the server`
  String get m3eToastRefreshFail {
    return Intl.message(
      'Can\'t reach the server',
      name: 'm3eToastRefreshFail',
      desc: '',
      args: [],
    );
  }

  /// `Opening the Android installer`
  String get m3eToastInstaller {
    return Intl.message(
      'Opening the Android installer',
      name: 'm3eToastInstaller',
      desc: '',
      args: [],
    );
  }

  /// `Flashlight`
  String get m3eScanTorch {
    return Intl.message('Flashlight', name: 'm3eScanTorch', desc: '', args: []);
  }

  /// `Choose from gallery`
  String get m3eScanGallery {
    return Intl.message(
      'Choose from gallery',
      name: 'm3eScanGallery',
      desc: '',
      args: [],
    );
  }

  /// `Before connecting`
  String get ios27DisclosureTitle {
    return Intl.message(
      'Before connecting',
      name: 'ios27DisclosureTitle',
      desc: '',
      args: [],
    );
  }

  /// `dropweb creates a VPN tunnel using a VPN configuration, and your iPhone will ask you to allow adding it. Your traffic goes through your subscription's servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and device ID.`
  String get ios27DisclosureBody {
    return Intl.message(
      'dropweb creates a VPN tunnel using a VPN configuration, and your iPhone will ask you to allow adding it. Your traffic goes through your subscription\'s servers. dropweb does not see or log what you do online. The subscription provider receives your IP address and device ID.',
      name: 'ios27DisclosureBody',
      desc: '',
      args: [],
    );
  }

  /// `Privacy Policy`
  String get ios27DisclosurePolicy {
    return Intl.message(
      'Privacy Policy',
      name: 'ios27DisclosurePolicy',
      desc: '',
      args: [],
    );
  }

  /// `Connection and country`
  String get ios27A11yJoy {
    return Intl.message(
      'Connection and country',
      name: 'ios27A11yJoy',
      desc: '',
      args: [],
    );
  }

  /// `Route: {name}. Open list`
  String ios27A11yRoute(Object name) {
    return Intl.message(
      'Route: $name. Open list',
      name: 'ios27A11yRoute',
      desc: '',
      args: [name],
    );
  }

  /// `just now`
  String get ios27UpdatedJustNow {
    return Intl.message(
      'just now',
      name: 'ios27UpdatedJustNow',
      desc: '',
      args: [],
    );
  }

  /// `{count, plural, one{{count} minute ago} other{{count} minutes ago}}`
  String ios27UpdatedMinutesAgo(num count) {
    return Intl.plural(
      count,
      one: '$count minute ago',
      other: '$count minutes ago',
      name: 'ios27UpdatedMinutesAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{{count} hour ago} other{{count} hours ago}}`
  String ios27UpdatedHoursAgo(num count) {
    return Intl.plural(
      count,
      one: '$count hour ago',
      other: '$count hours ago',
      name: 'ios27UpdatedHoursAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, one{{count} day ago} other{{count} days ago}}`
  String ios27UpdatedDaysAgo(num count) {
    return Intl.plural(
      count,
      one: '$count day ago',
      other: '$count days ago',
      name: 'ios27UpdatedDaysAgo',
      desc: '',
      args: [count],
    );
  }

  /// `Colors`
  String get ios27AppearanceColors {
    return Intl.message(
      'Colors',
      name: 'ios27AppearanceColors',
      desc: '',
      args: [],
    );
  }

  /// `Provider`
  String get ios27AppearanceProvider {
    return Intl.message(
      'Provider',
      name: 'ios27AppearanceProvider',
      desc: '',
      args: [],
    );
  }

  /// `Custom`
  String get ios27AppearanceOwn {
    return Intl.message(
      'Custom',
      name: 'ios27AppearanceOwn',
      desc: '',
      args: [],
    );
  }

  /// `Buttons`
  String get ios27ColorSlotAccent {
    return Intl.message(
      'Buttons',
      name: 'ios27ColorSlotAccent',
      desc: '',
      args: [],
    );
  }

  /// `Background top`
  String get ios27ColorSlotOrb1 {
    return Intl.message(
      'Background top',
      name: 'ios27ColorSlotOrb1',
      desc: '',
      args: [],
    );
  }

  /// `Background bottom`
  String get ios27ColorSlotOrb2 {
    return Intl.message(
      'Background bottom',
      name: 'ios27ColorSlotOrb2',
      desc: '',
      args: [],
    );
  }

  /// `Color: {slot}`
  String ios27ColorSheetLabel(Object slot) {
    return Intl.message(
      'Color: $slot',
      name: 'ios27ColorSheetLabel',
      desc: '',
      args: [slot],
    );
  }

  /// `Blue`
  String get ios27PresetBlue {
    return Intl.message('Blue', name: 'ios27PresetBlue', desc: '', args: []);
  }

  /// `Purple`
  String get ios27PresetPurple {
    return Intl.message(
      'Purple',
      name: 'ios27PresetPurple',
      desc: '',
      args: [],
    );
  }

  /// `Pink`
  String get ios27PresetPink {
    return Intl.message('Pink', name: 'ios27PresetPink', desc: '', args: []);
  }

  /// `Red`
  String get ios27PresetRed {
    return Intl.message('Red', name: 'ios27PresetRed', desc: '', args: []);
  }

  /// `Orange`
  String get ios27PresetOrange {
    return Intl.message(
      'Orange',
      name: 'ios27PresetOrange',
      desc: '',
      args: [],
    );
  }

  /// `Yellow`
  String get ios27PresetYellow {
    return Intl.message(
      'Yellow',
      name: 'ios27PresetYellow',
      desc: '',
      args: [],
    );
  }

  /// `Green`
  String get ios27PresetGreen {
    return Intl.message('Green', name: 'ios27PresetGreen', desc: '', args: []);
  }

  /// `Graphite`
  String get ios27PresetGraphite {
    return Intl.message(
      'Graphite',
      name: 'ios27PresetGraphite',
      desc: '',
      args: [],
    );
  }

  /// `The QR code camera will open here`
  String get ios27ToastQr {
    return Intl.message(
      'The QR code camera will open here',
      name: 'ios27ToastQr',
      desc: '',
      args: [],
    );
  }

  /// `Opens in the browser`
  String get ios27ToastLink {
    return Intl.message(
      'Opens in the browser',
      name: 'ios27ToastLink',
      desc: '',
      args: [],
    );
  }

  /// `Glass`
  String get ios27GlassTitle {
    return Intl.message('Glass', name: 'ios27GlassTitle', desc: '', args: []);
  }

  /// `Clear`
  String get ios27GlassCapClear {
    return Intl.message(
      'Clear',
      name: 'ios27GlassCapClear',
      desc: '',
      args: [],
    );
  }

  /// `Tinted`
  String get ios27GlassTinted {
    return Intl.message('Tinted', name: 'ios27GlassTinted', desc: '', args: []);
  }

  /// `Clearer`
  String get ios27GlassClearer {
    return Intl.message(
      'Clearer',
      name: 'ios27GlassClearer',
      desc: '',
      args: [],
    );
  }

  /// `Standard`
  String get ios27GlassStandard {
    return Intl.message(
      'Standard',
      name: 'ios27GlassStandard',
      desc: '',
      args: [],
    );
  }

  /// `Denser`
  String get ios27GlassDenser {
    return Intl.message('Denser', name: 'ios27GlassDenser', desc: '', args: []);
  }

  /// `Themes`
  String get ios27AppearanceThemes {
    return Intl.message(
      'Themes',
      name: 'ios27AppearanceThemes',
      desc: '',
      args: [],
    );
  }

  /// `Country`
  String get ios27StatCountry {
    return Intl.message(
      'Country',
      name: 'ios27StatCountry',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'ja'),
      Locale.fromSubtags(languageCode: 'ru'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
