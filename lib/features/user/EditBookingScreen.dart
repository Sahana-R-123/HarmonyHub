import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditBookingScreen extends StatefulWidget {
  final String studioId;
  final DocumentSnapshot bookingDoc;

  const EditBookingScreen({
    super.key,
    required this.studioId,
    required this.bookingDoc,
  });

  @override
  State<EditBookingScreen> createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController purposeCtrl = TextEditingController();
  final TextEditingController peopleCtrl = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String genre = 'Classical';

  final Map<String, int> selectedInstruments = {};
  bool isPastBooking = false;

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  void _loadBookingData() {
    final data = widget.bookingDoc.data() as Map<String, dynamic>;

    final start = (data['startTime'] as Timestamp).toDate();
    if (start.isBefore(DateTime.now())) isPastBooking = true;

    nameCtrl.text = data['userName'] ?? '';
    purposeCtrl.text = data['purpose'] ?? '';
    peopleCtrl.text = data['numberOfPeople']?.toString() ?? '';
    genre = data['genre'] ?? 'Classical';

    selectedDate = (data['date'] as Timestamp).toDate();
    startTime = TimeOfDay.fromDateTime(start);
    endTime =
        TimeOfDay.fromDateTime((data['endTime'] as Timestamp).toDate());

    final instruments =
        List<Map<String, dynamic>>.from(data['selectedInstruments']);

    for (var inst in instruments) {
      selectedInstruments[inst['instrumentId']] = inst['quantity'] ?? 1;
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  Future<TimeOfDay?> pickTime(TimeOfDay initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null || selectedDate == null) return null;

    final pickedDT = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      picked.hour,
      picked.minute,
    );

    if (pickedDT.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Past time not allowed')),
      );
      return null;
    }

    return picked;
  }

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
      if (doc.id == widget.bookingDoc.id) continue;

      final es = (doc['startTime'] as Timestamp).toDate();
      final ee = (doc['endTime'] as Timestamp).toDate();

      if (start.isBefore(ee) && end.isAfter(es)) {
        final booked = List<Map<String, dynamic>>.from(
          doc['selectedInstruments'],
        );

        for (var inst in booked) {
          if (selectedInstruments.containsKey(inst['instrumentId'])) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> updateBooking() async {
    if (!_formKey.currentState!.validate() ||
        selectedDate == null ||
        startTime == null ||
        endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all fields')),
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

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End must be after start')),
      );
      return;
    }

    if (await hasConflict(start, end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instrument conflict in this time slot'),
        ),
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final studioRef =
        FirebaseFirestore.instance.collection('studios').doc(widget.studioId);

    final oldInstruments = List<Map<String, dynamic>>.from(
      widget.bookingDoc['selectedInstruments'],
    );

    for (var inst in oldInstruments) {
      batch.update(
        studioRef.collection('instruments').doc(inst['instrumentId']),
        {'quantity': FieldValue.increment(inst['quantity'] ?? 1)},
      );
    }

    for (final e in selectedInstruments.entries) {
      batch.update(
        studioRef.collection('instruments').doc(e.key),
        {'quantity': FieldValue.increment(-e.value)},
      );
    }

    batch.update(widget.bookingDoc.reference, {
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
          .map((e) => {'instrumentId': e.key, 'quantity': e.value})
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isPastBooking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Booking')),
        body: const Center(
          child: Text(
            'This booking has already started and cannot be edited.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Booking')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextFormField(
              controller: peopleCtrl,
              decoration: const InputDecoration(labelText: 'Number of People'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: purposeCtrl,
              decoration: const InputDecoration(labelText: 'Purpose'),
            ),
            DropdownButtonFormField(
              value: genre,
              items: const [
                DropdownMenuItem(value: 'Classical', child: Text('Classical')),
                DropdownMenuItem(value: 'Rock', child: Text('Rock')),
                DropdownMenuItem(value: 'Jazz', child: Text('Jazz')),
                DropdownMenuItem(value: 'Pop', child: Text('Pop')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => genre = v!),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: pickDate,
              child: Text(
                selectedDate == null
                    ? 'Select Date'
                    : DateFormat('dd MMM yyyy').format(selectedDate!),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final t = await pickTime(startTime ?? TimeOfDay.now());
                if (t != null) setState(() => startTime = t);
              },
              child: Text(
                startTime == null ? 'Start Time' : startTime!.format(context),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final t = await pickTime(endTime ?? TimeOfDay.now());
                if (t != null) setState(() => endTime = t);
              },
              child: Text(
                endTime == null ? 'End Time' : endTime!.format(context),
              ),
            ),

            const SizedBox(height: 20),
            const Text('Select Instruments'),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('studios')
                  .doc(widget.studioId)
                  .collection('instruments')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final qty = doc['quantity'];

                    return ListTile(
                      title: Text(doc['name']),
                      subtitle: Text('Available: $qty'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: selectedInstruments[doc.id] == null
                                ? null
                                : () {
                                    setState(() {
                                      final current =
                                          selectedInstruments[doc.id] ?? 0;

                                      if (current <= 1) {
                                        selectedInstruments.remove(doc.id);
                                      } else {
                                        selectedInstruments[doc.id] =
                                            current - 1;
                                      }
                                    });
                                  },
                          ),
                          Text(
                            '${selectedInstruments[doc.id] ?? 0}',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: (selectedInstruments[doc.id] ?? 0) < qty
                                ? () {
                                    setState(() {
                                      selectedInstruments[doc.id] =
                                          (selectedInstruments[doc.id] ?? 0) + 1;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: updateBooking,
              child: const Text('Update Booking'),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}