// import 'package:binks/extensions/iterables.dart';
// import 'package:binks/photos/photos_model.dart';
// import 'package:binks/photos/photos_screen.dart';
// import 'package:binks/ui/grids.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// class FragmentSubplaces extends StatelessWidget {
//   final ScrollController scrollController;
//
//   const FragmentSubplaces({Key? key, required this.scrollController}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<PhotosModel>(
//       builder: (context, model, child) {
//         var items = model.places;
//
//         List<StaggeredGridWithSectionItem<String?, Place?>> placeOrCountries = [];
//
//         var groups = items.groupBy((e) => e.country);
//         var countries = groups.keys.toList(growable: false);
//
//         for (var country in countries) {
//           placeOrCountries.add(StaggeredGridWithSectionItem(country, null));
//
//           for (var place in groups[country]!) {
//             placeOrCountries.add(StaggeredGridWithSectionItem(null, place));
//           }
//         }
//
//         return StaggeredGridWithSections<String?, Place?>(
//           items: placeOrCountries,
//           crossAxisCount: 3,
//           scrollController: scrollController,
//           nameBuilder: (context, item) {
//             return Container(
//               alignment: Alignment.centerLeft,
//               color: Theme.of(context).dialogBackgroundColor,
//               padding: EdgeInsets.symmetric(horizontal: 12),
//               child: Text(item!, style: TextStyle(
//                   fontWeight: FontWeight.w500,
//                   fontSize: 15
//               )),
//             );
//           },
//           itemBuilder: (context, item) {
//             var plural = Intl.plural(item!.numberOfPhotos, one: 'photo', other: 'photos');
//             var coverPhoto = item.coverPhoto;
//
//             return GestureDetector(
//               // onTap: () => Navigator.push(context,
//               //     MaterialPageRoute(builder: (context) =>
//               //         PlacePage(id: item.id))),
//               child: GridTileWithBackgroundImage(
//                 image: coverPhoto == null
//                     ? Container()
//                     : PhotoPreview(id: coverPhoto, width: 256, height: 256),
//                 title: item.amenity,
//                 subtitle: '${item.numberOfPhotos} $plural',
//               ),
//             );
//           },
//           scrollLabelBuilder: (context, item) {
//             return item.name == null
//                 ? item.item!.amenity
//                 : item.name!;
//           },
//         );
//       },
//     );
//   }
// }
