# ReflectionClass

[![Pub Version](https://img.shields.io/pub/v/reflection_class)](https://pub.dev/packages/reflection_class)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![pub points](https://img.shields.io/pub/points/reflection_class)](https://pub.dev/packages/reflection_class/score) 
[![popularity](https://img.shields.io/pub/popularity/reflection_class)](https://pub.dev/packages/reflection_class/score)

A Flutter package that provides a pseudo reflection alternative for the missing reflection mechanism in Flutter. The package is based on registering a class at the start of the application, allowing the creation of objects of this class without using a constructor, similar to the reflection idea.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  reflection_class: ^0.0.1
```

## Usage
1. Register the class at the start of your application:

import 'package:reflection_class/reflection_class.dart';

```dart
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
```

2. Create objects of the registered class without using a constructor:

```dart
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
```

3. Full example:

```dart
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

```

## Features

* Pseudo reflection alternative for Flutter.
* Register a class at the start of the application.
* Create objects of the registered class without using a constructor.

## Issues and Bugs

Report any issues or bugs on the GitHub issues page.

## License

This package is licensed under the MIT License.

## Support

For any questions or assistance, please contact the author.
