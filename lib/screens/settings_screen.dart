import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Text Controllers
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে সেটিংস লোড করার জন্য getter তৈরি করা হলো
  DocumentReference get _settingsRef {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('shop_info');
  }

  bool _isLoading = false;
  bool _isUploadingImage = false;

  Uint8List? _imageBytes;
  String? _profileImageUrl;

  final ImagePicker _picker = ImagePicker();

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
        _phoneController.text = snapshot['phone'] ?? "";
        _addressController.text = snapshot['address'] ?? "";
        _profileImageUrl = snapshot['profileImageUrl'];
      });
    }
  }

  void _saveSettings() async {
    setState(() => _isLoading = true);
    await _settingsRef.set({
      'shopName': _shopNameController.text.trim(),
      'ownerName': _ownerNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    }, SetOptions(merge: true));

    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("দোকানের তথ্য সফলভাবে সেভ হয়েছে!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();

      setState(() {
        _imageBytes = bytes;
      });

      await _uploadToCloudinary(bytes, pickedFile.name);
    }
  }

  Future<void> _uploadToCloudinary(
    Uint8List imageBytes,
    String fileName,
  ) async {
    setState(() => _isUploadingImage = true);

    const String cloudName = "dnthfbpe7";
    const String uploadPreset = "Grocery app";

    Uri url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );
    var request = http.MultipartRequest("POST", url);

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
    );

    try {
      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var result = json.decode(String.fromCharCodes(responseData));

      if (response.statusCode == 200) {
        String secureUrl = result['secure_url'];

        await _settingsRef.set({
          'profileImageUrl': secureUrl,
        }, SetOptions(merge: true));

        setState(() {
          _profileImageUrl = secureUrl;
        });

        // Force refresh dashboard data
        await _settingsRef.get();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("লোগো সফলভাবে আপলোড হয়েছে!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint("Cloudinary Upload Error: ${result['error']['message']}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("ছবি আপলোডে সমস্যা হয়েছে!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("লগআউট", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("আপনি কি সত্যিই লগআউট করতে চান?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("না", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber[800], size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber[800]!, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ইউজারের লগইন করা জিমেইল নেওয়া হচ্ছে
    final String userEmail =
        FirebaseAuth.instance.currentUser?.email ?? "No Email";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          "সেটিংস",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("দোকানের তথ্য", Icons.storefront_rounded),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingImage ? null : _pickImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 75,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : (_imageBytes != null
                                      ? MemoryImage(_imageBytes!)
                                            as ImageProvider
                                      : null),
                            child:
                                _profileImageUrl == null && _imageBytes == null
                                ? Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 40,
                                    color: Colors.grey[400],
                                  )
                                : null,
                          ),
                          if (_isUploadingImage)
                            const Positioned.fill(
                              child: CircularProgressIndicator(
                                color: Colors.amber,
                                strokeWidth: 5,
                              ),
                            ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isUploadingImage
                                    ? Colors.grey
                                    : Colors.amber[800],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // আপডেট: ইউজারের জিমেইল দেখানো হচ্ছে
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      "দোকানের নাম",
                      _shopNameController,
                      Icons.store,
                    ),
                    _buildTextField(
                      "মালিকের নাম",
                      _ownerNameController,
                      Icons.person,
                    ),
                    _buildTextField(
                      "মোবাইল নাম্বার",
                      _phoneController,
                      Icons.phone,
                      type: TextInputType.phone,
                    ),
                    _buildTextField(
                      "দোকানের ঠিকানা",
                      _addressController,
                      Icons.location_on,
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isLoading ? null : _saveSettings,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "সেভ করুন",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  "লগআউট করুন",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
