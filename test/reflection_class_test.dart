import 'package:reflection_class/reflection_class.dart';
import 'package:test/test.dart';

class User {
  User(this.name, {this.age = 0});

  String name;
  int age;
  final DateTime created = DateTime(2020);

  String greet(String greeting, {String punctuation = '!'}) =>
      '$greeting, $name$punctuation';

  int birthday() => ++age;
}

class Admin extends User {
  Admin(super.name);
}

ClassMirror<User> userMirror() => ClassMirror<User>(
  constructor: (Map<String, Object?> args) =>
      User(args['name']! as String, age: (args['age'] as int?) ?? 0),
  properties: <PropertyMirror<User>>[
    PropertyMirror<User>(
      'name',
      type: String,
      get: (User u) => u.name,
      set: (User u, Object? v) => u.name = v! as String,
    ),
    PropertyMirror<User>(
      'age',
      type: int,
      get: (User u) => u.age,
      set: (User u, Object? v) => u.age = v! as int,
    ),
    PropertyMirror<User>('created', type: DateTime, get: (User u) => u.created),
  ],
  methods: <MethodMirror<User>>[
    MethodMirror<User>(
      'greet',
      invoke: (User u, List<Object?> args, Map<String, Object?> named) =>
          u.greet(
            args.first! as String,
            punctuation: (named['punctuation'] as String?) ?? '!',
          ),
    ),
    MethodMirror<User>(
      'birthday',
      invoke: (User u, List<Object?> args, Map<String, Object?> named) =>
          u.birthday(),
    ),
  ],
);

