import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  // টেক্সট কন্ট্রোলারগুলো
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();

  // ফায়ারবেস কালেকশন রেফারেন্স
  final CollectionReference _products = FirebaseFirestore.instance.collection(
    'products',
  );

  // ১. নতুন পণ্য যোগ করার পপ-আপ (Dialog)
  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "নতুন পণ্য যোগ করুন",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "পণ্যের নাম (যেমন: লাক্স সাবান)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _buyPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ক্রয়মূল্য (৳)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _sellPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "বিক্রয়মূল্য (৳)",
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final String name = _nameController.text.trim();
              final double? buyPrice = double.tryParse(
                _buyPriceController.text.trim(),
              );
              final double? sellPrice = double.tryParse(
                _sellPriceController.text.trim(),
              );

              // ভ্যালিডেশন (সব ফিল্ড ঠিকমতো পূরণ হয়েছে কি না)
              if (name.isNotEmpty && buyPrice != null && sellPrice != null) {
                // ফায়ারবেসে ডেটা সেভ করা
                await _products.add({
                  "name": name,
                  "buyPrice": buyPrice,
                  "sellPrice": sellPrice,
                  "timestamp":
                      FieldValue.serverTimestamp(), // লিস্ট সাজানোর জন্য সময়
                });

                // সেভ হওয়ার পর ইনপুট ফিল্ড ক্লিয়ার করা
                _nameController.clear();
                _buyPriceController.clear();
                _sellPriceController.clear();

                if (context.mounted) Navigator.pop(context); // পপ-আপ বন্ধ করা
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("দয়া করে সঠিক তথ্য দিন!")),
                );
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

  // ২. পণ্য ডিলিট করার ফাংশন
  void _deleteProduct(String productId) async {
    await _products.doc(productId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("পণ্যটি ডিলিট করা হয়েছে!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "পণ্য তালিকা",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // ৩. ফায়ারবেস থেকে রিয়েল-টাইম ডেটা দেখানোর জন্য StreamBuilder
      body: StreamBuilder(
        stream: _products.orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "কোনো পণ্য যোগ করা হয়নি।\nনিচের + বাটনে ক্লিক করে পণ্য যোগ করুন।",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // লিস্ট আকারে পণ্যগুলো দেখানো
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot documentSnapshot =
                  snapshot.data!.docs[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.1),
                    child: const Icon(Icons.inventory_2, color: Colors.teal),
                  ),
                  title: Text(
                    documentSnapshot['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    "কেনা: ৳${documentSnapshot['buyPrice']}  |  বিক্রি: ৳${documentSnapshot['sellPrice']}",
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteProduct(documentSnapshot.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      // ফ্লোটিং বাটন (নতুন পণ্য যোগ করার জন্য)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "নতুন পণ্য",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
