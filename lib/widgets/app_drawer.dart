import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    this.title = '메뉴',
    this.locationLabel,
    this.background,
    this.userStream,

    // ✅ 홈 분기
    required this.isHome,
    required this.onGoHome,

    // ✅ 섹션별 액션들
    required this.onGoNearbyMap,
    required this.onGoReport,

    required this.onGoCommunity,
    required this.onGoNotice,
    required this.onGoFashion,
    required this.onGoChatter,
    required this.onGoIssueList,
    required this.onGoWriteIssue,

    required this.onGoMyPage,

    required this.onGoSettings,
    required this.onLogout,
  });

  // ----------------------------
  // Optional UI
  // ----------------------------
  final String title;
  final String? locationLabel;

  /// ✅ 배경 주입 없으면 기본 하늘색
  final Widget? background;

  /// ✅ 유저 헤더용: users/{uid} 문서 스냅샷 스트림
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? userStream;

  // ----------------------------
  // Home behavior
  // ----------------------------
  final bool isHome;

  /// ✅ 홈이 아닌 페이지에서만 호출됨(홈으로 이동)
  final VoidCallback onGoHome;

  // ----------------------------
  // Actions
  // ----------------------------
  final VoidCallback onGoNearbyMap;
  final VoidCallback onGoReport;

  final VoidCallback onGoCommunity;
  final VoidCallback onGoNotice;
  final VoidCallback onGoFashion;
  final VoidCallback onGoChatter;
  final VoidCallback onGoIssueList;
  final VoidCallback onGoWriteIssue;

  final VoidCallback onGoMyPage;

  final VoidCallback onGoSettings;
  final Future<void> Function() onLogout;

  // ----------------------------
  // Helpers
  // ----------------------------
  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.pop(context); // drawer 닫기
    action();
  }

  Future<void> _closeThenAsync(BuildContext context, Future<void> Function() action) async {
    Navigator.pop(context); // drawer 닫기
    await action();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(child: background ?? const _DaySkyDrawerBackground()),

          SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ✅ 유저 헤더(있으면) / 없으면 기본 헤더
                if (userStream != null)
                  _UserHeader(
                    title: title,
                    locationLabel: locationLabel,
                    userStream: userStream!,
                  )
                else
                  _DrawerHeader(title: title, subtitle: locationLabel),

                const SizedBox(height: 10),

                // =========================
                // 바로가기
                // =========================
                const _SectionTitle('바로가기'),
                _Item(
                  icon: Icons.home_outlined,
                  label: isHome ? '닫기' : '홈',
                  onTap: () {
                    if (isHome) {
                      Navigator.pop(context);
                    } else {
                      _closeThen(context, onGoHome);
                    }
                  },
                ),
                _Item(
                  icon: Icons.map_outlined,
                  label: '내 주변 지도',
                  onTap: () => _closeThen(context, onGoNearbyMap),
                ),
                _Item(
                  icon: Icons.campaign_outlined,
                  label: '제보',
                  onTap: () => _closeThen(context, onGoReport),
                ),

                const SizedBox(height: 14),

                // =========================
                // 커뮤니티
                // =========================
                const _SectionTitle('커뮤니티'),
                _Item(
                  icon: Icons.forum_outlined,
                  label: '커뮤니티 메인',
                  onTap: () => _closeThen(context, onGoCommunity),
                ),
                _Item(
                  icon: Icons.campaign_outlined,
                  label: '공지',
                  onTap: () => _closeThen(context, onGoNotice)
                ),
                _Item(
                  icon: Icons.checkroom_outlined,
                  label: '패션',
                  onTap: () => _closeThen(context, onGoFashion)
                ),
                _Item(
                  icon: Icons.chat_bubble_outline,
                  label: '수다',
                  onTap: () => _closeThen(context, onGoChatter)
                ),
                _Item(
                  icon: Icons.warning_amber_outlined,
                  label: '사건/이슈',
                  onTap: () => _closeThen(context, onGoIssueList)
                ),
                _Item(
                  icon: Icons.edit_outlined,
                  label: '사건/이슈 작성',
                  onTap: () => _closeThen(context, onGoWriteIssue),
                ),

                const SizedBox(height: 14),

                // =========================
                // 내 정보
                // =========================
                const _SectionTitle('내 정보'),
                _Item(
                  icon: Icons.person_outline,
                  label: '마이페이지',
                  onTap: () => _closeThen(context, onGoMyPage),
                ),

                const SizedBox(height: 14),

                // =========================
                // 설정/계정
                // =========================
                const _SectionTitle('설정/계정'),
                _Item(
                  icon: Icons.settings_outlined,
                  label: '설정',
                  onTap: () => _closeThen(context, onGoSettings),
                ),

                const Divider(height: 22, thickness: 1, color: Colors.white24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton(
                    onPressed: () async => _closeThenAsync(context, onLogout),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================
// Background
// =============================
class _DaySkyDrawerBackground extends StatelessWidget {
  const _DaySkyDrawerBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4FC3F7),
            Color(0xFF4FC3F7),
            Color(0xFF4FC3F7),
          ],
        ),
      ),
    );
  }
}

// =============================
// Header (default)
// =============================
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================
// Header (user)
// =============================
class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.title,
    required this.userStream,
    this.locationLabel,
  });

  final String title;
  final String? locationLabel;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> userStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final nick = (data?['nickName'] ?? '').toString().trim();
        final img = (data?['profile_image_url'] ?? '').toString().trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                backgroundImage: (img.isNotEmpty) ? NetworkImage(img) : null,
                child: (img.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (nick.isNotEmpty) ? nick : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (locationLabel != null && locationLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locationLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================
// Section title
// =============================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// =============================
// Item
// =============================
class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      onTap: onTap,
    );
  }
}