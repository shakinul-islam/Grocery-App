//Ponno talika screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  String _searchQuery = "";

  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে products কালেকশন নেওয়ার জন্য getter তৈরি করা হলো
  CollectionReference get _products {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('products');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // স্টক সুন্দরভাবে দেখানোর জন্য হেল্পার ফাংশন (যেমন: 1.0 থাকলে 1 দেখাবে)
  String _formatStock(double stock) {
    return stock == stock.toInt() ? stock.toInt().toString() : stock.toString();
  }

  // ১. নতুন পণ্য যোগ করার পপ-আপ
  void _showAddProductDialog() {
    _nameController.clear();
    _buyPriceController.clear();
    _sellPriceController.clear();
    _stockController.clear();
    String selectedUnit = 'পিস';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "নতুন পণ্য যোগ করুন",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "পণ্যের নাম (যেমন: লাক্স সাবান)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _buyPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "ক্রয়মূল্য (৳)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _sellPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "বিক্রয়মূল্য (৳)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.price_check),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: "প্রাথমিক স্টক",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.add_box_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            ),
                          ),
                          items: ['পিস', 'কেজি', 'লিটার'].map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedUnit = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onPressed: () async {
                  final String name = _nameController.text.trim();
                  final double? buyPrice = double.tryParse(
                    _buyPriceController.text.trim(),
                  );
                  final double? sellPrice = double.tryParse(
                    _sellPriceController.text.trim(),
                  );
                  final double stock =
                      double.tryParse(_stockController.text.trim()) ?? 0.0;

                  if (name.isNotEmpty &&
                      buyPrice != null &&
                      sellPrice != null) {
                    // এখানে _products সরাসরি ইউজারের নিজস্ব ফোল্ডার থেকে ডাটা সেভ করবে
                    DocumentReference docRef = await _products.add({
                      "name": name,
                      "buyPrice": buyPrice,
                      "sellPrice": sellPrice,
                      "stock": stock,
                      "unit": selectedUnit,
                      "timestamp": FieldValue.serverTimestamp(),
                    });

                    if (stock > 0) {
                      // আপডেট: হিস্ট্রি সেভ করার সময় ইউজারের নিজস্ব ডিরেক্টরি কল করা হলো
                      String uid = FirebaseAuth.instance.currentUser!.uid;
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('purchase_history')
                          .add({
                            'productId': docRef.id,
                            'qty': stock,
                            'unit': selectedUnit,
                            'buyPrice': buyPrice,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("নতুন পণ্য সফলভাবে যোগ করা হয়েছে!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("দয়া করে সঠিক তথ্য দিন!"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text(
                  "সেভ করুন",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ২. পণ্য এডিট করার ফাংশন
  void _showEditProductDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;
    double oldStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
    String selectedUnit = data['unit'] ?? 'পিস';

    _nameController.text = data['name'] ?? '';
    _buyPriceController.text = (data['buyPrice'] ?? '').toString();
    _sellPriceController.text = (data['sellPrice'] ?? '').toString();
    _stockController.text = _formatStock(oldStock);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "পণ্য আপডেট করুন",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "পণ্যের নাম",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _buyPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "ক্রয়মূল্য (৳)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _sellPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "বিক্রয়মূল্য (৳)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.price_check),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: "বর্তমান স্টক",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.add_box_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            ),
                          ),
                          items: ['পিস', 'কেজি', 'লিটার'].map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setDialogState(() {
                                selectedUnit = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final String name = _nameController.text.trim();
                  final double? buyPrice = double.tryParse(
                    _buyPriceController.text.trim(),
                  );
                  final double? sellPrice = double.tryParse(
                    _sellPriceController.text.trim(),
                  );
                  final double newStock =
                      double.tryParse(_stockController.text.trim()) ?? 0.0;

                  if (name.isNotEmpty &&
                      buyPrice != null &&
                      sellPrice != null) {
                    await _products.doc(docId).update({
                      "name": name,
                      "buyPrice": buyPrice,
                      "sellPrice": sellPrice,
                      "stock": newStock,
                      "unit": selectedUnit,
                    });

                    double addedStock = newStock - oldStock;
                    if (addedStock > 0) {
                      // আপডেট: স্টক যোগ হলে হিস্ট্রি সেভ করার সময় ইউজারের নিজস্ব ডিরেক্টরি
                      String uid = FirebaseAuth.instance.currentUser!.uid;
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('purchase_history')
                          .add({
                            'productId': docId,
                            'qty': addedStock,
                            'unit': selectedUnit,
                            'buyPrice': buyPrice,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("পণ্য আপডেট করা হয়েছে!"),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "আপডেট করুন",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ৩. পণ্য ডিলিট করার ফাংশন
  void _deleteProduct(String productId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "নিশ্চিত করুন",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text("আপনি কি সত্যিই এই পণ্যটি মুছে ফেলতে চান?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _products.doc(productId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("পণ্যটি ডিলিট করা হয়েছে!"),
                    backgroundColor: Colors.redAccent,
                  ),
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "পণ্য তালিকা",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // সার্চ বার সেকশন
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "পণ্যের নাম লিখে খুঁজুন...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: _products.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "কোনো পণ্য যোগ করা হয়নি।\nনিচের + বাটনে ক্লিক করে পণ্য যোগ করুন।",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // ডাটা ফিল্টার করা এবং নাম অনুযায়ী (Ascending) সর্ট করা
                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                docs.sort((a, b) {
                  final nameA =
                      ((a.data() as Map<String, dynamic>)['name'] ?? '')
                          .toString()
                          .toLowerCase();
                  final nameB =
                      ((b.data() as Map<String, dynamic>)['name'] ?? '')
                          .toString()
                          .toLowerCase();
                  return nameA.compareTo(nameB);
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "কোনো পণ্য পাওয়া যায়নি!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final DocumentSnapshot doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    String id = doc.id;
                    String name = data['name'] ?? '';
                    double buyPrice =
                        (data['buyPrice'] as num?)?.toDouble() ?? 0.0;
                    double sellPrice =
                        (data['sellPrice'] as num?)?.toDouble() ?? 0.0;
                    double stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
                    String unit = data['unit'] ?? 'পিস'; // ডিফল্ট 'পিস'

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shadowColor: Colors.grey.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF2C3E50),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stock > 0
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: stock > 0
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    stock > 0
                                        ? "স্টক: ${_formatStock(stock)} $unit"
                                        : "স্টক আউট",
                                    style: TextStyle(
                                      color: stock > 0
                                          ? Colors.green[700]
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "কেনা দাম",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "৳$buyPrice",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "বিক্রি দাম",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "৳$sellPrice",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.blueAccent,
                                      ),
                                      onPressed: () =>
                                          _showEditProductDialog(doc),
                                      tooltip: "এডিট করুন",
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _deleteProduct(id),
                                      tooltip: "পণ্য মুছুন",
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
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
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.teal[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "নতুন পণ্য",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
