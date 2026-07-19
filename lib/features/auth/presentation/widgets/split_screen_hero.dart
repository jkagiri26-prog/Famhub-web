/// ============================================================
/// SPLIT SCREEN HERO — Premium hero layout for FAMHUB
/// ============================================================
///
/// 🎯 PURPOSE:
///   Creates an investor-ready, premium split-screen hero section:
///   - Left side (30%): Static welcome panel with value proposition
///   - Right side (70%): Auto-sliding carousel with targeted messaging
///     for farmers, traders, suppliers, and stakeholders
///
/// ✅ Behavior:
///   - Autoplay every 4–5 seconds
///   - Pause on hover
///   - Manual navigation with arrows and indicators
///   - Text overlay with fade-in animation per slide
///   - Always horizontal split (30/70) even on mobile — content adapts to fit
///   - On very narrow screens (<480px), reduces padding, font sizes, and spacing
/// ============================================================
library famhub_app.features.auth.presentation.widgets.split_screen_hero;

import 'dart:async';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// DATA MODELS
/// ─────────────────────────────────────────────────────────────

/// Data for each carousel slide
class _CarouselSlide {
  final String headline;
  final String subtext;
  final String ctaText;
  final String imagePath;
  final Color accentColor;

  const _CarouselSlide({
    required this.headline,
    required this.subtext,
    required this.ctaText,
    required this.imagePath,
    required this.accentColor,
  });
}

/// All four carousel slides
const List<_CarouselSlide> _slides = [
  _CarouselSlide(
    headline: 'Grow Smarter, Harvest Better',
    subtext:
        'Manage your farm, track crops, access market prices, and improve productivity with FAMHUB.',
    ctaText: 'Explore Farm Management',
    imagePath: 'assets/images/farm1.png',
    accentColor: Color(0xFF22C55E),
  ),
  _CarouselSlide(
    headline: 'Connect Directly with Farmers',
    subtext:
        'Buy and sell agricultural products faster through FAMHUB\'s trusted marketplace.',
    ctaText: 'Visit Marketplace',
    imagePath: 'assets/images/farm2.png',
    accentColor: Color(0xFFF59E0B),
  ),
  _CarouselSlide(
    headline: 'Reach Thousands of Farmers',
    subtext:
        'Showcase your products and grow your agricultural business with FAMHUB.',
    ctaText: 'Become a Supplier',
    imagePath: 'assets/images/farm3.png',
    accentColor: Color(0xFF3B82F6),
  ),
  _CarouselSlide(
    headline: 'Empower Kenya\'s Agriculture',
    subtext:
        'Support farmers through finance, logistics, knowledge, and extension services.',
    ctaText: 'Partner with FAMHUB',
    imagePath: 'assets/images/farm1.png',
    accentColor: Color(0xFF8B5CF6),
  ),
];

/// ─────────────────────────────────────────────────────────────
/// SPLIT SCREEN HERO WIDGET
/// ─────────────────────────────────────────────────────────────

class SplitScreenHero extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onExploreAsGuest;

  const SplitScreenHero({
    super.key,
    required this.onGetStarted,
    required this.onExploreAsGuest,
  });

  @override
  State<SplitScreenHero> createState() => _SplitScreenHeroState();
}

class _SplitScreenHeroState extends State<SplitScreenHero> {
  late final PageController _pageController;
  late Timer _autoPlayTimer;
  int _currentPage = 0;
  bool _isHovering = false;

  // FAMHUB brand colors
  static const _brandGreen = Color(0xFF059669);
  static const _darkGreen = Color(0xFF047857);
  static const _deepGreen = Color(0xFF065F46);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isHovering && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goNext() {
    final next = (_currentPage + 1) % _slides.length;
    _goToPage(next);
  }

  void _goPrevious() {
    final prev = (_currentPage - 1 + _slides.length) % _slides.length;
    _goToPage(prev);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    
    // Always use horizontal split (30/70) on all screen sizes
    // On very narrow screens (<480px), content adapts via smaller text
    return _buildSplitLayout(size, screenWidth);
  }

