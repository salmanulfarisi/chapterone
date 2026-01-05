import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

// Genres provider
final genresProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  try {
    final response = await apiService.get('${ApiConstants.mangaList}/genres');
    final List<dynamic> data = response.data is List ? response.data : [];
    return data.cast<String>();
  } catch (e) {
    Logger.error('Failed to fetch genres', e, null, 'GenresProvider');
    return [];
  }
});
