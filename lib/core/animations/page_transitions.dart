import 'package:flutter/material.dart';

/// Custom page transition animations
class CustomPageTransitions {
  /// Slide transition from right (default for forward navigation)
  static PageTransitionsTheme slideFromRight = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CustomSlidePageTransitionBuilder(),
      TargetPlatform.iOS: CustomSlidePageTransitionBuilder(),
    },
  );

  /// Fade transition
  static PageTransitionsTheme fade = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CustomFadePageTransitionBuilder(),
      TargetPlatform.iOS: CustomFadePageTransitionBuilder(),
    },
  );

  /// Scale transition
  static PageTransitionsTheme scale = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CustomScalePageTransitionBuilder(),
      TargetPlatform.iOS: CustomScalePageTransitionBuilder(),
    },
  );
}

/// Custom slide page transition builder
class CustomSlidePageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOutCubic;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Custom fade page transition builder
class CustomFadePageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}

/// Custom scale page transition builder
class CustomScalePageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Hero-style transition for manga cards
class HeroMangaTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
