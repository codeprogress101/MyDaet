import 'package:flutter_test/flutter_test.dart';
import 'package:mydaet/features/shared/report_status.dart';

void main() {
  test('normalize returns submitted for unknown values', () {
    expect(ReportStatusHelper.normalize('unknown'), 'submitted');
    expect(ReportStatusHelper.normalize(null), 'submitted');
  });

  test('pretty returns human-friendly labels', () {
    expect(ReportStatusHelper.pretty('in_review'), 'In review');
    expect(ReportStatusHelper.pretty('resolved'), 'Resolved');
  });
}
