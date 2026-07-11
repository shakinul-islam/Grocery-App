import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_screen.dart';
import 'sales_screen.dart';
import 'due_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'expense_screen.dart';
import 'inventory_screen.dart';
import 'detailed_sales_history.dart';
import 'notes_screen.dart';
import 'calculator_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double monthlyCashSales = 0.0;
  double monthlyDueSales = 0.0;
  double monthlyProfit = 0.0;
  double totalDue = 0.0;

  // মাস এবং বছরের জন্য ভেরিয়েবল
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  final List<String> banglaMonths = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  StreamSubscription<QuerySnapshot>? _salesSubscription;
  StreamSubscription<QuerySnapshot>? _customerSubscription;

  @override
  void initState() {
    super.initState();
    _fetchRealTimeSummary();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    _customerSubscription?.cancel();
    super.dispose();
  }

  void _fetchRealTimeSummary() {
    _salesSubscription?.cancel();

    DateTime startOfMonth = DateTime(selectedYear, selectedMonth, 1);
    DateTime endOfMonth = selectedMonth < 12
        ? DateTime(selectedYear, selectedMonth + 1, 1)
        : DateTime(selectedYear + 1, 1, 1);

    Timestamp startTimestamp = Timestamp.fromDate(startOfMonth);
    Timestamp endTimestamp = Timestamp.fromDate(endOfMonth);

    // ১. এই মাসের নগদ, বাকি বিক্রি এবং লাভের হিসাব
    _salesSubscription = FirebaseFirestore.instance
        .collection('sales')
        .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
        .where('timestamp', isLessThan: endTimestamp)
        .snapshots()
        .listen((snapshot) {
          double tempCash = 0.0;
          double tempDue = 0.0;
          double tempProfit = 0.0;

          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            // নগদ ও বাকি আলাদা করা
            if (data['paymentType'] == 'নগদ') {
              tempCash += (data['totalAmount'] as num).toDouble();
            } else if (data['paymentType'] == 'বাকি') {
              tempDue += (data['totalAmount'] as num).toDouble();
            }

            // লাভ হিসাব করা
            List items = data['items'] ?? [];
            for (var item in items) {
              double buyPrice = (item['buyPrice'] as num?)?.toDouble() ?? 0.0;
              double sellPrice = (item['sellPrice'] as num?)?.toDouble() ?? 0.0;
              double qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
              tempProfit += (sellPrice - buyPrice) * qty;
            }
          }
          if (mounted) {
            setState(() {
              monthlyCashSales = tempCash;
              monthlyDueSales = tempDue;
              monthlyProfit = tempProfit;
            });
          }
        });

    // ২. মোট বকেয়ার হিসাব (সব কাস্টমার মিলে)
    if (_customerSubscription == null) {
      _customerSubscription = FirebaseFirestore.instance
          .collection('customers')
          .snapshots()
          .listen((snapshot) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.account_circle,
            size: 30,
          ), // প্রোফাইল পিকচার আইকন
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('shop_info')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text(
                "দোকানের ড্যাশবোর্ড",
                style: TextStyle(fontSize: 16),
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
                    letterSpacing: 0.5,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ১. মাস এবং বছর সিলেক্ট করার অপশন
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: selectedMonth,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.indigo,
                          size: 20,
                        ),
                        items: List.generate(
                          12,
                          (index) => DropdownMenuItem<int>(
                            value: index + 1,
                            child: Text(banglaMonths[index]),
                          ),
                        ),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() => selectedMonth = newValue);
                            _fetchRealTimeSummary();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.indigo,
                          size: 24,
                        ),
                        items: List.generate(16, (index) {
                          int year = 2020 + index;
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() => selectedYear = newValue);
                            _fetchRealTimeSummary();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ২. ৪টি সামারি কার্ড
              Expanded(
                flex: 32,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildFlexibleSummaryCard(
                            title: "নগদ বিক্রি",
                            amount: "৳${monthlyCashSales.toStringAsFixed(0)}",
                            color: Colors.teal,
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                          _buildFlexibleSummaryCard(
                            title: "বাকি বিক্রি",
                            amount: "৳${monthlyDueSales.toStringAsFixed(0)}",
                            color: Colors.orange[700]!,
                            icon: Icons.hourglass_bottom_rounded,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildFlexibleSummaryCard(
                            title: "মোট লাভ",
                            amount: "৳${monthlyProfit.toStringAsFixed(0)}",
                            color: Colors.green[600]!,
                            icon: Icons.trending_up_rounded,
                          ),
                          _buildFlexibleSummaryCard(
                            title: "মোট বকেয়া",
                            amount: "৳${totalDue.toStringAsFixed(0)}",
                            color: Colors.redAccent[700]!,
                            icon: Icons.money_off_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(
                  "কুইক মেন্যু",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ৩. কুইক মেন্যু গ্রিড (৯টি আইটেম)
              Expanded(
                flex: 50,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildFlexibleMenuButton(
                            icon: Icons.point_of_sale_rounded,
                            title: "বিক্রয় করুন",
                            color: Colors.blue[600]!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SalesScreen(),
                              ),
                            ),
                          ),
                          _buildFlexibleMenuButton(
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
                          _buildFlexibleMenuButton(
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
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildFlexibleMenuButton(
                            icon: Icons.history_edu_rounded,
                            title: "স্টক হিস্ট্রি",
                            color: Colors.brown[600]!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const InventoryScreen(),
                              ),
                            ),
                          ),
                          _buildFlexibleMenuButton(
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
                          _buildFlexibleMenuButton(
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
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildFlexibleMenuButton(
                            icon: Icons.receipt_long_rounded,
                            title: "সেলস হিস্ট্রি",
                            color: Colors.indigo[500]!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DetailedSalesHistoryScreen(),
                              ),
                            ),
                          ),
                          _buildFlexibleMenuButton(
                            icon: Icons.edit_note_rounded,
                            title: "নোটস",
                            color: Colors.amber[700]!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotesScreen(),
                              ),
                            ),
                          ),
                          _buildFlexibleMenuButton(
                            icon: Icons.calculate_rounded,
                            title: "ক্যালকুলেটর",
                            color: Colors.pink[500]!,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CalculatorScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ফ্লেক্সিবল সামারি কার্ড ডিজাইন (ওভারফ্লো ফিক্স করা হয়েছে)
  Widget _buildFlexibleSummaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5.0),
        padding: const EdgeInsets.all(10.0), // প্যাডিং কমানো হয়েছে
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ), // Spacer এর বদলে SizedBox এবং Expanded ব্যবহার
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      fontSize: 20,
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ফ্লেক্সিবল মেন্যু বাটন ডিজাইন
  Widget _buildFlexibleMenuButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34495E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
