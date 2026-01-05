import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../auth/providers/auth_provider.dart';
import '../manga/providers/manga_provider.dart';
import '../../core/utils/logger.dart';

class MangaDiscussionScreen extends ConsumerStatefulWidget {
  final String mangaId;

  const MangaDiscussionScreen({super.key, required this.mangaId});

  @override
  ConsumerState<MangaDiscussionScreen> createState() => _MangaDiscussionScreenState();
}

class _MangaDiscussionScreenState extends ConsumerState<MangaDiscussionScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToCommentId;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    ref.invalidate(commentsProvider(widget.mangaId));
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post(
        ApiConstants.comments,
        data: {
          'mangaId': widget.mangaId,
          'content': _commentController.text.trim(),
        },
      );
      _commentController.clear();
      _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Comment posted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitReply(String parentCommentId) async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post(
        ApiConstants.comments,
        data: {
          'mangaId': widget.mangaId,
          'content': _replyController.text.trim(),
          'parentCommentId': parentCommentId,
        },
      );
      _replyController.clear();
      setState(() => _replyingToCommentId = null);
      _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Reply posted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post('${ApiConstants.comments}/$commentId/like');
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final mangaAsync = ref.watch(mangaDetailProvider(widget.mangaId));
    final commentsAsync = ref.watch(commentsProvider(widget.mangaId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: mangaAsync.maybeWhen(
          data: (manga) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                manga?.title ?? 'Discussion',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                'Community Discussion',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          orElse: () => const Text('Discussion'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to start the discussion!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadComments,
                  color: AppTheme.primaryRed,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final replies = comment['replies'] as List<dynamic>? ?? [];
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: index < comments.length - 1 ? 20 : 0),
                        child: _MainCommentCard(
                          comment: comment,
                          replies: replies,
                          onReply: () {
                            setState(() => _replyingToCommentId = comment['_id']);
                          },
                          onLike: () => _toggleLike(
                            comment['_id'],
                            comment['isLiked'] ?? false,
                          ),
                          onReplyLike: (replyId, isLiked) => _toggleLike(replyId, isLiked),
                          isReplying: _replyingToCommentId == comment['_id'],
                          replyController: _replyController,
                          onSubmitReply: () => _submitReply(comment['_id']),
                          onCancelReply: () {
                            setState(() => _replyingToCommentId = null);
                            _replyController.clear();
                          },
                          isSubmitting: _isSubmitting,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryRed),
                    const SizedBox(height: 16),
                    Text(
                      'Loading comments...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadComments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (user != null)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _commentController,
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts...',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.send,
                                color: _commentController.text.trim().isNotEmpty
                                    ? AppTheme.primaryRed
                                    : AppTheme.textSecondary,
                              ),
                              onPressed: _isSubmitting || _commentController.text.trim().isEmpty
                                  ? null
                                  : _submitComment,
                            ),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      if (_isSubmitting)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryRed,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Posting...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
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

class _MainCommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  final List<dynamic> replies;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final Function(String, bool) onReplyLike;
  final bool isReplying;
  final TextEditingController replyController;
  final VoidCallback onSubmitReply;
  final VoidCallback onCancelReply;
  final bool isSubmitting;

  const _MainCommentCard({
    required this.comment,
    required this.replies,
    required this.onReply,
    required this.onLike,
    required this.onReplyLike,
    required this.isReplying,
    required this.replyController,
    required this.onSubmitReply,
    required this.onCancelReply,
    required this.isSubmitting,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = comment['userId'];
    final username = user?['username'] ?? 'Anonymous';
    final avatar = user?['avatar'];
    final content = comment['content'] ?? '';
    final likesCount = comment['likesCount'] ?? 0;
    final isLiked = comment['isLiked'] ?? false;
    final createdAt = comment['createdAt'] != null
        ? DateTime.parse(comment['createdAt'].toString())
        : null;
    final repliesCount = comment['repliesCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryRed.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Comment
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with gradient border
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryRed,
                            AppTheme.primaryRed.withOpacity(0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryRed.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.darkBackground,
                        backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                        child: avatar == null
                            ? Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _formatDate(createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            content,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? AppTheme.primaryRed.withOpacity(0.2)
                              : AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: isLiked
                              ? Border.all(
                                  color: AppTheme.primaryRed.withOpacity(0.5),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$likesCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply_outlined,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reply${repliesCount > 0 ? ' ($repliesCount)' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isReplying) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryRed.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: replyController,
                          maxLines: 3,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSubmitting ? null : onCancelReply,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: isSubmitting ? null : onSubmitReply,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Reply', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Replies Section
          if (replies.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              height: 1,
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$repliesCount ${repliesCount == 1 ? 'Reply' : 'Replies'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...replies.asMap().entries.map((entry) {
                    final index = entry.key;
                    final reply = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < replies.length - 1 ? 14 : 0),
                      child: _ReplyCard(
                        reply: reply,
                        onLike: () => onReplyLike(reply['_id'], reply['isLiked'] ?? false),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Reply Card Widget
class _ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;
  final VoidCallback onLike;

  const _ReplyCard({
    required this.reply,
    required this.onLike,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = reply['userId'];
    final username = user?['username'] ?? 'Anonymous';
    final avatar = user?['avatar'];
    final content = reply['content'] ?? '';
    final likesCount = reply['likesCount'] ?? 0;
    final isLiked = reply['isLiked'] ?? false;
    final createdAt = reply['createdAt'] != null
        ? DateTime.parse(reply['createdAt'].toString())
        : null;

    return Container(
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withOpacity(0.08),
        ),
      ),
      child: Stack(
        children: [
          // Connecting line indicator
          Positioned(
            left: -24,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryRed.withOpacity(0.3),
                    AppTheme.primaryRed.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.cardBackground,
                  backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                  child: avatar == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      : null,
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
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        content,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isLiked
                                ? AppTheme.primaryRed.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$likesCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Provider for comments
final commentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mangaId) async {
    final apiService = ref.watch(apiServiceProvider);
    try {
      final response = await apiService.get(
        ApiConstants.comments,
        queryParameters: {'mangaId': mangaId},
      );
      final List<dynamic> data = response.data is List ? response.data : [];
      return data.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      Logger.error(
        'Error fetching comments: ${e.toString()}',
        e,
        null,
        'CommentsProvider',
      );
      return [];
    }
  },
);
