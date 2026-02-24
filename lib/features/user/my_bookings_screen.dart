import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'BookingBillScreen.dart';

// 👇 IMPORT YOUR EDIT SCREEN
import 'EditBookingScreen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  String formatTime(dynamic ts) {
    if (ts == null) return '--';
    return DateFormat('hh:mm a').format((ts as Timestamp).toDate());
  }

  String formatDate(dynamic ts) {
    if (ts == null) return '--';
    return DateFormat('dd MMM yyyy').format((ts as Timestamp).toDate());
  }

  /// 🔹 Fetch studio name

Future<String> fetchStudioName(String studioId) async {
  final doc = await FirebaseFirestore.instance
      .collection('studios')
      .doc(studioId)
      .get();

  return doc.data()?['name'] ?? 'Unknown Studio';
}
/// 🔹 Fetch FULL studio data (used for Bill & Policy screen)
Future<Map<String, dynamic>> fetchStudioData(String studioId) async {
  final doc = await FirebaseFirestore.instance
      .collection('studios')
      .doc(studioId)
      .get();

  return doc.data() ?? {};
}
  /// 🔹 Fetch instrument names
  Future<Map<String, String>> fetchInstrumentNames({
    required String studioId,
    required List<dynamic> instrumentIds,
  }) async {
    if (instrumentIds.isEmpty) return {};

    Map<String, String> names = {};

    for (int i = 0; i < instrumentIds.length; i += 10) {
      final chunk = instrumentIds.sublist(
        i,
        i + 10 > instrumentIds.length ? instrumentIds.length : i + 10,
      );

      final query = await FirebaseFirestore.instance
          .collection('studios')
          .doc(studioId)
          .collection('instruments')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (var doc in query.docs) {
        names[doc.id] = doc['name'] ?? 'Unknown';
      }
    }

    return names;
  }

  /// ❌ Cancel booking + restore instruments
  Future<void> cancelBooking({
    required BuildContext context,
    required String studioId,
    required DocumentSnapshot bookingDoc,
  }) async {
    final data = bookingDoc.data() as Map<String, dynamic>;
    final instruments =
        (data['selectedInstruments'] ?? []) as List<dynamic>;

    final batch = FirebaseFirestore.instance.batch();
    final studioRef =
        FirebaseFirestore.instance.collection('studios').doc(studioId);

    for (var inst in instruments) {
      batch.update(
        studioRef.collection('instruments').doc(inst['instrumentId']),
        {'quantity': FieldValue.increment(inst['quantity'] ?? 1)},
      );
    }

    batch.delete(bookingDoc.reference);
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking cancelled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        //backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('bookings')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bookings yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final studioId = doc.reference.parent.parent!.id;
              final bookingId = doc.id;

              final instruments =
                  (data['selectedInstruments'] ?? []) as List<dynamic>;

              final instrumentIds = instruments
                  .map((e) => e['instrumentId'])
                  .where((e) => e != null)
                  .toList();

              final status = data['status'] ?? 'pending';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 🏢 STUDIO NAME
                      FutureBuilder<String>(
                        future: fetchStudioName(studioId),
                        builder: (context, snap) {
                          return Text(
                            snap.data ?? 'Loading studio...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              //color: Colors.deepPurple,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      /// 👤 USER
                      Text(
                        data['userName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      /// 📅 DATE + TIME
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 6),
                          Text(formatDate(data['date'])),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${formatTime(data['startTime'])} - ${formatTime(data['endTime'])}',
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text('Purpose: ${data['purpose'] ?? '-'}'),
                      Text('Genre: ${data['genre'] ?? '-'}'),
                      Text(
                        'People: ${data['numberOfPeople']?.toString() ?? '-'}',
                      ),

                      const SizedBox(height: 8),

                      /// 🎸 INSTRUMENTS
                      const Text(
                        'Instruments:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      FutureBuilder<Map<String, String>>(
                        future: fetchInstrumentNames(
                          studioId: studioId,
                          instrumentIds: instrumentIds,
                        ),
                        builder: (context, snap) {
                          final names = snap.data ?? {};
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: instruments.map((inst) {
                              final name =
                                  names[inst['instrumentId']] ?? 'Unknown';
                              return Text(
                                  '• $name (x${inst['quantity'] ?? 1})');
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      /// ⏱ STATUS
                      Chip(
                        label: Text(status.toUpperCase()),
                        backgroundColor: status == 'confirmed'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),

                      const Divider(),
                      const SizedBox(height: 6),
const Divider(),
const SizedBox(height: 6),

// ✅ Only show "View Bill" if booking is approved
if (status == 'approved')
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      child: const Text('View Bill'),
      onPressed: () async {
        // ✅ Use studioId derived from Firestore path
        final studioData = await fetchStudioData(studioId);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingBillAndPolicyScreen(
              bookingData: data,
              studioData: {
                ...studioData,
                'studioId': studioId, // ✅ explicitly passed
              },
            ),
          ),
        );
      },
    ),
  ),
                      /// ✏️ EDIT / ❌ CANCEL
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditBookingScreen(
                                    studioId: studioId,
                                    bookingDoc: doc,
                                  ),
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Cancel Booking'),
                                  content: const Text(
                                    'Are you sure you want to cancel this booking?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Yes'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await cancelBooking(
                                  context: context,
                                  studioId: studioId,
                                  bookingDoc: doc,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
