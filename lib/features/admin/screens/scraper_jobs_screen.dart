import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../widgets/empty_state.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';

class ScraperJobsScreen extends ConsumerStatefulWidget {
  const ScraperJobsScreen({super.key});

  @override
  ConsumerState<ScraperJobsScreen> createState() => _ScraperJobsScreenState();
}

class _ScraperJobsScreenState extends ConsumerState<ScraperJobsScreen> {
  String _selectedStatus = 'all'; // all, pending, running, completed, failed

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(scrapingJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Scraper Jobs'),
            const SizedBox(width: 8),
            // Real-time update indicator
            jobsAsync.when(
              data: (jobs) {
                final hasRunning = jobs.any((j) => j['status'] == 'running' || j['status'] == 'pending');
                if (hasRunning) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: 0.5 + (0.5 * (0.5 + 0.5 * (value * 2 - 1).abs())),
                          child: child,
                        );
                      },
                      onEnd: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(scrapingJobsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter with counts
          jobsAsync.when(
            data: (jobs) => _buildStatusFilterWithCounts(jobs),
            loading: () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const LinearProgressIndicator(),
            ),
            error: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text('Filter: '),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('all', 'All', 0),
                          _buildStatusChip('pending', 'Pending', 0),
                          _buildStatusChip('running', 'Running', 0),
                          _buildStatusChip('completed', 'Completed', 0),
                          _buildStatusChip('failed', 'Failed', 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Jobs list
          Expanded(
            child: jobsAsync.when(
              data: (jobs) {
                final filteredJobs = _selectedStatus == 'all'
                    ? jobs
                    : jobs.where((job) => job['status'] == _selectedStatus).toList();

                if (filteredJobs.isEmpty) {
                  return EmptyState(
                    title: 'No Jobs',
                    message: _selectedStatus == 'all'
                        ? 'No scraping jobs found'
                        : 'No jobs with status: $_selectedStatus',
                    icon: Icons.work_off,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(scrapingJobsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = filteredJobs[index];
                      return _buildJobCard(job);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => EmptyState(
                title: 'Error',
                message: error.toString(),
                icon: Icons.error_outline,
                onRetry: () => ref.invalidate(scrapingJobsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterWithCounts(List<Map<String, dynamic>> jobs) {
    final allCount = jobs.length;
    final pendingCount = jobs.where((j) => j['status'] == 'pending').length;
    final runningCount = jobs.where((j) => j['status'] == 'running').length;
    final completedCount = jobs.where((j) => j['status'] == 'completed').length;
    final failedCount = jobs.where((j) => j['status'] == 'failed').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Filter: '),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('all', 'All', allCount),
                      _buildStatusChip('pending', 'Pending', pendingCount),
                      _buildStatusChip('running', 'Running', runningCount),
                      _buildStatusChip('completed', 'Completed', completedCount),
                      _buildStatusChip('failed', 'Failed', failedCount),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Summary bar
          if (runningCount > 0 || pendingCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$runningCount running, $pendingCount pending',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, int count) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedStatus = status;
            });
          }
        },
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status']?.toString() ?? 'unknown';
    final jobType = job['jobType']?.toString() ?? '';
    final progress = job['progress'] as Map<String, dynamic>? ?? {};
    final percentage = (progress['percentage'] as num?)?.toDouble() ?? 0.0;
    final mangaTitle = job['mangaTitle']?.toString();
    final error = job['error']?.toString();
    final current = progress['current'] as num? ?? 0;
    final total = progress['total'] as num? ?? 0;
    final currentStep = progress['currentStep']?.toString() ?? '';
    final message = progress['message']?.toString() ?? '';

    Color statusColor;
    IconData statusIcon;
    Widget? statusIndicator;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        // Animated rotating icon for running jobs
        statusIndicator = TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 2 * 3.14159,
              child: Icon(statusIcon, color: statusColor),
            );
          },
          onEnd: () {
            if (mounted && status == 'running') setState(() {});
          },
        );
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        // Pulsing animation for pending jobs
        statusIndicator = TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return Opacity(
              opacity: 0.5 + (0.5 * value),
              child: Icon(statusIcon, color: statusColor),
            );
          },
          onEnd: () {
            if (mounted && status == 'pending') setState(() {});
          },
        );
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.help_outline;
    }

    final jobIdStr = job['_id']?.toString() ?? '';
    final jobIdDisplay = jobIdStr.isNotEmpty && jobIdStr.length > 8
        ? jobIdStr.substring(0, 8)
        : jobIdStr;
    String jobTitle = mangaTitle ?? 'Job $jobIdDisplay...';
    
    // Add scraper name
    String scraperName = '';
    if (jobType.contains('asurascanz')) {
      scraperName = 'AsuraScanz';
    } else if (jobType.contains('asuracomic')) {
      scraperName = 'AsuraComic';
    } else if (jobType.contains('hotcomics')) {
      scraperName = 'HotComics';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: status == 'running' ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: status == 'running'
            ? BorderSide(color: statusColor.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        leading: statusIndicator ?? Icon(statusIcon, color: statusColor),
        title: Row(
          children: [
            Expanded(
              child: Text(
                jobTitle,
                style: TextStyle(
                  fontWeight: status == 'running' ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (scraperName.isNotEmpty) ...[
                  Chip(
                    avatar: Icon(Icons.web, size: 14, color: statusColor),
                    label: Text(
                      scraperName,
                      style: const TextStyle(fontSize: 10),
                    ),
                    padding: EdgeInsets.zero,
                    backgroundColor: statusColor.withOpacity(0.1),
                  ),
                  const SizedBox(width: 8),
                ],
                // Time indicator
                if (job['updatedAt'] != null)
                  Text(
                    _getTimeAgo(_parseDateTime(job['updatedAt'])),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            if (progress.isNotEmpty && (status == 'running' || status == 'pending')) ...[
              const SizedBox(height: 12),
              // Enhanced progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentStep.isNotEmpty || message.isNotEmpty) ...[
                    Text(
                      currentStep.isNotEmpty ? currentStep : message,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (current / total) : (percentage / 100),
                      backgroundColor: AppTheme.cardBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        total > 0
                            ? '$current / $total (${((current / total) * 100).toStringAsFixed(1)}%)'
                            : '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                      if (status == 'running')
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
            if (status == 'completed' && total > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Completed: $total items processed',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Job Type', jobType),
                _buildInfoRow('Job ID', job['_id']?.toString() ?? 'N/A'),
                if (job['createdAt'] != null)
                  _buildInfoRow(
                    'Created',
                    _parseDateTime(job['createdAt']).toString(),
                  ),
                if (job['updatedAt'] != null)
                  _buildInfoRow(
                    'Updated',
                    _parseDateTime(job['updatedAt']).toString(),
                  ),
                if (job['mangaId'] != null)
                  _buildInfoRow('Manga ID', job['mangaId']?.toString() ?? 'N/A'),
                if (job['url'] != null)
                  _buildInfoRow('URL', job['url']?.toString() ?? 'N/A'),
                if (status == 'running')
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final apiService = ref.read(apiServiceProvider);
                        await apiService.post(
                          '${ApiConstants.adminScraper}/jobs/${job['_id']}/cancel',
                        );
                        ref.invalidate(scrapingJobsProvider);
                        CustomSnackbar.success(context, 'Job cancelled');
                      } catch (e) {
                        CustomSnackbar.error(context, 'Failed to cancel job');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                    ),
                    child: const Text('Cancel Job'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    }
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

