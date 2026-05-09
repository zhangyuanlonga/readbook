import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/reader_image_decode_budget.dart';

typedef ReaderImageRetryCallback = void Function(ReaderImageRetryAction action);

class ReaderImagePipeline {
  const ReaderImagePipeline();

  ReaderImagePipelineRequest resolveRequest({
    required String sourceUrl,
    int retryNonce = 0,
  }) {
    return ReaderImagePipelineRequest(
      sourceUrl: sourceUrl,
      requestUrl: buildRequestUrl(imageUrl: sourceUrl, retryNonce: retryNonce),
      retryNonce: retryNonce,
    );
  }

  String buildRequestUrl({required String imageUrl, required int retryNonce}) {
    if (retryNonce <= 0 || imageUrl.startsWith('data:image/')) {
      return imageUrl;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.scheme == 'file') {
      return imageUrl;
    }

    final updatedParameters = Map<String, String>.from(uri.queryParameters)
      ..['retry'] = '$retryNonce';
    return uri.replace(queryParameters: updatedParameters).toString();
  }

  Widget buildReaderImageWidget({
    Key? key,
    required ReaderImagePipelineRequest request,
    required ReaderImagePipelinePalette palette,
    Map<String, String> headers = const <String, String>{},
    FilterQuality filterQuality = FilterQuality.medium,
    BoxFit fit = BoxFit.fitWidth,
    double placeholderAspectRatio = 3 / 4,
    String retryLabel = '图片加载失败，点击重试',
    ReaderImageRetryCallback? onRetry,
    ReaderImageDecodeBudget? decodeBudget,
  }) {
    final requestUrl = request.requestUrl;
    final uri = Uri.tryParse(requestUrl);
    if (isSvgImageUrl(requestUrl)) {
      return buildSvgImageWidget(
        key: key,
        request: request,
        palette: palette,
        headers: headers,
        fit: fit,
        placeholderAspectRatio: placeholderAspectRatio,
        retryLabel: retryLabel,
        onRetry: onRetry,
      );
    }
    if (requestUrl.startsWith('data:image/')) {
      return buildDataUriImage(
        key: key,
        request: request,
        palette: palette,
        filterQuality: filterQuality,
        fit: fit,
        placeholderAspectRatio: placeholderAspectRatio,
        retryLabel: retryLabel,
        onRetry: onRetry,
        decodeBudget: decodeBudget,
      );
    }
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        key: key,
        fit: fit,
        filterQuality: filterQuality,
        cacheWidth: decodeBudget?.cacheWidth,
        cacheHeight: decodeBudget?.cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          return buildImageErrorWidget(
            request: request,
            palette: palette,
            retryLabel: retryLabel,
            placeholderAspectRatio: placeholderAspectRatio,
            onRetry: onRetry,
          );
        },
      );
    }

    return Image.network(
      requestUrl,
      key: key,
      headers: headers.isEmpty ? null : headers,
      fit: fit,
      filterQuality: filterQuality,
      cacheWidth: decodeBudget?.cacheWidth,
      cacheHeight: decodeBudget?.cacheHeight,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return buildLoadingPlaceholder(
          color: palette.meta,
          aspectRatio: placeholderAspectRatio,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return buildImageErrorWidget(
          request: request,
          palette: palette,
          retryLabel: retryLabel,
          placeholderAspectRatio: placeholderAspectRatio,
          onRetry: onRetry,
        );
      },
    );
  }

  bool isSvgImageUrl(String imageUrl) {
    if (imageUrl.startsWith('data:image/svg+xml')) {
      return true;
    }
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path.toLowerCase() ?? imageUrl.toLowerCase();
    return path.endsWith('.svg') || path.endsWith('.svgz');
  }

  Widget buildSvgImageWidget({
    Key? key,
    required ReaderImagePipelineRequest request,
    required ReaderImagePipelinePalette palette,
    Map<String, String> headers = const <String, String>{},
    BoxFit fit = BoxFit.fitWidth,
    double placeholderAspectRatio = 3 / 4,
    String retryLabel = '图片加载失败，点击重试',
    ReaderImageRetryCallback? onRetry,
  }) {
    final requestUrl = request.requestUrl;
    final uri = Uri.tryParse(requestUrl);

    Widget placeholderBuilder(BuildContext context) {
      return buildLoadingPlaceholder(
        color: palette.meta,
        aspectRatio: placeholderAspectRatio,
      );
    }

    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      return buildImageErrorWidget(
        request: request,
        palette: palette,
        retryLabel: retryLabel,
        placeholderAspectRatio: placeholderAspectRatio,
        onRetry: onRetry,
      );
    }

    try {
      if (requestUrl.startsWith('data:image/svg+xml')) {
        final decoded = decodeDataUriImage(dataUri: requestUrl);
        if (decoded == null) {
          throw const FormatException('Invalid SVG data URI');
        }
        return SvgPicture.string(
          decoded.text,
          key: key,
          fit: fit,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: errorBuilder,
        );
      }
      if (uri != null && uri.scheme == 'file') {
        return SvgPicture.file(
          File.fromUri(uri),
          key: key,
          fit: fit,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: errorBuilder,
        );
      }
      return SvgPicture.network(
        requestUrl,
        key: key,
        headers: headers.isEmpty ? null : headers,
        fit: fit,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      );
    } catch (_) {
      return buildImageErrorWidget(
        request: request,
        palette: palette,
        retryLabel: retryLabel,
        placeholderAspectRatio: placeholderAspectRatio,
        onRetry: onRetry,
      );
    }
  }

  Widget buildDataUriImage({
    Key? key,
    required ReaderImagePipelineRequest request,
    required ReaderImagePipelinePalette palette,
    FilterQuality filterQuality = FilterQuality.medium,
    BoxFit fit = BoxFit.fitWidth,
    double placeholderAspectRatio = 3 / 4,
    String retryLabel = '图片加载失败，点击重试',
    ReaderImageRetryCallback? onRetry,
    ReaderImageDecodeBudget? decodeBudget,
  }) {
    try {
      final decoded = decodeDataUriImage(
        dataUri: request.requestUrl,
        maxBytes: decodeBudget?.maxDataUriBytes,
      );
      if (decoded == null) {
        throw const FormatException('Invalid data URI');
      }
      return Image.memory(
        decoded.bytes,
        key: key,
        fit: fit,
        filterQuality: filterQuality,
        cacheWidth: decodeBudget?.cacheWidth,
        cacheHeight: decodeBudget?.cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          return buildImageErrorWidget(
            request: request,
            palette: palette,
            retryLabel: retryLabel,
            placeholderAspectRatio: placeholderAspectRatio,
            onRetry: onRetry,
          );
        },
      );
    } catch (_) {
      return buildImageErrorWidget(
        request: request,
        palette: palette,
        retryLabel: retryLabel,
        placeholderAspectRatio: placeholderAspectRatio,
        onRetry: onRetry,
      );
    }
  }

  ReaderDecodedDataUriImage? decodeDataUriImage({
    required String dataUri,
    int? maxBytes,
  }) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex <= 0 || !dataUri.startsWith('data:')) {
      return null;
    }
    final metadata = dataUri.substring(5, commaIndex);
    final encoded = dataUri.substring(commaIndex + 1);
    final isBase64 = metadata.toLowerCase().contains(';base64');
    final mediaType = metadata.split(';').first.trim().toLowerCase();
    final bytes =
        isBase64
            ? base64Decode(encoded)
            : Uint8List.fromList(utf8.encode(Uri.decodeComponent(encoded)));
    if (maxBytes != null && maxBytes >= 0 && bytes.length > maxBytes) {
      return null;
    }
    return ReaderDecodedDataUriImage(
      mediaType: mediaType,
      bytes: bytes,
      text: utf8.decode(bytes, allowMalformed: true),
    );
  }

  Widget buildImageErrorWidget({
    Key? key,
    required ReaderImagePipelineRequest request,
    required ReaderImagePipelinePalette palette,
    double placeholderAspectRatio = 3 / 4,
    String retryLabel = '图片加载失败，点击重试',
    ReaderImageRetryCallback? onRetry,
  }) {
    return AspectRatio(
      key: key,
      aspectRatio: placeholderAspectRatio,
      child: InkWell(
        onTap: onRetry == null ? null : () => onRetry(request.toRetryAction()),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              retryLabel,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.meta),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoadingPlaceholder({
    required Color color,
    double aspectRatio = 3 / 4,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
    );
  }
}

class ReaderImagePipelineRequest {
  const ReaderImagePipelineRequest({
    required this.sourceUrl,
    required this.requestUrl,
    required this.retryNonce,
  });

  final String sourceUrl;
  final String requestUrl;
  final int retryNonce;

  ReaderImageRetryAction toRetryAction() {
    return ReaderImageRetryAction(
      sourceUrl: sourceUrl,
      requestUrl: requestUrl,
      retryNonce: retryNonce,
    );
  }
}

class ReaderImageRetryAction {
  const ReaderImageRetryAction({
    required this.sourceUrl,
    required this.requestUrl,
    required this.retryNonce,
  });

  final String sourceUrl;
  final String requestUrl;
  final int retryNonce;

  int get nextRetryNonce => retryNonce + 1;
}

class ReaderImagePipelinePalette {
  const ReaderImagePipelinePalette({required this.meta});

  final Color meta;
}

class ReaderDecodedDataUriImage {
  const ReaderDecodedDataUriImage({
    required this.mediaType,
    required this.bytes,
    required this.text,
  });

  final String mediaType;
  final Uint8List bytes;
  final String text;
}
