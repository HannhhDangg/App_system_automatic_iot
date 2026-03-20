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
  String _adminPassword = "---";
  String _doorPassword = "---";
  
  bool _revealAdminPass = false;
  bool _revealDoorPass = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _yobController = TextEditingController(); 
  final TextEditingController _phoneController = TextEditingController(); 
  
  // Biến lưu giới tính
  String _selectedGender = 'Nam';
  final List<String> _genders = ['Nam', 'Nữ', 'Khác'];

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPasswords() async {
    final adminSnap = await _dbRef.child('config/admin_password').get();
    final doorSnap = await _dbRef.child('config/door_password').get();
    setState(() {
      if (adminSnap.exists) _adminPassword = adminSnap.value.toString();
      if (doorSnap.exists) _doorPassword = doorSnap.value.toString();
    });
  }

  Future<bool> _promptAdminPasswordOnly() async {
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
            boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.orangeAccent, size: 55),
              const SizedBox(height: 15),
              const Text("XÁC THỰC QUẢN TRỊ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text("Vui lòng nhập mật khẩu Admin để thao tác", style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
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
                        if (controller.text == _adminPassword) { isCorrect = true; Navigator.pop(context); } 
                        else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sai mật khẩu Admin!'), backgroundColor: Colors.redAccent)); }
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

  void _tempReveal(String type) async {
    if (type == "admin" && _revealAdminPass) { setState(() => _revealAdminPass = false); return; }
    if (type == "door" && _revealDoorPass) { setState(() => _revealDoorPass = false); return; }

    if (await _promptAdminPasswordOnly()) {
      setState(() { if (type == "admin") _revealAdminPass = true; else _revealDoorPass = true; });
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() { if (type == "admin") _revealAdminPass = false; if (type == "door") _revealDoorPass = false; });
      });
    }
  }

  Future<void> _changeAdminPassword() async {
    if (await _promptAdminPasswordOnly()) {
      await _showNewPassDialog("Thiết lập mật khẩu Admin MỚI", Icons.admin_panel_settings, Colors.orangeAccent, (val) {
        _dbRef.child('config/admin_password').set(val); setState(() => _adminPassword = val);
      });
    }
  }

  Future<void> _changeDoorPassword() async {
    if (await _promptAdminPasswordOnly()) {
      await _showNewPassDialog("Thiết lập mật khẩu Cửa MỚI", Icons.door_front_door, Colors.blueAccent, (val) {
        _dbRef.child('config/door_password').set(val); setState(() => _doorPassword = val);
      });
    }
  }

  Future<void> _showNewPassDialog(String title, IconData icon, Color color, Function(String) onSave) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)))]),
        content: TextField(
          controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
          decoration: InputDecoration(
            labelText: 'Mã số mới (ít nhất 4 số)', labelStyle: const TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 0),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color.withOpacity(0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              if (ctrl.text.trim().length >= 4) { onSave(ctrl.text.trim()); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật mật khẩu thành công!'), backgroundColor: Colors.green)); } 
              else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu phải có ít nhất 4 số!'), backgroundColor: Colors.redAccent)); }
            }, 
            child: const Text('LƯU LẠI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Future<void> _editUserDialog(String cardId, Map data, bool isAdmin, String? adminSlot) async {
    if (!await _promptAdminPasswordOnly()) return;

    _nameController.text = data['name'] ?? '';
    _yobController.text = data['yob'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _selectedGender = data['gender'] ?? 'Nam'; // Đọc giới tính từ Firebase

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161625),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 25, right: 25, top: 30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("SỬA THÔNG TIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 18)),
              const SizedBox(height: 10), Text("UID: $cardId", style: const TextStyle(color: Colors.white54, fontSize: 14)), const SizedBox(height: 20),
              
              _buildTextField(_nameController, "Họ và tên", Icons.person), const SizedBox(height: 15),
              
              // Menu chọn Giới tính
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: const Color(0xFF1E1E2C),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Giới tính", labelStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.wc, color: Colors.blueAccent),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: const Color(0xFF1E1E2C),
                ),
                items: _genders.map((String g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) { if (val != null) setModalState(() => _selectedGender = val); },
              ),
              const SizedBox(height: 15),
              
              _buildTextField(_yobController, "Năm sinh", Icons.calendar_today, isNumber: true), const SizedBox(height: 15),
              _buildTextField(_phoneController, "Số điện thoại", Icons.phone, isNumber: true), const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isAdmin ? Colors.orangeAccent : Colors.blueAccent),
                  onPressed: () {
                    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
                      Map<String, dynamic> updateData = {
                        "uid": cardId, "name": _nameController.text, "yob": _yobController.text, 
                        "phone": _phoneController.text, "gender": _selectedGender, // LƯU GIỚI TÍNH
                        "timestamp": data['timestamp'] ?? ServerValue.timestamp,
                      };
                      if (isAdmin && adminSlot != null) _dbRef.child("admin_cards").child(adminSlot).update(updateData);
                      else _dbRef.child("members").child(cardId).update(updateData);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin!'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text("CẬP NHẬT TRỞ LẠI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          );
        }
      ),
    );
  }

  Future<void> _removeCard(String id, bool isAdmin, String? adminSlot) async {
    if (!await _promptAdminPasswordOnly()) return;
    if (isAdmin && adminSlot != null) await _dbRef.child('admin_cards').child(adminSlot).remove();
    else await _dbRef.child('members').child(id).remove();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa thẻ thành công!'), backgroundColor: Colors.green));
  }

  void _startRegistration({bool isAdmin = false, String? adminSlot}) {
    _nameController.clear(); _yobController.clear(); _phoneController.clear(); _selectedGender = 'Nam';
    _dbRef.child("system_command").set("scan_mode");
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161625),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StreamBuilder(
        stream: _dbRef.child("last_id").onValue,
        builder: (context, snapshot) {
          String cardId = snapshot.data?.snapshot.value?.toString() ?? "None";
          if (cardId == "None" || cardId == "null") return _buildScanningEffect();
          return _buildInputForm(cardId, isAdmin, adminSlot);
        },
      ),
    ).whenComplete(() { _dbRef.child("last_id").set("None"); _dbRef.child("system_command").set("idle"); });
  }

  Widget _buildScanningEffect() {
    return Container(
      height: 350, padding: const EdgeInsets.all(30),
      child: const Column(children: [
        Text("ĐANG CHỜ THẺ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blueAccent, letterSpacing: 2)), Spacer(),
        Stack(alignment: Alignment.center, children: [ SizedBox(width: 100, height: 100, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent)), Icon(Icons.contactless, size: 50, color: Colors.blueAccent) ]),
        SizedBox(height: 30), Text("Vui lòng quẹt thẻ vào đầu đọc RFID...", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)), Spacer(),
      ]),
    );
  }

  Widget _buildInputForm(String cardId, bool isAdmin, String? adminSlot) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 25, right: 25, top: 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Đã nhận thẻ: $cardId", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)), const SizedBox(height: 20),
            Text(isAdmin ? "THÊM ADMIN MỚI" : "THÊM THÀNH VIÊN", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)), const SizedBox(height: 20),
            
            _buildTextField(_nameController, "Họ và tên", Icons.person), const SizedBox(height: 15),
            
            DropdownButtonFormField<String>(
              value: _selectedGender, dropdownColor: const Color(0xFF1E1E2C), style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: "Giới tính", labelStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.wc, color: Colors.blueAccent),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: const Color(0xFF1E1E2C),
              ),
              items: _genders.map((String g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) { if (val != null) setModalState(() => _selectedGender = val); },
            ),
            const SizedBox(height: 15),

            _buildTextField(_yobController, "Năm sinh", Icons.calendar_today, isNumber: true), const SizedBox(height: 15),
            _buildTextField(_phoneController, "Số điện thoại", Icons.phone, isNumber: true), const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
                    Map<String, dynamic> data = {
                      "uid": cardId, "name": _nameController.text, "yob": _yobController.text, "gender": _selectedGender, 
                      "phone": _phoneController.text, "timestamp": ServerValue.timestamp,
                    };
                    if (isAdmin && adminSlot != null) _dbRef.child("admin_cards").child(adminSlot).set(data);
                    else _dbRef.child("members").child(cardId).set(data);
                    Navigator.pop(context);
                  } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ Họ tên và SĐT!'), backgroundColor: Colors.redAccent)); }
                },
                child: const Text("XÁC NHẬN LƯU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        );
      }
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller, style: const TextStyle(color: Colors.white), keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white54), prefixIcon: Icon(icon, color: Colors.blueAccent),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(10)),
        filled: true, fillColor: const Color(0xFF1E1E2C)
      )
    );
  }

  // --- HÀM LẤY ICON & MÀU THEO GIỚI TÍNH ---
  IconData _getAvatarIcon(String? gender) {
    if (gender == 'Nữ') return Icons.face_3; // Icon nữ
    if (gender == 'Nam') return Icons.face; // Icon nam
    return Icons.person; // Khác
  }
  Color _getAvatarColor(String? gender) {
    if (gender == 'Nữ') return Colors.pinkAccent;
    if (gender == 'Nam') return Colors.blueAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(_showAdminList ? "QUẢN TRỊ HỆ THỐNG" : "DANH SÁCH THÀNH VIÊN", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900)),
        centerTitle: true, backgroundColor: const Color(0xFF161625), elevation: 0,
        leading: _showAdminList ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _showAdminList = false)) : null,
      ),
      body: _showAdminList ? _buildAdminSection() : _buildMemberSection(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: !_showAdminList ? BottomAppBar(
        color: const Color(0xFF161625),
        child: TextButton.icon(
          onPressed: () => _promptAdminPasswordOnly().then((valid) { if (valid) setState(() => _showAdminList = true); }),
          icon: const Icon(Icons.security, color: Colors.orangeAccent),
          label: const Text("VÀO VÙNG QUẢN TRỊ", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        ),
      ) : null,
    );
  }

  Widget _buildFab() {
    return StreamBuilder(
      stream: _dbRef.child("admin_cards").onValue,
      builder: (context, snapshot) {
        Map? admins = snapshot.data?.snapshot.value as Map?;
        int adminCount = admins?.length ?? 0;
        if (_showAdminList) {
          if (adminCount >= 2) return const SizedBox.shrink(); 
          return FloatingActionButton.extended(
            onPressed: () {
              String slot = (admins?.containsKey('admin1') ?? false) ? 'admin2' : 'admin1';
              _startRegistration(isAdmin: true, adminSlot: slot);
            },
            label: const Text("THÊM ADMIN"), icon: const Icon(Icons.add_moderator), backgroundColor: Colors.orangeAccent,
          );
        } else {
          return FloatingActionButton.extended(
            onPressed: () => _startRegistration(isAdmin: false),
            label: const Text("THÊM THÀNH VIÊN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.person_add, color: Colors.white), backgroundColor: Colors.blueAccent,
          );
        }
      },
    );
  }

  Widget _buildMemberSection() {
    return StreamBuilder(
      stream: _dbRef.child("members").onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text("Chưa có thành viên nào.", style: TextStyle(color: Colors.white54)));
        Map members = snapshot.data!.snapshot.value as Map;
        return ListView(
          padding: const EdgeInsets.all(15),
          children: members.entries.map((e) => Dismissible(
            key: Key(e.key), direction: DismissDirection.endToStart,
            confirmDismiss: (_) async => await _promptAdminPasswordOnly(),
            onDismissed: (_) => _dbRef.child("members").child(e.key).remove(),
            background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            child: Card(
              color: const Color(0xFF1E1E2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getAvatarColor(e.value['gender']).withOpacity(0.2), 
                  child: Icon(_getAvatarIcon(e.value['gender']), color: _getAvatarColor(e.value['gender'])) // ICON & MÀU THEO GIỚI TÍNH
                ), 
                title: Text(e.value['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                subtitle: Text("Giới tính: ${e.value['gender'] ?? '---'}\nNăm sinh: ${e.value['yob'] ?? '---'}\nSĐT: ${e.value['phone'] ?? '---'}", style: const TextStyle(color: Colors.white54)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.greenAccent), onPressed: () => _editUserDialog(e.key, e.value, false, null)),
                ]),
              )
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildAdminSection() {
    return StreamBuilder(
      stream: _dbRef.child("admin_cards").onValue,
      builder: (context, snapshot) {
        Map? admins = snapshot.data?.snapshot.value as Map?;
        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            const Padding(padding: EdgeInsets.only(left: 5, bottom: 10), child: Row(children: [Icon(Icons.shield, color: Colors.orangeAccent, size: 20), SizedBox(width: 8), Text("CẤU HÌNH BẢO MẬT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))])),
            _buildSecurePasswordCard(title: "Mật khẩu Admin", subtitle: "Dùng để quản trị hệ thống", value: _adminPassword, isRevealed: _revealAdminPass, icon: Icons.admin_panel_settings, color: Colors.orangeAccent, onReveal: () => _tempReveal("admin"), onChange: _changeAdminPassword),
            _buildSecurePasswordCard(title: "Mật khẩu Mở cửa", subtitle: "Dùng để mở khóa trên bàn phím", value: _doorPassword, isRevealed: _revealDoorPass, icon: Icons.door_front_door, color: Colors.blueAccent, onReveal: () => _tempReveal("door"), onChange: _changeDoorPassword),
            const SizedBox(height: 15), const Divider(color: Colors.white10), const SizedBox(height: 15),
            const Padding(padding: EdgeInsets.only(left: 5, bottom: 10), child: Row(children: [Icon(Icons.credit_card, color: Colors.white70, size: 20), SizedBox(width: 8), Text("DANH SÁCH THẺ ADMIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))])),
            if (admins == null || admins.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Chưa có thẻ Admin vật lý nào.", style: TextStyle(color: Colors.white54))))
            else ...admins.entries.map((e) => Dismissible(
              key: Key(e.key), direction: DismissDirection.endToStart,
              confirmDismiss: (_) async => await _promptAdminPasswordOnly(),
              onDismissed: (_) => _dbRef.child("admin_cards").child(e.key).remove(),
              background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
              child: Card(
                color: const Color(0xFF2A2015), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.orangeAccent, width: 0.5)), margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAvatarColor(e.value['gender']).withOpacity(0.2), 
                    child: Icon(_getAvatarIcon(e.value['gender']), color: _getAvatarColor(e.value['gender'])) // ICON & MÀU THEO GIỚI TÍNH CHO ADMIN
                  ),
                  title: Text(e.value['name'] ?? '', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("UID: ${e.value['uid']}\nSĐT: ${e.value['phone']}", style: const TextStyle(color: Colors.white70)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.greenAccent), onPressed: () => _editUserDialog(e.value['uid'], e.value, true, e.key)),
                    IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: () => _removeCard(e.value['uid'], true, e.key)),
                  ]),
                ),
              ),
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSecurePasswordCard({required String title, required String subtitle, required String value, required bool isRevealed, required IconData icon, required Color color, required VoidCallback onReveal, required VoidCallback onChange}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Padding(padding: const EdgeInsets.all(15.0), child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: Text(isRevealed ? value : "• • • • • •", style: TextStyle(color: isRevealed ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.bold, letterSpacing: isRevealed ? 3 : 5, fontSize: 16))),
        ])),
        Column(children: [
          IconButton(icon: Icon(isRevealed ? Icons.visibility_off : Icons.visibility, color: isRevealed ? Colors.greenAccent : Colors.white54), onPressed: onReveal),
          IconButton(icon: Icon(Icons.edit_note, color: color), onPressed: onChange),
        ])
      ])),
    );
  }
}