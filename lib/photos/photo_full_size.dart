import 'package:binks/main.dart';
import 'package:binks/photos/photo_preview.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

typedef AnimationListener = void Function();

class PhotoFullSize extends StatefulWidget {
  final Photo photo;

  const PhotoFullSize({Key? key, required this.photo}) : super(key: key);

  @override
  _PhotoFullSizeState createState() => _PhotoFullSizeState();
}

class _PhotoFullSizeState extends State<PhotoFullSize> with TickerProviderStateMixin {
  Animation<double>? _doubleClickAnimation;
  late AnimationListener _doubleClickAnimationListener;
  late AnimationController _doubleClickAnimationController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);

  @override
  void dispose() {
    _doubleClickAnimationController.dispose();
    super.dispose();
  }

  Future<File?> getLocalImage(int id) async {
    var asset = await PhotoManager.refreshAssetProperties(id.toString());
    if (asset == null) {
      return null;
    }

    return await asset.originFile;
  }

  void onDoubleTap(ExtendedImageGestureState state) {
    final Offset? pointerDownPosition = state.pointerDownPosition;
    final double begin = state.gestureDetails!.totalScale ?? 1.0;
    final double end = begin == 1.0 ? 2.0 : 1.0;

    _doubleClickAnimation?.removeListener(_doubleClickAnimationListener);
    _doubleClickAnimationController.stop();
    _doubleClickAnimationController.reset();

    _doubleClickAnimationListener = () =>
        state.handleDoubleTap(scale: _doubleClickAnimation?.value, doubleTapPosition: pointerDownPosition);

    _doubleClickAnimation = _doubleClickAnimationController.drive(Tween<double>(begin: begin, end: end));
    _doubleClickAnimation?.addListener(_doubleClickAnimationListener);

    _doubleClickAnimationController.forward();
  }

  GestureConfig onInitGestureConfigHandler(ExtendedImageState state) {
    return GestureConfig(inPageView: true, initialScale: 1.0, minScale: 1.0, cacheGesture: false);
  }

  Widget onLoadStateChanged(ExtendedImageState state) {
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
      // TODO: This doesn't allow zooming until the full size image finishes
        return PhotoPreview(photo: widget.photo, width: 256, height: 0, fit: BoxFit.fitWidth, showIcon: false);
      default:
        return state.completedWidget;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photo.location == PhotoLocation.Remote) {
      return ExtendedImage.network('http://${HOSTNAME}/photos/api/v1/photos/${widget.photo.id}/download/',
          headers: {'Authorization': AUTH_HEADER},
          enableLoadState: true,
          mode: ExtendedImageMode.gesture,
          initGestureConfigHandler: onInitGestureConfigHandler,
          onDoubleTap: onDoubleTap,
          loadStateChanged: onLoadStateChanged);
    }

    return FutureBuilder<File?>(
      future: getLocalImage(widget.photo.id),
      builder: (context, snapshot) {
        var data = snapshot.data;
        if (data == null) {
          // TODO
          return Container();
        }

        return ExtendedImage.file(data,
            enableLoadState: true,
            mode: ExtendedImageMode.gesture,
            initGestureConfigHandler: onInitGestureConfigHandler,
            onDoubleTap: onDoubleTap,
            loadStateChanged: onLoadStateChanged);
      },
    );
  }
}
