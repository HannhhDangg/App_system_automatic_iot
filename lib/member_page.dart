import 'package:flutter/material.dart';

class MemberPage extends StatelessWidget {
  const MemberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thành viên")),
      body: const Center(child: Text("Danh sách các thẻ đã đăng ký")),
    );
  }
}