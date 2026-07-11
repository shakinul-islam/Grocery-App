import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;

  double todaySales = 0.0;
  double monthlySales = 0.0;
  double todayProfit = 0.0;
  double monthlyProfit = 0.0;
  double monthlyExpense = 0.0;
  double monthlyCost = 0.0; // ক্রয়মূল্য

  // মাস এবং বছরের জন্য ভেরিয়েবল (ফিল্টার)
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
    _generateReport();
  }

  String _toBanglaDigit(String number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    for (int i = 0; i < english.length; i++) {
      number = number.replaceAll(english[i], bangla[i]);
    }
    return number;
  }

  void _generateReport() async {
    try {
      setState(() => isLoading = true);

      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);

      // সিলেক্ট করা মাস ও বছর অনুযায়ী সময় নির্ধারণ
      DateTime startOfSelectedMonth = DateTime(selectedYear, selectedMonth, 1);
      DateTime endOfSelectedMonth = selectedMonth < 12
          ? DateTime(selectedYear, selectedMonth + 1, 1)
          : DateTime(selectedYear + 1, 1, 1);

      // ১. বিক্রির ডেটা আনা
      QuerySnapshot salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .get();

      // ২. খরচের ডেটা আনা (সিলেক্ট করা মাসের জন্য)
      QuerySnapshot expenseSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfSelectedMonth),
          )
          .where(
            'timestamp',
            isLessThan: Timestamp.fromDate(endOfSelectedMonth),
          )
          .get();

      double tSales = 0.0,
          mSales = 0.0,
          tProfit = 0.0,
          mProfit = 0.0,
          mExpense = 0.0,
          mCost = 0.0;

      // খরচ ক্যালকুলেশন
      for (var doc in expenseSnapshot.docs) {
        mExpense +=
            (doc.data() as Map<String, dynamic>)['amount'] as num? ?? 0.0;
      }

      // বিক্রি, লাভ ও ক্রয়মূল্য ক্যালকুলেশন
      for (var doc in salesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] == null) continue;

        DateTime saleDate = (data['timestamp'] as Timestamp).toDate();
        double saleAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

        double saleProfit = 0.0;
        double saleCost = 0.0;
        List items = data['items'] ?? [];
        for (var item in items) {
          double buyPrice = (item['buyPrice'] as num?)?.toDouble() ?? 0.0;
          double sellPrice = (item['sellPrice'] as num?)?.toDouble() ?? 0.0;
          double qty = (item['qty'] as num?)?.toDouble() ?? 0.0;

          saleProfit += (sellPrice - buyPrice) * qty;
          saleCost += (buyPrice * qty);
        }

        // আজকের হিসাব (সবসময় রিয়েল-টাইম আজকের দিন ট্র্যাক করবে)
        if (saleDate.isAfter(startOfToday) ||
            saleDate.isAtSameMomentAs(startOfToday)) {
          tSales += saleAmount;
          tProfit += saleProfit;
        }

        // সিলেক্ট করা মাসের হিসাব
        if (saleDate.year == selectedYear && saleDate.month == selectedMonth) {
          mSales += saleAmount;
          mProfit += saleProfit;
          mCost += saleCost;
        }
      }

      if (mounted) {
        setState(() {
          todaySales = tSales;
          monthlySales = mSales;
          todayProfit = tProfit;
          monthlyProfit = mProfit;
          monthlyExpense = mExpense;
          monthlyCost = mCost;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double netProfit = monthlyProfit - monthlyExpense;

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
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ১. মাস এবং বছর সিলেক্ট করার অপশন (Fixed Height)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueGrey.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: DropdownButton<int>(
                              value: selectedMonth,
                              isExpanded: true,
                              underline: const SizedBox(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                              icon: const Icon(
                                Icons.calendar_month,
                                color: Colors.blueGrey,
                                size: 18,
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
                                  _generateReport();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueGrey.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: DropdownButton<int>(
                              value: selectedYear,
                              isExpanded: true,
                              underline: const SizedBox(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down_circle,
                                color: Colors.blueGrey,
                                size: 18,
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
                                  _generateReport();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ২. সামারি কার্ডস গ্রিড (Expanded Layout)
                    Expanded(
                      flex: 32, // স্ক্রিনের সাইজ অনুযায়ী জায়গা নেবে
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 2.4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildReportCard(
                            "আজকের বিক্রি",
                            todaySales,
                            Colors.blue,
                          ),
                          _buildReportCard(
                            "আজকের লাভ",
                            todayProfit,
                            Colors.green,
                          ),
                          _buildReportCard(
                            "এই মাসের বিক্রি",
                            monthlySales,
                            Colors.indigo,
                          ),
                          _buildReportCard(
                            "এই মাসের খরচ",
                            monthlyExpense,
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ৩. ডোনাট চার্ট প্যানেল (Expanded Layout)
                    Expanded(
                      flex: 55, // স্ক্রিনের মেইন বড় অংশ চার্টকে দেওয়া হয়েছে
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.08),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${banglaMonths[selectedMonth - 1]}-এর আর্থিক বিশ্লেষণ",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  // ডোনাট চার্ট উইথ সেন্টার নিট লাভ টেক্সট
                                  Expanded(
                                    flex: 55,
                                    child: Stack(
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 50,
                                            sections: [
                                              PieChartSectionData(
                                                value: monthlyCost > 0
                                                    ? monthlyCost
                                                    : 1,
                                                color: Colors.orange[400]!,
                                                radius: 25,
                                                showTitle: false,
                                              ),
                                              PieChartSectionData(
                                                value: monthlyProfit > 0
                                                    ? monthlyProfit
                                                    : 1,
                                                color: Colors.green[500]!,
                                                radius: 25,
                                                showTitle: false,
                                              ),
                                              PieChartSectionData(
                                                value: monthlyExpense > 0
                                                    ? monthlyExpense
                                                    : 1,
                                                color: Colors.redAccent[400]!,
                                                radius: 25,
                                                showTitle: false,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                "নিট লাভ",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                      ),
                                                  child: Text(
                                                    "৳${_toBanglaDigit(netProfit.toStringAsFixed(0))}",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: netProfit >= 0
                                                          ? Colors.teal[700]
                                                          : Colors.red,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // প্রফেশনাল লেজেন্ড সাইড প্যানেল
                                  Expanded(
                                    flex: 45,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLegendIndicator(
                                          Colors.orange[400]!,
                                          "বিক্রি হওয়া পণ্যের ক্রয়মূল্য",
                                          monthlyCost,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildLegendIndicator(
                                          Colors.green[500]!,
                                          "বিক্রি হওয়া পণ্য থেকে প্রাপ্ত মোট লাভ",
                                          monthlyProfit,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildLegendIndicator(
                                          Colors.redAccent[400]!,
                                          "মাসিক মোট খরচ",
                                          monthlyExpense,
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
                  ],
                ),
              ),
            ),
    );
  }

  // লেজেন্ড আইটেম মেকার
  Widget _buildLegendIndicator(Color color, String title, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 2),
          child: Text(
            "৳${_toBanglaDigit(amount.toStringAsFixed(0))}",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // সামারি কার্ড মেকার
  Widget _buildReportCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "৳${_toBanglaDigit(amount.toStringAsFixed(0))}",
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
