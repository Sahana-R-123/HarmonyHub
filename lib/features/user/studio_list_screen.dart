import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'studio_details_screen.dart';

class StudioListScreen extends StatefulWidget {
  const StudioListScreen({super.key});

  @override
  State<StudioListScreen> createState() => _StudioListScreenState();
}

class _StudioListScreenState extends State<StudioListScreen> {
  DateTime? selectedDate;
  DateTime? selectedStart;
  DateTime? selectedEnd;

  bool applyFilter = false;
  String searchQuery = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔍 CHECK AVAILABILITY (FIXED)
  Future<bool> isStudioAvailable(String studioId) async {
    if (!applyFilter ||
        selectedDate == null ||
        selectedStart == null ||
        selectedEnd == null) {
      return true;
    }

    final snapshot = await _firestore
        .collection('studios')
        .doc(studioId)
        .collection('bookings')
        .where(
          'date',
          isEqualTo: Timestamp.fromDate(
            DateTime(
              selectedDate!.year,
              selectedDate!.month,
              selectedDate!.day,
            ),
          ),
        )
        .get();

    for (var doc in snapshot.docs) {
      final start = (doc['startTime'] as Timestamp).toDate();
      final end = (doc['endTime'] as Timestamp).toDate();

      // ⛔ TIME OVERLAP CHECK
      if (selectedStart!.isBefore(end) &&
          selectedEnd!.isAfter(start)) {
        return false;
      }
    }
    return true;
  }

  // 📅 DATE PICKER
  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        applyFilter = false;
      });
    }
  }

  // ⏰ TIME PICKER
  Future<void> pickTime({required bool isStart}) async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select date first')),
      );
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final dateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      time.hour,
      time.minute,
    );

    setState(() {
      isStart ? selectedStart = dateTime : selectedEnd = dateTime;
      applyFilter = false;
    });
  }

  void applyFilters() {
    if (selectedDate == null ||
        selectedStart == null ||
        selectedEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select date & time')),
      );
      return;
    }

    if (!selectedEnd!.isAfter(selectedStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('End time must be after start')),
      );
      return;
    }

    setState(() => applyFilter = true);
  }

  void clearFilters() {
    setState(() {
      selectedDate = null;
      selectedStart = null;
      selectedEnd = null;
      applyFilter = false;
    });
  }

  int getMinPrice(List prices) {
    if (prices.isEmpty) return 0;
    return prices
        .map((e) => e['pricePerHour'] as int)
        .reduce((a, b) => a < b ? a : b);
  }

  // 🔍 STUDIO FIELD SEARCH
  bool matchesStudioFields(Map<String, dynamic> data) {
    if (searchQuery.isEmpty) return true;

    final q = searchQuery.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final address =
        (data['fullAddress'] ?? '').toString().toLowerCase();

    return name.contains(q) || address.contains(q);
  }

  // 🔍 INSTRUMENT SUBCOLLECTION SEARCH
  Future<bool> matchesInstruments(String studioId) async {
    if (searchQuery.isEmpty) return true;

    final q = searchQuery.toLowerCase();

    final snapshot = await _firestore
        .collection('studios')
        .doc(studioId)
        .collection('instruments')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final combined =
          '${data['name'] ?? ''} ${data['type'] ?? ''}'
              .toLowerCase();

      if (combined.contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studios'),
        //backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search studios or instruments',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value.toLowerCase());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: pickDate,
                    child: Text(selectedDate == null
                        ? 'Select Date'
                        : selectedDate!
                            .toString()
                            .split(' ')[0]),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => pickTime(isStart: true),
                    child: Text(selectedStart == null
                        ? 'Select Start Time'
                        : TimeOfDay.fromDateTime(selectedStart!)
                            .format(context)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => pickTime(isStart: false),
                    child: Text(selectedEnd == null
                        ? 'Select End Time'
                        : TimeOfDay.fromDateTime(selectedEnd!)
                            .format(context)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: applyFilters,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Filter'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('studios')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final studios = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: studios.length,
                  itemBuilder: (context, index) {
                    final studio = studios[index];
                    final data =
                        studio.data() as Map<String, dynamic>;

                    return FutureBuilder<bool>(
                      future: matchesInstruments(studio.id),
                      builder: (context, instrumentSnap) {
                        final matchesSearch =
                            matchesStudioFields(data) ||
                                (instrumentSnap.data ?? false);

                        if (!matchesSearch) {
                          return const SizedBox.shrink();
                        }

                        final prices =
                            List.from(data['studioPrices'] ?? []);
                        final minPrice = getMinPrice(prices);

                        return FutureBuilder<bool>(
                          future: isStudioAvailable(studio.id),
                          builder: (context, availabilitySnap) {
                            if (!availabilitySnap.hasData) {
                              return const SizedBox();
                            }

                            if (applyFilter &&
                                !availabilitySnap.data!) {
                              return const SizedBox();
                            }

                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudioDetailsScreen(
                                        studioId: studio.id,
                                      ),
                                    ),
                                  );
                                },
                                title: Text(data['name'] ?? ''),
                                subtitle: Text(
                                  '${data['fullAddress'] ?? ''}\nFrom ₹$minPrice / hour',
                                ),
                                trailing: Icon(
                                  availabilitySnap.data!
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: availabilitySnap.data!
                                      ? Colors.green
                                      : Colors.red,
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
