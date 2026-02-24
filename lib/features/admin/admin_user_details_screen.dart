import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminUserDetailsScreen extends StatelessWidget {
  final String userId;

  const AdminUserDetailsScreen({
    super.key,
    required this.userId,
  });

  String _date(Timestamp ts) =>
      DateFormat('dd MMM yyyy').format(ts.toDate());

  String _time(Timestamp ts) =>
      DateFormat('hh:mm a').format(ts.toDate());

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  /// 🔹 Fetch studio name
  Future<String> _fetchStudioName(String studioId) async {
    final doc = await FirebaseFirestore.instance
        .collection('studios')
        .doc(studioId)
        .get();

    return doc.data()?['name'] ?? 'Unknown Studio';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        //backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final user = userSnap.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              /// 👤 PROFILE CARD
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['fullName'] ?? 'Unknown User', // ✅ FIXED
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${user['email'] ?? '-'}'),
                      Text('Phone: ${user['phone'] ?? '-'}'),
                      
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Booking History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              /// 📋 BOOKING HISTORY
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('bookings')
                      .where('userId', isEqualTo: userId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = snap.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('No bookings found'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data =
                            doc.data() as Map<String, dynamic>;

                        final status = data['status'] ?? 'pending';

                        /// 🔹 Extract studioId from path
                        final studioId =
                            doc.reference.parent.parent!.id;

                        return FutureBuilder<String>(
                          future: _fetchStudioName(studioId),
                          builder: (context, studioSnap) {
                            final studioName =
                                studioSnap.data ?? 'Loading studio...';

                            return Card(
                              elevation: 3,
                              margin:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studioName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        //color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_date(data['date'])} • '
                                      '${_time(data['startTime'])} - ${_time(data['endTime'])}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Purpose: ${data['purpose'] ?? '-'}'),
                                    Text('Genre: ${data['genre'] ?? '-'}'),
                                    Text(
                                        'People: ${data['numberOfPeople'] ?? '-'}'),
                                    const SizedBox(height: 8),
                                    Chip(
                                      label:
                                          Text(status.toUpperCase()),
                                      backgroundColor:
                                          _statusColor(status)
                                              .withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
