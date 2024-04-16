import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:octo_image/octo_image.dart';

import '../models/jellyfin_models.dart';
import '../services/album_image_provider.dart';

typedef ImageProviderCallback = void Function(ImageProvider? imageProvider);

/// This widget provides the default look for album images throughout Finamp -
/// Aspect ratio 1 with a circular border radius of 4. If you don't want these
/// customisations, use [BareAlbumImage] or get an [ImageProvider] directly
/// through [AlbumImageProvider.init].
class AlbumImage extends ConsumerWidget {
  const AlbumImage({
    Key? key,
    this.item,
    this.imageListenable,
    this.imageProviderCallback,
    this.borderRadius,
    this.placeholderBuilder,
    this.disabled = false,
    this.autoScale = true,
  }) : super(key: key);

  /// The item to get an image for.
  final BaseItemDto? item;

  final ProviderListenable<AsyncValue<ImageProvider?>>? imageListenable;

  /// A callback to get the image provider once it has been fetched.
  final ImageProviderCallback? imageProviderCallback;

  final BorderRadius? borderRadius;

  final WidgetBuilder? placeholderBuilder;

  final bool disabled;

  /// Whether to automatically scale the image to the size of the widget.
  final bool autoScale;

  static final defaultBorderRadius = BorderRadius.circular(4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = this.borderRadius ?? defaultBorderRadius;

    assert(item == null || imageListenable == null);
    if ((item == null || item!.imageId == null) && imageListenable == null) {
      if (imageProviderCallback != null) {
        imageProviderCallback!(null);
      }

      return ClipRRect(
        borderRadius: borderRadius,
        child: const AspectRatio(
          aspectRatio: 1,
          child: _AlbumImageErrorPlaceholder(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          int? physicalWidth;
          int? physicalHeight;
          if (autoScale) {
            // LayoutBuilder (and other pixel-related stuff in Flutter) returns logical pixels instead of physical pixels.
            // While this is great for doing layout stuff, we want to get images that are the right size in pixels.
            // Logical pixels aren't the same as the physical pixels on the device, they're quite a bit bigger.
            // If we use logical pixels for the image request, we'll get a smaller image than we want.
            // Because of this, we convert the logical pixels to physical pixels by multiplying by the device's DPI.
            final MediaQueryData mediaQuery = MediaQuery.of(context);
            physicalWidth =
                (constraints.maxWidth * mediaQuery.devicePixelRatio).toInt();
            physicalHeight =
                (constraints.maxHeight * mediaQuery.devicePixelRatio).toInt();
          }

          var image = BareAlbumImage(
            imageListenable: imageListenable ??
                albumImageProvider(AlbumImageRequest(
                  item: item!,
                  maxWidth: physicalWidth,
                  maxHeight: physicalHeight,
                )),
            imageProviderCallback: imageProviderCallback,
            placeholderBuilder:
                placeholderBuilder ?? BareAlbumImage.defaultPlaceholderBuilder,
          );
          return disabled
              ? Opacity(
                  opacity: 0.75,
                  child: ColorFiltered(
                      colorFilter:
                          const ColorFilter.mode(Colors.black, BlendMode.color),
                      child: image))
              : image;
        }),
      ),
    );
  }
}

/// An [AlbumImage] without any of the padding or media size detection.
class BareAlbumImage extends ConsumerStatefulWidget {
  const BareAlbumImage({
    Key? key,
    required this.imageListenable,
    this.imageProviderCallback,
    this.errorBuilder = defaultErrorBuilder,
    this.placeholderBuilder = defaultPlaceholderBuilder,
  }) : super(key: key);

  final ProviderListenable<AsyncValue<ImageProvider?>> imageListenable;
  final WidgetBuilder placeholderBuilder;
  final OctoErrorBuilder errorBuilder;
  final ImageProviderCallback? imageProviderCallback;

  static Widget defaultPlaceholderBuilder(BuildContext context) {
    return Container(color: Theme.of(context).cardColor);
  }

  static Widget defaultErrorBuilder(BuildContext context, _, __) {
    return const _AlbumImageErrorPlaceholder();
  }

  @override
  ConsumerState<BareAlbumImage> createState() => _BareAlbumImageState();
}

class _BareAlbumImageState extends ConsumerState<BareAlbumImage> {
  @override
  Widget build(BuildContext context) {
    AsyncValue<ImageProvider?> image = ref.watch(widget.imageListenable);

    if (image.hasValue && image.value != null) {
      if (widget.imageProviderCallback != null) {
        widget.imageProviderCallback!(image.value);
      }

      return OctoImage(
        image: ScrollAwareImageProvider(
            context: DisposableBuildContext(this), imageProvider: image.value!),
        fit: BoxFit.contain,
        placeholderBuilder: widget.placeholderBuilder,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (image.hasError) {
      if (widget.imageProviderCallback != null) {
        widget.imageProviderCallback!(null);
      }
      return const _AlbumImageErrorPlaceholder();
    }

    if (widget.imageProviderCallback != null) {
      widget.imageProviderCallback!(null);
    }

    return Builder(builder: widget.placeholderBuilder);
  }
}

class _AlbumImageErrorPlaceholder extends StatelessWidget {
  const _AlbumImageErrorPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: const Icon(Icons.album),
    );
  }
}
