import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_complete.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
    );
  }
}

class JoinPage4 extends StatefulWidget {
  final String email;
  final String intro;
  final String name;
  final String profile_image_url;
  final String nickName;
  final String gender;

  const JoinPage4({
    super.key,
    required this.email,
    required this.intro,
    required this.name,
    required this.profile_image_url,
    required this.nickName,
    required this.gender,
  });

  @override
  State<JoinPage4> createState() => _JoinPage4State();
}


class _JoinPage4State extends State<JoinPage4>{
  final FirebaseFirestore fs = FirebaseFirestore.instance; // 로직 유지
  bool isLocationChecked = false;
  bool isCameraChecked = false;
  bool isAlramChecked = false;


  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }



  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFFB2EBF2),
      appBar: AppBar(
        backgroundColor: Color(0xFF2F80ED),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2F80ED),
              Color(0xFF56CCF2),
              Color(0xFFB2EBF2),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                const Text(
                  "약관 동의",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "서비스 이용을 위해 동의가 필요해요.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 18),

                // 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 25,
                        offset: Offset(0, 15),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 상단 장식(기존 이미지 유지)

                      const SizedBox(height: 20),

                      // 아이콘 줄 (디자인만)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _CircleIcon(icon: Icons.location_on),
                          SizedBox(width: 12),
                          _CircleIcon(icon: Icons.camera_alt),
                          SizedBox(width: 12),
                          _CircleIcon(icon: Icons.edit_notifications),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ✅ 체크박스 로직 그대로 (UI만 카드 스타일)
                      CheckboxListTile(
                        title: const Text("위치기반 서비스에 동의합니다 (필수)"),
                        value: isLocationChecked,
                        activeColor: const Color(0xFF2F80ED),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            isLocationChecked = value!;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("카메라 서비스에 동의합니다 (필수)"),
                        value: isCameraChecked,
                        activeColor: const Color(0xFF2F80ED),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            isCameraChecked = value!;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("알림 및 기타 서비스에 동의합니다 (선택)"),
                        value: isAlramChecked,
                        activeColor: const Color(0xFF2F80ED),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            isAlramChecked = value!;
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      // 다음 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // ✅ 로직 그대로
                            if (!isLocationChecked || !isCameraChecked) {
                              _showMessage("필수사항은 반드시 체크하셔야 합니다.");
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JoinPage5(
                                  email: widget.email,
                                  intro: widget.intro,
                                  name: widget.name,
                                  nickName: widget.nickName,
                                  profile_image_url: widget.profile_image_url,
                                  gender: widget.gender,
                                  isLocationChecked: isLocationChecked,
                                  isCameraChecked: isCameraChecked,
                                  isAlramChecked: isAlramChecked,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "다음",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "필수 항목은 체크해야 다음으로 진행할 수 있어요.",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "날씨 맞춤 추천을 위해 권한이 필요할 수 있어요 ☁️",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  const _CircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Icon(
        icon,
        size: 30,
        color: const Color(0xFF2F80ED),
      ),
    );
  }
}


