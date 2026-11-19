import '../domain/ids.dart';

/// A course/subject the student takes (Routine tab + Profile > Courses).
class Course {
  final String id;
  final String name;
  final String? code;
  final int? colorTag;
  final String? teacher;
  final String? room;
  final double? credits;
  /// True for built-in example content ("Use examples" seed).
  final bool isSample;

  Course({
    String? id,
    required this.name,
    this.code,
    this.colorTag,
    this.teacher,
    this.room,
    this.credits,
    this.isSample = false,
  }) : id = id ?? newLocalId();

  /// Built-in palette for course color tags.
  static const palette = [
    0xFFE8963C, // Orange
    0xFF4A7C59, // Green
    0xFF3B6EA5, // Blue
    0xFF8B5E9E, // Purple
    0xFFD94F3D, // Red
    0xFF2A9D8F, // Teal
    0xFFC9962A, // Gold
    0xFF6B6057, // Taupe
  ];

  Course copyWith({
    String? name,
    String? code,
    bool clearCode = false,
    int? colorTag,
    bool clearColorTag = false,
    String? teacher,
    bool clearTeacher = false,
    String? room,
    bool clearRoom = false,
    double? credits,
    bool clearCredits = false,
    bool? isSample,
  }) =>
      Course(
        id: id,
        name: name ?? this.name,
        code: clearCode ? null : (code ?? this.code),
        colorTag: clearColorTag ? null : (colorTag ?? this.colorTag),
        teacher: clearTeacher ? null : (teacher ?? this.teacher),
        room: clearRoom ? null : (room ?? this.room),
        credits: clearCredits ? null : (credits ?? this.credits),
        isSample: isSample ?? this.isSample,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (code != null && code!.trim().isNotEmpty && code != 'null') 'code': code,
        if (colorTag != null) 'colorTag': colorTag,
        if (teacher != null && teacher!.trim().isNotEmpty && teacher != 'null') 'teacher': teacher,
        if (room != null && room!.trim().isNotEmpty && room != 'null') 'room': room,
        if (credits != null) 'credits': credits,
        if (isSample) 'isSample': true,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String?,
        name: (j['name'] as String?)?.trim().isNotEmpty == true && j['name'] != 'null'
            ? j['name'] as String
            : 'Class',
        code: (j['code'] as String?)?.trim().isNotEmpty == true && j['code'] != 'null'
            ? j['code'] as String
            : null,
        colorTag: (j['colorTag'] as num?)?.toInt(),
        teacher: (j['teacher'] as String?)?.trim().isNotEmpty == true && j['teacher'] != 'null'
            ? j['teacher'] as String
            : null,
        room: (j['room'] as String?)?.trim().isNotEmpty == true && j['room'] != 'null'
            ? j['room'] as String
            : null,
        credits: (j['credits'] as num?)?.toDouble(),
        isSample: j['isSample'] as bool? ?? false,
      );
}
