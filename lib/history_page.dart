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
  static const int _itemsPerPage = 10; // Đã thêm static để sửa lỗi biên dịch

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Lịch sử ra vào", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: dbRef.child('logs').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            
            // 1. Sắp xếp: Mới nhất lên trên đầu
            List<MapEntry<dynamic, dynamic>> allLogs = data.entries.toList()
  ..sort((a, b) => (b.value['timestamp'] ?? '').toString().compareTo((a.value['timestamp'] ?? '').toString()));

            // 2. Tính toán phân trang
            int totalItems = allLogs.length;
            int totalPages = (totalItems / _itemsPerPage).ceil();
            int startIndex = (_currentPage - 1) * _itemsPerPage;
            int endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
            
            List<MapEntry<dynamic, dynamic>> currentPageLogs = allLogs.sublist(startIndex, endIndex);

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: currentPageLogs.length,
                    itemBuilder: (context, index) {
                      var item = currentPageLogs[index].value;
                      return _buildLogCard(item);
                    },
                  ),
                ),
                // Thanh điều hướng trang
                if (totalPages > 1) _buildPaginationControls(totalPages),
              ],
            );
          }
          return const Center(child: Text("Chưa có lịch sử."));
        },
      ),
    );
  }

  Widget _buildLogCard(dynamic item) {
    String method = item['method'] ?? 'N/A';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(method),
          child: Icon(_getIcon(method), color: Colors.white),
        ),
        title: Text(_getTitle(item), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Phương thức: $method"),
        trailing: Text(item['timestamp'] ?? ''),
        onTap: () {
          // Chỉ hiện chi tiết nếu là Quẹt thẻ (RFID) để bảo mật OTP/Password
          if (method == "RFID" || method == "Admin Card") {
            _showMemberDetail(item['card_id']);
          }
        },
      ),
    );
  }

  String _getTitle(dynamic item) {
    String method = item['method'] ?? '';
    if (method == "OTP") return "Mã OTP";
    if (method == "Password") return "Mật khẩu thiết bị";
    if (method == "App (Xác thực)") return "Chủ nhà (App)";
    return item['name'] ?? "Khách lạ";
  }

  IconData _getIcon(String method) {
    if (method == "OTP") return Icons.vibration;
    if (method == "Password") return Icons.keyboard;
    if (method == "App (Xác thực)") return Icons.fingerprint;
    return Icons.credit_card;
  }

  Color _getAvatarColor(String method) {
    if (method == "OTP") return Colors.orange;
    if (method == "Password") return Colors.purple;
    if (method == "App (Xác thực)") return Colors.green;
    return Colors.blue;
  }

  void _showMemberDetail(String? cardId) async {
    if (cardId == null) return;
    DataSnapshot snapshot = await dbRef.child('members').child(cardId).get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(data['name'] ?? "Thông tin thẻ"),
          content: Text("SĐT: ${data['phone'] ?? 'N/A'}\nUID: $cardId"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))],
        ),
      );
    }
  }

  Widget _buildPaginationControls(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.arrow_back_ios),
          ),
          Text("Trang $_currentPage / $totalPages", style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }
}