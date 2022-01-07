import 'dart:typed_data';

import 'package:binks/main.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoPreview extends StatelessWidget {
  final Photo photo;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showIcon;

  const PhotoPreview({Key? key, required this.photo, required this.width, required this.height, required this.fit, this.showIcon = true}) : super(key: key);

  Future<Uint8List?> getLocalThumb(String id, double width, double height) async {
    var asset = await PhotoManager.refreshAssetProperties(id);
    if (asset == null) {
      return null;
    }

    return await asset.thumbDataWithSize(width.toInt(), height.toInt(), quality: 95);
  }

  @override
  Widget build(BuildContext context) {
    var uri = 'http://${HOSTNAME}/photos/api/v1/photos/${photo.remoteId}/preview/?width=${width.toInt()}&height=${height.toInt()}';

    // TODO: Extract and const?
    final loading = Container(
      alignment: Alignment.center,
      width: 48,
      height: 48,
      child: CircularProgressIndicator(),
    );

    // TODO: This is here for local photos but it's gross
    if (photo.location == PhotoLocation.Local) {
      return Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Container(
            width: width,
            height: height,
            child: FutureBuilder<Uint8List?>(
              // TODO: Null safety
              future: getLocalThumb(photo.localId!, width, height),
              builder: (context, snapshot) {
                var data = snapshot.data;
                if (data == null) {
                  // TODO: This probably doesn't match with ExtendedImage
                  return loading;
                }

                return ExtendedImage.memory(data, fit: fit, loadStateChanged: (state) {
                  switch (state.extendedImageLoadState) {
                    case LoadState.loading:
                      return loading;
                    default:
                      return state.completedWidget;
                  }
                });
              },
            ),
          ),
          if (showIcon)
            Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5.0,
                      ),
                    ]
                ),
                margin: const EdgeInsets.all(4),
                child: Icon(Icons.phone_android, size: 16)
            ),
        ],
      );
    }

    return ExtendedImage.network(uri, headers: {
      'Authorization': AUTH_HEADER
    }, fit: fit);
  }
}