import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter/material.dart';

void main() {
  //flutter 엔진과 바인딩을 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // YOUR_NATIVE_APP_KEY 대신 복사한 실제 네이티브 앱 키를 넣으세요.
  KakaoSdk.init(nativeAppKey: '');

  runApp(const MaterialApp(home:kakaoLogin()));

}




class kakaoLogin extends StatefulWidget {
  const kakaoLogin({super.key});

  @override
  State<kakaoLogin> createState() => _kakaoLoginState();
}

class _kakaoLoginState extends State<kakaoLogin> {

  //카카오 로그인 실행 함수
  Future<void> _signInWithKakao() async {
    try{
      final bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled){
        //카카오톡으로 르그인 시도(설치되어 있는 경우)
        token = await UserApi.instance.loginWithKakaoTalk();
        print('카카오톡 로그인 성공! 토근: ${token.accessToken}');
      }else {
        //카카오 계정(웹브라우저)로 로그인 시도
        token = await UserApi.instance.loginWithKakaoAccount();
        print('카카오 계정으로 로그인 성공! 토근ㅣ ${token.accessToken}');
      }
      //사용자 정보 가져오기
      final user= await UserApi.instance.me();
      print('사용자 로그인 정보: ${user.kakaoAccount?.profile?.nickname}');

    } catch (error) {
      //로그인 실패 시 에러 처리
      print('카카오 로그인 실패: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오 로그인')),
      body: Center(
        child: ElevatedButton(
            onPressed: _signInWithKakao,
            child: const Text('카카오 로그인')),
      ),
    );
  }
}





