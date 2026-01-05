import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

class ShimmerMangaCard extends StatelessWidget {
  const ShimmerMangaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.cardBackground,
      highlightColor: AppTheme.cardBackground.withOpacity(0.5),
      child: Container(
        width: 160,
        height: 240,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ShimmerMangaList extends StatelessWidget {
  final int itemCount;

  const ShimmerMangaList({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: ShimmerMangaCard(),
          );
        },
      ),
    );
  }
}

class ShimmerText extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerText({
    super.key,
    this.width = double.infinity,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.cardBackground,
      highlightColor: AppTheme.cardBackground.withOpacity(0.5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class ShimmerBanner extends StatelessWidget {
  const ShimmerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.cardBackground,
      highlightColor: AppTheme.cardBackground.withOpacity(0.5),
      child: Container(
        height: 400,
        width: double.infinity,
        decoration: const BoxDecoration(color: AppTheme.cardBackground),
      ),
    );
  }
}
