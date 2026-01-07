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
      "https://example.com/default_avatar.png"; // 기본 아바타 URL


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

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10,0,10,180),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 350, 0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
            //이미지 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(10,0,350,100),
              child:Image.asset("assets/joinIcon/cloud.png", width: 50,),
            ),

            Padding(
              padding: const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 50),
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _profile_image_file != null
                      ? FileImage(_profile_image_file!)
                      : NetworkImage(defaultImageUrl) as ImageProvider,
                ),
              ),
            ),

            TextField(
              controller: _name,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                labelText: "이름",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.onetwothree, size: 30,) ,
                labelText: "닉네임",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _intro,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_add_alt_rounded, size: 30,) ,
                labelText: "자기소개를 적어주세요!",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                //빈 값 조사
                if(_name.text.trim().isEmpty){
                  _showmessage("이름을 입력해주세요");
                  return;
                }
                if(_nickName.text.trim().isEmpty){
                  _showmessage("닉네임을 입력해주세요");
                  return;
                }

                //닉네임 체크
                final nickKey = _nickName.text.trim().toLowerCase();

                final nickDoc = await fs
                    .collection('usernames')
                    .doc(nickKey)
                    .get();

                if (nickDoc.exists) {
                  _showmessage("중복된 닉네임 입니다.");
                  return;
                }

                //닉네임 중복아닐때 아래코드 실행됨
                String imageUrl;
                if(_profile_image_file != null){
                  imageUrl = await uploadToStorage(_profile_image_file!);
                }else{
                  imageUrl = defaultImageUrl; //기본 아바타
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
              child: const Text("다음"),
            ),
          ],
        ),
      ),
    );
  }
}