//Paikari product/stock history

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // আইডি দিয়ে পণ্যের নাম বের করার জন্য একটি Map
  Map<String, String> _productNames = {};
  bool _isLoadingProducts = true;

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

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  // ফায়ারবেস থেকে সব পণ্যের নাম একবার লোড করে নেওয়া হচ্ছে
  Future<void> _loadProductNames() async {
    try {
      // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে products কালেকশন লোড করা হচ্ছে
      String uid = FirebaseAuth.instance.currentUser!.uid;
      QuerySnapshot productsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('products')
          .get();

      Map<String, String> tempNames = {};
      for (var doc in productsSnapshot.docs) {
        tempNames[doc.id] = doc['name'] ?? 'অজানা পণ্য';
      }
      if (mounted) {
        setState(() {
          _productNames = tempNames;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  // স্টক সুন্দরভাবে দেখানোর জন্য হেল্পার ফাংশন
  String _formatStock(double stock) {
    return stock == stock.toInt() ? stock.toInt().toString() : stock.toString();
  }

  @override
  Widget build(BuildContext context) {
    // সিলেক্ট করা মাস এবং বছর অনুযায়ী ডেট রেঞ্জ তৈরি করা
    DateTime startOfMonth = DateTime(selectedYear, selectedMonth, 1);
    DateTime endOfMonth = selectedMonth < 12
        ? DateTime(selectedYear, selectedMonth + 1, 1)
        : DateTime(selectedYear + 1, 1, 1);

    Timestamp startTimestamp = Timestamp.fromDate(startOfMonth);
    Timestamp endTimestamp = Timestamp.fromDate(endOfMonth);

    // আপডেট: StreamBuilder-এর জন্য ইউজারের uid নেওয়া হচ্ছে
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "স্টক হিস্ট্রি (ইনভেন্টরি)",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // মাস এবং বছর সিলেক্ট করার অপশন
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            underline: const SizedBox(),
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
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
                                setState(() {
                                  selectedMonth = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<int>(
                            value: selectedYear,
                            underline: const SizedBox(),
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
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
                                setState(() {
                                  selectedYear = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে purchase_history কালেকশন কল করা হচ্ছে
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('purchase_history')
                        .where(
                          'timestamp',
                          isGreaterThanOrEqualTo: startTimestamp,
                        )
                        .where('timestamp', isLessThan: endTimestamp)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // যদি ডেটা না থাকে বা সব প্রোডাক্ট ডিলিট হয়ে গিয়ে থাকে
                      var docs =
                          snapshot.data?.docs.where((doc) {
                            return _productNames.containsKey(
                              doc['productId'],
                            ); // শুধুমাত্র ঐ প্রোডাক্টগুলো দেখাবে যেগুলো এখনো লিস্টে আছে
                          }).toList() ??
                          [];

                      if (docs.isEmpty) {
                        return Column(
                          children: [
                            // 0 টাকার সামারি কার্ড
                            _buildSummaryCard(0),
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "এই মাসে কোনো স্টক হিস্ট্রি নেই।",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      // মোট ইনভেস্টমেন্ট বা খরচের হিসাব
                      double totalInvestment = 0;
                      for (var doc in docs) {
                        double price =
                            (doc['buyPrice'] as num?)?.toDouble() ?? 0.0;
                        double qty =
                            (doc['qty'] as num?)?.toDouble() ??
                            0.0; // qty এখন double
                        totalInvestment += (price * qty);
                      }

                      return Column(
                        children: [
                          // ইনভেস্টমেন্ট সামারি কার্ড
                          _buildSummaryCard(totalInvestment),

                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "কেনার বিস্তারিত বিবরণ:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                          ),

                          // হিস্ট্রি লিস্ট
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                var doc = docs[index];
                                String productId = doc['productId'] ?? '';
                                double qty =
                                    (doc['qty'] as num?)?.toDouble() ??
                                    0.0; // qty এখন double
                                double buyPrice =
                                    (doc['buyPrice'] as num?)?.toDouble() ??
                                    0.0;
                                String unit =
                                    (doc.data() as Map<String, dynamic>)
                                        .containsKey('unit')
                                    ? doc['unit']
                                    : 'পিস'; // ইউনিট ডাটাবেস থেকে, না থাকলে 'পিস'

                                double totalCost = qty * buyPrice;
                                DateTime date =
                                    (doc['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now();

                                String productName =
                                    _productNames[productId] ?? 'অজানা পণ্য';

                                // BD Time ফরম্যাট (১২ ঘন্টা ফরম্যাট)
                                String amPm = date.hour >= 12 ? 'PM' : 'AM';
                                int hour = date.hour > 12
                                    ? date.hour - 12
                                    : (date.hour == 0 ? 12 : date.hour);
                                String minute = date.minute.toString().padLeft(
                                  2,
                                  '0',
                                );
                                String formattedTime = "$hour:$minute $amPm";

                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.teal
                                              .withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.inventory,
                                            color: Colors.teal,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF2C3E50),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                "পরিমাণ: ${_formatStock(qty)} $unit  |  দাম: ৳${_formatStock(buyPrice)}/$unit",
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${date.day}/${date.month}/${date.year}  $formattedTime",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              "মোট খরচ",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              "৳${_formatStock(totalCost)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.redAccent[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // সামারি কার্ড উইজেট আলাদা করা হয়েছে
  Widget _buildSummaryCard(double totalInvestment) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[700]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.white70,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "পাইকারি কেনায় মোট খরচ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "৳${_formatStock(totalInvestment)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
