// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RulesTable extends Rules with TableInfo<$RulesTable, Rule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _matchTypeMeta = const VerificationMeta(
    'matchType',
  );
  @override
  late final GeneratedColumn<int> matchType = GeneratedColumn<int>(
    'match_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(50),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _radiusMeta = const VerificationMeta('radius');
  @override
  late final GeneratedColumn<int> radius = GeneratedColumn<int>(
    'radius',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowStarredContactsMeta =
      const VerificationMeta('allowStarredContacts');
  @override
  late final GeneratedColumn<bool> allowStarredContacts = GeneratedColumn<bool>(
    'allow_starred_contacts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_starred_contacts" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allowRepeatCallersMeta =
      const VerificationMeta('allowRepeatCallers');
  @override
  late final GeneratedColumn<bool> allowRepeatCallers = GeneratedColumn<bool>(
    'allow_repeat_callers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_repeat_callers" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isEnabled,
    matchType,
    priority,
    type,
    startTime,
    endTime,
    latitude,
    longitude,
    radius,
    packageName,
    activityType,
    allowStarredContacts,
    allowRepeatCallers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<Rule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('match_type')) {
      context.handle(
        _matchTypeMeta,
        matchType.isAcceptableOrUnknown(data['match_type']!, _matchTypeMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
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
    if (data.containsKey('radius')) {
      context.handle(
        _radiusMeta,
        radius.isAcceptableOrUnknown(data['radius']!, _radiusMeta),
      );
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('allow_starred_contacts')) {
      context.handle(
        _allowStarredContactsMeta,
        allowStarredContacts.isAcceptableOrUnknown(
          data['allow_starred_contacts']!,
          _allowStarredContactsMeta,
        ),
      );
    }
    if (data.containsKey('allow_repeat_callers')) {
      context.handle(
        _allowRepeatCallersMeta,
        allowRepeatCallers.isAcceptableOrUnknown(
          data['allow_repeat_callers']!,
          _allowRepeatCallersMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Rule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Rule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      matchType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_type'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      radius: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius'],
      ),
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      ),
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      ),
      allowStarredContacts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_starred_contacts'],
      )!,
      allowRepeatCallers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_repeat_callers'],
      )!,
    );
  }

  @override
  $RulesTable createAlias(String alias) {
    return $RulesTable(attachedDatabase, alias);
  }
}

class Rule extends DataClass implements Insertable<Rule> {
  final int id;
  final String name;
  final bool isEnabled;
  final int matchType;
  final int priority;
  final int type;
  final String? startTime;
  final String? endTime;
  final double? latitude;
  final double? longitude;
  final int? radius;
  final String? packageName;
  final String? activityType;
  final bool allowStarredContacts;
  final bool allowRepeatCallers;
  const Rule({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.matchType,
    required this.priority,
    required this.type,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
    this.radius,
    this.packageName,
    this.activityType,
    required this.allowStarredContacts,
    required this.allowRepeatCallers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['match_type'] = Variable<int>(matchType);
    map['priority'] = Variable<int>(priority);
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || radius != null) {
      map['radius'] = Variable<int>(radius);
    }
    if (!nullToAbsent || packageName != null) {
      map['package_name'] = Variable<String>(packageName);
    }
    if (!nullToAbsent || activityType != null) {
      map['activity_type'] = Variable<String>(activityType);
    }
    map['allow_starred_contacts'] = Variable<bool>(allowStarredContacts);
    map['allow_repeat_callers'] = Variable<bool>(allowRepeatCallers);
    return map;
  }

  RulesCompanion toCompanion(bool nullToAbsent) {
    return RulesCompanion(
      id: Value(id),
      name: Value(name),
      isEnabled: Value(isEnabled),
      matchType: Value(matchType),
      priority: Value(priority),
      type: Value(type),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      radius: radius == null && nullToAbsent
          ? const Value.absent()
          : Value(radius),
      packageName: packageName == null && nullToAbsent
          ? const Value.absent()
          : Value(packageName),
      activityType: activityType == null && nullToAbsent
          ? const Value.absent()
          : Value(activityType),
      allowStarredContacts: Value(allowStarredContacts),
      allowRepeatCallers: Value(allowRepeatCallers),
    );
  }

