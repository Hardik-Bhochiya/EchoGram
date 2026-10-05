import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/question_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/tag_chip.dart';

class AskQuestionScreen extends StatefulWidget {
  final String? preselectedCommunityId;
  const AskQuestionScreen({super.key, this.preselectedCommunityId});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagInputController = TextEditingController();

  String? _selectedCommunityId;
  bool _isAnonymous = false;
  final List<String> _selectedTags = [];

  final List<String> _suggestedTags = [
    'General',
    'Tech',
    'DailyChat',
    'Gaming',
    'Sports',
    'Music',
    'Movies',
    'Help',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCommunityId = widget.preselectedCommunityId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final cleaned = tag.trim().replaceAll('#', '');
    if (cleaned.isNotEmpty && !_selectedTags.contains(cleaned)) {
      setState(() => _selectedTags.add(cleaned));
      _tagInputController.clear();
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      final auth = context.read<AuthProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final questionProvider = context.read<QuestionProvider>();

      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final targetCommunityId = _selectedCommunityId ??
          (communityProvider.communities.isNotEmpty
              ? communityProvider.communities.first.id
              : 'c1');

      final targetCommunity = communityProvider.getCommunityById(targetCommunityId);
      final communityName = targetCommunity?.name ?? 'General Discussion';
      final regionId = targetCommunity?.regionId ?? 'general';
      final regionName = targetCommunity?.regionName ?? 'General';

      questionProvider.askQuestion(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        communityId: targetCommunityId,
        communityName: communityName,
        regionId: regionId,
        regionName: regionName,
        user: currentUser,
        isAnonymous: _isAnonymous,
        tags: _selectedTags.isNotEmpty ? _selectedTags : ['General'],
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAnonymous
                ? 'Question posted anonymously to $communityName! 🎭'
                : 'Question posted to $communityName!',
          ),
          backgroundColor: const Color(0xFF6D28D9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final communityProvider = context.watch<CommunityProvider>();
    final communities = communityProvider.communities;

    if (_selectedCommunityId == null && communities.isNotEmpty) {
      _selectedCommunityId = communities.first.id;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
        elevation: 0,
        title: const Text('Ask Your Community', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _handleSubmit,
            child: const Text(
              'Post',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7C3AED)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Community Selector
                const Text(
                  'Select Target Community',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCommunityId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151C2C) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: communities.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Text(c.iconEmoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCommunityId = val);
                  },
                ),
                const SizedBox(height: 18),

                // Title Input
                CustomTextField(
                  controller: _titleController,
                  labelText: 'Question Title',
                  hintText: 'e.g. Where can I find mid-sem question papers for 4th sem CE?',
                  maxLines: 2,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a title';
                    if (v.trim().length < 8) return 'Please provide more details in the title';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Content / Description Input
                CustomTextField(
                  controller: _contentController,
                  labelText: 'Details / Context (Optional)',
                  hintText: 'Share more context so seniors and professors can give exact answers...',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),

                // Tags Section
                const Text(
                  'Add Relevant Tags',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestedTags.map((tag) {
                    final isSel = _selectedTags.contains(tag);
                    return TagChip(
                      label: tag,
                      isSelected: isSel,
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagInputController,
                        decoration: InputDecoration(
                          hintText: 'Type custom tag (e.g. DDU_Exam)...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF151C2C) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _addTag(_tagInputController.text),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Anonymous Post Switch Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isAnonymous
                        ? const Color(0xFFFDF2F8)
                        : (isDark ? const Color(0xFF151C2C) : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isAnonymous
                          ? const Color(0xFFF472B6)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isAnonymous
                              ? const Color(0xFFFCE7F3)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEDE9FE)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.theater_comedy_rounded,
                          color: _isAnonymous ? const Color(0xFFDB2777) : const Color(0xFF7C3AED),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Post Anonymously',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            Text(
                              'Your name and profile avatar will be masked.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAnonymous,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: (val) => setState(() => _isAnonymous = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                PrimaryButton(
                  text: 'Publish Question',
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
