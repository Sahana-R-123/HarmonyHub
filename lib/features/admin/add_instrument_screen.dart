import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddInstrumentScreen extends StatefulWidget {
  final String studioId;

  const AddInstrumentScreen({
    super.key,
    required this.studioId,
  });

  @override
  State<AddInstrumentScreen> createState() => _AddInstrumentScreenState();
}

class _AddInstrumentScreenState extends State<AddInstrumentScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final rentController = TextEditingController();
  final quantityController = TextEditingController();

  String? selectedType;
  bool isAvailable = true;
  bool isLoading = false;

  /// 🎵 Instrument Types
  final List<String> instrumentTypes = [
    'String',
    'Percussion',
    'Keyboard',
    'Wind',
    'Electronic',
    'Other',
  ];

  Future<void> _saveInstrument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance
        .collection('studios')
        .doc(widget.studioId)
        .collection('instruments')
        .add({
      'name': nameController.text.trim(),
      'type': selectedType, // ✅ SAVED
      'rentPerHour': int.parse(rentController.text),
      'quantity': int.parse(quantityController.text),
      'isAvailable': isAvailable,
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Instrument'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                /// 🎸 Instrument Name
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                /// 🏷 Instrument Type
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Type',
                    border: OutlineInputBorder(),
                  ),
                  items: instrumentTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedType = value);
                  },
                  validator: (value) =>
                      value == null ? 'Select instrument type' : null,
                ),
                const SizedBox(height: 12),

                /// 💰 Rent
                TextFormField(
                  controller: rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rent per hour (₹)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                /// 🔢 Quantity
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                /// ✅ Availability
                SwitchListTile(
                  title: const Text('Available'),
                  value: isAvailable,
                  onChanged: (val) {
                    setState(() => isAvailable = val);
                  },
                ),
                const SizedBox(height: 20),

                /// 💾 Save Button
                isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveInstrument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Save Instrument',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
