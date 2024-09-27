import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz01/screen/signin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF8BBD0)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8BBD0),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFF8BBD0),
        ),
      ),
      home: const SigninScreen(),
    );
  }
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _noteController;

  String _selectedType = 'Income'; // Default type
  User? user;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _dateController =
        TextEditingController(); // Keep date as a TextEditingController for display
    _noteController = TextEditingController();
    user = FirebaseAuth.instance.currentUser; // Get current user
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SigninScreen()),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedDate != null) {
      setState(() {
        _dateController.text =
            "${selectedDate.toLocal()}".split(' ')[0]; // Format the date
      });
    }
  }

  void addExpenseHandle(BuildContext context, [DocumentSnapshot? doc]) {
    if (doc != null) {
      _amountController.text = doc['amount'].toString();
      _dateController.text = doc['date'];
      _selectedType = doc['type']; // Set the selected type
      _noteController.text = doc['note'];
    } else {
      _amountController.clear();
      _dateController.clear();
      _selectedType = 'Income'; // Reset to default
      _noteController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            doc != null ? "Edit Record" : "Add New Record",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Amount",
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dateController,
                  readOnly: true, // Make it read-only to prevent manual entry
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Date",
                  ),
                  onTap: () => _selectDate(context), // Trigger the date picker
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'Income', child: Text('Income')),
                    DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Type",
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!; // Update the selected type
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Note",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (doc != null) {
                  // Update existing record
                  FirebaseFirestore.instance
                      .collection(user!.email!)
                      .doc(doc.id)
                      .update({
                    'amount': _amountController.text,
                    'date': _dateController.text,
                    'type': _selectedType,
                    'note': _noteController.text,
                  });
                } else {
                  // Add new record
                  FirebaseFirestore.instance.collection(user!.email!).add({
                    'amount': _amountController.text,
                    'date': _dateController.text,
                    'type': _selectedType,
                    'note': _noteController.text,
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void deleteRecord(String id) {
    FirebaseFirestore.instance.collection(user!.email!).doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Tracker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection(user!.email!).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No records available"));
          }

          // Calculate total income and expense
          double totalIncome = 0;
          double totalExpense = 0;

          for (var record in snapshot.data!.docs) {
            if (record['type'].toLowerCase() == 'income') {
              totalIncome += double.tryParse(record['amount']) ?? 0;
            } else {
              totalExpense += double.tryParse(record['amount']) ?? 0;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Total Income: $totalIncome\nTotal Expense: $totalExpense",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: snapshot.data?.docs.length,
                  itemBuilder: (context, index) {
                    var record = snapshot.data!.docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: ListTile(
                        title: Text("Amount: ${record['amount']}"),
                        subtitle: Text(
                            "Date: ${record['date']}\nType: ${record['type']}\nNote: ${record['note']}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => deleteRecord(record.id),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          addExpenseHandle(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
