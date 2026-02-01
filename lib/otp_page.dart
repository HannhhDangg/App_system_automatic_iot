import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  String otpCode = "------";
  int _secondsRemaining = 300;
  Timer? _timer;
  StreamSubscription<DatabaseEvent>? _otpSubscription; // Để hủy lắng nghe khi chuyển trang
  
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    // 1. Lắng nghe mã OTP từ Firebase để không bị mất khi chuyển trang
    _otpSubscription = _dbRef.child("current_otp").onValue.listen((event) {
      final data = event.snapshot.value;
      if (mounted && data != null) {
        setState(() {
          otpCode = data.toString();
          // Nếu mã mới được tạo từ thiết bị khác, reset lại bộ đếm 5 phút
          if (otpCode != "EXPIRED" && otpCode != "expired" && otpCode != "------") {
            _startTimer();
          }
        });
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            otpCode = "EXPIRED";
            _dbRef.child("current_otp").set("expired");
            _timer?.cancel();
          }
        });
      }
    });
  }

  void generateOTP() {
    // Tạo mã 6 số mới và đẩy lên Firebase
    String newCode = (Random().nextInt(900000) + 100000).toString();
    _dbRef.child("current_otp").set(newCode);
    _startTimer(); // Bắt đầu đếm ngược ngay lập tức
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpSubscription?.cancel(); // Hủy lắng nghe Firebase để tránh rò rỉ bộ nhớ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mã mở cửa tạm thời")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            const Text(
              "MÃ OTP HIỆN TẠI TRÊN CLOUD",
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                otpCode,
                style: const TextStyle(
                  fontSize: 50, 
                  letterSpacing: 5, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.blue
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (otpCode != "EXPIRED" && otpCode != "expired" && otpCode != "------")
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_sharp, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  "Hiệu lực còn: ${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _secondsRemaining < 30 ? Colors.red : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: generateOTP,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("TẠO MÃ MỚI", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}