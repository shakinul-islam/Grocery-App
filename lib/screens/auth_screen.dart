import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart'; // আপনার ড্যাশবোর্ড স্ক্রিন

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isLoginMode = true; // true = Login, false = Register
  bool _isPasswordVisible = false; // পাসওয়ার্ড শো/হাইড করার জন্য

  // ১. লগইন বা রেজিস্ট্রেশন করার ফাংশন
  void _submitAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMsg("ইমেইল এবং পাসওয়ার্ড দিন");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // লগইন লজিক
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showMsg("লগইন সফল হয়েছে!");
      } else {
        // নতুন রেজিস্ট্রেশন লজিক
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showMsg("রেজিস্ট্রেশন সফল হয়েছে!");
      }
      _goToDashboard();
    } on FirebaseAuthException catch (e) {
      // ইউজারকে সহজ ভাষায় এরর বোঝানোর জন্য
      if (e.code == 'email-already-in-use') {
        _showMsg("এই ইমেইল দিয়ে আগেই অ্যাকাউন্ট খোলা আছে।");
      } else if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        _showMsg("ইমেইল বা পাসওয়ার্ড ভুল।");
      } else if (e.code == 'weak-password') {
        _showMsg("পাসওয়ার্ড অন্তত ৬ অক্ষরের হতে হবে।");
      } else if (e.code == 'invalid-email') {
        _showMsg("সঠিক ইমেইল অ্যাড্রেস দিন।");
      } else {
        _showMsg("Error: ${e.message}");
      }
    }

    setState(() => _isLoading = false);
  }

  // ২. জিমেইলে পাসওয়ার্ড রিসেট লিংক পাঠানোর ফাংশন
  void _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showMsg(
        "পাসওয়ার্ড রিসেট করতে ওপরের ঘরে আপনার ইমেইলটি লিখুন, তারপর এখানে ক্লিক করুন।",
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showMsg(
        "আপনার ইমেইলে পাসওয়ার্ড রিসেট করার একটি লিংক পাঠানো হয়েছে। ইনবক্স বা স্প্যাম ফোল্ডার চেক করুন!",
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showMsg("এই ইমেইলের কোনো অ্যাকাউন্ট নেই।");
      } else {
        _showMsg("Error: ${e.message}");
      }
    }
    setState(() => _isLoading = false);
  }

  // Helper Functions
  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.indigo[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F7FC,
      ), // স্মার্ট অফ-হোয়াইট ব্যাকগ্রাউন্ড
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // লোগো বা আইকন ডিজাইন
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 60,
                      color: Colors.indigo[600],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // হেডার টেক্সট
                Text(
                  _isLoginMode ? "স্বাগতম!" : "অ্যাকাউন্ট খুলুন",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C3E50),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode
                      ? "লগইন করে আপনার দোকানের হিসাব রাখুন"
                      : "আপনার ব্যবসার হিসাব রাখতে যুক্ত হোন",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // ইনপুট ফিল্ড কন্টেইনার (কার্ড স্টাইল)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Email Field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "ইমেইল অ্যাড্রেস",
                          hintText: "example@gmail.com",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.indigo[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.indigo.shade400,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: "পাসওয়ার্ড",
                          hintText: "অন্তত ৬ অক্ষরের পাসওয়ার্ড",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.indigo[400],
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.indigo.shade400,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // Forgot Password Button
                      if (_isLoginMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 0,
                                right: 0,
                              ),
                              foregroundColor: Colors.indigo[600],
                            ),
                            child: const Text(
                              "পাসওয়ার্ড ভুলে গেছেন?",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (!_isLoginMode) const SizedBox(height: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Main Action Button (লগইন বা রেজিস্ট্রেশন)
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submitAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isLoginMode ? "লগইন করুন" : "রেজিস্ট্রেশন করুন",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 24),

                // Toggle between Login and Register Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoginMode ? "অ্যাকাউন্ট নেই? " : "অ্যাকাউন্ট আছে? ",
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _emailController.clear();
                          _passwordController.clear();
                          _isPasswordVisible = false;
                        });
                      },
                      child: Text(
                        _isLoginMode ? "নতুন অ্যাকাউন্ট খুলুন" : "লগইন করুন",
                        style: TextStyle(
                          color: Colors.indigo[700],
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
