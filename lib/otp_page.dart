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

  String  otpCode          = "------";
  int     _secondsRemaining = 0;
  Timer?  _timer;
  bool    _wasUsed         = true;
  bool    _firstLoad       = true; // ← THÊM: bỏ qua lần đầu load

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
  }

  void _listenToFirebase() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (!mounted || data == null) return;

      final String newOtp  = data['current_otp']?.toString() ?? "------";
      final int    expiry  = data['expiry_time']  ?? 0;
      final bool   isUsed  = data['otp_used'] == true;
      final int    now     = DateTime.now().millisecondsSinceEpoch;
      final int    diff    = ((expiry - now) / 1000).round();

      // ── Phát hiện OTP vừa được dùng ──
      // Chỉ hiện thông báo khi:
      // 1. Không phải lần đầu load (_firstLoad = false)
      // 2. Trước đó chưa dùng (_wasUsed = false)
      // 3. Bây giờ đã dùng (isUsed = true)
      // 4. OTP là số thật (không phải EXPIRED/rỗng)
      if (!_firstLoad && !_wasUsed && isUsed &&
          newOtp != "------" && newOtp != "EXPIRED" &&
          newOtp.length == 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Khách vừa sử dụng mã OTP mở cửa!")
              ]),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        });
      }

      setState(() {
        otpCode   = newOtp;
        _wasUsed  = isUsed;
        _firstLoad = false; // ← sau lần đầu load xong, tắt flag

        if (!isUsed && diff > 0) {
          _secondsRemaining = diff;
          _startLocalTimer();
        } else {
          _secondsRemaining = 0;
          _timer?.cancel();
          if (isUsed) {
            otpCode = "ĐÃ SỬ DỤNG";
          } else if (diff <= 0 && newOtp != "------") {
            otpCode = "HẾT HẠN";
            // Chỉ báo hết hạn lên Firebase, KHÔNG set otp_used
            // để ESP32 tự xử lý theo expiry_time
            _dbRef.update({"current_otp": "EXPIRED"});
          }
        }
      });
    });
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
if (!mounted) { timer.cancel(); return; }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          otpCode = "HẾT HẠN";
        });
        // KHÔNG ghi otp_used=true ở đây
        // Chỉ đánh dấu OTP hết hạn, để ESP32 tự check expiry_time
        _dbRef.update({"current_otp": "EXPIRED"});

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.timer_off, color: Colors.white),
              SizedBox(width: 10),
              Text("Mã OTP đã hết hiệu lực!")
            ]),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void generateOTP() {
    // Hủy timer cũ
    _timer?.cancel();

    String newCode   = (Random().nextInt(900000) + 100000).toString();
    int    expiryMs  = DateTime.now().millisecondsSinceEpoch + 3600000;

    // Reset flag trước khi ghi Firebase
    // để không trigger thông báo "đã dùng" nhầm
    setState(() {
      _wasUsed  = false;
      _firstLoad = false;
      otpCode   = newCode;
      _secondsRemaining = 3600;
    });

    _dbRef.update({
      "current_otp"  : newCode,
      "expiry_time"  : expiryMs,
      "otp_used"     : false,   // ← reset về false
    });

    _startLocalTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isActive = _secondsRemaining > 0 && !_wasUsed;
    Color activeColor = _wasUsed
        ? Colors.greenAccent
        : (isActive ? Colors.blueAccent : Colors.redAccent);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("MÃ OTP KHÁCH",
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: const Color(0xFF161625),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _wasUsed
                  ? Icons.verified_user
                  : (isActive ? Icons.security_rounded : Icons.gpp_bad),
              size: 100,
              color: activeColor,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeColor, width: 2),
                boxShadow: [
                  BoxShadow(
color: activeColor.withOpacity(0.2), blurRadius: 20)
                ],
              ),
              child: Text(
                otpCode,
                style: TextStyle(
                  fontSize: (_wasUsed || otpCode == "HẾT HẠN" ||
                          otpCode == "ĐÃ SỬ DỤNG")
                      ? 28
                      : 50,
                  fontWeight: FontWeight.bold,
                  letterSpacing: (_wasUsed || otpCode == "HẾT HẠN") ? 2 : 8,
                  color: _wasUsed ? Colors.greenAccent : (isActive ? Colors.white : Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              _wasUsed
                  ? "Mã này đã được mở cửa thành công"
                  : (isActive
                      ? "⏳ Còn: ${_secondsRemaining ~/ 60}p ${(_secondsRemaining % 60).toString().padLeft(2, '0')}s"
                      : "Mã đã không còn khả dụng"),
              style: TextStyle(
                  color: activeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            SizedBox(
              height: 55,
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: generateOTP,
                child: const Text("TẠO MÃ MỚI",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
