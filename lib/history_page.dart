import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  
  // Lưu cả Tên và Giới tính
  Map<String, String> _userMap = {};
  Map<String, String> _genderMap = {}; 

  @override
  void initState() {
    super.initState();
    _fetchUsersDictionary();
  }

  void _fetchUsersDictionary() {
    // Lấy danh sách thành viên
    dbRef.child('members').onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        Map members = event.snapshot.value as Map;
        members.forEach((key, value) {
          if (value is Map) {
            _userMap[key.toString()] = value['name'] ?? 'Không tên';
            _genderMap[key.toString()] = value['gender'] ?? 'Khác';
          }
        });
        if (mounted) setState(() {});
      }
    });

    // Lấy danh sách admin
    dbRef.child('admin_cards').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map && value['uid'] != null) {
              _userMap[value['uid'].toString()] = "ADMIN: ${value['name']}";
              _genderMap[value['uid'].toString()] = value['gender'] ?? 'Khác';
            }
          });
        } else if (data is List) {
          for (var value in data) {
            if (value is Map && value['uid'] != null) {
              _userMap[value['uid'].toString()] = "ADMIN: ${value['name']}";
              _genderMap[value['uid'].toString()] = value['gender'] ?? 'Khác';
            }
          }
        }
        if (mounted) setState(() {});
      }
    });
  }

  int _getValidTimestamp(dynamic item) {
    if (item == null || item is! Map) return 0;
    dynamic t = item['timestamp'] ?? item['ts'] ?? 0;
    
    if (t is int) return t;
    if (t is double) return t.toInt();
    if (t is String) return int.tryParse(t) ?? 0;
    return 0;
  }

  void _showDeleteAllConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent), SizedBox(width: 8), Text("Xóa toàn bộ?", style: TextStyle(color: Colors.redAccent))]),
        content: const Text("Hành động này sẽ xóa vĩnh viễn toàn bộ lịch sử. Bạn có chắc chắn không?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              dbRef.child('logs').remove(); Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã dọn dẹp sạch lịch sử!"), backgroundColor: Colors.green));
            },
            child: const Text("Xóa sạch", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text("LỊCH SỬ RA VÀO", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900)),
        centerTitle: true, backgroundColor: const Color(0xFF161625), elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28), onPressed: _showDeleteAllConfirm)],
      ),
      body: StreamBuilder(
        stream: dbRef.child('logs').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final rawData = snapshot.data!.snapshot.value;
            List<MapEntry<dynamic, dynamic>> allLogs = [];

            if (rawData is Map) {
              allLogs = rawData.entries.where((e) => e.value is Map).toList();
            } else if (rawData is List) {
              for (int i = 0; i < rawData.length; i++) {
                if (rawData[i] != null && rawData[i] is Map) allLogs.add(MapEntry(i.toString(), rawData[i]));
              }
            }

            // LOẠI BỎ RÁC VÀ LOẠI BỎ SỰ KIỆN ĐÓNG CỬA
            allLogs.removeWhere((element) {
              Map item = element.value as Map;
              String methodRaw = (item['method'] ?? item['event'] ?? item['action'] ?? '').toString().toLowerCase();
              int ts = _getValidTimestamp(item);
              
              // Xóa nếu thời gian = 0 (rác) HOẶC là sự kiện khóa cửa
              return ts == 0 || methodRaw.contains("close");
            });
            
            allLogs.sort((a, b) => _getValidTimestamp(b.value).compareTo(_getValidTimestamp(a.value)));
            
            if (allLogs.isEmpty) return const Center(child: Text("Lịch sử trống.", style: TextStyle(color: Colors.white54)));

            int totalItems = allLogs.length;
            int totalPages = (totalItems / _itemsPerPage).ceil();
            if (_currentPage > totalPages) _currentPage = totalPages;
            if (_currentPage < 1) _currentPage = 1;

            int startIndex = (_currentPage - 1) * _itemsPerPage;
            int endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
            List<MapEntry<dynamic, dynamic>> currentPageLogs = allLogs.sublist(startIndex, endIndex);

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: currentPageLogs.length,
                    itemBuilder: (context, index) => _buildLogCard(currentPageLogs[index]),
                  ),
                ),
                if (totalPages > 1) _buildPaginationControls(totalPages),
              ],
            );
          }
          return const Center(child: Text("Chưa có lịch sử.", style: TextStyle(color: Colors.white54, fontSize: 16)));
        },
      ),
    );
  }

  Widget _buildLogCard(MapEntry<dynamic, dynamic> entry) {
    String logKey = entry.key.toString();
    Map item = entry.value as Map;

    String methodRaw = (item['method'] ?? item['event'] ?? item['action'] ?? '').toString().toLowerCase();
    String uid = (item['uid'] ?? item['card_id'] ?? '').toString();
    
    bool isCardScan = methodRaw.contains("card") || uid.isNotEmpty;
    bool isOTP = methodRaw.contains("otp");
    bool isPassword = methodRaw.contains("password") || methodRaw.contains("pass");
    bool isButton = methodRaw.contains("button");
    bool isAppOpen = methodRaw.contains("app");

    String ownerName = "Hệ thống"; String methodDisplay = "Mở khóa"; Color avatarColor = Colors.grey; IconData icon = Icons.help_outline; bool isUnknownCard = false;

    if (isCardScan) {
      String knownName = _userMap[uid] ?? "";
      String gender = _genderMap[uid] ?? "";

      if (knownName.isNotEmpty) {
        ownerName = knownName; 
        methodDisplay = "Thẻ từ (UID: $uid)"; 
        
        // ĐỔI ICON VÀ MÀU THEO GIỚI TÍNH
        if (gender == 'Nam') {
          avatarColor = Colors.blueAccent;
          icon = Icons.face;
        } else if (gender == 'Nữ') {
          avatarColor = Colors.pinkAccent;
          icon = Icons.face_3;
        } else {
          avatarColor = Colors.greenAccent;
          icon = Icons.person;
        }

      } else {
        isUnknownCard = true; ownerName = "⚠️ CẢNH BÁO: THẺ LẠ"; methodDisplay = "Thẻ không hợp lệ (UID: $uid)"; avatarColor = Colors.redAccent; icon = Icons.warning_amber_rounded;
      }
    } else if (isOTP) { ownerName = "Khách (OTP)"; methodDisplay = "Mã dùng 1 lần"; avatarColor = Colors.orangeAccent; icon = Icons.vibration;
    } else if (isPassword) { ownerName = "Người trong nhà"; methodDisplay = "Mật mã thiết bị"; avatarColor = Colors.purpleAccent; icon = Icons.dialpad;
    } else if (isAppOpen) { ownerName = "Chủ nhà"; methodDisplay = "Mở qua App"; avatarColor = Colors.tealAccent; icon = Icons.phonelink_ring;
    } else if (isButton) { ownerName = "Người trong nhà"; methodDisplay = "Nút bấm cơ"; avatarColor = Colors.blueAccent; icon = Icons.touch_app;
    }

    return Dismissible(
      key: Key(logKey), direction: DismissDirection.endToStart,
      background: Container(decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => dbRef.child('logs').child(logKey).remove(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12), color: isUnknownCard ? const Color(0xFF331515) : const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: isUnknownCard ? const BorderSide(color: Colors.redAccent, width: 1) : BorderSide.none),
        child: ListTile(
          onTap: () => isUnknownCard ? _showUnknownWarning(uid) : (isCardScan ? _showMemberDetail(uid) : null),
          leading: CircleAvatar(backgroundColor: avatarColor.withOpacity(0.2), child: Icon(icon, color: avatarColor)),
          title: Text(ownerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isUnknownCard ? Colors.redAccent : Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(methodDisplay, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  Text(_formatTime(_getValidTimestamp(item)), style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '--:--:--  |  --/--/----';
    var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String h = date.hour.toString().padLeft(2, '0');
    String m = date.minute.toString().padLeft(2, '0');
    String s = date.second.toString().padLeft(2, '0');
    String d = date.day.toString().padLeft(2, '0');
    String mo = date.month.toString().padLeft(2, '0');
    String y = date.year.toString();
    return "$h:$m:$s  |  $d/$mo/$y";
  }

  void _showMemberDetail(String cardId) async {
    DataSnapshot memberSnap = await dbRef.child('members').child(cardId).get();
    if (memberSnap.exists) {
      Map data = memberSnap.value as Map; 
      _showDetailDialog(data['name'], data['phone'], data['yob'], data['gender'], cardId);
    }
  }

  void _showDetailDialog(String? name, String? phone, String? yob, String? gender, String cardId) {
    showDialog(
      context: context, builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(name ?? "Thông tin thẻ", style: const TextStyle(color: Colors.white)),
        content: Text("Giới tính: ${gender ?? '---'}\nNăm sinh: ${yob ?? '---'}\nSĐT: ${phone ?? '---'}\nUID: $cardId", style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))],
      ),
    );
  }

  void _showUnknownWarning(String cardId) {
    showDialog(
      context: context, builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C), title: const Text("CẢNH BÁO", style: TextStyle(color: Colors.redAccent)),
        content: Text("Thẻ lạ cố gắng truy cập!\nUID: $cardId", style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đã hiểu"))],
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFF161625),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.arrow_back_ios, size: 18), color: Colors.blueAccent),
          Text("Trang $_currentPage / $totalPages", style: const TextStyle(color: Colors.white)),
          IconButton(onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.arrow_forward_ios, size: 18), color: Colors.blueAccent),
        ],
      ),
    );
  }
}