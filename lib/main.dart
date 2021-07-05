import 'package:async_builder/async_builder.dart';
import 'package:binks/database.dart';
import 'package:binks/mood/mood_model.dart';
import 'package:binks/mood/mood_screen.dart';
import 'package:binks/mood/moods_screen.dart';
import 'package:binks/mood/tag_model.dart';
import 'package:binks/routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MoodModel>(create: (context) => MoodModel()),
        ChangeNotifierProvider<TagModel>(create: (context) => TagModel()),
      ],
      child: MaterialApp(
        title: 'Binks',
        themeMode: ThemeMode.system,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
        ),
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        routes: {
          ROUTE_HOME: (context) => DefaultScreen(),
          ROUTE_MOOD: (context) => MoodScreen(),
          ROUTE_MOODS: (context) => MoodsScreen(),
        },
        initialRoute: ROUTE_HOME,
      )
    );
  }
}

class DefaultScreen extends StatefulWidget {
  @override
  _DefaultScreenState createState() => _DefaultScreenState();
}

class _DefaultScreenState extends State<DefaultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App'),
      ),
      body: AsyncBuilder<void>(
        future: Database.migrate(),
        waiting: (context) => Center(child: CircularProgressIndicator()),
        builder: (context, value) => Column(
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, ROUTE_MOODS),
              child: Text('Moods'),
            )
          ],
        ),
      ),
    );
  }
}
