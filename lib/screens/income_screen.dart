//আয়ের হিসাব স্ক্রিন

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final CollectionReference _incomes = FirebaseFirestore.instance.collection('incomes');
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // নতুন আয় যোগ করার ফাংশন
  Future<void> _addIncome() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("দয়া করে টাকার পরিমাণ লিখুন!")));
      return;
    }

    await _incomes.add({
      'note': _noteController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _noteController.clear();
    _amountController.clear();
    if (mounted) Navigator.pop(context);
  }

  // আয় ডিলিট করার ফাংশন
  Future<void> _deleteIncome(String id) async {
    await _incomes.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("আয়ের হিসাব"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _incomes.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)).orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          double totalIncome = 0.0;
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              totalIncome += (doc.data() as Map<String, dynamic>)['amount'] as double;
            }
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("এই মাসের মোট আয়", style: TextStyle(color: Colors.white, fontSize: 18)),
                  Text("৳$totalIncome", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data?.docs.length ?? 0,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.greenAccent, child: Icon(Icons.add, color: Colors.green)),
                        title: Text(data['note'] ?? "নতুন আয়"),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text("৳${data['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _deleteIncome(doc.id)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => showDialog(context: context, builder: (context) => AlertDialog(
          title: const Text("নতুন আয় যোগ করুন"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "পরিমাণ (৳)")),
            TextField(controller: _noteController, decoration: const InputDecoration(labelText: "উৎস বা নোট")),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("বাতিল")), ElevatedButton(onPressed: _addIncome, child: const Text("সেভ"))],
        )),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}