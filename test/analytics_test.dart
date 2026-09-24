import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/service/analytics_service.dart';
import 'package:rescu/service/fake_api_service.dart';

class MockFakeApiService extends FakeApiService {
  final List<List<Map<String, dynamic>>> sentBatches = [];

  @override
  Future<void> sendAnalyticsBatch(List<Map<String, dynamic>> events) async {
    sentBatches.add(events);
  }
}

void main() {
  late AnalyticsService analyticsService;
  late MockFakeApiService mockApi;

  setUp(() {
    Get.reset();
    mockApi = MockFakeApiService();
    Get.put<FakeApiService>(mockApi, permanent: true);
    analyticsService = Get.put(AnalyticsService(), permanent: true);
  });

  tearDown(() {
    analyticsService.onClose();
    Get.reset();
  });

  group('AnalyticsService Impression Deduplication', () {
    test(
        'Logs deal_impression event on first call and ignores duplicate calls in same session',
        () {
      expect(analyticsService.hasImpression(101), isFalse);

      final logged1 = analyticsService.trackImpression(
        dealId: 101,
        source: 'home_feed',
        position: 0,
      );
      expect(logged1, isTrue);
      expect(analyticsService.hasImpression(101), isTrue);
      expect(analyticsService.events.length, 1);
      expect(analyticsService.events.first.name, 'deal_impression');
      expect(analyticsService.events.first.properties, {
        'deal_id': 101,
        'source': 'home_feed',
        'position': 0,
      });

      // Second call across another screen/source for same deal ID
      final logged2 = analyticsService.trackImpression(
        dealId: 101,
        source: 'search',
        position: 2,
      );
      expect(logged2, isFalse); // Ignored!
      expect(analyticsService.events.length, 1);
    });
  });

  group('AnalyticsService Batching Logic', () {
    test('Flushes immediately when 10 events accumulate', () {
      for (int i = 0; i < 9; i++) {
        analyticsService.trackImpression(
          dealId: i + 1,
          source: 'home_feed',
          position: i,
        );
      }
      // 9 events logged, batch not yet sent
      expect(mockApi.sentBatches.isEmpty, isTrue);

      // 10th event logged
      analyticsService.trackImpression(
        dealId: 10,
        source: 'home_feed',
        position: 9,
      );

      expect(mockApi.sentBatches.length, 1);
      expect(mockApi.sentBatches.first.length, 10);
      expect(mockApi.sentBatches.first.first['properties']['deal_id'], 1);
      expect(mockApi.sentBatches.first.last['properties']['deal_id'], 10);
    });

    test('Flushes batch after 15 seconds if fewer than 10 events', () async {
      analyticsService.trackImpression(
        dealId: 1,
        source: 'home_feed',
        position: 0,
      );

      expect(mockApi.sentBatches.isEmpty, isTrue);

      // Wait 15.5 seconds
      await Future.delayed(const Duration(milliseconds: 15500));

      expect(mockApi.sentBatches.length, 1);
      expect(mockApi.sentBatches.first.length, 1);
      expect(mockApi.sentBatches.first.first['properties']['deal_id'], 1);
    });
  });
}
