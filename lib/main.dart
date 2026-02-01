import 'package:flutter/material.dart';
import 'home_page.dart';
import 'otp_page.dart'; // File mới
import 'package:firebase_core/firebase_core.dart'; // Thêm dòng này
import 'firebase_options.dart'; // Thêm dòng này
import 'history_page.dart';
import 'member_page.dart';

void main() async {
  // Đảm bảo các dịch vụ hệ thống được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase với dự án SmartHomeDoorLock
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SmartLockApp());
}

class SmartLockApp extends StatelessWidget {
  const SmartLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const OtpPage(), // Thêm trang OTP vào đây
    const HistoryPage(),
    const MemberPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // Giúp hiển thị tốt khi có 4 icon
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.lock_open), label: 'Khóa'),
          BottomNavigationBarItem(icon: Icon(Icons.vibration), label: 'Mã OTP'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Thành viên'),
        ],
      ),
    );
  }
}