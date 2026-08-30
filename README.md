# reflection_class

[![Pub Version](https://img.shields.io/pub/v/reflection_class)](https://pub.dev/packages/reflection_class)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![pub points](https://img.shields.io/pub/points/reflection_class)](https://pub.dev/packages/reflection_class/score)

Reach an object's properties and methods **by name**, where Flutter has no
`dart:mirrors`.

You declare what should be reachable — once, in plain Dart — and from there the
members can be read, written, called and serialised at run time. No code
generation, no build step, no dependencies.

## Installation

```yaml
dependencies:
  reflection_class: ^1.0.0
```

Requires Dart 3.8 or newer. Pure Dart: usable outside Flutter too.

## Usage

```dart
import 'package:reflection_class/reflection_class.dart';

class User {
  User(this.name, {this.age = 0});
  String name;
  int age;
  String greet(String greeting) => '$greeting, $name';
}

Reflector.instance.register<User>(
  ClassMirror<User>(
    constructor: (Map<String, Object?> args) =>
        User(args['name']! as String, age: (args['age'] as int?) ?? 0),
    properties: <PropertyMirror<User>>[
      PropertyMirror<User>('name',
          type: String,
          get: (User u) => u.name,
          set: (User u, Object? v) => u.name = v! as String),
      PropertyMirror<User>('age',
          type: int,
          get: (User u) => u.age,
          set: (User u, Object? v) => u.age = v! as int),
    ],
    methods: <MethodMirror<User>>[
      MethodMirror<User>('greet',
          invoke: (User u, List<Object?> args, Map<String, Object?> named) =>
              u.greet(args.first! as String)),
    ],
  ),
);
```

Then:

```dart
final User user = Reflector.instance.create<User>(<String, Object?>{'name': 'Ada'});

Reflector.instance.setField(user, 'age', 36);
Reflector.instance.getField(user, 'name');                  // 'Ada'
Reflector.instance.invoke(user, 'greet',
    positionalArguments: <Object?>['Hello']);               // 'Hello, Ada'
Reflector.instance.toMap(user);                             // {name: Ada, age: 36}
Reflector.instance.fromMap<User>(<String, Object?>{'name': 'Grace'});
```

### Building UI from a type

Because a mirror describes its own members, code can be written against types it
has never heard of — the `/example` app builds a whole editor this way:

```dart
final ClassMirror<Object> mirror = Reflector.instance.mirrorFor(object)!;

for (final PropertyMirror<Object> property in mirror.properties) {
  print('${property.name}: ${property.read(object)}'
      '${property.isReadOnly ? ' (read-only)' : ''}');
}
```

### Types that only exist as a name

```dart
final Object instance = Reflector.instance.createByName(json['type'] as String, json);
```

## API

| Member | Description |
|---|---|
| `Reflector.instance` | The shared registry. `Reflector()` makes a private one. |
| `register<T>(mirror)` / `unregister<T>()` / `clear()` | Registration. |
| `of<T>()` / `byName(name)` / `mirrorFor(instance)` | Look-ups. `mirrorFor` falls back to a registered supertype. |
| `create<T>(args)` / `createByName(name, args)` | Construction. |
| `getField` / `setField` / `invoke` | Member access by name. |
| `toMap` / `fromMap<T>` / `applyMap` | Serialisation without code generation. |
| `ClassMirror<T>` | The declared members of a type: `properties`, `methods`, `canCreate`. |
| `PropertyMirror<T>` | `read`, `write`, `isReadOnly`, `type`. |
| `MethodMirror<T>` | Callable: `mirror.method('greet')(instance, args)`. |

Every failure is a `ReflectionError` — `TypeNotRegisteredError`,
`MemberNotFoundError`, `ReadOnlyPropertyError`, `MissingConstructorError` — and
each message lists what *was* available.

## What this is not

It is not real reflection: nothing is discovered for you, and a member you do
not declare stays invisible. That is the trade Flutter forces — and it keeps
tree shaking intact, which `dart:mirrors` would not.

## License

MIT.
