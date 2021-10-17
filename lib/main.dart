import 'dart:convert';

import 'package:async_builder/async_builder.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:binks/database.dart';
import 'package:binks/mood/mood_model.dart';
import 'package:binks/mood/mood_screen.dart';
import 'package:binks/mood/moods_screen.dart';
import 'package:binks/mood/tag_model.dart';
import 'package:binks/music/music_model.dart';
import 'package:binks/music/music_screen.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:binks/photos/photos_screen.dart';
import 'package:binks/routes.dart';
import 'package:binks/sync.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

// TODO: Use this for photo syncing in the background on iOS: https://github.com/rekab-app/background_locator

// const String HOSTNAME = '192.168.0.81:8000';
const String HOSTNAME = '192.168.0.188:8000';
const String USERNAME = '';
const String PASSWORD = '';
var AUTH_HEADER = 'Basic ' + base64Encode('$USERNAME:$PASSWORD'.codeUnits);

FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;

  if (task.timeout) {
    // This task has exceeded its allowed running-time.
    // You must stop what you're doing and immediately .finish(taskId)
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }
  print('[BackgroundFetch] Headless event received.');
  // Do your work here...
  BackgroundFetch.finish(taskId);
}

void main() {
  var photosModel = PhotosModel();

  Sync.instance.setPhotosModel(photosModel);

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<MoodModel>(create: (context) => MoodModel()),
      ChangeNotifierProvider<MusicModel>(create: (context) => MusicModel()),
      ChangeNotifierProvider<PhotosModel>(create: (context) => photosModel),
      ChangeNotifierProvider<TagModel>(create: (context) => TagModel()),
    ],
    child: MyApp(),
  ));

  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initBackgroundFetch();
    initLocalNotifications();
  }

  Future<void> initBackgroundFetch() async {
    var backgroundFetchConfig = BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE
    );

    int status = await BackgroundFetch.configure(
      backgroundFetchConfig,
      onTaskFetch,
      onTaskTimeout
    );

    print('[BackgroundFetch] configure success: $status');

    if (!mounted) return;
  }

  Future<void> initLocalNotifications() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final IOSInitializationSettings iOS = IOSInitializationSettings();

    final InitializationSettings settings = InitializationSettings(
        android: android,
        iOS: iOS
    );

    await notifications.initialize(settings, onSelectNotification: selectNotification);
  }

  void selectNotification(String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        ROUTE_MUSIC: (context) => MusicScreen(),
        ROUTE_PHOTOS: (context) => PhotosScreen(),
      },
      initialRoute: ROUTE_HOME,
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
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, ROUTE_MUSIC),
              child: Text('Music'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, ROUTE_PHOTOS),
              child: Text('Photos'),
            ),
            ElevatedButton(
              onPressed: () async {
                var model = context.read<PhotosModel>();
              },
              child: Text('Hash'),
            )
          ],
        ),
      ),
    );
  }
}
