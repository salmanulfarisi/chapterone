import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connectivity/connectivity_service.dart';
import '../../services/offline/offline_service.dart';
import '../../widgets/custom_snackbar.dart';

class NoInternetScreen extends ConsumerStatefulWidget {
  const NoInternetScreen({super.key});

  @override
  ConsumerState<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends ConsumerState<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;

  final List<String> _funnyMessages = [
    "Oops! The internet went on a coffee break ☕",
    "Your WiFi is taking a nap 😴",
    "The internet is playing hide and seek 🫥",
    "Connection lost! Even the best need a break 🏖️",
    "No signal? Time to touch some grass 🌱",
    "The internet is having an existential crisis 🤔",
    "404: Internet not found 🚫",
    "Your connection is more lost than my keys 🔑",
    "The WiFi fairy is on strike ✨",
    "Internet.exe has stopped working 💻",
  ];

  String _currentMessage = "";

  @override
  void initState() {
    super.initState();
    _currentMessage = _funnyMessages[0];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Change message every 3 seconds
    _startMessageRotation();
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentMessage =
              _funnyMessages[(_funnyMessages.indexOf(_currentMessage) + 1) %
                  _funnyMessages.length];
        });
        _startMessageRotation();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final connectivityNotifier = ref.read(connectivityProvider.notifier);
    final isConnected = await connectivityNotifier.checkConnection();

    if (isConnected && mounted) {
      CustomSnackbar.success(context, 'Internet connection restored!');
      // Navigate back or to home using GoRouter
      try {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      } catch (e) {
        // Fallback if GoRouter is not available
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } else if (mounted) {
      CustomSnackbar.error(context, 'Still no internet connection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityState = ref.watch(connectivityProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.darkerBackground, AppTheme.darkBackground],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),

                  // Animated WiFi Icon
                  AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _bounceAnimation.value),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off,
                            size: 60,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Funny Message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      _currentMessage,
                      key: ValueKey(_currentMessage),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'Check your internet connection and try again',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: connectivityState.isConnected
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          connectivityState.isConnected
                              ? 'Connected'
                              : 'Disconnected',
                          style: TextStyle(
                            color: connectivityState.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Retry Button
                  ElevatedButton.icon(
                    onPressed: _checkConnection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tips Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.primaryRed,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Quick Tips',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTip('Check your WiFi or mobile data'),
                        _buildTip('Restart your router'),
                        _buildTip('Move to a better signal area'),
                        _buildTip('Check if airplane mode is off'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Offline Mode Button
                  FutureBuilder<List<String>>(
                    future: Future.value(OfflineService.instance.getCachedChapters()),
                    builder: (context, snapshot) {
                      final cachedCount = snapshot.data?.length ?? 0;
                      if (cachedCount == 0) {
                        return const SizedBox.shrink();
                      }

                      return TextButton.icon(
                        onPressed: () {
                          // Show info about cached chapters
                          // Note: Offline content screen not yet implemented
                          CustomSnackbar.info(
                            context,
                            'You have $cachedCount cached chapters available offline',
                          );
                        },
                        icon: const Icon(Icons.download_done),
                        label: Text('Browse $cachedCount Cached Chapters'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryRed,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
