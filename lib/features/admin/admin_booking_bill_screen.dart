import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminBookingBillScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> studioData;

  const AdminBookingBillScreen({
    super.key,
    required this.bookingData,
    required this.studioData,
  });

  @override
  State<AdminBookingBillScreen> createState() =>
      _AdminBookingBillScreenState();
}

class _AdminBookingBillScreenState extends State<AdminBookingBillScreen> {

bool get isCancelled => widget.bookingData['status'] == 'cancelled';

String getCancellationPolicyText() {
  final dynamic rawPolicy =
      widget.studioData['cancellationPolicy'];

  if (rawPolicy == null) {
    return 'No cancellation policy provided by the studio.';
  }

  if (rawPolicy is String) {
    return rawPolicy;
  }

  if (rawPolicy is Map) {
    final int fullRefundHours =
        rawPolicy['fullRefundBeforeHours'] ?? 24;
    final int partialRefundHours =
        rawPolicy['partialRefundBeforeHours'] ?? 12;
    final int partialRefundPercent =
        rawPolicy['partialRefundPercentage'] ?? 50;

    return '''
• ≥ $fullRefundHours hrs before slot → 100% refund
• $partialRefundHours–$fullRefundHours hrs before slot → $partialRefundPercent% refund
• < $partialRefundHours hrs before slot → No refund
• If studio cancels → Full refund or free reschedule
''';
  }

  if (rawPolicy is List) {
    return rawPolicy.map((e) => '• $e').join('\n');
  }

  return 'No valid cancellation policy available.';
}

double _hours() {
  final start =
      (widget.bookingData['startTime'] as Timestamp).toDate();
  final end =
      (widget.bookingData['endTime'] as Timestamp).toDate();
  return end.difference(start).inMinutes / 60;
}

Map<String, dynamic> _selectRoom() {
  final people = (widget.bookingData['numberOfPeople'] ?? 1);

  final List rooms = widget.studioData['studioPrices'] ?? [];

  rooms.sort((a, b) => (a['capacity'] ?? 0).compareTo(b['capacity'] ?? 0));

  for (final room in rooms) {
    if (people <= (room['capacity'] ?? 0)) {
      return room;
    }
  }

  return rooms.isNotEmpty ? rooms.last : {};
}

double _studioRate() {
  final room = _selectRoom();
  return (room['pricePerHour'] ?? 0).toDouble();
}

Future<double> _instrumentCost(double hours) async {
  final instruments = widget.bookingData['selectedInstruments'];
  if (instruments == null || instruments.isEmpty) return 0.0;

  double total = 0.0;
  final studioId = widget.studioData['studioId'];

  for (final item in instruments) {
    final instId = item['instrumentId'];
    final qty = item['quantity'] ?? 1;

    final doc = await FirebaseFirestore.instance
        .collection('studios')
        .doc(studioId)
        .collection('instruments')
        .doc(instId)
        .get();

    final rate = (doc.data()?['rentPerHour'] ?? 0).toDouble();
    total += rate * qty * hours;
  }

  return total;
}

/// ✅ FIXED: SAFE bookingId handling (THIS WAS THE BUG)
Future<double> _calculateCancellationCharge(
    double studioCost,
    double instCost,
    double hours,
) async {

  final studioId = widget.studioData['studioId'];

  // 🔴 FIX: fallback-safe bookingId
  final bookingId = widget.bookingData['bookingId'] ??
      widget.bookingData['id'];

  if (bookingId == null) {
    final gst = (studioCost + instCost) * 0.18;
    return (studioCost + instCost + gst) * 0.5;
  }

  final bookingRef = FirebaseFirestore.instance
      .collection('studios')
      .doc(studioId)
      .collection('bookings')
      .doc(bookingId);

  final doc = await bookingRef.get();

  if (doc.exists &&
      doc.data() != null &&
      doc.data()!.containsKey('cancellationCharge')) {
    return (doc['cancellationCharge'] as num).toDouble();
  }

  final dynamic rawPolicy = widget.studioData['cancellationPolicy'];

  final gst = (studioCost + instCost) * 0.18;
  final totalCost = studioCost + instCost + gst;

  double charge;

  if (rawPolicy == null || rawPolicy is! Map) {
    charge = totalCost * 0.5;
  } else {
    final int fullRefundHours =
        rawPolicy['fullRefundBeforeHours'] ?? 24;
    final int partialRefundHours =
        rawPolicy['partialRefundBeforeHours'] ?? 12;
    final int partialRefundPercent =
        rawPolicy['partialRefundPercentage'] ?? 50;

    final bookingTime =
        (widget.bookingData['startTime'] as Timestamp).toDate();

    final Timestamp? cancelledAtTs = doc.data()?['cancelledAt'];
final DateTime cancelledAt =
    cancelledAtTs != null ? cancelledAtTs.toDate() : DateTime.now();

final diffHours = bookingTime.difference(cancelledAt).inHours;

    if (diffHours >= fullRefundHours) {
      charge = 0;
    } else if (diffHours >= partialRefundHours &&
        diffHours < fullRefundHours) {
      charge = totalCost * (100 - partialRefundPercent) / 100;
    } else {
      charge = totalCost;
    }
  }

  if (!doc.data()!.containsKey('cancellationCharge')) {
  await bookingRef.set({
    'cancellationCharge': charge,
    'cancelledAt': Timestamp.now(),
  }, SetOptions(merge: true));
}

  return charge;
}

@override
Widget build(BuildContext context) {
  final booking = widget.bookingData;
  final studio = widget.studioData;

  final hours = _hours();
  final studioCost = _studioRate() * hours;

  return Scaffold(
    appBar: AppBar(title: const Text('Booking Bill')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _title('Studio Details'),
          Text(studio['name'] ?? ''),
          Text(studio['fullAddress'] ?? ''),
          Text('Contact: ${studio['contact'] ?? '-'}'),

          const Divider(height: 32),

          _title('Booking Details'),
          Text(
            'Date: ${DateFormat('dd MMM yyyy').format((booking['date'] as Timestamp).toDate())}',
          ),
          Text(
            'Time: ${DateFormat('hh:mm a').format((booking['startTime'] as Timestamp).toDate())}'
            ' - ${DateFormat('hh:mm a').format((booking['endTime'] as Timestamp).toDate())}',
          ),
          Text('Duration: ${hours.toStringAsFixed(1)} hrs'),

          const Divider(height: 32),

          if (isCancelled)
            FutureBuilder<double>(
              future: _instrumentCost(hours),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const CircularProgressIndicator();
                }

                final instCost = snap.data!;
                final gst = (studioCost + instCost) * 0.18;
                final totalCost = studioCost + instCost + gst;

                return FutureBuilder<double>(
                  future: _calculateCancellationCharge(
                      studioCost, instCost, hours),
                  builder: (context, cancelSnap) {
                    if (!cancelSnap.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final cancelCharge = cancelSnap.data!;
                    final refund = totalCost - cancelCharge;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title('Cancellation Bill'),
                        _row('Studio Charge', studioCost, bold: true),
                        _row('Instrument Charge', instCost, bold: true),
                        _row('GST (18%)', gst, bold: true),
                        _row('Cancellation Charge', cancelCharge, bold: true),
                        const Divider(),
                        _row('Total Refund', refund, bold: true),
                      ],
                    );
                  },
                );
              },
            )
          else
            FutureBuilder<double>(
              future: _instrumentCost(hours),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const CircularProgressIndicator();
                }

                final instCost = snap.data!;
                final gst = (studioCost + instCost) * 0.18;
                final total = studioCost + instCost + gst;

                return Column(
                  children: [
                    _title('Bill Details'),
                    _row('Studio Charge', studioCost),
                    _row('Instrument Rental', instCost),
                    _row('GST (18%)', gst),
                    const Divider(),
                    _row('Total', total, bold: true),
                  ],
                );
              },
            ),

          const Divider(height: 32),

          if (!isCancelled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Cancellation Policy'),
                Text(getCancellationPolicyText(),
                    style: const TextStyle(height: 1.5)),
              ],
            ),
        ],
      ),
    ),
  );
}

Widget _title(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    t,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
);

Widget _row(String l, double v, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      Text('₹${v.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
    ],
  ),
);
}