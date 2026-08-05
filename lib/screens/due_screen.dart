//বাকি খাতা স্ক্রিন

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_profile_screen.dart';

class DueScreen extends StatefulWidget {
  const DueScreen({super.key});

  @override
  State<DueScreen> createState() => _DueScreenState();
}

class _DueScreenState extends State<DueScreen> {
  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে কাস্টমার কালেকশন নেওয়ার জন্য getter তৈরি করা হলো
  CollectionReference get _customers {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('customers');
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // ম্যানুয়ালি নতুন বাকি কাস্টমার অ্যাড করার পপ-আপ
  void _showAddCustomerDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "নতুন বাকির কাস্টমার",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "কাস্টমারের নাম",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "মোবাইল নম্বর",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "প্রাথমিক বাকি (৳)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              String name = nameController.text.trim();
              String phone = phoneController.text.trim();
              double? amount = double.tryParse(amountController.text.trim());

              if (name.isNotEmpty &&
                  phone.isNotEmpty &&
                  amount != null &&
                  amount > 0) {
                // আপডেট: এখানে _customers অটোমেটিক ইউজারের নির্দিষ্ট ফোল্ডার পয়েন্ট করবে
                DocumentReference customerRef = _customers.doc(phone);
                await customerRef.set({
                  'name': name,
                  'phone': phone,
                  'dueAmount': amount,
                  'description': '',
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

                await customerRef.collection('ledger').add({
                  'type': 'Purchase',
                  'amount': amount,
                  'note': 'ম্যানুয়াল এন্ট্রি',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("নতুন কাস্টমার যোগ হয়েছে!")),
                  );
                }
              }
            },
            child: const Text("সেভ করুন"),
          ),
        ],
      ),
    );
  }

  // কাস্টমার ডিলিট করার কনফার্মেশন পপ-আপ
  void _confirmDeleteCustomer(String phone, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "কাস্টমার ডিলিট?",
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          "আপনি কি নিশ্চিত যে '$name'-কে তালিকা থেকে মুছে ফেলতে চান?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // আপডেট: সঠিক ইউজারের ডিরেক্টরি থেকেই ডিলিট হবে
              await _customers.doc(phone).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("কাস্টমার মুছে ফেলা হয়েছে!")),
                );
              }
            },
            child: const Text("মুছে ফেলুন"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "বাকি খাতা",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // সার্চ বার সেকশন
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "কাস্টমারের নাম খুঁজুন...",
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder(
              // আপডেট: _customers.snapshots() এখন সরাসরি ইউজারের নিজস্ব ডেটা নিয়ে আসবে
              stream: _customers.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("বর্তমানে কোনো কাস্টমার নেই!"),
                  );
                }

                // ফিল্টার ও সর্টিং লজিক
                var docs = snapshot.data!.docs.where((doc) {
                  String name = doc['name'].toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                docs.sort(
                  (a, b) =>
                      a['name'].toString().compareTo(b['name'].toString()),
                );

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("কোনো কাস্টমার পাওয়া যায়নি!"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    String phone = doc.id;
                    String name = doc['name'];
                    double dueAmount = (doc['dueAmount'] as num).toDouble();

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onLongPress: () => _confirmDeleteCustomer(phone, name),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CustomerProfileScreen(phone: phone, name: name),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.deepPurple,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "বকেয়া",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    "৳${dueAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomerDialog,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          "নতুন বাকি",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
