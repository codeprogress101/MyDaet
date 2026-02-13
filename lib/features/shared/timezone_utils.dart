const Duration _manilaOffset = Duration(hours: 8);

DateTime toManila(DateTime input) {
  final utc = input.isUtc ? input : input.toUtc();
  return utc.add(_manilaOffset);
}

String formatManilaTime(DateTime input, {bool includeZone = false}) {
  final dt = toManila(input);
  int hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  if (hour == 0) hour = 12;
  if (hour > 12) hour -= 12;
  final base = '$hour:$minute $ampm';
  return includeZone ? '$base PHT' : base;
}

String formatManilaDate(DateTime input, {bool includeYear = true}) {
  final dt = toManila(input);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = months[dt.month - 1];
  final day = dt.day.toString().padLeft(2, '0');
  if (!includeYear) return '$m $day';
  return '$m $day, ${dt.year}';
}

String formatManilaDateTime(DateTime input, {bool includeZone = true}) {
  return '${formatManilaDate(input)} - ${formatManilaTime(input, includeZone: includeZone)}';
}
