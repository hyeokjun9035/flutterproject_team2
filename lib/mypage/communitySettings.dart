import 'package:flutter/material.dart';

class CommunitySettings extends StatefulWidget {
  const CommunitySettings({super.key});

  @override
  State<CommunitySettings> createState() => _CommunitySettingsState();
}
//아직 설정 미정
class _CommunitySettingsState extends State<CommunitySettings> {
  bool _isPushEnabled = true; // 푸시 알림 상태 변수
  bool _isPrivateMode = false; // 추가 예시 설정

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
                      value: _isPushEnabled,
                      // 요청하신 회색 계열 적용
                      activeColor: Colors.white,
                      activeTrackColor: Colors.blueGrey[400],
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey[300],
                      onChanged: (bool value) {
                        setState(() {
                          _isPushEnabled = value;
                        });
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
                  // 가이드 페이지 이동 로직
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