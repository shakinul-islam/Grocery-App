//খরচ ও বাজেট স্ক্রিন

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// আপডেট: ইউজারের uid নেওয়ার জন্য FirebaseAuth ইমপোর্ট করা হলো
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে expenses কালেকশন নেওয়ার জন্য getter
  CollectionReference get _expenses {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('expenses');
  }

  // আপডেট: ইউজারের নিজস্ব ডিরেক্টরি থেকে budgets ডকুমেন্ট নেওয়ার জন্য getter
  DocumentReference get _budgetRef {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('expense_budgets');
  }

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final Map<String, double> _monthlyBudgets = {};
  String? _selectedCategory;

  // আপডেট: আপনার চাওয়া অনুযায়ী বাই-ডিফল্ট সব বাজেট ০.০ করে দেওয়া হলো যাতে ইউজার নিজে সেট করতে পারে
  final Map<String, dynamic> _defaultBudgets = {
    'দোকান ভাড়া': 0.0,
    'কর্মচারীর বেতন': 0.0,
    'চা-নাস্তা': 0.0,
    'যাতায়াত': 0.0,
    'বিদ্যুৎ বিল': 0.0,
    'অন্যান্য': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _listenToBudgets();
  }

  void _listenToBudgets() {
    _budgetRef.snapshots().listen((doc) {
      if (doc.exists &&
          doc.data() != null &&
          (doc.data() as Map).containsKey('budgets')) {
        Map<String, dynamic> data =
            (doc.data() as Map<String, dynamic>)['budgets'];
        if (mounted) {
          setState(() {
            _monthlyBudgets.clear();
            data.forEach((key, value) {
              _monthlyBudgets[key] = (value as num).toDouble();
            });
            if (_selectedCategory == null ||
                !_monthlyBudgets.containsKey(_selectedCategory)) {
              _selectedCategory = _monthlyBudgets.isNotEmpty
                  ? _monthlyBudgets.keys.first
                  : null;
            }
          });
        }
      } else {
        _budgetRef.set({'budgets': _defaultBudgets});
      }
    });
  }

  Future<void> _updateBudgetsInFirestore(
    Map<String, double> updatedBudgets,
  ) async {
    await _budgetRef.set({'budgets': updatedBudgets}, SetOptions(merge: true));
  }

  // এখানে updated logic ব্যবহার করা হয়েছে যাতে ডাটাবেস থেকে কি (Key) ডিলিট হয়
  Future<void> _deleteCategory(String categoryName) async {
    try {
      // ১. Firestore-এর Map ফিল্ড থেকে ক্যাটাগরি ডিলিট করার সঠিক উপায়
      await _budgetRef.update({'budgets.$categoryName': FieldValue.delete()});

      // ২. ওই ক্যাটাগরির সমস্ত খরচ রেকর্ড ডিলিট করা
      QuerySnapshot expenseDocs = await _expenses
          .where('category', isEqualTo: categoryName)
          .get();
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in expenseDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("'$categoryName' এবং এর সকল খরচ মুছে ফেলা হয়েছে!"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("মুছতে সমস্যা হয়েছে: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditBudgetDialog(String name, double amount) {
    final TextEditingController amountController = TextEditingController(
      text: amount.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "বাজেট আপডেট: $name",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "নতুন বাজেট লিমিট (৳)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              double newAmount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              Map<String, double> updated = Map.from(_monthlyBudgets);
              updated[name] = newAmount;
              await _updateBudgetsInFirestore(updated);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              "আপডেট করুন",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "নতুন খাত যোগ করুন",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "খাতের নাম",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "বাজেট লিমিট (৳)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              String newName = nameController.text.trim();
              double newAmount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              if (newName.isNotEmpty) {
                Map<String, double> updated = Map.from(_monthlyBudgets);
                updated[newName] = newAmount;
                await _updateBudgetsInFirestore(updated);
                if (context.mounted) Navigator.pop(context);
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

  void _showManageBudgetsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "বাজেট ম্যানেজমেন্ট",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _monthlyBudgets.length,
                    itemBuilder: (context, index) {
                      String key = _monthlyBudgets.keys.elementAt(index);
                      double amount = _monthlyBudgets[key]!;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "লিমিট: ৳$amount",
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () =>
                                    _showEditBudgetDialog(key, amount),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        "মুছে ফেলুন",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        "আপনি কি সত্যিই '$key' এবং এর সব খরচ মুছে ফেলতে চান?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("বাতিল"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            _deleteCategory(key);
                                            Navigator.pop(context);
                                          },
                                          child: const Text(
                                            "হ্যাঁ, মুছুন",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
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
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "নতুন খাত যোগ করুন",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _showAddBudgetDialog(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addExpense() {
    if (_monthlyBudgets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("আগে বাজেট সেটআপ করুন!")));
      return;
    }
    _noteController.clear();
    _amountController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "নতুন খরচ এন্ট্রি",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: "খরচের খাত",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                      color: Colors.deepPurple,
                    ),
                  ),
                  items: _monthlyBudgets.keys.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) =>
                      setDialogState(() => _selectedCategory = newValue),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "পরিমাণ (৳)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: "বিস্তারিত নোট (ঐচ্ছিক)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (_selectedCategory != null) {
                    await _expenses.add({
                      'category': _selectedCategory,
                      'note': _noteController.text.trim(),
                      'amount':
                          double.tryParse(_amountController.text.trim()) ?? 0.0,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  "সেভ করুন",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteExpense(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "মুছে ফেলুন",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text("আপনি কি সত্যিই এই খরচটি মুছে ফেলতে চান?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("বাতিল"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _expenses.doc(id).delete();
              if (context.mounted) Navigator.pop(context);
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
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "খরচ ও বাজেট",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.redAccent[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "বাজেট ম্যানেজমেন্ট",
            onPressed: _showManageBudgetsSheet,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _expenses
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
            )
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          double totalMonthlyBudget = _monthlyBudgets.values.fold(
            0.0,
            (sum, item) => sum + item,
          );
          double totalMonthlyExpense = 0.0;
          Map<String, double> categorySpent = {
            for (var cat in _monthlyBudgets.keys) cat: 0.0,
          };
          List<String> orderedCategories = [];
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              String category = data['category'] ?? 'অন্যান্য';
              double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              if (!categorySpent.containsKey(category)) {
                categorySpent[category] = 0.0;
              }
              categorySpent[category] = categorySpent[category]! + amount;
              totalMonthlyExpense += amount;
              if (!orderedCategories.contains(category)) {
                orderedCategories.add(category);
              }
            }
          }
          for (var category in _monthlyBudgets.keys) {
            if (!orderedCategories.contains(category)) {
              orderedCategories.add(category);
            }
          }
          double remainingBudget = totalMonthlyBudget - totalMonthlyExpense;
          double overallPercent = totalMonthlyBudget > 0
              ? (totalMonthlyExpense / totalMonthlyBudget)
              : 0.0;
          Color overallProgressColor = overallPercent >= 1.0
              ? Colors.redAccent
              : (overallPercent >= 0.75 ? Colors.orange : Colors.greenAccent);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent[700]!, Colors.red[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "মোট মাসিক বাজেট",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          "৳$totalMonthlyBudget",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "মোট খরচ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "৳$totalMonthlyExpense",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              remainingBudget >= 0
                                  ? "অবশিষ্ট আছে"
                                  : "বাজেট ওভার",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "৳${remainingBudget.abs()}",
                              style: TextStyle(
                                color: remainingBudget >= 0
                                    ? Colors.greenAccent
                                    : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: overallPercent > 1.0 ? 1.0 : overallPercent,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      color: overallProgressColor,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
              if (orderedCategories.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "খাত অনুযায়ী ট্র্যাকিং",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orderedCategories.length,
                    itemBuilder: (context, index) {
                      String category = orderedCategories[index];
                      double budget = _monthlyBudgets[category] ?? 0.0;
                      double spent = categorySpent[category] ?? 0.0;
                      double percent = budget > 0
                          ? (spent / budget)
                          : (spent > 0 ? 1.0 : 0.0);
                      Color progressColor = percent >= 1.0
                          ? Colors.redAccent
                          : (percent >= 0.75 ? Colors.orange : Colors.green);
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              budget > 0 ? "৳$spent / ৳$budget" : "৳$spent",
                              style: TextStyle(
                                fontSize: 12,
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: percent > 1.0 ? 1.0 : percent,
                              backgroundColor: Colors.grey[200],
                              color: progressColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "এই মাসের সকল খরচ:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    String id = doc.id;
                    String category = data['category'] ?? 'অন্যান্য';
                    String note = data['note'] ?? '';
                    DateTime time =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    String formattedTime =
                        "${time.day}/${time.month}/${time.year} - ${time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}";
                    return Card(
                      elevation: 0.5,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.redAccent.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.money_off,
                            color: Colors.redAccent,
                          ),
                        ),
                        title: Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                note,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "৳${data['amount']}",
                              style: TextStyle(
                                color: Colors.redAccent[700],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => _deleteExpense(id),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: Colors.redAccent[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "নতুন খরচ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
