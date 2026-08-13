// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VariantSpec {

 String get apk; String get testApk;
/// Create a copy of VariantSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VariantSpecCopyWith<VariantSpec> get copyWith => _$VariantSpecCopyWithImpl<VariantSpec>(this as VariantSpec, _$identity);

  /// Serializes this VariantSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VariantSpec&&(identical(other.apk, apk) || other.apk == apk)&&(identical(other.testApk, testApk) || other.testApk == testApk));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apk,testApk);

@override
String toString() {
  return 'VariantSpec(apk: $apk, testApk: $testApk)';
}


}

/// @nodoc
abstract mixin class $VariantSpecCopyWith<$Res>  {
  factory $VariantSpecCopyWith(VariantSpec value, $Res Function(VariantSpec) _then) = _$VariantSpecCopyWithImpl;
@useResult
$Res call({
 String apk, String testApk
});




}
/// @nodoc
class _$VariantSpecCopyWithImpl<$Res>
    implements $VariantSpecCopyWith<$Res> {
  _$VariantSpecCopyWithImpl(this._self, this._then);

  final VariantSpec _self;
  final $Res Function(VariantSpec) _then;

/// Create a copy of VariantSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apk = null,Object? testApk = null,}) {
  return _then(_self.copyWith(
apk: null == apk ? _self.apk : apk // ignore: cast_nullable_to_non_nullable
as String,testApk: null == testApk ? _self.testApk : testApk // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VariantSpec].
extension VariantSpecPatterns on VariantSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VariantSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VariantSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VariantSpec value)  $default,){
final _that = this;
switch (_that) {
case _VariantSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VariantSpec value)?  $default,){
final _that = this;
switch (_that) {
case _VariantSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apk,  String testApk)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VariantSpec() when $default != null:
return $default(_that.apk,_that.testApk);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apk,  String testApk)  $default,) {final _that = this;
switch (_that) {
case _VariantSpec():
return $default(_that.apk,_that.testApk);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apk,  String testApk)?  $default,) {final _that = this;
switch (_that) {
case _VariantSpec() when $default != null:
return $default(_that.apk,_that.testApk);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VariantSpec extends VariantSpec {
  const _VariantSpec({this.apk = 'app.apk', this.testApk = 'app-test.apk'}): super._();
  factory _VariantSpec.fromJson(Map<String, dynamic> json) => _$VariantSpecFromJson(json);

@override@JsonKey() final  String apk;
@override@JsonKey() final  String testApk;

/// Create a copy of VariantSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariantSpecCopyWith<_VariantSpec> get copyWith => __$VariantSpecCopyWithImpl<_VariantSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VariantSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariantSpec&&(identical(other.apk, apk) || other.apk == apk)&&(identical(other.testApk, testApk) || other.testApk == testApk));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apk,testApk);

@override
String toString() {
  return 'VariantSpec(apk: $apk, testApk: $testApk)';
}


}

/// @nodoc
abstract mixin class _$VariantSpecCopyWith<$Res> implements $VariantSpecCopyWith<$Res> {
  factory _$VariantSpecCopyWith(_VariantSpec value, $Res Function(_VariantSpec) _then) = __$VariantSpecCopyWithImpl;
@override @useResult
$Res call({
 String apk, String testApk
});




}
/// @nodoc
class __$VariantSpecCopyWithImpl<$Res>
    implements _$VariantSpecCopyWith<$Res> {
  __$VariantSpecCopyWithImpl(this._self, this._then);

  final _VariantSpec _self;
  final $Res Function(_VariantSpec) _then;

/// Create a copy of VariantSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apk = null,Object? testApk = null,}) {
  return _then(_VariantSpec(
apk: null == apk ? _self.apk : apk // ignore: cast_nullable_to_non_nullable
as String,testApk: null == testApk ? _self.testApk : testApk // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SessionSpec {

 int get schemaVersion; String get name; String get description; Map<String, VariantSpec> get variants; String get package; String get testPackage; String get instrumentationRunner; int get rounds; int? get trialTimeoutSeconds; List<String> get expectedResultFiles; String get deviceResultDir; Map<String, dynamic> get tags;
/// Create a copy of SessionSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSpecCopyWith<SessionSpec> get copyWith => _$SessionSpecCopyWithImpl<SessionSpec>(this as SessionSpec, _$identity);

  /// Serializes this SessionSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSpec&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.variants, variants)&&(identical(other.package, package) || other.package == package)&&(identical(other.testPackage, testPackage) || other.testPackage == testPackage)&&(identical(other.instrumentationRunner, instrumentationRunner) || other.instrumentationRunner == instrumentationRunner)&&(identical(other.rounds, rounds) || other.rounds == rounds)&&(identical(other.trialTimeoutSeconds, trialTimeoutSeconds) || other.trialTimeoutSeconds == trialTimeoutSeconds)&&const DeepCollectionEquality().equals(other.expectedResultFiles, expectedResultFiles)&&(identical(other.deviceResultDir, deviceResultDir) || other.deviceResultDir == deviceResultDir)&&const DeepCollectionEquality().equals(other.tags, tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,name,description,const DeepCollectionEquality().hash(variants),package,testPackage,instrumentationRunner,rounds,trialTimeoutSeconds,const DeepCollectionEquality().hash(expectedResultFiles),deviceResultDir,const DeepCollectionEquality().hash(tags));

@override
String toString() {
  return 'SessionSpec(schemaVersion: $schemaVersion, name: $name, description: $description, variants: $variants, package: $package, testPackage: $testPackage, instrumentationRunner: $instrumentationRunner, rounds: $rounds, trialTimeoutSeconds: $trialTimeoutSeconds, expectedResultFiles: $expectedResultFiles, deviceResultDir: $deviceResultDir, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $SessionSpecCopyWith<$Res>  {
  factory $SessionSpecCopyWith(SessionSpec value, $Res Function(SessionSpec) _then) = _$SessionSpecCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String name, String description, Map<String, VariantSpec> variants, String package, String testPackage, String instrumentationRunner, int rounds, int? trialTimeoutSeconds, List<String> expectedResultFiles, String deviceResultDir, Map<String, dynamic> tags
});




}
/// @nodoc
class _$SessionSpecCopyWithImpl<$Res>
    implements $SessionSpecCopyWith<$Res> {
  _$SessionSpecCopyWithImpl(this._self, this._then);

  final SessionSpec _self;
  final $Res Function(SessionSpec) _then;

/// Create a copy of SessionSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? name = null,Object? description = null,Object? variants = null,Object? package = null,Object? testPackage = null,Object? instrumentationRunner = null,Object? rounds = null,Object? trialTimeoutSeconds = freezed,Object? expectedResultFiles = null,Object? deviceResultDir = null,Object? tags = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as Map<String, VariantSpec>,package: null == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String,testPackage: null == testPackage ? _self.testPackage : testPackage // ignore: cast_nullable_to_non_nullable
as String,instrumentationRunner: null == instrumentationRunner ? _self.instrumentationRunner : instrumentationRunner // ignore: cast_nullable_to_non_nullable
as String,rounds: null == rounds ? _self.rounds : rounds // ignore: cast_nullable_to_non_nullable
as int,trialTimeoutSeconds: freezed == trialTimeoutSeconds ? _self.trialTimeoutSeconds : trialTimeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,expectedResultFiles: null == expectedResultFiles ? _self.expectedResultFiles : expectedResultFiles // ignore: cast_nullable_to_non_nullable
as List<String>,deviceResultDir: null == deviceResultDir ? _self.deviceResultDir : deviceResultDir // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionSpec].
extension SessionSpecPatterns on SessionSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionSpec value)  $default,){
final _that = this;
switch (_that) {
case _SessionSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionSpec value)?  $default,){
final _that = this;
switch (_that) {
case _SessionSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String name,  String description,  Map<String, VariantSpec> variants,  String package,  String testPackage,  String instrumentationRunner,  int rounds,  int? trialTimeoutSeconds,  List<String> expectedResultFiles,  String deviceResultDir,  Map<String, dynamic> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionSpec() when $default != null:
return $default(_that.schemaVersion,_that.name,_that.description,_that.variants,_that.package,_that.testPackage,_that.instrumentationRunner,_that.rounds,_that.trialTimeoutSeconds,_that.expectedResultFiles,_that.deviceResultDir,_that.tags);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String name,  String description,  Map<String, VariantSpec> variants,  String package,  String testPackage,  String instrumentationRunner,  int rounds,  int? trialTimeoutSeconds,  List<String> expectedResultFiles,  String deviceResultDir,  Map<String, dynamic> tags)  $default,) {final _that = this;
switch (_that) {
case _SessionSpec():
return $default(_that.schemaVersion,_that.name,_that.description,_that.variants,_that.package,_that.testPackage,_that.instrumentationRunner,_that.rounds,_that.trialTimeoutSeconds,_that.expectedResultFiles,_that.deviceResultDir,_that.tags);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String name,  String description,  Map<String, VariantSpec> variants,  String package,  String testPackage,  String instrumentationRunner,  int rounds,  int? trialTimeoutSeconds,  List<String> expectedResultFiles,  String deviceResultDir,  Map<String, dynamic> tags)?  $default,) {final _that = this;
switch (_that) {
case _SessionSpec() when $default != null:
return $default(_that.schemaVersion,_that.name,_that.description,_that.variants,_that.package,_that.testPackage,_that.instrumentationRunner,_that.rounds,_that.trialTimeoutSeconds,_that.expectedResultFiles,_that.deviceResultDir,_that.tags);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class _SessionSpec extends SessionSpec {
  const _SessionSpec({this.schemaVersion = SessionSpec.currentSchemaVersion, required this.name, this.description = '', required final  Map<String, VariantSpec> variants, required this.package, required this.testPackage, this.instrumentationRunner = 'dev.flutter.plugins.integration_test.FlutterTestRunner', this.rounds = 1, this.trialTimeoutSeconds, final  List<String> expectedResultFiles = const [], required this.deviceResultDir, final  Map<String, dynamic> tags = const {}}): _variants = variants,_expectedResultFiles = expectedResultFiles,_tags = tags,super._();
  factory _SessionSpec.fromJson(Map<String, dynamic> json) => _$SessionSpecFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  String name;
@override@JsonKey() final  String description;
 final  Map<String, VariantSpec> _variants;
@override Map<String, VariantSpec> get variants {
  if (_variants is EqualUnmodifiableMapView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_variants);
}

@override final  String package;
@override final  String testPackage;
@override@JsonKey() final  String instrumentationRunner;
@override@JsonKey() final  int rounds;
@override final  int? trialTimeoutSeconds;
 final  List<String> _expectedResultFiles;
@override@JsonKey() List<String> get expectedResultFiles {
  if (_expectedResultFiles is EqualUnmodifiableListView) return _expectedResultFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_expectedResultFiles);
}

@override final  String deviceResultDir;
 final  Map<String, dynamic> _tags;
@override@JsonKey() Map<String, dynamic> get tags {
  if (_tags is EqualUnmodifiableMapView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tags);
}


/// Create a copy of SessionSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSpecCopyWith<_SessionSpec> get copyWith => __$SessionSpecCopyWithImpl<_SessionSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSpec&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._variants, _variants)&&(identical(other.package, package) || other.package == package)&&(identical(other.testPackage, testPackage) || other.testPackage == testPackage)&&(identical(other.instrumentationRunner, instrumentationRunner) || other.instrumentationRunner == instrumentationRunner)&&(identical(other.rounds, rounds) || other.rounds == rounds)&&(identical(other.trialTimeoutSeconds, trialTimeoutSeconds) || other.trialTimeoutSeconds == trialTimeoutSeconds)&&const DeepCollectionEquality().equals(other._expectedResultFiles, _expectedResultFiles)&&(identical(other.deviceResultDir, deviceResultDir) || other.deviceResultDir == deviceResultDir)&&const DeepCollectionEquality().equals(other._tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,name,description,const DeepCollectionEquality().hash(_variants),package,testPackage,instrumentationRunner,rounds,trialTimeoutSeconds,const DeepCollectionEquality().hash(_expectedResultFiles),deviceResultDir,const DeepCollectionEquality().hash(_tags));

@override
String toString() {
  return 'SessionSpec(schemaVersion: $schemaVersion, name: $name, description: $description, variants: $variants, package: $package, testPackage: $testPackage, instrumentationRunner: $instrumentationRunner, rounds: $rounds, trialTimeoutSeconds: $trialTimeoutSeconds, expectedResultFiles: $expectedResultFiles, deviceResultDir: $deviceResultDir, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$SessionSpecCopyWith<$Res> implements $SessionSpecCopyWith<$Res> {
  factory _$SessionSpecCopyWith(_SessionSpec value, $Res Function(_SessionSpec) _then) = __$SessionSpecCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String name, String description, Map<String, VariantSpec> variants, String package, String testPackage, String instrumentationRunner, int rounds, int? trialTimeoutSeconds, List<String> expectedResultFiles, String deviceResultDir, Map<String, dynamic> tags
});




}
/// @nodoc
class __$SessionSpecCopyWithImpl<$Res>
    implements _$SessionSpecCopyWith<$Res> {
  __$SessionSpecCopyWithImpl(this._self, this._then);

  final _SessionSpec _self;
  final $Res Function(_SessionSpec) _then;

/// Create a copy of SessionSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? name = null,Object? description = null,Object? variants = null,Object? package = null,Object? testPackage = null,Object? instrumentationRunner = null,Object? rounds = null,Object? trialTimeoutSeconds = freezed,Object? expectedResultFiles = null,Object? deviceResultDir = null,Object? tags = null,}) {
  return _then(_SessionSpec(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,variants: null == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as Map<String, VariantSpec>,package: null == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as String,testPackage: null == testPackage ? _self.testPackage : testPackage // ignore: cast_nullable_to_non_nullable
as String,instrumentationRunner: null == instrumentationRunner ? _self.instrumentationRunner : instrumentationRunner // ignore: cast_nullable_to_non_nullable
as String,rounds: null == rounds ? _self.rounds : rounds // ignore: cast_nullable_to_non_nullable
as int,trialTimeoutSeconds: freezed == trialTimeoutSeconds ? _self.trialTimeoutSeconds : trialTimeoutSeconds // ignore: cast_nullable_to_non_nullable
as int?,expectedResultFiles: null == expectedResultFiles ? _self._expectedResultFiles : expectedResultFiles // ignore: cast_nullable_to_non_nullable
as List<String>,deviceResultDir: null == deviceResultDir ? _self.deviceResultDir : deviceResultDir // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$SessionHistoryEntry {

 DateTime get at; String get from; String get to; String? get reason;
/// Create a copy of SessionHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionHistoryEntryCopyWith<SessionHistoryEntry> get copyWith => _$SessionHistoryEntryCopyWithImpl<SessionHistoryEntry>(this as SessionHistoryEntry, _$identity);

  /// Serializes this SessionHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionHistoryEntry&&(identical(other.at, at) || other.at == at)&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,from,to,reason);

@override
String toString() {
  return 'SessionHistoryEntry(at: $at, from: $from, to: $to, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionHistoryEntryCopyWith<$Res>  {
  factory $SessionHistoryEntryCopyWith(SessionHistoryEntry value, $Res Function(SessionHistoryEntry) _then) = _$SessionHistoryEntryCopyWithImpl;
@useResult
$Res call({
 DateTime at, String from, String to, String? reason
});




}
/// @nodoc
class _$SessionHistoryEntryCopyWithImpl<$Res>
    implements $SessionHistoryEntryCopyWith<$Res> {
  _$SessionHistoryEntryCopyWithImpl(this._self, this._then);

  final SessionHistoryEntry _self;
  final $Res Function(SessionHistoryEntry) _then;

/// Create a copy of SessionHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? from = null,Object? to = null,Object? reason = freezed,}) {
  return _then(_self.copyWith(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionHistoryEntry].
extension SessionHistoryEntryPatterns on SessionHistoryEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionHistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionHistoryEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionHistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _SessionHistoryEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionHistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _SessionHistoryEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  String from,  String to,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionHistoryEntry() when $default != null:
return $default(_that.at,_that.from,_that.to,_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  String from,  String to,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _SessionHistoryEntry():
return $default(_that.at,_that.from,_that.to,_that.reason);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  String from,  String to,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _SessionHistoryEntry() when $default != null:
return $default(_that.at,_that.from,_that.to,_that.reason);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class _SessionHistoryEntry extends SessionHistoryEntry {
  const _SessionHistoryEntry({required this.at, required this.from, required this.to, this.reason}): super._();
  factory _SessionHistoryEntry.fromJson(Map<String, dynamic> json) => _$SessionHistoryEntryFromJson(json);

@override final  DateTime at;
@override final  String from;
@override final  String to;
@override final  String? reason;

/// Create a copy of SessionHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionHistoryEntryCopyWith<_SessionHistoryEntry> get copyWith => __$SessionHistoryEntryCopyWithImpl<_SessionHistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionHistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionHistoryEntry&&(identical(other.at, at) || other.at == at)&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,from,to,reason);

@override
String toString() {
  return 'SessionHistoryEntry(at: $at, from: $from, to: $to, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$SessionHistoryEntryCopyWith<$Res> implements $SessionHistoryEntryCopyWith<$Res> {
  factory _$SessionHistoryEntryCopyWith(_SessionHistoryEntry value, $Res Function(_SessionHistoryEntry) _then) = __$SessionHistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, String from, String to, String? reason
});




}
/// @nodoc
class __$SessionHistoryEntryCopyWithImpl<$Res>
    implements _$SessionHistoryEntryCopyWith<$Res> {
  __$SessionHistoryEntryCopyWithImpl(this._self, this._then);

  final _SessionHistoryEntry _self;
  final $Res Function(_SessionHistoryEntry) _then;

/// Create a copy of SessionHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? from = null,Object? to = null,Object? reason = freezed,}) {
  return _then(_SessionHistoryEntry(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SessionStatus {

 int get schemaVersion; String get sessionId; SessionState get state; DateTime get createdAt; DateTime get updatedAt; int get roundsCompleted; int get roundsPlanned; String? get currentTrial; List<SessionHistoryEntry> get history; String? get error;
/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStatusCopyWith<SessionStatus> get copyWith => _$SessionStatusCopyWithImpl<SessionStatus>(this as SessionStatus, _$identity);

  /// Serializes this SessionStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionStatus&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.state, state) || other.state == state)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.roundsCompleted, roundsCompleted) || other.roundsCompleted == roundsCompleted)&&(identical(other.roundsPlanned, roundsPlanned) || other.roundsPlanned == roundsPlanned)&&(identical(other.currentTrial, currentTrial) || other.currentTrial == currentTrial)&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,sessionId,state,createdAt,updatedAt,roundsCompleted,roundsPlanned,currentTrial,const DeepCollectionEquality().hash(history),error);

@override
String toString() {
  return 'SessionStatus(schemaVersion: $schemaVersion, sessionId: $sessionId, state: $state, createdAt: $createdAt, updatedAt: $updatedAt, roundsCompleted: $roundsCompleted, roundsPlanned: $roundsPlanned, currentTrial: $currentTrial, history: $history, error: $error)';
}


}

/// @nodoc
abstract mixin class $SessionStatusCopyWith<$Res>  {
  factory $SessionStatusCopyWith(SessionStatus value, $Res Function(SessionStatus) _then) = _$SessionStatusCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String sessionId, SessionState state, DateTime createdAt, DateTime updatedAt, int roundsCompleted, int roundsPlanned, String? currentTrial, List<SessionHistoryEntry> history, String? error
});




}
/// @nodoc
class _$SessionStatusCopyWithImpl<$Res>
    implements $SessionStatusCopyWith<$Res> {
  _$SessionStatusCopyWithImpl(this._self, this._then);

  final SessionStatus _self;
  final $Res Function(SessionStatus) _then;

/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? sessionId = null,Object? state = null,Object? createdAt = null,Object? updatedAt = null,Object? roundsCompleted = null,Object? roundsPlanned = null,Object? currentTrial = freezed,Object? history = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SessionState,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,roundsCompleted: null == roundsCompleted ? _self.roundsCompleted : roundsCompleted // ignore: cast_nullable_to_non_nullable
as int,roundsPlanned: null == roundsPlanned ? _self.roundsPlanned : roundsPlanned // ignore: cast_nullable_to_non_nullable
as int,currentTrial: freezed == currentTrial ? _self.currentTrial : currentTrial // ignore: cast_nullable_to_non_nullable
as String?,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<SessionHistoryEntry>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionStatus].
extension SessionStatusPatterns on SessionStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionStatus value)  $default,){
final _that = this;
switch (_that) {
case _SessionStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionStatus value)?  $default,){
final _that = this;
switch (_that) {
case _SessionStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String sessionId,  SessionState state,  DateTime createdAt,  DateTime updatedAt,  int roundsCompleted,  int roundsPlanned,  String? currentTrial,  List<SessionHistoryEntry> history,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionStatus() when $default != null:
return $default(_that.schemaVersion,_that.sessionId,_that.state,_that.createdAt,_that.updatedAt,_that.roundsCompleted,_that.roundsPlanned,_that.currentTrial,_that.history,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String sessionId,  SessionState state,  DateTime createdAt,  DateTime updatedAt,  int roundsCompleted,  int roundsPlanned,  String? currentTrial,  List<SessionHistoryEntry> history,  String? error)  $default,) {final _that = this;
switch (_that) {
case _SessionStatus():
return $default(_that.schemaVersion,_that.sessionId,_that.state,_that.createdAt,_that.updatedAt,_that.roundsCompleted,_that.roundsPlanned,_that.currentTrial,_that.history,_that.error);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String sessionId,  SessionState state,  DateTime createdAt,  DateTime updatedAt,  int roundsCompleted,  int roundsPlanned,  String? currentTrial,  List<SessionHistoryEntry> history,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _SessionStatus() when $default != null:
return $default(_that.schemaVersion,_that.sessionId,_that.state,_that.createdAt,_that.updatedAt,_that.roundsCompleted,_that.roundsPlanned,_that.currentTrial,_that.history,_that.error);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _SessionStatus extends SessionStatus {
  const _SessionStatus({this.schemaVersion = SessionStatus.currentSchemaVersion, required this.sessionId, required this.state, required this.createdAt, required this.updatedAt, this.roundsCompleted = 0, required this.roundsPlanned, this.currentTrial, final  List<SessionHistoryEntry> history = const [], this.error}): _history = history,super._();
  factory _SessionStatus.fromJson(Map<String, dynamic> json) => _$SessionStatusFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  String sessionId;
@override final  SessionState state;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  int roundsCompleted;
@override final  int roundsPlanned;
@override final  String? currentTrial;
 final  List<SessionHistoryEntry> _history;
@override@JsonKey() List<SessionHistoryEntry> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override final  String? error;

/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionStatusCopyWith<_SessionStatus> get copyWith => __$SessionStatusCopyWithImpl<_SessionStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionStatus&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.state, state) || other.state == state)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.roundsCompleted, roundsCompleted) || other.roundsCompleted == roundsCompleted)&&(identical(other.roundsPlanned, roundsPlanned) || other.roundsPlanned == roundsPlanned)&&(identical(other.currentTrial, currentTrial) || other.currentTrial == currentTrial)&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,sessionId,state,createdAt,updatedAt,roundsCompleted,roundsPlanned,currentTrial,const DeepCollectionEquality().hash(_history),error);

@override
String toString() {
  return 'SessionStatus(schemaVersion: $schemaVersion, sessionId: $sessionId, state: $state, createdAt: $createdAt, updatedAt: $updatedAt, roundsCompleted: $roundsCompleted, roundsPlanned: $roundsPlanned, currentTrial: $currentTrial, history: $history, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SessionStatusCopyWith<$Res> implements $SessionStatusCopyWith<$Res> {
  factory _$SessionStatusCopyWith(_SessionStatus value, $Res Function(_SessionStatus) _then) = __$SessionStatusCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String sessionId, SessionState state, DateTime createdAt, DateTime updatedAt, int roundsCompleted, int roundsPlanned, String? currentTrial, List<SessionHistoryEntry> history, String? error
});




}
/// @nodoc
class __$SessionStatusCopyWithImpl<$Res>
    implements _$SessionStatusCopyWith<$Res> {
  __$SessionStatusCopyWithImpl(this._self, this._then);

  final _SessionStatus _self;
  final $Res Function(_SessionStatus) _then;

/// Create a copy of SessionStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? sessionId = null,Object? state = null,Object? createdAt = null,Object? updatedAt = null,Object? roundsCompleted = null,Object? roundsPlanned = null,Object? currentTrial = freezed,Object? history = null,Object? error = freezed,}) {
  return _then(_SessionStatus(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SessionState,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,roundsCompleted: null == roundsCompleted ? _self.roundsCompleted : roundsCompleted // ignore: cast_nullable_to_non_nullable
as int,roundsPlanned: null == roundsPlanned ? _self.roundsPlanned : roundsPlanned // ignore: cast_nullable_to_non_nullable
as int,currentTrial: freezed == currentTrial ? _self.currentTrial : currentTrial // ignore: cast_nullable_to_non_nullable
as String?,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<SessionHistoryEntry>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TrialMetadata {

 int get schemaVersion; String get sessionId; String get variantName; String get trialId; int? get round; DateTime get startedAt; DateTime get finishedAt; Map<String, dynamic> get deviceBefore; Map<String, dynamic> get deviceAfter; List<String> get warnings; Map<String, dynamic> get config; String? get deviceProfile; String? get deviceProfileSha256; bool get thermalThrottled; int? get maxThermalStatus;
/// Create a copy of TrialMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrialMetadataCopyWith<TrialMetadata> get copyWith => _$TrialMetadataCopyWithImpl<TrialMetadata>(this as TrialMetadata, _$identity);

  /// Serializes this TrialMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialMetadata&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.variantName, variantName) || other.variantName == variantName)&&(identical(other.trialId, trialId) || other.trialId == trialId)&&(identical(other.round, round) || other.round == round)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&const DeepCollectionEquality().equals(other.deviceBefore, deviceBefore)&&const DeepCollectionEquality().equals(other.deviceAfter, deviceAfter)&&const DeepCollectionEquality().equals(other.warnings, warnings)&&const DeepCollectionEquality().equals(other.config, config)&&(identical(other.deviceProfile, deviceProfile) || other.deviceProfile == deviceProfile)&&(identical(other.deviceProfileSha256, deviceProfileSha256) || other.deviceProfileSha256 == deviceProfileSha256)&&(identical(other.thermalThrottled, thermalThrottled) || other.thermalThrottled == thermalThrottled)&&(identical(other.maxThermalStatus, maxThermalStatus) || other.maxThermalStatus == maxThermalStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,sessionId,variantName,trialId,round,startedAt,finishedAt,const DeepCollectionEquality().hash(deviceBefore),const DeepCollectionEquality().hash(deviceAfter),const DeepCollectionEquality().hash(warnings),const DeepCollectionEquality().hash(config),deviceProfile,deviceProfileSha256,thermalThrottled,maxThermalStatus);

@override
String toString() {
  return 'TrialMetadata(schemaVersion: $schemaVersion, sessionId: $sessionId, variantName: $variantName, trialId: $trialId, round: $round, startedAt: $startedAt, finishedAt: $finishedAt, deviceBefore: $deviceBefore, deviceAfter: $deviceAfter, warnings: $warnings, config: $config, deviceProfile: $deviceProfile, deviceProfileSha256: $deviceProfileSha256, thermalThrottled: $thermalThrottled, maxThermalStatus: $maxThermalStatus)';
}


}

/// @nodoc
abstract mixin class $TrialMetadataCopyWith<$Res>  {
  factory $TrialMetadataCopyWith(TrialMetadata value, $Res Function(TrialMetadata) _then) = _$TrialMetadataCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String sessionId, String variantName, String trialId, int? round, DateTime startedAt, DateTime finishedAt, Map<String, dynamic> deviceBefore, Map<String, dynamic> deviceAfter, List<String> warnings, Map<String, dynamic> config, String? deviceProfile, String? deviceProfileSha256, bool thermalThrottled, int? maxThermalStatus
});




}
/// @nodoc
class _$TrialMetadataCopyWithImpl<$Res>
    implements $TrialMetadataCopyWith<$Res> {
  _$TrialMetadataCopyWithImpl(this._self, this._then);

  final TrialMetadata _self;
  final $Res Function(TrialMetadata) _then;

/// Create a copy of TrialMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? sessionId = null,Object? variantName = null,Object? trialId = null,Object? round = freezed,Object? startedAt = null,Object? finishedAt = null,Object? deviceBefore = null,Object? deviceAfter = null,Object? warnings = null,Object? config = null,Object? deviceProfile = freezed,Object? deviceProfileSha256 = freezed,Object? thermalThrottled = null,Object? maxThermalStatus = freezed,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,variantName: null == variantName ? _self.variantName : variantName // ignore: cast_nullable_to_non_nullable
as String,trialId: null == trialId ? _self.trialId : trialId // ignore: cast_nullable_to_non_nullable
as String,round: freezed == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceBefore: null == deviceBefore ? _self.deviceBefore : deviceBefore // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,deviceAfter: null == deviceAfter ? _self.deviceAfter : deviceAfter // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,deviceProfile: freezed == deviceProfile ? _self.deviceProfile : deviceProfile // ignore: cast_nullable_to_non_nullable
as String?,deviceProfileSha256: freezed == deviceProfileSha256 ? _self.deviceProfileSha256 : deviceProfileSha256 // ignore: cast_nullable_to_non_nullable
as String?,thermalThrottled: null == thermalThrottled ? _self.thermalThrottled : thermalThrottled // ignore: cast_nullable_to_non_nullable
as bool,maxThermalStatus: freezed == maxThermalStatus ? _self.maxThermalStatus : maxThermalStatus // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrialMetadata].
extension TrialMetadataPatterns on TrialMetadata {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrialMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrialMetadata() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrialMetadata value)  $default,){
final _that = this;
switch (_that) {
case _TrialMetadata():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrialMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _TrialMetadata() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String sessionId,  String variantName,  String trialId,  int? round,  DateTime startedAt,  DateTime finishedAt,  Map<String, dynamic> deviceBefore,  Map<String, dynamic> deviceAfter,  List<String> warnings,  Map<String, dynamic> config,  String? deviceProfile,  String? deviceProfileSha256,  bool thermalThrottled,  int? maxThermalStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrialMetadata() when $default != null:
return $default(_that.schemaVersion,_that.sessionId,_that.variantName,_that.trialId,_that.round,_that.startedAt,_that.finishedAt,_that.deviceBefore,_that.deviceAfter,_that.warnings,_that.config,_that.deviceProfile,_that.deviceProfileSha256,_that.thermalThrottled,_that.maxThermalStatus);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String sessionId,  String variantName,  String trialId,  int? round,  DateTime startedAt,  DateTime finishedAt,  Map<String, dynamic> deviceBefore,  Map<String, dynamic> deviceAfter,  List<String> warnings,  Map<String, dynamic> config,  String? deviceProfile,  String? deviceProfileSha256,  bool thermalThrottled,  int? maxThermalStatus)  $default,) {final _that = this;
switch (_that) {
case _TrialMetadata():
return $default(_that.schemaVersion,_that.sessionId,_that.variantName,_that.trialId,_that.round,_that.startedAt,_that.finishedAt,_that.deviceBefore,_that.deviceAfter,_that.warnings,_that.config,_that.deviceProfile,_that.deviceProfileSha256,_that.thermalThrottled,_that.maxThermalStatus);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String sessionId,  String variantName,  String trialId,  int? round,  DateTime startedAt,  DateTime finishedAt,  Map<String, dynamic> deviceBefore,  Map<String, dynamic> deviceAfter,  List<String> warnings,  Map<String, dynamic> config,  String? deviceProfile,  String? deviceProfileSha256,  bool thermalThrottled,  int? maxThermalStatus)?  $default,) {final _that = this;
switch (_that) {
case _TrialMetadata() when $default != null:
return $default(_that.schemaVersion,_that.sessionId,_that.variantName,_that.trialId,_that.round,_that.startedAt,_that.finishedAt,_that.deviceBefore,_that.deviceAfter,_that.warnings,_that.config,_that.deviceProfile,_that.deviceProfileSha256,_that.thermalThrottled,_that.maxThermalStatus);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class _TrialMetadata extends TrialMetadata {
  const _TrialMetadata({this.schemaVersion = TrialMetadata.currentSchemaVersion, required this.sessionId, required this.variantName, required this.trialId, this.round, required this.startedAt, required this.finishedAt, final  Map<String, dynamic> deviceBefore = const {}, final  Map<String, dynamic> deviceAfter = const {}, final  List<String> warnings = const [], final  Map<String, dynamic> config = const {}, this.deviceProfile, this.deviceProfileSha256, this.thermalThrottled = false, this.maxThermalStatus}): _deviceBefore = deviceBefore,_deviceAfter = deviceAfter,_warnings = warnings,_config = config,super._();
  factory _TrialMetadata.fromJson(Map<String, dynamic> json) => _$TrialMetadataFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  String sessionId;
@override final  String variantName;
@override final  String trialId;
@override final  int? round;
@override final  DateTime startedAt;
@override final  DateTime finishedAt;
 final  Map<String, dynamic> _deviceBefore;
@override@JsonKey() Map<String, dynamic> get deviceBefore {
  if (_deviceBefore is EqualUnmodifiableMapView) return _deviceBefore;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_deviceBefore);
}

 final  Map<String, dynamic> _deviceAfter;
@override@JsonKey() Map<String, dynamic> get deviceAfter {
  if (_deviceAfter is EqualUnmodifiableMapView) return _deviceAfter;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_deviceAfter);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

 final  Map<String, dynamic> _config;
@override@JsonKey() Map<String, dynamic> get config {
  if (_config is EqualUnmodifiableMapView) return _config;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_config);
}

@override final  String? deviceProfile;
@override final  String? deviceProfileSha256;
@override@JsonKey() final  bool thermalThrottled;
@override final  int? maxThermalStatus;

/// Create a copy of TrialMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrialMetadataCopyWith<_TrialMetadata> get copyWith => __$TrialMetadataCopyWithImpl<_TrialMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrialMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrialMetadata&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.variantName, variantName) || other.variantName == variantName)&&(identical(other.trialId, trialId) || other.trialId == trialId)&&(identical(other.round, round) || other.round == round)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&const DeepCollectionEquality().equals(other._deviceBefore, _deviceBefore)&&const DeepCollectionEquality().equals(other._deviceAfter, _deviceAfter)&&const DeepCollectionEquality().equals(other._warnings, _warnings)&&const DeepCollectionEquality().equals(other._config, _config)&&(identical(other.deviceProfile, deviceProfile) || other.deviceProfile == deviceProfile)&&(identical(other.deviceProfileSha256, deviceProfileSha256) || other.deviceProfileSha256 == deviceProfileSha256)&&(identical(other.thermalThrottled, thermalThrottled) || other.thermalThrottled == thermalThrottled)&&(identical(other.maxThermalStatus, maxThermalStatus) || other.maxThermalStatus == maxThermalStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,sessionId,variantName,trialId,round,startedAt,finishedAt,const DeepCollectionEquality().hash(_deviceBefore),const DeepCollectionEquality().hash(_deviceAfter),const DeepCollectionEquality().hash(_warnings),const DeepCollectionEquality().hash(_config),deviceProfile,deviceProfileSha256,thermalThrottled,maxThermalStatus);

@override
String toString() {
  return 'TrialMetadata(schemaVersion: $schemaVersion, sessionId: $sessionId, variantName: $variantName, trialId: $trialId, round: $round, startedAt: $startedAt, finishedAt: $finishedAt, deviceBefore: $deviceBefore, deviceAfter: $deviceAfter, warnings: $warnings, config: $config, deviceProfile: $deviceProfile, deviceProfileSha256: $deviceProfileSha256, thermalThrottled: $thermalThrottled, maxThermalStatus: $maxThermalStatus)';
}


}

/// @nodoc
abstract mixin class _$TrialMetadataCopyWith<$Res> implements $TrialMetadataCopyWith<$Res> {
  factory _$TrialMetadataCopyWith(_TrialMetadata value, $Res Function(_TrialMetadata) _then) = __$TrialMetadataCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String sessionId, String variantName, String trialId, int? round, DateTime startedAt, DateTime finishedAt, Map<String, dynamic> deviceBefore, Map<String, dynamic> deviceAfter, List<String> warnings, Map<String, dynamic> config, String? deviceProfile, String? deviceProfileSha256, bool thermalThrottled, int? maxThermalStatus
});




}
/// @nodoc
class __$TrialMetadataCopyWithImpl<$Res>
    implements _$TrialMetadataCopyWith<$Res> {
  __$TrialMetadataCopyWithImpl(this._self, this._then);

  final _TrialMetadata _self;
  final $Res Function(_TrialMetadata) _then;

/// Create a copy of TrialMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? sessionId = null,Object? variantName = null,Object? trialId = null,Object? round = freezed,Object? startedAt = null,Object? finishedAt = null,Object? deviceBefore = null,Object? deviceAfter = null,Object? warnings = null,Object? config = null,Object? deviceProfile = freezed,Object? deviceProfileSha256 = freezed,Object? thermalThrottled = null,Object? maxThermalStatus = freezed,}) {
  return _then(_TrialMetadata(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,variantName: null == variantName ? _self.variantName : variantName // ignore: cast_nullable_to_non_nullable
as String,trialId: null == trialId ? _self.trialId : trialId // ignore: cast_nullable_to_non_nullable
as String,round: freezed == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,finishedAt: null == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deviceBefore: null == deviceBefore ? _self._deviceBefore : deviceBefore // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,deviceAfter: null == deviceAfter ? _self._deviceAfter : deviceAfter // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,config: null == config ? _self._config : config // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,deviceProfile: freezed == deviceProfile ? _self.deviceProfile : deviceProfile // ignore: cast_nullable_to_non_nullable
as String?,deviceProfileSha256: freezed == deviceProfileSha256 ? _self.deviceProfileSha256 : deviceProfileSha256 // ignore: cast_nullable_to_non_nullable
as String?,thermalThrottled: null == thermalThrottled ? _self.thermalThrottled : thermalThrottled // ignore: cast_nullable_to_non_nullable
as bool,maxThermalStatus: freezed == maxThermalStatus ? _self.maxThermalStatus : maxThermalStatus // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
