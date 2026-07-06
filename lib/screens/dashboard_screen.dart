import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_screen.dart';
import 'sales_screen.dart';
import 'due_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double todaySales = 0.0;
  double todayDue = 0.0;
  double totalDue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchRealTimeSummary();
  }

  void _fetchRealTimeSummary() {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);
    Timestamp todayTimestamp = Timestamp.fromDate(startOfToday);

    // ১. আজকের বিক্রির হিসাব
    FirebaseFirestore.instance
        .collection('sales')
        .where('timestamp', isGreaterThanOrEqualTo: todayTimestamp)
        .snapshots()
        .listen((snapshot) {
          double tempCash = 0.0;
          double tempDue = 0.0;
          for (var doc in snapshot.docs) {
            if (doc['paymentType'] == 'Cash') {
              tempCash += (doc['totalAmount'] as num).toDouble();
            } else if (doc['paymentType'] == 'Due') {
              tempDue += (doc['totalAmount'] as num).toDouble();
            }
          }
          if (mounted) {
            setState(() {
              todaySales = tempCash;
              todayDue = tempDue;
            });
          }
        });

    // ২. মোট বকেয়ার হিসাব
    FirebaseFirestore.instance.collection('customers').snapshots().listen((
      snapshot,
    ) {
      double tempTotalDue = 0.0;
      for (var doc in snapshot.docs) {
        tempTotalDue += (doc['dueAmount'] as num).toDouble();
      }
      if (mounted) {
        setState(() {
          totalDue = tempTotalDue;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        elevation: 0,
        // বামপাশে সেটিংসে যাওয়ার আইকন
        leading: IconButton(
          icon: const Icon(Icons.person_pin, size: 28),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        // শপ এবং ওনার নেম লাইভ আপডেট
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('shop_info')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text(
                "দোকানের ড্যাশবোর্ড",
                style: TextStyle(fontSize: 18),
              );
            }
            var data = snapshot.data!.data() as Map<String, dynamic>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['shopName'] ?? "দোকানের নাম",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  data['ownerName'] ?? "মালিক",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "আজকের সামারি",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: "নগদ বিক্রি",
                      amount: "৳$todaySales",
                      color: Colors.teal,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: "আজকের বাকি",
                      amount: "৳$todayDue",
                      color: Colors.orange[700]!,
                      icon: Icons.hourglass_bottom_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                title: "মোট বকেয়া (সব কাস্টমার)",
                amount: "৳$totalDue",
                color: Colors.redAccent[700]!,
                icon: Icons.money_off_outlined,
                isFullWidth: true,
              ),

              const SizedBox(height: 32),
              const Text(
                "কুইক মেন্যু",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildMenuButton(
                    icon: Icons.point_of_sale_rounded,
                    title: "দ্রুত বিক্রি (POS)",
                    color: Colors.blue[600]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesScreen(),
                      ),
                    ),
                  ),
                  _buildMenuButton(
                    icon: Icons.menu_book_rounded,
                    title: "বাকি খাতা",
                    color: Colors.deepPurple[500]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DueScreen(),
                      ),
                    ),
                  ),
                  _buildMenuButton(
                    icon: Icons.inventory_2_rounded,
                    title: "পণ্য তালিকা",
                    color: Colors.teal[600]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductScreen(),
                      ),
                    ),
                  ),
                  _buildMenuButton(
                    icon: Icons.analytics_rounded,
                    title: "রিপোর্ট",
                    color: Colors.blueGrey[700]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportScreen(),
                      ),
                    ),
                  ),
                  _buildMenuButton(
                    icon: Icons.account_balance_wallet_rounded,
                    title: "খরচ",
                    color: Colors.redAccent[400]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExpenseScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: isFullWidth ? 24 : 20,
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34495E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
