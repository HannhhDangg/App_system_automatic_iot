import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Kết nối tới nhánh 'logs' trên Firebase của bạn
    final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('logs');

    return Scaffold(
      appBar: AppBar(title: const Text("Lịch sử ra vào")),
      body: StreamBuilder(
        stream: _dbRef.onValue, // Lắng nghe dữ liệu thay đổi liên tục
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            
            // Chuyển Map thành List để hiển thị
            List<dynamic> logList = data.values.toList();

            return ListView.builder(
              itemCount: logList.length,
              itemBuilder: (context, index) {
                var item = logList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.access_time)),
                    title: Text("Thành viên: ${item['name'] ?? 'Chưa xác định'}"),
                    subtitle: Text("ID Thẻ: ${item['card_id'] ?? 'N/A'}"),
                    trailing: Text(item['timestamp'] ?? ''),
                  ),
                );
              },
            );
          }
          return const Center(child: Text("Chưa có lịch sử ra vào."));
        },
      ),
    );
  }
}