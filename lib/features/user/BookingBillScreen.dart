import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingBillAndPolicyScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final Map<String, dynamic> studioData;

  const BookingBillAndPolicyScreen({
    super.key,
    required this.bookingData,
    required this.studioData,
  });

  @override
  State<BookingBillAndPolicyScreen> createState() =>
      _BookingBillAndPolicyScreenState();
}

class _BookingBillAndPolicyScreenState
    extends State<BookingBillAndPolicyScreen> {
  bool agreed = false;

  /// ⏱ Calculate duration in hours
  double getHours() {
    final start =
        (widget.bookingData['startTime'] as Timestamp).toDate();
    final end =
        (widget.bookingData['endTime'] as Timestamp).toDate();
    return end.difference(start).inMinutes / 60;
  }

  /// 🎸 Instrument rental cost (FIXED studioId source)
  Future<double> getInstrumentCost(double hours) async {
    final instruments = widget.bookingData['selectedInstruments'];
    if (instruments == null || instruments.isEmpty) return 0.0;

    double total = 0.0;

    // ✅ FIX: studioId comes from bookingData
    final String? studioId = widget.studioData['studioId'];
    if (studioId == null) {
      debugPrint('Studio ID not found in bookingData');
      return 0.0;
    }

    for (final item in instruments) {
      final instrumentId = item['instrumentId'];
      if (instrumentId == null) continue;

      final doc = await FirebaseFirestore.instance
          .collection('studios')
          .doc(studioId)
          .collection('instruments')
          .doc(instrumentId)
          .get();

      final price = (doc.data()?['rentPerHour'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 1).toInt();

      total += price * qty * hours;
    }

    return total;
  }

  /// ❌ Cancellation policy text builder
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
      return rawPolicy.join('\n• ');
    }

    return 'No valid cancellation policy available.';
  }

  /// 🔹 Safe helper to get studio rate
  double getStudioRate() {
    final prices = widget.studioData['studioPrices'];
    if (prices == null) return 0.0;

    if (prices is List && prices.isNotEmpty) {
      final first = prices.first;
      if (first is Map && first['pricePerHour'] != null) {
        return (first['pricePerHour'] as num).toDouble();
      }
    } else if (prices is Map && prices['pricePerHour'] != null) {
      return (prices['pricePerHour'] as num).toDouble();
    }

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;
    final studio = widget.studioData;

    final double hours = getHours();

    final double studioRate = getStudioRate();
    final double studioCost = studioRate * hours;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🏢 STUDIO DETAILS
            _sectionTitle('Studio Details'),
            Text(studio['name'] ?? ''),
            Text(studio['fullAddress'] ?? ''),
            Text('Contact: ${studio['contact'] ?? '-'}'),

            const Divider(height: 32),

            /// 📅 BOOKING DETAILS
            _sectionTitle('Booking Details'),
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format((booking['date'] as Timestamp).toDate())}',
            ),
            Text(
              'Time: ${DateFormat('hh:mm a').format((booking['startTime'] as Timestamp).toDate())} - '
              '${DateFormat('hh:mm a').format((booking['endTime'] as Timestamp).toDate())}',
            ),
            Text('Duration: ${hours.toStringAsFixed(1)} hrs'),

            const Divider(height: 32),

            /// 💰 BILL DETAILS
            _sectionTitle('Bill Details'),
            FutureBuilder<double>(
              future: getInstrumentCost(hours),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final instrumentCost = snapshot.data!;
                final gst = (studioCost + instrumentCost) * 0.18;
                final total = studioCost + instrumentCost + gst;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Studio Charge', '₹${studioCost.toStringAsFixed(2)}'),
                    _row('Instrument Rental', '₹${instrumentCost.toStringAsFixed(2)}'),
                    _row('GST (18%)', '₹${gst.toStringAsFixed(2)}'),
                    const Divider(),
                    _row('Total Payable', '₹${total.toStringAsFixed(2)}', bold: true),
                    const SizedBox(height: 8),
                    const Text(
                      '* Additional charges may apply for overtime usage, damages, or late returns.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 32),

            /// 📜 POLICIES
            _sectionTitle('Studio Booking Policies'),
            _bullet('Studios are booked in hourly slots'),
            _bullet('Arrive at least 5 minutes before start time'),
            _bullet('Late arrival does not extend booking duration'),
            _bullet('Extra usage may incur additional charges'),
            _bullet('Damage to studio equipment will be charged'),
            _bullet('Valid ID may be required'),

            const SizedBox(height: 16),

            _sectionTitle('Cancellation Policy'),
            Text(getCancellationPolicyText(), style: const TextStyle(height: 1.4)),

            const SizedBox(height: 16),

            _sectionTitle('Instrument Rental Policies'),
            _bullet('Return instruments in original condition'),
            _bullet('Security deposit may apply (refundable)'),
            _bullet('Late returns incur extra charges'),
            _bullet('Damage or loss will be charged'),

            const Divider(height: 32),

            CheckboxListTile(
              value: agreed,
              onChanged: (v) => setState(() => agreed = v ?? false),
              title: const Text(
                'I agree to the studio and rental policies',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: agreed ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(14),
                ),
                child: const Text(
                  'Proceed to Pay',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 UI helpers
  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _row(String l, String r, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text(r, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    ),
  );

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• '),
        Expanded(child: Text(t)),
      ],
    ),
  );
}