library reflection_class;

import 'dart:async';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;

part 'reflection_class_impl.dart';

/// If your singleton that you register wants to use the manually signalling
/// of its ready state, it can implement this interface class instead of using
/// the [signalsReady] parameter of the registration functions
/// (you don't really have to implement much ;-) )
abstract class WillSignalReady {}

/// If an object implements the [ShadowChangeHandler] if will get notified if
/// an Object with the same registration type and name is registered on a
/// higher scope which will shadow it.
/// It also will get notified if the shadowing object is removed from ReflectionClass
///
/// This can be helpful to unsubscribe / resubscribe from Streams or Listenables
abstract class ShadowChangeHandlers {
  void onGetShadowed(Object shadowing);
  void onLeaveShadow(Object shadowing);
}

/// If objects that are registered inside ReflectionClass implements [Disposable] the
/// [onDispose] method will be called whenever that Object is unregistered,
/// resetted or its enclosing Scope is popped
abstract class Disposable {
  FutureOr onDispose();
}

/// Signature of the class function used by non async factories
typedef ClassFunc<T> = T Function();

/// For Factories that expect up to two parameters if you need only one use `void` for the one
/// you don't use
typedef ClassFuncParam<T, PARAM> = T Function(
  PARAM param,
);

/// Signature for disposing function
/// because closures like `(x){}` have a return type of Null we don't use `FutureOr<void>`
typedef DisposingFunc<T> = FutureOr Function(T param);

/// Signature for disposing function on scope level
typedef ScopeDisposeFunc = FutureOr Function();

/// Data structure used to identify a dependency by type and instanceName
class InitDependency implements Type {
  final Type type;
  final String? instanceName;

  InitDependency(this.type, {this.instanceName});

  @override
  String toString() => "InitDependency(type:$type, instanceName:$instanceName)";
}

class WaitingTimeOutException implements Exception {
  /// In case of a timeout while waiting for an instance to get ready
  /// This exception is thrown with information about who is still waiting.
  ///
  /// If you pass the [callee] parameter to [isReady], or define dependent Singletons
  /// this maps lists which callees are waiting for whom.
  final Map<String, List<String>> areWaitedBy;

  /// Lists with Types that are still not ready.
  final List<String> notReadyYet;

  /// Lists with Types that are already ready.
  final List<String> areReady;

  WaitingTimeOutException(
    this.areWaitedBy,
    this.notReadyYet,
    this.areReady,
  );

  // todo : assert(areWaitedBy != null && notReadyYet != null && areReady != null);

  @override
  String toString() {
    // ignore: avoid_print
    print(
        'ReflectionClass: There was a timeout while waiting for an instance to signal ready');
    // ignore: avoid_print
    print('The following instance types where waiting for completion');
    for (final entry in areWaitedBy.entries) {
      // ignore: avoid_print
      print('${entry.value} is waiting for ${entry.key}');
    }
    // ignore: avoid_print
    print('The following instance types have NOT signalled ready yet');
    for (final entry in notReadyYet) {
      // ignore: avoid_print
      print(entry);
    }
    // ignore: avoid_print
    print('The following instance types HAVE signalled ready yet');
    for (final entry in areReady) {
      // ignore: avoid_print
      print(entry);
    }
    return super.toString();
  }
}

/// Very simple and easy to use service locator
/// You register your object creation factory or an instance of an object with [registerClass]
/// And retrieve the desired object using [get] or call your locator as function as its a
/// callable class
/// Additionally [ReflectionClass] offers asynchronous creation functions as well as functions to synchronize
/// the async initialization of multiple Singletons
abstract class ReflectionClass {
  static final ReflectionClass _instance = _ReflectionClassImplementation();

  /// Optional call-back that will get call whenever a change in the current scope happens
  /// This can be very helpful to update the UI in such a case to make sure it uses
  /// the correct Objects after a scope change
  /// The ReflectionClass_mixin has a matching `rebuiltOnScopeChange` method
  void Function(bool pushed)? onScopeChanged;

  /// access to the Singleton instance of ReflectionClass
  static ReflectionClass get instance => _instance;

  /// If you need more than one instance of ReflectionClass you can use [asNewInstance()]
  /// You should prefer to use the `instance()` method to access the global instance of [ReflectionClass].
  factory ReflectionClass.asNewInstance() {
    return _ReflectionClassImplementation();
  }

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  T createObject<T extends Object>({
    String? instanceName,
    dynamic param,
  });

  /// retrieves or creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// for factories you can pass up to 2 parameters [param,param2] they have to match the types
  /// given at registration with [registerClassWithParam()]
  T get<T extends Object>({
    String? instanceName,
    dynamic param,
  });

  /// Callable class so that you can write `ReflectionClass.instance<MyType>` instead of
  /// `ReflectionClass.instance.get<MyType>`
  T call<T extends Object>({
    String? instanceName,
    dynamic param,
  });

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [ClassFunc] class function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended.
  void registerClass<T extends Object>(
    ClassFunc<T> classFunc, {
    String? instanceName,
  });

  /// registers a type so that a new instance will be created on each call of [get] on that type
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
  ///
  ///    ReflectionClass.registerClassWithParam<TestClassParam,String>((s)
  ///        => TestClassParam(param:s);
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

  /// returns a Future that completes if all asynchronously created Singletons and any
  /// Singleton that had [signalsReady==true] are ready.
  /// This can be used inside a FutureBuilder to change the UI as soon as all initialization
  /// is done
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if not all Singletons
  /// were ready in the given time. The Exception contains details on which Singletons are not
  /// ready yet. if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  });

  /// Returns a Future that completes if the instance of a Singleton, defined by Type [T] or
  /// by name [instanceName] or by passing an existing [instance], is ready
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  });

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready without waiting
  bool isReadySync<T extends Object>({
    Object? instance,
    String? instanceName,
  });

  /// Returns if all async Singletons are ready without waiting
  /// if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  // ignore: avoid_positional_boolean_parameters
  bool allReadySync([bool ignorePendingAsyncCreation = false]);

  /// Used to manually signal the ready state of a Singleton.
  /// If you want to use this mechanism you have to pass [signalsReady==true] when registering
  /// the Singleton.
  /// If [instance] has a value ReflectionClass will search for the responsible Singleton
  /// and completes all futures that might be waited for by [isReady]
  /// If all waiting singletons have signalled ready the future you can get
  /// from [allReady] is automatically completed
  ///
  /// Typically this is used in this way inside the registered objects init
  /// method `ReflectionClass.instance.signalReady(this);`
  ///
  /// if [instance] is `null` and no factory/singleton is waiting to be signalled this
  /// will complete the future you got from [allReady], so it can be used to globally
  /// giving a ready Signal
  ///
  /// Both ways are mutually exclusive, meaning either only use the global `signalReady()` and
  /// don't register a singleton to signal ready or use any async registrations
  ///
  /// Or use async registrations methods or let individual instances signal their ready
  /// state on their own.
  void signalReady(Object? instance);
}
