import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Import your screens
import 'studio_list_screen.dart';
import 'my_bookings_screen.dart';
import 'edit_profile_screen.dart';

class UserDashboardScreen extends StatelessWidget {
  const UserDashboardScreen({super.key});

  /// 🔹 Fetch current user profile from Firestore
  Stream<DocumentSnapshot> _userProfileStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  /// 🔹 Profile bottom sheet
  void _showProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _userProfileStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;

            if (data == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Profile data not found'),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _profileRow('Name', data['fullName']),
                  _profileRow('Email', data['email']),
                  _profileRow('Phone', data['phone']),
                  _profileRow('Address', data['address']),
                  if ((data['companyOrArtistName'] ?? '').isNotEmpty)
                    _profileRow(
                      'Company / Artist',
                      data['companyOrArtistName'],
                    ),

                  const SizedBox(height: 24),

                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),

      /// 🧩 MAIN CONTENT
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// 🎵 STUDIOS
            _dashboardCard(
              context,
              title: 'Studios',
              icon: Icons.music_note,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudioListScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            /// 📅 MY BOOKINGS
            _dashboardCard(
              context,
              title: 'My Bookings',
              icon: Icons.calendar_today,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyBookingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      /// 👤 PROFILE BUTTON (BOTTOM RIGHT)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.person),
        onPressed: () => _showProfile(context),
      ),
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
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
