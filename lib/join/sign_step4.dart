import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_complete.dart';


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
class JoinPage4 extends StatefulWidget {
  //authcation 과 동일한 uid 사용을 위해서 끌어옴
  final String email;
  final String password;
  final String intro;
  final String name;
  final String profile_image_url;
  final String nickName;
  final String gender;

  const JoinPage4({
    super.key,
    required this.email,
    required this.password,
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
  final FirebaseFirestore fs = FirebaseFirestore.instance;
 bool isLocationChecked = false;
 bool isCameraChecked = false;
 bool isAlramChecked = false;


  Future<bool> _join() async {
    final nickNameText = widget.nickName.trim();

    // 닉네임이 비어있으면 안되지만, 이전에 검사되었다고 가정하고 중복 체크만 수행-------------이거 'user'라고 써져있게 해놓기
    // 3. 🔑 Firestore에서 이메일 중복 검사
    try {
      final QuerySnapshot result = await fs.collection('users')
          .where('nickName', isEqualTo: nickNameText) // emailText 사용
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        _showMessage('이미 사용중인 닉네임 입니다.');
        return false; // 🛑 중복 시 즉시 종료
      }
    } catch (e) {
      // Firestore 접근 중 오류 발생
      _showMessage('닉네임 중복 확인 중 오류발생: ${e.toString()}');
      return false; // 🛑 오류 시 즉시 종료
    }

    // 4. 모든 검사 통과
    return true;
  }



void _showMessage(String msg) {
  if (!mounted) return;
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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 270,0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
            //이미지 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(10,0,350,180),
              child:Image.asset("assets/joinIcon/cloud.png", width: 50,),
            ),
            Padding(
                padding:const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 20),
              child: Text("기타 및 관련 서비스에 동의해주세요"),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), ),
                Icon(Icons.location_on, size: 50,),
                Icon(Icons.camera_alt, size: 50,),
                Icon(Icons.edit_notifications, size: 50,),
              ]
            ),

            CheckboxListTile(
              title: const Text("위치기반 서비스에 동의합니다 (필수)"),
              value: isLocationChecked,
              onChanged: (value) {
                setState(() {
                  isLocationChecked = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text("카메라 서비스에 동의합니다 (필수)"),
              value: isCameraChecked,
              onChanged: (value) {
                setState(() {
                  isCameraChecked = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text("알림 및 기타 서비스에 동의합니다 (선택)"),
              value: isAlramChecked,
              onChanged: (value) {
                setState(() {
                  isAlramChecked = value!;
                });
              },
            ),

            ElevatedButton(
                onPressed: () async {
                  if (isLocationChecked == false || isCameraChecked == false) {
                    _showMessage("필수사항은 반드시 체크하셔야 합니다.");
                    return;
                  }

                  try {
                    bool success = await _join();

                    if (!success) {
                      return;
                    }
                    if(!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinPage5(
                          email: widget.email,
                          password: widget.password,
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
                  } catch (e) {
                    _showMessage("회원가입 처리 중 오류가 발생했습니다: $e");
                  }
                },
                child: Text("다음")
            )
          ],

        ),
      ),
    );
  }
}


/////


