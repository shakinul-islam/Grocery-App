import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_profile_screen.dart'; // নতুন প্রোফাইল স্ক্রিন যুক্ত করা হলো

class DueScreen extends StatefulWidget {
  const DueScreen({super.key});

  @override
  State<DueScreen> createState() => _DueScreenState();
}

class _DueScreenState extends State<DueScreen> {
  final CollectionReference _customers = FirebaseFirestore.instance.collection(
    'customers',
  );

  // ম্যানুয়ালি নতুন বাকি কাস্টমার অ্যাড করার পপ-আপ
  void _showAddCustomerDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("নতুন বাকির কাস্টমার"),
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
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "মোবাইল নম্বর",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              String name = nameController.text.trim();
              String phone = phoneController.text.trim();
              double? amount = double.tryParse(amountController.text.trim());

              if (name.isNotEmpty &&
                  phone.isNotEmpty &&
                  amount != null &&
                  amount > 0) {
                DocumentReference customerRef = _customers.doc(phone);

                await customerRef.set({
                  'name': name,
                  'phone': phone,
                  'dueAmount': amount,
                  'description': '', // প্রোফাইলের ডেসক্রিপশনের জন্য
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
                    const SnackBar(
                      content: Text("নতুন কাস্টমার সফলভাবে যোগ হয়েছে!"),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "সেভ করুন",
              style: TextStyle(color: Colors.white),
            ),
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
          "আপনি কি নিশ্চিত যে '$name'-কে তালিকা থেকে মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা সম্ভব নয়।",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _customers.doc(phone).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("কাস্টমার মুছে ফেলা হয়েছে!")),
                );
              }
            },
            child: const Text(
              "মুছে ফেলুন",
              style: TextStyle(color: Colors.white),
            ),
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
        title: const Text(
          "বাকি খাতা",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _customers.where('dueAmount', isGreaterThan: 0).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("বর্তমানে কোনো বকেয়া নেই!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              String phone = doc.id;
              String name = doc['name'];
              double dueAmount = (doc['dueAmount'] as num).toDouble();

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // নামের উপর ক্লিক করলে প্রোফাইল স্ক্রিনে যাবে
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomerProfileScreen(phone: phone, name: name),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.deepPurple.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // ডিলিট আইকন
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    onPressed: () =>
                                        _confirmDeleteCustomer(phone, name),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "৳$dueAmount",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
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
      // ম্যানুয়ালি কাস্টমার অ্যাড করার ফ্লোটিং বাটন
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
