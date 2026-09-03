import 'package:flutter/material.dart';
import 'package:pos/themes/styles/styles.dart';

class CustomLeftDrawer extends StatelessWidget {
  final List<String> items;
  final List<VoidCallback> onItemTap;

  const CustomLeftDrawer({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      items.length == onItemTap.length,
      'items and onItemTap lists must have the same length',
    );

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Center(
              child: Text(
                'Actions',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    items[index],
                    style: Styles.labelTextStyle,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onItemTap[index]();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
