import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunitySettings extends StatefulWidget {
  final Map<String, dynamic> user;
  const CommunitySettings({super.key, required this.user});

  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}
//아직 설정 미정
class _CommunitySettingsState extends State<CommunitySettings> {
  bool _isPushEnabled = false;
  bool _isPrivateMode = false; // 추가 예시 설정
  @override
  void initState() {
    super.initState();

    _isPushEnabled = widget.user['isAlramChecked'] ?? false;
  }

  void _updateAlarmSetting(bool newValue) async {
    setState(() {
      _isPushEnabled = newValue;
    });

    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isAlramChecked': newValue, // 서버의 컬럼명과 정확히 일치해야 함
        });
        print("Firestore 업데이트 성공: $newValue");
      } else {
        print("로그인된 사용자가 없습니다.");
      }
    } catch (e) {
      // 4. 실패 시 스위치 상태를 원래대로 돌리고 에러 알림
      setState(() {
        _isPushEnabled = !newValue;
      });
      print("업데이트 에러: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("설정 저장에 실패했습니다.")),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            "커뮤니티 설정",
            style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "알림 및 보안",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),


            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [

                  _buildSettingItem(
                    icon: Icons.notifications_active_outlined,
                    iconColor: Colors.blueAccent,
                    title: "푸시 알림",
                    subtitle: "새로운 댓글이나 소식을 알려드립니다.",
                    trailing: Switch(
                      value: _isPushEnabled, // 연결: isAlramChecked
                      activeColor: Colors.white,
                      activeTrackColor: Colors.blueGrey[400],
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey[300],
                      onChanged: (bool value) {
                        // 4. 스위치 클릭 시 DB 업데이트 호출
                        _updateAlarmSetting(value);
                      },
                    ),
                  ),

                  const Divider(height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F1F1)),


                  _buildSettingItem(
                    icon: Icons.lock_outline_rounded,
                    iconColor: Colors.orangeAccent,
                    title: "내 활동 비공개",
                    subtitle: "작성한 글을 다른 사람이 볼 수 없게 합니다.",
                    trailing: Switch(
                      value: _isPrivateMode,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.blueGrey[400],
                      onChanged: (bool value) {
                        setState(() {
                          _isPrivateMode = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              "기타",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),


            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text("커뮤니티 이용 가이드", style: TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PreparingPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}


class PreparingPage extends StatelessWidget {
  const PreparingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 80, color: Colors.blueGrey[200]),
            const SizedBox(height: 20),
            const Text(
              "페이지 준비 중",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              "더 나은 서비스를 위해\n열심히 준비하고 있습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}