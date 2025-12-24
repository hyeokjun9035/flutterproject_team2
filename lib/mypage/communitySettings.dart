import 'package:flutter/material.dart';

class CommunitySettings extends StatefulWidget {
  const CommunitySettings({super.key});

  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}

class _CommunitySettingsState extends State<CommunitySettings> {
  bool _isPushEnabled = true; // 푸시 알림 상태 변수

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("커뮤니티 설정", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "필요한 설정 추가 예정",
              style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // 푸시 알림 설정 영역
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("푸시 알림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _isPushEnabled,
                    activeColor: Colors.green,
                    onChanged: (bool value) {
                      setState(() {
                        _isPushEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}