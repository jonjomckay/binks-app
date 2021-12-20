import 'package:draggable_scrollbar_sliver/draggable_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

const GridTileWithBackgroundImageTextStyle = TextStyle(
  shadows: [
    Shadow(
      blurRadius: 20.0,
      color: Colors.black,
      offset: Offset(5, 0),
    ),
  ],
);

class GridTileWithBackgroundImage extends StatelessWidget {
  final Widget image;
  final String title;
  final String subtitle;
  final int maxTitleLines;
  final Function()? onTap;

  const GridTileWithBackgroundImage({Key? key, required this.image, required this.title, required this.subtitle, this.maxTitleLines = 5, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          image,
          Container(color: Colors.black54),
          Container(
            margin: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, textAlign: TextAlign.center,
                    maxLines: maxTitleLines,
                    overflow: TextOverflow.ellipsis,
                    style: GridTileWithBackgroundImageTextStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    )),
                SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GridTileWithBackgroundImageTextStyle.copyWith(
                      fontSize: 12
                    ))
              ],
            ),
          )
        ],
      ),
    );
  }
}


class StaggeredGridWithSectionItem<T1, T2> {
  final T1? name;
  final T2? item;

  StaggeredGridWithSectionItem(this.name, this.item);
}

class StaggeredGridWithSections<T1, T2> extends StatelessWidget {
  final ScrollController scrollController;
  final List<StaggeredGridWithSectionItem<T1, T2>> items;
  final Widget Function(BuildContext context, T1 item) nameBuilder;
  final Widget Function(BuildContext context, T2 item) itemBuilder;
  final String Function(BuildContext context, StaggeredGridWithSectionItem<T1, T2> item) scrollLabelBuilder;
  final int crossAxisCount;

  StaggeredGridWithSections(
      {Key? key, required this.scrollController, required this.items, required this.nameBuilder, required this.itemBuilder, required this.scrollLabelBuilder, required this.crossAxisCount})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollbar.semicircle(
        controller: scrollController,
        backgroundColor: Colors.white,
        labelConstraints: BoxConstraints.expand(width: 200, height: 30),
        labelTextBuilder: (offsetY) {
          int currentItem = scrollController.hasClients
              ? (scrollController.offset / scrollController.position.maxScrollExtent * items.length).floor()
              : 0;

          if (currentItem >= items.length) {
            currentItem = items.length - 1;
          } else if (currentItem <= 0) {
            currentItem = 0;
          }

          var label = scrollLabelBuilder(context, items[currentItem]);

          return Text('$label', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold
          ));
        },
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverStaggeredGrid.countBuilder(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              itemCount: items.length,
              itemBuilder: (context, index) {
                var nameOrItem = items[index];
                if (nameOrItem.name != null) {
                  return nameBuilder(context, nameOrItem.name!);
                }

                return itemBuilder(context, nameOrItem.item!);
              },
              staggeredTileBuilder: (index) {
                var nameOrItem = items[index];
                if (nameOrItem.item != null) {
                  return StaggeredTile.count(1, 1);
                }

                return StaggeredTile.extent(crossAxisCount, 48);
              },
            )
          ],
        )
    );
  }
}