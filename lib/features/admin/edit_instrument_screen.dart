import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditInstrumentScreen extends StatefulWidget {
  final String studioId;
  final String instrumentId;
  final Map<String, dynamic> instrumentData;

  const EditInstrumentScreen({
    super.key,
    required this.studioId,
    required this.instrumentId,
    required this.instrumentData,
  });

  @override
  State<EditInstrumentScreen> createState() =>
      _EditInstrumentScreenState();
}

class _EditInstrumentScreenState extends State<EditInstrumentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController rentController;
  late TextEditingController quantityController;

  String? selectedType;
  bool isAvailable = true;
  bool isLoading = false;

  final List<String> instrumentTypes = [
    'String',
    'Percussion',
    'Keyboard',
    'Wind',
    'Electronic',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.instrumentData;

    nameController =
        TextEditingController(text: data['name']);
    rentController =
        TextEditingController(text: data['rentPerHour'].toString());
    quantityController =
        TextEditingController(text: data['quantity'].toString());
    selectedType = data['type'];
    isAvailable = data['isAvailable'] ?? true;
  }

  Future<void> _updateInstrument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance
        .collection('studios')
        .doc(widget.studioId)
        .collection('instruments')
        .doc(widget.instrumentId)
        .update({
      'name': nameController.text.trim(),
      'type': selectedType,
      'rentPerHour': int.parse(rentController.text),
      'quantity': int.parse(quantityController.text),
      'isAvailable': isAvailable,
      'updatedAt': Timestamp.now(),
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Instrument'),
        //backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                  onChanged: (value) =>
                      setState(() => selectedType = value),
                  validator: (v) =>
                      v == null ? 'Select instrument type' : null,
                ),
                const SizedBox(height: 12),

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

                SwitchListTile(
                  title: const Text('Available'),
                  value: isAvailable,
                  onChanged: (val) {
                    setState(() => isAvailable = val);
                  },
                ),
                const SizedBox(height: 20),

                isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateInstrument,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Update Instrument',
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
