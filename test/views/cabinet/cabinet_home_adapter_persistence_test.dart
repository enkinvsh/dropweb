import 'dart:convert';

import 'package:dropweb/views/cabinet/cabinet_home_adapter.dart';
import 'package:dropweb/views/cabinet/cabinet_home_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> validPayload() => <String, dynamic>{
        'tariffName': 'Pro',
        'tariffCostLabel': '300 ₽',
        'balanceLabel': 'Баланс 392 ₽',
        'balanceAmountKopeks': 39200,
        'referralLink': 'https://cab.dropweb.org/ref/abc',
        'subscriptionUrl': 'https://cab.dropweb.org/sub/xyz',
        'importState': 'ready',
        'statusLabel': '18d 3h',
      };

  group('CabinetHomeAdapter persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('update() persists snapshot so a new adapter can restore() it',
        () async {
      final writer = CabinetHomeAdapter();
      final data = CabinetHomeData.fromBridgePayload(validPayload());
      expect(data, isNotNull);
      writer.update(data!);

      // Allow the fire-and-forget persistence write to complete.
      await Future<void>.delayed(Duration.zero);

      final reader = CabinetHomeAdapter();
      expect(reader.snapshot.value, isNull);
      await reader.restore();

      final restored = reader.snapshot.value;
      expect(restored, isNotNull);
      expect(restored!.tariffName, 'Pro');
      expect(restored.tariffCostLabel, '300 ₽');
      expect(restored.balanceLabel, 'Баланс 392 ₽');
      expect(restored.balanceAmountKopeks, 39200);
      expect(restored.referralLink.toString(),
          'https://cab.dropweb.org/ref/abc');
      // subscriptionUrl is token-bearing and MUST NOT be restored from
      // plaintext SharedPreferences. After cold restart the UI falls
      // back to opening the cabinet; the live bridge republishes the
      // URL once the WebView re-authenticates.
      expect(restored.subscriptionUrl, isNull);
      expect(restored.importState, CabinetImportState.ready);
      expect(restored.statusLabel, '18d 3h');

      // Strictly verify the persisted JSON blob does not contain the
      // token-bearing subscription URL or even the key. This is a
      // regression guard for the security review finding.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('cabinet_home_snapshot_v1');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('subscriptionUrl')));
      expect(stored, isNot(contains('cab.dropweb.org/sub/xyz')));
      final decoded = json.decode(stored!) as Map<String, dynamic>;
      expect(decoded.containsKey('subscriptionUrl'), isFalse);
    });

    test('restore() ignores corrupt stored JSON and leaves snapshot null',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cabinet_home_snapshot_v1': '{not valid json',
      });

      final adapter = CabinetHomeAdapter();
      await adapter.restore();
      expect(adapter.snapshot.value, isNull);
    });

    test('restore() ignores stored payload that fails validation', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        // importState is required and must be a known enum value.
        'cabinet_home_snapshot_v1': json.encode(<String, dynamic>{
          'tariffName': 'Pro',
          'importState': 'totally-unknown-state',
        }),
      });

      final adapter = CabinetHomeAdapter();
      await adapter.restore();
      expect(adapter.snapshot.value, isNull);

      // Invalid payload must be cleared so it cannot block future writes.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cabinet_home_snapshot_v1'), isNull);
    });

    test('restore() does not overwrite a snapshot already set by the bridge',
        () async {
      // Stored snapshot uses 'ready'.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cabinet_home_snapshot_v1': json.encode(validPayload()),
      });

      final adapter = CabinetHomeAdapter();
      final fresh = CabinetHomeData.fromBridgePayload(<String, dynamic>{
        ...validPayload(),
        'importState': 'imported',
        'tariffName': 'Fresh',
      });
      adapter.update(fresh!);

      await adapter.restore();

      expect(adapter.snapshot.value?.tariffName, 'Fresh');
      expect(adapter.snapshot.value?.importState, CabinetImportState.imported);
    });

    test('clear() removes the persisted snapshot', () async {
      final adapter = CabinetHomeAdapter();
      final data = CabinetHomeData.fromBridgePayload(validPayload());
      adapter.update(data!);
      await Future<void>.delayed(Duration.zero);

      adapter.clear();
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cabinet_home_snapshot_v1'), isNull);

      final reader = CabinetHomeAdapter();
      await reader.restore();
      expect(reader.snapshot.value, isNull);
    });
  });
}
