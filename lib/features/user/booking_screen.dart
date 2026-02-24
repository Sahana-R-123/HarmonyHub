import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingScreen extends StatefulWidget {
  final String studioId;

  const BookingScreen({
    super.key,
    required this.studioId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController purposeCtrl = TextEditingController();
  final TextEditingController peopleCtrl = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String genre = 'Classical';

  final Map<String, int> selectedInstruments = {};

  /// 📅 Date Picker
  Future<void> pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date != null) setState(() => selectedDate = date);
  }

  /// ⏰ Time Picker
  Future<TimeOfDay?> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null || selectedDate == null) return picked;

    final pickedDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      picked.hour,
      picked.minute,
    );

    if (pickedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Past time is not allowed')),
      );
      return null;
    }
    return picked;
  }

  /// ⛔ Check time conflict (ALWAYS) + instrument conflict (OPTIONAL)
  Future<bool> hasConflict(DateTime start, DateTime end) async {
    final bookings = await FirebaseFirestore.instance
        .collection('studios')
        .doc(widget.studioId)
        .collection('bookings')
        .where(
          'date',
          isEqualTo: Timestamp.fromDate(
            DateTime(start.year, start.month, start.day),
          ),
        )
        .get();

    for (var doc in bookings.docs) {
      final existingStart = (doc['startTime'] as Timestamp).toDate();
      final existingEnd = (doc['endTime'] as Timestamp).toDate();

      // 🔴 TIME OVERLAP → BLOCK
      if (start.isBefore(existingEnd) && end.isAfter(existingStart)) {
        // If no instruments selected, block immediately
        if (selectedInstruments.isEmpty) {
          return true;
        }

        // Otherwise check instrument overlap
        final bookedInstruments =
            List<Map<String, dynamic>>.from(doc['selectedInstruments']);

        for (var inst in bookedInstruments) {
          if (selectedInstruments.containsKey(inst['instrumentId'])) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// 💾 Submit Booking
  Future<void> submitBooking() async {
    if (!_formKey.currentState!.validate() ||
        selectedDate == null ||
        startTime == null ||
        endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all required fields')),
      );
      return;
    }

    final start = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      startTime!.hour,
      startTime!.minute,
    );

    final end = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      endTime!.hour,
      endTime!.minute,
    );

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
        ),
      );
      return;
    }

    if (await hasConflict(start, end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot is not available'),
        ),
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final studioRef = FirebaseFirestore.instance
        .collection('studios')
        .doc(widget.studioId);

    /// 🔻 Reduce quantity ONLY if instruments selected
    for (final entry in selectedInstruments.entries) {
      batch.update(
        studioRef.collection('instruments').doc(entry.key),
        {'quantity': FieldValue.increment(-entry.value)},
      );
    }

    batch.set(
      studioRef.collection('bookings').doc(),
      {
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'userName': nameCtrl.text,
        'date': Timestamp.fromDate(
          DateTime(start.year, start.month, start.day),
        ),
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'numberOfPeople': int.parse(peopleCtrl.text),
        'purpose': purposeCtrl.text,
        'genre': genre,
        'selectedInstruments': selectedInstruments.entries
            .map((e) => {
                  'instrumentId': e.key,
                  'quantity': e.value,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Studio'),
        //backgroundColor: Colors.deepPurple,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: peopleCtrl,
              decoration:
                  const InputDecoration(labelText: 'Number of People'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: purposeCtrl,
              decoration: const InputDecoration(labelText: 'Purpose'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField(
              value: genre,
              items: const [
                DropdownMenuItem(
                    value: 'Classical', child: Text('Classical')),
                DropdownMenuItem(value: 'Rock', child: Text('Rock')),
                DropdownMenuItem(value: 'Jazz', child: Text('Jazz')),
                DropdownMenuItem(value: 'Pop', child: Text('Pop')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => genre = v!),
              decoration: const InputDecoration(labelText: 'Genre'),
            ),
            ElevatedButton(
              onPressed: pickDate,
              child: Text(selectedDate == null
                  ? 'Select Date'
                  : selectedDate!.toString().split(' ')[0]),
            ),
            ElevatedButton(
              onPressed: () async {
                startTime = await pickTime();
                endTime = null;
                setState(() {});
              },
              child: Text(startTime == null
                  ? 'Start Time'
                  : startTime!.format(context)),
            ),
            ElevatedButton(
              onPressed: startTime == null
                  ? null
                  : () async {
                      final picked = await pickTime();
                      if (picked == null) return;

                      final startMinutes =
                          startTime!.hour * 60 + startTime!.minute;
                      final endMinutes =
                          picked.hour * 60 + picked.minute;

                      if (endMinutes <= startMinutes) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'End time must be after start time'),
                          ),
                        );
                        return;
                      }

                      endTime = picked;
                      setState(() {});
                    },
              child: Text(endTime == null
                  ? 'End Time'
                  : endTime!.format(context)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Instruments',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('studios')
                  .doc(widget.studioId)
                  .collection('instruments')
                  .where('isAvailable', isEqualTo: true)
                  .where('quantity', isGreaterThan: 0)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No instruments available',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    return CheckboxListTile(
                      title: Text(doc['name']),
                      subtitle:
                          Text('Available: ${doc['quantity']}'),
                      value:
                          selectedInstruments.containsKey(doc.id),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedInstruments[doc.id] = 1;
                          } else {
                            selectedInstruments.remove(doc.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              onPressed: submitBooking,
              child: const Text('Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
