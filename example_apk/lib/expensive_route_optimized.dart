// Better version.

import 'package:example_apk/expensive_route.dart' as unoptimized;
import 'package:flutter/material.dart';

/// A somewhat optimized version of [ExpensiveRoute].
class ExpensiveRouteOptimized extends StatelessWidget {
  const ExpensiveRouteOptimized({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Dogs'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Image.asset(
              key: Key('dog_photo'),
              'assets/bond+friend.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: unoptimized.itemCount,
              itemBuilder: (c, i) => _ExpensiveItem(index: i),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row of the [ExpensiveRouteOptimized]'s list: its own index, followed by
/// ten Text widgets counting from 1 to 10.
class _ExpensiveItem extends StatelessWidget {
  final int index;

  const _ExpensiveItem({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '#$index',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('1'),
                Text('2'),
                Text('3'),
                Text('4'),
                Text('5'),
                Text('6'),
                Text('7'),
                Text('8'),
                Text('9'),
                Text('10'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
