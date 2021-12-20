import 'package:binks/extensions/iterables.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:binks/photos/photos_screen.dart';
import 'package:binks/photos/place_screen.dart';
import 'package:binks/ui/grids.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FragmentPlaces extends StatelessWidget {
  final ScrollController scrollController;

  const FragmentPlaces({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotosModel>(
      builder: (context, model, child) {
        var items = model.places;

        List<StaggeredGridWithSectionItem<String?, Area?>> areaOrCountries = [];

        var groups = items.groupBy((e) => e.country);
        var countries = groups.keys.toList(growable: false);

        for (var country in countries) {
          areaOrCountries.add(StaggeredGridWithSectionItem(country, null));

          Map<String, Area> areas = {};

          for (var place in groups[country]!) {
            // TODO: This could end up putting 2 different areas in the same country with the same name together, which isn't great
            var key = '${place.area},${place.country}';
            if (areas.containsKey(key)) {
              areas[key]!.numberOfPhotos += place.numberOfPhotos;
            } else {
              areas[key] = Area(area: place.area, country: place.country, numberOfPhotos: place.numberOfPhotos);
            }
          }

          for (var city in areas.values.sorted((a, b) => a.area?.compareTo(b.area ?? '') ?? 0)) {
            areaOrCountries.add(StaggeredGridWithSectionItem(null, city));
          }
        }

        return StaggeredGridWithSections<String?, Area?>(
          items: areaOrCountries,
          crossAxisCount: 3,
          scrollController: scrollController,
          nameBuilder: (context, item) {
            return Container(
              alignment: Alignment.centerLeft,
              color: Theme.of(context).dialogBackgroundColor,
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(item!, style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15
              )),
            );
          },
          itemBuilder: (context, item) {
            var plural = Intl.plural(item!.numberOfPhotos, one: 'photo', other: 'photos');
            // var coverPhoto = item.coverPhoto;

            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) =>
                      CityScreen(area: item))),
              child: GridTileWithBackgroundImage(
                image: Container(),
                // TODO: This definitely isn't the right way
                title: item.area ?? 'Unknown',
                subtitle: '${item.numberOfPhotos} $plural',
              ),
            );
          },
          scrollLabelBuilder: (context, item) {
            return item.name == null
                ? item.item!.area ?? 'Unknown'
                : item.name!;
          },
        );
      },
    );
  }
}
