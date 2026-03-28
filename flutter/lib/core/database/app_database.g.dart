// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, content, createdAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;
  final String content;
  final DateTime createdAt;
  final bool synced;
  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      content: Value(content),
      createdAt: Value(createdAt),
      synced: Value(synced),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  Note copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    bool? synced,
  }) => Note(
    id: id ?? this.id,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    synced: synced ?? this.synced,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<bool> synced;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
  }) : content = Value(content);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
    });
  }

  NotesCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<bool>? synced,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $OfflineIncidentsTable extends OfflineIncidents
    with TableInfo<$OfflineIncidentsTable, OfflineIncident> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineIncidentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _divisionMeta = const VerificationMeta(
    'division',
  );
  @override
  late final GeneratedColumn<String> division = GeneratedColumn<String>(
    'division',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _projectJobSiteMeta = const VerificationMeta(
    'projectJobSite',
  );
  @override
  late final GeneratedColumn<String> projectJobSite = GeneratedColumn<String>(
    'project_job_site',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _immediateActionsMeta = const VerificationMeta(
    'immediateActions',
  );
  @override
  late final GeneratedColumn<String> immediateActions = GeneratedColumn<String>(
    'immediate_actions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _potentialSeverityMeta = const VerificationMeta(
    'potentialSeverity',
  );
  @override
  late final GeneratedColumn<String> potentialSeverity =
      GeneratedColumn<String>(
        'potential_severity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _shiftMeta = const VerificationMeta('shift');
  @override
  late final GeneratedColumn<String> shift = GeneratedColumn<String>(
    'shift',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _weatherMeta = const VerificationMeta(
    'weather',
  );
  @override
  late final GeneratedColumn<String> weather = GeneratedColumn<String>(
    'weather',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isRailroadPropertyMeta =
      const VerificationMeta('isRailroadProperty');
  @override
  late final GeneratedColumn<bool> isRailroadProperty = GeneratedColumn<bool>(
    'is_railroad_property',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_railroad_property" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _railroadClientMeta = const VerificationMeta(
    'railroadClient',
  );
  @override
  late final GeneratedColumn<String> railroadClient = GeneratedColumn<String>(
    'railroad_client',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _railroadNotifiedMeta = const VerificationMeta(
    'railroadNotified',
  );
  @override
  late final GeneratedColumn<bool> railroadNotified = GeneratedColumn<bool>(
    'railroad_notified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("railroad_notified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _railroadNotificationMethodMeta =
      const VerificationMeta('railroadNotificationMethod');
  @override
  late final GeneratedColumn<String> railroadNotificationMethod =
      GeneratedColumn<String>(
        'railroad_notification_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _injuredPersonsJsonMeta =
      const VerificationMeta('injuredPersonsJson');
  @override
  late final GeneratedColumn<String> injuredPersonsJson =
      GeneratedColumn<String>(
        'injured_persons_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _photoPathsJsonMeta = const VerificationMeta(
    'photoPathsJson',
  );
  @override
  late final GeneratedColumn<String> photoPathsJson = GeneratedColumn<String>(
    'photo_paths_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _isDraftMeta = const VerificationMeta(
    'isDraft',
  );
  @override
  late final GeneratedColumn<bool> isDraft = GeneratedColumn<bool>(
    'is_draft',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_draft" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _reporterIdMeta = const VerificationMeta(
    'reporterId',
  );
  @override
  late final GeneratedColumn<String> reporterId = GeneratedColumn<String>(
    'reporter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    date,
    location,
    latitude,
    longitude,
    division,
    projectJobSite,
    description,
    immediateActions,
    severity,
    potentialSeverity,
    shift,
    weather,
    isRailroadProperty,
    railroadClient,
    railroadNotified,
    railroadNotificationMethod,
    injuredPersonsJson,
    photoPathsJson,
    isDraft,
    reporterId,
    syncStatus,
    syncError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_incidents';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineIncident> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('division')) {
      context.handle(
        _divisionMeta,
        division.isAcceptableOrUnknown(data['division']!, _divisionMeta),
      );
    }
    if (data.containsKey('project_job_site')) {
      context.handle(
        _projectJobSiteMeta,
        projectJobSite.isAcceptableOrUnknown(
          data['project_job_site']!,
          _projectJobSiteMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('immediate_actions')) {
      context.handle(
        _immediateActionsMeta,
        immediateActions.isAcceptableOrUnknown(
          data['immediate_actions']!,
          _immediateActionsMeta,
        ),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('potential_severity')) {
      context.handle(
        _potentialSeverityMeta,
        potentialSeverity.isAcceptableOrUnknown(
          data['potential_severity']!,
          _potentialSeverityMeta,
        ),
      );
    }
    if (data.containsKey('shift')) {
      context.handle(
        _shiftMeta,
        shift.isAcceptableOrUnknown(data['shift']!, _shiftMeta),
      );
    }
    if (data.containsKey('weather')) {
      context.handle(
        _weatherMeta,
        weather.isAcceptableOrUnknown(data['weather']!, _weatherMeta),
      );
    }
    if (data.containsKey('is_railroad_property')) {
      context.handle(
        _isRailroadPropertyMeta,
        isRailroadProperty.isAcceptableOrUnknown(
          data['is_railroad_property']!,
          _isRailroadPropertyMeta,
        ),
      );
    }
    if (data.containsKey('railroad_client')) {
      context.handle(
        _railroadClientMeta,
        railroadClient.isAcceptableOrUnknown(
          data['railroad_client']!,
          _railroadClientMeta,
        ),
      );
    }
    if (data.containsKey('railroad_notified')) {
      context.handle(
        _railroadNotifiedMeta,
        railroadNotified.isAcceptableOrUnknown(
          data['railroad_notified']!,
          _railroadNotifiedMeta,
        ),
      );
    }
    if (data.containsKey('railroad_notification_method')) {
      context.handle(
        _railroadNotificationMethodMeta,
        railroadNotificationMethod.isAcceptableOrUnknown(
          data['railroad_notification_method']!,
          _railroadNotificationMethodMeta,
        ),
      );
    }
    if (data.containsKey('injured_persons_json')) {
      context.handle(
        _injuredPersonsJsonMeta,
        injuredPersonsJson.isAcceptableOrUnknown(
          data['injured_persons_json']!,
          _injuredPersonsJsonMeta,
        ),
      );
    }
    if (data.containsKey('photo_paths_json')) {
      context.handle(
        _photoPathsJsonMeta,
        photoPathsJson.isAcceptableOrUnknown(
          data['photo_paths_json']!,
          _photoPathsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_draft')) {
      context.handle(
        _isDraftMeta,
        isDraft.isAcceptableOrUnknown(data['is_draft']!, _isDraftMeta),
      );
    }
    if (data.containsKey('reporter_id')) {
      context.handle(
        _reporterIdMeta,
        reporterId.isAcceptableOrUnknown(data['reporter_id']!, _reporterIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineIncident map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineIncident(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      division: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}division'],
      )!,
      projectJobSite: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_job_site'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      immediateActions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}immediate_actions'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      potentialSeverity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}potential_severity'],
      )!,
      shift: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift'],
      )!,
      weather: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather'],
      )!,
      isRailroadProperty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_railroad_property'],
      )!,
      railroadClient: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}railroad_client'],
      )!,
      railroadNotified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}railroad_notified'],
      )!,
      railroadNotificationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}railroad_notification_method'],
      )!,
      injuredPersonsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}injured_persons_json'],
      )!,
      photoPathsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_paths_json'],
      )!,
      isDraft: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_draft'],
      )!,
      reporterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reporter_id'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OfflineIncidentsTable createAlias(String alias) {
    return $OfflineIncidentsTable(attachedDatabase, alias);
  }
}

