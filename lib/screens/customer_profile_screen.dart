import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // কপি করার জন্য
import 'package:url_launcher/url_launcher.dart'; // কল করার জন্য
import 'package:intl/intl.dart'; // সময় ফরম্যাটের জন্য

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
  final TextEditingController _nameEditController = TextEditingController();
  final TextEditingController _phoneEditController = TextEditingController();

  Timer? _debounce;
  bool _isDescInitialized = false; // ডেসক্রিপশন বারবার রিলোড না হওয়ার জন্য

  @override
  void dispose() {
    _descController.dispose();
    _nameEditController.dispose();
    _phoneEditController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // অটো-সেভ ডেসক্রিপশন ফাংশন (ব্যাকগ্রাউন্ডে সেভ হবে, স্ক্রিন রিলোড নেবে না)
  void _onDescriptionChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      // আপডেট: ইউজারের নিজস্ব ডিরেক্টরিতে ডেসক্রিপশন সেভ করা হচ্ছে
      String uid = FirebaseAuth.instance.currentUser!.uid;

      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('customers')
          .doc(widget.phone)
          .update({'description': value.trim()});
    });
  }

  // কল ফিচার
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  // কপি ফিচার
  void _copyPhone(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("নম্বর কপি করা হয়েছে!")));
  }

  // এডিট প্রোফাইল ডায়লগ
  void _showEditCustomerDialog(String currentName, String currentPhone) {
    _nameEditController.text = currentName;
    _phoneEditController.text = currentPhone;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("প্রোফাইল এডিট"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameEditController,
              decoration: const InputDecoration(labelText: "নাম"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneEditController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "ফোন নম্বর"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              String newName = _nameEditController.text.trim();
              String newPhone = _phoneEditController.text.trim();

              if (newName.isEmpty || newPhone.isEmpty) return;

              // আপডেট: ডাটা ট্রান্সফারের জন্য ইউজারের uid সংগ্রহ
              String uid = FirebaseAuth.instance.currentUser!.uid;

              // যদি ফোন নম্বর পরিবর্তন করা হয়, তাহলে ডাটা ট্রান্সফার করতে হবে
              if (newPhone != widget.phone) {
                // প্রসেসিং এর জন্য লোডিং দেখানো
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // আপডেট: পুরানো এবং নতুন ডকুমেন্টের পাথ ইউজারের ডিরেক্টরি অনুযায়ী করা হলো
                DocumentReference oldDoc = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('customers')
                    .doc(widget.phone);

                DocumentReference newDoc = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('customers')
                    .doc(newPhone);

                var docSnapshot = await oldDoc.get();
                if (docSnapshot.exists) {
                  Map<String, dynamic> data =
                      docSnapshot.data() as Map<String, dynamic>;
                  data['name'] = newName;
                  data['phone'] = newPhone;

                  // নতুন ডকুমেন্টে ডাটা সেভ
                  await newDoc.set(data);

                  // লেজার (হিস্ট্রি) ট্রান্সফার
                  var ledgerDocs = await oldDoc.collection('ledger').get();
                  for (var ledgerDoc in ledgerDocs.docs) {
                    await newDoc
                        .collection('ledger')
                        .doc(ledgerDoc.id)
                        .set(ledgerDoc.data());
                    await ledgerDoc.reference.delete();
                  }

                  // পুরানো ডকুমেন্ট রিমুভ করা
                  await oldDoc.delete();

                  if (context.mounted) {
                    Navigator.pop(context); // লোডিং বন্ধ
                    Navigator.pop(context); // এডিট ডায়লগ বন্ধ
                    Navigator.pop(
                      context,
                    ); // প্রোফাইল স্ক্রিন থেকে বের করে লিস্টে পাঠানো
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("প্রোফাইল আপডেট হয়েছে!")),
                    );
                  }
                }
              } else {
                // শুধু নাম পরিবর্তন হলে
                // আপডেট: নাম আপডেটের জন্য সঠিক পাথ সেট করা হলো
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('customers')
                    .doc(widget.phone)
                    .update({'name': newName});

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("নাম আপডেট হয়েছে!")),
                  );
                }
              }
            },
            child: const Text("সেভ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
              "বর্তমান বাকি: ৳${currentDue.toStringAsFixed(0)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            child: const Text("বাতিল"),
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
                // আপডেট: পেমেন্ট রিসিভ করার সময় ইউজারের নিজস্ব ডিরেক্টরি কল করা হলো
                String uid = FirebaseAuth.instance.currentUser!.uid;

                DocumentReference customerRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('customers')
                    .doc(widget.phone);

                await customerRef.update({
                  'dueAmount': FieldValue.increment(-paidAmount),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                await customerRef.collection('ledger').add({
                  'type': 'Payment',
                  'amount': paidAmount,
                  'note': 'নগদ টাকা জমা',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
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
                    content: Text("সঠিক পরিমাণ লিখুন!"),
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
    // আপডেট: build মেথডের ভেতরে uid ডিক্লেয়ার করা হলো যাতে নিচের StreamBuilder গুলো এটি পায়
    final String uid = FirebaseAuth.instance.currentUser!.uid;

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
            StreamBuilder<DocumentSnapshot>(
              // আপডেট: কাস্টমারের ডেটা ফেচ করার জন্য ইউজারের নিজস্ব পাথ
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('customers')
                  .doc(widget.phone)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                double dueAmount =
                    (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

                // ডেসক্রিপশন শুধু প্রথমবার লোড হবে, টাইপ করার সময় লাফাবে না
                if (!_isDescInitialized && data.containsKey('description')) {
                  _descController.text = data['description'] ?? '';
                  _isDescInitialized = true;
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
                                  data['name'] ?? widget.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      data['phone'] ?? widget.phone,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _copyPhone(
                                        data['phone'] ?? widget.phone,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.call,
                                        size: 20,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _makeCall(
                                        data['phone'] ?? widget.phone,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showEditCustomerDialog(
                                        data['name'] ?? widget.name,
                                        data['phone'] ?? widget.phone,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ডানদিকের বড় করা বকেয়া সেকশন
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "বর্তমান বকেয়া",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "৳${dueAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dueAmount > 0
                                          ? Colors.green
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "জমা নিন",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        onChanged:
                            _onDescriptionChanged, // ব্যাকগ্রাউন্ডে অটো-সেভ হবে
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: "ডেসক্রিপশন...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            StreamBuilder<QuerySnapshot>(
              // আপডেট: কাস্টমারের লেজার/হিস্ট্রি ফেচ করার জন্য ইউজারের নিজস্ব পাথ
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
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
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "এযাবৎ মোট পরিশোধ: ৳${totalPaid.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data?.docs.length ?? 0,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          bool isPayment = doc['type'] == 'Payment';

                          // UTC টাইমকে BD টাইম (+6) এ কনভার্ট করা হচ্ছে
                          DateTime date =
                              (doc['timestamp'] as Timestamp?)
                                  ?.toDate()
                                  .toUtc() ??
                              DateTime.now().toUtc();
                          DateTime bdDate = date.add(const Duration(hours: 6));
                          String formattedTime = DateFormat(
                            'dd/MM/yyyy h:mm a',
                          ).format(bdDate);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isPayment
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isPayment ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                doc['note'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                "৳${doc['amount']}",
                                style: TextStyle(
                                  color: isPayment ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      15, // টাকার পরিমাণ বড় করে দেখানো হলো
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
