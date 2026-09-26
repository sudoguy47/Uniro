enum AppThemeMode { system, light, dark }

class UserSettings {
  final String name;
  final String avatarColor;
  final String? avatarUri;
  final int assignmentReminderDays;
  final int examReminderDays;
  final bool notificationsEnabled;
  final AppThemeMode theme;

  UserSettings({
    required this.name,
    this.avatarColor = '#E8963C',
    this.avatarUri,
    this.assignmentReminderDays = 2,
    this.examReminderDays = 3,
    this.notificationsEnabled = true,
    this.theme = AppThemeMode.system,
  });

  factory UserSettings.defaults() => UserSettings(
    name: 'Student',
    avatarColor: '#E8963C',
    assignmentReminderDays: 2,
    examReminderDays: 3,
    notificationsEnabled: true,
    theme: AppThemeMode.system,
  );

  UserSettings copyWith({
    String? name,
    String? avatarColor,
    String? avatarUri,
    int? assignmentReminderDays,
    int? examReminderDays,
    bool? notificationsEnabled,
    AppThemeMode? theme,
  }) {
    return UserSettings(
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUri: avatarUri ?? this.avatarUri,
      assignmentReminderDays:
          assignmentReminderDays ?? this.assignmentReminderDays,
      examReminderDays: examReminderDays ?? this.examReminderDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatarColor': avatarColor,
    'avatarUri': avatarUri,
    'assignmentReminderDays': assignmentReminderDays,
    'examReminderDays': examReminderDays,
    'notificationsEnabled': notificationsEnabled,
    'theme': theme.name,
  };

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
    name: j['name'] ?? 'Student',
    avatarColor: j['avatarColor'] ?? '#E8963C',
    avatarUri: j['avatarUri'],
    assignmentReminderDays: j['assignmentReminderDays'] ?? 2,
    examReminderDays: j['examReminderDays'] ?? 3,
    notificationsEnabled: j['notificationsEnabled'] ?? true,
    theme: j['theme'] != null
        ? AppThemeMode.values.byName(j['theme'])
        : AppThemeMode.system,
  );
}
