import 'package:flutter/material.dart';

class Communityadd extends StatefulWidget {
  const Communityadd({super.key});

  @override
  State<Communityadd> createState() => _CommunityaddState();
}

class _CommunityaddState extends State<Communityadd> {
  final List<String> categories = ["사건/이슈", "수다", "패션"];
  String selectedCategory = "사건/이슈";

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox; // scaffold context
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    // 선택박스 위치를 얻기 위해 CompositedTransformTarget로 연결할 거라
    // 여기서는 “너비”만 잡아주면 됨
    final double dropdownWidth = 400; // 필요하면 double.infinity 대신 박스 너비로 맞춰도 됨

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown, // 바깥 누르면 닫힘
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 52), // ✅ 항상 "아래"로 (박스 높이만큼)
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 180, // 많아지면 스크롤
                    minWidth: 200,
                  ),
                  child: Container(
                    width: dropdownWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: categories.map((item) {
                        final bool selected = item == selectedCategory;
                        return ListTile(
                          dense: true,
                          title: Text(item),
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () {
                            setState(() => selectedCategory = item);
                            _removeDropdown();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("새 게시물")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 이 박스 바로 아래로 항상 펼쳐지게 연결
            CompositedTransformTarget(
              link: _layerLink,
              child: InkWell(
                onTap: _toggleDropdown,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Text(selectedCategory, style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      Icon(_isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              decoration: const InputDecoration(
                labelText: "제목",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: TextField(
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: "내용",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),

            const SizedBox(height: 0),

            const ListTile(
              leading: Icon(Icons.location_on_outlined),
              title: Text("위치추가"),
              trailing: Icon(Icons.chevron_right),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("공유"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
