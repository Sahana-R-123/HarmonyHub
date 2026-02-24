import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        //backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _adminCard(
              context,
              title: 'Add Studio',
              icon: Icons.add_business,
              onTap: () {
                Navigator.pushNamed(context, '/admin/add-studio');
              },
            ),
            const SizedBox(height: 16),

            _adminCard(
              context,
              title: 'View Studios',
              icon: Icons.music_note,
              onTap: () {
                Navigator.pushNamed(context, '/admin/studios');
              },
            ),
            const SizedBox(height: 16),

            /// ✅ NEW: VIEW BOOKINGS
            _adminCard(
              context,
              title: 'View Bookings',
              icon: Icons.event_note,
              onTap: () {
                Navigator.pushNamed(context, '/admin/bookings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: Colors.blue),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
