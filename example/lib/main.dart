import 'package:flutter/material.dart';
import 'package:reflection_class/reflection_class.dart';

void main() {
  ReflectionClass.instance
      .registerClassWithParam<Example, Map<String, dynamic>>(
    (param) => Example.fromJson(param),
  );

  ReflectionClass.instance.registerClass<Example2>(
    () => Example2(),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReflectionClass Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'ReflectionClass Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Example example;
  late Example example2;
  @override
  void initState() {
    super.initState();
    Map<String, dynamic> jsonMap = {
      'name': 'John Doe',
      'age': 25,
    };
    Map<String, dynamic> jsonMap2 = {
      'name': 'Sophie Evans',
      'age': 21,
    };
    example = ReflectionClass.instance.get<Example>(param: jsonMap);
    example2 = ReflectionClass.instance.get<Example>(param: jsonMap2);
    Example2 e = ReflectionClass.instance.createObject<Example2>();
    print(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(example()),
            Text(example2.toString()),
          ],
        ),
      ),
    );
  }
}

class Example {
  final String? name;
  final int? age;
  Example({
    this.name,
    this.age,
  });

  factory Example.fromJson(Map<String, dynamic> json) => Example(
        name: json["name"],
        age: json["age"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "age": age,
      };

  call() => 'Name: $name, Age: $age';

  @override
  String toString() => 'Example(name: $name, age: $age)';
}

class Example2 {}
