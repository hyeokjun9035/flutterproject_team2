import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/community/Chatter.dart';
import 'package:flutter_project/community/Fashion.dart';
import 'package:flutter_project/community/Notice.dart';

import '../mypage/userEdit.dart';
import 'app_drawer.dart';

// 프로젝트 클래스들 import (경로는 네 프로젝트에 맞게 유지)
import 'package:flutter_project/join/login.dart';
import 'package:flutter_project/mypage/userMypage.dart';
import 'package:flutter_project/community/Community.dart';
import 'package:flutter_project/community/Communityadd.dart';
import 'package:flutter_project/mypage/locationSettings.dart';
import '../community/Event.dart';
import '../data/nearby_issues_service.dart';
import '../ui/nearby_issue_map_page.dart';

class AppDrawerFactory {
  /// ✅ 홈/대시보드에서: "내 주변 지도"에 posts 넘겨야 하는 버전
  static Widget buildWithNearbyMap({
    required BuildContext context,

    // 헤더 데이터
    required Stream<DocumentSnapshot<Map<String, dynamic>>> userStream,
    String? locationLabel,

    // ✅ 홈인지 여부(홈이면 Drawer에 '닫기', 아니면 '홈')
    required bool isHome,

    /// ✅ isHome=false(다른 페이지)일 때 홈으로 보내는 동작
    /// 홈 페이지에서는 사실상 호출 안됨(그래도 required라서 no-op 넣어도 됨)
    required VoidCallback onGoHome,

    // 지도에 필요
    required double myLat,
    required double myLng,
    required Future<List<NearbyIssuePost>> Function() getNearbyTopPosts,

    // 배경(원하면)
    Widget? background,
  }) {
    return AppDrawer(
      userStream: userStream,
      locationLabel: locationLabel,
      background: background,

      isHome: isHome,
      onGoHome: onGoHome,

      onGoNearbyMap: () async {
        final posts = await _safeGetPosts(getNearbyTopPosts);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NearbyIssuesMapPage(myLat: myLat, myLng: myLng, posts: posts),
          ),
        );
      },

      onGoReport: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Event()));
      },

      onGoCommunity: () {
        // ✅ 너 프로젝트에서 홈에서 쓰던 클래스명이 Community()였으니 그걸로
        Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPage()));
      },

      onGoNotice: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Notice()));
      },

      onGoFashion: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Fashion()));
      },

      onGoChatter: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Chatter()));
      },

      onGoIssueList: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Event()));
      },

      onGoWriteIssue: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => Communityadd()));
      },

      onGoMyPage: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserMypage()));
      },

      onGoSettings: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const UserEdit()));
      },

      onLogout: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
          );
        }
      },
    );
  }

  /// ✅ 다른 페이지(지도/커뮤니티 등)에서도 공통 메뉴만 쓰고 싶을 때
  /// - 내 주변 지도 메뉴가 필요 없으면 onGoNearbyMapOverride 안 넘기면 "눌러도 아무 동작 없음"으로 둠
  static Widget buildBasic({
    required BuildContext context,

    required Stream<DocumentSnapshot<Map<String, dynamic>>> userStream,
    String? locationLabel,

    required bool isHome,
    required VoidCallback onGoHome,

    Widget? background,

    VoidCallback? onGoNearbyMapOverride,
  }) {
    return AppDrawer(
      userStream: userStream,
      locationLabel: locationLabel,
      background: background,

      isHome: isHome,
      onGoHome: onGoHome,

      onGoNearbyMap: onGoNearbyMapOverride ?? () {},

      onGoReport: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Event()));
      },

      onGoCommunity: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityPage()));
      },

      onGoNotice: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Notice()));
      },

      onGoFashion: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Fashion()));
      },

      onGoChatter: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Chatter()));
      },

      onGoIssueList: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const Event()));
      },

      onGoWriteIssue: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => Communityadd()));
      },

      onGoMyPage: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserMypage()));
      },

      onGoSettings: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LocationSettings()));
      },

      onLogout: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
          );
        }
      },
    );
  }

  static Future<List<NearbyIssuePost>> _safeGetPosts(
      Future<List<NearbyIssuePost>> Function() getter,
      ) async {
    try {
      return await getter().timeout(const Duration(seconds: 2));
    } catch (_) {
      return const <NearbyIssuePost>[];
    }
  }
}