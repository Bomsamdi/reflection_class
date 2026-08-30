import 'package:flutter/material.dart';
import 'package:reflection_class/reflection_class.dart';

/// A plain model with no annotations, no generated code and no base class.
class Product {
  Product({required this.name, required this.price, this.inStock = true});

  String name;
  double price;
  bool inStock;

  /// Not writable, so the editor shows it read-only.
  String get label => '$name (${price.toStringAsFixed(2)} zl)';

  void applyDiscount(double percent) => price = price * (1 - percent / 100);
}

/// Declared once. From here the members are reachable by name.
final ClassMirror<Product> productMirror = ClassMirror<Product>(
  constructor: (Map<String, Object?> args) => Product(
    name: args['name']! as String,
    price: (args['price']! as num).toDouble(),
    inStock: (args['inStock'] as bool?) ?? true,
  ),
  properties: <PropertyMirror<Product>>[
    PropertyMirror<Product>(
      'name',
      type: String,
      get: (Product p) => p.name,
      set: (Product p, Object? v) => p.name = v! as String,
    ),
    PropertyMirror<Product>(
      'price',
      type: double,
      get: (Product p) => p.price,
      set: (Product p, Object? v) => p.price = (v! as num).toDouble(),
    ),
    PropertyMirror<Product>(
      'inStock',
      type: bool,
      get: (Product p) => p.inStock,
      set: (Product p, Object? v) => p.inStock = v! as bool,
    ),
    PropertyMirror<Product>('label', type: String, get: (Product p) => p.label),
  ],
  methods: <MethodMirror<Product>>[
    MethodMirror<Product>(
      'applyDiscount',
      invoke: (Product p, List<Object?> args, Map<String, Object?> named) =>
          p.applyDiscount((args.first! as num).toDouble()),
    ),
  ],
);

void main() {
  Reflector.instance.register<Product>(productMirror);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'reflection_class example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Product _product = Reflector.instance.create<Product>(<String, Object?>{
    'name': 'Coffee beans',
    'price': 42.0,
  });

  /// The editor below is built from the mirror, not from the Product class:
  /// it would work the same for any registered type.
  ClassMirror<Object> get _mirror => Reflector.instance.mirrorFor(_product)!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('reflection_class')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Editor generated from ${_mirror.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final PropertyMirror<Object> property in _mirror.properties)
            _PropertyRow(
              property: property,
              instance: _product,
              onChanged: () => setState(() {}),
            ),
          const Divider(height: 32),
          Text('Methods', style: Theme.of(context).textTheme.titleMedium),
          for (final String method in _mirror.methodNames)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton(
                onPressed: () => setState(() {
                  Reflector.instance.invoke(
                    _product,
                    method,
                    positionalArguments: <Object?>[10],
                  );
                }),
                child: Text('$method(10)'),
              ),
            ),
          const Divider(height: 32),
          Text('toMap()', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(Reflector.instance.toMap(_product).toString()),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.property,
    required this.instance,
    required this.onChanged,
  });

  final PropertyMirror<Object> property;
  final Object instance;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Object? value = property.read(instance);

    if (property.isReadOnly) {
      return ListTile(
        title: Text(property.name),
        subtitle: Text('$value'),
        trailing: const Icon(Icons.lock_outline, size: 18),
      );
    }
    if (value is bool) {
      return SwitchListTile(
        title: Text(property.name),
        value: value,
        onChanged: (bool next) {
          Reflector.instance.setField(instance, property.name, next);
          onChanged();
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(
          labelText: property.name,
          helperText: '${property.type}',
        ),
        onChanged: (String text) {
          final Object? parsed = property.type == double
              ? double.tryParse(text)
              : text;
          if (parsed == null) return;
          Reflector.instance.setField(instance, property.name, parsed);
          onChanged();
        },
      ),
    );
  }
}
