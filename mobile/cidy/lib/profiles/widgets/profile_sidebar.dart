import 'package:flutter/material.dart';
import '../models/sidebar_menu_item.dart';

class ProfileSidebar extends StatelessWidget {
  final String fullName;
  final String profileImageUrl;
  final List<SidebarMenuItem> menuItems; // everything except logout
  final VoidCallback onLogout;
  final VoidCallback onClose;
  final int notificationCount;

  const ProfileSidebar({
    super.key,
    required this.fullName,
    required this.profileImageUrl,
    required this.menuItems,
    required this.onLogout,
    required this.onClose,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).primaryColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: close button
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: onClose,
              ),
            ),

            // Row 2: profile section
            InkWell(
              onTap: () {
                Navigator.pop(context); // close drawer
                // Navigate to account screen if you like
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(profileImageUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Dynamic menu items
            ...menuItems.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              ),
            ),
            const Spacer(),
            // Fixed logout item
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
