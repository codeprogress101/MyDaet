import 'package:flutter_test/flutter_test.dart';
import 'package:mydaet/features/shared/timezone_utils.dart';

void main() {
  test('toManila converts UTC to Manila time (+8)', () {
    final utc = DateTime.utc(2026, 2, 16, 0, 0, 0);
    final manila = toManila(utc);
    expect(manila.year, 2026);
    expect(manila.month, 2);
    expect(manila.day, 16);
    expect(manila.hour, 8);
  });

  test('formatManilaDateTime includes PHT zone when requested', () {
    final utc = DateTime.utc(2026, 2, 16, 5, 30, 0);
    final text = formatManilaDateTime(utc, includeZone: true);
    expect(text.contains('PHT'), isTrue);
  });
}
