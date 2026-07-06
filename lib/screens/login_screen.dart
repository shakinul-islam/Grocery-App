import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart'; // ড্যাশবোর্ড স্ক্রিন ইমপোর্ট করা হয়েছে

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _verificationId = "";
  bool _isLoading = false;

  // ১. ফায়ারবেসের মাধ্যমে OTP পাঠানোর ফাংশন
  void _sendOTP() async {
    setState(() {
      _isLoading = true;
    });

    String phoneNumber = "+880${_phoneController.text.trim()}";

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // অটোমেটিক ভেরিফিকেশন হলে (কিছু কিছু ডিভাইসে হয়)
        await _auth.signInWithCredential(credential);
        _goToDashboard();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _isLoading = false;
          _verificationId = verificationId;
        });
        // OTP সফলভাবে পাঠানো হলে পপ-আপ দেখাবে
        _showOTPDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ২. পপ-আপ (Dialog) যেখানে ইউজার ৬ ডিজিটের কোডটি বসাবে
  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("OTP দিন"),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: "6-digit OTP কোডটি লিখুন",
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // ৩. OTP ভেরিফাই করার ফাংশন
              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: _verificationId,
                  smsCode: _otpController.text.trim(),
                );
                await _auth.signInWithCredential(credential);
                Navigator.pop(context); // পপ-আপ বন্ধ করবে
                _goToDashboard(); // ড্যাশবোর্ডে নিয়ে যাবে
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("ভুল OTP দিয়েছেন!")),
                );
              }
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  // ৪. লগইন সফল হলে ড্যাশবোর্ডে যাওয়ার ফাংশন
  void _goToDashboard() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("লগইন সফল হয়েছে!")));

    // ড্যাশবোর্ডে নিয়ে যাওয়ার আসল কোড
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "দোকানের হিসাব",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "লগইন করতে আপনার মোবাইল নম্বর দিন",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixText: "+880 ",
                  prefixStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  labelText: "মোবাইল নম্বর",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _sendOTP,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "OTP পাঠান",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),

              const Spacer(),
              const Text(
                "Made with ❤️ by Shakinul",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
