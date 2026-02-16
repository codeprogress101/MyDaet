import 'package:flutter_test/flutter_test.dart';
import 'package:mydaet/services/permissions.dart';

void main() {
  group('Permissions.canEditReport', () {
    test('super admin can always edit', () {
      const user = UserContext(uid: 'u1', role: AppRole.superAdmin);
      expect(
        Permissions.canEditReport(
          user,
          reportOfficeId: null,
          assignedToUid: null,
          currentUserUid: user.uid,
        ),
        isTrue,
      );
    });

    test('office admin requires matching office', () {
      const user = UserContext(
        uid: 'u2',
        role: AppRole.officeAdmin,
        officeId: 'office-a',
      );
      expect(
        Permissions.canEditReport(
          user,
          reportOfficeId: 'office-a',
          assignedToUid: null,
          currentUserUid: user.uid,
        ),
        isTrue,
      );
      expect(
        Permissions.canEditReport(
          user,
          reportOfficeId: 'office-b',
          assignedToUid: null,
          currentUserUid: user.uid,
        ),
        isFalse,
      );
    });

    test('moderator can only edit assigned reports', () {
      const user = UserContext(uid: 'mod-1', role: AppRole.moderator);
      expect(
        Permissions.canEditReport(
          user,
          reportOfficeId: 'office-a',
          assignedToUid: 'mod-1',
          currentUserUid: 'mod-1',
        ),
        isTrue,
      );
      expect(
        Permissions.canEditReport(
          user,
          reportOfficeId: 'office-a',
          assignedToUid: 'other-mod',
          currentUserUid: 'mod-1',
        ),
        isFalse,
      );
    });
  });
}
