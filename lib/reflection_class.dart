library reflection_class;

//  Created by Bomsamdi on 2023
//  Copyright © 2023 Bomsamdi. All rights reserved.

import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;

part 'reflection_class_impl.dart';

/// [ShadowHandler] helps to hendle when
/// an Object with the same registration type and name is registered on a
/// higher scope which will shadow it.
abstract class ShadowHandler {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}

/// If objects that are registered inside ReflectionClass implements [Disposable] the
/// [onDispose] method will be called whenever that Object is unregistered,
/// resetted or its enclosing Scope is popped
abstract class Disposable {
  FutureOr onDispose();
}

/// Class function used by class constructors without params
typedef ClassFunc<T> = T Function();

/// Class function used by class constructors with params
typedef ClassFuncParam<T, PARAM> = T Function(
  PARAM param,
);

/// Disposing function signature
typedef DisposingFunc<T> = FutureOr Function(T param);

/// Disposing function signature on scope level
typedef ScopeDisposeFunc = FutureOr Function();

/// You register your classes with [registerClass]
/// And retrieve the desired object using [createObject] or call your locator as function as its a
/// callable class
abstract class ReflectionClass {
  static final ReflectionClass _instance = _ReflectionClassImplementation();

  /// Optional call-back that will get call whenever a change in the current scope happens
  /// This can be very helpful to update the UI in such a case to make sure it uses
  /// the correct Objects after a scope change
  /// The ReflectionClass_mixin has a matching `rebuiltOnScopeChange` method
  void Function(bool pushed)? onScopeChanged;

  /// access to the Singleton instance of ReflectionClass
  static ReflectionClass get instance => _instance;

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// for constructors that have params you can pass it in [param] they have to match the types
  /// given at registration with [registerClassWithParam()]
  T createObject<T extends Object>({
    String? instanceName,
    dynamic param,
  });

  /// Callable class so that you can write `ReflectionClass.instance<MyType>` instead of
  /// `ReflectionClass.instance.createObject<MyType>`
  T call<T extends Object>({
    String? instanceName,
    dynamic param,
  });

  /// registers a type so that a new instance will be created on each call of [createObject] on that type
  /// [T] type to register
  /// [ClassFunc] class function for this type
  /// [instanceName] if you provide a value here your class gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended.
  void registerClass<T extends Object>(
    ClassFunc<T> classFunc, {
    String? instanceName,
  });

  /// registers a type so that a new instance will be created on each call of [createObject] on that type
  /// based on up to two parameters provided to [get()]
  /// [T] type to register
  /// [PARAM] type of param
  /// if you use only one parameter pass void here
  /// [ClassFunc] class function for this type that accepts two parameters
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended.
  ///
  /// example:
  ///    ReflectionClass.registerClassWithParam<TestClassParam,String>((s)
  ///        => TestClassParam(param:s));
  void registerClassWithParam<T extends Object, PARAM>(
    ClassFuncParam<T, PARAM> classFunc, {
    String? instanceName,
  });

  /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
  /// is registered inside ReflectionClass
  bool isRegistered<T extends Object>({Object? instance, String? instanceName});

  /// Clears all registered types. Handy when writing unit tests
  /// If you provided dispose function when registering they will be called
  /// [dispose] if `false` it only resets without calling any dispose
  /// functions
  /// As dispose functions can be async, you should await this function.
  Future<void> reset({bool dispose = true});

  /// Clears all registered types for the current scope
  /// If you provided dispose function when registering they will be called
  /// [dispose] if `false` it only resets without calling any dispose
  /// functions
  /// As dispose functions can be async, you should await this function.
  Future<void> resetScope({bool dispose = true});

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  void pushNewScope({
    void Function(ReflectionClass reflectionClass)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  });

  /// Disposes all factories/Singletons that have been registered in this scope
  /// and pops (destroys) the scope so that the previous scope gets active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is popped.
  /// As dispose functions can be async, you should await this function.
  Future<void> popScope();

  /// if you have a lot of scopes with names you can pop (see [popScope]) all
  /// scopes above the scope with [name] including that scope unless [inclusive]= false
  /// Scopes are popped in order from the top
  /// As dispose functions can be async, you should await this function.
  /// If no scope with [name] exists, nothing is popped and `false` is returned
  Future<bool> popScopesTill(String name, {bool inclusive = true});

  /// Returns the name of the current scope if it has one otherwise null
  /// if you are already on the baseScope it returns 'baseScope'
  String? get currentScopeName;

  /// Unregister an [instance] of an object or a factory/singleton by Type [T] or by name
  /// [instanceName] if you need to dispose any resources you can do it using
  /// [disposingFunction] function that provides an instance of your class to be disposed.
  /// This function overrides the disposing you might have provided when registering.
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  });
}
