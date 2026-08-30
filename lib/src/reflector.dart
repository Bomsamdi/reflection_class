import 'errors.dart';
import 'mirrors.dart';

/// A registry of [ClassMirror]s, and the entry point of this package.
///
/// Register what should be reachable at run time, then address those members
/// by name:
///
/// ```dart
/// Reflector.instance.register(
///   ClassMirror<User>(
///     constructor: (Map<String, Object?> args) =>
///         User(args['name']! as String),
///     properties: <PropertyMirror<User>>[
///       PropertyMirror<User>('name',
///           get: (User u) => u.name,
///           set: (User u, Object? v) => u.name = v! as String),
///     ],
///   ),
/// );
///
/// final User user = Reflector.instance.create<User>(<String, Object?>{'name': 'Ada'});
/// Reflector.instance.setField(user, 'name', 'Grace');
/// print(Reflector.instance.toMap(user)); // {name: Grace}
/// ```
class Reflector {
  /// Creates an empty registry. Most code wants [instance].
  Reflector();

  /// The registry shared by the whole program.
  static final Reflector instance = Reflector();

  final Map<Type, ClassMirror<Object>> _byType = <Type, ClassMirror<Object>>{};
  final Map<String, ClassMirror<Object>> _byName =
      <String, ClassMirror<Object>>{};

  /// The names of every registered type, in registration order.
  Iterable<String> get registeredNames => _byName.keys;

  /// How many types are registered.
  int get length => _byType.length;

  /// Registers [mirror] for [T].
  ///
  /// Registering the same type twice replaces the previous mirror.
  void register<T extends Object>(ClassMirror<T> mirror) {
    _byType[T] = mirror;
    _byName[mirror.name] = mirror;
  }

  /// Removes the mirror of [T]. Returns whether one was registered.
  bool unregister<T extends Object>() {
    final ClassMirror<Object>? mirror = _byType.remove(T);
    if (mirror == null) return false;
    _byName.remove(mirror.name);
    return true;
  }

  /// Forgets every registration.
  void clear() {
    _byType.clear();
    _byName.clear();
  }

  /// Whether [T] has a mirror.
  bool isRegistered<T extends Object>() => _byType.containsKey(T);

  /// Whether a type named [typeName] has a mirror.
  bool isRegisteredByName(String typeName) => _byName.containsKey(typeName);

  /// The mirror of [T], or throws [TypeNotRegisteredError].
  ClassMirror<T> of<T extends Object>() {
    final ClassMirror<Object>? mirror = _byType[T];
    if (mirror == null) {
      throw TypeNotRegisteredError(T.toString(), registeredNames);
    }
    return mirror as ClassMirror<T>;
  }

  /// The mirror registered under [typeName], or throws
  /// [TypeNotRegisteredError].
  ClassMirror<Object> byName(String typeName) =>
      _byName[typeName] ??
      (throw TypeNotRegisteredError(typeName, registeredNames));

  /// The mirror matching [instance], or null.
  ///
  /// Looks the run-time type up first; failing that, falls back to the first
  /// registered mirror that accepts the instance, so a subclass is served by
  /// its registered supertype.
  ClassMirror<Object>? mirrorFor(Object instance) {
    final ClassMirror<Object>? exact = _byType[instance.runtimeType];
    if (exact != null) return exact;
    for (final ClassMirror<Object> mirror in _byType.values) {
      if (mirror.isInstance(instance)) return mirror;
    }
    return null;
  }

  ClassMirror<Object> _require(Object instance) =>
      mirrorFor(instance) ??
      (throw TypeNotRegisteredError(
        instance.runtimeType.toString(),
        registeredNames,
      ));

  /// Creates a [T] from [arguments].
  T create<T extends Object>([
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) => of<T>().create(arguments);

  /// Creates an instance of the type registered as [typeName].
  ///
  /// The static type is [Object]; this is the path for names that only exist
  /// at run time, such as a discriminator read from JSON.
  Object createByName(
    String typeName, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) => byName(typeName).create(arguments);

  /// Reads [propertyName] off [instance].
  Object? getField(Object instance, String propertyName) =>
      _require(instance).getField(instance, propertyName);

  /// Writes [value] to [propertyName] of [instance].
  void setField(Object instance, String propertyName, Object? value) =>
      _require(instance).setField(instance, propertyName, value);

  /// Calls [methodName] on [instance].
  Object? invoke(
    Object instance,
    String methodName, {
    List<Object?> positionalArguments = const <Object?>[],
    Map<String, Object?> namedArguments = const <String, Object?>{},
  }) => _require(instance).invoke(
    instance,
    methodName,
    positionalArguments: positionalArguments,
    namedArguments: namedArguments,
  );

  /// Every readable property of [instance], by name.
  Map<String, Object?> toMap(Object instance) =>
      _require(instance).toMap(instance);

  /// Builds a [T] out of [values].
  T fromMap<T extends Object>(Map<String, Object?> values) =>
      of<T>().fromMap(values);

  /// Writes [values] onto [instance].
  void applyMap(Object instance, Map<String, Object?> values) =>
      _require(instance).applyMap(instance, values);

  @override
  String toString() => 'Reflector(${_byName.keys.join(', ')})';
}
