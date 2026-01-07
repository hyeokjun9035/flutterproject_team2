import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_step4.dart';

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

class JoinPage3 extends StatefulWidget {
  final String email;
  final String name;
  final String intro;
  final String nickName;
  final String profile_image_url;

  const JoinPage3({
    super.key,
    required this.email,
    required this.name,
    required this.intro,
    required this.nickName,
    required this.profile_image_url,
  });

  @override
  State<JoinPage3> createState() => _JoinPage3State();
}

class _JoinPage3State extends State<JoinPage3>{
  final FirebaseFirestore fs = FirebaseFirestore.instance; // 로직 유지
  String _gender = "male";

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
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
                const SizedBox(height:50),
                const Text(
                  "추가 정보",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "성별을 선택해 주세요.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 100),

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

                      const SizedBox(height: 16),

                      // ✅ 성별 선택 박스 (로직 그대로, 디자인만 변경)
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: _inputDeco(
                          label: "성별",
                          icon: Icons.wc_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(value: "male", child: Text("남")),
                          DropdownMenuItem(value: "female", child: Text("녀")),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _gender = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // ✅ 네 로직 그대로 (변경 없음)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JoinPage4(
                                  email: widget.email,
                                  name: widget.name,
                                  intro: widget.intro,
                                  profile_image_url: widget.profile_image_url,
                                  nickName: widget.nickName,
                                  gender: _gender ?? "", // 원본 유지
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

                      const SizedBox(height: 8),
                      const Text(
                        "다음 단계에서 마지막 설정을 진행해요.",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const Text(
                  "날씨 맞춤 추천을 위해 기본 정보를 받아요 ☀️",
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
