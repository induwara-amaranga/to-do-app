enum GroupingMode { Default, day, month, year }

/// The mode called [name] (as stored in settings), or [GroupingMode.Default].
GroupingMode groupingModeFromName(String? name) {
  for (final m in GroupingMode.values) {
    if (m.name == name) return m;
  }
  return GroupingMode.Default;
}
