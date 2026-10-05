import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showSenderName;
  final String currentUserId;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final Function(bool deleteForEveryone)? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    this.showSenderName = true,
    this.currentUserId = '',
    this.onLike,
    this.onDislike,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context) {
    if (message.isDeleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF58A6FF), size: 20),
                title: const Text('Copy Text', style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 14)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
              if (message.isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF85149), size: 20),
                  title: const Text('Delete Message', style: TextStyle(color: Color(0xFFF85149), fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call(true);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeenIndicator() {
    if (message.status == 'seen') {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF58A6FF), // WhatsApp-style blue double tick
      );
    } else if (message.status == 'delivered') {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF8B949E), // WhatsApp-style grey delivered double tick
      );
    } else {
      return const Icon(
        Icons.done_rounded,
        size: 15,
        color: Color(0xFF8B949E), // WhatsApp-style grey sent single tick
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final isDeleted = message.isDeleted;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    final hasLiked = message.likes.contains(currentUserId);
    final hasDisliked = message.dislikes.contains(currentUserId);
    final likeCount = message.likes.length;
    final dislikeCount = message.dislikes.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showSenderName) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF21262D),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF58A6FF),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showContextMenu(context),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 310),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? const Color(0xFF161B22)
                      : (isMine ? const Color(0xFF1F6FEB) : const Color(0xFF21262D)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isDeleted
                        ? const Color(0xFF30363D)
                        : (isMine ? const Color(0xFF388BFD) : const Color(0xFF30363D)),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMine && showSenderName && !isDeleted) ...[
                      Text(
                        message.senderName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF58A6FF),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],

                    if (isDeleted)
                      const Text(
                        'This message was deleted',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF8B949E),
                        ),
                      )
                    else ...[
                      Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFFF0F6FC),
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // WhatsApp-style reactions (Like & Dislike with counters) and Timestamp Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Like and Dislike buttons & counters under message
                          Wrap(
                            spacing: 6,
                            children: [
                              // Like button & counter
                              InkWell(
                                onTap: onLike,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasLiked
                                        ? (isMine ? const Color(0xFF1158C7) : const Color(0xFF30363D))
                                        : Colors.black.withAlpha(46),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: hasLiked ? const Color(0xFF58A6FF) : Colors.transparent,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                        size: 13,
                                        color: hasLiked ? const Color(0xFF58A6FF) : const Color(0xFF8B949E),
                                      ),
                                      if (likeCount > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '$likeCount',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: hasLiked ? const Color(0xFF58A6FF) : const Color(0xFFC9D1D9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              // Dislike button & counter
                              InkWell(
                                onTap: onDislike,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasDisliked
                                        ? (isMine ? const Color(0xFF8B1D1D) : const Color(0xFF3E1F24))
                                        : Colors.black.withAlpha(46),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: hasDisliked ? const Color(0xFFF85149) : Colors.transparent,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                                        size: 13,
                                        color: hasDisliked ? const Color(0xFFF85149) : const Color(0xFF8B949E),
                                      ),
                                      if (dislikeCount > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '$dislikeCount',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: hasDisliked ? const Color(0xFFF85149) : const Color(0xFFC9D1D9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 12),

                          // Time and WhatsApp ticks
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF8B949E),
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 4),
                                _buildSeenIndicator(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
