import 'package:binks/photos/photo_preview.dart';
import 'package:binks/photos/photo_screen.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:binks/ui/grids.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FragmentPhotos extends StatelessWidget {
  final ScrollController scrollController;

  const FragmentPhotos({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PhotosModel>(
        builder: (context, model, child) {
          return PhotoList(scrollController: scrollController, photos: model.photos);
        },
      ),
    );
  }
}

class PhotoList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Photo> photos;

  const PhotoList({Key? key, required this.scrollController, required this.photos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var dateFormat = DateFormat.yMMMEd();

    List<StaggeredGridWithSectionItem<DateTime, Photo>> organisedPhotos = [];

    for (int i = 0; i < photos.length; i++) {
      var prevPhoto = i == 0 ? null : photos[i - 1];
      var thisPhoto = photos[i];

      // If this is the first photo, add the date separator first
      if (i == 0) {
        organisedPhotos.add(StaggeredGridWithSectionItem(thisPhoto.modifiedAt, null));
      }

      // If this and the previous photo are from different days, add the date separator
      if (prevPhoto != null && prevPhoto.modifiedAt.day != thisPhoto.modifiedAt.day) {
        organisedPhotos.add(StaggeredGridWithSectionItem(thisPhoto.modifiedAt, null));
      }

      organisedPhotos.add(StaggeredGridWithSectionItem(null, thisPhoto));
    }

    return StaggeredGridWithSections<DateTime, Photo> (
      items: organisedPhotos,
      crossAxisCount: 4,
      scrollController: scrollController,
      nameBuilder: (context, item) {
        return Container(
          alignment: Alignment.centerLeft,
          color: Theme.of(context).dialogBackgroundColor,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(dateFormat.format(item), style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15
          )),
        );
      },
      itemBuilder: (context, item) {
        return GestureDetector(
          child: PhotoPreview(photo: item, width: 256, height: 256, fit: BoxFit.cover),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PhotoScreen(
            // currentIndex: photos.indexOf(item),
            photos: photos,
            pageController: PageController(initialPage: photos.indexOf(item)),
          ))),
        );
      },
      scrollLabelBuilder: (context, item) {
        var date = item.name != null
            ? item.name!
            : item.item!.modifiedAt;

        return dateFormat.format(date);
      },
    );
  }
}
