import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetailedSalesHistoryScreen extends StatefulWidget {
  const DetailedSalesHistoryScreen({super.key});

  @override
  State<DetailedSalesHistoryScreen> createState() =>
      _DetailedSalesHistoryScreenState();
}

class _DetailedSalesHistoryScreenState
    extends State<DetailedSalesHistoryScreen> {
  // ডিফল্ট ফিল্টার 'আজ' সেট করা হলো
  String _selectedFilter = 'আজ';
  final List<String> _filters = ['আজ', 'এই মাস', 'এই বছর', 'নির্দিষ্ট তারিখ'];

  // ক্যালেন্ডার থেকে বাছাই করা তারিখ
  DateTime? _selectedSpecificDate;

  // ক্যালেন্ডার ওপেন করার ফাংশন
  Future<void> _pickDate(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedSpecificDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueGrey[800]!, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.blueGrey[900]!, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedSpecificDate = picked;
        _selectedFilter = 'নির্দিষ্ট তারিখ';
      });
    } else {
      // যদি ইউজার ক্যানসেল করে দেয়
      if (_selectedFilter == 'নির্দিষ্ট তারিখ' &&
          _selectedSpecificDate == null) {
        setState(() {
          _selectedFilter = 'আজ';
        });
      }
    }
  }

  // ফিল্টার অনুযায়ী শুরুর তারিখ বের করার লজিক
  DateTime _getStartDate() {
    DateTime now = DateTime.now();
    if (_selectedFilter == 'আজ') {
      return DateTime(now.year, now.month, now.day);
    } else if (_selectedFilter == 'এই মাস') {
      return DateTime(now.year, now.month, 1);
    } else if (_selectedFilter == 'এই বছর') {
      return DateTime(now.year, 1, 1);
    } else if (_selectedFilter == 'নির্দিষ্ট তারিখ' &&
        _selectedSpecificDate != null) {
      return DateTime(
        _selectedSpecificDate!.year,
        _selectedSpecificDate!.month,
        _selectedSpecificDate!.day,
      );
    }
    return DateTime(now.year, now.month, now.day);
  }

  // ফিল্টার অনুযায়ী শেষ তারিখ বের করার লজিক (যাতে নির্দিষ্ট দিনের বা মাসের একদম শেষ পর্যন্ত ডাটা আসে)
  DateTime _getEndDate() {
    DateTime start = _getStartDate();
    if (_selectedFilter == 'আজ' || _selectedFilter == 'নির্দিষ্ট তারিখ') {
      return start.add(const Duration(days: 1)); // পরের দিনের রাত ১২টা পর্যন্ত
    } else if (_selectedFilter == 'এই মাস') {
      return (start.month < 12)
          ? DateTime(start.year, start.month + 1, 1)
          : DateTime(start.year + 1, 1, 1);
    } else if (_selectedFilter == 'এই বছর') {
      return DateTime(start.year + 1, 1, 1);
    }
    return start.add(const Duration(days: 1));
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

  // দশমিক স্টক সুন্দরভাবে দেখানোর জন্য (যেমন: ১.০ থাকলে ১ দেখাবে)
  String _formatStock(double stock) {
    return stock == stock.toInt()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = _getStartDate();
    DateTime endDate = _getEndDate();

    // হেডার টেক্সট লজিক
    String headerText =
        _selectedFilter == 'নির্দিষ্ট তারিখ' && _selectedSpecificDate != null
        ? "${_toBanglaDigit(DateFormat('dd/MM/yyyy').format(_selectedSpecificDate!))} তারিখের"
        : "$_selectedFilter";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "বিক্রির বিস্তারিত ইতিহাস",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ফিল্টার সেকশন (আজ, এই মাস, এই বছর, নির্দিষ্ট তারিখ)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "হিসাব দেখুন:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        underline: const SizedBox(),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.blueGrey,
                        ),
                        items: _filters.map((String filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(
                              filter == 'নির্দিষ্ট তারিখ' &&
                                      _selectedSpecificDate != null
                                  ? "তারিখ: ${_toBanglaDigit(DateFormat('dd/MM').format(_selectedSpecificDate!))}"
                                  : filter,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            if (newValue == 'নির্দিষ্ট তারিখ') {
                              _pickDate(context);
                            } else {
                              setState(() {
                                _selectedFilter = newValue;
                                _selectedSpecificDate = null; // রিসেট
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ক্যালেন্ডার আইকন বাটন
                    InkWell(
                      onTap: () => _pickDate(context),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ডাটা লোড ও প্রদর্শন
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('sales')
                  .where(
                    'timestamp',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
                  )
                  .where('timestamp', isLessThan: Timestamp.fromDate(endDate))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // যদি কোনো ডেটা না থাকে (Zero Sales)
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[350],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "এই সময়ে কোনো বিক্রির রেকর্ড নেই।",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                double totalSales = 0.0;
                double totalProfit = 0.0;

                // মোট বিক্রি ও লাভ হিসাব করা
                for (var doc in docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  totalSales +=
                      (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

                  List items = data['items'] ?? [];
                  for (var item in items) {
                    double buyPrice =
                        (item['buyPrice'] as num?)?.toDouble() ?? 0.0;
                    double sellPrice =
                        (item['sellPrice'] as num?)?.toDouble() ?? 0.0;
                    double qty =
                        (item['qty'] as num?)?.toDouble() ??
                        0.0; // ডেসিমাল সাপোর্ট
                    totalProfit += (sellPrice - buyPrice) * qty;
                  }
                }

                return Column(
                  children: [
                    // ওপরের সামারি কার্ড (মোট বিক্রি ও লাভ)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueGrey[700]!,
                            Colors.blueGrey[500]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "$headerText মোট বিক্রি",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "৳${_toBanglaDigit(totalSales.toStringAsFixed(0))}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white30,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "$headerText মোট লাভ",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "৳${_toBanglaDigit(totalProfit.toStringAsFixed(0))}",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // বিক্রির বিস্তারিত লিস্ট
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;

                          DateTime date = data['timestamp'] != null
                              ? (data['timestamp'] as Timestamp).toDate()
                              : DateTime.now();
                          String formattedDate = DateFormat(
                            'dd MMM, yyyy - hh:mm a',
                          ).format(date);

                          double totalAmount =
                              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                          String paymentType = data['paymentType'] ?? 'নগদ';
                          List items = data['items'] ?? [];

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // কার্ডের হেডার (সময় ও পেমেন্ট টাইপ)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: paymentType == 'বাকি'
                                              ? Colors.orange[100]
                                              : Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          paymentType,
                                          style: TextStyle(
                                            color: paymentType == 'বাকি'
                                                ? Colors.orange[800]
                                                : Colors.green[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // বিক্রি হওয়া প্রোডাক্টের লিস্ট (কেজি/লিটার/পিস সাপোর্টসহ)
                                  ...items.map((item) {
                                    String name =
                                        item['name'] ?? 'অজানা প্রোডাক্ট';
                                    double qty =
                                        (item['qty'] as num?)?.toDouble() ??
                                        0.0;
                                    double price =
                                        (item['sellPrice'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                    String unit =
                                        item['unit'] ??
                                        'পিস'; // ইউনিট ডাটাবেস থেকে
                                    double subTotal = qty * price;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "$name (${_toBanglaDigit(_formatStock(qty))} $unit x ${_toBanglaDigit(price.toString())})",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "৳${_toBanglaDigit(subTotal.toString())}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(height: 20),
                                  // মোট বিল
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "মোট বিল:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "৳${_toBanglaDigit(totalAmount.toString())}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.blueGrey[800],
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
}
