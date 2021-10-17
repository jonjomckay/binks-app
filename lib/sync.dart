import 'dart:async';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:binks/main.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';

Future onTaskFetch(String id) async {
  // This is the fetch-event callback.
  print("[BackgroundFetch] Event received $id");

  if (id == 'flutter_background_fetch') {
    // This is the event sent every $minimumFetchInterval
  }

  if (id == 'photos_sync') {
    int i = 0;
  }

  // Signal completion, so the OS doesn't punish us for taking too long
  BackgroundFetch.finish(id);
}

Future onTaskTimeout(String id) async {
  // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
  print("[BackgroundFetch] TASK TIMEOUT taskId: $id");

  // Signal completion, so the OS doesn't punish us for taking too long
  BackgroundFetch.finish(id);
}

class Sync {
  static final Sync instance = Sync();

  CancelableOperation<void>? _runningSync;
  late PhotosModel _photosModel;

  BehaviorSubject<UploadProgress?> _streamController = BehaviorSubject();

  void setPhotosModel(PhotosModel model) {
    _photosModel = model;
  }

  Future stop() async {
    var runningSync = _runningSync;
    if (runningSync == null) {
      return;
    }

    await runningSync.cancel();
  }

  Stream<UploadProgress?> syncProgress() {
    return _streamController.stream;
  }

  Future onSyncNext(UploadProgress? progress) async {
    log('Got next of ${progress?.status}');

    _streamController.add(progress);

    if (progress == null) {
      return;
    }

    await notifications.show(0, 'Syncing', '${progress.complete} / ${progress.total}', NotificationDetails(
        android: AndroidNotificationDetails('sync', 'Sync',
          channelDescription: 'Information about data synchronisation',
          importance: Importance.min,
          maxProgress: progress.total,
          onlyAlertOnce: true,
          ongoing: false,
          priority: Priority.low,
          progress: progress.complete,
          showProgress: true,
        )
    ));
  }

  Future onSyncDone(UploadProgress progress) async {
    log('Finishing sync with ${progress.status}');

    _streamController.add(progress);

    await notifications.show(0, 'Sync', 'Sync complete', NotificationDetails(
        android: AndroidNotificationDetails('sync', 'Sync',
          channelDescription: 'Information about data synchronisation',
          importance: Importance.min,
          onlyAlertOnce: true,
          ongoing: false,
          priority: Priority.low,
          showProgress: false,
        )
    ));
  }

  Future onSyncError(Object error, [StackTrace? stackTrace]) async {
    log('Unable to complete sync', error: error, stackTrace: stackTrace);
    _streamController.addError(error, stackTrace);
  }

  Future<void> sync() async {
    var runningSync = _runningSync;
    if (runningSync != null && !runningSync.isCompleted) {
      log('A sync is already running!');
      return;
    }

    log('Starting sync');

    _runningSync = _photosModel.syncPhotos(onSyncNext, onSyncDone, onSyncError);

    int i = 0;
  }
}