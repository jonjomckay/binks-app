import 'dart:typed_data';

import 'package:binks/photos/photo_full_size.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

class LocalImageProvider extends ImageProvider<Photo> {
  final Photo photo;

  LocalImageProvider(this.photo);

  // TODO: This is duplicated
  Future<Uint8List?> _getLocalThumb(int id) async {
    var asset = await PhotoManager.refreshAssetProperties(id.toString());
    if (asset == null) {
      return null;
    }

    return await asset.originBytes;
  }

  @override
  ImageStreamCompleter load(Photo key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
        scale: 1,
        codec: Future(() async {
          // TODO: Dimensions
          var result = await _getLocalThumb(key.id);
          if (result == null) {
            // TODO
            return decode(Uint8List(0));
          }

          return decode(result);
        }));
  }

  @override
  Future<Photo> obtainKey(ImageConfiguration configuration) {
    return Future.value(photo);
  }
}

class PhotoScreen extends StatefulWidget {
  final PageController pageController;
  final List<Photo> photos;

  const PhotoScreen({Key? key, required this.pageController, required this.photos}) : super(key: key);

  @override
  _PhotoScreenState createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  @override
  void initState() {
    super.initState();

    var model = context.read<CurrentPhotoModel>();
    // TODO: This calls setState before the first render, causing a warning
    model.setCurrentPhoto(widget.pageController.initialPage.toDouble());

    widget.pageController.addListener(() {
      model.setCurrentPhoto(widget.pageController.page);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<CurrentPhotoModel>(builder: (context, model, child) {
          var photo = model.currentPhoto;
          if (photo == null) {
            return Text('');
          }

          return Text('${photo.name}');
        }),
      ),
      body: Consumer<PhotosModel>(builder: (context, model, child) {
        return ExtendedImageGesturePageView.builder(
          controller: widget.pageController,
          itemCount: widget.photos.length,
          itemBuilder: (context, index) {
            return PhotoFullSize(photo: widget.photos[index]);
          },
        );
      }),
    );
  }
}
