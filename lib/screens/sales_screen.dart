//POS screen for quick sales

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে products কালেকশন নেওয়ার জন্য getter তৈরি করা হলো
  CollectionReference get _products {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('products');
  }

  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে sales কালেকশন নেওয়ার জন্য getter তৈরি করা হলো
  CollectionReference get _sales {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sales');
  }

  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে customers কালেকশন নেওয়ার জন্য getter তৈরি করা হলো
  CollectionReference get _customers {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('customers');
  }

  // ফাস্ট পারফরম্যান্সের জন্য স্ট্রিমটি আগে থেকে ডিফাইন করা হলো
  late Stream<QuerySnapshot> _productsStream;

  // সার্চের জন্য ভেরিয়েবল
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Map<String, Map<String, dynamic>> cart = {};
  double totalAmount = 0.0;
  bool isProcessing = false;
  List<Map<String, dynamic>> _allCustomers = [];

  @override
  void initState() {
    super.initState();
    // স্ট্রিমটি ইনিশিয়ালাইজ করা হলো, যাতে বারবার রিলোড না হয়
    _productsStream = _products.orderBy('name').snapshots();
    _fetchCustomers();
  }

  void _fetchCustomers() {
    _customers.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _allCustomers = snapshot.docs
              .map((doc) => {'phone': doc.id, 'name': doc['name']})
              .toList();
        });
      }
    });
  }

  // স্টক সুন্দরভাবে দেখানোর জন্য (যেমন: ১.০ থাকলে ১ দেখাবে)
  String _formatStock(double stock) {
    return stock == stock.toInt()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  // দশমিক স্টক এবং ইউনিট সাপোর্টের জন্য double ব্যবহার করা হয়েছে
  void _updateCart(
    String id,
    String name,
    double buyPrice,
    double sellPrice,
    double change,
    double currentStock,
    String unit,
  ) {
    setState(() {
      if (!cart.containsKey(id)) {
        if (change > 0) {
          if (currentStock > 0) {
            cart[id] = {
              'name': name,
              'buyPrice': buyPrice,
              'sellPrice': sellPrice,
              'qty': change,
              'unit': unit,
            };
          } else {
            _showSnackBar("স্টকে পর্যাপ্ত পণ্য নেই!", Colors.redAccent);
            return;
          }
        }
      } else {
        double newQty = cart[id]!['qty'] + change;
        if (change > 0 && newQty > currentStock) {
          _showSnackBar("স্টকে আর পণ্য নেই!", Colors.redAccent);
          return;
        }

        if (newQty <= 0) {
          cart.remove(id);
        } else {
          cart[id]!['qty'] = newQty;
        }
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    double tempTotal = 0.0;
    cart.forEach((key, item) => tempTotal += (item['sellPrice'] * item['qty']));
    totalAmount = tempTotal;
  }

  Future<void> _deductStock() async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var entry in cart.entries) {
      DocumentReference productRef = _products.doc(entry.key);
      batch.update(productRef, {
        'stock': FieldValue.increment(-entry.value['qty']),
      });
    }
    await batch.commit();
  }

  void _checkoutCash() async {
    if (cart.isEmpty) return;
    setState(() => isProcessing = true);

    await _sales.add({
      'items': cart.values.toList(),
      'totalAmount': totalAmount,
      'paymentType': 'নগদ',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _deductStock();

    _clearCartAndShowMessage("নগদ বিক্রি সফল হয়েছে!", Colors.green);
  }

  void _showDueDialog() {
    if (cart.isEmpty) return;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    List<Map<String, dynamic>> filteredCustomers = [];
    bool showSuggestions = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "বাকি খাতা",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "মোট বকেয়া:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          "৳$totalAmount",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "কাস্টমারের নাম (সার্চ করুন)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_search,
                        color: Colors.deepPurple,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.trim().isNotEmpty) {
                          filteredCustomers = _allCustomers
                              .where(
                                (customer) => customer['name']
                                    .toString()
                                    .toLowerCase()
                                    .contains(value.trim().toLowerCase()),
                              )
                              .toList();
                          showSuggestions = filteredCustomers.isNotEmpty;
                        } else {
                          showSuggestions = false;
                        }
                      });
                    },
                  ),
                  if (showSuggestions)
                    Container(
                      height: 140,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          var customer = filteredCustomers[index];
                          return InkWell(
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                if (mounted) {
                                  nameController.text = customer['name'];
                                  phoneController.text = customer['phone'];
                                  setDialogState(() => showSuggestions = false);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "${customer['name']}  (${customer['phone']})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "মোবাইল নম্বর",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
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
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _checkoutDue(nameController.text, phoneController.text);
                  } else {
                    _showSnackBar("নাম ও মোবাইল নম্বর দিন!", Colors.redAccent);
                  }
                },
                child: const Text(
                  "বাকি সেভ করুন",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _checkoutDue(String customerName, String customerPhone) async {
    setState(() => isProcessing = true);

    List<String> purchasedItems = [];
    for (var item in cart.values) {
      purchasedItems.add(
        "${item['name']} x${_formatStock((item['qty'] as num).toDouble())}",
      );
    }
    String ledgerNote = "ক্রয়: ${purchasedItems.join(', ')}";

    await _sales.add({
      'items': cart.values.toList(),
      'totalAmount': totalAmount,
      'paymentType': 'বাকি',
      'customerName': customerName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    DocumentReference customerRef = _customers.doc(customerPhone);
    await customerRef.set({
      'name': customerName,
      'phone': customerPhone,
      'dueAmount': FieldValue.increment(totalAmount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await customerRef.collection('ledger').add({
      'type': 'Purchase',
      'amount': totalAmount,
      'note': ledgerNote,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _deductStock();

    _clearCartAndShowMessage("বাকির খাতায় সেভ হয়েছে!", Colors.orange);
  }

  void _clearCartAndShowMessage(String message, Color color) {
    setState(() {
      cart.clear();
      totalAmount = 0.0;
      isProcessing = false;
      _searchController.clear();
      _searchQuery = '';
    });
    _showSnackBar(message, color);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "দ্রুত বিক্রি (POS)",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // সার্চ বার সেকশন
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "পণ্য খুঁজুন...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade400),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder(
              stream: _productsStream,
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
                          "কোনো পণ্য নেই। আগে পণ্য যোগ করুন।",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                var allDocs = snapshot.data!.docs;
                var filteredDocs = allDocs;

                if (_searchQuery.isNotEmpty) {
                  filteredDocs = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "কোনো পণ্য পাওয়া যায়নি",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String id = doc.id;
                    String name = data['name'] ?? 'অজানা পণ্য';
                    double bPrice =
                        (data['buyPrice'] as num?)?.toDouble() ?? 0.0;
                    double sPrice =
                        (data['sellPrice'] as num?)?.toDouble() ?? 0.0;
                    double currentStock =
                        (data['stock'] as num?)?.toDouble() ?? 0.0;
                    String unit = data['unit'] ?? 'পিস';

                    double qtyInCart = cart.containsKey(id)
                        ? (cart[id]!['qty'] as num).toDouble()
                        : 0.0;
                    double availableStock = currentStock - qtyInCart;

                    // একক অনুযায়ী স্টেপ নির্ধারণ (কেজি বা লিটার হলে ০.৫ করে, পিস হলে ১.০ করে)
                    double step = (unit == 'কেজি' || unit == 'লিটার')
                        ? 0.5
                        : 1.0;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.blue,
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
                                      color: Color(0xFF2C3E50),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        "৳$sPrice",
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: availableStock > 0
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          availableStock > 0
                                              ? "স্টক: ${_formatStock(availableStock)} $unit"
                                              : "স্টক আউট",
                                          style: TextStyle(
                                            color: availableStock > 0
                                                ? Colors.green[800]
                                                : Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () => _updateCart(
                                      id,
                                      name,
                                      bPrice,
                                      sPrice,
                                      -step,
                                      currentStock,
                                      unit,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 35,
                                      minHeight: 35,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(
                                    _formatStock(qtyInCart),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    onPressed: availableStock >= step
                                        ? () => _updateCart(
                                            id,
                                            name,
                                            bPrice,
                                            sPrice,
                                            step,
                                            currentStock,
                                            unit,
                                          )
                                        : null,
                                    constraints: const BoxConstraints(
                                      minWidth: 35,
                                      minHeight: 35,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
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

          // কার্ট প্রিভিউ এবং চেকআউট সেকশন
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "মোট দাম:",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (cart.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                cart.values
                                    .map(
                                      (e) =>
                                          "${e['name']} x${_formatStock((e['qty'] as num).toDouble())}",
                                    )
                                    .join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "৳${_formatStock(totalAmount)}",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[500],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.book_outlined, size: 20),
                              onPressed: totalAmount > 0
                                  ? _showDueDialog
                                  : null,
                              label: const Text(
                                "বাকি (Due)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                Icons.payments_outlined,
                                size: 20,
                              ),
                              onPressed: totalAmount > 0 ? _checkoutCash : null,
                              label: const Text(
                                "নগদ (Cash)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
