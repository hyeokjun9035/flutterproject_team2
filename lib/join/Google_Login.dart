// 로그인 구현

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';

void main() async {
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

  Future<UserCredential?> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('오류!! $e');
      return null;
    }
  }

  Future<void> googleLogout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('구글 로그인'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await googleLogout();
                if (!mounted) return;
                setState(() {}); // ✅ UI 갱신
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그아웃 완료')),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: isLoggedIn
            ? Text('${user!.displayName ?? "사용자"}님 로그인 상태입니다.')
            : ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('구글로 로그인'),
          onPressed: () async {
            final userCredential = await googleLogin();
            if (!mounted) return;

            if (userCredential != null) {
              setState(() {}); // ✅ UI 갱신
              final user = FirebaseAuth.instance.currentUser;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user?.displayName ?? "사용자"}님 환영합니다!'),

                ),
              );

            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그인 취소 or 실패')),
              );
            }
          },
        ),
      ),
    );
  }
}