void main() {
  late Reflector reflector;

  setUp(() {
    reflector = Reflector()..register<User>(userMirror());
  });

  group('registry', () {
    test('reports what it knows', () {
      expect(reflector.isRegistered<User>(), isTrue);
      expect(reflector.isRegisteredByName('User'), isTrue);
      expect(reflector.registeredNames, contains('User'));
      expect(reflector.length, 1);
    });

    test('unregisters and clears', () {
      expect(reflector.unregister<User>(), isTrue);
      expect(reflector.isRegistered<User>(), isFalse);
      expect(reflector.unregister<User>(), isFalse);

      reflector.register<User>(userMirror());
      reflector.clear();
      expect(reflector.length, 0);
    });

    test('an unknown type says which types it does know', () {
      reflector.clear();
      reflector.register<User>(userMirror());

      expect(
        () => reflector.of<Admin>(),
        throwsA(
          isA<TypeNotRegisteredError>().having(
            (TypeNotRegisteredError e) => e.message,
            'message',
            allOf(contains('Admin'), contains('User')),
          ),
        ),
      );
    });

    test('serves a subclass from its registered supertype', () {
      final Admin admin = Admin('Ada');

      expect(reflector.getField(admin, 'name'), 'Ada');
      expect(reflector.mirrorFor(admin)?.name, 'User');
    });

    test('members stay usable through an untyped mirror', () {
      // Regression: the accessors used to be public fields, so reading one off
      // a ClassMirror<Object> cast the closure and threw
      // "(User) => String is not a subtype of (Object) => Object?" - which is
      // exactly what a generic, mirror-driven UI does.
      final Object user = User('Ada', age: 36);
      final ClassMirror<Object> mirror = reflector.mirrorFor(user)!;

      final Map<String, Object?> read = <String, Object?>{
        for (final PropertyMirror<Object> property in mirror.properties)
          property.name: property.read(user),
      };

      expect(read['name'], 'Ada');
      expect(read['age'], 36);

      mirror.property('age').write(user, 37, owner: mirror.name);
      expect(mirror.method('birthday')(user), 38);
    });

    test('a custom mirror name can be used instead of the type name', () {
      final Reflector named = Reflector()
        ..register<User>(
          ClassMirror<User>(
            name: 'account',
            constructor: (Map<String, Object?> a) => User(a['name']! as String),
          ),
        );

      expect(named.isRegisteredByName('account'), isTrue);
      expect(
        (named.createByName('account', <String, Object?>{'name': 'Ada'})
                as User)
            .name,
        'Ada',
      );
    });
  });

  group('creating', () {
    test('builds an instance from named arguments', () {
      final User user = reflector.create<User>(<String, Object?>{
        'name': 'Ada',
        'age': 36,
      });

      expect(user.name, 'Ada');
      expect(user.age, 36);
    });

    test('builds by run-time name', () {
      final Object user = reflector.createByName('User', <String, Object?>{
        'name': 'Grace',
      });

      expect((user as User).name, 'Grace');
    });

    test('refuses a mirror registered without a constructor', () {
      final Reflector bare = Reflector()
        ..register<User>(
          ClassMirror<User>(
            properties: <PropertyMirror<User>>[
              PropertyMirror<User>('name', get: (User u) => u.name),
            ],
          ),
        );

      expect(
        () => bare.create<User>(),
        throwsA(isA<MissingConstructorError>()),
      );
    });
  });

  group('properties', () {
    test('reads and writes by name', () {
      final User user = User('Ada');

      expect(reflector.getField(user, 'name'), 'Ada');
      reflector.setField(user, 'name', 'Grace');
      expect(user.name, 'Grace');
    });

    test('refuses to write a property declared without a setter', () {
      final User user = User('Ada');

      expect(
        () => reflector.setField(user, 'created', DateTime(2024)),
        throwsA(isA<ReadOnlyPropertyError>()),
      );
    });

    test('an unknown property lists the known ones', () {
      final User user = User('Ada');

      expect(
        () => reflector.getField(user, 'nope'),
        throwsA(
          isA<MemberNotFoundError>().having(
            (MemberNotFoundError e) => e.message,
            'message',
            allOf(contains('nope'), contains('name'), contains('property')),
          ),
        ),
      );
    });

    test('describes what it knows about a type', () {
      final ClassMirror<User> mirror = reflector.of<User>();

      expect(mirror.propertyNames, <String>['name', 'age', 'created']);
      expect(mirror.methodNames, <String>['greet', 'birthday']);
      expect(mirror.property('created').isReadOnly, isTrue);
      expect(mirror.property('name').type, String);
    });
  });

  group('methods', () {
    test('calls with positional and named arguments', () {
      final User user = User('Ada');

      expect(
        reflector.invoke(
          user,
          'greet',
          positionalArguments: <Object?>['Hello'],
          namedArguments: <String, Object?>{'punctuation': '?'},
        ),
        'Hello, Ada?',
      );
    });

    test('calls without arguments and returns the value', () {
      final User user = User('Ada', age: 36);

      expect(reflector.invoke(user, 'birthday'), 37);
      expect(user.age, 37);
    });

    test('an unknown method lists the known ones', () {
      final User user = User('Ada');

      expect(
        () => reflector.invoke(user, 'nope'),
        throwsA(
          isA<MemberNotFoundError>().having(
            (MemberNotFoundError e) => e.message,
            'message',
            allOf(contains('nope'), contains('greet'), contains('method')),
          ),
        ),
      );
    });
  });

  group('maps', () {
    test('turns an instance into its readable properties', () {
      final User user = User('Ada', age: 36);

      expect(reflector.toMap(user), <String, Object?>{
        'name': 'Ada',
        'age': 36,
        'created': DateTime(2020),
      });
    });

    test('builds an instance back from a map', () {
      final User user = reflector.fromMap<User>(<String, Object?>{
        'name': 'Ada',
        'age': 36,
      });

      expect(user.name, 'Ada');
      expect(user.age, 36);
    });

    test('a round trip keeps the writable values', () {
      final User original = User('Ada', age: 36);

      final User copy = reflector.fromMap<User>(reflector.toMap(original));

      expect(copy.name, original.name);
      expect(copy.age, original.age);
    });

    test('applyMap writes onto an existing instance', () {
      final User user = User('Ada', age: 36);

      reflector.applyMap(user, <String, Object?>{'age': 37});

      expect(user.age, 37);
      expect(user.name, 'Ada');
    });

    test('applyMap refuses a read-only property', () {
      final User user = User('Ada');

      expect(
        () => reflector.applyMap(user, <String, Object?>{
          'created': DateTime(2024),
        }),
        throwsA(isA<ReadOnlyPropertyError>()),
      );
    });

    test('fromMap ignores read-only values the constructor consumed', () {
      final User user = reflector.fromMap<User>(<String, Object?>{
        'name': 'Ada',
        'age': 36,
        'created': DateTime(2020),
      });

      expect(user.name, 'Ada');
    });
  });

  group('the shared registry', () {
    tearDown(Reflector.instance.clear);

    test('is a Reflector like any other', () {
      Reflector.instance.register<User>(userMirror());

      final User user = Reflector.instance.create<User>(<String, Object?>{
        'name': 'Ada',
      });

      expect(Reflector.instance.getField(user, 'name'), 'Ada');
    });
  });
}
