// DO NOT OPTIMIZE THIS FILE.
//
// This route is a benchmark fixture. It is deliberately expensive: nothing is
// const, the ListView builds all 1000 of its items eagerly, and every item
// holds a fresh row of Text widgets. Making it faster would invalidate every
// .benchmark baseline recorded from this app.
//
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';

/// The number of items built eagerly by the [ExpensiveRoute]'s list.
const int itemCount = 1000;

/// A deliberately unoptimized route, used as a measurable workload.
class ExpensiveRoute extends StatelessWidget {
  const ExpensiveRoute({super.key});

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
            child: ListView(
              children: [
                for (var i = 1; i <= itemCount; i++) _ExpensiveItem(index: i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row of the [ExpensiveRoute]'s list: its own index, followed by
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
