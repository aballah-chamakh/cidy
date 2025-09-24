import 'package:flutter/material.dart';
import '../models/sidebar_menu_item.dart';
import 'package:cidy/config.dart';

class ProfileSidebar extends StatelessWidget {
  final String email;
  final String fullName;
  final String imageUrl;
  final List<SidebarMenuItem> menuItems; // everything except logout
  final VoidCallback onLogout;
  final VoidCallback onClose;
  final int notificationCount;

  const ProfileSidebar({
    super.key,
    required this.email,
    required this.fullName,
    required this.imageUrl,
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
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
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
                      backgroundImage: NetworkImage(
                        Config.backendUrl + imageUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: Icon(item.icon),
                title: Row(
                  children: [
                    Text(item.label),
                    if (item.label == "Notifications")
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Container(
                          padding: const EdgeInsets.only(
                            right: 12,
                            left: 12,
                            top: 2,
                            bottom: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '${notificationCount > 99 ? '+99' : notificationCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              ),
            ),

            const Spacer(),
            // Fixed logout item
            ListTile(
              iconColor: Colors.white,
              textColor: Colors.white,
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
