/// RBAC roles for the Highlander application.
///
/// Roles are ordered by access level (lowest → highest).
/// Use [isAtLeast] to check if the current role has sufficient privileges.
enum Role {
  fieldReporter(
    displayName: 'Field Reporter',
    apiValue: 'field_reporter',
    level: 0,
  ),
  safetyCoordinator(
    displayName: 'Safety Coordinator',
    apiValue: 'safety_coordinator',
    level: 1,
  ),
  safetyManager(
    displayName: 'Safety Manager',
    apiValue: 'safety_manager',
    level: 2,
  ),
  pm(displayName: 'Project Manager', apiValue: 'pm', level: 3),
  divisionManager(
    displayName: 'Division Manager',
    apiValue: 'division_manager',
    level: 4,
  ),
  executive(displayName: 'Executive', apiValue: 'executive', level: 5),
  admin(displayName: 'Admin', apiValue: 'admin', level: 6);

  const Role({
    required this.displayName,
    required this.apiValue,
    required this.level,
  });

  /// Human-readable name shown in the UI.
  final String displayName;

  /// The string value sent to / received from the API.
  final String apiValue;

  /// Numeric hierarchy level — higher = more access.
  final int level;

  /// Returns true if this role's access level is at least as high as [role].
  bool isAtLeast(Role role) => level >= role.level;

  /// Look up a [Role] by its [apiValue]. Returns null if not found.
  static Role? fromApiValue(String value) {
    for (final role in Role.values) {
      if (role.apiValue == value) return role;
    }
    return null;
  }
}
