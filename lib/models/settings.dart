enum AppThemeMode { system, light, dark }

class UserSettings {
  final String name;
  final String? avatarUri;
  final int assignmentReminderDays;
  final int examReminderDays;
  final bool notificationsEnabled;
  final AppThemeMode theme;
  final int weekStartDay;
  final String dashboardView;
  final int minAttendancePercent;
  final int dailyStudyGoalMinutes;

  UserSettings({
    required this.name,
    this.avatarUri,
    this.assignmentReminderDays = 2,
    this.examReminderDays = 3,
    this.notificationsEnabled = true,
    this.theme = AppThemeMode.light,
    this.weekStartDay = DateTime.saturday,
    this.dashboardView = 'active',
    this.minAttendancePercent = 75,
    this.dailyStudyGoalMinutes = 0,
  });

  factory UserSettings.defaults() => UserSettings(
    name: 'Student',
    assignmentReminderDays: 2,
    examReminderDays: 3,
    notificationsEnabled: true,
    theme: AppThemeMode.light,
    weekStartDay: DateTime.saturday,
    dashboardView: 'active',
    minAttendancePercent: 75,
    dailyStudyGoalMinutes: 0,
  );

  UserSettings copyWith({
    String? name,
    String? avatarUri,
    int? assignmentReminderDays,
    int? examReminderDays,
    bool? notificationsEnabled,
    AppThemeMode? theme,
    int? weekStartDay,
    String? dashboardView,
    int? minAttendancePercent,
    int? dailyStudyGoalMinutes,
  }) {
    return UserSettings(
      name: name ?? this.name,
      avatarUri: avatarUri ?? this.avatarUri,
      assignmentReminderDays:
          assignmentReminderDays ?? this.assignmentReminderDays,
      examReminderDays: examReminderDays ?? this.examReminderDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      theme: theme ?? this.theme,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      dashboardView: dashboardView ?? this.dashboardView,
      minAttendancePercent: minAttendancePercent ?? this.minAttendancePercent,
      dailyStudyGoalMinutes:
          dailyStudyGoalMinutes ?? this.dailyStudyGoalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarUri': avatarUri,
    'assignmentReminderDays': assignmentReminderDays,
    'examReminderDays': examReminderDays,
    'notificationsEnabled': notificationsEnabled,
    'theme': theme.name,
    'weekStartDay': weekStartDay,
    'dashboardView': dashboardView,
    'minAttendancePercent': minAttendancePercent,
    'dailyStudyGoalMinutes': dailyStudyGoalMinutes,
  };

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
    name: j['name'] ?? 'Student',
    avatarUri: j['avatarUri'],
    assignmentReminderDays: j['assignmentReminderDays'] ?? 2,
    examReminderDays: j['examReminderDays'] ?? 3,
    notificationsEnabled: j['notificationsEnabled'] ?? true,
    theme: j['theme'] != null
        ? AppThemeMode.values.byName(j['theme'])
        : AppThemeMode.light,
    weekStartDay: (j['weekStartDay'] as num?)?.toInt() ?? DateTime.saturday,
    dashboardView: j['dashboardView'] ?? 'active',
    minAttendancePercent: (j['minAttendancePercent'] as num?)?.toInt() ?? 75,
    dailyStudyGoalMinutes: (j['dailyStudyGoalMinutes'] as num?)?.toInt() ?? 0,
  );
}
