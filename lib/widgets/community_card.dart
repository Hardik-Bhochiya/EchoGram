import 'package:flutter/material.dart';
import '../models/community.dart';

class CommunityCard extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;
  final VoidCallback onJoinToggle;
  final VoidCallback? onChatTap;
  final VoidCallback? onDelete;
  final bool isHorizontal;

  const CommunityCard({
    super.key,
    required this.community,
    required this.onTap,
    required this.onJoinToggle,
    this.onChatTap,
    this.onDelete,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF30363D),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(
                      community.iconEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: Text(
                          community.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                community.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFFF0F6FC),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 12, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      community.locationSpot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF58A6FF), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                community.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF8B949E),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF8B949E)),
                  const SizedBox(width: 4),
                  Text(
                    '${community.memberCount} members',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B949E)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Text(
                      community.iconEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                community.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: Color(0xFFF0F6FC),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF21262D),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF30363D)),
                              ),
                              child: Text(
                                community.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B949E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Location Spot Forwarding Tag
                        Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 13, color: Color(0xFF58A6FF)),
                            const SizedBox(width: 3),
                            Text(
                              community.locationSpot,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF58A6FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          community.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFF30363D)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 15, color: Color(0xFF238636)),
                      const SizedBox(width: 5),
                      Text(
                        '${community.memberCount} ${community.memberCount == 1 ? 'member joined' : 'members joined'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDA3633), size: 19),
                          tooltip: 'Delete Group (Creator)',
                          onPressed: onDelete,
                        ),
                      // Simple Chat Button
                      InkWell(
                        onTap: onChatTap ?? onTap,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF58A6FF)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF58A6FF)),
                              SizedBox(width: 4),
                              Text(
                                'Chat',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF58A6FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Join / Leave Button
                      if (community.isJoined)
                        InkWell(
                          onTap: onJoinToggle,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21262D),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFF85149)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.exit_to_app_rounded, size: 13, color: Color(0xFFF85149)),
                                SizedBox(width: 4),
                                Text(
                                  'Leave',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF85149),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: onJoinToggle,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF238636),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0x33FFFFFF)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Join',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
