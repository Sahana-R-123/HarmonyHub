import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService authService = AuthService();

  String selectedRole = 'user';
  bool isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    companyController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Address
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Company / Artist
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company / Artist Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Role
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() => selectedRole = value!);
                },
              ),
              const SizedBox(height: 24),

              // Register Button
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (fullNameController.text.isEmpty ||
                            phoneController.text.isEmpty ||
                            addressController.text.isEmpty ||
                            emailController.text.isEmpty ||
                            passwordController.text.isEmpty ||
                            confirmPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all required fields'),
                            ),
                          );
                          return;
                        }

                        if (passwordController.text !=
                            confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                            ),
                          );
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          await authService.registerUser(
                            fullName: fullNameController.text.trim(),
                            phone: phoneController.text.trim(),
                            address: addressController.text.trim(),
                            companyOrArtistName:
                                companyController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text.trim(),
                            role: selectedRole,
                          );

                          // ✅ EMAIL VERIFICATION (ADDED)
                          await FirebaseAuth
                              .instance.currentUser
                              ?.sendEmailVerification();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Registration successful. Please verify your email.',
                              ),
                            ),
                          );

                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        } finally {
                          setState(() => isLoading = false);
                        }
                      },
                      child: const Text('Register'),
                    ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
