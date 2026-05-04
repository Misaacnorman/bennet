import 'package:intl/intl.dart';

/// Fixed-point money in minor units (e.g. cents).
typedef MinorUnits = int;

String formatMoney(MinorUnits minor, {String currencySymbol = r'$'}) {
  final v = minor / 100.0;
  return '$currencySymbol${NumberFormat('#,##0.00', 'en_US').format(v)}';
}

/// Parses user input like "12", "12.5", "12.34" into minor units.
MinorUnits? parseMoneyInput(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final v = double.tryParse(s.replaceAll(',', ''));
  if (v == null) return null;
  return (v * 100).round();
}
