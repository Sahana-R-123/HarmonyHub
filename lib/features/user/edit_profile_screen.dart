import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final companyCtrl = TextEditingController();

  bool isLoading = true;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// 🔹 Load existing user data
  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();
    if (data != null) {
      fullNameCtrl.text = data['fullName'] ?? '';
      phoneCtrl.text = data['phone'] ?? '';
      addressCtrl.text = data['address'] ?? '';
      companyCtrl.text = data['companyOrArtistName'] ?? '';
    }

    setState(() => isLoading = false);
  }

  /// 🔹 Update Firestore
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fullName': fullNameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'companyOrArtistName': companyCtrl.text.trim(),
    });

    setState(() => isLoading = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    companyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 12),

                    _field(
                      controller: fullNameCtrl,
                      label: 'Full Name',
                    ),

                    const SizedBox(height: 16),

                    _field(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      keyboard: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    _field(
                      controller: addressCtrl,
                      label: 'Address',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    _field(
                      controller: companyCtrl,
                      label: 'Company / Artist Name (Optional)',
                      required: false,
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = true,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
