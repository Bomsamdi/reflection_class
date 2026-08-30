import 'errors.dart';

/// Builds an instance from named arguments.
typedef Constructor<T> = T Function(Map<String, Object?> arguments);

/// Reads a property off an instance.
typedef Getter<T> = Object? Function(T instance);

/// Writes a property on an instance.
typedef Setter<T> = void Function(T instance, Object? value);

/// Calls a method on an instance.
typedef Invoker<T> =
    Object? Function(
      T instance,
      List<Object?> positionalArguments,
      Map<String, Object?> namedArguments,
    );

/// One readable, optionally writable property of [T].
///
/// ```dart
/// PropertyMirror<User>('name', get: (User u) => u.name,
///     set: (User u, Object? v) => u.name = v! as String);
/// ```
class PropertyMirror<T> {
  const PropertyMirror(
    this.name, {
    required Getter<T> get,
    Setter<T>? set,
    this.type,
  }) : _get = get,
       _set = set;

  /// The name the property is addressed by.
  final String name;

  // Kept private and reached through [read] and [write]: handing the raw
  // closures out breaks every view of this mirror as PropertyMirror<Object>,
  // because function parameters are contravariant, so
  // `(Product) => String` is not a subtype of `(Object) => Object?`.
  final Getter<T> _get;
  final Setter<T>? _set;

  /// The declared type, kept for description only.
  final Type? type;

  /// Whether this property was registered without a setter.
  bool get isReadOnly => _set == null;

  /// Reads the value off [instance].
  Object? read(T instance) => _get(instance);

  /// Writes [value] onto [instance].
  ///
  /// Throws [ReadOnlyPropertyError] when no setter was declared; [owner] only
  /// names the type in that message.
  void write(T instance, Object? value, {String owner = '?'}) {
    final Setter<T>? set = _set;
    if (set == null) throw ReadOnlyPropertyError(owner, name);
    set(instance, value);
  }

  @override
  String toString() =>
      'PropertyMirror($name${type == null ? '' : ': $type'}'
      '${isReadOnly ? ', read-only' : ''})';
}

/// One callable method of [T].
///
/// ```dart
/// MethodMirror<Counter>('increment',
///     invoke: (Counter c, List<Object?> args, _) => c.increment());
/// ```
class MethodMirror<T> {
  const MethodMirror(this.name, {required Invoker<T> invoke})
    : _invoke = invoke;

  /// The name the method is addressed by.
  final String name;

  // Private for the same reason as PropertyMirror's accessors.
  final Invoker<T> _invoke;

  /// Calls the method on [instance].
  Object? call(
    T instance, [
    List<Object?> positionalArguments = const <Object?>[],
    Map<String, Object?> namedArguments = const <String, Object?>{},
  ]) => _invoke(instance, positionalArguments, namedArguments);

  @override
  String toString() => 'MethodMirror($name)';
}

/// The members of [T] that this package can reach at run time.
///
/// Flutter has no `dart:mirrors`, so the metadata is declared once instead of
/// being discovered. From there the members can be addressed by name.
class ClassMirror<T extends Object> {
  ClassMirror({
    String? name,
    Constructor<T>? constructor,
    List<PropertyMirror<T>> properties = const <Never>[],
    List<MethodMirror<T>> methods = const <Never>[],
  }) : name = name ?? T.toString(),
       _constructor = constructor,
       _properties = <String, PropertyMirror<T>>{
         for (final PropertyMirror<T> property in properties)
           property.name: property,
       },
       _methods = <String, MethodMirror<T>>{
         for (final MethodMirror<T> method in methods) method.name: method,
       };

  /// The name this type is addressed by. Defaults to the type's own name.
  final String name;

  final Constructor<T>? _constructor;

  /// Whether a constructor was declared, i.e. whether [create] can work.
  bool get canCreate => _constructor != null;

  final Map<String, PropertyMirror<T>> _properties;
  final Map<String, MethodMirror<T>> _methods;

  /// The declared properties, in registration order.
  Iterable<PropertyMirror<T>> get properties => _properties.values;

  /// The declared methods, in registration order.
  Iterable<MethodMirror<T>> get methods => _methods.values;

  /// The names of the declared properties.
  Iterable<String> get propertyNames => _properties.keys;

  /// The names of the declared methods.
  Iterable<String> get methodNames => _methods.keys;

  /// Whether [instance] is a [T].
  bool isInstance(Object instance) => instance is T;

  /// Whether a property with [propertyName] was declared.
  bool hasProperty(String propertyName) =>
      _properties.containsKey(propertyName);

  /// Whether a method with [methodName] was declared.
  bool hasMethod(String methodName) => _methods.containsKey(methodName);

  /// The declared property, or throws [MemberNotFoundError].
  PropertyMirror<T> property(String propertyName) =>
      _properties[propertyName] ??
      (throw MemberNotFoundError(
        name,
        propertyName,
        'property',
        _properties.keys,
      ));

  /// The declared method, or throws [MemberNotFoundError].
  MethodMirror<T> method(String methodName) =>
      _methods[methodName] ??
      (throw MemberNotFoundError(name, methodName, 'method', _methods.keys));

  /// Creates an instance from [arguments].
  ///
  /// Throws [MissingConstructorError] when no constructor was declared.
  T create([Map<String, Object?> arguments = const <String, Object?>{}]) {
    final Constructor<T>? constructor = _constructor;
    if (constructor == null) throw MissingConstructorError(name);
    return constructor(arguments);
  }

  /// Reads [propertyName] off [instance].
  Object? getField(T instance, String propertyName) =>
      property(propertyName).read(instance);

  /// Writes [value] to [propertyName] of [instance].
  ///
  /// Throws [ReadOnlyPropertyError] for a property declared without a setter.
  void setField(T instance, String propertyName, Object? value) {
    property(propertyName).write(instance, value, owner: name);
  }

  /// Calls [methodName] on [instance].
  Object? invoke(
    T instance,
    String methodName, {
    List<Object?> positionalArguments = const <Object?>[],
    Map<String, Object?> namedArguments = const <String, Object?>{},
  }) => method(methodName)(instance, positionalArguments, namedArguments);

  /// Every readable property of [instance], by name.
  ///
  /// A serialisation of sorts, without code generation.
  Map<String, Object?> toMap(T instance) => <String, Object?>{
    for (final PropertyMirror<T> property in _properties.values)
      property.name: property.read(instance),
  };

  /// Builds an instance from [values] with [create], then writes any remaining
  /// writable properties.
  T fromMap(Map<String, Object?> values) {
    final T instance = create(values);
    applyMap(instance, values, skipReadOnly: true);
    return instance;
  }

  /// Writes [values] onto [instance].
  ///
  /// Unknown names throw [MemberNotFoundError]. Read-only properties throw
  /// unless [skipReadOnly] is set, which is what [fromMap] does - the
  /// constructor has already consumed them.
  void applyMap(
    T instance,
    Map<String, Object?> values, {
    bool skipReadOnly = false,
  }) {
    for (final MapEntry<String, Object?> entry in values.entries) {
      if (skipReadOnly && !hasProperty(entry.key)) continue;
      final PropertyMirror<T> property = this.property(entry.key);
      if (property.isReadOnly) {
        if (skipReadOnly) continue;
        throw ReadOnlyPropertyError(name, entry.key);
      }
      property.write(instance, entry.value, owner: name);
    }
  }

  @override
  String toString() =>
      'ClassMirror<$name>'
      '(${_properties.length} properties, ${_methods.length} methods)';
}