  factory Rule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Rule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      matchType: serializer.fromJson<int>(json['matchType']),
      priority: serializer.fromJson<int>(json['priority']),
      type: serializer.fromJson<int>(json['type']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      radius: serializer.fromJson<int?>(json['radius']),
      packageName: serializer.fromJson<String?>(json['packageName']),
      activityType: serializer.fromJson<String?>(json['activityType']),
      allowStarredContacts: serializer.fromJson<bool>(
        json['allowStarredContacts'],
      ),
      allowRepeatCallers: serializer.fromJson<bool>(json['allowRepeatCallers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'matchType': serializer.toJson<int>(matchType),
      'priority': serializer.toJson<int>(priority),
      'type': serializer.toJson<int>(type),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'radius': serializer.toJson<int?>(radius),
      'packageName': serializer.toJson<String?>(packageName),
      'activityType': serializer.toJson<String?>(activityType),
      'allowStarredContacts': serializer.toJson<bool>(allowStarredContacts),
      'allowRepeatCallers': serializer.toJson<bool>(allowRepeatCallers),
    };
  }

  Rule copyWith({
    int? id,
    String? name,
    bool? isEnabled,
    int? matchType,
    int? priority,
    int? type,
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<int?> radius = const Value.absent(),
    Value<String?> packageName = const Value.absent(),
    Value<String?> activityType = const Value.absent(),
    bool? allowStarredContacts,
    bool? allowRepeatCallers,
  }) => Rule(
    id: id ?? this.id,
    name: name ?? this.name,
    isEnabled: isEnabled ?? this.isEnabled,
    matchType: matchType ?? this.matchType,
    priority: priority ?? this.priority,
    type: type ?? this.type,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    radius: radius.present ? radius.value : this.radius,
    packageName: packageName.present ? packageName.value : this.packageName,
    activityType: activityType.present ? activityType.value : this.activityType,
    allowStarredContacts: allowStarredContacts ?? this.allowStarredContacts,
    allowRepeatCallers: allowRepeatCallers ?? this.allowRepeatCallers,
  );
  Rule copyWithCompanion(RulesCompanion data) {
    return Rule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      matchType: data.matchType.present ? data.matchType.value : this.matchType,
      priority: data.priority.present ? data.priority.value : this.priority,
      type: data.type.present ? data.type.value : this.type,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radius: data.radius.present ? data.radius.value : this.radius,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      allowStarredContacts: data.allowStarredContacts.present
          ? data.allowStarredContacts.value
          : this.allowStarredContacts,
      allowRepeatCallers: data.allowRepeatCallers.present
          ? data.allowRepeatCallers.value
          : this.allowRepeatCallers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Rule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('matchType: $matchType, ')
          ..write('priority: $priority, ')
          ..write('type: $type, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('packageName: $packageName, ')
          ..write('activityType: $activityType, ')
          ..write('allowStarredContacts: $allowStarredContacts, ')
          ..write('allowRepeatCallers: $allowRepeatCallers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isEnabled,
    matchType,
    priority,
    type,
    startTime,
    endTime,
    latitude,
    longitude,
    radius,
    packageName,
    activityType,
    allowStarredContacts,
    allowRepeatCallers,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rule &&
          other.id == this.id &&
          other.name == this.name &&
          other.isEnabled == this.isEnabled &&
          other.matchType == this.matchType &&
          other.priority == this.priority &&
          other.type == this.type &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radius == this.radius &&
          other.packageName == this.packageName &&
          other.activityType == this.activityType &&
          other.allowStarredContacts == this.allowStarredContacts &&
          other.allowRepeatCallers == this.allowRepeatCallers);
}

class RulesCompanion extends UpdateCompanion<Rule> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isEnabled;
  final Value<int> matchType;
  final Value<int> priority;
  final Value<int> type;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int?> radius;
  final Value<String?> packageName;
  final Value<String?> activityType;
  final Value<bool> allowStarredContacts;
  final Value<bool> allowRepeatCallers;
  const RulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.matchType = const Value.absent(),
    this.priority = const Value.absent(),
    this.type = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.packageName = const Value.absent(),
    this.activityType = const Value.absent(),
    this.allowStarredContacts = const Value.absent(),
    this.allowRepeatCallers = const Value.absent(),
  });
  RulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isEnabled = const Value.absent(),
    this.matchType = const Value.absent(),
    this.priority = const Value.absent(),
    required int type,
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.packageName = const Value.absent(),
    this.activityType = const Value.absent(),
    this.allowStarredContacts = const Value.absent(),
    this.allowRepeatCallers = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<Rule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isEnabled,
    Expression<int>? matchType,
    Expression<int>? priority,
    Expression<int>? type,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? radius,
    Expression<String>? packageName,
    Expression<String>? activityType,
    Expression<bool>? allowStarredContacts,
    Expression<bool>? allowRepeatCallers,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (matchType != null) 'match_type': matchType,
      if (priority != null) 'priority': priority,
      if (type != null) 'type': type,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radius != null) 'radius': radius,
      if (packageName != null) 'package_name': packageName,
      if (activityType != null) 'activity_type': activityType,
      if (allowStarredContacts != null)
        'allow_starred_contacts': allowStarredContacts,
      if (allowRepeatCallers != null)
        'allow_repeat_callers': allowRepeatCallers,
    });
  }

  RulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isEnabled,
    Value<int>? matchType,
    Value<int>? priority,
    Value<int>? type,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<int?>? radius,
    Value<String?>? packageName,
    Value<String?>? activityType,
    Value<bool>? allowStarredContacts,
    Value<bool>? allowRepeatCallers,
  }) {
    return RulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      matchType: matchType ?? this.matchType,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      packageName: packageName ?? this.packageName,
      activityType: activityType ?? this.activityType,
      allowStarredContacts: allowStarredContacts ?? this.allowStarredContacts,
      allowRepeatCallers: allowRepeatCallers ?? this.allowRepeatCallers,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (matchType.present) {
      map['match_type'] = Variable<int>(matchType.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radius.present) {
      map['radius'] = Variable<int>(radius.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (allowStarredContacts.present) {
      map['allow_starred_contacts'] = Variable<bool>(
        allowStarredContacts.value,
      );
    }
    if (allowRepeatCallers.present) {
      map['allow_repeat_callers'] = Variable<bool>(allowRepeatCallers.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('matchType: $matchType, ')
          ..write('priority: $priority, ')
          ..write('type: $type, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('packageName: $packageName, ')
          ..write('activityType: $activityType, ')
          ..write('allowStarredContacts: $allowStarredContacts, ')
          ..write('allowRepeatCallers: $allowRepeatCallers')
          ..write(')'))
        .toString();
  }
}

class $RuleTriggersTable extends RuleTriggers
    with TableInfo<$RuleTriggersTable, RuleTrigger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleTriggersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<int> ruleId = GeneratedColumn<int>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerTypeMeta = const VerificationMeta(
    'triggerType',
  );
  @override
  late final GeneratedColumn<int> triggerType = GeneratedColumn<int>(
    'trigger_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _radiusMeta = const VerificationMeta('radius');
  @override
  late final GeneratedColumn<double> radius = GeneratedColumn<double>(
    'radius',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarKeywordMeta = const VerificationMeta(
    'calendarKeyword',
  );
  @override
  late final GeneratedColumn<String> calendarKeyword = GeneratedColumn<String>(
    'calendar_keyword',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarIncludeAllDayMeta =
      const VerificationMeta('calendarIncludeAllDay');
  @override
  late final GeneratedColumn<bool> calendarIncludeAllDay =
      GeneratedColumn<bool>(
        'calendar_include_all_day',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("calendar_include_all_day" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _calendarLookaheadHoursMeta =
      const VerificationMeta('calendarLookaheadHours');
  @override
  late final GeneratedColumn<int> calendarLookaheadHours = GeneratedColumn<int>(
    'calendar_lookahead_hours',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ruleId,
    triggerType,
    startTime,
    endTime,
    latitude,
    longitude,
    radius,
    packageName,
    activityType,
    calendarId,
    calendarKeyword,
    calendarIncludeAllDay,
    calendarLookaheadHours,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_triggers';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleTrigger> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('trigger_type')) {
      context.handle(
        _triggerTypeMeta,
        triggerType.isAcceptableOrUnknown(
          data['trigger_type']!,
          _triggerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
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
    if (data.containsKey('radius')) {
      context.handle(
        _radiusMeta,
        radius.isAcceptableOrUnknown(data['radius']!, _radiusMeta),
      );
    }
    if (data.containsKey('package_name')) {
      context.handle(
        _packageNameMeta,
        packageName.isAcceptableOrUnknown(
          data['package_name']!,
          _packageNameMeta,
        ),
      );
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    }
    if (data.containsKey('calendar_keyword')) {
      context.handle(
        _calendarKeywordMeta,
        calendarKeyword.isAcceptableOrUnknown(
          data['calendar_keyword']!,
          _calendarKeywordMeta,
        ),
      );
    }
    if (data.containsKey('calendar_include_all_day')) {
      context.handle(
        _calendarIncludeAllDayMeta,
        calendarIncludeAllDay.isAcceptableOrUnknown(
          data['calendar_include_all_day']!,
          _calendarIncludeAllDayMeta,
        ),
      );
    }
    if (data.containsKey('calendar_lookahead_hours')) {
      context.handle(
        _calendarLookaheadHoursMeta,
        calendarLookaheadHours.isAcceptableOrUnknown(
          data['calendar_lookahead_hours']!,
          _calendarLookaheadHoursMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleTrigger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleTrigger(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_id'],
      )!,
      triggerType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trigger_type'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      radius: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius'],
      ),
      packageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_name'],
      ),
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      ),
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      ),
      calendarKeyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_keyword'],
      ),
      calendarIncludeAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}calendar_include_all_day'],
      )!,
      calendarLookaheadHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calendar_lookahead_hours'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $RuleTriggersTable createAlias(String alias) {
    return $RuleTriggersTable(attachedDatabase, alias);
  }
}

class RuleTrigger extends DataClass implements Insertable<RuleTrigger> {
  final int id;
  final int ruleId;
  final int triggerType;
  final String? startTime;
  final String? endTime;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? packageName;
  final String? activityType;
  final String? calendarId;
  final String? calendarKeyword;
  final bool calendarIncludeAllDay;
  final int? calendarLookaheadHours;
  final bool enabled;
  const RuleTrigger({
    required this.id,
    required this.ruleId,
    required this.triggerType,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
    this.radius,
    this.packageName,
    this.activityType,
    this.calendarId,
    this.calendarKeyword,
    required this.calendarIncludeAllDay,
    this.calendarLookaheadHours,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['rule_id'] = Variable<int>(ruleId);
    map['trigger_type'] = Variable<int>(triggerType);
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || radius != null) {
      map['radius'] = Variable<double>(radius);
    }
    if (!nullToAbsent || packageName != null) {
      map['package_name'] = Variable<String>(packageName);
    }
    if (!nullToAbsent || activityType != null) {
      map['activity_type'] = Variable<String>(activityType);
    }
    if (!nullToAbsent || calendarId != null) {
      map['calendar_id'] = Variable<String>(calendarId);
    }
    if (!nullToAbsent || calendarKeyword != null) {
      map['calendar_keyword'] = Variable<String>(calendarKeyword);
    }
    map['calendar_include_all_day'] = Variable<bool>(calendarIncludeAllDay);
    if (!nullToAbsent || calendarLookaheadHours != null) {
      map['calendar_lookahead_hours'] = Variable<int>(calendarLookaheadHours);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  RuleTriggersCompanion toCompanion(bool nullToAbsent) {
    return RuleTriggersCompanion(
      id: Value(id),
      ruleId: Value(ruleId),
      triggerType: Value(triggerType),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      radius: radius == null && nullToAbsent
          ? const Value.absent()
          : Value(radius),
      packageName: packageName == null && nullToAbsent
          ? const Value.absent()
          : Value(packageName),
      activityType: activityType == null && nullToAbsent
          ? const Value.absent()
          : Value(activityType),
      calendarId: calendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarId),
      calendarKeyword: calendarKeyword == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarKeyword),
      calendarIncludeAllDay: Value(calendarIncludeAllDay),
      calendarLookaheadHours: calendarLookaheadHours == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarLookaheadHours),
      enabled: Value(enabled),
    );
  }

  factory RuleTrigger.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleTrigger(
      id: serializer.fromJson<int>(json['id']),
      ruleId: serializer.fromJson<int>(json['ruleId']),
      triggerType: serializer.fromJson<int>(json['triggerType']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      radius: serializer.fromJson<double?>(json['radius']),
      packageName: serializer.fromJson<String?>(json['packageName']),
      activityType: serializer.fromJson<String?>(json['activityType']),
      calendarId: serializer.fromJson<String?>(json['calendarId']),
      calendarKeyword: serializer.fromJson<String?>(json['calendarKeyword']),
      calendarIncludeAllDay: serializer.fromJson<bool>(
        json['calendarIncludeAllDay'],
      ),
      calendarLookaheadHours: serializer.fromJson<int?>(
        json['calendarLookaheadHours'],
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ruleId': serializer.toJson<int>(ruleId),
      'triggerType': serializer.toJson<int>(triggerType),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'radius': serializer.toJson<double?>(radius),
      'packageName': serializer.toJson<String?>(packageName),
      'activityType': serializer.toJson<String?>(activityType),
      'calendarId': serializer.toJson<String?>(calendarId),
      'calendarKeyword': serializer.toJson<String?>(calendarKeyword),
      'calendarIncludeAllDay': serializer.toJson<bool>(calendarIncludeAllDay),
      'calendarLookaheadHours': serializer.toJson<int?>(calendarLookaheadHours),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  RuleTrigger copyWith({
    int? id,
    int? ruleId,
    int? triggerType,
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> radius = const Value.absent(),
    Value<String?> packageName = const Value.absent(),
    Value<String?> activityType = const Value.absent(),
    Value<String?> calendarId = const Value.absent(),
    Value<String?> calendarKeyword = const Value.absent(),
    bool? calendarIncludeAllDay,
    Value<int?> calendarLookaheadHours = const Value.absent(),
    bool? enabled,
  }) => RuleTrigger(
    id: id ?? this.id,
    ruleId: ruleId ?? this.ruleId,
    triggerType: triggerType ?? this.triggerType,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    radius: radius.present ? radius.value : this.radius,
    packageName: packageName.present ? packageName.value : this.packageName,
    activityType: activityType.present ? activityType.value : this.activityType,
    calendarId: calendarId.present ? calendarId.value : this.calendarId,
    calendarKeyword: calendarKeyword.present
        ? calendarKeyword.value
        : this.calendarKeyword,
    calendarIncludeAllDay: calendarIncludeAllDay ?? this.calendarIncludeAllDay,
    calendarLookaheadHours: calendarLookaheadHours.present
        ? calendarLookaheadHours.value
        : this.calendarLookaheadHours,
    enabled: enabled ?? this.enabled,
  );
  RuleTrigger copyWithCompanion(RuleTriggersCompanion data) {
    return RuleTrigger(
      id: data.id.present ? data.id.value : this.id,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      triggerType: data.triggerType.present
          ? data.triggerType.value
          : this.triggerType,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radius: data.radius.present ? data.radius.value : this.radius,
      packageName: data.packageName.present
          ? data.packageName.value
          : this.packageName,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      calendarKeyword: data.calendarKeyword.present
          ? data.calendarKeyword.value
          : this.calendarKeyword,
      calendarIncludeAllDay: data.calendarIncludeAllDay.present
          ? data.calendarIncludeAllDay.value
          : this.calendarIncludeAllDay,
      calendarLookaheadHours: data.calendarLookaheadHours.present
          ? data.calendarLookaheadHours.value
          : this.calendarLookaheadHours,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleTrigger(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('triggerType: $triggerType, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('packageName: $packageName, ')
          ..write('activityType: $activityType, ')
          ..write('calendarId: $calendarId, ')
          ..write('calendarKeyword: $calendarKeyword, ')
          ..write('calendarIncludeAllDay: $calendarIncludeAllDay, ')
          ..write('calendarLookaheadHours: $calendarLookaheadHours, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ruleId,
    triggerType,
    startTime,
    endTime,
    latitude,
    longitude,
    radius,
    packageName,
    activityType,
    calendarId,
    calendarKeyword,
    calendarIncludeAllDay,
    calendarLookaheadHours,
    enabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleTrigger &&
          other.id == this.id &&
          other.ruleId == this.ruleId &&
          other.triggerType == this.triggerType &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radius == this.radius &&
          other.packageName == this.packageName &&
          other.activityType == this.activityType &&
          other.calendarId == this.calendarId &&
          other.calendarKeyword == this.calendarKeyword &&
          other.calendarIncludeAllDay == this.calendarIncludeAllDay &&
          other.calendarLookaheadHours == this.calendarLookaheadHours &&
          other.enabled == this.enabled);
}

class RuleTriggersCompanion extends UpdateCompanion<RuleTrigger> {
  final Value<int> id;
  final Value<int> ruleId;
  final Value<int> triggerType;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> radius;
  final Value<String?> packageName;
  final Value<String?> activityType;
  final Value<String?> calendarId;
  final Value<String?> calendarKeyword;
  final Value<bool> calendarIncludeAllDay;
  final Value<int?> calendarLookaheadHours;
  final Value<bool> enabled;
  const RuleTriggersCompanion({
    this.id = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.packageName = const Value.absent(),
    this.activityType = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.calendarKeyword = const Value.absent(),
    this.calendarIncludeAllDay = const Value.absent(),
    this.calendarLookaheadHours = const Value.absent(),
    this.enabled = const Value.absent(),
  });
  RuleTriggersCompanion.insert({
    this.id = const Value.absent(),
    required int ruleId,
    required int triggerType,
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radius = const Value.absent(),
    this.packageName = const Value.absent(),
    this.activityType = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.calendarKeyword = const Value.absent(),
    this.calendarIncludeAllDay = const Value.absent(),
    this.calendarLookaheadHours = const Value.absent(),
    this.enabled = const Value.absent(),
  }) : ruleId = Value(ruleId),
       triggerType = Value(triggerType);
  static Insertable<RuleTrigger> custom({
    Expression<int>? id,
    Expression<int>? ruleId,
    Expression<int>? triggerType,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? radius,
    Expression<String>? packageName,
    Expression<String>? activityType,
    Expression<String>? calendarId,
    Expression<String>? calendarKeyword,
    Expression<bool>? calendarIncludeAllDay,
    Expression<int>? calendarLookaheadHours,
    Expression<bool>? enabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ruleId != null) 'rule_id': ruleId,
      if (triggerType != null) 'trigger_type': triggerType,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radius != null) 'radius': radius,
      if (packageName != null) 'package_name': packageName,
      if (activityType != null) 'activity_type': activityType,
      if (calendarId != null) 'calendar_id': calendarId,
      if (calendarKeyword != null) 'calendar_keyword': calendarKeyword,
      if (calendarIncludeAllDay != null)
        'calendar_include_all_day': calendarIncludeAllDay,
      if (calendarLookaheadHours != null)
        'calendar_lookahead_hours': calendarLookaheadHours,
      if (enabled != null) 'enabled': enabled,
    });
  }

  RuleTriggersCompanion copyWith({
    Value<int>? id,
    Value<int>? ruleId,
    Value<int>? triggerType,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? radius,
    Value<String?>? packageName,
    Value<String?>? activityType,
    Value<String?>? calendarId,
    Value<String?>? calendarKeyword,
    Value<bool>? calendarIncludeAllDay,
    Value<int?>? calendarLookaheadHours,
    Value<bool>? enabled,
  }) {
    return RuleTriggersCompanion(
      id: id ?? this.id,
      ruleId: ruleId ?? this.ruleId,
      triggerType: triggerType ?? this.triggerType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      packageName: packageName ?? this.packageName,
      activityType: activityType ?? this.activityType,
      calendarId: calendarId ?? this.calendarId,
      calendarKeyword: calendarKeyword ?? this.calendarKeyword,
      calendarIncludeAllDay:
          calendarIncludeAllDay ?? this.calendarIncludeAllDay,
      calendarLookaheadHours:
          calendarLookaheadHours ?? this.calendarLookaheadHours,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<int>(ruleId.value);
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<int>(triggerType.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radius.present) {
      map['radius'] = Variable<double>(radius.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (calendarKeyword.present) {
      map['calendar_keyword'] = Variable<String>(calendarKeyword.value);
    }
    if (calendarIncludeAllDay.present) {
      map['calendar_include_all_day'] = Variable<bool>(
        calendarIncludeAllDay.value,
      );
    }
    if (calendarLookaheadHours.present) {
      map['calendar_lookahead_hours'] = Variable<int>(
        calendarLookaheadHours.value,
      );
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleTriggersCompanion(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('triggerType: $triggerType, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radius: $radius, ')
          ..write('packageName: $packageName, ')
          ..write('activityType: $activityType, ')
          ..write('calendarId: $calendarId, ')
          ..write('calendarKeyword: $calendarKeyword, ')
          ..write('calendarIncludeAllDay: $calendarIncludeAllDay, ')
          ..write('calendarLookaheadHours: $calendarLookaheadHours, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }
}

class $CalendarBusyWindowsCacheTable extends CalendarBusyWindowsCache
    with
        TableInfo<
          $CalendarBusyWindowsCacheTable,
          CalendarBusyWindowsCacheData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarBusyWindowsCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _triggerIdMeta = const VerificationMeta(
    'triggerId',
  );
  @override
  late final GeneratedColumn<String> triggerId = GeneratedColumn<String>(
    'trigger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdHashMeta = const VerificationMeta(
    'eventIdHash',
  );
  @override
  late final GeneratedColumn<String> eventIdHash = GeneratedColumn<String>(
    'event_id_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calendarIdMeta = const VerificationMeta(
    'calendarId',
  );
  @override
  late final GeneratedColumn<String> calendarId = GeneratedColumn<String>(
    'calendar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMillisMeta = const VerificationMeta(
    'startMillis',
  );
  @override
  late final GeneratedColumn<int> startMillis = GeneratedColumn<int>(
    'start_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMillisMeta = const VerificationMeta(
    'endMillis',
  );
  @override
  late final GeneratedColumn<int> endMillis = GeneratedColumn<int>(
    'end_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keywordMatchedMeta = const VerificationMeta(
    'keywordMatched',
  );
  @override
  late final GeneratedColumn<bool> keywordMatched = GeneratedColumn<bool>(
    'keyword_matched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keyword_matched" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    triggerId,
    eventIdHash,
    calendarId,
    startMillis,
    endMillis,
    isAllDay,
    keywordMatched,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_busy_windows_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarBusyWindowsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('trigger_id')) {
      context.handle(
        _triggerIdMeta,
        triggerId.isAcceptableOrUnknown(data['trigger_id']!, _triggerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_triggerIdMeta);
    }
    if (data.containsKey('event_id_hash')) {
      context.handle(
        _eventIdHashMeta,
        eventIdHash.isAcceptableOrUnknown(
          data['event_id_hash']!,
          _eventIdHashMeta,
        ),
      );
    }
    if (data.containsKey('calendar_id')) {
      context.handle(
        _calendarIdMeta,
        calendarId.isAcceptableOrUnknown(data['calendar_id']!, _calendarIdMeta),
      );
    }
    if (data.containsKey('start_millis')) {
      context.handle(
        _startMillisMeta,
        startMillis.isAcceptableOrUnknown(
          data['start_millis']!,
          _startMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMillisMeta);
    }
    if (data.containsKey('end_millis')) {
      context.handle(
        _endMillisMeta,
        endMillis.isAcceptableOrUnknown(data['end_millis']!, _endMillisMeta),
      );
    } else if (isInserting) {
      context.missing(_endMillisMeta);
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('keyword_matched')) {
      context.handle(
        _keywordMatchedMeta,
        keywordMatched.isAcceptableOrUnknown(
          data['keyword_matched']!,
          _keywordMatchedMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarBusyWindowsCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarBusyWindowsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      triggerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_id'],
      )!,
      eventIdHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id_hash'],
      ),
      calendarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_id'],
      ),
      startMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_millis'],
      )!,
      endMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_millis'],
      )!,
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      keywordMatched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keyword_matched'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CalendarBusyWindowsCacheTable createAlias(String alias) {
    return $CalendarBusyWindowsCacheTable(attachedDatabase, alias);
  }
}

class CalendarBusyWindowsCacheData extends DataClass
    implements Insertable<CalendarBusyWindowsCacheData> {
  final int id;
  final String triggerId;
  final String? eventIdHash;
  final String? calendarId;
  final int startMillis;
  final int endMillis;
  final bool isAllDay;
  final bool keywordMatched;
  final int fetchedAt;
  const CalendarBusyWindowsCacheData({
    required this.id,
    required this.triggerId,
    this.eventIdHash,
    this.calendarId,
    required this.startMillis,
    required this.endMillis,
    required this.isAllDay,
    required this.keywordMatched,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['trigger_id'] = Variable<String>(triggerId);
    if (!nullToAbsent || eventIdHash != null) {
      map['event_id_hash'] = Variable<String>(eventIdHash);
    }
    if (!nullToAbsent || calendarId != null) {
      map['calendar_id'] = Variable<String>(calendarId);
    }
    map['start_millis'] = Variable<int>(startMillis);
    map['end_millis'] = Variable<int>(endMillis);
    map['is_all_day'] = Variable<bool>(isAllDay);
    map['keyword_matched'] = Variable<bool>(keywordMatched);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  CalendarBusyWindowsCacheCompanion toCompanion(bool nullToAbsent) {
    return CalendarBusyWindowsCacheCompanion(
      id: Value(id),
      triggerId: Value(triggerId),
      eventIdHash: eventIdHash == null && nullToAbsent
          ? const Value.absent()
          : Value(eventIdHash),
      calendarId: calendarId == null && nullToAbsent
          ? const Value.absent()
          : Value(calendarId),
      startMillis: Value(startMillis),
      endMillis: Value(endMillis),
      isAllDay: Value(isAllDay),
      keywordMatched: Value(keywordMatched),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CalendarBusyWindowsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarBusyWindowsCacheData(
      id: serializer.fromJson<int>(json['id']),
      triggerId: serializer.fromJson<String>(json['triggerId']),
      eventIdHash: serializer.fromJson<String?>(json['eventIdHash']),
      calendarId: serializer.fromJson<String?>(json['calendarId']),
      startMillis: serializer.fromJson<int>(json['startMillis']),
      endMillis: serializer.fromJson<int>(json['endMillis']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      keywordMatched: serializer.fromJson<bool>(json['keywordMatched']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'triggerId': serializer.toJson<String>(triggerId),
      'eventIdHash': serializer.toJson<String?>(eventIdHash),
      'calendarId': serializer.toJson<String?>(calendarId),
      'startMillis': serializer.toJson<int>(startMillis),
      'endMillis': serializer.toJson<int>(endMillis),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'keywordMatched': serializer.toJson<bool>(keywordMatched),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  CalendarBusyWindowsCacheData copyWith({
    int? id,
    String? triggerId,
    Value<String?> eventIdHash = const Value.absent(),
    Value<String?> calendarId = const Value.absent(),
    int? startMillis,
    int? endMillis,
    bool? isAllDay,
    bool? keywordMatched,
    int? fetchedAt,
  }) => CalendarBusyWindowsCacheData(
    id: id ?? this.id,
    triggerId: triggerId ?? this.triggerId,
    eventIdHash: eventIdHash.present ? eventIdHash.value : this.eventIdHash,
    calendarId: calendarId.present ? calendarId.value : this.calendarId,
    startMillis: startMillis ?? this.startMillis,
    endMillis: endMillis ?? this.endMillis,
    isAllDay: isAllDay ?? this.isAllDay,
    keywordMatched: keywordMatched ?? this.keywordMatched,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CalendarBusyWindowsCacheData copyWithCompanion(
    CalendarBusyWindowsCacheCompanion data,
  ) {
    return CalendarBusyWindowsCacheData(
      id: data.id.present ? data.id.value : this.id,
      triggerId: data.triggerId.present ? data.triggerId.value : this.triggerId,
      eventIdHash: data.eventIdHash.present
          ? data.eventIdHash.value
          : this.eventIdHash,
      calendarId: data.calendarId.present
          ? data.calendarId.value
          : this.calendarId,
      startMillis: data.startMillis.present
          ? data.startMillis.value
          : this.startMillis,
      endMillis: data.endMillis.present ? data.endMillis.value : this.endMillis,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      keywordMatched: data.keywordMatched.present
          ? data.keywordMatched.value
          : this.keywordMatched,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarBusyWindowsCacheData(')
          ..write('id: $id, ')
          ..write('triggerId: $triggerId, ')
          ..write('eventIdHash: $eventIdHash, ')
          ..write('calendarId: $calendarId, ')
          ..write('startMillis: $startMillis, ')
          ..write('endMillis: $endMillis, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('keywordMatched: $keywordMatched, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    triggerId,
    eventIdHash,
    calendarId,
    startMillis,
    endMillis,
    isAllDay,
    keywordMatched,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarBusyWindowsCacheData &&
          other.id == this.id &&
          other.triggerId == this.triggerId &&
          other.eventIdHash == this.eventIdHash &&
          other.calendarId == this.calendarId &&
          other.startMillis == this.startMillis &&
          other.endMillis == this.endMillis &&
          other.isAllDay == this.isAllDay &&
          other.keywordMatched == this.keywordMatched &&
          other.fetchedAt == this.fetchedAt);
}

class CalendarBusyWindowsCacheCompanion
    extends UpdateCompanion<CalendarBusyWindowsCacheData> {
  final Value<int> id;
  final Value<String> triggerId;
  final Value<String?> eventIdHash;
  final Value<String?> calendarId;
  final Value<int> startMillis;
  final Value<int> endMillis;
  final Value<bool> isAllDay;
  final Value<bool> keywordMatched;
  final Value<int> fetchedAt;
  const CalendarBusyWindowsCacheCompanion({
    this.id = const Value.absent(),
    this.triggerId = const Value.absent(),
    this.eventIdHash = const Value.absent(),
    this.calendarId = const Value.absent(),
    this.startMillis = const Value.absent(),
    this.endMillis = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.keywordMatched = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  CalendarBusyWindowsCacheCompanion.insert({
    this.id = const Value.absent(),
    required String triggerId,
    this.eventIdHash = const Value.absent(),
    this.calendarId = const Value.absent(),
    required int startMillis,
    required int endMillis,
    this.isAllDay = const Value.absent(),
    this.keywordMatched = const Value.absent(),
    required int fetchedAt,
  }) : triggerId = Value(triggerId),
       startMillis = Value(startMillis),
       endMillis = Value(endMillis),
       fetchedAt = Value(fetchedAt);
  static Insertable<CalendarBusyWindowsCacheData> custom({
    Expression<int>? id,
    Expression<String>? triggerId,
    Expression<String>? eventIdHash,
    Expression<String>? calendarId,
    Expression<int>? startMillis,
    Expression<int>? endMillis,
    Expression<bool>? isAllDay,
    Expression<bool>? keywordMatched,
    Expression<int>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (triggerId != null) 'trigger_id': triggerId,
      if (eventIdHash != null) 'event_id_hash': eventIdHash,
      if (calendarId != null) 'calendar_id': calendarId,
      if (startMillis != null) 'start_millis': startMillis,
      if (endMillis != null) 'end_millis': endMillis,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (keywordMatched != null) 'keyword_matched': keywordMatched,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  CalendarBusyWindowsCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? triggerId,
    Value<String?>? eventIdHash,
    Value<String?>? calendarId,
    Value<int>? startMillis,
    Value<int>? endMillis,
    Value<bool>? isAllDay,
    Value<bool>? keywordMatched,
    Value<int>? fetchedAt,
  }) {
    return CalendarBusyWindowsCacheCompanion(
      id: id ?? this.id,
      triggerId: triggerId ?? this.triggerId,
      eventIdHash: eventIdHash ?? this.eventIdHash,
      calendarId: calendarId ?? this.calendarId,
      startMillis: startMillis ?? this.startMillis,
      endMillis: endMillis ?? this.endMillis,
      isAllDay: isAllDay ?? this.isAllDay,
      keywordMatched: keywordMatched ?? this.keywordMatched,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (triggerId.present) {
      map['trigger_id'] = Variable<String>(triggerId.value);
    }
    if (eventIdHash.present) {
      map['event_id_hash'] = Variable<String>(eventIdHash.value);
    }
    if (calendarId.present) {
      map['calendar_id'] = Variable<String>(calendarId.value);
    }
    if (startMillis.present) {
      map['start_millis'] = Variable<int>(startMillis.value);
    }
    if (endMillis.present) {
      map['end_millis'] = Variable<int>(endMillis.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (keywordMatched.present) {
      map['keyword_matched'] = Variable<bool>(keywordMatched.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarBusyWindowsCacheCompanion(')
          ..write('id: $id, ')
          ..write('triggerId: $triggerId, ')
          ..write('eventIdHash: $eventIdHash, ')
          ..write('calendarId: $calendarId, ')
          ..write('startMillis: $startMillis, ')
          ..write('endMillis: $endMillis, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('keywordMatched: $keywordMatched, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RulesTable rules = $RulesTable(this);
  late final $RuleTriggersTable ruleTriggers = $RuleTriggersTable(this);
  late final $CalendarBusyWindowsCacheTable calendarBusyWindowsCache =
      $CalendarBusyWindowsCacheTable(this);
  late final Index ruleTriggersRuleId = Index(
    'rule_triggers_rule_id',
    'CREATE INDEX rule_triggers_rule_id ON rule_triggers (rule_id)',
  );
  late final Index calendarBusyWindowsTriggerId = Index(
    'calendar_busy_windows_trigger_id',
    'CREATE INDEX calendar_busy_windows_trigger_id ON calendar_busy_windows_cache (trigger_id)',
  );
  late final Index calendarBusyWindowsStartMillis = Index(
    'calendar_busy_windows_start_millis',
    'CREATE INDEX calendar_busy_windows_start_millis ON calendar_busy_windows_cache (start_millis)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    rules,
    ruleTriggers,
    calendarBusyWindowsCache,
    ruleTriggersRuleId,
    calendarBusyWindowsTriggerId,
    calendarBusyWindowsStartMillis,
  ];
}

typedef $$RulesTableCreateCompanionBuilder =
    RulesCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> isEnabled,
      Value<int> matchType,
      Value<int> priority,
      required int type,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int?> radius,
      Value<String?> packageName,
      Value<String?> activityType,
      Value<bool> allowStarredContacts,
      Value<bool> allowRepeatCallers,
    });
typedef $$RulesTableUpdateCompanionBuilder =
    RulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> isEnabled,
      Value<int> matchType,
      Value<int> priority,
      Value<int> type,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<int?> radius,
      Value<String?> packageName,
      Value<String?> activityType,
      Value<bool> allowStarredContacts,
      Value<bool> allowRepeatCallers,
    });

class $$RulesTableFilterComposer extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchType => $composableBuilder(
    column: $table.matchType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
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

  ColumnFilters<int> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowStarredContacts => $composableBuilder(
    column: $table.allowStarredContacts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowRepeatCallers => $composableBuilder(
    column: $table.allowRepeatCallers,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchType => $composableBuilder(
    column: $table.matchType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
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

  ColumnOrderings<int> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowStarredContacts => $composableBuilder(
    column: $table.allowStarredContacts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowRepeatCallers => $composableBuilder(
    column: $table.allowRepeatCallers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RulesTable> {
  $$RulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get matchType =>
      $composableBuilder(column: $table.matchType, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get radius =>
      $composableBuilder(column: $table.radius, builder: (column) => column);

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowStarredContacts => $composableBuilder(
    column: $table.allowStarredContacts,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowRepeatCallers => $composableBuilder(
    column: $table.allowRepeatCallers,
    builder: (column) => column,
  );
}

class $$RulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RulesTable,
          Rule,
          $$RulesTableFilterComposer,
          $$RulesTableOrderingComposer,
          $$RulesTableAnnotationComposer,
          $$RulesTableCreateCompanionBuilder,
          $$RulesTableUpdateCompanionBuilder,
          (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
          Rule,
          PrefetchHooks Function()
        > {
  $$RulesTableTableManager(_$AppDatabase db, $RulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> matchType = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int?> radius = const Value.absent(),
                Value<String?> packageName = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<bool> allowStarredContacts = const Value.absent(),
                Value<bool> allowRepeatCallers = const Value.absent(),
              }) => RulesCompanion(
                id: id,
                name: name,
                isEnabled: isEnabled,
                matchType: matchType,
                priority: priority,
                type: type,
                startTime: startTime,
                endTime: endTime,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                packageName: packageName,
                activityType: activityType,
                allowStarredContacts: allowStarredContacts,
                allowRepeatCallers: allowRepeatCallers,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isEnabled = const Value.absent(),
                Value<int> matchType = const Value.absent(),
                Value<int> priority = const Value.absent(),
                required int type,
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<int?> radius = const Value.absent(),
                Value<String?> packageName = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<bool> allowStarredContacts = const Value.absent(),
                Value<bool> allowRepeatCallers = const Value.absent(),
              }) => RulesCompanion.insert(
                id: id,
                name: name,
                isEnabled: isEnabled,
                matchType: matchType,
                priority: priority,
                type: type,
                startTime: startTime,
                endTime: endTime,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                packageName: packageName,
                activityType: activityType,
                allowStarredContacts: allowStarredContacts,
                allowRepeatCallers: allowRepeatCallers,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RulesTable,
      Rule,
      $$RulesTableFilterComposer,
      $$RulesTableOrderingComposer,
      $$RulesTableAnnotationComposer,
      $$RulesTableCreateCompanionBuilder,
      $$RulesTableUpdateCompanionBuilder,
      (Rule, BaseReferences<_$AppDatabase, $RulesTable, Rule>),
      Rule,
      PrefetchHooks Function()
    >;
typedef $$RuleTriggersTableCreateCompanionBuilder =
    RuleTriggersCompanion Function({
      Value<int> id,
      required int ruleId,
      required int triggerType,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> radius,
      Value<String?> packageName,
      Value<String?> activityType,
      Value<String?> calendarId,
      Value<String?> calendarKeyword,
      Value<bool> calendarIncludeAllDay,
      Value<int?> calendarLookaheadHours,
      Value<bool> enabled,
    });
typedef $$RuleTriggersTableUpdateCompanionBuilder =
    RuleTriggersCompanion Function({
      Value<int> id,
      Value<int> ruleId,
      Value<int> triggerType,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> radius,
      Value<String?> packageName,
      Value<String?> activityType,
      Value<String?> calendarId,
      Value<String?> calendarKeyword,
      Value<bool> calendarIncludeAllDay,
      Value<int?> calendarLookaheadHours,
      Value<bool> enabled,
    });

class $$RuleTriggersTableFilterComposer
    extends Composer<_$AppDatabase, $RuleTriggersTable> {
  $$RuleTriggersTableFilterComposer({
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

  ColumnFilters<int> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
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

  ColumnFilters<double> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarKeyword => $composableBuilder(
    column: $table.calendarKeyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get calendarIncludeAllDay => $composableBuilder(
    column: $table.calendarIncludeAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calendarLookaheadHours => $composableBuilder(
    column: $table.calendarLookaheadHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleTriggersTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleTriggersTable> {
  $$RuleTriggersTableOrderingComposer({
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

  ColumnOrderings<int> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
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

  ColumnOrderings<double> get radius => $composableBuilder(
    column: $table.radius,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarKeyword => $composableBuilder(
    column: $table.calendarKeyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get calendarIncludeAllDay => $composableBuilder(
    column: $table.calendarIncludeAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calendarLookaheadHours => $composableBuilder(
    column: $table.calendarLookaheadHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleTriggersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleTriggersTable> {
  $$RuleTriggersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<int> get triggerType => $composableBuilder(
    column: $table.triggerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get radius =>
      $composableBuilder(column: $table.radius, builder: (column) => column);

  GeneratedColumn<String> get packageName => $composableBuilder(
    column: $table.packageName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarKeyword => $composableBuilder(
    column: $table.calendarKeyword,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get calendarIncludeAllDay => $composableBuilder(
    column: $table.calendarIncludeAllDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calendarLookaheadHours => $composableBuilder(
    column: $table.calendarLookaheadHours,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$RuleTriggersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleTriggersTable,
          RuleTrigger,
          $$RuleTriggersTableFilterComposer,
          $$RuleTriggersTableOrderingComposer,
          $$RuleTriggersTableAnnotationComposer,
          $$RuleTriggersTableCreateCompanionBuilder,
          $$RuleTriggersTableUpdateCompanionBuilder,
          (
            RuleTrigger,
            BaseReferences<_$AppDatabase, $RuleTriggersTable, RuleTrigger>,
          ),
          RuleTrigger,
          PrefetchHooks Function()
        > {
  $$RuleTriggersTableTableManager(_$AppDatabase db, $RuleTriggersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleTriggersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleTriggersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleTriggersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ruleId = const Value.absent(),
                Value<int> triggerType = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> radius = const Value.absent(),
                Value<String?> packageName = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<String?> calendarId = const Value.absent(),
                Value<String?> calendarKeyword = const Value.absent(),
                Value<bool> calendarIncludeAllDay = const Value.absent(),
                Value<int?> calendarLookaheadHours = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => RuleTriggersCompanion(
                id: id,
                ruleId: ruleId,
                triggerType: triggerType,
                startTime: startTime,
                endTime: endTime,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                packageName: packageName,
                activityType: activityType,
                calendarId: calendarId,
                calendarKeyword: calendarKeyword,
                calendarIncludeAllDay: calendarIncludeAllDay,
                calendarLookaheadHours: calendarLookaheadHours,
                enabled: enabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ruleId,
                required int triggerType,
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> radius = const Value.absent(),
                Value<String?> packageName = const Value.absent(),
                Value<String?> activityType = const Value.absent(),
                Value<String?> calendarId = const Value.absent(),
                Value<String?> calendarKeyword = const Value.absent(),
                Value<bool> calendarIncludeAllDay = const Value.absent(),
                Value<int?> calendarLookaheadHours = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => RuleTriggersCompanion.insert(
                id: id,
                ruleId: ruleId,
                triggerType: triggerType,
                startTime: startTime,
                endTime: endTime,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                packageName: packageName,
                activityType: activityType,
                calendarId: calendarId,
                calendarKeyword: calendarKeyword,
                calendarIncludeAllDay: calendarIncludeAllDay,
                calendarLookaheadHours: calendarLookaheadHours,
                enabled: enabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleTriggersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleTriggersTable,
      RuleTrigger,
      $$RuleTriggersTableFilterComposer,
      $$RuleTriggersTableOrderingComposer,
      $$RuleTriggersTableAnnotationComposer,
      $$RuleTriggersTableCreateCompanionBuilder,
      $$RuleTriggersTableUpdateCompanionBuilder,
      (
        RuleTrigger,
        BaseReferences<_$AppDatabase, $RuleTriggersTable, RuleTrigger>,
      ),
      RuleTrigger,
      PrefetchHooks Function()
    >;
typedef $$CalendarBusyWindowsCacheTableCreateCompanionBuilder =
    CalendarBusyWindowsCacheCompanion Function({
      Value<int> id,
      required String triggerId,
      Value<String?> eventIdHash,
      Value<String?> calendarId,
      required int startMillis,
      required int endMillis,
      Value<bool> isAllDay,
      Value<bool> keywordMatched,
      required int fetchedAt,
    });
typedef $$CalendarBusyWindowsCacheTableUpdateCompanionBuilder =
    CalendarBusyWindowsCacheCompanion Function({
      Value<int> id,
      Value<String> triggerId,
      Value<String?> eventIdHash,
      Value<String?> calendarId,
      Value<int> startMillis,
      Value<int> endMillis,
      Value<bool> isAllDay,
      Value<bool> keywordMatched,
      Value<int> fetchedAt,
    });

class $$CalendarBusyWindowsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarBusyWindowsCacheTable> {
  $$CalendarBusyWindowsCacheTableFilterComposer({
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

  ColumnFilters<String> get triggerId => $composableBuilder(
    column: $table.triggerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventIdHash => $composableBuilder(
    column: $table.eventIdHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMillis => $composableBuilder(
    column: $table.startMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMillis => $composableBuilder(
    column: $table.endMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keywordMatched => $composableBuilder(
    column: $table.keywordMatched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarBusyWindowsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarBusyWindowsCacheTable> {
  $$CalendarBusyWindowsCacheTableOrderingComposer({
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

  ColumnOrderings<String> get triggerId => $composableBuilder(
    column: $table.triggerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventIdHash => $composableBuilder(
    column: $table.eventIdHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMillis => $composableBuilder(
    column: $table.startMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMillis => $composableBuilder(
    column: $table.endMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keywordMatched => $composableBuilder(
    column: $table.keywordMatched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarBusyWindowsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarBusyWindowsCacheTable> {
  $$CalendarBusyWindowsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get triggerId =>
      $composableBuilder(column: $table.triggerId, builder: (column) => column);

  GeneratedColumn<String> get eventIdHash => $composableBuilder(
    column: $table.eventIdHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarId => $composableBuilder(
    column: $table.calendarId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMillis => $composableBuilder(
    column: $table.startMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMillis =>
      $composableBuilder(column: $table.endMillis, builder: (column) => column);

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<bool> get keywordMatched => $composableBuilder(
    column: $table.keywordMatched,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CalendarBusyWindowsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarBusyWindowsCacheTable,
          CalendarBusyWindowsCacheData,
          $$CalendarBusyWindowsCacheTableFilterComposer,
          $$CalendarBusyWindowsCacheTableOrderingComposer,
          $$CalendarBusyWindowsCacheTableAnnotationComposer,
          $$CalendarBusyWindowsCacheTableCreateCompanionBuilder,
          $$CalendarBusyWindowsCacheTableUpdateCompanionBuilder,
          (
            CalendarBusyWindowsCacheData,
            BaseReferences<
              _$AppDatabase,
              $CalendarBusyWindowsCacheTable,
              CalendarBusyWindowsCacheData
            >,
          ),
          CalendarBusyWindowsCacheData,
          PrefetchHooks Function()
        > {
  $$CalendarBusyWindowsCacheTableTableManager(
    _$AppDatabase db,
    $CalendarBusyWindowsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarBusyWindowsCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CalendarBusyWindowsCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarBusyWindowsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> triggerId = const Value.absent(),
                Value<String?> eventIdHash = const Value.absent(),
                Value<String?> calendarId = const Value.absent(),
                Value<int> startMillis = const Value.absent(),
                Value<int> endMillis = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<bool> keywordMatched = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
              }) => CalendarBusyWindowsCacheCompanion(
                id: id,
                triggerId: triggerId,
                eventIdHash: eventIdHash,
                calendarId: calendarId,
                startMillis: startMillis,
                endMillis: endMillis,
                isAllDay: isAllDay,
                keywordMatched: keywordMatched,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String triggerId,
                Value<String?> eventIdHash = const Value.absent(),
                Value<String?> calendarId = const Value.absent(),
                required int startMillis,
                required int endMillis,
                Value<bool> isAllDay = const Value.absent(),
                Value<bool> keywordMatched = const Value.absent(),
                required int fetchedAt,
              }) => CalendarBusyWindowsCacheCompanion.insert(
                id: id,
                triggerId: triggerId,
                eventIdHash: eventIdHash,
                calendarId: calendarId,
                startMillis: startMillis,
                endMillis: endMillis,
                isAllDay: isAllDay,
                keywordMatched: keywordMatched,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarBusyWindowsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarBusyWindowsCacheTable,
      CalendarBusyWindowsCacheData,
      $$CalendarBusyWindowsCacheTableFilterComposer,
      $$CalendarBusyWindowsCacheTableOrderingComposer,
      $$CalendarBusyWindowsCacheTableAnnotationComposer,
      $$CalendarBusyWindowsCacheTableCreateCompanionBuilder,
      $$CalendarBusyWindowsCacheTableUpdateCompanionBuilder,
      (
        CalendarBusyWindowsCacheData,
        BaseReferences<
          _$AppDatabase,
          $CalendarBusyWindowsCacheTable,
          CalendarBusyWindowsCacheData
        >,
      ),
      CalendarBusyWindowsCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db, _db.rules);
  $$RuleTriggersTableTableManager get ruleTriggers =>
      $$RuleTriggersTableTableManager(_db, _db.ruleTriggers);
  $$CalendarBusyWindowsCacheTableTableManager get calendarBusyWindowsCache =>
      $$CalendarBusyWindowsCacheTableTableManager(
        _db,
        _db.calendarBusyWindowsCache,
      );
}
