// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ResourcesTable extends Resources
    with TableInfo<$ResourcesTable, Resource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _fieldsJsonMeta =
      const VerificationMeta('fieldsJson');
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
      'fields_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _coverImageMeta =
      const VerificationMeta('coverImage');
  @override
  late final GeneratedColumn<String> coverImage = GeneratedColumn<String>(
      'cover_image', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, type, name, fieldsJson, coverImage, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resources';
  @override
  VerificationContext validateIntegrity(Insertable<Resource> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
          _fieldsJsonMeta,
          fieldsJson.isAcceptableOrUnknown(
              data['fields_json']!, _fieldsJsonMeta));
    }
    if (data.containsKey('cover_image')) {
      context.handle(
          _coverImageMeta,
          coverImage.isAcceptableOrUnknown(
              data['cover_image']!, _coverImageMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Resource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Resource(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      fieldsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fields_json'])!,
      coverImage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_image']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ResourcesTable createAlias(String alias) {
    return $ResourcesTable(attachedDatabase, alias);
  }
}

class Resource extends DataClass implements Insertable<Resource> {
  final String id;
  final String type;
  final String name;
  final String fieldsJson;
  final String? coverImage;
  final int createdAt;
  final int updatedAt;
  const Resource(
      {required this.id,
      required this.type,
      required this.name,
      required this.fieldsJson,
      this.coverImage,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['fields_json'] = Variable<String>(fieldsJson);
    if (!nullToAbsent || coverImage != null) {
      map['cover_image'] = Variable<String>(coverImage);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ResourcesCompanion toCompanion(bool nullToAbsent) {
    return ResourcesCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      fieldsJson: Value(fieldsJson),
      coverImage: coverImage == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Resource.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Resource(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      coverImage: serializer.fromJson<String?>(json['coverImage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'coverImage': serializer.toJson<String?>(coverImage),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Resource copyWith(
          {String? id,
          String? type,
          String? name,
          String? fieldsJson,
          Value<String?> coverImage = const Value.absent(),
          int? createdAt,
          int? updatedAt}) =>
      Resource(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        fieldsJson: fieldsJson ?? this.fieldsJson,
        coverImage: coverImage.present ? coverImage.value : this.coverImage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Resource copyWithCompanion(ResourcesCompanion data) {
    return Resource(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      fieldsJson:
          data.fieldsJson.present ? data.fieldsJson.value : this.fieldsJson,
      coverImage:
          data.coverImage.present ? data.coverImage.value : this.coverImage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Resource(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('coverImage: $coverImage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, name, fieldsJson, coverImage, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Resource &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.fieldsJson == this.fieldsJson &&
          other.coverImage == this.coverImage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ResourcesCompanion extends UpdateCompanion<Resource> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> fieldsJson;
  final Value<String?> coverImage;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ResourcesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.coverImage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourcesCompanion.insert({
    required String id,
    required String type,
    required String name,
    this.fieldsJson = const Value.absent(),
    this.coverImage = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Resource> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? fieldsJson,
    Expression<String>? coverImage,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (coverImage != null) 'cover_image': coverImage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourcesCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String>? name,
      Value<String>? fieldsJson,
      Value<String?>? coverImage,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return ResourcesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      coverImage: coverImage ?? this.coverImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (coverImage.present) {
      map['cover_image'] = Variable<String>(coverImage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourcesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('coverImage: $coverImage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourceImagesTable extends ResourceImages
    with TableInfo<$ResourceImagesTable, ResourceImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceIdMeta =
      const VerificationMeta('resourceId');
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints:
          'NOT NULL REFERENCES resources(id) ON DELETE CASCADE');
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<int> sort = GeneratedColumn<int>(
      'sort', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, resourceId, filePath, note, sort];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource_images';
  @override
  VerificationContext validateIntegrity(Insertable<ResourceImage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
          _resourceIdMeta,
          resourceId.isAcceptableOrUnknown(
              data['resource_id']!, _resourceIdMeta));
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('sort')) {
      context.handle(
          _sortMeta, sort.isAcceptableOrUnknown(data['sort']!, _sortMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResourceImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceImage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      sort: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort'])!,
    );
  }

  @override
  $ResourceImagesTable createAlias(String alias) {
    return $ResourceImagesTable(attachedDatabase, alias);
  }
}

class ResourceImage extends DataClass implements Insertable<ResourceImage> {
  final String id;
  final String resourceId;
  final String filePath;
  final String note;
  final int sort;
  const ResourceImage(
      {required this.id,
      required this.resourceId,
      required this.filePath,
      required this.note,
      required this.sort});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['resource_id'] = Variable<String>(resourceId);
    map['file_path'] = Variable<String>(filePath);
    map['note'] = Variable<String>(note);
    map['sort'] = Variable<int>(sort);
    return map;
  }

  ResourceImagesCompanion toCompanion(bool nullToAbsent) {
    return ResourceImagesCompanion(
      id: Value(id),
      resourceId: Value(resourceId),
      filePath: Value(filePath),
      note: Value(note),
      sort: Value(sort),
    );
  }

  factory ResourceImage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceImage(
      id: serializer.fromJson<String>(json['id']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      note: serializer.fromJson<String>(json['note']),
      sort: serializer.fromJson<int>(json['sort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'resourceId': serializer.toJson<String>(resourceId),
      'filePath': serializer.toJson<String>(filePath),
      'note': serializer.toJson<String>(note),
      'sort': serializer.toJson<int>(sort),
    };
  }

  ResourceImage copyWith(
          {String? id,
          String? resourceId,
          String? filePath,
          String? note,
          int? sort}) =>
      ResourceImage(
        id: id ?? this.id,
        resourceId: resourceId ?? this.resourceId,
        filePath: filePath ?? this.filePath,
        note: note ?? this.note,
        sort: sort ?? this.sort,
      );
  ResourceImage copyWithCompanion(ResourceImagesCompanion data) {
    return ResourceImage(
      id: data.id.present ? data.id.value : this.id,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      note: data.note.present ? data.note.value : this.note,
      sort: data.sort.present ? data.sort.value : this.sort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceImage(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('filePath: $filePath, ')
          ..write('note: $note, ')
          ..write('sort: $sort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, resourceId, filePath, note, sort);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceImage &&
          other.id == this.id &&
          other.resourceId == this.resourceId &&
          other.filePath == this.filePath &&
          other.note == this.note &&
          other.sort == this.sort);
}

class ResourceImagesCompanion extends UpdateCompanion<ResourceImage> {
  final Value<String> id;
  final Value<String> resourceId;
  final Value<String> filePath;
  final Value<String> note;
  final Value<int> sort;
  final Value<int> rowid;
  const ResourceImagesCompanion({
    this.id = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.note = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourceImagesCompanion.insert({
    required String id,
    required String resourceId,
    required String filePath,
    this.note = const Value.absent(),
    this.sort = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        resourceId = Value(resourceId),
        filePath = Value(filePath);
  static Insertable<ResourceImage> custom({
    Expression<String>? id,
    Expression<String>? resourceId,
    Expression<String>? filePath,
    Expression<String>? note,
    Expression<int>? sort,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (resourceId != null) 'resource_id': resourceId,
      if (filePath != null) 'file_path': filePath,
      if (note != null) 'note': note,
      if (sort != null) 'sort': sort,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceImagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? resourceId,
      Value<String>? filePath,
      Value<String>? note,
      Value<int>? sort,
      Value<int>? rowid}) {
    return ResourceImagesCompanion(
      id: id ?? this.id,
      resourceId: resourceId ?? this.resourceId,
      filePath: filePath ?? this.filePath,
      note: note ?? this.note,
      sort: sort ?? this.sort,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (sort.present) {
      map['sort'] = Variable<int>(sort.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceImagesCompanion(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('filePath: $filePath, ')
          ..write('note: $note, ')
          ..write('sort: $sort, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FilmsTable extends Films with TableInfo<$FilmsTable, Film> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directorMeta =
      const VerificationMeta('director');
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
      'director', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _coverGradientMeta =
      const VerificationMeta('coverGradient');
  @override
  late final GeneratedColumn<String> coverGradient = GeneratedColumn<String>(
      'cover_gradient', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, director, year, coverGradient, sourceUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'films';
  @override
  VerificationContext validateIntegrity(Insertable<Film> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('director')) {
      context.handle(_directorMeta,
          director.isAcceptableOrUnknown(data['director']!, _directorMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('cover_gradient')) {
      context.handle(
          _coverGradientMeta,
          coverGradient.isAcceptableOrUnknown(
              data['cover_gradient']!, _coverGradientMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Film map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Film(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      director: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}director'])!,
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year']),
      coverGradient: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_gradient'])!,
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url'])!,
    );
  }

  @override
  $FilmsTable createAlias(String alias) {
    return $FilmsTable(attachedDatabase, alias);
  }
}

class Film extends DataClass implements Insertable<Film> {
  final String id;
  final String title;
  final String director;
  final int? year;
  final String coverGradient;
  final String sourceUrl;
  const Film(
      {required this.id,
      required this.title,
      required this.director,
      this.year,
      required this.coverGradient,
      required this.sourceUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['director'] = Variable<String>(director);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    map['cover_gradient'] = Variable<String>(coverGradient);
    map['source_url'] = Variable<String>(sourceUrl);
    return map;
  }

  FilmsCompanion toCompanion(bool nullToAbsent) {
    return FilmsCompanion(
      id: Value(id),
      title: Value(title),
      director: Value(director),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      coverGradient: Value(coverGradient),
      sourceUrl: Value(sourceUrl),
    );
  }

  factory Film.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Film(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      director: serializer.fromJson<String>(json['director']),
      year: serializer.fromJson<int?>(json['year']),
      coverGradient: serializer.fromJson<String>(json['coverGradient']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'director': serializer.toJson<String>(director),
      'year': serializer.toJson<int?>(year),
      'coverGradient': serializer.toJson<String>(coverGradient),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
    };
  }

  Film copyWith(
          {String? id,
          String? title,
          String? director,
          Value<int?> year = const Value.absent(),
          String? coverGradient,
          String? sourceUrl}) =>
      Film(
        id: id ?? this.id,
        title: title ?? this.title,
        director: director ?? this.director,
        year: year.present ? year.value : this.year,
        coverGradient: coverGradient ?? this.coverGradient,
        sourceUrl: sourceUrl ?? this.sourceUrl,
      );
  Film copyWithCompanion(FilmsCompanion data) {
    return Film(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      director: data.director.present ? data.director.value : this.director,
      year: data.year.present ? data.year.value : this.year,
      coverGradient: data.coverGradient.present
          ? data.coverGradient.value
          : this.coverGradient,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Film(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('director: $director, ')
          ..write('year: $year, ')
          ..write('coverGradient: $coverGradient, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, director, year, coverGradient, sourceUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Film &&
          other.id == this.id &&
          other.title == this.title &&
          other.director == this.director &&
          other.year == this.year &&
          other.coverGradient == this.coverGradient &&
          other.sourceUrl == this.sourceUrl);
}

class FilmsCompanion extends UpdateCompanion<Film> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> director;
  final Value<int?> year;
  final Value<String> coverGradient;
  final Value<String> sourceUrl;
  final Value<int> rowid;
  const FilmsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.director = const Value.absent(),
    this.year = const Value.absent(),
    this.coverGradient = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilmsCompanion.insert({
    required String id,
    required String title,
    this.director = const Value.absent(),
    this.year = const Value.absent(),
    this.coverGradient = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title);
  static Insertable<Film> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? director,
    Expression<int>? year,
    Expression<String>? coverGradient,
    Expression<String>? sourceUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (director != null) 'director': director,
      if (year != null) 'year': year,
      if (coverGradient != null) 'cover_gradient': coverGradient,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilmsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? director,
      Value<int?>? year,
      Value<String>? coverGradient,
      Value<String>? sourceUrl,
      Value<int>? rowid}) {
    return FilmsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      director: director ?? this.director,
      year: year ?? this.year,
      coverGradient: coverGradient ?? this.coverGradient,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (coverGradient.present) {
      map['cover_gradient'] = Variable<String>(coverGradient.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilmsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('director: $director, ')
          ..write('year: $year, ')
          ..write('coverGradient: $coverGradient, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FilmFramesTable extends FilmFrames
    with TableInfo<$FilmFramesTable, FilmFrame> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilmFramesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filmIdMeta = const VerificationMeta('filmId');
  @override
  late final GeneratedColumn<String> filmId = GeneratedColumn<String>(
      'film_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES films(id) ON DELETE CASCADE');
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageRefMeta =
      const VerificationMeta('imageRef');
  @override
  late final GeneratedColumn<String> imageRef = GeneratedColumn<String>(
      'image_ref', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paletteJsonMeta =
      const VerificationMeta('paletteJson');
  @override
  late final GeneratedColumn<String> paletteJson = GeneratedColumn<String>(
      'palette_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _inBoardMeta =
      const VerificationMeta('inBoard');
  @override
  late final GeneratedColumn<bool> inBoard = GeneratedColumn<bool>(
      'in_board', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("in_board" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, filmId, name, imageRef, paletteJson, sourceUrl, inBoard];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'film_frames';
  @override
  VerificationContext validateIntegrity(Insertable<FilmFrame> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('film_id')) {
      context.handle(_filmIdMeta,
          filmId.isAcceptableOrUnknown(data['film_id']!, _filmIdMeta));
    } else if (isInserting) {
      context.missing(_filmIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_ref')) {
      context.handle(_imageRefMeta,
          imageRef.isAcceptableOrUnknown(data['image_ref']!, _imageRefMeta));
    } else if (isInserting) {
      context.missing(_imageRefMeta);
    }
    if (data.containsKey('palette_json')) {
      context.handle(
          _paletteJsonMeta,
          paletteJson.isAcceptableOrUnknown(
              data['palette_json']!, _paletteJsonMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    if (data.containsKey('in_board')) {
      context.handle(_inBoardMeta,
          inBoard.isAcceptableOrUnknown(data['in_board']!, _inBoardMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FilmFrame map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FilmFrame(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      filmId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}film_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      imageRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_ref'])!,
      paletteJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}palette_json'])!,
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url'])!,
      inBoard: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}in_board'])!,
    );
  }

  @override
  $FilmFramesTable createAlias(String alias) {
    return $FilmFramesTable(attachedDatabase, alias);
  }
}

class FilmFrame extends DataClass implements Insertable<FilmFrame> {
  final String id;
  final String filmId;
  final String name;
  final String imageRef;
  final String paletteJson;
  final String sourceUrl;
  final bool inBoard;
  const FilmFrame(
      {required this.id,
      required this.filmId,
      required this.name,
      required this.imageRef,
      required this.paletteJson,
      required this.sourceUrl,
      required this.inBoard});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['film_id'] = Variable<String>(filmId);
    map['name'] = Variable<String>(name);
    map['image_ref'] = Variable<String>(imageRef);
    map['palette_json'] = Variable<String>(paletteJson);
    map['source_url'] = Variable<String>(sourceUrl);
    map['in_board'] = Variable<bool>(inBoard);
    return map;
  }

  FilmFramesCompanion toCompanion(bool nullToAbsent) {
    return FilmFramesCompanion(
      id: Value(id),
      filmId: Value(filmId),
      name: Value(name),
      imageRef: Value(imageRef),
      paletteJson: Value(paletteJson),
      sourceUrl: Value(sourceUrl),
      inBoard: Value(inBoard),
    );
  }

  factory FilmFrame.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FilmFrame(
      id: serializer.fromJson<String>(json['id']),
      filmId: serializer.fromJson<String>(json['filmId']),
      name: serializer.fromJson<String>(json['name']),
      imageRef: serializer.fromJson<String>(json['imageRef']),
      paletteJson: serializer.fromJson<String>(json['paletteJson']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      inBoard: serializer.fromJson<bool>(json['inBoard']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filmId': serializer.toJson<String>(filmId),
      'name': serializer.toJson<String>(name),
      'imageRef': serializer.toJson<String>(imageRef),
      'paletteJson': serializer.toJson<String>(paletteJson),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'inBoard': serializer.toJson<bool>(inBoard),
    };
  }

  FilmFrame copyWith(
          {String? id,
          String? filmId,
          String? name,
          String? imageRef,
          String? paletteJson,
          String? sourceUrl,
          bool? inBoard}) =>
      FilmFrame(
        id: id ?? this.id,
        filmId: filmId ?? this.filmId,
        name: name ?? this.name,
        imageRef: imageRef ?? this.imageRef,
        paletteJson: paletteJson ?? this.paletteJson,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        inBoard: inBoard ?? this.inBoard,
      );
  FilmFrame copyWithCompanion(FilmFramesCompanion data) {
    return FilmFrame(
      id: data.id.present ? data.id.value : this.id,
      filmId: data.filmId.present ? data.filmId.value : this.filmId,
      name: data.name.present ? data.name.value : this.name,
      imageRef: data.imageRef.present ? data.imageRef.value : this.imageRef,
      paletteJson:
          data.paletteJson.present ? data.paletteJson.value : this.paletteJson,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      inBoard: data.inBoard.present ? data.inBoard.value : this.inBoard,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FilmFrame(')
          ..write('id: $id, ')
          ..write('filmId: $filmId, ')
          ..write('name: $name, ')
          ..write('imageRef: $imageRef, ')
          ..write('paletteJson: $paletteJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('inBoard: $inBoard')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, filmId, name, imageRef, paletteJson, sourceUrl, inBoard);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilmFrame &&
          other.id == this.id &&
          other.filmId == this.filmId &&
          other.name == this.name &&
          other.imageRef == this.imageRef &&
          other.paletteJson == this.paletteJson &&
          other.sourceUrl == this.sourceUrl &&
          other.inBoard == this.inBoard);
}

class FilmFramesCompanion extends UpdateCompanion<FilmFrame> {
  final Value<String> id;
  final Value<String> filmId;
  final Value<String> name;
  final Value<String> imageRef;
  final Value<String> paletteJson;
  final Value<String> sourceUrl;
  final Value<bool> inBoard;
  final Value<int> rowid;
  const FilmFramesCompanion({
    this.id = const Value.absent(),
    this.filmId = const Value.absent(),
    this.name = const Value.absent(),
    this.imageRef = const Value.absent(),
    this.paletteJson = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.inBoard = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FilmFramesCompanion.insert({
    required String id,
    required String filmId,
    required String name,
    required String imageRef,
    this.paletteJson = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.inBoard = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        filmId = Value(filmId),
        name = Value(name),
        imageRef = Value(imageRef);
  static Insertable<FilmFrame> custom({
    Expression<String>? id,
    Expression<String>? filmId,
    Expression<String>? name,
    Expression<String>? imageRef,
    Expression<String>? paletteJson,
    Expression<String>? sourceUrl,
    Expression<bool>? inBoard,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filmId != null) 'film_id': filmId,
      if (name != null) 'name': name,
      if (imageRef != null) 'image_ref': imageRef,
      if (paletteJson != null) 'palette_json': paletteJson,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (inBoard != null) 'in_board': inBoard,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FilmFramesCompanion copyWith(
      {Value<String>? id,
      Value<String>? filmId,
      Value<String>? name,
      Value<String>? imageRef,
      Value<String>? paletteJson,
      Value<String>? sourceUrl,
      Value<bool>? inBoard,
      Value<int>? rowid}) {
    return FilmFramesCompanion(
      id: id ?? this.id,
      filmId: filmId ?? this.filmId,
      name: name ?? this.name,
      imageRef: imageRef ?? this.imageRef,
      paletteJson: paletteJson ?? this.paletteJson,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      inBoard: inBoard ?? this.inBoard,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filmId.present) {
      map['film_id'] = Variable<String>(filmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imageRef.present) {
      map['image_ref'] = Variable<String>(imageRef.value);
    }
    if (paletteJson.present) {
      map['palette_json'] = Variable<String>(paletteJson.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (inBoard.present) {
      map['in_board'] = Variable<bool>(inBoard.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilmFramesCompanion(')
          ..write('id: $id, ')
          ..write('filmId: $filmId, ')
          ..write('name: $name, ')
          ..write('imageRef: $imageRef, ')
          ..write('paletteJson: $paletteJson, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('inBoard: $inBoard, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PosesTable extends Poses with TableInfo<$PosesTable, Pose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('新手友好'));
  static const VerificationMeta _jointsJsonMeta =
      const VerificationMeta('jointsJson');
  @override
  late final GeneratedColumn<String> jointsJson = GeneratedColumn<String>(
      'joints_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tipMeta = const VerificationMeta('tip');
  @override
  late final GeneratedColumn<String> tip = GeneratedColumn<String>(
      'tip', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _lensAdviceMeta =
      const VerificationMeta('lensAdvice');
  @override
  late final GeneratedColumn<String> lensAdvice = GeneratedColumn<String>(
      'lens_advice', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _builtinMeta =
      const VerificationMeta('builtin');
  @override
  late final GeneratedColumn<bool> builtin = GeneratedColumn<bool>(
      'builtin', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("builtin" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _favoriteMeta =
      const VerificationMeta('favorite');
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
      'favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        category,
        difficulty,
        jointsJson,
        tip,
        lensAdvice,
        builtin,
        favorite
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poses';
  @override
  VerificationContext validateIntegrity(Insertable<Pose> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('joints_json')) {
      context.handle(
          _jointsJsonMeta,
          jointsJson.isAcceptableOrUnknown(
              data['joints_json']!, _jointsJsonMeta));
    } else if (isInserting) {
      context.missing(_jointsJsonMeta);
    }
    if (data.containsKey('tip')) {
      context.handle(
          _tipMeta, tip.isAcceptableOrUnknown(data['tip']!, _tipMeta));
    }
    if (data.containsKey('lens_advice')) {
      context.handle(
          _lensAdviceMeta,
          lensAdvice.isAcceptableOrUnknown(
              data['lens_advice']!, _lensAdviceMeta));
    }
    if (data.containsKey('builtin')) {
      context.handle(_builtinMeta,
          builtin.isAcceptableOrUnknown(data['builtin']!, _builtinMeta));
    }
    if (data.containsKey('favorite')) {
      context.handle(_favoriteMeta,
          favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pose(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty'])!,
      jointsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}joints_json'])!,
      tip: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tip'])!,
      lensAdvice: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lens_advice'])!,
      builtin: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}builtin'])!,
      favorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favorite'])!,
    );
  }

  @override
  $PosesTable createAlias(String alias) {
    return $PosesTable(attachedDatabase, alias);
  }
}

class Pose extends DataClass implements Insertable<Pose> {
  final String id;
  final String name;
  final String category;
  final String difficulty;
  final String jointsJson;
  final String tip;
  final String lensAdvice;
  final bool builtin;
  final bool favorite;
  const Pose(
      {required this.id,
      required this.name,
      required this.category,
      required this.difficulty,
      required this.jointsJson,
      required this.tip,
      required this.lensAdvice,
      required this.builtin,
      required this.favorite});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['difficulty'] = Variable<String>(difficulty);
    map['joints_json'] = Variable<String>(jointsJson);
    map['tip'] = Variable<String>(tip);
    map['lens_advice'] = Variable<String>(lensAdvice);
    map['builtin'] = Variable<bool>(builtin);
    map['favorite'] = Variable<bool>(favorite);
    return map;
  }

  PosesCompanion toCompanion(bool nullToAbsent) {
    return PosesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      difficulty: Value(difficulty),
      jointsJson: Value(jointsJson),
      tip: Value(tip),
      lensAdvice: Value(lensAdvice),
      builtin: Value(builtin),
      favorite: Value(favorite),
    );
  }

  factory Pose.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pose(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      jointsJson: serializer.fromJson<String>(json['jointsJson']),
      tip: serializer.fromJson<String>(json['tip']),
      lensAdvice: serializer.fromJson<String>(json['lensAdvice']),
      builtin: serializer.fromJson<bool>(json['builtin']),
      favorite: serializer.fromJson<bool>(json['favorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'difficulty': serializer.toJson<String>(difficulty),
      'jointsJson': serializer.toJson<String>(jointsJson),
      'tip': serializer.toJson<String>(tip),
      'lensAdvice': serializer.toJson<String>(lensAdvice),
      'builtin': serializer.toJson<bool>(builtin),
      'favorite': serializer.toJson<bool>(favorite),
    };
  }

  Pose copyWith(
          {String? id,
          String? name,
          String? category,
          String? difficulty,
          String? jointsJson,
          String? tip,
          String? lensAdvice,
          bool? builtin,
          bool? favorite}) =>
      Pose(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        jointsJson: jointsJson ?? this.jointsJson,
        tip: tip ?? this.tip,
        lensAdvice: lensAdvice ?? this.lensAdvice,
        builtin: builtin ?? this.builtin,
        favorite: favorite ?? this.favorite,
      );
  Pose copyWithCompanion(PosesCompanion data) {
    return Pose(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      jointsJson:
          data.jointsJson.present ? data.jointsJson.value : this.jointsJson,
      tip: data.tip.present ? data.tip.value : this.tip,
      lensAdvice:
          data.lensAdvice.present ? data.lensAdvice.value : this.lensAdvice,
      builtin: data.builtin.present ? data.builtin.value : this.builtin,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pose(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('difficulty: $difficulty, ')
          ..write('jointsJson: $jointsJson, ')
          ..write('tip: $tip, ')
          ..write('lensAdvice: $lensAdvice, ')
          ..write('builtin: $builtin, ')
          ..write('favorite: $favorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, category, difficulty, jointsJson,
      tip, lensAdvice, builtin, favorite);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pose &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.difficulty == this.difficulty &&
          other.jointsJson == this.jointsJson &&
          other.tip == this.tip &&
          other.lensAdvice == this.lensAdvice &&
          other.builtin == this.builtin &&
          other.favorite == this.favorite);
}

class PosesCompanion extends UpdateCompanion<Pose> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> difficulty;
  final Value<String> jointsJson;
  final Value<String> tip;
  final Value<String> lensAdvice;
  final Value<bool> builtin;
  final Value<bool> favorite;
  final Value<int> rowid;
  const PosesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.jointsJson = const Value.absent(),
    this.tip = const Value.absent(),
    this.lensAdvice = const Value.absent(),
    this.builtin = const Value.absent(),
    this.favorite = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PosesCompanion.insert({
    required String id,
    required String name,
    required String category,
    this.difficulty = const Value.absent(),
    required String jointsJson,
    this.tip = const Value.absent(),
    this.lensAdvice = const Value.absent(),
    this.builtin = const Value.absent(),
    this.favorite = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        category = Value(category),
        jointsJson = Value(jointsJson);
  static Insertable<Pose> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? difficulty,
    Expression<String>? jointsJson,
    Expression<String>? tip,
    Expression<String>? lensAdvice,
    Expression<bool>? builtin,
    Expression<bool>? favorite,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (difficulty != null) 'difficulty': difficulty,
      if (jointsJson != null) 'joints_json': jointsJson,
      if (tip != null) 'tip': tip,
      if (lensAdvice != null) 'lens_advice': lensAdvice,
      if (builtin != null) 'builtin': builtin,
      if (favorite != null) 'favorite': favorite,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PosesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? category,
      Value<String>? difficulty,
      Value<String>? jointsJson,
      Value<String>? tip,
      Value<String>? lensAdvice,
      Value<bool>? builtin,
      Value<bool>? favorite,
      Value<int>? rowid}) {
    return PosesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      jointsJson: jointsJson ?? this.jointsJson,
      tip: tip ?? this.tip,
      lensAdvice: lensAdvice ?? this.lensAdvice,
      builtin: builtin ?? this.builtin,
      favorite: favorite ?? this.favorite,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (jointsJson.present) {
      map['joints_json'] = Variable<String>(jointsJson.value);
    }
    if (tip.present) {
      map['tip'] = Variable<String>(tip.value);
    }
    if (lensAdvice.present) {
      map['lens_advice'] = Variable<String>(lensAdvice.value);
    }
    if (builtin.present) {
      map['builtin'] = Variable<bool>(builtin.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PosesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('difficulty: $difficulty, ')
          ..write('jointsJson: $jointsJson, ')
          ..write('tip: $tip, ')
          ..write('lensAdvice: $lensAdvice, ')
          ..write('builtin: $builtin, ')
          ..write('favorite: $favorite, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LightingScenesTable extends LightingScenes
    with TableInfo<$LightingScenesTable, LightingScene> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LightingScenesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sceneJsonMeta =
      const VerificationMeta('sceneJson');
  @override
  late final GeneratedColumn<String> sceneJson = GeneratedColumn<String>(
      'scene_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _linkedPoseIdMeta =
      const VerificationMeta('linkedPoseId');
  @override
  late final GeneratedColumn<String> linkedPoseId = GeneratedColumn<String>(
      'linked_pose_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES poses(id) ON DELETE SET NULL');
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, sceneJson, linkedPoseId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lighting_scenes';
  @override
  VerificationContext validateIntegrity(Insertable<LightingScene> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('scene_json')) {
      context.handle(_sceneJsonMeta,
          sceneJson.isAcceptableOrUnknown(data['scene_json']!, _sceneJsonMeta));
    } else if (isInserting) {
      context.missing(_sceneJsonMeta);
    }
    if (data.containsKey('linked_pose_id')) {
      context.handle(
          _linkedPoseIdMeta,
          linkedPoseId.isAcceptableOrUnknown(
              data['linked_pose_id']!, _linkedPoseIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LightingScene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LightingScene(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sceneJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scene_json'])!,
      linkedPoseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}linked_pose_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LightingScenesTable createAlias(String alias) {
    return $LightingScenesTable(attachedDatabase, alias);
  }
}

class LightingScene extends DataClass implements Insertable<LightingScene> {
  final String id;
  final String name;
  final String sceneJson;
  final String? linkedPoseId;
  final int updatedAt;
  const LightingScene(
      {required this.id,
      required this.name,
      required this.sceneJson,
      this.linkedPoseId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['scene_json'] = Variable<String>(sceneJson);
    if (!nullToAbsent || linkedPoseId != null) {
      map['linked_pose_id'] = Variable<String>(linkedPoseId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LightingScenesCompanion toCompanion(bool nullToAbsent) {
    return LightingScenesCompanion(
      id: Value(id),
      name: Value(name),
      sceneJson: Value(sceneJson),
      linkedPoseId: linkedPoseId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedPoseId),
      updatedAt: Value(updatedAt),
    );
  }

  factory LightingScene.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LightingScene(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sceneJson: serializer.fromJson<String>(json['sceneJson']),
      linkedPoseId: serializer.fromJson<String?>(json['linkedPoseId']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sceneJson': serializer.toJson<String>(sceneJson),
      'linkedPoseId': serializer.toJson<String?>(linkedPoseId),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LightingScene copyWith(
          {String? id,
          String? name,
          String? sceneJson,
          Value<String?> linkedPoseId = const Value.absent(),
          int? updatedAt}) =>
      LightingScene(
        id: id ?? this.id,
        name: name ?? this.name,
        sceneJson: sceneJson ?? this.sceneJson,
        linkedPoseId:
            linkedPoseId.present ? linkedPoseId.value : this.linkedPoseId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LightingScene copyWithCompanion(LightingScenesCompanion data) {
    return LightingScene(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sceneJson: data.sceneJson.present ? data.sceneJson.value : this.sceneJson,
      linkedPoseId: data.linkedPoseId.present
          ? data.linkedPoseId.value
          : this.linkedPoseId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LightingScene(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sceneJson: $sceneJson, ')
          ..write('linkedPoseId: $linkedPoseId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sceneJson, linkedPoseId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LightingScene &&
          other.id == this.id &&
          other.name == this.name &&
          other.sceneJson == this.sceneJson &&
          other.linkedPoseId == this.linkedPoseId &&
          other.updatedAt == this.updatedAt);
}

class LightingScenesCompanion extends UpdateCompanion<LightingScene> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> sceneJson;
  final Value<String?> linkedPoseId;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LightingScenesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sceneJson = const Value.absent(),
    this.linkedPoseId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LightingScenesCompanion.insert({
    required String id,
    required String name,
    required String sceneJson,
    this.linkedPoseId = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        sceneJson = Value(sceneJson),
        updatedAt = Value(updatedAt);
  static Insertable<LightingScene> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sceneJson,
    Expression<String>? linkedPoseId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sceneJson != null) 'scene_json': sceneJson,
      if (linkedPoseId != null) 'linked_pose_id': linkedPoseId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LightingScenesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? sceneJson,
      Value<String?>? linkedPoseId,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return LightingScenesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sceneJson: sceneJson ?? this.sceneJson,
      linkedPoseId: linkedPoseId ?? this.linkedPoseId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sceneJson.present) {
      map['scene_json'] = Variable<String>(sceneJson.value);
    }
    if (linkedPoseId.present) {
      map['linked_pose_id'] = Variable<String>(linkedPoseId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LightingScenesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sceneJson: $sceneJson, ')
          ..write('linkedPoseId: $linkedPoseId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GearItemsTable extends GearItems
    with TableInfo<$GearItemsTable, GearItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GearItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mountMeta = const VerificationMeta('mount');
  @override
  late final GeneratedColumn<String> mount = GeneratedColumn<String>(
      'mount', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _specsJsonMeta =
      const VerificationMeta('specsJson');
  @override
  late final GeneratedColumn<String> specsJson = GeneratedColumn<String>(
      'specs_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _priceRefMeta =
      const VerificationMeta('priceRef');
  @override
  late final GeneratedColumn<double> priceRef = GeneratedColumn<double>(
      'price_ref', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _builtinMeta =
      const VerificationMeta('builtin');
  @override
  late final GeneratedColumn<bool> builtin = GeneratedColumn<bool>(
      'builtin', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("builtin" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, kind, brand, model, mount, specsJson, priceRef, builtin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gear_items';
  @override
  VerificationContext validateIntegrity(Insertable<GearItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('mount')) {
      context.handle(
          _mountMeta, mount.isAcceptableOrUnknown(data['mount']!, _mountMeta));
    }
    if (data.containsKey('specs_json')) {
      context.handle(_specsJsonMeta,
          specsJson.isAcceptableOrUnknown(data['specs_json']!, _specsJsonMeta));
    }
    if (data.containsKey('price_ref')) {
      context.handle(_priceRefMeta,
          priceRef.isAcceptableOrUnknown(data['price_ref']!, _priceRefMeta));
    }
    if (data.containsKey('builtin')) {
      context.handle(_builtinMeta,
          builtin.isAcceptableOrUnknown(data['builtin']!, _builtinMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GearItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GearItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      mount: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mount'])!,
      specsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}specs_json'])!,
      priceRef: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_ref']),
      builtin: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}builtin'])!,
    );
  }

  @override
  $GearItemsTable createAlias(String alias) {
    return $GearItemsTable(attachedDatabase, alias);
  }
}

class GearItem extends DataClass implements Insertable<GearItem> {
  final String id;
  final String kind;
  final String brand;
  final String model;
  final String mount;
  final String specsJson;
  final double? priceRef;
  final bool builtin;
  const GearItem(
      {required this.id,
      required this.kind,
      required this.brand,
      required this.model,
      required this.mount,
      required this.specsJson,
      this.priceRef,
      required this.builtin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['brand'] = Variable<String>(brand);
    map['model'] = Variable<String>(model);
    map['mount'] = Variable<String>(mount);
    map['specs_json'] = Variable<String>(specsJson);
    if (!nullToAbsent || priceRef != null) {
      map['price_ref'] = Variable<double>(priceRef);
    }
    map['builtin'] = Variable<bool>(builtin);
    return map;
  }

  GearItemsCompanion toCompanion(bool nullToAbsent) {
    return GearItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      brand: Value(brand),
      model: Value(model),
      mount: Value(mount),
      specsJson: Value(specsJson),
      priceRef: priceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(priceRef),
      builtin: Value(builtin),
    );
  }

  factory GearItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GearItem(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      brand: serializer.fromJson<String>(json['brand']),
      model: serializer.fromJson<String>(json['model']),
      mount: serializer.fromJson<String>(json['mount']),
      specsJson: serializer.fromJson<String>(json['specsJson']),
      priceRef: serializer.fromJson<double?>(json['priceRef']),
      builtin: serializer.fromJson<bool>(json['builtin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'brand': serializer.toJson<String>(brand),
      'model': serializer.toJson<String>(model),
      'mount': serializer.toJson<String>(mount),
      'specsJson': serializer.toJson<String>(specsJson),
      'priceRef': serializer.toJson<double?>(priceRef),
      'builtin': serializer.toJson<bool>(builtin),
    };
  }

  GearItem copyWith(
          {String? id,
          String? kind,
          String? brand,
          String? model,
          String? mount,
          String? specsJson,
          Value<double?> priceRef = const Value.absent(),
          bool? builtin}) =>
      GearItem(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        mount: mount ?? this.mount,
        specsJson: specsJson ?? this.specsJson,
        priceRef: priceRef.present ? priceRef.value : this.priceRef,
        builtin: builtin ?? this.builtin,
      );
  GearItem copyWithCompanion(GearItemsCompanion data) {
    return GearItem(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      brand: data.brand.present ? data.brand.value : this.brand,
      model: data.model.present ? data.model.value : this.model,
      mount: data.mount.present ? data.mount.value : this.mount,
      specsJson: data.specsJson.present ? data.specsJson.value : this.specsJson,
      priceRef: data.priceRef.present ? data.priceRef.value : this.priceRef,
      builtin: data.builtin.present ? data.builtin.value : this.builtin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GearItem(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('mount: $mount, ')
          ..write('specsJson: $specsJson, ')
          ..write('priceRef: $priceRef, ')
          ..write('builtin: $builtin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, brand, model, mount, specsJson, priceRef, builtin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GearItem &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.brand == this.brand &&
          other.model == this.model &&
          other.mount == this.mount &&
          other.specsJson == this.specsJson &&
          other.priceRef == this.priceRef &&
          other.builtin == this.builtin);
}

class GearItemsCompanion extends UpdateCompanion<GearItem> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> brand;
  final Value<String> model;
  final Value<String> mount;
  final Value<String> specsJson;
  final Value<double?> priceRef;
  final Value<bool> builtin;
  final Value<int> rowid;
  const GearItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.brand = const Value.absent(),
    this.model = const Value.absent(),
    this.mount = const Value.absent(),
    this.specsJson = const Value.absent(),
    this.priceRef = const Value.absent(),
    this.builtin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GearItemsCompanion.insert({
    required String id,
    required String kind,
    required String brand,
    required String model,
    this.mount = const Value.absent(),
    this.specsJson = const Value.absent(),
    this.priceRef = const Value.absent(),
    this.builtin = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        brand = Value(brand),
        model = Value(model);
  static Insertable<GearItem> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? brand,
    Expression<String>? model,
    Expression<String>? mount,
    Expression<String>? specsJson,
    Expression<double>? priceRef,
    Expression<bool>? builtin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (mount != null) 'mount': mount,
      if (specsJson != null) 'specs_json': specsJson,
      if (priceRef != null) 'price_ref': priceRef,
      if (builtin != null) 'builtin': builtin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GearItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String>? brand,
      Value<String>? model,
      Value<String>? mount,
      Value<String>? specsJson,
      Value<double?>? priceRef,
      Value<bool>? builtin,
      Value<int>? rowid}) {
    return GearItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      mount: mount ?? this.mount,
      specsJson: specsJson ?? this.specsJson,
      priceRef: priceRef ?? this.priceRef,
      builtin: builtin ?? this.builtin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (mount.present) {
      map['mount'] = Variable<String>(mount.value);
    }
    if (specsJson.present) {
      map['specs_json'] = Variable<String>(specsJson.value);
    }
    if (priceRef.present) {
      map['price_ref'] = Variable<double>(priceRef.value);
    }
    if (builtin.present) {
      map['builtin'] = Variable<bool>(builtin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GearItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('brand: $brand, ')
          ..write('model: $model, ')
          ..write('mount: $mount, ')
          ..write('specsJson: $specsJson, ')
          ..write('priceRef: $priceRef, ')
          ..write('builtin: $builtin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlansTable extends Plans with TableInfo<$PlansTable, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('draft'));
  static const VerificationMeta _modulesJsonMeta =
      const VerificationMeta('modulesJson');
  @override
  late final GeneratedColumn<String> modulesJson = GeneratedColumn<String>(
      'modules_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, status, modulesJson, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(Insertable<Plan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('modules_json')) {
      context.handle(
          _modulesJsonMeta,
          modulesJson.isAcceptableOrUnknown(
              data['modules_json']!, _modulesJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      modulesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modules_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PlansTable createAlias(String alias) {
    return $PlansTable(attachedDatabase, alias);
  }
}

class Plan extends DataClass implements Insertable<Plan> {
  final String id;
  final String title;
  final String status;
  final String modulesJson;
  final int createdAt;
  final int updatedAt;
  const Plan(
      {required this.id,
      required this.title,
      required this.status,
      required this.modulesJson,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['modules_json'] = Variable<String>(modulesJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      id: Value(id),
      title: Value(title),
      status: Value(status),
      modulesJson: Value(modulesJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Plan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      modulesJson: serializer.fromJson<String>(json['modulesJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'modulesJson': serializer.toJson<String>(modulesJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Plan copyWith(
          {String? id,
          String? title,
          String? status,
          String? modulesJson,
          int? createdAt,
          int? updatedAt}) =>
      Plan(
        id: id ?? this.id,
        title: title ?? this.title,
        status: status ?? this.status,
        modulesJson: modulesJson ?? this.modulesJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      modulesJson:
          data.modulesJson.present ? data.modulesJson.value : this.modulesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('modulesJson: $modulesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, status, modulesJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          other.id == this.id &&
          other.title == this.title &&
          other.status == this.status &&
          other.modulesJson == this.modulesJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> status;
  final Value<String> modulesJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PlansCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.modulesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required String id,
    required String title,
    this.status = const Value.absent(),
    this.modulesJson = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Plan> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? status,
    Expression<String>? modulesJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (modulesJson != null) 'modules_json': modulesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? status,
      Value<String>? modulesJson,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return PlansCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      modulesJson: modulesJson ?? this.modulesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (modulesJson.present) {
      map['modules_json'] = Variable<String>(modulesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('modulesJson: $modulesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanSnapshotsTable extends PlanSnapshots
    with TableInfo<$PlanSnapshotsTable, PlanSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES plans(id) ON DELETE CASCADE');
  static const VerificationMeta _modulesJsonMeta =
      const VerificationMeta('modulesJson');
  @override
  late final GeneratedColumn<String> modulesJson = GeneratedColumn<String>(
      'modules_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, planId, modulesJson, label, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<PlanSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('modules_json')) {
      context.handle(
          _modulesJsonMeta,
          modulesJson.isAcceptableOrUnknown(
              data['modules_json']!, _modulesJsonMeta));
    } else if (isInserting) {
      context.missing(_modulesJsonMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      modulesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}modules_json'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PlanSnapshotsTable createAlias(String alias) {
    return $PlanSnapshotsTable(attachedDatabase, alias);
  }
}

class PlanSnapshot extends DataClass implements Insertable<PlanSnapshot> {
  final String id;
  final String planId;
  final String modulesJson;
  final String? label;
  final int createdAt;
  const PlanSnapshot(
      {required this.id,
      required this.planId,
      required this.modulesJson,
      this.label,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['modules_json'] = Variable<String>(modulesJson);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PlanSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return PlanSnapshotsCompanion(
      id: Value(id),
      planId: Value(planId),
      modulesJson: Value(modulesJson),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory PlanSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanSnapshot(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      modulesJson: serializer.fromJson<String>(json['modulesJson']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'modulesJson': serializer.toJson<String>(modulesJson),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PlanSnapshot copyWith(
          {String? id,
          String? planId,
          String? modulesJson,
          Value<String?> label = const Value.absent(),
          int? createdAt}) =>
      PlanSnapshot(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        modulesJson: modulesJson ?? this.modulesJson,
        label: label.present ? label.value : this.label,
        createdAt: createdAt ?? this.createdAt,
      );
  PlanSnapshot copyWithCompanion(PlanSnapshotsCompanion data) {
    return PlanSnapshot(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      modulesJson:
          data.modulesJson.present ? data.modulesJson.value : this.modulesJson,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanSnapshot(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('modulesJson: $modulesJson, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, modulesJson, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanSnapshot &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.modulesJson == this.modulesJson &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class PlanSnapshotsCompanion extends UpdateCompanion<PlanSnapshot> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> modulesJson;
  final Value<String?> label;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PlanSnapshotsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.modulesJson = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanSnapshotsCompanion.insert({
    required String id,
    required String planId,
    required String modulesJson,
    this.label = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        planId = Value(planId),
        modulesJson = Value(modulesJson),
        createdAt = Value(createdAt);
  static Insertable<PlanSnapshot> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? modulesJson,
    Expression<String>? label,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (modulesJson != null) 'modules_json': modulesJson,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanSnapshotsCompanion copyWith(
      {Value<String>? id,
      Value<String>? planId,
      Value<String>? modulesJson,
      Value<String?>? label,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return PlanSnapshotsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      modulesJson: modulesJson ?? this.modulesJson,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (modulesJson.present) {
      map['modules_json'] = Variable<String>(modulesJson.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('modulesJson: $modulesJson, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderConfigsTable extends ProviderConfigs
    with TableInfo<$ProviderConfigsTable, ProviderConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseUrlMeta =
      const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
      'base_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _protocolMeta =
      const VerificationMeta('protocol');
  @override
  late final GeneratedColumn<String> protocol = GeneratedColumn<String>(
      'protocol', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('openai'));
  static const VerificationMeta _encryptedKeyMeta =
      const VerificationMeta('encryptedKey');
  @override
  late final GeneratedColumn<String> encryptedKey = GeneratedColumn<String>(
      'encrypted_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _defaultModelMeta =
      const VerificationMeta('defaultModel');
  @override
  late final GeneratedColumn<String> defaultModel = GeneratedColumn<String>(
      'default_model', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _modelsJsonMeta =
      const VerificationMeta('modelsJson');
  @override
  late final GeneratedColumn<String> modelsJson = GeneratedColumn<String>(
      'models_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        baseUrl,
        protocol,
        encryptedKey,
        defaultModel,
        modelsJson,
        enabled,
        priority
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_configs';
  @override
  VerificationContext validateIntegrity(Insertable<ProviderConfig> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta,
          baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('protocol')) {
      context.handle(_protocolMeta,
          protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta));
    }
    if (data.containsKey('encrypted_key')) {
      context.handle(
          _encryptedKeyMeta,
          encryptedKey.isAcceptableOrUnknown(
              data['encrypted_key']!, _encryptedKeyMeta));
    }
    if (data.containsKey('default_model')) {
      context.handle(
          _defaultModelMeta,
          defaultModel.isAcceptableOrUnknown(
              data['default_model']!, _defaultModelMeta));
    }
    if (data.containsKey('models_json')) {
      context.handle(
          _modelsJsonMeta,
          modelsJson.isAcceptableOrUnknown(
              data['models_json']!, _modelsJsonMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderConfig(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      baseUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_url'])!,
      protocol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}protocol'])!,
      encryptedKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}encrypted_key'])!,
      defaultModel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}default_model'])!,
      modelsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}models_json'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
    );
  }

  @override
  $ProviderConfigsTable createAlias(String alias) {
    return $ProviderConfigsTable(attachedDatabase, alias);
  }
}

class ProviderConfig extends DataClass implements Insertable<ProviderConfig> {
  final String id;
  final String name;
  final String baseUrl;
  final String protocol;
  final String encryptedKey;
  final String defaultModel;
  final String modelsJson;
  final bool enabled;
  final int priority;
  const ProviderConfig(
      {required this.id,
      required this.name,
      required this.baseUrl,
      required this.protocol,
      required this.encryptedKey,
      required this.defaultModel,
      required this.modelsJson,
      required this.enabled,
      required this.priority});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['protocol'] = Variable<String>(protocol);
    map['encrypted_key'] = Variable<String>(encryptedKey);
    map['default_model'] = Variable<String>(defaultModel);
    map['models_json'] = Variable<String>(modelsJson);
    map['enabled'] = Variable<bool>(enabled);
    map['priority'] = Variable<int>(priority);
    return map;
  }

  ProviderConfigsCompanion toCompanion(bool nullToAbsent) {
    return ProviderConfigsCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      protocol: Value(protocol),
      encryptedKey: Value(encryptedKey),
      defaultModel: Value(defaultModel),
      modelsJson: Value(modelsJson),
      enabled: Value(enabled),
      priority: Value(priority),
    );
  }

  factory ProviderConfig.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderConfig(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      protocol: serializer.fromJson<String>(json['protocol']),
      encryptedKey: serializer.fromJson<String>(json['encryptedKey']),
      defaultModel: serializer.fromJson<String>(json['defaultModel']),
      modelsJson: serializer.fromJson<String>(json['modelsJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'protocol': serializer.toJson<String>(protocol),
      'encryptedKey': serializer.toJson<String>(encryptedKey),
      'defaultModel': serializer.toJson<String>(defaultModel),
      'modelsJson': serializer.toJson<String>(modelsJson),
      'enabled': serializer.toJson<bool>(enabled),
      'priority': serializer.toJson<int>(priority),
    };
  }

  ProviderConfig copyWith(
          {String? id,
          String? name,
          String? baseUrl,
          String? protocol,
          String? encryptedKey,
          String? defaultModel,
          String? modelsJson,
          bool? enabled,
          int? priority}) =>
      ProviderConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        protocol: protocol ?? this.protocol,
        encryptedKey: encryptedKey ?? this.encryptedKey,
        defaultModel: defaultModel ?? this.defaultModel,
        modelsJson: modelsJson ?? this.modelsJson,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
      );
  ProviderConfig copyWithCompanion(ProviderConfigsCompanion data) {
    return ProviderConfig(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      encryptedKey: data.encryptedKey.present
          ? data.encryptedKey.value
          : this.encryptedKey,
      defaultModel: data.defaultModel.present
          ? data.defaultModel.value
          : this.defaultModel,
      modelsJson:
          data.modelsJson.present ? data.modelsJson.value : this.modelsJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfig(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('protocol: $protocol, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('modelsJson: $modelsJson, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, baseUrl, protocol, encryptedKey,
      defaultModel, modelsJson, enabled, priority);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfig &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.protocol == this.protocol &&
          other.encryptedKey == this.encryptedKey &&
          other.defaultModel == this.defaultModel &&
          other.modelsJson == this.modelsJson &&
          other.enabled == this.enabled &&
          other.priority == this.priority);
}

class ProviderConfigsCompanion extends UpdateCompanion<ProviderConfig> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> protocol;
  final Value<String> encryptedKey;
  final Value<String> defaultModel;
  final Value<String> modelsJson;
  final Value<bool> enabled;
  final Value<int> priority;
  final Value<int> rowid;
  const ProviderConfigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.protocol = const Value.absent(),
    this.encryptedKey = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.modelsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderConfigsCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    this.protocol = const Value.absent(),
    this.encryptedKey = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.modelsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        baseUrl = Value(baseUrl);
  static Insertable<ProviderConfig> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? protocol,
    Expression<String>? encryptedKey,
    Expression<String>? defaultModel,
    Expression<String>? modelsJson,
    Expression<bool>? enabled,
    Expression<int>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (protocol != null) 'protocol': protocol,
      if (encryptedKey != null) 'encrypted_key': encryptedKey,
      if (defaultModel != null) 'default_model': defaultModel,
      if (modelsJson != null) 'models_json': modelsJson,
      if (enabled != null) 'enabled': enabled,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderConfigsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? baseUrl,
      Value<String>? protocol,
      Value<String>? encryptedKey,
      Value<String>? defaultModel,
      Value<String>? modelsJson,
      Value<bool>? enabled,
      Value<int>? priority,
      Value<int>? rowid}) {
    return ProviderConfigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      protocol: protocol ?? this.protocol,
      encryptedKey: encryptedKey ?? this.encryptedKey,
      defaultModel: defaultModel ?? this.defaultModel,
      modelsJson: modelsJson ?? this.modelsJson,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<String>(protocol.value);
    }
    if (encryptedKey.present) {
      map['encrypted_key'] = Variable<String>(encryptedKey.value);
    }
    if (defaultModel.present) {
      map['default_model'] = Variable<String>(defaultModel.value);
    }
    if (modelsJson.present) {
      map['models_json'] = Variable<String>(modelsJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('protocol: $protocol, ')
          ..write('encryptedKey: $encryptedKey, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('modelsJson: $modelsJson, ')
          ..write('enabled: $enabled, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CallLogsTable extends CallLogs with TableInfo<$CallLogsTable, CallLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CallLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _successMeta =
      const VerificationMeta('success');
  @override
  late final GeneratedColumn<bool> success = GeneratedColumn<bool>(
      'success', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("success" IN (0, 1))'));
  static const VerificationMeta _latencyMsMeta =
      const VerificationMeta('latencyMs');
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
      'latency_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _promptTokensMeta =
      const VerificationMeta('promptTokens');
  @override
  late final GeneratedColumn<int> promptTokens = GeneratedColumn<int>(
      'prompt_tokens', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _completionTokensMeta =
      const VerificationMeta('completionTokens');
  @override
  late final GeneratedColumn<int> completionTokens = GeneratedColumn<int>(
      'completion_tokens', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
      'error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        providerId,
        model,
        success,
        latencyMs,
        promptTokens,
        completionTokens,
        error,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'call_logs';
  @override
  VerificationContext validateIntegrity(Insertable<CallLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('success')) {
      context.handle(_successMeta,
          success.isAcceptableOrUnknown(data['success']!, _successMeta));
    } else if (isInserting) {
      context.missing(_successMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(_latencyMsMeta,
          latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta));
    } else if (isInserting) {
      context.missing(_latencyMsMeta);
    }
    if (data.containsKey('prompt_tokens')) {
      context.handle(
          _promptTokensMeta,
          promptTokens.isAcceptableOrUnknown(
              data['prompt_tokens']!, _promptTokensMeta));
    }
    if (data.containsKey('completion_tokens')) {
      context.handle(
          _completionTokensMeta,
          completionTokens.isAcceptableOrUnknown(
              data['completion_tokens']!, _completionTokensMeta));
    }
    if (data.containsKey('error')) {
      context.handle(
          _errorMeta, error.isAcceptableOrUnknown(data['error']!, _errorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CallLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CallLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      success: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}success'])!,
      latencyMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}latency_ms'])!,
      promptTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}prompt_tokens'])!,
      completionTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completion_tokens'])!,
      error: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CallLogsTable createAlias(String alias) {
    return $CallLogsTable(attachedDatabase, alias);
  }
}

class CallLog extends DataClass implements Insertable<CallLog> {
  final int id;
  final String providerId;
  final String model;
  final bool success;
  final int latencyMs;
  final int promptTokens;
  final int completionTokens;
  final String? error;
  final int createdAt;
  const CallLog(
      {required this.id,
      required this.providerId,
      required this.model,
      required this.success,
      required this.latencyMs,
      required this.promptTokens,
      required this.completionTokens,
      this.error,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['model'] = Variable<String>(model);
    map['success'] = Variable<bool>(success);
    map['latency_ms'] = Variable<int>(latencyMs);
    map['prompt_tokens'] = Variable<int>(promptTokens);
    map['completion_tokens'] = Variable<int>(completionTokens);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  CallLogsCompanion toCompanion(bool nullToAbsent) {
    return CallLogsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      model: Value(model),
      success: Value(success),
      latencyMs: Value(latencyMs),
      promptTokens: Value(promptTokens),
      completionTokens: Value(completionTokens),
      error:
          error == null && nullToAbsent ? const Value.absent() : Value(error),
      createdAt: Value(createdAt),
    );
  }

  factory CallLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CallLog(
      id: serializer.fromJson<int>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      model: serializer.fromJson<String>(json['model']),
      success: serializer.fromJson<bool>(json['success']),
      latencyMs: serializer.fromJson<int>(json['latencyMs']),
      promptTokens: serializer.fromJson<int>(json['promptTokens']),
      completionTokens: serializer.fromJson<int>(json['completionTokens']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'providerId': serializer.toJson<String>(providerId),
      'model': serializer.toJson<String>(model),
      'success': serializer.toJson<bool>(success),
      'latencyMs': serializer.toJson<int>(latencyMs),
      'promptTokens': serializer.toJson<int>(promptTokens),
      'completionTokens': serializer.toJson<int>(completionTokens),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  CallLog copyWith(
          {int? id,
          String? providerId,
          String? model,
          bool? success,
          int? latencyMs,
          int? promptTokens,
          int? completionTokens,
          Value<String?> error = const Value.absent(),
          int? createdAt}) =>
      CallLog(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        model: model ?? this.model,
        success: success ?? this.success,
        latencyMs: latencyMs ?? this.latencyMs,
        promptTokens: promptTokens ?? this.promptTokens,
        completionTokens: completionTokens ?? this.completionTokens,
        error: error.present ? error.value : this.error,
        createdAt: createdAt ?? this.createdAt,
      );
  CallLog copyWithCompanion(CallLogsCompanion data) {
    return CallLog(
      id: data.id.present ? data.id.value : this.id,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      model: data.model.present ? data.model.value : this.model,
      success: data.success.present ? data.success.value : this.success,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      promptTokens: data.promptTokens.present
          ? data.promptTokens.value
          : this.promptTokens,
      completionTokens: data.completionTokens.present
          ? data.completionTokens.value
          : this.completionTokens,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CallLog(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('success: $success, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, providerId, model, success, latencyMs,
      promptTokens, completionTokens, error, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CallLog &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.model == this.model &&
          other.success == this.success &&
          other.latencyMs == this.latencyMs &&
          other.promptTokens == this.promptTokens &&
          other.completionTokens == this.completionTokens &&
          other.error == this.error &&
          other.createdAt == this.createdAt);
}

class CallLogsCompanion extends UpdateCompanion<CallLog> {
  final Value<int> id;
  final Value<String> providerId;
  final Value<String> model;
  final Value<bool> success;
  final Value<int> latencyMs;
  final Value<int> promptTokens;
  final Value<int> completionTokens;
  final Value<String?> error;
  final Value<int> createdAt;
  const CallLogsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.model = const Value.absent(),
    this.success = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CallLogsCompanion.insert({
    this.id = const Value.absent(),
    required String providerId,
    required String model,
    required bool success,
    required int latencyMs,
    this.promptTokens = const Value.absent(),
    this.completionTokens = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
  })  : providerId = Value(providerId),
        model = Value(model),
        success = Value(success),
        latencyMs = Value(latencyMs),
        createdAt = Value(createdAt);
  static Insertable<CallLog> custom({
    Expression<int>? id,
    Expression<String>? providerId,
    Expression<String>? model,
    Expression<bool>? success,
    Expression<int>? latencyMs,
    Expression<int>? promptTokens,
    Expression<int>? completionTokens,
    Expression<String>? error,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (model != null) 'model': model,
      if (success != null) 'success': success,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (promptTokens != null) 'prompt_tokens': promptTokens,
      if (completionTokens != null) 'completion_tokens': completionTokens,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CallLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? providerId,
      Value<String>? model,
      Value<bool>? success,
      Value<int>? latencyMs,
      Value<int>? promptTokens,
      Value<int>? completionTokens,
      Value<String?>? error,
      Value<int>? createdAt}) {
    return CallLogsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      success: success ?? this.success,
      latencyMs: latencyMs ?? this.latencyMs,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (success.present) {
      map['success'] = Variable<bool>(success.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (promptTokens.present) {
      map['prompt_tokens'] = Variable<int>(promptTokens.value);
    }
    if (completionTokens.present) {
      map['completion_tokens'] = Variable<int>(completionTokens.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CallLogsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('success: $success, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('promptTokens: $promptTokens, ')
          ..write('completionTokens: $completionTokens, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ResourcesTable resources = $ResourcesTable(this);
  late final $ResourceImagesTable resourceImages = $ResourceImagesTable(this);
  late final $FilmsTable films = $FilmsTable(this);
  late final $FilmFramesTable filmFrames = $FilmFramesTable(this);
  late final $PosesTable poses = $PosesTable(this);
  late final $LightingScenesTable lightingScenes = $LightingScenesTable(this);
  late final $GearItemsTable gearItems = $GearItemsTable(this);
  late final $PlansTable plans = $PlansTable(this);
  late final $PlanSnapshotsTable planSnapshots = $PlanSnapshotsTable(this);
  late final $ProviderConfigsTable providerConfigs =
      $ProviderConfigsTable(this);
  late final $CallLogsTable callLogs = $CallLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        resources,
        resourceImages,
        films,
        filmFrames,
        poses,
        lightingScenes,
        gearItems,
        plans,
        planSnapshots,
        providerConfigs,
        callLogs,
        settings
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('resources',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('resource_images', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('films',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('film_frames', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('poses',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('lighting_scenes', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('plans',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('plan_snapshots', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$ResourcesTableCreateCompanionBuilder = ResourcesCompanion Function({
  required String id,
  required String type,
  required String name,
  Value<String> fieldsJson,
  Value<String?> coverImage,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$ResourcesTableUpdateCompanionBuilder = ResourcesCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> name,
  Value<String> fieldsJson,
  Value<String?> coverImage,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$ResourcesTableReferences
    extends BaseReferences<_$AppDatabase, $ResourcesTable, Resource> {
  $$ResourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ResourceImagesTable, List<ResourceImage>>
      _resourceImagesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.resourceImages,
              aliasName: $_aliasNameGenerator(
                  db.resources.id, db.resourceImages.resourceId));

  $$ResourceImagesTableProcessedTableManager get resourceImagesRefs {
    final manager = $$ResourceImagesTableTableManager($_db, $_db.resourceImages)
        .filter((f) => f.resourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_resourceImagesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverImage => $composableBuilder(
      column: $table.coverImage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> resourceImagesRefs(
      Expression<bool> Function($$ResourceImagesTableFilterComposer f) f) {
    final $$ResourceImagesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.resourceImages,
        getReferencedColumn: (t) => t.resourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ResourceImagesTableFilterComposer(
              $db: $db,
              $table: $db.resourceImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverImage => $composableBuilder(
      column: $table.coverImage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => column);

  GeneratedColumn<String> get coverImage => $composableBuilder(
      column: $table.coverImage, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> resourceImagesRefs<T extends Object>(
      Expression<T> Function($$ResourceImagesTableAnnotationComposer a) f) {
    final $$ResourceImagesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.resourceImages,
        getReferencedColumn: (t) => t.resourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ResourceImagesTableAnnotationComposer(
              $db: $db,
              $table: $db.resourceImages,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ResourcesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ResourcesTable,
    Resource,
    $$ResourcesTableFilterComposer,
    $$ResourcesTableOrderingComposer,
    $$ResourcesTableAnnotationComposer,
    $$ResourcesTableCreateCompanionBuilder,
    $$ResourcesTableUpdateCompanionBuilder,
    (Resource, $$ResourcesTableReferences),
    Resource,
    PrefetchHooks Function({bool resourceImagesRefs})> {
  $$ResourcesTableTableManager(_$AppDatabase db, $ResourcesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> fieldsJson = const Value.absent(),
            Value<String?> coverImage = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ResourcesCompanion(
            id: id,
            type: type,
            name: name,
            fieldsJson: fieldsJson,
            coverImage: coverImage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required String name,
            Value<String> fieldsJson = const Value.absent(),
            Value<String?> coverImage = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ResourcesCompanion.insert(
            id: id,
            type: type,
            name: name,
            fieldsJson: fieldsJson,
            coverImage: coverImage,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ResourcesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({resourceImagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (resourceImagesRefs) db.resourceImages
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (resourceImagesRefs)
                    await $_getPrefetchedData<Resource, $ResourcesTable,
                            ResourceImage>(
                        currentTable: table,
                        referencedTable: $$ResourcesTableReferences
                            ._resourceImagesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ResourcesTableReferences(db, table, p0)
                                .resourceImagesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.resourceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ResourcesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ResourcesTable,
    Resource,
    $$ResourcesTableFilterComposer,
    $$ResourcesTableOrderingComposer,
    $$ResourcesTableAnnotationComposer,
    $$ResourcesTableCreateCompanionBuilder,
    $$ResourcesTableUpdateCompanionBuilder,
    (Resource, $$ResourcesTableReferences),
    Resource,
    PrefetchHooks Function({bool resourceImagesRefs})>;
typedef $$ResourceImagesTableCreateCompanionBuilder = ResourceImagesCompanion
    Function({
  required String id,
  required String resourceId,
  required String filePath,
  Value<String> note,
  Value<int> sort,
  Value<int> rowid,
});
typedef $$ResourceImagesTableUpdateCompanionBuilder = ResourceImagesCompanion
    Function({
  Value<String> id,
  Value<String> resourceId,
  Value<String> filePath,
  Value<String> note,
  Value<int> sort,
  Value<int> rowid,
});

final class $$ResourceImagesTableReferences
    extends BaseReferences<_$AppDatabase, $ResourceImagesTable, ResourceImage> {
  $$ResourceImagesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ResourcesTable _resourceIdTable(_$AppDatabase db) =>
      db.resources.createAlias(
          $_aliasNameGenerator(db.resourceImages.resourceId, db.resources.id));

  $$ResourcesTableProcessedTableManager get resourceId {
    final $_column = $_itemColumn<String>('resource_id')!;

    final manager = $$ResourcesTableTableManager($_db, $_db.resources)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_resourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ResourceImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourceImagesTable> {
  $$ResourceImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnFilters(column));

  $$ResourcesTableFilterComposer get resourceId {
    final $$ResourcesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.resourceId,
        referencedTable: $db.resources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ResourcesTableFilterComposer(
              $db: $db,
              $table: $db.resources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ResourceImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourceImagesTable> {
  $$ResourceImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sort => $composableBuilder(
      column: $table.sort, builder: (column) => ColumnOrderings(column));

  $$ResourcesTableOrderingComposer get resourceId {
    final $$ResourcesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.resourceId,
        referencedTable: $db.resources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ResourcesTableOrderingComposer(
              $db: $db,
              $table: $db.resources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ResourceImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourceImagesTable> {
  $$ResourceImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  $$ResourcesTableAnnotationComposer get resourceId {
    final $$ResourcesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.resourceId,
        referencedTable: $db.resources,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ResourcesTableAnnotationComposer(
              $db: $db,
              $table: $db.resources,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ResourceImagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ResourceImagesTable,
    ResourceImage,
    $$ResourceImagesTableFilterComposer,
    $$ResourceImagesTableOrderingComposer,
    $$ResourceImagesTableAnnotationComposer,
    $$ResourceImagesTableCreateCompanionBuilder,
    $$ResourceImagesTableUpdateCompanionBuilder,
    (ResourceImage, $$ResourceImagesTableReferences),
    ResourceImage,
    PrefetchHooks Function({bool resourceId})> {
  $$ResourceImagesTableTableManager(
      _$AppDatabase db, $ResourceImagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourceImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourceImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourceImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> resourceId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ResourceImagesCompanion(
            id: id,
            resourceId: resourceId,
            filePath: filePath,
            note: note,
            sort: sort,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String resourceId,
            required String filePath,
            Value<String> note = const Value.absent(),
            Value<int> sort = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ResourceImagesCompanion.insert(
            id: id,
            resourceId: resourceId,
            filePath: filePath,
            note: note,
            sort: sort,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ResourceImagesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({resourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (resourceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.resourceId,
                    referencedTable:
                        $$ResourceImagesTableReferences._resourceIdTable(db),
                    referencedColumn:
                        $$ResourceImagesTableReferences._resourceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ResourceImagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ResourceImagesTable,
    ResourceImage,
    $$ResourceImagesTableFilterComposer,
    $$ResourceImagesTableOrderingComposer,
    $$ResourceImagesTableAnnotationComposer,
    $$ResourceImagesTableCreateCompanionBuilder,
    $$ResourceImagesTableUpdateCompanionBuilder,
    (ResourceImage, $$ResourceImagesTableReferences),
    ResourceImage,
    PrefetchHooks Function({bool resourceId})>;
typedef $$FilmsTableCreateCompanionBuilder = FilmsCompanion Function({
  required String id,
  required String title,
  Value<String> director,
  Value<int?> year,
  Value<String> coverGradient,
  Value<String> sourceUrl,
  Value<int> rowid,
});
typedef $$FilmsTableUpdateCompanionBuilder = FilmsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> director,
  Value<int?> year,
  Value<String> coverGradient,
  Value<String> sourceUrl,
  Value<int> rowid,
});

final class $$FilmsTableReferences
    extends BaseReferences<_$AppDatabase, $FilmsTable, Film> {
  $$FilmsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FilmFramesTable, List<FilmFrame>>
      _filmFramesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.filmFrames,
          aliasName: $_aliasNameGenerator(db.films.id, db.filmFrames.filmId));

  $$FilmFramesTableProcessedTableManager get filmFramesRefs {
    final manager = $$FilmFramesTableTableManager($_db, $_db.filmFrames)
        .filter((f) => f.filmId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_filmFramesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FilmsTableFilterComposer extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get director => $composableBuilder(
      column: $table.director, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverGradient => $composableBuilder(
      column: $table.coverGradient, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  Expression<bool> filmFramesRefs(
      Expression<bool> Function($$FilmFramesTableFilterComposer f) f) {
    final $$FilmFramesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filmFrames,
        getReferencedColumn: (t) => t.filmId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilmFramesTableFilterComposer(
              $db: $db,
              $table: $db.filmFrames,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FilmsTableOrderingComposer
    extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get director => $composableBuilder(
      column: $table.director, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverGradient => $composableBuilder(
      column: $table.coverGradient,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));
}

class $$FilmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilmsTable> {
  $$FilmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get coverGradient => $composableBuilder(
      column: $table.coverGradient, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  Expression<T> filmFramesRefs<T extends Object>(
      Expression<T> Function($$FilmFramesTableAnnotationComposer a) f) {
    final $$FilmFramesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.filmFrames,
        getReferencedColumn: (t) => t.filmId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilmFramesTableAnnotationComposer(
              $db: $db,
              $table: $db.filmFrames,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$FilmsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FilmsTable,
    Film,
    $$FilmsTableFilterComposer,
    $$FilmsTableOrderingComposer,
    $$FilmsTableAnnotationComposer,
    $$FilmsTableCreateCompanionBuilder,
    $$FilmsTableUpdateCompanionBuilder,
    (Film, $$FilmsTableReferences),
    Film,
    PrefetchHooks Function({bool filmFramesRefs})> {
  $$FilmsTableTableManager(_$AppDatabase db, $FilmsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> director = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String> coverGradient = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FilmsCompanion(
            id: id,
            title: title,
            director: director,
            year: year,
            coverGradient: coverGradient,
            sourceUrl: sourceUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String> director = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<String> coverGradient = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FilmsCompanion.insert(
            id: id,
            title: title,
            director: director,
            year: year,
            coverGradient: coverGradient,
            sourceUrl: sourceUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$FilmsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({filmFramesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (filmFramesRefs) db.filmFrames],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (filmFramesRefs)
                    await $_getPrefetchedData<Film, $FilmsTable, FilmFrame>(
                        currentTable: table,
                        referencedTable:
                            $$FilmsTableReferences._filmFramesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$FilmsTableReferences(db, table, p0)
                                .filmFramesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.filmId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$FilmsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FilmsTable,
    Film,
    $$FilmsTableFilterComposer,
    $$FilmsTableOrderingComposer,
    $$FilmsTableAnnotationComposer,
    $$FilmsTableCreateCompanionBuilder,
    $$FilmsTableUpdateCompanionBuilder,
    (Film, $$FilmsTableReferences),
    Film,
    PrefetchHooks Function({bool filmFramesRefs})>;
typedef $$FilmFramesTableCreateCompanionBuilder = FilmFramesCompanion Function({
  required String id,
  required String filmId,
  required String name,
  required String imageRef,
  Value<String> paletteJson,
  Value<String> sourceUrl,
  Value<bool> inBoard,
  Value<int> rowid,
});
typedef $$FilmFramesTableUpdateCompanionBuilder = FilmFramesCompanion Function({
  Value<String> id,
  Value<String> filmId,
  Value<String> name,
  Value<String> imageRef,
  Value<String> paletteJson,
  Value<String> sourceUrl,
  Value<bool> inBoard,
  Value<int> rowid,
});

final class $$FilmFramesTableReferences
    extends BaseReferences<_$AppDatabase, $FilmFramesTable, FilmFrame> {
  $$FilmFramesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FilmsTable _filmIdTable(_$AppDatabase db) => db.films
      .createAlias($_aliasNameGenerator(db.filmFrames.filmId, db.films.id));

  $$FilmsTableProcessedTableManager get filmId {
    final $_column = $_itemColumn<String>('film_id')!;

    final manager = $$FilmsTableTableManager($_db, $_db.films)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_filmIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FilmFramesTableFilterComposer
    extends Composer<_$AppDatabase, $FilmFramesTable> {
  $$FilmFramesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageRef => $composableBuilder(
      column: $table.imageRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paletteJson => $composableBuilder(
      column: $table.paletteJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inBoard => $composableBuilder(
      column: $table.inBoard, builder: (column) => ColumnFilters(column));

  $$FilmsTableFilterComposer get filmId {
    final $$FilmsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filmId,
        referencedTable: $db.films,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilmsTableFilterComposer(
              $db: $db,
              $table: $db.films,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FilmFramesTableOrderingComposer
    extends Composer<_$AppDatabase, $FilmFramesTable> {
  $$FilmFramesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageRef => $composableBuilder(
      column: $table.imageRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paletteJson => $composableBuilder(
      column: $table.paletteJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inBoard => $composableBuilder(
      column: $table.inBoard, builder: (column) => ColumnOrderings(column));

  $$FilmsTableOrderingComposer get filmId {
    final $$FilmsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filmId,
        referencedTable: $db.films,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilmsTableOrderingComposer(
              $db: $db,
              $table: $db.films,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FilmFramesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilmFramesTable> {
  $$FilmFramesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imageRef =>
      $composableBuilder(column: $table.imageRef, builder: (column) => column);

  GeneratedColumn<String> get paletteJson => $composableBuilder(
      column: $table.paletteJson, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<bool> get inBoard =>
      $composableBuilder(column: $table.inBoard, builder: (column) => column);

  $$FilmsTableAnnotationComposer get filmId {
    final $$FilmsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.filmId,
        referencedTable: $db.films,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FilmsTableAnnotationComposer(
              $db: $db,
              $table: $db.films,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FilmFramesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FilmFramesTable,
    FilmFrame,
    $$FilmFramesTableFilterComposer,
    $$FilmFramesTableOrderingComposer,
    $$FilmFramesTableAnnotationComposer,
    $$FilmFramesTableCreateCompanionBuilder,
    $$FilmFramesTableUpdateCompanionBuilder,
    (FilmFrame, $$FilmFramesTableReferences),
    FilmFrame,
    PrefetchHooks Function({bool filmId})> {
  $$FilmFramesTableTableManager(_$AppDatabase db, $FilmFramesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilmFramesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilmFramesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilmFramesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> filmId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> imageRef = const Value.absent(),
            Value<String> paletteJson = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<bool> inBoard = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FilmFramesCompanion(
            id: id,
            filmId: filmId,
            name: name,
            imageRef: imageRef,
            paletteJson: paletteJson,
            sourceUrl: sourceUrl,
            inBoard: inBoard,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String filmId,
            required String name,
            required String imageRef,
            Value<String> paletteJson = const Value.absent(),
            Value<String> sourceUrl = const Value.absent(),
            Value<bool> inBoard = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FilmFramesCompanion.insert(
            id: id,
            filmId: filmId,
            name: name,
            imageRef: imageRef,
            paletteJson: paletteJson,
            sourceUrl: sourceUrl,
            inBoard: inBoard,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$FilmFramesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({filmId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (filmId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.filmId,
                    referencedTable:
                        $$FilmFramesTableReferences._filmIdTable(db),
                    referencedColumn:
                        $$FilmFramesTableReferences._filmIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FilmFramesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FilmFramesTable,
    FilmFrame,
    $$FilmFramesTableFilterComposer,
    $$FilmFramesTableOrderingComposer,
    $$FilmFramesTableAnnotationComposer,
    $$FilmFramesTableCreateCompanionBuilder,
    $$FilmFramesTableUpdateCompanionBuilder,
    (FilmFrame, $$FilmFramesTableReferences),
    FilmFrame,
    PrefetchHooks Function({bool filmId})>;
typedef $$PosesTableCreateCompanionBuilder = PosesCompanion Function({
  required String id,
  required String name,
  required String category,
  Value<String> difficulty,
  required String jointsJson,
  Value<String> tip,
  Value<String> lensAdvice,
  Value<bool> builtin,
  Value<bool> favorite,
  Value<int> rowid,
});
typedef $$PosesTableUpdateCompanionBuilder = PosesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> category,
  Value<String> difficulty,
  Value<String> jointsJson,
  Value<String> tip,
  Value<String> lensAdvice,
  Value<bool> builtin,
  Value<bool> favorite,
  Value<int> rowid,
});

final class $$PosesTableReferences
    extends BaseReferences<_$AppDatabase, $PosesTable, Pose> {
  $$PosesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LightingScenesTable, List<LightingScene>>
      _lightingScenesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.lightingScenes,
              aliasName: $_aliasNameGenerator(
                  db.poses.id, db.lightingScenes.linkedPoseId));

  $$LightingScenesTableProcessedTableManager get lightingScenesRefs {
    final manager = $$LightingScenesTableTableManager($_db, $_db.lightingScenes)
        .filter(
            (f) => f.linkedPoseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_lightingScenesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PosesTableFilterComposer extends Composer<_$AppDatabase, $PosesTable> {
  $$PosesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jointsJson => $composableBuilder(
      column: $table.jointsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tip => $composableBuilder(
      column: $table.tip, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lensAdvice => $composableBuilder(
      column: $table.lensAdvice, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get builtin => $composableBuilder(
      column: $table.builtin, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnFilters(column));

  Expression<bool> lightingScenesRefs(
      Expression<bool> Function($$LightingScenesTableFilterComposer f) f) {
    final $$LightingScenesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lightingScenes,
        getReferencedColumn: (t) => t.linkedPoseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LightingScenesTableFilterComposer(
              $db: $db,
              $table: $db.lightingScenes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PosesTableOrderingComposer
    extends Composer<_$AppDatabase, $PosesTable> {
  $$PosesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jointsJson => $composableBuilder(
      column: $table.jointsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tip => $composableBuilder(
      column: $table.tip, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lensAdvice => $composableBuilder(
      column: $table.lensAdvice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get builtin => $composableBuilder(
      column: $table.builtin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnOrderings(column));
}

class $$PosesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PosesTable> {
  $$PosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<String> get jointsJson => $composableBuilder(
      column: $table.jointsJson, builder: (column) => column);

  GeneratedColumn<String> get tip =>
      $composableBuilder(column: $table.tip, builder: (column) => column);

  GeneratedColumn<String> get lensAdvice => $composableBuilder(
      column: $table.lensAdvice, builder: (column) => column);

  GeneratedColumn<bool> get builtin =>
      $composableBuilder(column: $table.builtin, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  Expression<T> lightingScenesRefs<T extends Object>(
      Expression<T> Function($$LightingScenesTableAnnotationComposer a) f) {
    final $$LightingScenesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.lightingScenes,
        getReferencedColumn: (t) => t.linkedPoseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LightingScenesTableAnnotationComposer(
              $db: $db,
              $table: $db.lightingScenes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PosesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PosesTable,
    Pose,
    $$PosesTableFilterComposer,
    $$PosesTableOrderingComposer,
    $$PosesTableAnnotationComposer,
    $$PosesTableCreateCompanionBuilder,
    $$PosesTableUpdateCompanionBuilder,
    (Pose, $$PosesTableReferences),
    Pose,
    PrefetchHooks Function({bool lightingScenesRefs})> {
  $$PosesTableTableManager(_$AppDatabase db, $PosesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> difficulty = const Value.absent(),
            Value<String> jointsJson = const Value.absent(),
            Value<String> tip = const Value.absent(),
            Value<String> lensAdvice = const Value.absent(),
            Value<bool> builtin = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PosesCompanion(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty,
            jointsJson: jointsJson,
            tip: tip,
            lensAdvice: lensAdvice,
            builtin: builtin,
            favorite: favorite,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String category,
            Value<String> difficulty = const Value.absent(),
            required String jointsJson,
            Value<String> tip = const Value.absent(),
            Value<String> lensAdvice = const Value.absent(),
            Value<bool> builtin = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PosesCompanion.insert(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty,
            jointsJson: jointsJson,
            tip: tip,
            lensAdvice: lensAdvice,
            builtin: builtin,
            favorite: favorite,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PosesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({lightingScenesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lightingScenesRefs) db.lightingScenes
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lightingScenesRefs)
                    await $_getPrefetchedData<Pose, $PosesTable, LightingScene>(
                        currentTable: table,
                        referencedTable:
                            $$PosesTableReferences._lightingScenesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PosesTableReferences(db, table, p0)
                                .lightingScenesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.linkedPoseId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PosesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PosesTable,
    Pose,
    $$PosesTableFilterComposer,
    $$PosesTableOrderingComposer,
    $$PosesTableAnnotationComposer,
    $$PosesTableCreateCompanionBuilder,
    $$PosesTableUpdateCompanionBuilder,
    (Pose, $$PosesTableReferences),
    Pose,
    PrefetchHooks Function({bool lightingScenesRefs})>;
typedef $$LightingScenesTableCreateCompanionBuilder = LightingScenesCompanion
    Function({
  required String id,
  required String name,
  required String sceneJson,
  Value<String?> linkedPoseId,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$LightingScenesTableUpdateCompanionBuilder = LightingScenesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> sceneJson,
  Value<String?> linkedPoseId,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$LightingScenesTableReferences
    extends BaseReferences<_$AppDatabase, $LightingScenesTable, LightingScene> {
  $$LightingScenesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PosesTable _linkedPoseIdTable(_$AppDatabase db) =>
      db.poses.createAlias(
          $_aliasNameGenerator(db.lightingScenes.linkedPoseId, db.poses.id));

  $$PosesTableProcessedTableManager? get linkedPoseId {
    final $_column = $_itemColumn<String>('linked_pose_id');
    if ($_column == null) return null;
    final manager = $$PosesTableTableManager($_db, $_db.poses)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedPoseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LightingScenesTableFilterComposer
    extends Composer<_$AppDatabase, $LightingScenesTable> {
  $$LightingScenesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sceneJson => $composableBuilder(
      column: $table.sceneJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$PosesTableFilterComposer get linkedPoseId {
    final $$PosesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.linkedPoseId,
        referencedTable: $db.poses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PosesTableFilterComposer(
              $db: $db,
              $table: $db.poses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LightingScenesTableOrderingComposer
    extends Composer<_$AppDatabase, $LightingScenesTable> {
  $$LightingScenesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sceneJson => $composableBuilder(
      column: $table.sceneJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$PosesTableOrderingComposer get linkedPoseId {
    final $$PosesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.linkedPoseId,
        referencedTable: $db.poses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PosesTableOrderingComposer(
              $db: $db,
              $table: $db.poses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LightingScenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LightingScenesTable> {
  $$LightingScenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sceneJson =>
      $composableBuilder(column: $table.sceneJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PosesTableAnnotationComposer get linkedPoseId {
    final $$PosesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.linkedPoseId,
        referencedTable: $db.poses,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PosesTableAnnotationComposer(
              $db: $db,
              $table: $db.poses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LightingScenesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LightingScenesTable,
    LightingScene,
    $$LightingScenesTableFilterComposer,
    $$LightingScenesTableOrderingComposer,
    $$LightingScenesTableAnnotationComposer,
    $$LightingScenesTableCreateCompanionBuilder,
    $$LightingScenesTableUpdateCompanionBuilder,
    (LightingScene, $$LightingScenesTableReferences),
    LightingScene,
    PrefetchHooks Function({bool linkedPoseId})> {
  $$LightingScenesTableTableManager(
      _$AppDatabase db, $LightingScenesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LightingScenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LightingScenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LightingScenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> sceneJson = const Value.absent(),
            Value<String?> linkedPoseId = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LightingScenesCompanion(
            id: id,
            name: name,
            sceneJson: sceneJson,
            linkedPoseId: linkedPoseId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String sceneJson,
            Value<String?> linkedPoseId = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LightingScenesCompanion.insert(
            id: id,
            name: name,
            sceneJson: sceneJson,
            linkedPoseId: linkedPoseId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LightingScenesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({linkedPoseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (linkedPoseId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.linkedPoseId,
                    referencedTable:
                        $$LightingScenesTableReferences._linkedPoseIdTable(db),
                    referencedColumn: $$LightingScenesTableReferences
                        ._linkedPoseIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LightingScenesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LightingScenesTable,
    LightingScene,
    $$LightingScenesTableFilterComposer,
    $$LightingScenesTableOrderingComposer,
    $$LightingScenesTableAnnotationComposer,
    $$LightingScenesTableCreateCompanionBuilder,
    $$LightingScenesTableUpdateCompanionBuilder,
    (LightingScene, $$LightingScenesTableReferences),
    LightingScene,
    PrefetchHooks Function({bool linkedPoseId})>;
typedef $$GearItemsTableCreateCompanionBuilder = GearItemsCompanion Function({
  required String id,
  required String kind,
  required String brand,
  required String model,
  Value<String> mount,
  Value<String> specsJson,
  Value<double?> priceRef,
  Value<bool> builtin,
  Value<int> rowid,
});
typedef $$GearItemsTableUpdateCompanionBuilder = GearItemsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> brand,
  Value<String> model,
  Value<String> mount,
  Value<String> specsJson,
  Value<double?> priceRef,
  Value<bool> builtin,
  Value<int> rowid,
});

class $$GearItemsTableFilterComposer
    extends Composer<_$AppDatabase, $GearItemsTable> {
  $$GearItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mount => $composableBuilder(
      column: $table.mount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get specsJson => $composableBuilder(
      column: $table.specsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceRef => $composableBuilder(
      column: $table.priceRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get builtin => $composableBuilder(
      column: $table.builtin, builder: (column) => ColumnFilters(column));
}

class $$GearItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $GearItemsTable> {
  $$GearItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mount => $composableBuilder(
      column: $table.mount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get specsJson => $composableBuilder(
      column: $table.specsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceRef => $composableBuilder(
      column: $table.priceRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get builtin => $composableBuilder(
      column: $table.builtin, builder: (column) => ColumnOrderings(column));
}

class $$GearItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GearItemsTable> {
  $$GearItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get mount =>
      $composableBuilder(column: $table.mount, builder: (column) => column);

  GeneratedColumn<String> get specsJson =>
      $composableBuilder(column: $table.specsJson, builder: (column) => column);

  GeneratedColumn<double> get priceRef =>
      $composableBuilder(column: $table.priceRef, builder: (column) => column);

  GeneratedColumn<bool> get builtin =>
      $composableBuilder(column: $table.builtin, builder: (column) => column);
}

class $$GearItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GearItemsTable,
    GearItem,
    $$GearItemsTableFilterComposer,
    $$GearItemsTableOrderingComposer,
    $$GearItemsTableAnnotationComposer,
    $$GearItemsTableCreateCompanionBuilder,
    $$GearItemsTableUpdateCompanionBuilder,
    (GearItem, BaseReferences<_$AppDatabase, $GearItemsTable, GearItem>),
    GearItem,
    PrefetchHooks Function()> {
  $$GearItemsTableTableManager(_$AppDatabase db, $GearItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GearItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GearItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GearItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> brand = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<String> mount = const Value.absent(),
            Value<String> specsJson = const Value.absent(),
            Value<double?> priceRef = const Value.absent(),
            Value<bool> builtin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GearItemsCompanion(
            id: id,
            kind: kind,
            brand: brand,
            model: model,
            mount: mount,
            specsJson: specsJson,
            priceRef: priceRef,
            builtin: builtin,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String kind,
            required String brand,
            required String model,
            Value<String> mount = const Value.absent(),
            Value<String> specsJson = const Value.absent(),
            Value<double?> priceRef = const Value.absent(),
            Value<bool> builtin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GearItemsCompanion.insert(
            id: id,
            kind: kind,
            brand: brand,
            model: model,
            mount: mount,
            specsJson: specsJson,
            priceRef: priceRef,
            builtin: builtin,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GearItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GearItemsTable,
    GearItem,
    $$GearItemsTableFilterComposer,
    $$GearItemsTableOrderingComposer,
    $$GearItemsTableAnnotationComposer,
    $$GearItemsTableCreateCompanionBuilder,
    $$GearItemsTableUpdateCompanionBuilder,
    (GearItem, BaseReferences<_$AppDatabase, $GearItemsTable, GearItem>),
    GearItem,
    PrefetchHooks Function()>;
typedef $$PlansTableCreateCompanionBuilder = PlansCompanion Function({
  required String id,
  required String title,
  Value<String> status,
  Value<String> modulesJson,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$PlansTableUpdateCompanionBuilder = PlansCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> status,
  Value<String> modulesJson,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $$PlansTableReferences
    extends BaseReferences<_$AppDatabase, $PlansTable, Plan> {
  $$PlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlanSnapshotsTable, List<PlanSnapshot>>
      _planSnapshotsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.planSnapshots,
              aliasName:
                  $_aliasNameGenerator(db.plans.id, db.planSnapshots.planId));

  $$PlanSnapshotsTableProcessedTableManager get planSnapshotsRefs {
    final manager = $$PlanSnapshotsTableTableManager($_db, $_db.planSnapshots)
        .filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planSnapshotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PlansTableFilterComposer extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> planSnapshotsRefs(
      Expression<bool> Function($$PlanSnapshotsTableFilterComposer f) f) {
    final $$PlanSnapshotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.planSnapshots,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlanSnapshotsTableFilterComposer(
              $db: $db,
              $table: $db.planSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlansTableOrderingComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlansTable> {
  $$PlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> planSnapshotsRefs<T extends Object>(
      Expression<T> Function($$PlanSnapshotsTableAnnotationComposer a) f) {
    final $$PlanSnapshotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.planSnapshots,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlanSnapshotsTableAnnotationComposer(
              $db: $db,
              $table: $db.planSnapshots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$PlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlansTable,
    Plan,
    $$PlansTableFilterComposer,
    $$PlansTableOrderingComposer,
    $$PlansTableAnnotationComposer,
    $$PlansTableCreateCompanionBuilder,
    $$PlansTableUpdateCompanionBuilder,
    (Plan, $$PlansTableReferences),
    Plan,
    PrefetchHooks Function({bool planSnapshotsRefs})> {
  $$PlansTableTableManager(_$AppDatabase db, $PlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> modulesJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlansCompanion(
            id: id,
            title: title,
            status: status,
            modulesJson: modulesJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String> status = const Value.absent(),
            Value<String> modulesJson = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlansCompanion.insert(
            id: id,
            title: title,
            status: status,
            modulesJson: modulesJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$PlansTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({planSnapshotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (planSnapshotsRefs) db.planSnapshots
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (planSnapshotsRefs)
                    await $_getPrefetchedData<Plan, $PlansTable, PlanSnapshot>(
                        currentTable: table,
                        referencedTable:
                            $$PlansTableReferences._planSnapshotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$PlansTableReferences(db, table, p0)
                                .planSnapshotsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.planId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$PlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlansTable,
    Plan,
    $$PlansTableFilterComposer,
    $$PlansTableOrderingComposer,
    $$PlansTableAnnotationComposer,
    $$PlansTableCreateCompanionBuilder,
    $$PlansTableUpdateCompanionBuilder,
    (Plan, $$PlansTableReferences),
    Plan,
    PrefetchHooks Function({bool planSnapshotsRefs})>;
typedef $$PlanSnapshotsTableCreateCompanionBuilder = PlanSnapshotsCompanion
    Function({
  required String id,
  required String planId,
  required String modulesJson,
  Value<String?> label,
  required int createdAt,
  Value<int> rowid,
});
typedef $$PlanSnapshotsTableUpdateCompanionBuilder = PlanSnapshotsCompanion
    Function({
  Value<String> id,
  Value<String> planId,
  Value<String> modulesJson,
  Value<String?> label,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $$PlanSnapshotsTableReferences
    extends BaseReferences<_$AppDatabase, $PlanSnapshotsTable, PlanSnapshot> {
  $$PlanSnapshotsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $PlansTable _planIdTable(_$AppDatabase db) => db.plans
      .createAlias($_aliasNameGenerator(db.planSnapshots.planId, db.plans.id));

  $$PlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $$PlansTableTableManager($_db, $_db.plans)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PlanSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$PlansTableFilterComposer get planId {
    final $$PlansTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableFilterComposer(
              $db: $db,
              $table: $db.plans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlanSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$PlansTableOrderingComposer get planId {
    final $$PlansTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableOrderingComposer(
              $db: $db,
              $table: $db.plans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlanSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanSnapshotsTable> {
  $$PlanSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modulesJson => $composableBuilder(
      column: $table.modulesJson, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlansTableAnnotationComposer get planId {
    final $$PlansTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.plans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PlansTableAnnotationComposer(
              $db: $db,
              $table: $db.plans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PlanSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlanSnapshotsTable,
    PlanSnapshot,
    $$PlanSnapshotsTableFilterComposer,
    $$PlanSnapshotsTableOrderingComposer,
    $$PlanSnapshotsTableAnnotationComposer,
    $$PlanSnapshotsTableCreateCompanionBuilder,
    $$PlanSnapshotsTableUpdateCompanionBuilder,
    (PlanSnapshot, $$PlanSnapshotsTableReferences),
    PlanSnapshot,
    PrefetchHooks Function({bool planId})> {
  $$PlanSnapshotsTableTableManager(_$AppDatabase db, $PlanSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> modulesJson = const Value.absent(),
            Value<String?> label = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanSnapshotsCompanion(
            id: id,
            planId: planId,
            modulesJson: modulesJson,
            label: label,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String planId,
            required String modulesJson,
            Value<String?> label = const Value.absent(),
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanSnapshotsCompanion.insert(
            id: id,
            planId: planId,
            modulesJson: modulesJson,
            label: label,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PlanSnapshotsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (planId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.planId,
                    referencedTable:
                        $$PlanSnapshotsTableReferences._planIdTable(db),
                    referencedColumn:
                        $$PlanSnapshotsTableReferences._planIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PlanSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlanSnapshotsTable,
    PlanSnapshot,
    $$PlanSnapshotsTableFilterComposer,
    $$PlanSnapshotsTableOrderingComposer,
    $$PlanSnapshotsTableAnnotationComposer,
    $$PlanSnapshotsTableCreateCompanionBuilder,
    $$PlanSnapshotsTableUpdateCompanionBuilder,
    (PlanSnapshot, $$PlanSnapshotsTableReferences),
    PlanSnapshot,
    PrefetchHooks Function({bool planId})>;
typedef $$ProviderConfigsTableCreateCompanionBuilder = ProviderConfigsCompanion
    Function({
  required String id,
  required String name,
  required String baseUrl,
  Value<String> protocol,
  Value<String> encryptedKey,
  Value<String> defaultModel,
  Value<String> modelsJson,
  Value<bool> enabled,
  Value<int> priority,
  Value<int> rowid,
});
typedef $$ProviderConfigsTableUpdateCompanionBuilder = ProviderConfigsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> baseUrl,
  Value<String> protocol,
  Value<String> encryptedKey,
  Value<String> defaultModel,
  Value<String> modelsJson,
  Value<bool> enabled,
  Value<int> priority,
  Value<int> rowid,
});

class $$ProviderConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get protocol => $composableBuilder(
      column: $table.protocol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedKey => $composableBuilder(
      column: $table.encryptedKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultModel => $composableBuilder(
      column: $table.defaultModel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get modelsJson => $composableBuilder(
      column: $table.modelsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));
}

class $$ProviderConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseUrl => $composableBuilder(
      column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get protocol => $composableBuilder(
      column: $table.protocol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedKey => $composableBuilder(
      column: $table.encryptedKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultModel => $composableBuilder(
      column: $table.defaultModel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get modelsJson => $composableBuilder(
      column: $table.modelsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));
}

class $$ProviderConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumn<String> get encryptedKey => $composableBuilder(
      column: $table.encryptedKey, builder: (column) => column);

  GeneratedColumn<String> get defaultModel => $composableBuilder(
      column: $table.defaultModel, builder: (column) => column);

  GeneratedColumn<String> get modelsJson => $composableBuilder(
      column: $table.modelsJson, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);
}

class $$ProviderConfigsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProviderConfigsTable,
    ProviderConfig,
    $$ProviderConfigsTableFilterComposer,
    $$ProviderConfigsTableOrderingComposer,
    $$ProviderConfigsTableAnnotationComposer,
    $$ProviderConfigsTableCreateCompanionBuilder,
    $$ProviderConfigsTableUpdateCompanionBuilder,
    (
      ProviderConfig,
      BaseReferences<_$AppDatabase, $ProviderConfigsTable, ProviderConfig>
    ),
    ProviderConfig,
    PrefetchHooks Function()> {
  $$ProviderConfigsTableTableManager(
      _$AppDatabase db, $ProviderConfigsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> baseUrl = const Value.absent(),
            Value<String> protocol = const Value.absent(),
            Value<String> encryptedKey = const Value.absent(),
            Value<String> defaultModel = const Value.absent(),
            Value<String> modelsJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProviderConfigsCompanion(
            id: id,
            name: name,
            baseUrl: baseUrl,
            protocol: protocol,
            encryptedKey: encryptedKey,
            defaultModel: defaultModel,
            modelsJson: modelsJson,
            enabled: enabled,
            priority: priority,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String baseUrl,
            Value<String> protocol = const Value.absent(),
            Value<String> encryptedKey = const Value.absent(),
            Value<String> defaultModel = const Value.absent(),
            Value<String> modelsJson = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProviderConfigsCompanion.insert(
            id: id,
            name: name,
            baseUrl: baseUrl,
            protocol: protocol,
            encryptedKey: encryptedKey,
            defaultModel: defaultModel,
            modelsJson: modelsJson,
            enabled: enabled,
            priority: priority,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProviderConfigsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProviderConfigsTable,
    ProviderConfig,
    $$ProviderConfigsTableFilterComposer,
    $$ProviderConfigsTableOrderingComposer,
    $$ProviderConfigsTableAnnotationComposer,
    $$ProviderConfigsTableCreateCompanionBuilder,
    $$ProviderConfigsTableUpdateCompanionBuilder,
    (
      ProviderConfig,
      BaseReferences<_$AppDatabase, $ProviderConfigsTable, ProviderConfig>
    ),
    ProviderConfig,
    PrefetchHooks Function()>;
typedef $$CallLogsTableCreateCompanionBuilder = CallLogsCompanion Function({
  Value<int> id,
  required String providerId,
  required String model,
  required bool success,
  required int latencyMs,
  Value<int> promptTokens,
  Value<int> completionTokens,
  Value<String?> error,
  required int createdAt,
});
typedef $$CallLogsTableUpdateCompanionBuilder = CallLogsCompanion Function({
  Value<int> id,
  Value<String> providerId,
  Value<String> model,
  Value<bool> success,
  Value<int> latencyMs,
  Value<int> promptTokens,
  Value<int> completionTokens,
  Value<String?> error,
  Value<int> createdAt,
});

class $$CallLogsTableFilterComposer
    extends Composer<_$AppDatabase, $CallLogsTable> {
  $$CallLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get success => $composableBuilder(
      column: $table.success, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CallLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $CallLogsTable> {
  $$CallLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get success => $composableBuilder(
      column: $table.success, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get error => $composableBuilder(
      column: $table.error, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CallLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CallLogsTable> {
  $$CallLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<bool> get success =>
      $composableBuilder(column: $table.success, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<int> get promptTokens => $composableBuilder(
      column: $table.promptTokens, builder: (column) => column);

  GeneratedColumn<int> get completionTokens => $composableBuilder(
      column: $table.completionTokens, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CallLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CallLogsTable,
    CallLog,
    $$CallLogsTableFilterComposer,
    $$CallLogsTableOrderingComposer,
    $$CallLogsTableAnnotationComposer,
    $$CallLogsTableCreateCompanionBuilder,
    $$CallLogsTableUpdateCompanionBuilder,
    (CallLog, BaseReferences<_$AppDatabase, $CallLogsTable, CallLog>),
    CallLog,
    PrefetchHooks Function()> {
  $$CallLogsTableTableManager(_$AppDatabase db, $CallLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CallLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CallLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CallLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<bool> success = const Value.absent(),
            Value<int> latencyMs = const Value.absent(),
            Value<int> promptTokens = const Value.absent(),
            Value<int> completionTokens = const Value.absent(),
            Value<String?> error = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
          }) =>
              CallLogsCompanion(
            id: id,
            providerId: providerId,
            model: model,
            success: success,
            latencyMs: latencyMs,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            error: error,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String providerId,
            required String model,
            required bool success,
            required int latencyMs,
            Value<int> promptTokens = const Value.absent(),
            Value<int> completionTokens = const Value.absent(),
            Value<String?> error = const Value.absent(),
            required int createdAt,
          }) =>
              CallLogsCompanion.insert(
            id: id,
            providerId: providerId,
            model: model,
            success: success,
            latencyMs: latencyMs,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            error: error,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CallLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CallLogsTable,
    CallLog,
    $$CallLogsTableFilterComposer,
    $$CallLogsTableOrderingComposer,
    $$CallLogsTableAnnotationComposer,
    $$CallLogsTableCreateCompanionBuilder,
    $$CallLogsTableUpdateCompanionBuilder,
    (CallLog, BaseReferences<_$AppDatabase, $CallLogsTable, CallLog>),
    CallLog,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  Value<String> value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db, _db.resources);
  $$ResourceImagesTableTableManager get resourceImages =>
      $$ResourceImagesTableTableManager(_db, _db.resourceImages);
  $$FilmsTableTableManager get films =>
      $$FilmsTableTableManager(_db, _db.films);
  $$FilmFramesTableTableManager get filmFrames =>
      $$FilmFramesTableTableManager(_db, _db.filmFrames);
  $$PosesTableTableManager get poses =>
      $$PosesTableTableManager(_db, _db.poses);
  $$LightingScenesTableTableManager get lightingScenes =>
      $$LightingScenesTableTableManager(_db, _db.lightingScenes);
  $$GearItemsTableTableManager get gearItems =>
      $$GearItemsTableTableManager(_db, _db.gearItems);
  $$PlansTableTableManager get plans =>
      $$PlansTableTableManager(_db, _db.plans);
  $$PlanSnapshotsTableTableManager get planSnapshots =>
      $$PlanSnapshotsTableTableManager(_db, _db.planSnapshots);
  $$ProviderConfigsTableTableManager get providerConfigs =>
      $$ProviderConfigsTableTableManager(_db, _db.providerConfigs);
  $$CallLogsTableTableManager get callLogs =>
      $$CallLogsTableTableManager(_db, _db.callLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
