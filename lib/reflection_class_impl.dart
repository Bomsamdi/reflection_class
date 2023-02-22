part of 'reflection_class.dart';

//  Created by Bomsamdi on 2023
//  Copyright © 2023 Bomsamdi. All rights reserved.

/// Two handy functions that help me to express my intention clearer and shorter to check for runtime
/// errors
// ignore: avoid_positional_boolean_parameters
void throwIf(bool condition, Object error) {
  if (condition) throw error;
}

// ignore: avoid_positional_boolean_parameters
void throwIfNot(bool condition, Object error) {
  if (!condition) throw error;
}

class _ServiceClass<T extends Object, PARAM> {
  final _ReflectionClassImplementation _reflectionClassInstance;
  final _Scope registrationScope;

  late final Type paramType;

  /// Because of the different creation methods we need alternative class functions
  /// only one of them is always set.
  final ClassFunc<T>? creationFunction;
  final ClassFuncParam<T, PARAM>? creationFunctionParam;

  ///  Dispose function that is used when a scope is popped
  final DisposingFunc<T>? disposeFunction;

  /// In case of a named registration the instance name is here stored for easy access
  final String? instanceName;

  /// If an existing Object gets registered or an async/lazy Singleton has finished
  /// its creation, it is stored here
  Object? instance;

  /// the type that was used when registering, used for runtime checks
  late final Type registrationType;

  bool get isNamedRegistration => instanceName != null;

  _ServiceClass(
    this._reflectionClassInstance, {
    this.creationFunction,
    this.creationFunctionParam,
    this.instance,
    this.instanceName,
    required this.registrationScope,
    this.disposeFunction,
  }) : assert(
            !(disposeFunction != null &&
                instance != null &&
                instance is Disposable),
            ' You are trying to register type ${instance.runtimeType.toString()} '
            'that implements "Disposable" but you also provide a disposing function') {
    registrationType = T;
    paramType = PARAM;
  }

  FutureOr dispose() {
    /// check if we are shadowing an existing Object
    final classThatWouldbeShadowed = _reflectionClassInstance
        ._findFirstClassByNameAndTypeOrNull(instanceName,
            type: T, lookInScopeBelow: true);

    final objectThatWouldbeShadowed = classThatWouldbeShadowed?.instance;
    if (objectThatWouldbeShadowed != null &&
        objectThatWouldbeShadowed is ShadowHandler) {
      objectThatWouldbeShadowed.onLeaveShadow(instance!);
    }

    if (instance is Disposable) {
      return (instance as Disposable).onDispose();
    }
  }

  /// Returns an instance depending on the registration type
  T getObject(dynamic param) {
    try {
      if (creationFunctionParam != null) {
        return creationFunctionParam!(param as PARAM);
      } else {
        return creationFunction!();
      }
    } catch (e) {
      rethrow;
    }
  }
}

class _Scope {
  final String? name;
  final ScopeDisposeFunc? disposeFunc;
  final factoriesByName =
      <String?, Map<Type, _ServiceClass<Object, dynamic>>>{};

  _Scope({this.name, this.disposeFunc});

  Future<void> reset({required bool dispose}) async {
    if (dispose) {
      for (final element in allClasses) {
        await element.dispose();
      }
    }
    factoriesByName.clear();
  }

  List<_ServiceClass> get allClasses => factoriesByName.values
      .fold<List<_ServiceClass>>([], (sum, x) => sum..addAll(x.values));

  Future<void> dispose() async {
    await disposeFunc?.call();
  }
}

class _ReflectionClassImplementation implements ReflectionClass {
  static const _baseScopeName = 'reflectionBaseScope';
  final _scopes = [_Scope(name: _baseScopeName)];

  _Scope get _currentScope => _scopes.last;

  @override
  void Function(bool pushed)? onScopeChanged;

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  @override
  bool allowReassignment = true;

  /// Is used by several other functions to retrieve the correct [_ServiceClass]
  _ServiceClass<T, dynamic>?
      _findFirstClassByNameAndTypeOrNull<T extends Object>(String? instanceName,
          {Type? type, bool lookInScopeBelow = false}) {
    /// We use an assert here instead of an `if..throw` because it gets called on every call
    /// of [get]
    /// `(const Object() is! T)` tests if [T] is a real type and not Object or dynamic
    assert(
      type != null || const Object() is! T,
      'ReflectionClass: The compiler could not infer the type. You have to provide a type '
      'and optionally a name. Did you accidentally do `var sl=ReflectionClass.instance();` '
      'instead of var sl=ReflectionClass.instance;',
    );

    _ServiceClass<T, dynamic>? instanceFactory;

    int scopeLevel = _scopes.length - (lookInScopeBelow ? 2 : 1);

    while (instanceFactory == null && scopeLevel >= 0) {
      final factoryByTypes = _scopes[scopeLevel].factoriesByName[instanceName];
      if (type == null) {
        instanceFactory = factoryByTypes != null
            ? factoryByTypes[T] as _ServiceClass<T, dynamic>?
            : null;
      } else {
        /// in most cases we can rely on the generic type T because it is passed
        /// in by callers. In case of dependent types this does not work as these types
        /// are dynamic
        instanceFactory = factoryByTypes != null
            ? factoryByTypes[type] as _ServiceClass<T, dynamic>?
            : null;
      }
      scopeLevel--;
    }

    return instanceFactory;
  }

