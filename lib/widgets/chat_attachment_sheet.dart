import 'package:flutter/material.dart';

class ChatAttachmentSheet extends StatelessWidget {
  final Function(String type, String title) onSelected;

  const ChatAttachmentSheet({super.key, required this.onSelected});

  static void show(BuildContext context, Function(String type, String title) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatAttachmentSheet(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.image_rounded, 'color': const Color(0xFF58A6FF), 'title': 'Photo / Image', 'type': 'photo'},
      {'icon': Icons.camera_alt_rounded, 'color': const Color(0xFFBC8CFF), 'title': 'Camera', 'type': 'camera'},
      {'icon': Icons.description_rounded, 'color': const Color(0xFF388BFD), 'title': 'Document / Notes', 'type': 'document'},
      {'icon': Icons.contact_page_rounded, 'color': const Color(0xFF238636), 'title': 'Contact', 'type': 'contact'},
      {'icon': Icons.poll_rounded, 'color': const Color(0xFFD29922), 'title': 'Create Poll', 'type': 'poll'},
      {'icon': Icons.mic_rounded, 'color': const Color(0xFF79C0FF), 'title': 'Audio Note', 'type': 'audio'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Share Content',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF0F6FC),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(item['type'] as String, item['title'] as String);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: item['color'] as Color,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['title'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF0F6FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
