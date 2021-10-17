import 'package:binks/photos/photos_model.dart';
import 'package:binks/photos/photos_screen.dart';
import 'package:binks/ui/grids.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FragmentPhotos extends StatelessWidget {
  final ScrollController scrollController;

  const FragmentPhotos({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var dateFormat = DateFormat.yMMMEd();

    return Scaffold(
      body: Consumer<PhotosModel>(
        builder: (context, model, child) {
          var items = model.photos;

          List<StaggeredGridWithSectionItem<DateTime, Photo>> photos = [];

          for (int i = 0; i < items.length; i++) {
            var prevPhoto = i == 0 ? null : items[i - 1];
            var thisPhoto = items[i];

            // If this is the first photo, add the date separator first
            if (i == 0) {
              photos.add(StaggeredGridWithSectionItem(thisPhoto.modifiedAt, null));
            }

            // If this and the previous photo are from different days, add the date separator
            if (prevPhoto != null && prevPhoto.modifiedAt.day != thisPhoto.modifiedAt.day) {
              photos.add(StaggeredGridWithSectionItem(thisPhoto.modifiedAt, null));
            }

            photos.add(StaggeredGridWithSectionItem(null, thisPhoto));
          }

          return StaggeredGridWithSections<DateTime, Photo> (
            items: photos,
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
              return PhotoPreview(id: item.id, width: 256, height: 256);
            },
            scrollLabelBuilder: (context, item) {
              var date = item.name != null
                  ? item.name!
                  : item.item!.modifiedAt;

              return dateFormat.format(date);
            },
          );
        },
      ),
    );
  }
}
