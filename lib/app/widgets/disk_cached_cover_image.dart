import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/cache/cover_image_disk_cache.dart';

class DiskCachedCoverImage extends StatefulWidget {
  const DiskCachedCoverImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String? imageUrl;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  State<DiskCachedCoverImage> createState() => _DiskCachedCoverImageState();
}

class _DiskCachedCoverImageState extends State<DiskCachedCoverImage> {
  File? _imageFile;
  bool _isResolving = false;
  String _resolvedUrl = '';

  @override
  void initState() {
    super.initState();
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(covariant DiskCachedCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.imageUrl ?? '').trim() != (widget.imageUrl ?? '').trim()) {
      _scheduleResolve();
    }
  }

  void _scheduleResolve() {
    final normalizedUrl = (widget.imageUrl ?? '').trim();
    _resolvedUrl = normalizedUrl;

    if (normalizedUrl.isEmpty) {
      if (_imageFile != null || _isResolving) {
        setState(() {
          _imageFile = null;
          _isResolving = false;
        });
      }
      return;
    }

    setState(() {
      _isResolving = true;
      _imageFile = null;
    });

    unawaited(_resolveCover(normalizedUrl));
  }

  Future<void> _resolveCover(String normalizedUrl) async {
    final file = await CoverImageDiskCache.instance.resolve(normalizedUrl);
    if (!mounted || _resolvedUrl != normalizedUrl) {
      return;
    }

    setState(() {
      _isResolving = false;
      _imageFile = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = (widget.imageUrl ?? '').trim();
    if (normalizedUrl.isEmpty) {
      return widget.fallback;
    }

    final file = _imageFile;
    if (file != null) {
      return Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: (_, __, ___) => widget.fallback,
      );
    }

    if (_isResolving) {
      return widget.fallback;
    }

    return Image.network(
      normalizedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      loadingBuilder: (_, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return widget.fallback;
      },
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
