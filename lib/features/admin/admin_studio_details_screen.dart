import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminStudioDetailsScreen extends StatelessWidget {
  final String studioId;

  const AdminStudioDetailsScreen({
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

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Details'),
        //backgroundColor: Colors.deepPurple,
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
                                  //color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(),

                /// 🎸 INSTRUMENTS
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
                            leading: const Icon(
                              Icons.music_note,
                              //color: Colors.deepPurple,
                            ),
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

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
