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
        title: const Text('Dogs'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: Image.asset(
              key: const Key('dog_photo'),
              'assets/bond+friend-smaller.jpg',
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

/// A single row of the [ExpensiveRoute]'s list: its own index, followed by
/// ten Text widgets counting from 1 to 10.
/// Every 10th element is an image.
class _ExpensiveItem extends StatelessWidget {
  final int index;

  const _ExpensiveItem({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: (index % 10 == 0)
          ? SizedBox(
              height: 100,
              child: Image.asset(
                'assets/bond+friend-smaller.jpg',
                fit: BoxFit.cover,
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '#$index',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [for (var n = 1; n <= 10; n++) Text('$n')],
                  ),
                ),
              ],
            ),
    );
  }
}
