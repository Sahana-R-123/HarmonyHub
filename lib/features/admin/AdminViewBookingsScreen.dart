import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ ADD THIS IMPORT
import 'admin_user_details_screen.dart';

class AdminViewBookingsScreen extends StatefulWidget {
  const AdminViewBookingsScreen({super.key});

  @override
  State<AdminViewBookingsScreen> createState() =>
      _AdminViewBookingsScreenState();
}

class _AdminViewBookingsScreenState extends State<AdminViewBookingsScreen> {
  String statusFilter = 'all';
  String studioFilter = '';
  String instrumentFilter = '';

  final Map<String, String> _studioNameCache = {};
  final Map<String, Map<String, String>> _instrumentNameCache = {};

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

  /// 🔹 Fetch studio name (cached)
  Future<String> _fetchStudioName(String studioId) async {
    if (_studioNameCache.containsKey(studioId)) {
      return _studioNameCache[studioId]!;
    }

    final doc = await FirebaseFirestore.instance
        .collection('studios')
        .doc(studioId)
        .get();

    final name = doc.data()?['name'] ?? 'Unknown Studio';
    _studioNameCache[studioId] = name;
    return name;
  }

  /// 🔹 Fetch instrument names (cached)
  Future<Map<String, String>> _fetchInstrumentNames(
    String studioId,
    List<dynamic> instruments,
  ) async {
    if (!_instrumentNameCache.containsKey(studioId)) {
      _instrumentNameCache[studioId] = {};
    }

    Map<String, String> names = _instrumentNameCache[studioId]!;

    List<String> missingIds = [];

    for (var inst in instruments) {
      if (inst is Map && inst.containsKey('instrumentId')) {
        final id = inst['instrumentId'];
        if (!names.containsKey(id)) {
          missingIds.add(id);
        }
      }
    }

    for (var id in missingIds) {
      final doc = await FirebaseFirestore.instance
          .collection('studios')
          .doc(studioId)
          .collection('instruments')
          .doc(id)
          .get();

      names[id] = doc.data()?['name'] ?? 'Unknown';
    }

    return names;
  }

  /// ✅ APPROVE / ❌ REJECT WITH RESTORE
  Future<void> _updateStatus({
    required String studioId,
    required DocumentSnapshot bookingDoc,
    required String status,
  }) async {
    final data = bookingDoc.data() as Map<String, dynamic>;
    final instruments =
        (data['selectedInstruments'] ?? []) as List<dynamic>;

    final batch = FirebaseFirestore.instance.batch();
    final studioRef =
        FirebaseFirestore.instance.collection('studios').doc(studioId);

    if (status == 'rejected') {
      for (var inst in instruments) {
        batch.update(
          studioRef.collection('instruments').doc(inst['instrumentId']),
          {'quantity': FieldValue.increment(inst['quantity'] ?? 1)},
        );
      }
    }

    batch.update(bookingDoc.reference, {'status': status});
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          /// 🔍 FILTER BAR
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    DropdownButton<String>(
                      value: statusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (v) =>
                          setState(() => statusFilter = v!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Studio name',
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setState(() => studioFilter = v.toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Instrument name',
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => instrumentFilter = v.toLowerCase()),
                ),
              ],
            ),
          ),

          /// 📋 BOOKINGS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('bookings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No bookings found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final studioId = doc.reference.parent.parent!.id;
                    final status = data['status'] ?? 'pending';
                    final instruments =
                        (data['selectedInstruments'] ?? []) as List<dynamic>;

                    if (statusFilter != 'all' && status != statusFilter) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<String>(
                      future: _fetchStudioName(studioId),
                      builder: (context, studioSnap) {
                        final studioName =
                            studioSnap.data?.toLowerCase() ?? '';

                        if (studioFilter.isNotEmpty &&
                            !studioName.contains(studioFilter)) {
                          return const SizedBox.shrink();
                        }

                        return FutureBuilder<Map<String, String>>(
                          future:
                              _fetchInstrumentNames(studioId, instruments),
                          builder: (context, instSnap) {
                            final instNames = instSnap.data ?? {};

                            if (instrumentFilter.isNotEmpty &&
                                !instNames.values.any((n) =>
                                    n.toLowerCase()
                                        .contains(instrumentFilter))) {
                              return const SizedBox.shrink();
                            }

                            return Card(
                              elevation: 4,
                              margin:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studioSnap.data ??
                                          'Loading studio...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['userName'] ?? 'Unknown User',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_date(data['date'])} • '
                                      '${_time(data['startTime'])} - ${_time(data['endTime'])}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Purpose: ${data['purpose'] ?? '-'}'),
                                    Text('Genre: ${data['genre'] ?? '-'}'),
                                    Text('People: ${data['numberOfPeople'] ?? '-'}'),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Instruments:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    ...instruments.map((inst) => Text(
                                          '• ${instNames[inst['instrumentId']] ?? 'Unknown'} (x${inst['quantity']})',
                                        )),
                                    const SizedBox(height: 10),
                                    Chip(
                                      label: Text(status.toUpperCase()),
                                      backgroundColor:
                                          _statusColor(status).withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Divider(),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AdminUserDetailsScreen(
                                              userId: data['userId'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('User Details'),
                                    ),
                                    if (status == 'pending') ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green),
                                            onPressed: () => _updateStatus(
                                              studioId: studioId,
                                              bookingDoc: doc,
                                              status: 'approved',
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            onPressed: () => _updateStatus(
                                              studioId: studioId,
                                              bookingDoc: doc,
                                              status: 'rejected',
                                            ),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
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
