import 'package:flutter/material.dart';
import 'package:reflection_class/reflection_class.dart';

void main() {
  ReflectionClass.instance.registerClassWithParam<Example, int>(
      (param) => Example(a: param),
      instanceName: "example");
  ReflectionClass.instance.registerClassWithParam<Example, int>(
      (param) => Example.test(param),
      instanceName: "exampleTest");

  ReflectionClass.instance.registerClass<Example2>(
    () => Example2(),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    Example a = ReflectionClass.instance
        .createObject<Example>(param: 1, instanceName: "example");
    print(a.a);
    Example b = ReflectionClass.instance
        .createObject<Example>(param: 1, instanceName: "exampleTest");
    print(b.a);
    Example2 e = ReflectionClass.instance.createObject<Example2>();
    print(e);
    Example2 g = ReflectionClass.instance<Example2>();
    print(g);
    Example3 example3 = Example3(example: Example(a: 1), example2: Example2());
    print(example3<Example>().a);
    print(example3("test"));
    print(example3("test2"));
    print(example3<Example3>());
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class Example {
  final int a;
  Example({required this.a});
  Example.test(int x) : a = x * 10;
}

class Example2 {}

class Example3 with Callable {
  final Example2 example2;
  final Example example;
  String test = "TEST";

  @override
  Map<String, dynamic> get callableProperties => {
        'example': example,
        'example2': example2,
        'test': test,
      };

  Example3({
    required this.example,
    required this.example2,
  });
}

abstract class Callable {
  Map<String, dynamic> get callableProperties;

  call<T extends Object>([dynamic name]) {
    if (name != null) {
      return callableProperties[name];
    }
    return callableProperties.values.firstWhere(
      (element) => element.runtimeType == T,
      orElse: () => null,
    );
  }
}
