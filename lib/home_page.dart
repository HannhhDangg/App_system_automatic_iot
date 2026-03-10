import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:local_auth/local_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final LocalAuthentication auth = LocalAuthentication();
  final SpeechToText _speechToText = SpeechToText();

  bool isDoorOpen = false;
  bool isLightOn = false;
  bool isCurtainOpen = false;
  String _lastWords = 'Chạm vào Micro để ra lệnh';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _listenToFirebase();
    _initSpeech();
    _listenToCardNotifications();
  }

  void _listenToFirebase() {
    _dbRef.child("door_status").onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => isDoorOpen = (event.snapshot.value.toString() == "1"));
      }
    });
    _dbRef.child("light_status").onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => isLightOn = (event.snapshot.value.toString() == "1"));
      }
    });
    _dbRef.child("curtain_status").onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => isCurtainOpen = (event.snapshot.value.toString() == "1"));
      }
    });
  }

  void _listenToCardNotifications() {
    _dbRef.child("last_id").onValue.listen((event) async {
      String cardId = event.snapshot.value?.toString() ?? "None";
      if (cardId != "None" && cardId != "null" && mounted) {
        DataSnapshot memberData = await _dbRef.child("members").child(cardId).get();
        DataSnapshot adminData = await _dbRef.child("admin").get();
        
        String name = "Khách lạ";
        if (memberData.exists) {
          name = (memberData.value as Map)['name'] ?? "Không tên";
        }
        if (adminData.exists && (adminData.value as Map)['uid'] == cardId) {
          name = "ADMIN: ${(adminData.value as Map)['name']}";
        }
        _showCardDialog(name, cardId);
      }
    });
  }

  void _showCardDialog(String name, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thông báo ra vào"),
        content: Text("Người dùng: $name\nID: $id"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))
        ],
      ),
    );
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize(onStatus: (status) {
      if (status == 'notListening' || status == 'done') {
        setState(() => _isListening = false);
      }
    });
  }

  // Hàm xử lý khi bấm vào Đèn/Rèm
  void _toggleDevice(String path, bool currentStatus) {
    _dbRef.child(path).set(currentStatus ? 0 : 1);
  }

  Future<void> _handleDoorAction() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        // Nếu máy không có vân tay, cho phép mở thẳng để test
        _dbRef.child("door_status").set(!isDoorOpen ? 1 : 0);
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Xác thực để điều khiển cửa',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _dbRef.child("door_status").set(!isDoorOpen ? 1 : 0);
      }
    } on PlatformException catch (e) {
      print("Lỗi xác thực: $e");
    }
  }

  void _processVoiceCommand(String words) {
    String w = words.toLowerCase();
    if (w.contains("bật đèn")) _dbRef.child("light_status").set(1);
    else if (w.contains("tắt đèn")) _dbRef.child("light_status").set(0);
    
    if (w.contains("mở rèm")) _dbRef.child("curtain_status").set(1);
    else if (w.contains("đóng rèm")) _dbRef.child("curtain_status").set(0);

    if (w.contains("mở cửa")) _handleDoorAction();
  }

  Future<void> _toggleListening() async {
    if (await Permission.microphone.request().isGranted) {
      if (!_isListening) {
        setState(() { _isListening = true; _lastWords = "Đang lắng nghe..."; });
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              if (result.finalResult) _processVoiceCommand(result.recognizedWords);
            });
          },
          localeId: "vi_VN",
          listenMode: ListenMode.confirmation,
        );
      } else {
        setState(() => _isListening = false);
        await _speechToText.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Smart Home Voice", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator(
                "Đèn", isLightOn, Icons.lightbulb, Colors.yellow, 
                () => _toggleDevice("light_status", isLightOn)
              ),
              _buildStatusIndicator(
                "Rèm", isCurtainOpen, Icons.curtains, Colors.blue, 
                () => _toggleDevice("curtain_status", isCurtainOpen)
              ),
            ],
          ),
          const Spacer(),
          // Nút bấm Cửa
          GestureDetector(
            onTap: _handleDoorAction,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: isDoorOpen ? Colors.green.shade50 : Colors.red.shade50,
                  child: Icon(
                    isDoorOpen ? Icons.lock_open : Icons.lock, 
                    size: 70, 
                    color: isDoorOpen ? Colors.green : Colors.red
                  ),
                ),
                const SizedBox(height: 10),
                Text(isDoorOpen ? "CỬA ĐANG MỞ" : "CỬA ĐANG KHÓA", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDoorOpen ? Colors.green : Colors.red)
                ),
              ],
            ),
          ),
          const Spacer(),
          // Vùng Voice Control
          Container(
            padding: const EdgeInsets.all(30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
            ),
            child: Column(
              children: [
                Text(
                  _lastWords,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: _isListening ? Colors.blue : Colors.black54, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _toggleListening,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: _isListening ? Colors.red : Colors.blue,
                    child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 40),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị trạng thái có thêm chức năng bấm
  Widget _buildStatusIndicator(String title, bool isOn, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Icon(icon, size: 45, color: isOn ? color : Colors.grey[300]),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              isOn ? "BẬT" : "TẮT",
              style: TextStyle(fontSize: 12, color: isOn ? color : Colors.grey, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}