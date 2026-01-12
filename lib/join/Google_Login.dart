// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/home/home_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore 패키지 임포트
import '../firebase_options.dart';
import 'login.dart'; // LoginPage가 정의된 파일을 임포트해야 합니다.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화
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
      title: 'Google & Firestore 연동 예제',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const GoogleLogin(),
    );
  }
}

class GoogleLogin extends StatefulWidget {
  const GoogleLogin({super.key});

  @override
  State<GoogleLogin> createState() => _GoogleLoginState();
}

class _GoogleLoginState extends State<GoogleLogin> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance; // ✅ Firestore 인스턴스

  // ✅ Firestore에 사용자 정보를 저장하거나 업데이트하는 함수
  Future<void> _saveUserToFirestore(User user) async {
    final DocumentReference userRef = _db.collection('users').doc(user.uid);
    final DocumentSnapshot doc = await userRef.get();

    // Google 인증에서 얻는 기본 정보
    final String? email = user.email;
    final String? displayName = user.displayName;
    final String? photoURL = user.photoURL;

    if (!doc.exists) {
      // 문서가 존재하지 않을 때 (최초 로그인)
      await userRef.set({
        // 1. Google 인증 정보 기반 필드
        'uid': user.uid,
        'email': email,
        'profile_image_url': photoURL, // Google 프로필 URL

        // 2. ✅ 제공해주신 추가 필드들 (초기값 설정)
        // 이름과 별명은 Google DisplayName을 기본으로, 혹은 이메일에서 추출하여 설정
        'name': displayName ?? '',
        'nickName': displayName ?? email?.split('@').first ?? 'User',
        'gender': '', // 초기값 빈 문자열 또는 'unknown'
        'intro': 'hi!',

        // 권한 및 상태 관련 필드 (초기값: true 또는 null)
        'isAlramChecked': true,
        'isCameraChecked': true,
        'isLocationChecked': true,
        'writeBlockedUntil': null, // 차단 기간은 초기에는 null 또는 0

        // 3. 시간 관련 필드 (Firebase 서버 시간 사용)
        'createdAt': FieldValue.serverTimestamp(), // 생성 시점
        'lastLogin': FieldValue.serverTimestamp(), // 최종 로그인
      });
      // debugPrint('Firestore: 새 사용자 (${user.email}) 정보 저장 완료');
    } else {
      // 문서가 존재할 때 (재로그인)
      // 기존 필드는 유지하고 최종 로그인 시간만 업데이트
      await userRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      debugPrint('Firestore: 사용자 (${user.email}) 최종 로그인 시간 업데이트');
    }
  }

  // ✅ Google 로그인 함수 (Firestore 저장 로직 추가됨)
  Future<UserCredential?> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // 로그인 취소

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 🔴 인증 성공 후 Firestore 저장/업데이트 함수 호출
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      // debugPrint('구글 로그인 중 오류 발생: $e');
      return null;
    }
  }

  // Google 로그아웃 함수
  Future<void> googleLogout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }


  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth.instance.currentUser를 사용하여 로그인 상태 확인
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('구글 로그인/회원가입'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await googleLogout();
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그아웃 완료')),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: isLoggedIn
            ?
        // 로그인 상태
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${user!.displayName ?? "사용자"}님 로그인 상태입니다.'),
            // Text('UID: ${user.uid}'), 사용자 uid가 보임
            const SizedBox(height: 20,),
            ElevatedButton(
              child: const Text('메인화면으로'),
              onPressed: (){
                if(user != null){
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=> const HomePage()));
                }else{
                  _showMessage("사용자가 없습니다. 다시 시도해주세요.");
                }
                }

            )
          ],
        )

            : // 로그아웃 상태
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('구글로 로그인/회원가입'),
          onPressed: () async {
            final userCredential = await googleLogin();
            if (!mounted) return;

            if (userCredential != null) {
              setState(() {}); // UI 갱신 (로그인 상태 반영)
              final user = FirebaseAuth.instance.currentUser;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user?.displayName ?? "사용자"}님 환영합니다!'),
                  // action: SnackBarAction(
                  //     label: '페이지 이동',
                  //     onPressed: (){
                  //       Navigator.push(
                  //           context,
                  //           MaterialPageRoute(builder: (_)=> const HomePage())
                  //       );
                  //     }),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그인 취소 또는 실패')),
              );
            }
          },
        ),
      ),
    );
  }
}