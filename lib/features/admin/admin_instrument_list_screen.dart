import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_instrument_screen.dart';
import 'edit_instrument_screen.dart';

class AdminInstrumentListScreen extends StatelessWidget {
  final String studioId;
  final String studioName;

  const AdminInstrumentListScreen({
    super.key,
    required this.studioId,
    required this.studioName,
  });

  @override
  Widget build(BuildContext context) {
    final instrumentsRef = FirebaseFirestore.instance
        .collection('studios')
        .doc(studioId)
        .collection('instruments');

    return Scaffold(
      appBar: AppBar(
        title: Text('$studioName Instruments'),
        backgroundColor: Colors.deepPurple,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddInstrumentScreen(
                studioId: studioId,
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: instrumentsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No instruments added'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(data['name'] ?? 'Instrument'),
                  subtitle: Text(
                    '${data['type'] ?? 'Instrument'} • ₹${data['rentPerHour']}/hr • Qty: ${data['quantity']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// ✏️ EDIT
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditInstrumentScreen(
                                studioId: studioId,
                                instrumentId: doc.id,
                                instrumentData: data,
                              ),
                            ),
                          );
                        },
                      ),

                      /// 🗑 DELETE
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete Instrument'),
                              content: const Text(
                                'Are you sure you want to delete this instrument?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await instrumentsRef.doc(doc.id).delete();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
