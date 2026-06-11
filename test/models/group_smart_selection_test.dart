import 'dart:ui';

import 'package:dropweb/common/app_localizations.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // getCurrentSelectedName (display path) reads appLocalizations, which
  // asserts an instance was loaded.
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  Group smartGroup({String? now}) => Group(
        type: GroupType.Smart,
        name: '🧠 Smart',
        now: now,
      );

  group('GroupExt.resolveSelectedName (delay-resolution path)', () {
    test(
        'unpinned smart group (core placeholder now) yields "" so the '
        'resolution chain terminates at the group itself', () {
      final group = smartGroup(now: 'Smart - Select');

      expect(group.resolveSelectedName(''), '');
    });

    test('never leaks the localized auto label into resolution', () {
      final group = smartGroup(now: 'Smart - Select');

      expect(group.resolveSelectedName(''), isNot(appLocalizations.smartAuto));
    });

    test('pinned smart group resolves to the pinned node', () {
      final group = smartGroup(now: 'Node A');

      expect(group.resolveSelectedName(''), 'Node A');
    });

    test('url-test group keeps computed-now semantics', () {
      const group = Group(
        type: GroupType.URLTest,
        name: 'Fastest',
        now: 'Node B',
      );

      expect(group.resolveSelectedName(''), 'Node B');
      expect(group.resolveSelectedName('Manual'), 'Node B');
    });

    test('selector group prefers the user pick over now', () {
      const group = Group(
        type: GroupType.Selector,
        name: 'VPN',
        now: 'Node C',
      );

      expect(group.resolveSelectedName('Picked'), 'Picked');
      expect(group.resolveSelectedName(''), 'Node C');
    });
  });

  group('GroupExt.getCurrentSelectedName (display path)', () {
    test('unpinned smart group surfaces the localized auto label', () {
      final group = smartGroup(now: 'Smart - Select');

      expect(group.getCurrentSelectedName(''), appLocalizations.smartAuto);
    });

    test('pinned smart group displays the pinned node', () {
      final group = smartGroup(now: 'Node A');

      expect(group.getCurrentSelectedName(''), 'Node A');
    });
  });
}
