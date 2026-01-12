import 'dart:math';
import 'dart:io'; // File 사용을 위해 필요
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_step3.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase 초기화 설정
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

class JoinPage2 extends StatefulWidget {
  final String email;

  const JoinPage2({
    super.key,
    required this.email,
  });

  @override
  State<JoinPage2> createState() => _JoinPage2State();
}

class _JoinPage2State extends State<JoinPage2>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _nickName = TextEditingController();
  final TextEditingController _intro = TextEditingController(text: "hi!");

  File? _profile_image_file;
  String defaultImageUrl =
      "https://example.com/default_avatar.png"; // 기본 아바타 URL (로직 그대로)

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if(picked !=null){
      setState(() {
        _profile_image_file = File(picked.path);
      });
    }
  }

  Future<String> uploadToStorage(File file) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child("profile_images/${DateTime.now().millisecondsSinceEpoch}.png");

    await ref.putFile(file); //실제업로드
    return await ref.getDownloadURL(); //다운로드 URL반환
  }

  void _showmessage(String msg){
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg))
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
                const SizedBox(height: 30),
                const Text(
                  "프로필 설정",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "닉네임과 프로필을 입력해주세요.",
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
                      // 프로필 이미지 + 카메라 아이콘(디자인만)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFFEFF3F8),
                              backgroundImage: _profile_image_file != null
                                  ? FileImage(_profile_image_file!)
                                  : NetworkImage(defaultImageUrl) as ImageProvider,
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F80ED),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _name,
                        decoration: _inputDeco(
                          label: "이름",
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _nickName,
                        decoration: _inputDeco(
                          label: "닉네임",
                          hint: "중복 불가",
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _intro,
                        maxLines: 2,
                        decoration: _inputDeco(
                          label: "자기소개",
                          hint: "예) 오늘 날씨 너무 좋네요!",
                          icon: Icons.chat_bubble_outline,
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // ✅ 여기부터 아래 로직은 네 원본 그대로 (변경 없음)
                            if(_name.text.trim().isEmpty){
                              _showmessage("이름을 입력해주세요");
                              return;
                            }
                            if(_nickName.text.trim().isEmpty){
                              _showmessage("닉네임을 입력해주세요");
                              return;
                            }

                            final nickKey = _nickName.text.trim().toLowerCase();

                            final nickDoc = await fs
                                .collection('usernames')
                                .doc(nickKey)
                                .get();

                            if (nickDoc.exists) {
                              _showmessage("중복된 닉네임 입니다.");
                              return;
                            }

                            String imageUrl;
                            if(_profile_image_file != null){
                              imageUrl = await uploadToStorage(_profile_image_file!);
                            }else{
                              imageUrl = defaultImageUrl;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JoinPage3(
                                  email: widget.email,
                                  name: _name.text,
                                  profile_image_url: imageUrl,
                                  nickName: _nickName.text,
                                  intro: _intro.text,
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
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const Text(
                  "사진은 나중에 설정해도 괜찮아요 ☁️",
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
