import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/utils/logger.dart';
import '../../services/backend/backend_health_service.dart';
import '../../services/connectivity/connectivity_service.dart';
import '../../features/manga/providers/manga_provider.dart';
import '../../features/manga/providers/genres_provider.dart';
import '../../features/manga/providers/recommendations_provider.dart';
import '../../services/api/api_service.dart';
import '../../services/storage/storage_service.dart';
import '../../core/constants/api_constants.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _loadingAnimationController;
  late AnimationController _textAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _textFadeAnimation;

  String _loadingText = 'Initializing...';
  double _loadingProgress = 0.0;
  bool _backendOnline = false;
  bool _dbOnline = false;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Loading animation controller (for spinner)
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Text fade animation controller
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward(); // Start with text visible

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.linear,
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoAnimationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Check connectivity
      _updateLoading('Checking internet connection...', 0.05);
      await Future.delayed(const Duration(milliseconds: 400));

      final connectivityState = ref.read(connectivityProvider);
      if (!connectivityState.isConnected) {
        _updateLoading('No internet connection detected', 0.0);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/no-internet');
        }
        return;
      }

      // Step 2: Check backend health with detailed status
      _updateLoading('Connecting to server...', 0.15);
      final backendHealth = ref.read(backendHealthProvider.notifier);
      final backendOnline = await backendHealth.checkHealth().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          Logger.warning('Backend health check timed out', 'SplashScreen');
          return false;
        },
      );

      setState(() {
        _backendOnline = backendOnline;
      });

      if (!backendOnline) {
        _updateLoading('Server connection failed', 0.15);
        await Future.delayed(const Duration(seconds: 1));
        // Continue anyway - app can work with cached data
      } else {
        _updateLoading('Server connected successfully', 0.25);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Step 3: Check database connectivity (via a simple API call)
      _updateLoading('Verifying database connection...', 0.3);
      final dbOnline = await _checkDatabaseConnection();
      setState(() {
        _dbOnline = dbOnline;
      });

      if (!dbOnline && backendOnline) {
        _updateLoading('Database connection issue', 0.3);
        await Future.delayed(const Duration(milliseconds: 500));
      } else if (dbOnline) {
        _updateLoading('Database connected', 0.35);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Step 4: Pre-load initial content (only if backend and DB are online)
      if (backendOnline && dbOnline) {
        await _preloadContent();
      } else {
        _updateLoading('Using offline mode', 0.7);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 5: Wait for auth state
      _updateLoading('Loading user preferences...', 0.85);
      await Future.delayed(const Duration(milliseconds: 400));

      // Step 6: Complete
      _updateLoading('Almost ready...', 0.95);
      await Future.delayed(const Duration(milliseconds: 300));

      _updateLoading('Ready!', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 7: Navigate based on auth state and setup
      if (mounted) {
        final authState = ref.read(authProvider);

        // Check if user has completed setup (first time setup)
        final hasCompletedSetup =
            StorageService.getSetting<bool>('setup_completed') ?? false;

        if (!hasCompletedSetup) {
          // First time - go to setup
          context.go('/settings?setup=true');
        } else if (authState.isAuthenticated) {
          // User is logged in, navigate to home
          context.go('/home');
        } else {
          // User is not logged in, navigate to login
          context.go('/login');
        }
      }
    } catch (e) {
      Logger.error('Splash initialization error', e, null, 'SplashScreen');
      if (mounted) {
        // Try to navigate to setup or login as fallback
        final hasCompletedSetup =
            StorageService.getSetting<bool>('setup_completed') ?? false;
        if (!hasCompletedSetup) {
          context.go('/settings?setup=true');
        } else {
          context.go('/login');
        }
      }
    }
  }

  Future<bool> _checkDatabaseConnection() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      // Try a lightweight endpoint that requires DB access
      // Using genres endpoint as it's fast and requires DB
      await apiService
          .get('${ApiConstants.mangaList}/genres')
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('Database check timed out');
            },
          );
      return true;
    } catch (e) {
      Logger.warning('Database check failed: $e', 'SplashScreen');
      return false;
    }
  }

  Future<void> _preloadContent() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final authState = ref.read(authProvider);

      _updateLoading('Preparing content...', 0.4);

      // Run all pre-loading in parallel with shorter timeouts
      // This way if one fails, others can still succeed
      final preloadFutures = <Future<void>>[];

      // Pre-load genres (essential for search and filtering)
      preloadFutures.add(
        ref
            .read(genresProvider.future)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning('Genres pre-load timed out', 'SplashScreen');
                throw TimeoutException('Genres timeout');
              },
            )
            .then((_) {
              Logger.info('Genres pre-loaded successfully', 'SplashScreen');
            })
            .catchError((e) {
              Logger.warning('Failed to pre-load genres: $e', 'SplashScreen');
            }),
      );

      // Pre-load featured manga (for home screen carousel)
      preloadFutures.add(
        apiService
            .get('${ApiConstants.mangaList}/featured')
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning('Featured pre-load timed out', 'SplashScreen');
                throw TimeoutException('Featured timeout');
              },
            )
            .then((_) {
              Logger.info(
                'Featured content pre-loaded successfully',
                'SplashScreen',
              );
            })
            .catchError((e) {
              Logger.warning('Failed to pre-load featured: $e', 'SplashScreen');
            }),
      );

      // Pre-load trending manga (reduced limit for faster loading)
      preloadFutures.add(
        ref
            .read(
              mangaListProvider(
                MangaListParams(limit: '10', sort: 'desc', sortBy: 'views'),
              ).future,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning(
                  'Trending manga pre-load timed out',
                  'SplashScreen',
                );
                throw TimeoutException('Trending timeout');
              },
            )
            .then((_) {
              Logger.info(
                'Trending manga pre-loaded successfully',
                'SplashScreen',
              );
            })
            .catchError((e) {
              Logger.warning(
                'Failed to pre-load trending manga: $e',
                'SplashScreen',
              );
            }),
      );

      // Pre-load popular manga (reduced limit)
      preloadFutures.add(
        ref
            .read(
              mangaListProvider(
                MangaListParams(limit: '10', sort: 'desc', sortBy: 'rating'),
              ).future,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning(
                  'Popular manga pre-load timed out',
                  'SplashScreen',
                );
                throw TimeoutException('Popular timeout');
              },
            )
            .then((_) {
              Logger.info(
                'Popular manga pre-loaded successfully',
                'SplashScreen',
              );
            })
            .catchError((e) {
              Logger.warning(
                'Failed to pre-load popular manga: $e',
                'SplashScreen',
              );
            }),
      );

      // Pre-load new releases (reduced limit)
      preloadFutures.add(
        ref
            .read(
              mangaListProvider(
                MangaListParams(limit: '10', sort: 'desc', sortBy: 'createdAt'),
              ).future,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                Logger.warning(
                  'New releases pre-load timed out',
                  'SplashScreen',
                );
                throw TimeoutException('New releases timeout');
              },
            )
            .then((_) {
              Logger.info(
                'New releases pre-loaded successfully',
                'SplashScreen',
              );
            })
            .catchError((e) {
              Logger.warning(
                'Failed to pre-load new releases: $e',
                'SplashScreen',
              );
            }),
      );

      // Pre-load recommendations and continue reading if authenticated
      if (authState.isAuthenticated) {
        preloadFutures.add(
          ref
              .read(recommendationsProvider.future)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Logger.warning(
                    'Recommendations pre-load timed out',
                    'SplashScreen',
                  );
                  throw TimeoutException('Recommendations timeout');
                },
              )
              .then((_) {
                Logger.info(
                  'Recommendations pre-loaded successfully',
                  'SplashScreen',
                );
              })
              .catchError((e) {
                Logger.warning(
                  'Failed to pre-load recommendations: $e',
                  'SplashScreen',
                );
              }),
        );

        preloadFutures.add(
          ref
              .read(continueReadingProvider.future)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Logger.warning(
                    'Continue reading pre-load timed out',
                    'SplashScreen',
                  );
                  throw TimeoutException('Continue reading timeout');
                },
              )
              .then((_) {
                Logger.info(
                  'Continue reading pre-loaded successfully',
                  'SplashScreen',
                );
              })
              .catchError((e) {
                Logger.warning(
                  'Failed to pre-load continue reading: $e',
                  'SplashScreen',
                );
              }),
        );
      }

      // Wait for all pre-loads with a maximum total timeout
      // This ensures we don't wait forever, but still allow parallel loading
      _updateLoading('Loading content...', 0.5);
      try {
        await Future.wait(
          preloadFutures,
          eagerError: false, // Don't stop on first error
        ).timeout(
          const Duration(
            seconds: 15,
          ), // Maximum 15 seconds for all parallel loads
        );
      } on TimeoutException {
        Logger.warning(
          'Some content pre-loads timed out, continuing anyway',
          'SplashScreen',
        );
      }

      _updateLoading('Content ready', 0.7);
    } catch (e) {
      // Don't block app startup if pre-loading fails
      Logger.warning(
        'Some pre-loads failed, continuing anyway: $e',
        'SplashScreen',
      );
    }
  }

  void _updateLoading(String text, double progress) {
    if (mounted) {
      // Fade out current text
      _textAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _loadingText = text;
            _loadingProgress = progress;
          });
          // Fade in new text
          _textAnimationController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _loadingAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.darkerBackground, AppTheme.darkBackground],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // App Name
                      const Text(
                        'ChapterOne',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your Manga Reader',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 64),

              // Loading animation with progress
              Column(
                children: [
                  // Animated spinner with pulsing effect
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryRed.withOpacity(0.2),
                            AppTheme.primaryRed.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryRed.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          // Inner spinner
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Loading text with fade animation
                  SizedBox(
                    height: 24,
                    child: AnimatedBuilder(
                      animation: _textFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textFadeAnimation.value,
                          child: Text(
                            _loadingText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Enhanced progress bar with animation
                  Container(
                    width: 250,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _loadingProgress),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryRed,
                                    AppTheme.primaryRed.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryRed.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Progress percentage
                  Text(
                    '${(_loadingProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Status indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Backend status
                      _buildStatusIndicator(
                        'Backend',
                        _backendOnline,
                        Icons.cloud,
                      ),
                      const SizedBox(width: 24),
                      // Database status
                      _buildStatusIndicator(
                        'Database',
                        _dbOnline,
                        Icons.storage,
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

  Widget _buildStatusIndicator(String label, bool isOnline, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.check_circle : Icons.error_outline,
          color: isOnline ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              isOnline ? 'Online' : 'Checking...',
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