  /// Is used by several other functions to retrieve the correct [_ServiceClass]
  _ServiceClass _findClassByNameAndType<T extends Object>(
    String? instanceName, [
    Type? type,
  ]) {
    final instanceFactory =
        _findFirstClassByNameAndTypeOrNull<T>(instanceName, type: type);

    assert(
      instanceFactory != null,
      'Object/factory with ${instanceName != null ? 'with name $instanceName and ' : ''}'
      'type ${T.toString()} is not registered inside ReflectionClass. '
      '\n(Did you accidentally do ReflectionClass sl=ReflectionClass.instance(); instead of ReflectionClass sl=ReflectionClass.instance;'
      '\nDid you forget to register it?)',
    );

    return instanceFactory!;
  }

  /// Creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// you can pass parameters in [param], [param] is dynamic type
  /// given at registration with [registerClassWithParam()]
  @override
  T createObject<T extends Object>({
    String? instanceName,
    dynamic param,
  }) {
    final instanceFactory = _findClassByNameAndType<T>(instanceName);

    Object instance = instanceFactory.getObject(param);

    assert(
      instance is T,
      'Object with name $instanceName has a different type '
      '(${instanceFactory.registrationType.toString()}) than the one that is inferred '
      '(${T.toString()}) where you call it',
    );

    return instance as T;
  }

