import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:local_auth/local_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LocalAuthentication auth = LocalAuthentication();

  bool isDoorOpen      = false;
  bool isSystemLocked  = false; 
  String _adminPassword = "---";

  @override
  void initState() {
    super.initState();
    _loadAdminPassword();
    _listenToFirebase();
  }

  // Tải mật khẩu Admin về để dự phòng trường hợp Vân tay bị lỗi
  Future<void> _loadAdminPassword() async {
    final snap = await _dbRef.child('config/admin_password').get();
    if (snap.exists) {
      if (mounted) setState(() => _adminPassword = snap.value.toString());
    }
  }

  void _listenToFirebase() {
    // 1. LẮNG NGHE TRẠNG THÁI CỬA (ESP32 sẽ báo cho App biết khi nào cửa thực sự mở/đóng)
    _dbRef.child("door_status").onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => isDoorOpen = (event.snapshot.value.toString() == "1"));
      }
    });

    // 2. LẮNG NGHE TRẠNG THÁI AN NINH (Khóa hệ thống)
    _dbRef.child("system_command").onValue.listen((event) {
      if (!mounted) return;
      String cmd = event.snapshot.value?.toString() ?? "idle";
      bool locked = cmd == "locked";
      setState(() => isSystemLocked = locked);
      if (locked) _showLockedDialog();
    });
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(children: [
          Icon(Icons.lock, color: Colors.redAccent),
          SizedBox(width: 8),
          Text("Hệ thống bị khóa!", style: TextStyle(color: Colors.redAccent)),
        ]),
        content: const Text("Nhập sai quá nhiều lần.\nBạn có muốn mở khóa từ xa không?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Để sau", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open, color: Colors.white),
            label: const Text("Mở khóa ngay", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(ctx); _remoteUnlock(); },
          ),
        ],
      ),
    );
  }

  // --- HÀM BẢO MẬT 2 LỚP: VÂN TAY -> NẾU LỖI THÌ NHẬP PASS ---
  Future<bool> _authenticate() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        bool authenticated = await auth.authenticate(
          localizedReason: 'Xác thực để thực hiện thao tác',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
        if (authenticated) return true;
      }
    } catch (e) {
      print("Lỗi vân tay: $e");
    }
    
    // NẾU VÂN TAY THẤT BẠI HOẶC BỊ HỦY -> HIỆN BẢNG NHẬP MẬT KHẨU ADMIN
    return await _promptAdminPassword();
  }

  Future<bool> _promptAdminPassword() async {
    final controller = TextEditingController();
    bool isCorrect = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.orangeAccent, size: 55),
              const SizedBox(height: 15),
              const Text("XÁC THỰC BẰNG MẬT KHẨU", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Vân tay thất bại, vui lòng nhập Pass Admin", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 25),
              TextField(
                controller: controller, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  filled: true, fillColor: const Color(0xFF0F0F1A), hintText: "••••••", hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("HỦY", style: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        if (controller.text == _adminPassword) {
                          isCorrect = true; Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sai mật khẩu Admin!'), backgroundColor: Colors.redAccent));
                        }
                      },
                      child: const Text("XÁC NHẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    return isCorrect;
  }

  // --- HÀM MỞ KHÓA HỆ THỐNG (TỪ XA) ---
  Future<void> _remoteUnlock() async {
    bool ok = await _authenticate(); // Gọi hàm bảo mật 2 lớp
    if (!ok) return; 
    
    // Gửi lệnh unlock_admin xuống mạch
    await _dbRef.child("system_command").set("unlock_admin");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Đã gửi lệnh mở khóa hệ thống!"), backgroundColor: Colors.green),
      );
    }
  }

  // --- HÀM NÚT BẤM MỞ CỬA CHÍNH (ĐÃ FIX LỖI KẸT GIAO DIỆN) ---
  Future<void> _handleDoorAction() async {
    if (!isDoorOpen) {
      bool ok = await _authenticate(); // Yêu cầu vân tay / pass
      if (!ok) return;
      
      // CHUẨN XÁC: Gửi chữ 'open' vào 'system_command' để gọi ESP32
      _dbRef.child("system_command").set("open"); 
    } else {
      // Khi cửa ĐANG MỞ, bấm vào nút thì không làm gì cả, chờ mạch ESP32 tự đóng sau 5s
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cửa đang mở, sẽ tự động khóa lại sau 5 giây!'), backgroundColor: Colors.orangeAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("SMART LOCK", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: const Color(0xFF161625),
        elevation: 0,
        actions: [
          if (isSystemLocked)
            IconButton(
              icon: const Icon(Icons.lock_open, color: Colors.redAccent),
              tooltip: "Mở khóa từ xa",
              onPressed: _remoteUnlock,
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSystemLocked)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.redAccent)),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.redAccent, size: 30),
                    const SizedBox(width: 15),
                    const Expanded(child: Text("HỆ THỐNG ĐANG BỊ KHÓA AN NINH!", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: _remoteUnlock,
                      child: const Text("MỞ KHÓA", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),

            GestureDetector(
              onTap: _handleDoorAction,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDoorOpen ? Colors.greenAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                  border: Border.all(color: isDoorOpen ? Colors.greenAccent : Colors.blueAccent, width: 4),
                  boxShadow: [
                    BoxShadow(color: isDoorOpen ? Colors.greenAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.3), blurRadius: 50, spreadRadius: 10)
                  ]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDoorOpen ? Icons.lock_open : Icons.lock,
                      size: 100, 
                      color: isDoorOpen ? Colors.greenAccent : Colors.blueAccent
                    ),
                    const SizedBox(height: 15),
                    Text(
                      isDoorOpen ? "CỬA ĐANG MỞ" : "CỬA ĐANG KHÓA",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDoorOpen ? Colors.greenAccent : Colors.blueAccent
                      )
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text("Chạm vào biểu tượng để điều khiển", style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}