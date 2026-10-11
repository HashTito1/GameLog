const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Unambiguous short date, e.g. "Sep 2, 2026". Numeric d/m/y reads as a
/// different date in the US than elsewhere.
String formatShortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';
