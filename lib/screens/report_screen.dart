import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;

  // ওপরের কার্ডের জন্য ভেরিয়েবল
  double todaySales = 0.0;
  double monthlySales = 0.0;
  double todayProfit = 0.0;
  double monthlyProfit = 0.0;

  // মাসের সিরিয়াল লিস্টের জন্য ভেরিয়েবল
  List<Map<String, dynamic>> monthlyHistoryList = [];

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
    _generateReport();
  }

  // ইংরেজি সংখ্যাকে বাংলায় কনভার্ট করার ফাংশন
  String _toBanglaDigit(String number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      number = number.replaceAll(english[i], bangla[i]);
    }
    return number;
  }

  // ফায়ারবেস থেকে ডেটা এনে রিপোর্ট তৈরি করার ফাংশন
  void _generateReport() async {
    try {
      setState(() => isLoading = true);

      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);

      QuerySnapshot salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .orderBy('timestamp', descending: true)
          .get();

      double tSales = 0.0;
      double mSales = 0.0;
      double tProfit = 0.0;
      double mProfit = 0.0;
      monthlyHistoryList.clear(); // লিস্ট ক্লিয়ার করে নেওয়া হলো

      Map<String, Map<String, dynamic>> groupedData = {};

      for (var doc in salesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['timestamp'] == null) continue;

        DateTime saleDate = (data['timestamp'] as Timestamp).toDate();
        // Null Safety যুক্ত করা হলো
        double saleAmount = data['totalAmount'] != null
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;

        double saleProfit = 0.0;
        List items = data['items'] ?? [];
        for (var item in items) {
          // পুরোনো ডেটায় কোনো কিছু মিসিং থাকলে অ্যাপ যেন হ্যাং না হয়
          double buyPrice = item['buyPrice'] != null
              ? (item['buyPrice'] as num).toDouble()
              : 0.0;
          double sellPrice = item['sellPrice'] != null
              ? (item['sellPrice'] as num).toDouble()
              : 0.0;
          int qty = item['qty'] != null ? (item['qty'] as num).toInt() : 0;

          saleProfit += (sellPrice - buyPrice) * qty;
        }

        if (saleDate.isAfter(startOfToday) ||
            saleDate.isAtSameMomentAs(startOfToday)) {
          tSales += saleAmount;
          tProfit += saleProfit;
        }

        if (saleDate.year == now.year && saleDate.month == now.month) {
          mSales += saleAmount;
          mProfit += saleProfit;
        }

        String monthKey =
            "${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}";

        if (!groupedData.containsKey(monthKey)) {
          groupedData[monthKey] = {
            'sales': 0.0,
            'profit': 0.0,
            'month': saleDate.month,
            'year': saleDate.year,
          };
        }
        groupedData[monthKey]!['sales'] =
            (groupedData[monthKey]!['sales'] ?? 0) + saleAmount;
        groupedData[monthKey]!['profit'] =
            (groupedData[monthKey]!['profit'] ?? 0) + saleProfit;
      }

      groupedData.forEach((key, value) {
        monthlyHistoryList.add({
          'key': key,
          'displayMonth':
              "${banglaMonths[value['month'] - 1]} ${_toBanglaDigit(value['year'].toString())}",
          'sales': value['sales'],
          'profit': value['profit'],
          'month': value['month'],
          'year': value['year'],
        });
      });

      monthlyHistoryList.sort((a, b) => b['key'].compareTo(a['key']));

      if (mounted) {
        setState(() {
          todaySales = tSales;
          monthlySales = mSales;
          todayProfit = tProfit;
          monthlyProfit = mProfit;
          isLoading = false;
        });
      }
    } catch (e) {
      // যদি কোনো কারণে এরর আসে, তাহলে লোডিং বন্ধ করে ইউজারকে মেসেজ দেখাবে
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ডেটা লোড করতে সমস্যা হয়েছে, ডেটাবেস চেক করুন।"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ১. ইউজার থেকে পারমিশন নেওয়ার পপ-আপ (Dialog)
  void _confirmDeleteMonth(int year, int month, String displayMonth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "ডেটা মুছে ফেলবেন?",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "আপনি কি নিশ্চিত যে $displayMonth-এর সব বিক্রির রেকর্ড মুছে ফেলতে চান?\n\nএকবার মুছে ফেললে এটি আর ফিরিয়ে আনা সম্ভব নয়।",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "বাতিল",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context); // ডায়লগ বন্ধ করবে
              _deleteDataForMonth(year, month); // ডিলিট ফাংশন কল করবে
            },
            child: const Text(
              "হ্যাঁ, মুছে ফেলুন",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ২. নির্দিষ্ট মাসের ডেটা ফায়ারবেস থেকে মুছে ফেলার লজিক
  void _deleteDataForMonth(int year, int month) async {
    setState(() => isLoading = true);

    DateTime startOfMonth = DateTime(year, month, 1);
    // পরের মাসের ১ তারিখ বের করা (যাতে এই মাসের শেষ দিন পর্যন্ত কাভার হয়)
    DateTime endOfMonth = (month < 12)
        ? DateTime(year, month + 1, 1)
        : DateTime(year + 1, 1, 1);

    // ফায়ারবেস থেকে ওই নির্দিষ্ট মাসের ডেটাগুলো ফিল্টার করে আনা
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    // লুপ চালিয়ে সব ডকুমেন্ট ডিলিট করা
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ওই মাসের সব ডেটা সফলভাবে মুছে ফেলা হয়েছে!"),
          backgroundColor: Colors.green,
        ),
      );
      _generateReport(); // ডিলিট হওয়ার পর লিস্ট রিফ্রেশ করা
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "রিপোর্ট ও হিসাব",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "সামারি",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportCard(
                          "আজকের বিক্রি",
                          todaySales,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportCard(
                          "আজকের লাভ",
                          todayProfit,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportCard(
                          "এই মাসের বিক্রি",
                          monthlySales,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportCard(
                          "এই মাসের লাভ",
                          monthlyProfit,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "মাসিক হিসাব (সিরিয়াল অনুযায়ী)",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  monthlyHistoryList.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              "এখনো কোনো পূর্ববর্তী রেকর্ড নেই।",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: monthlyHistoryList.length,
                          itemBuilder: (context, index) {
                            var data = monthlyHistoryList[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey.withOpacity(
                                    0.1,
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                title: Text(
                                  data['displayMonth'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        "বিক্রি: ৳${_toBanglaDigit(data['sales'].toString())}",
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Text(
                                        "লাভ: ৳${_toBanglaDigit(data['profit'].toString())}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ডিলিট আইকন যুক্ত করা হলো
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: "এই মাসের ডেটা মুছুন",
                                  onPressed: () {
                                    _confirmDeleteMonth(
                                      data['year'],
                                      data['month'],
                                      data['displayMonth'],
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(bottom: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "৳${_toBanglaDigit(amount.toString())}",
            style: TextStyle(
              fontSize: 22,
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
