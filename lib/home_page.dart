import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Thêm dòng này

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isOpen = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  void toggleDoor() {
    setState(() {
      isOpen = !isOpen;
    });
    
    // --- GỬI LÊN FIREBASE ---
    // Gửi 1 để mở cửa, 0 để đóng cửa
    _dbRef.child("door_status").set(isOpen ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Điều khiển cửa")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: toggleDoor,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(50),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOpen ? Icons.lock_open : Icons.lock,
                  size: 120,
                  color: isOpen ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOpen ? "CỬA ĐANG MỞ" : "CỬA ĐANG ĐÓNG",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            FloatingActionButton.large(
              onPressed: () {
                // Sẽ tích hợp giọng nói ở đây
              },
              child: const Icon(Icons.mic, size: 50),
            ),
            const SizedBox(height: 15),
            const Text("Nhấn để ra lệnh giọng nói"),
          ],
        ),
      ),
    );
  }
}