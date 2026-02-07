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
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String otpCode = "------";
  int _secondsRemaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  void _listenToFirebase() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (mounted && data != null) {
        setState(() {
          otpCode = data['current_otp']?.toString() ?? "------";
          int expiry = data['expiry_time'] ?? 0;
          int now = DateTime.now().millisecondsSinceEpoch;
          
          // Chặn số âm
          int diff = ((expiry - now) / 1000).round();
          _secondsRemaining = diff > 0 ? diff : 0; 
          
          if (_secondsRemaining > 0) {
            _startLocalTimer();
          } else {
            otpCode = "EXPIRED";
          }
        });
      }
    });
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => otpCode = "EXPIRED");
        timer.cancel();
      }
    });
  }

  void generateOTP() {
    String newCode = (Random().nextInt(900000) + 100000).toString();
    int expiryTime = DateTime.now().millisecondsSinceEpoch + 7200000; // 2 Tiếng
    _dbRef.update({"current_otp": newCode, "expiry_time": expiryTime, "otp_used": false});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mã OTP")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: _secondsRemaining > 0 ? Colors.blue : Colors.red),
            const SizedBox(height: 20),
            Text(otpCode, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _secondsRemaining > 0 ? Colors.black : Colors.red)),
            const SizedBox(height: 20),
            // Hiển thị trạng thái thay vì số âm
            Text(
              _secondsRemaining > 0 ? "Còn hiệu lực: ${_secondsRemaining ~/ 60} phút" : "Mã đã hết hiệu lực",
              style: TextStyle(color: _secondsRemaining > 0 ? Colors.black : Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(onPressed: generateOTP, child: const Text("TẠO MÃ MỚI")),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}