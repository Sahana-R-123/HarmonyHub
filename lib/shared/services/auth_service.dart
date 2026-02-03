import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// REGISTER USER
  Future<void> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String address,
    String? companyOrArtistName,
    required String role,
    required String password,
  }) async {
    try {
      // 1️⃣ Create user in Firebase Authentication
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      // 2️⃣ Save extra user data in Firestore
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'companyOrArtistName': companyOrArtistName,
        'role': role, // admin / user
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// LOGIN USER & RETURN ROLE
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // 1️⃣ Login via Firebase Auth
      UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      // 2️⃣ Fetch role from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      return userDoc['role']; // admin / user
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
