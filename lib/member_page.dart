import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});
  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _showAdminList = false;

  void _startRegistration({bool isAdmin = false, String? adminSlot}) {
    _dbRef.child("system_command").set("scan_mode");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StreamBuilder(
        stream: _dbRef.child("last_id").onValue,
        builder: (context, snapshot) {
          String cardId = snapshot.data?.snapshot.value?.toString() ?? "None";
          if (cardId == "None" || cardId == "null") return _buildScanningEffect();
          return _buildInputForm(cardId, isAdmin, adminSlot);
        },
      ),
    );
  }

  Widget _buildScanningEffect() {
    return Container(
      height: 300, padding: const EdgeInsets.all(30),
      child: Column(children: [
        const Text("QUY TRÌNH ĐĂNG KÝ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const Spacer(),
        const Stack(alignment: Alignment.center, children: [
          SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 2)),
          Icon(Icons.contactless, size: 40, color: Colors.blue),
        ]),
        const SizedBox(height: 20),
        const Text("Vui lòng quẹt thẻ vào đầu đọc RFID để thêm thẻ", textAlign: TextAlign.center),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("HỦY BỎ", style: TextStyle(color: Colors.red))),
      ]),
    );
  }

  Widget _buildInputForm(String cardId, bool isAdmin, String? adminSlot) {
    final nameController = TextEditingController();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isAdmin ? "ĐĂNG KÝ ADMIN MỚI" : "THÊM THÀNH VIÊN", style: const TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: nameController, decoration: const InputDecoration(labelText: "Họ và tên")),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              if (isAdmin && adminSlot != null) {
                _dbRef.child("admin_cards").child(adminSlot).set({
                  "uid": cardId, "name": nameController.text, "timestamp": ServerValue.timestamp,
                });
              } else {
                _dbRef.child("members").child(cardId).set({
                  "name": nameController.text, "timestamp": ServerValue.timestamp,
                });
              }
              _dbRef.child("last_id").set("None");
              Navigator.pop(context);
            }
          },
          child: const Text("XÁC NHẬN"),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showAdminList ? "Quản lý 2 Thẻ Admin" : "Danh sách Thành viên"),
        centerTitle: true,
        leading: _showAdminList ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _showAdminList = false)) : null,
      ),
      body: _showAdminList ? _buildAdminSection() : _buildMemberSection(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: !_showAdminList ? BottomAppBar(
        child: TextButton.icon(
          onPressed: () => setState(() => _showAdminList = true),
          icon: const Icon(Icons.security, color: Colors.orange),
          label: const Text("QUẢN LÝ ADMIN", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ),
      ) : null,
    );
  }

  // Logic hiển thị nút thêm thẻ thông minh
  Widget _buildFab() {
    return StreamBuilder(
      stream: _dbRef.child("admin_cards").onValue,
      builder: (context, snapshot) {
        Map? admins = snapshot.data?.snapshot.value as Map?;
        int adminCount = admins?.length ?? 0;

        if (_showAdminList) {
          // Nếu đã đủ 2 thẻ admin, không cho hiện nút thêm nữa
          if (adminCount >= 2) return const SizedBox.shrink(); 
          return FloatingActionButton.extended(
            onPressed: () {
              // Tìm slot trống để thêm (admin1 hoặc admin2)
              String slot = (admins?.containsKey('admin1') ?? false) ? 'admin2' : 'admin1';
              _startRegistration(isAdmin: true, adminSlot: slot);
            },
            label: const Text("THÊM ADMIN"),
            icon: const Icon(Icons.add_moderator),
            backgroundColor: Colors.orange,
          );
        } else {
          return FloatingActionButton.extended(
            onPressed: () => _startRegistration(isAdmin: false),
            label: const Text("THÊM THÀNH VIÊN"),
            icon: const Icon(Icons.person_add),
          );
        }
      },
    );
  }

  Widget _buildMemberSection() {
    return StreamBuilder(
      stream: _dbRef.child("members").onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("Chưa có thành viên nào."));
        Map members = snapshot.data!.snapshot.value as Map;
        return ListView(
          padding: const EdgeInsets.all(10),
          children: members.entries.map((e) => Dismissible(
            key: Key(e.key),
            direction: DismissDirection.startToEnd,
            background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (direction) => _dbRef.child("members").child(e.key).remove(),
            child: Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(e.value['name']), subtitle: Text("ID: ${e.key}"))),
          )).toList(),
        );
      },
    );
  }

  Widget _buildAdminSection() {
    return StreamBuilder(
      stream: _dbRef.child("admin_cards").onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("Chưa có Admin. Nhấn nút dưới để thêm."));
        }
        Map admins = snapshot.data!.snapshot.value as Map;
        return ListView(
          padding: const EdgeInsets.all(10),
          children: admins.entries.map((e) => Dismissible(
            key: Key(e.key),
            direction: DismissDirection.startToEnd, // Vuốt sang phải để xóa thẻ Admin bị mất
            background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.delete_forever, color: Colors.white)),
            onDismissed: (direction) => _dbRef.child("admin_cards").child(e.key).remove(),
            child: Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.orange),
                title: Text(e.value['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("UID: ${e.value['uid']}"),
                trailing: const Icon(Icons.swipe_right, size: 15, color: Colors.grey),
              ),
            ),
          )).toList(),
        );
      },
    );
  }
}