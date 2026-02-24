import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStudioScreen extends StatefulWidget {
  const AddStudioScreen({super.key});

  @override
  State<AddStudioScreen> createState() => _AddStudioScreenState();
}

class _AddStudioScreenState extends State<AddStudioScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();

  // 🔹 Cancellation policy controllers
  final TextEditingController fullRefundHoursController =
      TextEditingController();
  final TextEditingController partialRefundHoursController =
      TextEditingController();
  final TextEditingController partialRefundPercentController =
      TextEditingController();

  bool isLoading = false;

  // 🔥 Dynamic studio room types
  List<Map<String, TextEditingController>> studioTypes = [];

  @override
  void initState() {
    super.initState();
    _addStudioType();
  }

  void _addStudioType() {
    setState(() {
      studioTypes.add({
        'type': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void _removeStudioType(int index) {
    setState(() {
      studioTypes.removeAt(index);
    });
  }

  Future<void> addStudio() async {
    setState(() => isLoading = true);

    final List<Map<String, dynamic>> prices = studioTypes
        .where((e) =>
            e['type']!.text.isNotEmpty &&
            e['price']!.text.isNotEmpty)
        .map((e) => {
              'type': e['type']!.text.trim(),
              'pricePerHour': int.tryParse(e['price']!.text.trim()),
            })
        .toList();

    await FirebaseFirestore.instance.collection('studios').add({
      'name': nameController.text.trim(),
      'fullAddress': addressController.text.trim(),
      'contact': contactController.text.trim(),
      'website': websiteController.text.trim(),
      'studioPrices': prices,

      // ✅ Cancellation Policy (Structured)
      'cancellationPolicy': {
        'fullRefundBeforeHours':
            int.tryParse(fullRefundHoursController.text.trim()) ?? 0,
        'partialRefundBeforeHours':
            int.tryParse(partialRefundHoursController.text.trim()) ?? 0,
        'partialRefundPercentage':
            int.tryParse(partialRefundPercentController.text.trim()) ?? 0,
      },

      'isActive': true,
      'createdAt': Timestamp.now(),
    });

    setState(() => isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Studio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _inputField('Studio Name', nameController),
            _inputField('Full Address', addressController, maxLines: 2),
            _inputField(
              'Contact Number',
              contactController,
              keyboardType: TextInputType.phone,
            ),
            _inputField(
              'Website URL',
              websiteController,
              keyboardType: TextInputType.url,
              hint: 'https://www.studio.com',
            ),

            const SizedBox(height: 24),
            const Text(
              'Studio Room Types & Price / Hour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...studioTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final controllers = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: controllers['type'],
                        decoration: const InputDecoration(
                          labelText: 'Room Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controllers['price'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price per hour (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (studioTypes.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeStudioType(index),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            TextButton.icon(
              onPressed: _addStudioType,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Room Type'),
            ),

            const SizedBox(height: 32),

            // 🔥 Cancellation Policy Section
            const Text(
              'Cancellation Policy (Studio)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _inputField(
              'Full refund before (hours)',
              fullRefundHoursController,
              keyboardType: TextInputType.number,
              hint: 'e.g. 24',
            ),
            _inputField(
              'Partial refund before (hours)',
              partialRefundHoursController,
              keyboardType: TextInputType.number,
              hint: 'e.g. 12',
            ),
            _inputField(
              'Partial refund percentage (%)',
              partialRefundPercentController,
              keyboardType: TextInputType.number,
              hint: 'e.g. 50',
            ),

            const SizedBox(height: 32),

            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: addStudio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Add Studio'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}