import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStudioScreen extends StatefulWidget {
  final String studioId;
  final Map<String, dynamic> studioData;

  const EditStudioScreen({
    super.key,
    required this.studioId,
    required this.studioData,
  });

  @override
  State<EditStudioScreen> createState() => _EditStudioScreenState();
}

class _EditStudioScreenState extends State<EditStudioScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController contactController;
  late TextEditingController websiteController;

  final List<Map<String, TextEditingController>> studioRooms = [];

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.studioData['name'] ?? '');
    addressController =
        TextEditingController(text: widget.studioData['fullAddress'] ?? '');
    contactController =
        TextEditingController(text: widget.studioData['contact'] ?? '');
    websiteController =
        TextEditingController(text: widget.studioData['website'] ?? '');

    final List prices = List.from(widget.studioData['studioPrices'] ?? []);

    for (var room in prices) {
      studioRooms.add({
        'type': TextEditingController(text: room['type']),
        'price': TextEditingController(
          text: room['pricePerHour'].toString(),
        ),
      });
    }
  }

  void _addStudioRoom() {
    setState(() {
      studioRooms.add({
        'type': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final List<Map<String, dynamic>> updatedPrices = [];

    for (var room in studioRooms) {
      if (room['type']!.text.isNotEmpty &&
          room['price']!.text.isNotEmpty) {
        updatedPrices.add({
          'type': room['type']!.text.trim(),
          'pricePerHour': int.parse(room['price']!.text.trim()),
        });
      }
    }

    await FirebaseFirestore.instance
        .collection('studios')
        .doc(widget.studioId)
        .update({
      'name': nameController.text.trim(),
      'fullAddress': addressController.text.trim(),
      'contact': contactController.text.trim(),
      'website': websiteController.text.trim(),
      'studioPrices': updatedPrices,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Studio'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field('Studio Name', nameController),
              _field('Full Address', addressController),
              _field('Contact', contactController),
              _field('Website', websiteController),

              const SizedBox(height: 20),
              const Text(
                'Studio Rooms & Prices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ...studioRooms.map((room) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: room['type'],
                          decoration: const InputDecoration(
                            labelText: 'Room Type',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: room['price'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '₹ / hour',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Studio Room'),
                onPressed: _addStudioRoom,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }
}
