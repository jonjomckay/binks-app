import 'package:animated_item_picker/animated_item_picker.dart';
import 'package:binks/photos/fragments/fragment_photos.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:binks/photos/photos_screen.dart';
import 'package:binks/ui/grids.dart';
import 'package:drag_select_grid_view/drag_select_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:item_selector/item_selector.dart';
import 'package:multiselect_scope/multiselect_scope.dart';
import 'package:provider/provider.dart';

class CreateAlbumDialog extends StatefulWidget {
  const CreateAlbumDialog({Key? key}) : super(key: key);

  @override
  _CreateAlbumDialogState createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<CreateAlbumDialog> {
  final controller = DragSelectGridViewController();
  final _multiselectController = MultiselectController();
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  void scheduleRebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    // controller.addListener(scheduleRebuild);
  }

  @override
  void dispose() {
    // controller.removeListener(scheduleRebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var model = context.read<PhotosModel>();
    var photos = model.photos;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create album'),
        actions: [
          TextButton(
            child: Text('SAVE', style: theme.textTheme.button),
            onPressed: () {
              var form = _formKey.currentState;
              if (form == null) {
                return;
              }

              var a = _multiselectController.selectedIndexes;

              if (form.validate()) {
                // TODO: Submit
                // Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Container(
          margin: const EdgeInsets.all(8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Name',
                    hintText: 'Pick a name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                DragSelectGridView(
                  gridController: controller,
                  shrinkWrap: true,
                  triggerSelectionOnTap: true,
                  itemCount: photos.length,
                  itemBuilder: (context, index, selected) {
                    var photo = photos[index];

                    if (selected) {
                      return Text('Selected');
                    }

                    return PhotoPreview(id: photo.id, width: 256, height: 256);
                  },
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                  ),
                ),
                // AnimatedItemPicker(
                //   axis: Axis.horizontal,
                //   multipleSelection: true,
                //   itemCount: photos.length,
                //   itemBuilder: (index, animatedValue) {
                //     var photo = photos[index];
                //     return PhotoPreview(id: photo.id, width: 256, height: 256);
                //   },
                //   onItemPicked: (int , bool ) {
                //
                //   },
                // ),
                // ItemSelectionController(
                //   selectionMode: ItemSelectionMode.single,
                //   onSelectionStart: (start, end) {
                //     int i = 0;
                //     return true;
                //   },
                //   onSelectionEnd: (start, end) {
                //     int i = 0;
                //     return true;
                //   },
                //   onSelectionUpdate: (start, end) {
                //     int i = 0;
                //     return true;
                //   },
                //   child: GridView.builder(
                //     controller: _scrollController,
                //     shrinkWrap: true,
                //     gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                //         maxCrossAxisExtent: 140
                //     ),
                //     itemCount: photos.length,
                //     itemBuilder: (context, index) {
                //       return ItemSelectionBuilder(
                //         index: index,
                //         builder: (context, index, selected) {
                //           var photo = photos[index];
                //
                //           if (selected) {
                //             return Text('Selected');
                //           }
                //
                //           return PhotoPreview(id: photo.id, width: 256, height: 256);
                //         },
                //       );
                //     },
                //   ),
                // ),
                // MultiselectScope(
                //   controller: _multiselectController,
                //   dataSource: photos,
                //   initialSelectedIndexes: [],
                //   keepSelectedItemsBetweenUpdates: true,
                //   child: GridView.builder(
                //     controller: _scrollController,
                //     shrinkWrap: true,
                //     gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                //       maxCrossAxisExtent: 140
                //     ),
                //     itemCount: photos.length,
                //     itemBuilder: (context, index) {
                //       var photo = photos[index];
                //
                //       final controller = MultiselectScope.controllerOf(context);
                //
                //       return InkWell(
                //         onTap: () {
                //           controller.select(index);
                //         },
                //         child: controller.isSelected(index)
                //           ? Text('Selected')
                //           : PhotoPreview(id: photo.id, width: 256, height: 256),
                //       );
                //     },
                //   ),
                // )
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class FragmentAlbums extends StatelessWidget {
  final ScrollController scrollController;

  const FragmentAlbums({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO: This should disappear and reappear on page switch, not swipe with the page
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => CreateAlbumDialog(),
            ));
          }
      ),
      body: Consumer<PhotosModel>(
        builder: (context, model, child) {
          var items = model.albums
              .map((e) => StaggeredGridWithSectionItem(null, e))
              .toList(growable: false);

          return StaggeredGridWithSections<String?, Album?>(
            items: items,
            crossAxisCount: 3,
            scrollController: scrollController,
            nameBuilder: (context, item) => Container(),
            itemBuilder: (context, item) {
              var plural = Intl.plural(item!.numberOfPhotos, one: 'photo', other: 'photos');
              var coverPhoto = item.coverPhoto;

              return GestureDetector(
                // onTap: () => Navigator.push(context,
                //     MaterialPageRoute(builder: (context) =>
                //         PlacePage(id: item.id))),
                child: GridTileWithBackgroundImage(
                  image: coverPhoto == null
                      ? Container()
                      : PhotoPreview(id: coverPhoto, width: 256, height: 256),
                  title: item.name,
                  subtitle: '${item.numberOfPhotos} $plural',
                ),
              );
            },
            scrollLabelBuilder: (context, item) {
              return item.item!.name;
            },
          );
        },
      ),
    );
  }
}
