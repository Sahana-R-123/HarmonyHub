import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_screen.dart'; // ✅ ADDED

class StudioDetailsScreen extends StatelessWidget {
  final String studioId;

  const StudioDetailsScreen({
    super.key,
    required this.studioId,
  });

  // 📍 Open address in Google Maps
  Future<void> _openMaps(String address) async {
    final Uri mapsUrl = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/search/',
      queryParameters: {
        'api': '1',
        'query': address,
      },
    );

    await launchUrl(
      mapsUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  // 🌐 Open website in browser
  Future<void> _openWebsite(String website) async {
    final Uri url = Uri.parse(
      website.startsWith('http') ? website : 'https://$website',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  // 📞 Call studio
  Future<void> _callStudio(String phone) async {
    final Uri telUri = Uri.parse('tel:$phone');
    await launchUrl(
      telUri,
      mode: LaunchMode.externalApplication,
    );
  }

String _formatHour(int hour) {
  final period = hour >= 12 ? "PM" : "AM";
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return "$h $period";
}
  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('studios').doc(studioId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Studio not found'));
          }

          final studio =
              snapshot.data!.data() as Map<String, dynamic>;

          final String name = studio['name'] ?? 'Studio';
          final String address = studio['fullAddress'] ?? '';
          final String website = studio['website'] ?? '';
          final String contact = studio['contact'] ?? '';
          final bool isAvailable = studio['isActive'] ?? false;

          final List studioPrices =
              List.from(studio['studioPrices'] ?? []);

          // ✅ Cancellation policy (SAFE)
          final dynamic rawPolicy = studio['cancellationPolicy'];

 
String cancellationPolicy = 'No cancellation policy provided.';

if (rawPolicy is String) {
  cancellationPolicy = rawPolicy;
} else if (rawPolicy is Map) {
  final int fullRefundHours =
      (rawPolicy['fullRefundBeforeHours'] ?? 0) as int;
  final int partialRefundHours =
      (rawPolicy['partialRefundBeforeHours'] ?? 0) as int;
  final int partialRefundPercent =
      (rawPolicy['partialRefundPercentage'] ?? 0) as int;

  cancellationPolicy =
      'Full refund if cancelled at least $fullRefundHours hours before the slot.\n'
      'Partial refund of $partialRefundPercent% if cancelled at least '
      '$partialRefundHours hours before the slot.\n'
      'No refund for cancellations within $partialRefundHours hours.';
}

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🏢 STUDIO NAME
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                /// ✅ AVAILABLE STATUS
                Row(
                  children: [
                    Icon(
                      isAvailable
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: isAvailable
                          ? Colors.green
                          : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        color: isAvailable
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// 📍 ADDRESS
                if (address.isNotEmpty)
                  InkWell(
                    onTap: () => _openMaps(address),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                /// 📞 CONTACT
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _callStudio(contact),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          contact,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                /// 🌐 WEBSITE
                if (website.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openWebsite(website),
                    child: Row(
                      children: const [
                        Icon(Icons.language, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Visit Website',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),

                /// 🎧 STUDIO ROOMS
                if (studioPrices.isNotEmpty) ...[
                  const Text(
                    'Studio Rooms (₹ / hour)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: studioPrices.length,
                      itemBuilder: (context, index) {
                        final room =
                            studioPrices[index] as Map<String, dynamic>;

                        return Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                room['type'] ?? 'Room',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '₹${room['pricePerHour']} / hour',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                /// 🔥 BUSY HOUR PREDICTION
const SizedBox(height: 24),
const Divider(),

const Text(
  '🔥 Popular Hours',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

StreamBuilder<DocumentSnapshot>(
  stream: firestore
      .collection('studio_busy_hours')
      .doc(studioId)
      .snapshots(),
  builder: (context, busySnapshot) {
    if (busySnapshot.connectionState ==
        ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!busySnapshot.hasData ||
        !busySnapshot.data!.exists) {
      return const Text('No busy hour prediction available');
    }

    final data =
        busySnapshot.data!.data() as Map<String, dynamic>;

    final List<int> busyHours =
        (data['busyHours'] as List<dynamic>? ?? [])
            .map((e) => e as int)
            .toList();

    if (busyHours.isEmpty) {
      return const Text('No busy hours predicted');
    }

    busyHours.sort(); // ✅ important

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: busyHours.map((hour) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatHour(hour),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        );
      }).toList(),
    );
  },
),
                /// 🎸 INSTRUMENTS  ✅ RESTORED
                const Text(
                  'Available Instruments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('studios')
                      .doc(studioId)
                      .collection('instruments')
                      .snapshots(),
                  builder: (context, instrumentSnapshot) {
                    if (instrumentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!instrumentSnapshot.hasData ||
                        instrumentSnapshot.data!.docs.isEmpty) {
                      return const Text('No instruments available');
                    }

                    final instruments =
                        instrumentSnapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: instruments.length,
                      itemBuilder: (context, index) {
                        final instrument =
                            instruments[index].data()
                                as Map<String, dynamic>;

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(
                                instrument['name'] ?? 'Instrument'),
                            subtitle: Text(
                              '${instrument['type']} • ₹${instrument['rentPerHour']}/hr • Qty: ${instrument['quantity']}',
                            ),
                            trailing: Icon(
                              (instrument['isAvailable'] == true &&
                                      (instrument['quantity'] ?? 0) > 0)
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  (instrument['isAvailable'] == true &&
                                          (instrument['quantity'] ?? 0) > 0)
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Divider(),

                /// 📄 VIEW CANCELLATION POLICY  ✅ ADDED
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.policy),
                  title: const Text(
                    'Cancellation Policy',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing:
                      const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cancellation Policy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cancellationPolicy,
                              style:
                                  const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                /// 📅 BOOK BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookingScreen(studioId: studioId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Text(
                      'Proceed to Booking',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}