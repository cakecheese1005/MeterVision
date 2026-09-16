import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Renders a locally captured meter photo.
///
/// Two things this handles that a bare `Image.file` does not:
///
///  * **Web.** `camera` and `image_picker` hand back a blob: URL on web rather
///    than a filesystem path, so it has to go through `Image.network`.
///    (Previously this pulled the blob down with a raw Dio call, which meant
///    a widget imported the HTTP client - the one place in the app that
///    reached past the ApiClient boundary.)
///
///  * **Missing files.** A queued draft can outlive its image: Android may
///    evict the camera plugin's cache directory under storage pressure, and
///    the app can be reinstalled. Without an errorBuilder that surfaces as a
///    grey box with an exception in the console; here it says plainly that the
///    photo is gone, which is what the officer needs to know before the sync
///    queue tells them the upload failed.
class CapturedImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;

  const CapturedImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.isEmpty) return const _MissingImage();

    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, _, _) => const _MissingImage(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    return Image.file(
      File(imagePath),
      fit: fit,
      errorBuilder: (_, _, _) => const _MissingImage(),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 28, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            'Photo unavailable',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
