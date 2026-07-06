import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final CollectionReference _products = FirebaseFirestore.instance.collection(
    'products',
  );
  final CollectionReference _sales = FirebaseFirestore.instance.collection(
    'sales',
  );
  final CollectionReference _customers = FirebaseFirestore.instance.collection(
    'customers',
  );

  Map<String, Map<String, dynamic>> cart = {};
  double totalAmount = 0.0;
  bool isProcessing = false;
  List<Map<String, dynamic>> _allCustomers = [];

  @override
  void initState() {
    super.initState();
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

  void _updateCart(
    String id,
    String name,
    double buyPrice,
    double sellPrice,
    int change,
  ) {
    setState(() {
      if (!cart.containsKey(id)) {
        if (change > 0) {
          cart[id] = {
            'name': name,
            'buyPrice': buyPrice,
            'sellPrice': sellPrice,
            'qty': change,
          };
        }
      } else {
        int newQty = cart[id]!['qty'] + change;
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

  void _checkoutCash() async {
    if (cart.isEmpty) return;
    setState(() => isProcessing = true);
    await _sales.add({
      'items': cart.values.toList(),
      'totalAmount': totalAmount,
      'paymentType': 'Cash',
      'timestamp': FieldValue.serverTimestamp(),
    });
    _clearCartAndShowMessage("নগদ বিক্রি সফল হয়েছে!");
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
            title: const Text("বাকি খাতা"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "মোট বকেয়া: ৳$totalAmount",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "কাস্টমারের নাম (সার্চ করুন)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search),
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
                      height: 120,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.blueGrey.shade50,
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
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              child: Text(
                                "${customer['name']}  (${customer['phone']})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "মোবাইল নম্বর",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("বাতিল"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _checkoutDue(nameController.text, phoneController.text);
                  }
                },
                child: const Text(
                  "বাকি সেভ করুন",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // আপডেট করা বাকি (Due) বিক্রির লজিক
  void _checkoutDue(String customerName, String customerPhone) async {
    setState(() => isProcessing = true);

    // কার্টের আইটেমগুলো লুপ করে পণ্যের নাম ও পরিমাণ দিয়ে একটি সুন্দর স্ট্রিং তৈরি করা হচ্ছে
    List<String> purchasedItems = [];
    for (var item in cart.values) {
      purchasedItems.add("${item['name']} x${item['qty']}");
    }
    String ledgerNote = "ক্রয়: ${purchasedItems.join(', ')}";

    await _sales.add({
      'items': cart.values.toList(),
      'totalAmount': totalAmount,
      'paymentType': 'Due',
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

    // লেজারে ডাইনামিক নোট সেভ করা হচ্ছে
    await customerRef.collection('ledger').add({
      'type': 'Purchase',
      'amount': totalAmount,
      'note': ledgerNote,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _clearCartAndShowMessage("বাকির খাতায় সেভ হয়েছে!");
  }

  void _clearCartAndShowMessage(String message) {
    setState(() {
      cart.clear();
      totalAmount = 0.0;
      isProcessing = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "দ্রুত বিক্রি (POS)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _products.orderBy('name').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("কোনো পণ্য নেই। আগে পণ্য যোগ করুন।"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    String id = doc.id;
                    String name = doc['name'];
                    double bPrice = (doc['buyPrice'] as num).toDouble();
                    double sPrice = (doc['sellPrice'] as num).toDouble();
                    int qty = cart.containsKey(id) ? cart[id]!['qty'] : 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "৳$sPrice",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _updateCart(id, name, bPrice, sPrice, -1),
                            ),
                            Text(
                              "$qty",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  _updateCart(id, name, bPrice, sPrice, 1),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "মোট দাম:",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "৳$totalAmount",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                isProcessing
                    ? const CircularProgressIndicator()
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              onPressed: totalAmount > 0
                                  ? _showDueDialog
                                  : null,
                              child: const Text(
                                "বাকি (Due)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              onPressed: totalAmount > 0 ? _checkoutCash : null,
                              child: const Text(
                                "নগদ (Cash)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
