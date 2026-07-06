import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final DocumentReference _settingsRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('shop_info');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    DocumentSnapshot snapshot = await _settingsRef.get();
    if (snapshot.exists) {
      setState(() {
        _shopNameController.text = snapshot['shopName'] ?? "";
        _ownerNameController.text = snapshot['ownerName'] ?? "";
      });
    }
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    await _settingsRef.set({
      'shopName': _shopNameController.text.trim(),
      'ownerName': _ownerNameController.text.trim(),
    });
    setState(() => _isLoading = false);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("সেটিংস সফলভাবে সেভ হয়েছে!")),
      );
  }

  // পারমিশনসহ লগআউট
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("লগআউট নিশ্চিত করুন"),
        content: const Text("আপনি কি সত্যিই লগআউট করতে চান?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("না"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text(
              "হ্যাঁ, লগআউট",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("সেটিংস"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: "দোকানের নাম",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _ownerNameController,
                      decoration: const InputDecoration(
                        labelText: "মালিকের নাম",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _saveSettings,
                            child: const Text("সেভ করুন"),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text("লগআউট করুন"),
            ),
          ],
        ),
      ),
    );
  }
}
