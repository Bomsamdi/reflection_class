## 1.0.0

Written from scratch, pure Dart, no dependencies:

* `ClassMirror<T>` - the members of a type, declared once.
* `PropertyMirror<T>` - `read`, `write`, `isReadOnly`, `type`.
* `MethodMirror<T>` - callable with positional and named arguments.
* `Reflector` - a registry: `register`, `of`, `byName`, `mirrorFor`, `create`,
  `createByName`, `getField`, `setField`, `invoke`, `toMap`, `fromMap`,
  `applyMap`, `unregister`, `clear`.
* `mirrorFor` falls back to a registered supertype, so a subclass is served by
  its parent's mirror.
* Typed errors that name what was available: `TypeNotRegisteredError`,
  `MemberNotFoundError`, `ReadOnlyPropertyError`, `MissingConstructorError`.
* The accessors are methods rather than fields, so a mirror stays usable when
  it is held as `ClassMirror<Object>` - reading a `Getter<User>` off such a view
  used to throw `(User) => String is not a subtype of (Object) => Object?`,
  which is exactly what generic, mirror-driven code does.

### Other

* Requires Dart 3.8; `lints` 6; no Flutter dependency, so it works in plain
  Dart as well.
* 23 tests, plus 3 in the example. The package previously shipped an empty test.
* The example builds a complete object editor from a mirror, without naming the
  model type anywhere in the UI code.

## 0.0.1

* Initial release.
