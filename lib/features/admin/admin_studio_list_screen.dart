import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_instrument_list_screen.dart';
import 'EditStudioScreen.dart';

class AdminStudioListScreen extends StatefulWidget {
  const AdminStudioListScreen({super.key});

  @override
  State<AdminStudioListScreen> createState() =>
      _AdminStudioListScreenState();
}

class _AdminStudioListScreenState
    extends State<AdminStudioListScreen> {
  String searchQuery = '';

  Future<void> _openMaps(String address) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

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

  Future<void> _deleteStudio(
      BuildContext context, String studioId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Studio'),
        content: const Text(
          'This will permanently delete the studio and all its data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('studios')
          .doc(studioId)
          .delete();
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (searchQuery.isEmpty) return true;

    final q = searchQuery.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final address =
        (data['fullAddress'] ?? '').toString().toLowerCase();

    return name.contains(q) || address.contains(q);
  }

  /// 🔹 NEW: Show cancellation policy bottom sheet
  void _showCancellationPolicy(
      BuildContext context, String policy) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              policy.isNotEmpty
                  ? policy
                  : 'No cancellation policy provided.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
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
          /// 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by studio name or address',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
            ),
          ),

          /// 📋 STUDIO LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('studios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No studios added yet'),
                  );
                }

                final studios = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: studios.length,
                  itemBuilder: (context, index) {
                    final studio = studios[index];
                    final data =
                        studio.data() as Map<String, dynamic>;

                    if (!_matchesSearch(data)) {
                      return const SizedBox.shrink();
                    }

                    final String name =
                        data['name'] ?? 'Unnamed Studio';
                    final String address =
                        data['fullAddress'] ?? '';
                    final String contact =
                        data['contact'] ?? '';
                    final String website =
                        data['website'] ?? '';
                    final dynamic rawPolicy = data['cancellationPolicy'];



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
                    final List studioPrices =
                        List.from(data['studioPrices'] ?? []);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            /// 🔹 Header Row
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditStudioScreen(
                                            studioId:
                                                studio.id,
                                            studioData:
                                                data,
                                          ),
                                        ),
                                      );
                                    } else if (value ==
                                        'delete') {
                                      _deleteStudio(
                                          context,
                                          studio.id);
                                    }
                                  },
                                  itemBuilder: (_) =>
                                      const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(
                                            color:
                                                Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            /// 📍 Address
                            if (address.isNotEmpty)
                              InkWell(
                                onTap: () => _openMaps(address),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            /// 📞 Contact
                            if (contact.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () =>
                                    _callStudio(contact),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone,
                                        size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      contact,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.blue,
                                        decoration:
                                            TextDecoration
                                                .underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            /// 🌐 Website
                            if (website.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () =>
                                    _openWebsite(website),
                                child: Row(
                                  children: const [
                                    Icon(Icons.language,
                                        size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Visit Website',
                                      style: TextStyle(
                                        color:
                                            Colors.blue,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            /// 🎧 Studio Rooms
                            if (studioPrices.isNotEmpty) ...[
                              const Text(
                                'Studio Rooms (₹ / hour)',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 90,
                                child: ListView.builder(
                                  scrollDirection:
                                      Axis.horizontal,
                                  itemCount:
                                      studioPrices.length,
                                  itemBuilder:
                                      (context, i) {
                                    final room =
                                        studioPrices[i];
                                    return Container(
                                      width: 160,
                                      margin:
                                          const EdgeInsets
                                              .only(
                                              right: 10),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors
                                            .blue
                                            .shade50,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12),
                                      ),
                                      padding:
                                          const EdgeInsets
                                              .all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                            room['type'] ??
                                                '',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                          Text(
                                            '₹${room['pricePerHour']} / hr',
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  16,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),
                            const Divider(),

                            /// 🎼 Manage Instruments
                            Align(
                              alignment:
                                  Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(
                                    Icons.music_note),
                                label: const Text(
                                    'Manage Instruments'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminInstrumentListScreen(
                                        studioId:
                                            studio.id,
                                        studioName: name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            /// ❌ NEW: View Cancellation Policy
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(
                                    Icons.policy),
                                label: const Text(
                                    'View Cancellation Policy'),
                                onPressed: () =>
                                    _showCancellationPolicy(
                                  context,
                                  cancellationPolicy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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