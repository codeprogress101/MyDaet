enum AuditLogScope { none, office, all }

class AppRole {
  static const String superAdmin = 'super_admin';
  static const String officeAdmin = 'office_admin';
  static const String moderator = 'moderator';
  static const String resident = 'resident';
  static const String legacyAdmin = 'admin';

  static String normalize(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    switch (normalized) {
      case legacyAdmin:
        return superAdmin;
      case superAdmin:
      case officeAdmin:
      case moderator:
      case resident:
        return normalized;
      default:
        return resident;
    }
  }

  static bool isAdmin(String role) {
    return role == superAdmin || role == officeAdmin;
  }

  static bool isStaff(String role) {
    return isAdmin(role) || role == moderator;
  }
}

class UserContext {
  final String uid;
  final String role;
  final String? officeId;
  final String? officeName;
  final bool isActive;

  const UserContext({
    required this.uid,
    required this.role,
    this.officeId,
    this.officeName,
    this.isActive = true,
  });

  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get isOfficeAdmin => role == AppRole.officeAdmin;
  bool get isModerator => role == AppRole.moderator;
  bool get isResident => role == AppRole.resident;
  bool get isAdmin => isSuperAdmin || isOfficeAdmin;
  bool get isStaff => isAdmin || isModerator;
}

class Permissions {
  static bool canViewAllOffices(UserContext user) {
    return user.isSuperAdmin;
  }

  static bool canManageOfficeSlots(UserContext user) {
    return user.isSuperAdmin || user.isOfficeAdmin;
  }

  static bool canAssignReportsGlobal(UserContext user) {
    return user.isSuperAdmin;
  }

  static bool canAssignReportsWithinOffice(
    UserContext user, {
    String? reportOfficeId,
  }) {
    if (!user.isOfficeAdmin) return false;
    final trimmed = reportOfficeId?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return user.officeId != null && user.officeId == trimmed;
  }

  static bool canEditReport(
    UserContext user, {
    String? reportOfficeId,
    String? assignedToUid,
    String? currentUserUid,
  }) {
    if (user.isSuperAdmin) return true;
    if (user.isOfficeAdmin) {
      final trimmed = reportOfficeId?.trim();
      if (trimmed == null || trimmed.isEmpty) return false;
      return user.officeId != null && user.officeId == trimmed;
    }
    if (user.isModerator) {
      if (currentUserUid == null || currentUserUid.isEmpty) return false;
      return assignedToUid != null && assignedToUid == currentUserUid;
    }
    return false;
  }

  static AuditLogScope auditLogScope(UserContext user) {
    if (user.isSuperAdmin) return AuditLogScope.all;
    if (user.isOfficeAdmin) return AuditLogScope.office;
    return AuditLogScope.none;
  }

  static bool canViewAuditLogs(UserContext user) {
    return auditLogScope(user) != AuditLogScope.none;
  }

  static bool canManageUsers(UserContext user) {
    return user.isSuperAdmin;
  }

  static bool shouldScopeByOffice(UserContext user) {
    return user.isOfficeAdmin || user.isModerator;
  }
}
