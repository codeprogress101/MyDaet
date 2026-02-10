class Appointment {
  final String id;
  final String officeId;

  const Appointment({
    required this.id,
    required this.officeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'officeId': officeId,
    };
  }
}

class OfficeSlot {
  final String id;
  final String officeId;

  const OfficeSlot({
    required this.id,
    required this.officeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'officeId': officeId,
    };
  }
}
