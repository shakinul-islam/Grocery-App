import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerProfileScreen extends StatefulWidget {
  final String phone;
  final String name;

  const CustomerProfileScreen({
    super.key,
    required this.phone,
    required this.name,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final TextEditingController _descController = TextEditingController();
  bool _isSavingDesc = false;

  // ডেসক্রিপশন সেভ করার ফাংশন
  void _saveDescription() async {
    setState(() => _isSavingDesc = true);
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.phone)
        .update({'description': _descController.text.trim()});
    setState(() => _isSavingDesc = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ডেসক্রিপশন সেভ হয়েছে!")));
    }
  }

  // টাকা জমা নেওয়ার পপ-আপ ফাংশন
  void _showReceivePaymentDialog(double currentDue) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${widget.name}-এর জমা"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "বর্তমান বাকি: ৳$currentDue",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "জমা দেওয়ার পরিমাণ (৳)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              double? paidAmount = double.tryParse(
                amountController.text.trim(),
              );

              if (paidAmount != null &&
                  paidAmount > 0 &&
                  paidAmount <= currentDue) {
                DocumentReference customerRef = FirebaseFirestore.instance
                    .collection('customers')
                    .doc(widget.phone);

                // মূল ব্যালেন্স থেকে মাইনাস করা
                await customerRef.update({
                  'dueAmount': FieldValue.increment(-paidAmount),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                // হিস্ট্রিতে জমার এন্ট্রি করা
                await customerRef.collection('ledger').add({
                  'type': 'Payment',
                  'amount': paidAmount,
                  'note': 'নগদ টাকা জমা',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context); // ডায়লগ বন্ধ করা
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("টাকা জমা সফল হয়েছে!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "সঠিক পরিমাণ লিখুন (বর্তমান বাকির চেয়ে বেশি নয়)",
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text("জমা নিন", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("${widget.name} - এর প্রোফাইল"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ১. কাস্টমার ইনফো, বকেয়া এবং ডেসক্রিপশন সেকশন
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(widget.phone)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();

                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                double dueAmount =
                    (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

                // ডেসক্রিপশন টেক্সটফিল্ডে ডাটা সেট করা
                if (_descController.text.isEmpty &&
                    data['description'] != null) {
                  _descController.text = data['description'];
                }

                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      widget.phone,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ডানপাশের বকেয়া এবং টাকা জমা সেকশন
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "বর্তমান বাকি",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "৳$dueAmount",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // টাকা জমা বাটন
                                InkWell(
                                  onTap: () {
                                    if (dueAmount > 0) {
                                      _showReceivePaymentDialog(dueAmount);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "কাস্টমারের কোনো বকেয়া নেই!",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dueAmount > 0
                                          ? Colors.green
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      "টাকা জমা",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "নোট / ডেসক্রিপশন:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              "কাস্টমার সম্পর্কে কিছু লিখে রাখুন (যেমন: ঠিকানা বা পেশা)...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingDesc ? null : _saveDescription,
                          icon: _isSavingDesc
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: const Text("সেভ করুন"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // ২. মোট পরিশোধ ও হিস্ট্রি (Ledger) সেকশন
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(widget.phone)
                  .collection('ledger')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                double totalPaid = 0.0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    if (doc['type'] == 'Payment') {
                      totalPaid += (doc['amount'] as num).toDouble();
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "এযাবৎ মোট পরিশোধ: ৳$totalPaid",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "লেনদেনের হিস্ট্রি:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text("কোনো লেনদেন পাওয়া যায়নি।"),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var doc = snapshot.data!.docs[index];
                            bool isPayment = doc['type'] == 'Payment';
                            DateTime date =
                                (doc['timestamp'] as Timestamp?)?.toDate() ??
                                DateTime.now();

                            return Card(
                              elevation: 0.5,
                              margin: const EdgeInsets.only(
                                bottom: 8,
                              ), // কার্ডের মাঝে একটু গ্যাপ
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ), // প্যাডিং বাড়ানো হলো
                                leading: CircleAvatar(
                                  backgroundColor: isPayment
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  child: Icon(
                                    isPayment
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isPayment
                                        ? Colors.green
                                        : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  doc['note'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    height: 1.4, // লাইনের মাঝে স্পেস
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "${date.day}/${date.month}/${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                trailing: Text(
                                  "৳${doc['amount']}",
                                  style: TextStyle(
                                    color: isPayment
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
