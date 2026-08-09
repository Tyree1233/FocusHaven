import 'package:flutter/material.dart';

/// A single benefit row displayed in the FocusHaven Pro sheet.
class ProBenefit extends StatelessWidget {
  const ProBenefit({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}
