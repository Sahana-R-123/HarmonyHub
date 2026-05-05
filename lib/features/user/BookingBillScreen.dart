import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'PaymentScreen.dart';

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

  double getHours() {
    final start =
        (widget.bookingData['startTime'] as Timestamp).toDate();
    final end =
        (widget.bookingData['endTime'] as Timestamp).toDate();
    return end.difference(start).inMinutes / 60;
  }

  Future<double> getInstrumentCost(double hours) async {
    final instruments = widget.bookingData['selectedInstruments'];
    if (instruments == null || instruments.isEmpty) return 0.0;

    double total = 0.0;

    final String? studioId = widget.studioData['studioId'];
    if (studioId == null) return 0.0;

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

  String getCancellationPolicyText() {
    final dynamic rawPolicy =
        widget.studioData['cancellationPolicy'];

    if (rawPolicy == null) {
      return 'No cancellation policy provided by the studio.';
    }

    if (rawPolicy is String) return rawPolicy;

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

    return 'No valid cancellation policy available.';
  }

  double getStudioCostByPeople(double hours) {
    final int people = widget.bookingData['numberOfPeople'] ?? 1;

    final prices = widget.studioData['studioPrices'];

    if (prices == null || prices is! List || prices.isEmpty) {
      return 0.0;
    }

    List<Map<String, dynamic>> rooms = List<Map<String, dynamic>>.from(prices);

    rooms.sort((a, b) =>
        (a['pricePerHour'] ?? 0).compareTo(b['pricePerHour'] ?? 0));

    int index = (people / 2).floor();
    if (index >= rooms.length) index = rooms.length - 1;

    final rate =
        (rooms[index]['pricePerHour'] ?? 0).toDouble();

    return rate * hours;
  }

  double getCancellationCharge(double totalCost) {
    final policy = widget.studioData['cancellationPolicy'];

    if (policy == null || policy is! Map) {
      return totalCost * 0.2;
    }

    final start =
        (widget.bookingData['startTime'] as Timestamp).toDate();

    final now = DateTime.now();
    final hoursBefore = start.difference(now).inHours;

    final fullRefundHours = policy['fullRefundBeforeHours'] ?? 24;
    final partialRefundHours = policy['partialRefundBeforeHours'] ?? 12;
    final partialRefundPercent =
        policy['partialRefundPercentage'] ?? 50;

    if (hoursBefore >= fullRefundHours) {
      return 0;
    } else if (hoursBefore >= partialRefundHours) {
      return totalCost * (100 - partialRefundPercent) / 100;
    } else {
      return totalCost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;
    final studio = widget.studioData;

    final double hours = getHours();

    final bool isCancelled = booking['status'] == 'cancelled';

    final double studioCost = getStudioCostByPeople(hours);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _sectionTitle('Studio Details'),
            Text(studio['name'] ?? ''),
            Text(studio['fullAddress'] ?? ''),
            Text('Contact: ${studio['contact'] ?? '-'}'),

            const Divider(height: 32),

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

            _sectionTitle(isCancelled ? 'Cancellation Bill' : 'Bill Details'),

            FutureBuilder<double>(
              future: getInstrumentCost(hours),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final instrumentCost = snapshot.data!;

                final gst = (studioCost + instrumentCost) * 0.18;
                final totalCost = studioCost + instrumentCost + gst;

                final cancelCharge =
                    getCancellationCharge(totalCost);

                if (isCancelled) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Studio Charge',
                          '₹${studioCost.toStringAsFixed(2)}'),
                      _row('Instrument Rental',
                          '₹${instrumentCost.toStringAsFixed(2)}'),
                      _row('GST (18%)',
                          '₹${gst.toStringAsFixed(2)}'),
                      const Divider(),
                      _row('Cancellation Charge',
                          '₹${cancelCharge.toStringAsFixed(2)}'),
                      const Divider(),
                      _row(
                          'Total Refund',
                          '₹${(totalCost - cancelCharge).toStringAsFixed(2)}',
                          bold: true),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Studio Charge',
                        '₹${studioCost.toStringAsFixed(2)}'),
                    _row('Instrument Rental',
                        '₹${instrumentCost.toStringAsFixed(2)}'),
                    _row('GST (18%)', '₹${gst.toStringAsFixed(2)}'),
                    const Divider(),
                    _row('Total Payable',
                        '₹${totalCost.toStringAsFixed(2)}',
                        bold: true),
                  ],
                );
              },
            ),

            const Divider(height: 32),

            /// ❌ HIDE these if cancelled
            if (!isCancelled) ...[
              _sectionTitle('Studio Booking Policies'),
              _bullet('Studios are booked in hourly slots'),
              _bullet('Arrive at least 5 minutes before start time'),
              _bullet('Late arrival does not extend booking duration'),
              _bullet('Extra usage may incur additional charges'),
              _bullet('Damage to studio equipment will be charged'),
              _bullet('Valid ID may be required'),

              const SizedBox(height: 16),
            ],

            /// ✅ ALWAYS show cancellation policy
            _sectionTitle('Cancellation Policy'),
            Text(getCancellationPolicyText()),

            /// ❌ HIDE if cancelled
            if (!isCancelled) ...[
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
                title: const Text('I agree to policies'),
                controlAffinity: ListTileControlAffinity.leading,
              ),

              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: agreed
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentScreen(
                                  bookingData: widget.bookingData,
                                  studioData: widget.studioData,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: const Text('Proceed to Pay'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  Widget _row(String l, String r, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l,
              style:
                  TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(r,
              style:
                  TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ],
      );

  Widget _bullet(String t) => Row(
        children: [
          const Text('• '),
          Expanded(child: Text(t)),
        ],
      );
}