class OfflineIncident extends DataClass implements Insertable<OfflineIncident> {
  /// Local auto-increment ID (not the server ID).
  final int id;
  final String type;
  final DateTime? date;
  final String location;
  final double latitude;
  final double longitude;
  final String division;
  final String projectJobSite;
  final String description;
  final String immediateActions;
  final String severity;
  final String potentialSeverity;
  final String shift;
  final String weather;
  final bool isRailroadProperty;
  final String railroadClient;
  final bool railroadNotified;
  final String railroadNotificationMethod;
  final String injuredPersonsJson;
  final String photoPathsJson;
  final bool isDraft;
  final String reporterId;

  /// Sync lifecycle: pending, syncing, synced, error
  final String syncStatus;

  /// Error message from last failed sync attempt, if any.
  final String syncError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OfflineIncident({
    required this.id,
    required this.type,
    this.date,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.division,
    required this.projectJobSite,
    required this.description,
    required this.immediateActions,
    required this.severity,
    required this.potentialSeverity,
    required this.shift,
    required this.weather,
    required this.isRailroadProperty,
    required this.railroadClient,
    required this.railroadNotified,
    required this.railroadNotificationMethod,
    required this.injuredPersonsJson,
    required this.photoPathsJson,
    required this.isDraft,
    required this.reporterId,
    required this.syncStatus,
    required this.syncError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<DateTime>(date);
    }
    map['location'] = Variable<String>(location);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['division'] = Variable<String>(division);
    map['project_job_site'] = Variable<String>(projectJobSite);
    map['description'] = Variable<String>(description);
    map['immediate_actions'] = Variable<String>(immediateActions);
    map['severity'] = Variable<String>(severity);
    map['potential_severity'] = Variable<String>(potentialSeverity);
    map['shift'] = Variable<String>(shift);
    map['weather'] = Variable<String>(weather);
    map['is_railroad_property'] = Variable<bool>(isRailroadProperty);
    map['railroad_client'] = Variable<String>(railroadClient);
    map['railroad_notified'] = Variable<bool>(railroadNotified);
    map['railroad_notification_method'] = Variable<String>(
      railroadNotificationMethod,
    );
    map['injured_persons_json'] = Variable<String>(injuredPersonsJson);
    map['photo_paths_json'] = Variable<String>(photoPathsJson);
    map['is_draft'] = Variable<bool>(isDraft);
    map['reporter_id'] = Variable<String>(reporterId);
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_error'] = Variable<String>(syncError);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OfflineIncidentsCompanion toCompanion(bool nullToAbsent) {
    return OfflineIncidentsCompanion(
      id: Value(id),
      type: Value(type),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      location: Value(location),
      latitude: Value(latitude),
      longitude: Value(longitude),
      division: Value(division),
      projectJobSite: Value(projectJobSite),
      description: Value(description),
      immediateActions: Value(immediateActions),
      severity: Value(severity),
      potentialSeverity: Value(potentialSeverity),
      shift: Value(shift),
      weather: Value(weather),
      isRailroadProperty: Value(isRailroadProperty),
      railroadClient: Value(railroadClient),
      railroadNotified: Value(railroadNotified),
      railroadNotificationMethod: Value(railroadNotificationMethod),
      injuredPersonsJson: Value(injuredPersonsJson),
      photoPathsJson: Value(photoPathsJson),
      isDraft: Value(isDraft),
      reporterId: Value(reporterId),
      syncStatus: Value(syncStatus),
      syncError: Value(syncError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfflineIncident.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineIncident(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      date: serializer.fromJson<DateTime?>(json['date']),
      location: serializer.fromJson<String>(json['location']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      division: serializer.fromJson<String>(json['division']),
      projectJobSite: serializer.fromJson<String>(json['projectJobSite']),
      description: serializer.fromJson<String>(json['description']),
      immediateActions: serializer.fromJson<String>(json['immediateActions']),
      severity: serializer.fromJson<String>(json['severity']),
      potentialSeverity: serializer.fromJson<String>(json['potentialSeverity']),
      shift: serializer.fromJson<String>(json['shift']),
      weather: serializer.fromJson<String>(json['weather']),
      isRailroadProperty: serializer.fromJson<bool>(json['isRailroadProperty']),
      railroadClient: serializer.fromJson<String>(json['railroadClient']),
      railroadNotified: serializer.fromJson<bool>(json['railroadNotified']),
      railroadNotificationMethod: serializer.fromJson<String>(
        json['railroadNotificationMethod'],
      ),
      injuredPersonsJson: serializer.fromJson<String>(
        json['injuredPersonsJson'],
      ),
      photoPathsJson: serializer.fromJson<String>(json['photoPathsJson']),
      isDraft: serializer.fromJson<bool>(json['isDraft']),
      reporterId: serializer.fromJson<String>(json['reporterId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncError: serializer.fromJson<String>(json['syncError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'date': serializer.toJson<DateTime?>(date),
      'location': serializer.toJson<String>(location),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'division': serializer.toJson<String>(division),
      'projectJobSite': serializer.toJson<String>(projectJobSite),
      'description': serializer.toJson<String>(description),
      'immediateActions': serializer.toJson<String>(immediateActions),
      'severity': serializer.toJson<String>(severity),
      'potentialSeverity': serializer.toJson<String>(potentialSeverity),
      'shift': serializer.toJson<String>(shift),
      'weather': serializer.toJson<String>(weather),
      'isRailroadProperty': serializer.toJson<bool>(isRailroadProperty),
      'railroadClient': serializer.toJson<String>(railroadClient),
      'railroadNotified': serializer.toJson<bool>(railroadNotified),
      'railroadNotificationMethod': serializer.toJson<String>(
        railroadNotificationMethod,
      ),
      'injuredPersonsJson': serializer.toJson<String>(injuredPersonsJson),
      'photoPathsJson': serializer.toJson<String>(photoPathsJson),
      'isDraft': serializer.toJson<bool>(isDraft),
      'reporterId': serializer.toJson<String>(reporterId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncError': serializer.toJson<String>(syncError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfflineIncident copyWith({
    int? id,
    String? type,
    Value<DateTime?> date = const Value.absent(),
    String? location,
    double? latitude,
    double? longitude,
    String? division,
    String? projectJobSite,
    String? description,
    String? immediateActions,
    String? severity,
    String? potentialSeverity,
    String? shift,
    String? weather,
    bool? isRailroadProperty,
    String? railroadClient,
    bool? railroadNotified,
    String? railroadNotificationMethod,
    String? injuredPersonsJson,
    String? photoPathsJson,
    bool? isDraft,
    String? reporterId,
    String? syncStatus,
    String? syncError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OfflineIncident(
    id: id ?? this.id,
    type: type ?? this.type,
    date: date.present ? date.value : this.date,
    location: location ?? this.location,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    division: division ?? this.division,
    projectJobSite: projectJobSite ?? this.projectJobSite,
    description: description ?? this.description,
    immediateActions: immediateActions ?? this.immediateActions,
    severity: severity ?? this.severity,
    potentialSeverity: potentialSeverity ?? this.potentialSeverity,
    shift: shift ?? this.shift,
    weather: weather ?? this.weather,
    isRailroadProperty: isRailroadProperty ?? this.isRailroadProperty,
    railroadClient: railroadClient ?? this.railroadClient,
    railroadNotified: railroadNotified ?? this.railroadNotified,
    railroadNotificationMethod:
        railroadNotificationMethod ?? this.railroadNotificationMethod,
    injuredPersonsJson: injuredPersonsJson ?? this.injuredPersonsJson,
    photoPathsJson: photoPathsJson ?? this.photoPathsJson,
    isDraft: isDraft ?? this.isDraft,
    reporterId: reporterId ?? this.reporterId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError ?? this.syncError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OfflineIncident copyWithCompanion(OfflineIncidentsCompanion data) {
    return OfflineIncident(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      location: data.location.present ? data.location.value : this.location,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      division: data.division.present ? data.division.value : this.division,
      projectJobSite: data.projectJobSite.present
          ? data.projectJobSite.value
          : this.projectJobSite,
      description: data.description.present
          ? data.description.value
          : this.description,
      immediateActions: data.immediateActions.present
          ? data.immediateActions.value
          : this.immediateActions,
      severity: data.severity.present ? data.severity.value : this.severity,
      potentialSeverity: data.potentialSeverity.present
          ? data.potentialSeverity.value
          : this.potentialSeverity,
      shift: data.shift.present ? data.shift.value : this.shift,
      weather: data.weather.present ? data.weather.value : this.weather,
      isRailroadProperty: data.isRailroadProperty.present
          ? data.isRailroadProperty.value
          : this.isRailroadProperty,
      railroadClient: data.railroadClient.present
          ? data.railroadClient.value
          : this.railroadClient,
      railroadNotified: data.railroadNotified.present
          ? data.railroadNotified.value
          : this.railroadNotified,
      railroadNotificationMethod: data.railroadNotificationMethod.present
          ? data.railroadNotificationMethod.value
          : this.railroadNotificationMethod,
      injuredPersonsJson: data.injuredPersonsJson.present
          ? data.injuredPersonsJson.value
          : this.injuredPersonsJson,
      photoPathsJson: data.photoPathsJson.present
          ? data.photoPathsJson.value
          : this.photoPathsJson,
      isDraft: data.isDraft.present ? data.isDraft.value : this.isDraft,
      reporterId: data.reporterId.present
          ? data.reporterId.value
          : this.reporterId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineIncident(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('location: $location, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('division: $division, ')
          ..write('projectJobSite: $projectJobSite, ')
          ..write('description: $description, ')
          ..write('immediateActions: $immediateActions, ')
          ..write('severity: $severity, ')
          ..write('potentialSeverity: $potentialSeverity, ')
          ..write('shift: $shift, ')
          ..write('weather: $weather, ')
          ..write('isRailroadProperty: $isRailroadProperty, ')
          ..write('railroadClient: $railroadClient, ')
          ..write('railroadNotified: $railroadNotified, ')
          ..write('railroadNotificationMethod: $railroadNotificationMethod, ')
          ..write('injuredPersonsJson: $injuredPersonsJson, ')
          ..write('photoPathsJson: $photoPathsJson, ')
          ..write('isDraft: $isDraft, ')
          ..write('reporterId: $reporterId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    date,
    location,
    latitude,
    longitude,
    division,
    projectJobSite,
    description,
    immediateActions,
    severity,
    potentialSeverity,
    shift,
    weather,
    isRailroadProperty,
    railroadClient,
    railroadNotified,
    railroadNotificationMethod,
    injuredPersonsJson,
    photoPathsJson,
    isDraft,
    reporterId,
    syncStatus,
    syncError,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineIncident &&
          other.id == this.id &&
          other.type == this.type &&
          other.date == this.date &&
          other.location == this.location &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.division == this.division &&
          other.projectJobSite == this.projectJobSite &&
          other.description == this.description &&
          other.immediateActions == this.immediateActions &&
          other.severity == this.severity &&
          other.potentialSeverity == this.potentialSeverity &&
          other.shift == this.shift &&
          other.weather == this.weather &&
          other.isRailroadProperty == this.isRailroadProperty &&
          other.railroadClient == this.railroadClient &&
          other.railroadNotified == this.railroadNotified &&
          other.railroadNotificationMethod == this.railroadNotificationMethod &&
          other.injuredPersonsJson == this.injuredPersonsJson &&
          other.photoPathsJson == this.photoPathsJson &&
          other.isDraft == this.isDraft &&
          other.reporterId == this.reporterId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OfflineIncidentsCompanion extends UpdateCompanion<OfflineIncident> {
  final Value<int> id;
  final Value<String> type;
  final Value<DateTime?> date;
  final Value<String> location;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> division;
  final Value<String> projectJobSite;
  final Value<String> description;
  final Value<String> immediateActions;
  final Value<String> severity;
  final Value<String> potentialSeverity;
  final Value<String> shift;
  final Value<String> weather;
  final Value<bool> isRailroadProperty;
  final Value<String> railroadClient;
  final Value<bool> railroadNotified;
  final Value<String> railroadNotificationMethod;
  final Value<String> injuredPersonsJson;
  final Value<String> photoPathsJson;
  final Value<bool> isDraft;
  final Value<String> reporterId;
  final Value<String> syncStatus;
  final Value<String> syncError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const OfflineIncidentsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.location = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.division = const Value.absent(),
    this.projectJobSite = const Value.absent(),
    this.description = const Value.absent(),
    this.immediateActions = const Value.absent(),
    this.severity = const Value.absent(),
    this.potentialSeverity = const Value.absent(),
    this.shift = const Value.absent(),
    this.weather = const Value.absent(),
    this.isRailroadProperty = const Value.absent(),
    this.railroadClient = const Value.absent(),
    this.railroadNotified = const Value.absent(),
    this.railroadNotificationMethod = const Value.absent(),
    this.injuredPersonsJson = const Value.absent(),
    this.photoPathsJson = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.reporterId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OfflineIncidentsCompanion.insert({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.location = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.division = const Value.absent(),
    this.projectJobSite = const Value.absent(),
    this.description = const Value.absent(),
    this.immediateActions = const Value.absent(),
    this.severity = const Value.absent(),
    this.potentialSeverity = const Value.absent(),
    this.shift = const Value.absent(),
    this.weather = const Value.absent(),
    this.isRailroadProperty = const Value.absent(),
    this.railroadClient = const Value.absent(),
    this.railroadNotified = const Value.absent(),
    this.railroadNotificationMethod = const Value.absent(),
    this.injuredPersonsJson = const Value.absent(),
    this.photoPathsJson = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.reporterId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<OfflineIncident> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<DateTime>? date,
    Expression<String>? location,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? division,
    Expression<String>? projectJobSite,
    Expression<String>? description,
    Expression<String>? immediateActions,
    Expression<String>? severity,
    Expression<String>? potentialSeverity,
    Expression<String>? shift,
    Expression<String>? weather,
    Expression<bool>? isRailroadProperty,
    Expression<String>? railroadClient,
    Expression<bool>? railroadNotified,
    Expression<String>? railroadNotificationMethod,
    Expression<String>? injuredPersonsJson,
    Expression<String>? photoPathsJson,
    Expression<bool>? isDraft,
    Expression<String>? reporterId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (division != null) 'division': division,
      if (projectJobSite != null) 'project_job_site': projectJobSite,
      if (description != null) 'description': description,
      if (immediateActions != null) 'immediate_actions': immediateActions,
      if (severity != null) 'severity': severity,
      if (potentialSeverity != null) 'potential_severity': potentialSeverity,
      if (shift != null) 'shift': shift,
      if (weather != null) 'weather': weather,
      if (isRailroadProperty != null)
        'is_railroad_property': isRailroadProperty,
      if (railroadClient != null) 'railroad_client': railroadClient,
      if (railroadNotified != null) 'railroad_notified': railroadNotified,
      if (railroadNotificationMethod != null)
        'railroad_notification_method': railroadNotificationMethod,
      if (injuredPersonsJson != null)
        'injured_persons_json': injuredPersonsJson,
      if (photoPathsJson != null) 'photo_paths_json': photoPathsJson,
      if (isDraft != null) 'is_draft': isDraft,
      if (reporterId != null) 'reporter_id': reporterId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OfflineIncidentsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<DateTime?>? date,
    Value<String>? location,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? division,
    Value<String>? projectJobSite,
    Value<String>? description,
    Value<String>? immediateActions,
    Value<String>? severity,
    Value<String>? potentialSeverity,
    Value<String>? shift,
    Value<String>? weather,
    Value<bool>? isRailroadProperty,
    Value<String>? railroadClient,
    Value<bool>? railroadNotified,
    Value<String>? railroadNotificationMethod,
    Value<String>? injuredPersonsJson,
    Value<String>? photoPathsJson,
    Value<bool>? isDraft,
    Value<String>? reporterId,
    Value<String>? syncStatus,
    Value<String>? syncError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return OfflineIncidentsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      division: division ?? this.division,
      projectJobSite: projectJobSite ?? this.projectJobSite,
      description: description ?? this.description,
      immediateActions: immediateActions ?? this.immediateActions,
      severity: severity ?? this.severity,
      potentialSeverity: potentialSeverity ?? this.potentialSeverity,
      shift: shift ?? this.shift,
      weather: weather ?? this.weather,
      isRailroadProperty: isRailroadProperty ?? this.isRailroadProperty,
      railroadClient: railroadClient ?? this.railroadClient,
      railroadNotified: railroadNotified ?? this.railroadNotified,
      railroadNotificationMethod:
          railroadNotificationMethod ?? this.railroadNotificationMethod,
      injuredPersonsJson: injuredPersonsJson ?? this.injuredPersonsJson,
      photoPathsJson: photoPathsJson ?? this.photoPathsJson,
      isDraft: isDraft ?? this.isDraft,
      reporterId: reporterId ?? this.reporterId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (division.present) {
      map['division'] = Variable<String>(division.value);
    }
    if (projectJobSite.present) {
      map['project_job_site'] = Variable<String>(projectJobSite.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (immediateActions.present) {
      map['immediate_actions'] = Variable<String>(immediateActions.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (potentialSeverity.present) {
      map['potential_severity'] = Variable<String>(potentialSeverity.value);
    }
    if (shift.present) {
      map['shift'] = Variable<String>(shift.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(weather.value);
    }
    if (isRailroadProperty.present) {
      map['is_railroad_property'] = Variable<bool>(isRailroadProperty.value);
    }
    if (railroadClient.present) {
      map['railroad_client'] = Variable<String>(railroadClient.value);
    }
    if (railroadNotified.present) {
      map['railroad_notified'] = Variable<bool>(railroadNotified.value);
    }
    if (railroadNotificationMethod.present) {
      map['railroad_notification_method'] = Variable<String>(
        railroadNotificationMethod.value,
      );
    }
    if (injuredPersonsJson.present) {
      map['injured_persons_json'] = Variable<String>(injuredPersonsJson.value);
    }
    if (photoPathsJson.present) {
      map['photo_paths_json'] = Variable<String>(photoPathsJson.value);
    }
    if (isDraft.present) {
      map['is_draft'] = Variable<bool>(isDraft.value);
    }
    if (reporterId.present) {
      map['reporter_id'] = Variable<String>(reporterId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineIncidentsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('location: $location, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('division: $division, ')
          ..write('projectJobSite: $projectJobSite, ')
          ..write('description: $description, ')
          ..write('immediateActions: $immediateActions, ')
          ..write('severity: $severity, ')
          ..write('potentialSeverity: $potentialSeverity, ')
          ..write('shift: $shift, ')
          ..write('weather: $weather, ')
          ..write('isRailroadProperty: $isRailroadProperty, ')
          ..write('railroadClient: $railroadClient, ')
          ..write('railroadNotified: $railroadNotified, ')
          ..write('railroadNotificationMethod: $railroadNotificationMethod, ')
          ..write('injuredPersonsJson: $injuredPersonsJson, ')
          ..write('photoPathsJson: $photoPathsJson, ')
          ..write('isDraft: $isDraft, ')
          ..write('reporterId: $reporterId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $OfflineIncidentsTable offlineIncidents = $OfflineIncidentsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notes, offlineIncidents];
}

typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      required String content,
      Value<DateTime> createdAt,
      Value<bool> synced,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<int> id,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<bool> synced,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                content: content,
                createdAt: createdAt,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String content,
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                content: content,
                createdAt: createdAt,
                synced: synced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$OfflineIncidentsTableCreateCompanionBuilder =
    OfflineIncidentsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<DateTime?> date,
      Value<String> location,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> division,
      Value<String> projectJobSite,
      Value<String> description,
      Value<String> immediateActions,
      Value<String> severity,
      Value<String> potentialSeverity,
      Value<String> shift,
      Value<String> weather,
      Value<bool> isRailroadProperty,
      Value<String> railroadClient,
      Value<bool> railroadNotified,
      Value<String> railroadNotificationMethod,
      Value<String> injuredPersonsJson,
      Value<String> photoPathsJson,
      Value<bool> isDraft,
      Value<String> reporterId,
      Value<String> syncStatus,
      Value<String> syncError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$OfflineIncidentsTableUpdateCompanionBuilder =
    OfflineIncidentsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<DateTime?> date,
      Value<String> location,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> division,
      Value<String> projectJobSite,
      Value<String> description,
      Value<String> immediateActions,
      Value<String> severity,
      Value<String> potentialSeverity,
      Value<String> shift,
      Value<String> weather,
      Value<bool> isRailroadProperty,
      Value<String> railroadClient,
      Value<bool> railroadNotified,
      Value<String> railroadNotificationMethod,
      Value<String> injuredPersonsJson,
      Value<String> photoPathsJson,
      Value<bool> isDraft,
      Value<String> reporterId,
      Value<String> syncStatus,
      Value<String> syncError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$OfflineIncidentsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineIncidentsTable> {
  $$OfflineIncidentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectJobSite => $composableBuilder(
    column: $table.projectJobSite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get immediateActions => $composableBuilder(
    column: $table.immediateActions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get potentialSeverity => $composableBuilder(
    column: $table.potentialSeverity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shift => $composableBuilder(
    column: $table.shift,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRailroadProperty => $composableBuilder(
    column: $table.isRailroadProperty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get railroadClient => $composableBuilder(
    column: $table.railroadClient,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get railroadNotified => $composableBuilder(
    column: $table.railroadNotified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get railroadNotificationMethod => $composableBuilder(
    column: $table.railroadNotificationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get injuredPersonsJson => $composableBuilder(
    column: $table.injuredPersonsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPathsJson => $composableBuilder(
    column: $table.photoPathsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDraft => $composableBuilder(
    column: $table.isDraft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reporterId => $composableBuilder(
    column: $table.reporterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineIncidentsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineIncidentsTable> {
  $$OfflineIncidentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get division => $composableBuilder(
    column: $table.division,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectJobSite => $composableBuilder(
    column: $table.projectJobSite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get immediateActions => $composableBuilder(
    column: $table.immediateActions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get potentialSeverity => $composableBuilder(
    column: $table.potentialSeverity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shift => $composableBuilder(
    column: $table.shift,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRailroadProperty => $composableBuilder(
    column: $table.isRailroadProperty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get railroadClient => $composableBuilder(
    column: $table.railroadClient,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get railroadNotified => $composableBuilder(
    column: $table.railroadNotified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get railroadNotificationMethod => $composableBuilder(
    column: $table.railroadNotificationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get injuredPersonsJson => $composableBuilder(
    column: $table.injuredPersonsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPathsJson => $composableBuilder(
    column: $table.photoPathsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDraft => $composableBuilder(
    column: $table.isDraft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reporterId => $composableBuilder(
    column: $table.reporterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineIncidentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineIncidentsTable> {
  $$OfflineIncidentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get division =>
      $composableBuilder(column: $table.division, builder: (column) => column);

  GeneratedColumn<String> get projectJobSite => $composableBuilder(
    column: $table.projectJobSite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get immediateActions => $composableBuilder(
    column: $table.immediateActions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get potentialSeverity => $composableBuilder(
    column: $table.potentialSeverity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shift =>
      $composableBuilder(column: $table.shift, builder: (column) => column);

  GeneratedColumn<String> get weather =>
      $composableBuilder(column: $table.weather, builder: (column) => column);

  GeneratedColumn<bool> get isRailroadProperty => $composableBuilder(
    column: $table.isRailroadProperty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get railroadClient => $composableBuilder(
    column: $table.railroadClient,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get railroadNotified => $composableBuilder(
    column: $table.railroadNotified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get railroadNotificationMethod => $composableBuilder(
    column: $table.railroadNotificationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get injuredPersonsJson => $composableBuilder(
    column: $table.injuredPersonsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPathsJson => $composableBuilder(
    column: $table.photoPathsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDraft =>
      $composableBuilder(column: $table.isDraft, builder: (column) => column);

  GeneratedColumn<String> get reporterId => $composableBuilder(
    column: $table.reporterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfflineIncidentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineIncidentsTable,
          OfflineIncident,
          $$OfflineIncidentsTableFilterComposer,
          $$OfflineIncidentsTableOrderingComposer,
          $$OfflineIncidentsTableAnnotationComposer,
          $$OfflineIncidentsTableCreateCompanionBuilder,
          $$OfflineIncidentsTableUpdateCompanionBuilder,
          (
            OfflineIncident,
            BaseReferences<
              _$AppDatabase,
              $OfflineIncidentsTable,
              OfflineIncident
            >,
          ),
          OfflineIncident,
          PrefetchHooks Function()
        > {
  $$OfflineIncidentsTableTableManager(
    _$AppDatabase db,
    $OfflineIncidentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineIncidentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineIncidentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineIncidentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime?> date = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> division = const Value.absent(),
                Value<String> projectJobSite = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> immediateActions = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<String> potentialSeverity = const Value.absent(),
                Value<String> shift = const Value.absent(),
                Value<String> weather = const Value.absent(),
                Value<bool> isRailroadProperty = const Value.absent(),
                Value<String> railroadClient = const Value.absent(),
                Value<bool> railroadNotified = const Value.absent(),
                Value<String> railroadNotificationMethod = const Value.absent(),
                Value<String> injuredPersonsJson = const Value.absent(),
                Value<String> photoPathsJson = const Value.absent(),
                Value<bool> isDraft = const Value.absent(),
                Value<String> reporterId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String> syncError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OfflineIncidentsCompanion(
                id: id,
                type: type,
                date: date,
                location: location,
                latitude: latitude,
                longitude: longitude,
                division: division,
                projectJobSite: projectJobSite,
                description: description,
                immediateActions: immediateActions,
                severity: severity,
                potentialSeverity: potentialSeverity,
                shift: shift,
                weather: weather,
                isRailroadProperty: isRailroadProperty,
                railroadClient: railroadClient,
                railroadNotified: railroadNotified,
                railroadNotificationMethod: railroadNotificationMethod,
                injuredPersonsJson: injuredPersonsJson,
                photoPathsJson: photoPathsJson,
                isDraft: isDraft,
                reporterId: reporterId,
                syncStatus: syncStatus,
                syncError: syncError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime?> date = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> division = const Value.absent(),
                Value<String> projectJobSite = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> immediateActions = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<String> potentialSeverity = const Value.absent(),
                Value<String> shift = const Value.absent(),
                Value<String> weather = const Value.absent(),
                Value<bool> isRailroadProperty = const Value.absent(),
                Value<String> railroadClient = const Value.absent(),
                Value<bool> railroadNotified = const Value.absent(),
                Value<String> railroadNotificationMethod = const Value.absent(),
                Value<String> injuredPersonsJson = const Value.absent(),
                Value<String> photoPathsJson = const Value.absent(),
                Value<bool> isDraft = const Value.absent(),
                Value<String> reporterId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String> syncError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OfflineIncidentsCompanion.insert(
                id: id,
                type: type,
                date: date,
                location: location,
                latitude: latitude,
                longitude: longitude,
                division: division,
                projectJobSite: projectJobSite,
                description: description,
                immediateActions: immediateActions,
                severity: severity,
                potentialSeverity: potentialSeverity,
                shift: shift,
                weather: weather,
                isRailroadProperty: isRailroadProperty,
                railroadClient: railroadClient,
                railroadNotified: railroadNotified,
                railroadNotificationMethod: railroadNotificationMethod,
                injuredPersonsJson: injuredPersonsJson,
                photoPathsJson: photoPathsJson,
                isDraft: isDraft,
                reporterId: reporterId,
                syncStatus: syncStatus,
                syncError: syncError,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineIncidentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineIncidentsTable,
      OfflineIncident,
      $$OfflineIncidentsTableFilterComposer,
      $$OfflineIncidentsTableOrderingComposer,
      $$OfflineIncidentsTableAnnotationComposer,
      $$OfflineIncidentsTableCreateCompanionBuilder,
      $$OfflineIncidentsTableUpdateCompanionBuilder,
      (
        OfflineIncident,
        BaseReferences<_$AppDatabase, $OfflineIncidentsTable, OfflineIncident>,
      ),
      OfflineIncident,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$OfflineIncidentsTableTableManager get offlineIncidents =>
      $$OfflineIncidentsTableTableManager(_db, _db.offlineIncidents);
}
