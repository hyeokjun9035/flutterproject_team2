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
  final String uid;
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
    //authcation 과 동일한 uid 사용을 위해서 끌어옴
    required this.uid
  });

  @override
  State<JoinPage4> createState() => _JoinPage4State();
}
class _JoinPage4State extends State<JoinPage4>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
 bool isLocationChecked = false;
 bool isCameraChecked = false;
 bool isAlramChecked = false;


  Future<void> _join() async {
    final uid = widget.uid;

    final nickKey = widget.nickName.trim().toLowerCase();
    final userRef = fs.collection('users').doc(uid);
    final nickRef = fs.collection('usernames').doc(nickKey);

    await fs.runTransaction((tx) async {
      // 1) 닉네임 선점 확인(없으면 생성)
      final nickSnap = await tx.get(nickRef);
      if (nickSnap.exists) {
        // 이미 다른 uid가 쓰고 있으면 중복 처리
        final existingUid = (nickSnap.data()?['uid'] ?? '').toString();
        if (existingUid.isNotEmpty && existingUid != uid) {
          throw Exception('DUPLICATE_NICKNAME');
        }
        // existingUid == uid 면 이미 내가 선점한 상태 -> 그대로 진행
      } else {
        tx.set(nickRef, {
          'uid': uid,
          'nickName': widget.nickName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2) users/{uid} 생성/병합 저장
      tx.set(userRef, {
        'uid': uid,
        'email': widget.email,
        'name': widget.name,
        'nickName': widget.nickName,
        'intro': widget.intro,
        'gender': widget.gender,
        'profile_image_url': widget.profile_image_url,
        'isLocationChecked': isLocationChecked,
        'isCameraChecked': isCameraChecked,
        'isAlramChecked': isAlramChecked,

        // 🔥 이 두 줄이 핵심
        'writeBlockedUntil': null,
        'status': 'active',

        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
                    _showmessage("필수사항은 반드시 체크하셔야 합니다.");
                    return;
                  }

                  try {
                    await _join();

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinPage5(
                          uid: widget.uid,
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
                  } catch (e) {
                    if (e.toString().contains('DUPLICATE_NICKNAME')) {
                      _showmessage("중복된 닉네임 입니다.");
                    } else {
                      _showmessage("회원가입 저장 실패: $e");
                    }
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



