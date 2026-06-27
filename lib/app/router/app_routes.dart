abstract final class AppRoutes {
  // ── Top-level ─────────────────────────────────────────────────────────────
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';

  // ── Authenticated sub-routes ──────────────────────────────────────────────

  /// Today's reflection list.
  static const reflections = '/home/reflections';

  /// Reflections for a specific date (deep-linkable: `orbit://reflection/:date`)
  static String reflectionByDate(String date) => '/home/reflections/$date';

  /// Weekly overview (future). Deep-link: `orbit://weekly`
  static const weekly = '/home/weekly';

  /// AI knowledge view. Deep-link: `orbit://knowledge`
  static const knowledge = '/home/knowledge';

  /// Task list. Deep-link: `orbit://task` (all tasks)
  static const tasks = '/home/tasks';

  /// Single task detail. Deep-link: `orbit://task/:id`
  static String taskById(String id) => '/home/tasks/$id';

  /// App settings. Deep-link: `orbit://settings`
  static const settings = '/home/settings';
}
