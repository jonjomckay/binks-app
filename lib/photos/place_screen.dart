import 'package:binks/extensions/iterables.dart';
import 'package:binks/photos/fragments/fragment_photos.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recase/recase.dart';

class CityScreen extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  final Area area;

  CityScreen({Key? key, required this.area}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var model = context.read<PhotosModel>();

    var places = model.places
        .where((p) => p.area == area.area)
        .where((p) => p.country == area.country)
        // .map((e) => e.id)
        .toList();
    
    var amenities = places
        .where((p) => p.amenity != null)
        .distinctBy((e) => '${e.amenity},${e.type}')
        .toList();

    var localities = places
        .where((p) => p.amenity == null)
        .where((p) => p.locality != null)
        .distinctBy((p) => '${p.locality},${p.type}')
        .toList();

    var subPlaces = [...amenities, ...localities]
        .map((e) {
          if (e.amenity != null) {
            return SubPlace(e.name, e.category, e.type);
          }

          return SubPlace(e.name, e.category, e.type);
        })
        .sorted((a, b) => a.name.compareTo(b.name))
        .toList();

    var placeIds = places
        .map((p) => p.id)
        .toList();

    var photos = model.photos
        .where((p) => placeIds.contains(p.placeId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('hi'),
      ),
      endDrawer: Drawer(
        child: Text('hi')
      ),
      body: Column(
        children: [
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              itemCount: subPlaces.length,
              itemBuilder: (context, index) {
                var place = subPlaces[index];

                return ListTile(
                  dense: true,
                  leading: Icon(getSubPlaceIcon(place)),
                  title: Text('${place.name}'),
                  subtitle: Text('${place.type.titleCase} / ${place.category.titleCase}'),
                );
              },
            ),
          ),
          Expanded(child: PhotoList(scrollController: _scrollController, photos: photos)),
        ],
      ),
    );
  }
}

IconData getSubPlaceIcon(SubPlace place) {
  switch (place.type) {
    case 'bank':
      return Icons.account_balance;
    case 'bus_stop':
      return Icons.directions_bus;
    case 'cinema':
      return Icons.theaters;
    case 'convenience':
    case 'supermarket':
      return Icons.local_grocery_store;
    case 'cycleway':
      return Icons.directions_bike;
    case 'house':
      return Icons.house;
    case 'pub':
      return Icons.sports_bar;
    case 'restaurant':
      return Icons.restaurant;
    case 'retail':
      return Icons.local_mall;
    case 'university':
      return Icons.school;
    default:
      if (place.category == 'amenity') {
        return Icons.business;
      } else if (place.category == 'highway') {
        return Icons.add_road;
      } else if (place.category == 'shop') {
        return Icons.store;
      }

      print([place.category, place.type]);
      return Icons.place;
  }
}

class SubPlace {
  final String name;
  final String category;
  final String type;

  SubPlace(this.name, this.category, this.type);
}
