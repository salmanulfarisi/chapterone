import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import '../../core/utils/logger.dart';

// Parameter class for stable provider keys
class FeedbackQueryParams {
  final String? type;
  final String? status;
  final int page;
  final int limit;

  FeedbackQueryParams({
    this.type,
    this.status,
    required this.page,
    required this.limit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackQueryParams &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          status == other.status &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode => type.hashCode ^ status.hashCode ^ page.hashCode ^ limit.hashCode;
}

class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  ConsumerState<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  String _selectedType = 'all';
  String _selectedStatus = 'all';
  int _currentPage = 1;
  final int _limit = 20;

  FeedbackQueryParams get _providerParams {
    return FeedbackQueryParams(
      type: _selectedType == 'all' ? null : _selectedType,
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      page: _currentPage,
      limit: _limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(
      adminFeedbackProvider(_providerParams),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Requests'),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardBackground,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
                      DropdownMenuItem(value: 'request', child: Text('Request')),
                      DropdownMenuItem(value: 'contact', child: Text('Contact')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Feedback List
          Expanded(
            child: feedbackAsync.when(
              data: (data) {
                final feedbacks = data['feedbacks'] as List;
                final totalPages = data['totalPages'] as int;

                if (feedbacks.isEmpty) {
                  return const Center(
                    child: Text('No feedback found'),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(adminFeedbackProvider(_providerParams));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: feedbacks.length,
                          itemBuilder: (context, index) {
                            final feedback = feedbacks[index];
                            return _FeedbackCard(
                              feedback: feedback,
                              onStatusUpdate: () {
                                ref.invalidate(adminFeedbackProvider(_providerParams));
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    // Pagination
                    if (totalPages > 1)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 1
                                  ? () {
                                      setState(() => _currentPage--);
                                    }
                                  : null,
                            ),
                            Text('Page $_currentPage of $totalPages'),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentPage < totalPages
                                  ? () {
                                      setState(() => _currentPage++);
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryRed),
                    const SizedBox(height: 16),
                    Text(
                      'Loading feedback...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              error: (error, stack) {
                Logger.error(
                  'Admin feedback error: ${error.toString()}',
                  error,
                  stack,
                  'AdminFeedbackScreen',
                );
                return Center(
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
                        'Error loading feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(adminFeedbackProvider(_providerParams));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends ConsumerWidget {
  final Map<String, dynamic> feedback;
  final VoidCallback onStatusUpdate;

  const _FeedbackCard({
    required this.feedback,
    required this.onStatusUpdate,
  });

  void _showStatusUpdateDialog(BuildContext context, WidgetRef ref, String feedbackId, String newStatus, VoidCallback onUpdate) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Status'),
        content: Text('Change status to ${newStatus.toUpperCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.put(
                  '${ApiConstants.adminFeedback}/$feedbackId',
                  data: {'status': newStatus},
                );
                onUpdate();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Status updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = feedback['userId'];
    final username = user?['username'] ?? user?['email'] ?? 'Unknown';
    final type = feedback['type'] ?? 'feedback';
    final status = feedback['status'] ?? 'pending';
    final subject = feedback['subject'] ?? '';
    final message = feedback['message'] ?? '';
                final mangaTitle = feedback['mangaTitle'];
                final adminNotes = feedback['adminNotes'];
    final createdAt = feedback['createdAt'] != null
        ? DateTime.parse(feedback['createdAt'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardBackground,
      child: ExpansionTile(
        leading: Icon(
          type == 'request' ? Icons.book : type == 'contact' ? Icons.mail : Icons.feedback,
          color: AppTheme.primaryRed,
        ),
        title: Text(
          subject,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $username'),
            Text('Type: ${type.toUpperCase()}'),
            Text('Status: ${status.toUpperCase()}'),
            if (createdAt != null) Text('Date: ${_formatDate(createdAt)}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mangaTitle != null) ...[
                  Text(
                    'Manga: $mangaTitle',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Message:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(message),
                if (adminNotes != null && adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Admin Notes:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(adminNotes),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (newStatus) async {
                        if (newStatus != null && newStatus != status) {
                          _showStatusUpdateDialog(context, ref, feedback['_id'], newStatus, onStatusUpdate);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Provider for admin feedback
final adminFeedbackProvider = FutureProvider.family<Map<String, dynamic>, FeedbackQueryParams>(
  (ref, params) async {
    final apiService = ref.watch(apiServiceProvider);
    try {
      final queryParams = <String, dynamic>{
        'page': params.page,
        'limit': params.limit,
      };
      if (params.type != null) {
        queryParams['type'] = params.type;
      }
      if (params.status != null) {
        queryParams['status'] = params.status;
      }

      final response = await apiService.get(
        ApiConstants.adminFeedback,
        queryParameters: queryParams,
      );
      
      final data = response.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        // Ensure feedbacks is always a List
        if (result['feedbacks'] == null) {
          result['feedbacks'] = [];
        }
        if (result['total'] == null) {
          result['total'] = 0;
        }
        if (result['totalPages'] == null) {
          result['totalPages'] = 0;
        }
        return result;
      }
      
      // Fallback structure
      return {
        'feedbacks': data is List ? data : [],
        'total': data is List ? data.length : 0,
        'page': params.page,
        'limit': params.limit,
        'totalPages': data is List ? ((data.length / params.limit).ceil()) : 0,
      };
    } catch (e) {
      Logger.error(
        'Error fetching admin feedback: ${e.toString()}',
        e,
        null,
        'AdminFeedbackProvider',
      );
      return {
        'feedbacks': [],
        'total': 0,
        'page': params.page,
        'limit': params.limit,
        'totalPages': 0,
      };
    }
  },
);

