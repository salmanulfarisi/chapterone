import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../services/api/api_service.dart';
import 'package:intl/intl.dart';
import '../../core/utils/logger.dart';

// Activity logs provider with stable key
final activityLogsProvider =
    FutureProvider.family<Map<String, dynamic>, _LogFilters>((
      ref,
      filters,
    ) async {
      final apiService = ref.watch(apiServiceProvider);
      try {
        final queryParams = <String, dynamic>{};
        if (filters.action != null) queryParams['action'] = filters.action;
        if (filters.severity != null) {
          queryParams['severity'] = filters.severity;
        }
        if (filters.limit != null) queryParams['limit'] = filters.limit;
        if (filters.skip != null) queryParams['skip'] = filters.skip;

        final response = await apiService.get(
          ApiConstants.adminLogs,
          queryParameters: queryParams,
        );
        return Map<String, dynamic>.from(response.data);
      } catch (e) {
        Logger.error(
          'Error fetching activity logs: ${e.toString()}',
          e,
          null,
          'ActivityLogsProvider',
        );
        return {'logs': [], 'total': 0, 'error': e.toString()};
      }
    });

// Stable filter class for provider key
class _LogFilters {
  final String? action;
  final String? severity;
  final int? limit;
  final int? skip;

  _LogFilters({this.action, this.severity, this.limit, this.skip});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LogFilters &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          severity == other.severity &&
          limit == other.limit &&
          skip == other.skip;

  @override
  int get hashCode =>
      action.hashCode ^ severity.hashCode ^ limit.hashCode ^ skip.hashCode;
}

// System health provider
final systemHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get('${ApiConstants.adminLogs}/health');
    return Map<String, dynamic>.from(response.data);
  } catch (e) {
    Logger.error(
      'Error fetching system health: ${e.toString()}',
      e,
      null,
      'SystemHealthProvider',
    );
    return {'error': e.toString()};
  }
});

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  String? _selectedAction;
  String? _selectedSeverity;
  int _currentPage = 0;
  final int _pageSize = 50;

  @override
  Widget build(BuildContext context) {
    // Create stable filter object
    final filters = _LogFilters(
      action: _selectedAction,
      severity: _selectedSeverity,
      limit: _pageSize,
      skip: _currentPage * _pageSize,
    );

    final logsAsync = ref.watch(activityLogsProvider(filters));
    final healthAsync = ref.watch(systemHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final currentFilters = _LogFilters(
                action: _selectedAction,
                severity: _selectedSeverity,
                limit: _pageSize,
                skip: _currentPage * _pageSize,
              );
              ref.invalidate(activityLogsProvider(currentFilters));
              ref.invalidate(systemHealthProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // System Health Stats
          healthAsync.when(
            data: (health) {
              if (health.containsKey('error')) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.cardBackground,
                  child: Center(
                    child: Text(
                      'Error loading health stats: ${health['error']}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.cardBackground,
                child: Row(
                  children: [
                    Expanded(
                      child: _HealthStatCard(
                        label: 'Total Logs',
                        value: '${health['totalLogs'] ?? 0}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HealthStatCard(
                        label: 'Errors',
                        value: '${health['errorLogs'] ?? 0}',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HealthStatCard(
                        label: 'Critical',
                        value: '${health['criticalLogs'] ?? 0}',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HealthStatCard(
                        label: 'Error Rate',
                        value:
                            '${(health['errorRate'] ?? 0).toStringAsFixed(1)}%',
                        color: (health['errorRate'] ?? 0) > 5
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.cardBackground,
              child: Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),

          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardBackground,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAction,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All Actions',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'manga_created',
                        child: Text(
                          'Manga Created',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'manga_updated',
                        child: Text(
                          'Manga Updated',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'manga_deleted',
                        child: Text(
                          'Manga Deleted',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'chapter_added',
                        child: Text(
                          'Chapter Added',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'scraper_job_completed',
                        child: Text(
                          'Job Completed',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'system_error',
                        child: Text(
                          'System Error',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedAction = value;
                        _currentPage = 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSeverity,
                    decoration: const InputDecoration(
                      labelText: 'Severity',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All Severities',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'info',
                        child: Text('Info', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'warning',
                        child: Text('Warning', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'error',
                        child: Text('Error', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text(
                          'Critical',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSeverity = value;
                        _currentPage = 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: logsAsync.when(
              data: (data) {
                final logs = data['logs'] as List<dynamic>? ?? [];
                final total = data['total'] as int? ?? 0;

                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logs found',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return _LogItem(log: log);
                        },
                      ),
                    ),
                    // Pagination
                    if (total > _pageSize)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              'Page ${_currentPage + 1} of ${(total / _pageSize).ceil()}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: (_currentPage + 1) * _pageSize < total
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading logs',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        error.toString(),
                        style: const TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final currentFilters = _LogFilters(
                          action: _selectedAction,
                          severity: _selectedSeverity,
                          limit: _pageSize,
                          skip: _currentPage * _pageSize,
                        );
                        ref.invalidate(activityLogsProvider(currentFilters));
                        ref.invalidate(systemHealthProvider);
                      },
                      child: const Text('Retry'),
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

class _HealthStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogItem({required this.log});

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'error':
        return Colors.orange;
      case 'warning':
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = log['severity'] as String? ?? 'info';
    final action = log['action'] as String? ?? 'unknown';
    final user = log['userId'] as Map<String, dynamic>?;
    final details = log['details'] as Map<String, dynamic>? ?? {};
    final timestamp = log['createdAt'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          color: _getSeverityColor(severity),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                action.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            if (timestamp != null)
              Text(
                DateFormat('MMM dd, HH:mm').format(DateTime.parse(timestamp)),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null)
              Text(
                'User: ${user['username'] ?? user['email'] ?? 'Unknown'}',
                style: const TextStyle(fontSize: 11),
              ),
            if (details.isNotEmpty)
              Text(
                details.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
