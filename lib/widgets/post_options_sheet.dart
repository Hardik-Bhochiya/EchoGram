import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/question_provider.dart';
import '../models/question.dart';

class PostOptionsSheet extends StatelessWidget {
  final Question question;

  const PostOptionsSheet({super.key, required this.question});

  static void show(BuildContext context, Question question) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PostOptionsSheet(question: question),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final questionProvider = context.watch<QuestionProvider>();
    final currentQ = questionProvider.getQuestionById(question.id) ?? question;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                currentQ.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: currentQ.isBookmarked ? const Color(0xFF7C3AED) : null,
              ),
              title: Text(currentQ.isBookmarked ? 'Remove Bookmark' : 'Bookmark Question'),
              subtitle: const Text('Save this post to your profile library', style: TextStyle(fontSize: 12)),
              onTap: () {
                questionProvider.toggleBookmark(currentQ.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      currentQ.isBookmarked
                          ? 'Removed from bookmarks'
                          : 'Saved to bookmarks in Profile 📌',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Question'),
              subtitle: const Text('Send to friends or batch WhatsApp group', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Question link copied to clipboard 📋')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy Post Text'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post copied to clipboard')),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
              title: const Text('Report Post', style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Report spam, abuse, or violation of community guidelines', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted to moderators')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
