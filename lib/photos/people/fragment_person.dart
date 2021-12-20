import 'package:binks/photos/fragments/fragment_photos.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FragmentPerson extends StatelessWidget {
  final Person person;

  const FragmentPerson({Key? key, required this.person}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Consumer<PhotosModel>(builder: (context, model, child) {
        var photoIds = person.faces.map((e) => e.photo).toList();
        var photos = model.photos
            .where((element) => element.location == PhotoLocation.Remote)
            .where((photo) => photoIds.contains(photo.id))
            .toList();

        return PhotoList(scrollController: ScrollController(), photos: photos);
      }),
    );
  }
}
