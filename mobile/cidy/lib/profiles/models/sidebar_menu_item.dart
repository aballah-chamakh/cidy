import 'package:flutter/material.dart';

class SidebarMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
