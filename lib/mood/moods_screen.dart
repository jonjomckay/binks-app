import 'package:async_builder/async_builder.dart';
import 'package:binks/mood/mood_constants.dart';
import 'package:binks/mood/mood_model.dart';
import 'package:binks/routes.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';

class MoodsScreen extends StatefulWidget {
  const MoodsScreen({Key? key}) : super(key: key);

  @override
  _MoodsScreenState createState() => _MoodsScreenState();
}

class _MoodsScreenState extends State<MoodsScreen> {
  static const int NUMBER_OF_DATES = 30;

  int countWords(String? value) {
    if (value == null) {
      return 0;
    }

    return RegExp(r"\w+('\w+)?").allMatches(value).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Moods'),
      ),
      body: Consumer<MoodModel>(
        builder: (context, model, child) => AsyncBuilder<Map<DateTime, Mood>>(
          future: model.listMoods(NUMBER_OF_DATES),
          retain: true,
          waiting: (context) => Center(child: CircularProgressIndicator()),
          builder: (context, moods) {
            if (moods == null) {
              return Container();
            }

            return ListView.builder(
              itemCount: NUMBER_OF_DATES,
              itemBuilder: (context, index) {
                var now = DateTime.now();
                var date = DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: index));

                return InkWell(
                  onTap: () =>
                      Navigator.pushNamed(context, ROUTE_MOOD, arguments: date),
                  child: Builder(builder: (context) {
                    var mood = moods[date];

                    int tagCount = mood == null ? 0 : mood.tags.length;

                    int wordCount = mood == null ? 0 : countWords(mood.comment);

                    var text = Jiffy().isSame(date, Units.DAY)
                        ? 'Today'
                        : Jiffy(date).format('MMMM do (EEEE)');

                    return ListTile(
                      title: Text('$text'),
                      subtitle: Text('$wordCount words / $tagCount tags'),
                      trailing: MoodIcon(mood: mood?.mood),
                    );
                  }),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MoodIcon extends StatelessWidget {
  final int? mood;

  const MoodIcon({Key? key, required this.mood}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var mood = this.mood;
    if (mood == null) {
      return CircleAvatar(
        child: Text('?'),
      );
    }

    return CircleAvatar(
      child: Text('$mood', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: MOOD_COLORS[mood][0],
      foregroundColor: MOOD_COLORS[mood][1],
    );
  }
}
