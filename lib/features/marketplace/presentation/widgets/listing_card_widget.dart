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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                      (constraints.maxWidth / 1.5).clamp(104.0, 148.0);
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
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.2,
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