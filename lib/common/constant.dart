import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:flutter/material.dart';

const appName = "dropweb";
const appHelperService = "DropwebHelperService";
const coreName = "clashx.meta";
const browserUa =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const packageName = "app.dropweb";
// SECURITY: Random.secure() (CSPRNG) — plain Random is predictable, IPC hijack risk.
final unixSocketPath =
    "/tmp/dropwebSocket_${Random.secure().nextInt(1 << 32).toRadixString(16)}${Random.secure().nextInt(1 << 16).toRadixString(16)}.sock";
const helperPort = 47890;
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const mmdbFileName = "geoip.metadb";
const asnFileName = "ASN.mmdb";
const geoIpFileName = "GeoIP.dat";
const geoSiteFileName = "GeoSite.dat";
final double kHeaderHeight = system.isDesktop
    ? !Platform.isMacOS
        ? 40
        : 28
    : 0;
const profilesDirectoryName = "profiles";
const localhost = "127.0.0.1";
const clashConfigKey = "clash_config";
const configKey = "config";
const socksPortKey = "socks_port";
const double dialogCommonWidth = 300;
const repository = "enkinvsh/dropweb";
const defaultExternalController = "127.0.0.1:9090";
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = "https://www.gstatic.com/generate_204";
final commonFilter = ImageFilter.blur(
  sigmaX: 2.5,
  sigmaY: 2.5,
  tileMode: TileMode.mirror,
);

const navigationItemListEquality = ListEquality<NavigationItem>();
const connectionListEquality = ListEquality<Connection>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const defaultPrimaryColor = 0xFF29FF76;

double getWidgetHeight(num lines) => max(lines * 84 + (lines - 1) * 16, 0).ap;

const maxLength = 150;

const mainIsolate = "dropwebMainIsolate";

const serviceIsolate = "dropwebServiceIsolate";

const defaultPrimaryColors = [
  0xFF29FF76, // Emerald (Падение)
  0xFF38BDF8, // Frost
  0xFFA78BFA, // Amethyst
  0xFFEF4444, // Crimson
  0xFFF59E0B, // Amber
  0xFF64748B, // Stealth
];

/// Theme trio: accent + two ambient orb colors.
class ThemePreset {
  const ThemePreset(
    this.nameKey,
    this.accent,
    this.orbPrimary,
    this.orbSecondary,
  );

  final String nameKey; // l10n key, resolved in UI
  final int accent;
  final int orbPrimary;
  final int orbSecondary;
}

const themePresets = <ThemePreset>[
  ThemePreset('presetEmerald', 0xFF29FF76, 0xFF009938, 0xFF2BFF7A),
  ThemePreset('presetFrost', 0xFF38BDF8, 0xFF60A5FA, 0xFF38BDF8),
  ThemePreset('presetAmethyst', 0xFFA78BFA, 0xFF8B5CF6, 0xFFA855F7),
  ThemePreset('presetCrimson', 0xFFEF4444, 0xFFF87171, 0xFFB91C1C),
  ThemePreset('presetAmber', 0xFFF59E0B, 0xFFFBBF24, 0xFFB45309),
  ThemePreset('presetStealth', 0xFF64748B, 0xFF94A3B8, 0xFF475569),
];

const scriptTemplate = """
const main = (config) => {
  return config;
}""";
