enum SortingMode {
  aToz,
  zToa,
  createdDateIncreasing,
  createdDateDecreasing,
  dueDateIncreasing,
  dueDateDecreasing,
  starredFirst,
  nonStarredFirst,
  manual,
}

extension SortingModeExtension on SortingMode {
  String get displayName {
    switch (this) {
      case SortingMode.aToz:
        return 'A to Z';
      case SortingMode.zToa:
        return 'Z to A';
      case SortingMode.createdDateIncreasing:
        return 'Created Date ↑';
      case SortingMode.createdDateDecreasing:
        return 'Created Date ↓';
      case SortingMode.dueDateIncreasing:
        return 'Due Date ↑';
      case SortingMode.dueDateDecreasing:
        return 'Due Date ↓';
      case SortingMode.starredFirst:
        return 'Starred First';
      case SortingMode.nonStarredFirst:
        return 'Non-Starred First';
      case SortingMode.manual:
        return 'Manual';
    }
  }
}

/// The mode called [name] (as stored in settings), or [fallback] if unknown.
SortingMode sortingModeFromName(
  String? name, {
  SortingMode fallback = SortingMode.createdDateDecreasing,
}) {
  for (final m in SortingMode.values) {
    if (m.name == name) return m;
  }
  return fallback;
}
