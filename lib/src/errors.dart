/// Base class of everything this package throws.
sealed class ReflectionError implements Exception {
  const ReflectionError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a type has no [ClassMirror] registered.
final class TypeNotRegisteredError extends ReflectionError {
  TypeNotRegisteredError(this.typeName, Iterable<String> known)
    : super(
        'No mirror registered for "$typeName". '
        'Registered types: ${known.isEmpty ? '<none>' : known.join(', ')}.',
      );

  final String typeName;
}

/// Thrown when a mirror has no member under the requested name.
final class MemberNotFoundError extends ReflectionError {
  MemberNotFoundError(
    this.typeName,
    this.memberName,
    this.kind,
    Iterable<String> known,
  ) : super(
        '"$typeName" has no $kind called "$memberName". '
        'Known ${kind}s: ${known.isEmpty ? '<none>' : known.join(', ')}.',
      );

  final String typeName;
  final String memberName;

  /// Either `property` or `method`.
  final String kind;
}

/// Thrown when writing to a property that was registered without a setter.
final class ReadOnlyPropertyError extends ReflectionError {
  ReadOnlyPropertyError(this.typeName, this.propertyName)
    : super(
        '"$propertyName" of "$typeName" was registered without a '
        'setter, so it cannot be written.',
      );

  final String typeName;
  final String propertyName;
}

/// Thrown when creating an instance of a mirror registered without a
/// constructor.
final class MissingConstructorError extends ReflectionError {
  MissingConstructorError(this.typeName)
    : super(
        'The mirror for "$typeName" was registered without a '
        'constructor, so instances cannot be created from it.',
      );

  final String typeName;
}

/// Thrown when an instance does not match the mirror it is used with.
final class WrongInstanceTypeError extends ReflectionError {
  WrongInstanceTypeError(this.expected, this.actual)
    : super('Expected an instance of "$expected" but got "$actual".');

  final String expected;
  final String actual;
}
