import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showSenderName;
  final String currentUserId;
  final Function(bool deleteForEveryone)? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    this.showSenderName = true,
    this.currentUserId = 'user-hardik',
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
        size: 14,
        color: Color(0xFF58A6FF), // Blue seen ticks
      );
    } else if (message.status == 'delivered') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Color(0xFF8B949E), // Grey delivered double tick
      );
    } else {
      return const Icon(
        Icons.done_rounded,
        size: 14,
        color: Color(0xFF8B949E), // Grey sent single tick
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final isDeleted = message.isDeleted;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF58A6FF),
                        ),
                      ),
                      const SizedBox(height: 2),
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
                    else
                      Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFF0F6FC),
                          height: 1.35,
                        ),
                      ),

                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                        if (isMine && !isDeleted) ...[
                          const SizedBox(width: 4),
                          _buildSeenIndicator(),
                        ],
                      ],
                    ),
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