  /// ── SPLIT LAYOUT (Always horizontal: 30% + 70%) ──
  /// Adapts spacing, font sizes, and padding for narrower screens
  /// while maintaining the side-by-side layout at all widths.
  Widget _buildSplitLayout(Size size, double screenWidth) {
    // Determine if we're on a compact/narrow screen
    final isCompact = screenWidth < 480;
    final isTablet = screenWidth >= 480 && screenWidth < 768;
    final isDesktop = screenWidth >= 768;
    
    // Left panel width: 30% on desktop, 35% on tablet, 40% on compact
    final leftFraction = isCompact ? 0.40 : (isTablet ? 0.35 : 0.30);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // ── LEFT PANEL: Static Welcome ──
              SizedBox(
                width: constraints.maxWidth * leftFraction,
                height: constraints.maxHeight,
                child: _buildLeftPanel(
                  constraints.maxHeight,
                  isCompact: isCompact,
                ),
              ),

              // ── DIVIDER: Tilted middle border ──
              _buildDivider(constraints.maxHeight),

              // ── RIGHT PANEL: Carousel ──
              Expanded(
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _buildRightPanel(constraints.maxHeight),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ── LEFT PANEL (All screen sizes) ──
  /// Adapts padding, font sizes, and spacing based on [isCompact].
  Widget _buildLeftPanel(double height, {bool isCompact = false}) {
    // Responsive values
    final hPadding = isCompact ? 16.0 : 32.0;
    final logoSize = isCompact ? 28.0 : 36.0;
    final headlineSize = isCompact ? 20.0 : (height < 500 ? 24.0 : 32.0);
    final subtextSize = isCompact ? 11.0 : 13.5;
    final buttonPadding = isCompact ? 12.0 : 16.0;
    final buttonFontSize = isCompact ? 13.0 : 16.0;
    final guestFontSize = isCompact ? 11.0 : 14.0;
    final gapLogoHeadline = isCompact ? 16.0 : 32.0;
    final gapHeadlineSubtext = isCompact ? 10.0 : 20.0;
    final gapSubtextButton = isCompact ? 16.0 : 32.0;
    final gapButtonGuest = isCompact ? 10.0 : 16.0;
    final bottomAccentWidth = isCompact ? 40.0 : 60.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _deepGreen,
            _brandGreen,
            _darkGreen,
            _deepGreen,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // ── FAMHUB Logo ──
              _buildLogo(logoSize: logoSize),

              SizedBox(height: gapLogoHeadline),

              // ── Headline ──
              Text(
                'Welcome to\nFAMHUB',
                style: TextStyle(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),

              SizedBox(height: gapHeadlineSubtext),

              // ── Subheadline ──
              Text(
                'Kenya\'s digital agriculture platform connecting farmers, traders, suppliers, financiers, and stakeholders to grow together.',
                style: TextStyle(
                  fontSize: subtextSize,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: gapSubtextButton),

              // ── CTA Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onGetStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandGreen,
                    padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapButtonGuest),

              // ── Secondary Link ──
              Center(
                child: GestureDetector(
                  onTap: widget.onExploreAsGuest,
                  child: Text(
                    'Explore as Guest',
                    style: TextStyle(
                      fontSize: guestFontSize,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Bottom accent ──
              Container(
                height: 3,
                width: bottomAccentWidth,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// ── DIVIDER: Tilted middle border ──
  Widget _buildDivider(double height) {
    return ClipPath(
      clipper: _TiltedDividerClipper(),
      child: Container(
        width: 28,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ── RIGHT PANEL: Carousel ──
  Widget _buildRightPanel(double height) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          // ── PageView ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return _CarouselSlideWidget(
                slide: _slides[index],
                isActive: index == _currentPage,
              );
            },
          ),

          // ── Navigation Arrows (visible on hover) ──
          AnimatedOpacity(
            opacity: _isHovering ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _buildNavigationArrows(height),
          ),

          // ── Indicator Dots ──
          Positioned(
            bottom: 32,
            right: 32,
            child: _buildIndicatorDots(),
          ),
        ],
      ),
    );
  }

  /// ── Navigation Arrows ──
  Widget _buildNavigationArrows(double height) {
    return Stack(
      children: [
        // Left arrow
        Positioned(
          left: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: _goPrevious,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        // Right arrow
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: _goNext,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ── Indicator Dots ──
  Widget _buildIndicatorDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _currentPage;
        return GestureDetector(
          onTap: () => _goToPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
        );
      }),
    );
  }

  /// ── FAMHUB Logo ──
  Widget _buildLogo({double logoSize = 36}) {
    // Derive child sizes proportionally
    final iconContainer = logoSize;
    final iconSize = logoSize * 0.55;
    final fontSize = logoSize * 0.5;
    final spacing = logoSize * 0.28;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconContainer,
          height: iconContainer,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.agriculture_rounded,
            size: iconSize,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        SizedBox(width: spacing),
        Text(
          'FAMHUB',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// CAROUSEL SLIDE WIDGET
/// ─────────────────────────────────────────────────────────────

class _CarouselSlideWidget extends StatefulWidget {
  final _CarouselSlide slide;
  final bool isActive;

  const _CarouselSlideWidget({
    required this.slide,
    required this.isActive,
  });

  @override
  State<_CarouselSlideWidget> createState() => _CarouselSlideWidgetState();
}

class _CarouselSlideWidgetState extends State<_CarouselSlideWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeInHeadline;
  late Animation<double> _fadeInSubtext;
  late Animation<double> _fadeInCta;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeInHeadline = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _fadeInSubtext = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );

    _fadeInCta = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_CarouselSlideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;

    // Start animation when active
    if (widget.isActive && !_animController.isAnimating) {
      // Use post-frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_animController.isCompleted) {
          _animController.forward(from: 0.0);
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background Image ──
        _buildBackgroundImage(slide.imagePath),

        // ── Dark Gradient Overlay (40–50%) ──
        _buildGradientOverlay(),

        // ── Text Content (lower-left, cinematic) ──
        _buildTextContent(slide),
      ],
    );
  }

  Widget _buildBackgroundImage(String imagePath) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        // Fallback gradient if image fails
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _brandGreen.withValues(alpha: 0.8),
                _deepGreen,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.15),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.75),
          ],
          stops: const [0.0, 0.3, 0.55, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildTextContent(_CarouselSlide slide) {
    return Positioned(
      left: 40,
      right: 40,
      bottom: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Slide Label ──
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeTransition(
              opacity: _fadeInHeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: slide.accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: slide.accentColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getSlideLabel(slide),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slide.accentColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // ── Headline ──
          FadeTransition(
            opacity: _fadeInHeadline,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - _fadeInHeadline.value)),
              child: Text(
                slide.headline,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Subtext ──
          FadeTransition(
            opacity: _fadeInSubtext,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - _fadeInSubtext.value)),
              child: Text(
                slide.subtext,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── CTA Button ──
          FadeTransition(
            opacity: _fadeInCta,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - _fadeInCta.value)),
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(slide.ctaText),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSlideLabel(_CarouselSlide slide) {
    if (slide.ctaText.contains('Farm')) return 'FOR FARMERS';
    if (slide.ctaText.contains('Market')) return 'FOR TRADERS';
    if (slide.ctaText.contains('Supplier')) return 'FOR SUPPLIERS';
    if (slide.ctaText.contains('Partner')) return 'FOR STAKEHOLDERS';
    return '';
  }
}

/// ─────────────────────────────────────────────────────────────
/// TILTED DIVIDER CLIPPER
/// ─────────────────────────────────────────────────────────────

class _TiltedDividerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height * 0.02);
    path.lineTo(size.width, size.height * 0.98);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Brand green ref for internal use
const Color _brandGreen = Color(0xFF059669);
const Color _deepGreen = Color(0xFF065F46);
const Color _darkGreen = Color(0xFF047857);
