import 'package:flutter/material.dart';

class ListingCardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String location;
  final String? imageUrl;
  final String? badge;
  final Widget? trailing;

  const ListingCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.location,
    this.imageUrl,
    this.badge,
    this.trailing,
  });

  /// Image area that renders only network-reachable http(s) references.
  ///
  /// Marketplace listing images are PRIVATE storage paths returned by the
  /// backend (e.g. `images/listings/<stock_id>/image1.jpeg`), not public
  /// URLs. Passing a raw storage path to `Image.network` can never resolve
  /// and would trigger a doomed network request. Until a private media
  /// retrieval mechanism resolves those paths into http(s) URLs, any
  /// non-http(s) / failed reference falls back to the shared placeholder.
  Widget _buildImageArea(double imageHeight) {
    final resolvedUrl = _networkSafeUrl(imageUrl);
    return SizedBox(
      width: double.infinity,
      height: imageHeight,
      child: resolvedUrl == null
          ? _placeholder()
          : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
    );
  }

  /// Returns [imageUrl] only when it is a fetchable network reference,
  /// otherwise null (private storage paths, relative refs, malformed values).
  String? _networkSafeUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return null;
    }
    return value;
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xfff1f5f2),
      child: Icon(
        Icons.agriculture_outlined,
        size: 38,
        color: Colors.green.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageHeight =
                      (constraints.maxWidth / 1.35).clamp(108.0, 152.0);
                  return SizedBox(
                    width: double.infinity,
                    height: imageHeight,
                    child: _buildImageArea(imageHeight),
                  );
                },
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1 — title · variant (compact, single line).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                height: 1.15,
                              ),
                            ),
                            if (subtitle.trim().isNotEmpty) ...[
                              const TextSpan(
                                text: '  ·  ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: subtitle.trim(),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                // Line 2 — price + unit.
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.15,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 3),
                // Line 3 — location.
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.15,
                        ),
                      ),
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