  /// Callable class so that you can write `ReflectionClass.instance<MyType>` instead of
  /// `ReflectionClass.instance.get<MyType>`
  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param,
  }) {
    return createObject<T>(instanceName: instanceName, param: param);
  }

  /// Method for registeration a type, when you need new instance of registeration class you
  /// should call [createObject] or execute callable class on that type
  /// [T] type to register
  /// [ClassFunc] class function for this type
  /// If [instanceName] != null your class gets registered with that
  /// name. You will provide value of [instanceName] only when you need to register more
  /// than one instance of one type.
  @override
  void registerClass<T extends Object>(
    ClassFunc<T> classFunc, {
    String? instanceName,
  }) {
    _register<T, void>(
      instanceName: instanceName,
      classFunc: classFunc,
    );
  }

  /// Method for registeration a type, when you need new instance of registeration class you
  /// should call [createObject] or execute callable class on that type
  /// [T] type to register
  /// [ClassFunc] class function for this type that accept [PARAM]
  /// If [instanceName] != null your class gets registered with that
  /// name. You will provide value of [instanceName] only when you need to register more
  /// than one instance of one type.
  /// ### Example:
  ///'''dart
  ///    ReflectionClass.registerClassWithParam<TestClassParam,String>((s)
  ///        => TestClassParam(param:s));
  ///'''
  @override
  void registerClassWithParam<T extends Object, PARAM>(
    ClassFuncParam<T, PARAM> classFunc, {
    String? instanceName,
  }) {
    _register<T, PARAM>(
      instanceName: instanceName,
      classFuncParam: classFunc,
    );
  }

  /// Clears all registered types. Handy when writing unit tests.
  @override
  Future<void> reset({bool dispose = true}) async {
    if (dispose) {
      for (int level = _scopes.length - 1; level >= 0; level--) {
        await _scopes[level].dispose();
        await _scopes[level].reset(dispose: dispose);
      }
    }
    _scopes.removeRange(1, _scopes.length);
    await resetScope(dispose: dispose);
  }

  /// Clears all registered types of the current scope.
  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) {
      await _currentScope.dispose();
    }
    await _currentScope.reset(dispose: dispose);
  }

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  @override
  void pushNewScope(
      {void Function(ReflectionClass reflectionClass)? init,
      String? scopeName,
      ScopeDisposeFunc? dispose}) {
    assert(scopeName != _baseScopeName,
        'This name is reserved for the real base scope.');
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have used the scope name $scopeName',
    );
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    init?.call(this);
    onScopeChanged?.call(true);
  }

  /// Disposes all factories/Singletons that have been registered in this scope
  /// and pops (destroys) the scope so that the previous scope gets active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is popped.
  /// As dispose functions can be async, you should await this function.
  @override
  Future<void> popScope() async {
    throwIfNot(
        _scopes.length > 1,
        StateError(
            "ReflectionClass: You are already on the base scope. you can't pop this one"));
    await _currentScope.dispose();
    await _currentScope.reset(dispose: true);
    _scopes.removeLast();
    onScopeChanged?.call(false);
  }

  /// if you have a lot of scopes with names you can pop (see [popScope]) all scopes above
  /// the scope with [scopeName] including that scope
  /// Scopes are popped in order from the top
  /// As dispose functions can be async, you should await this function.
  @override
  Future<bool> popScopesTill(String scopeName, {bool inclusive = true}) async {
    assert(scopeName != _baseScopeName, "You can't pop the base scope");
    if (_scopes.firstWhereOrNull((x) => x.name == scopeName) == null) {
      return false;
    }
    String? poppedScopeName;
    do {
      poppedScopeName = _currentScope.name;
      await popScope();
    } while (inclusive
        ? (poppedScopeName != scopeName)
        : (_currentScope.name != scopeName));
    onScopeChanged?.call(false);
    return true;
  }

  @override
  String? get currentScopeName => _currentScope.name;

  void _register<T extends Object, PARAM>({
    ClassFunc<T>? classFunc,
    ClassFuncParam<T, PARAM>? classFuncParam,
    T? instance,
    required String? instanceName,
    Iterable<Type>? dependsOn,
    DisposingFunc<T>? disposeFunc,
  }) {
    throwIfNot(
      const Object() is! T,
      'ReflectionClass: You have to provide type. Did you accidentally do `var sl=ReflectionClass.instance();` '
      'instead of var sl=ReflectionClass.instance;',
    );

    final factoriesByName = _currentScope.factoriesByName;
    throwIf(
      factoriesByName.containsKey(instanceName) &&
          factoriesByName[instanceName]!.containsKey(T) &&
          !allowReassignment,
      ArgumentError(
        // ignore: missing_whitespace_between_adjacent_strings
        'Object/factory with ${instanceName != null ? 'with name $instanceName and ' : ''}'
        'type ${T.toString()} is already registered inside ReflectionClass. ',
      ),
    );

    if (instance != null) {
      /// check if we are shadowing an existing Object
      final classThatWouldbeShadowed =
          _findFirstClassByNameAndTypeOrNull(instanceName, type: T);

      final objectThatWouldbeShadowed = classThatWouldbeShadowed?.instance;
      if (objectThatWouldbeShadowed != null &&
          objectThatWouldbeShadowed is ShadowHandler) {
        objectThatWouldbeShadowed.onGetShadowed(instance);
      }
    }

    final serviceClass = _ServiceClass<T, PARAM>(
      this,
      registrationScope: _currentScope,
      creationFunction: classFunc,
      creationFunctionParam: classFuncParam,
      instance: instance,
      instanceName: instanceName,
      disposeFunction: disposeFunc,
    );

    factoriesByName.putIfAbsent(
      instanceName,
      () => <Type, _ServiceClass<Object, dynamic>>{},
    );
    factoriesByName[instanceName]![T] = serviceClass;
  }

  /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
  /// is registered inside ReflectionClass
  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
  }) {
    if (instance != null) {
      return _findFirstClassByInstanceOrNull(instance) != null;
    } else {
      return _findFirstClassByNameAndTypeOrNull<T>(instanceName) != null;
    }
  }

  /// Unregister an instance of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides an instance of your class to be disposed
  @override
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) async {
    final classToRemove = instance != null
        ? _findClassByInstance(instance)
        : _findClassByNameAndType<T>(instanceName);

    classToRemove.registrationScope.factoriesByName[classToRemove.instanceName]!
        .remove(classToRemove.registrationType);

    if (classToRemove.instance != null) {
      if (disposingFunction != null) {
        final dispose = disposingFunction.call(classToRemove.instance as T);
        if (dispose is Future) {
          await dispose;
        }
      } else {
        final dispose = classToRemove.dispose();
        if (dispose is Future) {
          await dispose;
        }
      }
    }
  }

  List<_ServiceClass> get _allClasses {
    return _scopes.fold<List<_ServiceClass>>(
      [],
      (sum, x) => sum..addAll(x.allClasses),
    );
  }

  _ServiceClass? _findFirstClassByInstanceOrNull(Object instance) {
    final registeredClasses =
        _allClasses.where((x) => identical(x.instance, instance));
    return registeredClasses.isEmpty ? null : registeredClasses.first;
  }

  _ServiceClass _findClassByInstance(Object instance) {
    final registeredClass = _findFirstClassByInstanceOrNull(instance);

    throwIf(
      registeredClass == null,
      StateError(
          'This instance of the type ${instance.runtimeType} is not available in ReflectionClass'),
    );

    return registeredClass!;
  }
}
