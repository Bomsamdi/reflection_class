/// Reach an object's members by name where Flutter has no `dart:mirrors`.
///
/// Declare a [ClassMirror] once per type, register it with a [Reflector], and
/// read properties, call methods or turn instances into maps at run time.
library;

export 'src/errors.dart';
export 'src/mirrors.dart'
    show
        ClassMirror,
        Constructor,
        Getter,
        Invoker,
        MethodMirror,
        PropertyMirror,
        Setter;
export 'src/reflector.dart' show Reflector;
