import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedReminderTime;
  String? _editingNoteId;
  bool _isEditing = false;
  bool _isSearching = false;
  String _searchQuery = '';
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Notification Plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initAnimations();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _initAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutBack,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // নোটিফিকেশন ইনিশিয়ালাইজেশন (v22+ Named Syntax)
  void _initializeNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // নোটিফিকেশনে ট্যাপ করলে এখানে অ্যাকশন হ্যান্ডেল করতে পারবেন
      },
    );
  }

  // রিমাইন্ডার শিডিউল করা (v22+ Named Syntax)
  Future<void> _scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'note_reminder_channel',
          'Note Reminders',
          channelDescription: 'Channel for Note Reminders',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ডেট এবং টাইম পিকার
  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6C63FF),
                onPrimary: Colors.white,
                onSurface: Color(0xFF2C3E50),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedReminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // নোট এবং রিমাইন্ডার সেভ করা (এডিটের জন্য আপডেট)
  void _addNote() async {
    if (_noteController.text.isNotEmpty) {
      String noteContent = _noteController.text;

      if (_isEditing && _editingNoteId != null) {
        // এডিট মোড - নোট আপডেট করা
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('notes')
            .doc(_editingNoteId);

        // পুরাতন রিমাইন্ডার থাকলে নোটিফিকেশন ক্যানসেল করা
        DocumentSnapshot oldNote = await docRef.get();
        if (oldNote['reminderTime'] != null) {
          try {
            await flutterLocalNotificationsPlugin.cancel(
              id: _editingNoteId!.hashCode,
            );
          } catch (e) {
            debugPrint("Notification Cancel Error: $e");
          }
        }

        // নোট আপডেট করা
        await docRef.update({
          'content': noteContent,
          'reminderTime': _selectedReminderTime != null
              ? Timestamp.fromDate(_selectedReminderTime!)
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // নতুন রিমাইন্ডার সেট করা থাকলে নোটিফিকেশন শিডিউল করা
        if (_selectedReminderTime != null) {
          int notificationId = _editingNoteId!.hashCode;
          try {
            await _scheduleNotification(
              notificationId,
              "📝 রিমাইন্ডার",
              noteContent,
              _selectedReminderTime!,
            );
          } catch (e) {
            debugPrint("Notification Scheduling Error: $e");
          }
        }

        setState(() {
          _isEditing = false;
          _editingNoteId = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("নোট আপডেট করা হয়েছে!"),
              backgroundColor: const Color(0xFF6C63FF),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // নতুন নোট অ্যাড করা
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('notes')
            .add({
              'content': noteContent,
              'timestamp': FieldValue.serverTimestamp(),
              'reminderTime': _selectedReminderTime != null
                  ? Timestamp.fromDate(_selectedReminderTime!)
                  : null,
            });

        // রিমাইন্ডার সেট করা থাকলে নোটিফিকেশন শিডিউল করা হবে
        if (_selectedReminderTime != null) {
          int notificationId = docRef.id.hashCode;
          try {
            await _scheduleNotification(
              notificationId,
              "📝 রিমাইন্ডার",
              noteContent,
              _selectedReminderTime!,
            );
          } catch (e) {
            debugPrint("Notification Scheduling Error: $e");
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("নোট সেভ করা হয়েছে!"),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      _noteController.clear();
      setState(() {
        _selectedReminderTime = null;
      });
      if (mounted) Navigator.pop(context);
    }
  }

  // নোট এডিট করার জন্য ডেটা লোড করা
  void _editNote(DocumentSnapshot note) {
    setState(() {
      _isEditing = true;
      _editingNoteId = note.id;
      _noteController.text = note['content'] ?? '';
      _selectedReminderTime = note['reminderTime']?.toDate();
    });

    _showAddNoteBottomSheet();
  }

  // ডিলিট কনফার্মেশন ডায়ালগ
  void _showDeleteDialog(DocumentSnapshot note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            const Text(
              "নোট মুছবেন?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "আপনি কি নিশ্চিত যে এই নোটটি মুছে ফেলতে চান?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("বাতিল", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              // নোটিফিকেশন ক্যানসেল করা (v22+ Named Syntax)
              if (note['reminderTime'] != null) {
                try {
                  await flutterLocalNotificationsPlugin.cancel(
                    id: note.id.hashCode,
                  );
                } catch (e) {
                  debugPrint("Notification Cancel Error: $e");
                }
              }
              await note.reference.delete();
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("নোট মুছে ফেলা হয়েছে!"),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text("মুছুন", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // নতুন নোট অ্যাড করার বটম শিট (এডিট সাপোর্ট সহ)
  void _showAddNoteBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isEditing
                                ? [Colors.blue.shade400, Colors.blue.shade700]
                                : [
                                    const Color(0xFF6C63FF),
                                    const Color(0xFF8B83FF),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isEditing ? Icons.edit : Icons.note_add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isEditing ? "নোট এডিট করুন" : "নতুন নোট লিখুন",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      if (_isEditing)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _editingNoteId = null;
                              _noteController.clear();
                              _selectedReminderTime = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            "বাতিল",
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Note input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "আপনার নোট লিখুন...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reminder section
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedReminderTime != null
                          ? const Color(0xFFF3F0FF)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedReminderTime != null
                            ? const Color(0xFF6C63FF)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          color: _selectedReminderTime != null
                              ? const Color(0xFF6C63FF)
                              : Colors.grey.shade400,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedReminderTime == null
                                ? "রিমাইন্ডার সেট করুন"
                                : DateFormat(
                                    'EEE, MMM dd • hh:mm a',
                                  ).format(_selectedReminderTime!),
                            style: TextStyle(
                              color: _selectedReminderTime != null
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey.shade500,
                              fontWeight: _selectedReminderTime != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedReminderTime != null)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedReminderTime = null;
                              });
                              setModalState(() {});
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.add_alert,
                            color: _selectedReminderTime != null
                                ? const Color(0xFF6C63FF)
                                : Colors.grey.shade400,
                          ),
                          onPressed: () async {
                            await _pickDateTime();
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditing
                            ? Colors.blue.shade600
                            : const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _addNote,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEditing ? Icons.update : Icons.save,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isEditing ? "আপডেট করুন" : "সেভ করুন",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Search functionality - toggle search
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "নোট খুঁজুন...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        setState(() {});
                      },
                    ),
                  ),
                ),
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.note_alt,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "ডেইলি নোটস",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _toggleSearch,
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notes')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "নোট লোড হচ্ছে...",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.note_alt_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "কোনো নোট নেই",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "নতুন নোট যোগ করতে নিচের বাটনে ক্লিক করুন",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          // Filter notes based on search query
          List<QueryDocumentSnapshot> filteredNotes = snapshot.data!.docs;
          if (_searchQuery.isNotEmpty) {
            filteredNotes = filteredNotes.where((note) {
              String content = note['content']?.toString().toLowerCase() ?? '';
              return content.contains(_searchQuery);
            }).toList();
          }

          if (filteredNotes.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "কোনো নোট পাওয়া যায়নি",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "'$_searchQuery' এর জন্য কোনো ম্যাচ নেই",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotes.length,
            itemBuilder: (context, index) {
              var note = filteredNotes[index];
              Timestamp? reminderTimestamp = note['reminderTime'];
              DateTime? reminderDate = reminderTimestamp?.toDate();

              // নিরাপদে চেক করা হচ্ছে updatedAt ফিল্ড আছে কিনা
              bool hasUpdatedAt =
                  note.data()?.containsKey('updatedAt') ?? false;
              Timestamp? updatedTimestamp = hasUpdatedAt
                  ? note['updatedAt']
                  : null;

              // Highlight matched text
              String content = note['content'] ?? '';
              bool isMatch =
                  _searchQuery.isNotEmpty &&
                  content.toLowerCase().contains(_searchQuery);

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isMatch ? const Color(0xFFF3F0FF) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isMatch
                          ? const Color(0xFF6C63FF).withOpacity(0.1)
                          : Colors.grey.shade200,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: isMatch ? 4 : 2,
                    ),
                  ],
                  border: Border(
                    left: BorderSide(
                      color: isMatch
                          ? const Color(0xFF6C63FF)
                          : reminderDate != null
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade300,
                      width: isMatch ? 6 : 4,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _editNote(note),
                    onLongPress: () => _showDeleteDialog(note),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: isMatch && _searchQuery.isNotEmpty
                                    ? _buildHighlightedText(
                                        content,
                                        _searchQuery,
                                        const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF2C3E50),
                                          height: 1.5,
                                        ),
                                      )
                                    : Text(
                                        content,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF2C3E50),
                                          height: 1.5,
                                        ),
                                      ),
                              ),
                              if (isMatch)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF6C63FF),
                                        const Color(0xFF8B83FF),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "ম্যাচ",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (updatedTimestamp != null && !isMatch)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "এডিট",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (reminderDate != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6C63FF).withOpacity(0.1),
                                    const Color(0xFF6C63FF).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alarm,
                                    size: 14,
                                    color: const Color(0xFF6C63FF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy - hh:mm a',
                                    ).format(reminderDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6C63FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF6C63FF),
          elevation: 8,
          onPressed: () {
            // Close search if open
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _searchQuery = '';
              });
            }
            setState(() {
              _isEditing = false;
              _editingNoteId = null;
              _noteController.clear();
              _selectedReminderTime = null;
            });
            _showAddNoteBottomSheet();
          },
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  // Helper method to build highlighted text
  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final int matchIndex = lowerText.indexOf(lowerQuery, start);
      if (matchIndex == -1) {
        // No more matches
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      // Add text before match
      if (matchIndex > start) {
        spans.add(
          TextSpan(text: text.substring(start, matchIndex), style: style),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: style.copyWith(
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6C63FF),
          ),
        ),
      );

      start = matchIndex + query.length;
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }
}

extension on Object? {
  bool? containsKey(String s) {}
}
