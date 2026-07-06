import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final CollectionReference _expenses = FirebaseFirestore.instance.collection(
    'expenses',
  );
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  void _addExpense() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("নতুন খরচ এন্ট্রি"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: "কীসের খরচ? (যেমন: চা-নাস্তা)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "পরিমাণ (৳)",
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (_noteController.text.isNotEmpty &&
                  _amountController.text.isNotEmpty) {
                await _expenses.add({
                  'note': _noteController.text.trim(),
                  'amount': double.parse(_amountController.text.trim()),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                _noteController.clear();
                _amountController.clear();
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

  @override
  Widget build(BuildContext context) {
    DateTime startOfToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("প্রাত্যহিক খরচ"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _expenses
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
            )
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("আজকের কোনো খরচ নেই!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.money_off, color: Colors.redAccent),
                  title: Text(
                    doc['note'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    "৳${doc['amount']}",
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "খরচ যোগ করুন",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
