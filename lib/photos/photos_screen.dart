import 'package:binks/contacts/contacts_model.dart';
import 'package:binks/photos/fragments/fragment_albums.dart';
import 'package:binks/photos/people/fragment_people.dart';
import 'package:binks/photos/fragments/fragment_photos.dart';
import 'package:binks/photos/fragments/fragment_places.dart';
import 'package:binks/photos/fragments/fragment_upload.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({Key? key}) : super(key: key);

  @override
  _PhotosScreenState createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController(initialPage: 0);

  List<Widget> _children = [Container()];
  int _selectedFragment = 0;
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();

    _children = [
      FragmentPhotos(scrollController: _scrollController),
      FragmentAlbums(scrollController: _scrollController),
      FragmentPlaces(scrollController: _scrollController),
      FragmentPeople(scrollController: _scrollController)
    ];
  }

  void selectDestination(int index) {
    setState(() {
      _selectedDestination = index;
    });
  }

  void selectFragment(int index) {
    _pageController.animateToPage(index, duration: Duration(milliseconds: 200), curve: Curves.easeInOut);

    setState(() {
      _selectedFragment = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await context.read<PhotosModel>().reloadData();
              // TODO: This shouldn't be here
              await context.read<ContactsModel>().reloadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.upload),
            onPressed: () async {
              Navigator.push(context, MaterialPageRoute(builder: (context) => FragmentUpload()));
            },
          )
        ],
      ),
      drawer: Drawer(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                          child: Text(
                            'Binks',
                            style: textTheme.headline6,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                          child: Text(
                            'jonjo@jonjomckay.com',
                            style: textTheme.caption,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
              ),
              DrawerItem(
                destination: 0,
                icon: Icons.photo,
                title: 'Photos',
                selected: _selectedDestination == 0,
                onTap: () => selectDestination(0),
              ),
              DrawerItem(
                destination: 1,
                icon: Icons.calendar_today,
                title: 'Daily',
                selected: _selectedDestination == 1,
                onTap: () => selectDestination(1)
              ),
              DrawerItem(
                destination: 2,
                icon: Icons.notes,
                title: 'Notes',
                selected: _selectedDestination == 2,
                onTap: () => selectDestination(2)
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _selectedFragment,
        onTap: selectFragment,
        items: [
          SalomonBottomBarItem(
            icon: Icon(Icons.photo_library),
            title: Text('Photos'),
            selectedColor: Colors.white,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.photo_album),
            title: Text('Albums'),
            selectedColor: Colors.white,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.place),
            title: Text('Places'),
            selectedColor: Colors.white,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.face),
            title: Text('People'),
            selectedColor: Colors.white,
          ),
        ],
      ),
      body: Container(
        child: PageView(
          controller: _pageController,
          onPageChanged: (value) => setState(() {
            _selectedFragment = value;
          }),
          children: _children
        )
      ),
    );
  }
}

class DrawerItem extends StatelessWidget {
  final int destination;
  final IconData icon;
  final String title;
  final bool selected;
  final void Function() onTap;

  const DrawerItem({Key? key, required this.destination, required this.icon, required this.title, required this.selected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTileTheme(
        selectedColor: Colors.white,
        selectedTileColor: theme.primaryColor,
        style: ListTileStyle.drawer,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.elliptical(8, 8))
        ),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          selected: selected,
          visualDensity: VisualDensity.compact,
          onTap: onTap,
        ),
      ),
    );
  }
}