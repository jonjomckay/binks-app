import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:binks/database.dart';
import 'package:binks/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:r_crypto/r_crypto.dart';

class PhotosModel extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: 5000,
  ));

  List<Album> _albums = [];
  List<Photo> _photos = [];
  List<Place> _places = [];

  List<Album> get albums => List.unmodifiable(_albums);
  List<Photo> get photos => List.unmodifiable(_photos);
  List<Place> get places => List.unmodifiable(_places);

  bool cancelSync = false;

  Future reloadData() async {
    await listAlbums();
    await listPhotos();
    await listPlaces();

    notifyListeners();
  }

  Future<Map<String, dynamic>> requestGet(String path, { int? limit, int? offset }) async {
    Map<String, dynamic> query = {};
    if (limit != null) {
      query['limit'] = '$limit';
    }
    if (offset != null) {
      query['offset'] = '$offset';
    }

    var response = await _dio.getUri(Uri.http(HOSTNAME, path, query), options: Options(headers: {
      'Authorization': AUTH_HEADER
    }));

    var body = response.data;
    if (body.isEmpty || response.statusCode != 200) {
      throw Exception('Oh dear: ${response.data}');
    }

    return body;
  }

  Future<void> listAlbums() async {
    log('Listing all albums');
    var content = await requestGet('/photos/api/v1/albums/');

    _albums = List.from(content['results']).map((e) => Album.fromMap(e)).toList();
    _albums = [..._albums, ...albums, ..._albums, ...albums, ..._albums, ...albums, ..._albums, ...albums, ..._albums, ...albums, ..._albums, ...albums, ..._albums, ...albums, ..._albums];
  }

  Future<void> listPhotos() async {
    log('Listing all photos');
    var content = await requestGet('/photos/api/v1/photos/');

    _photos = List.from(content['results']).map((e) => Photo.fromMap(e)).toList();
  }

  Future<void> listPlaces() async {
    log('Listing all places');
    var content = await requestGet('/photos/api/v1/places/');

    _places = List.from(content['results']).map((e) => Place.fromMap(e)).toList();
    _places = [..._places, ...places, ..._places, ...places, ..._places, ...places, ..._places, ...places, ..._places, ...places, ..._places, ...places, ..._places, ...places, ..._places];
    _places = [..._places, ...places];
  }

  void bench(String type, Function() run) {
    var startTime = DateTime.now();

    for (var i = 0; i < 100; i++) {
      run();
    }

    print('Finished $type in ${DateTime.now().difference(startTime).inMilliseconds}ms');
  }

  CancelableOperation<void> enumerateLocalPhotos(Function(Object, [StackTrace?]) onError) {
    return CancelableOperation.fromFuture(Future(() async {
      try {
        log('Enumerating all local photos');

        var database = await Database.writable();
        var beginsAt = DateTime.now();

        var albums = await PhotoManager.getAssetPathList(hasAll: true, onlyAll: true, type: RequestType.image);
        var photos = (await database.query(TABLE_PHOTO, columns: ['id']))
          .map((e) => e['id'] as String)
          .toSet();

        for (var album in albums) {
          var pageSize = 50;
          var maxPages = (album.assetCount / pageSize).ceil();

          for (var page = 1; page <= maxPages; page++) {
            var items = await album.getAssetListPaged(page, pageSize);
            var batch = database.batch();

            for (var item in items) {
              // TODO: There must be a better way of doing this
              if (cancelSync) {
                return;
              }

              if (photos.contains(item.id)) {
                batch.update(TABLE_PHOTO, {
                  'touched_at': beginsAt.millisecondsSinceEpoch
                }, where: 'id = ?', whereArgs: [item.id]);
                continue;
              }

              var file = await item.originFile;
              if (file == null) {
                log('No file found for ${item.id}');
                continue;
              }

              var hash = rHash.filePath(HashType.blake3(), file.path);

              batch.insert(TABLE_PHOTO, {
                'id': item.id,
                'blake3': convert(hash),
                'created_at': item.createDateTime.millisecondsSinceEpoch,
                'touched_at': beginsAt.millisecondsSinceEpoch
              });
            }

            await batch.commit();
          }
        }

        // Now remove any old local photos from the database that no longer exist
        var deleted = await database.delete(TABLE_PHOTO, where: 'touched_at != ?', whereArgs: [beginsAt.millisecondsSinceEpoch]);
        log('Finished, and removed $deleted old photos');
      } catch (e, stackTrace) {
        await onError(e, stackTrace);
      }
    }));
  }

  String convert(List<int> bytes) {
    StringBuffer buffer = new StringBuffer();
    for (int part in bytes) {
      if (part & 0xff != part) {
        throw new FormatException("Non-byte integer detected");
      }
      buffer.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
    }

    return buffer.toString();
  }

  CancelableOperation<void> syncPhotos(Function(UploadProgress?) onNext, Function(UploadProgress) onDone, Function(Object, [StackTrace?]) onError) {
    return CancelableOperation.fromFuture(Future(() async {
      await onNext(UploadProgress(UploadStatus.STARTING, 1, 1));

      await enumerateLocalPhotos(onError).valueOrCancellation();
      await uploadAllPhotos(onNext, onDone, onError).valueOrCancellation();
    }), onCancel: () async {
      cancelSync = true;
      // TODO: 0, 1?
      await onNext(UploadProgress(UploadStatus.CANCELLING, 0, 1));
    });
  }

  CancelableOperation<void> uploadAllPhotos(Function(UploadProgress?) onNext, Function(UploadProgress) onDone, Function(Object, [StackTrace?]) onError) {
    int done = 0;
    int total = 1;

    return CancelableOperation.fromFuture(Future(() async {
      log('Uploading all photos');

      // Refresh the list of all the remote photos, so we have their checksums
      await listPhotos();

      try {
        var result = await PhotoManager.requestPermissionExtend();
        if (result != PermissionState.authorized) {
          // TODO
          await onError(Exception('Permission is required to access your photos! Please try again.'));
          return;
        }

        var database = await Database.writable();

        var existingChecksums = this.photos
          .map((e) => e.checksum)
          .toSet();

        // If any images with the same checksum exist, we don't need to upload them
        var photosToUpload = (await database.query(TABLE_PHOTO, columns: ['id', 'blake3']))
          .where((e) => !existingChecksums.contains(e['blake3']))
          .toList();

        var maxToUpload = 5;
        total = photosToUpload.length;

        for (var photo in photosToUpload) {
          // TODO
          if (done > maxToUpload) {
            break;
          }

          await onNext(UploadProgress(UploadStatus.RUNNING, done, total));

          log('Uploading ${photo['id']}');

          var item = await AssetEntity.fromId(photo['id'] as String);
          if (item == null) {
            continue;
          }

          var file = await item.file;
          if (file == null) {
            continue;
          }

          var formData = FormData.fromMap({
            'image': await MultipartFile.fromFile(file.path, filename: await item.titleAsync),
            // 'modified_at': file.lastModifiedSync().toIso8601String()
          });

          await _dio.postUri(Uri.http(HOSTNAME, '/photos/api/v1/photos/upload/'), data: formData, options: Options(
              headers: {
                'Authorization': AUTH_HEADER
              }
          ));

          // TODO
          done += 1;
        }

        await reloadData();
      } catch (e, stackTrace) {
        // await onNext(UploadProgress(UploadStatus.ERRORED, done, total));
        await onError(e, stackTrace);
      } finally {
        if (cancelSync) {
          await onDone(UploadProgress(UploadStatus.CANCELLED, done, total));
        } else {
          await onDone(UploadProgress(UploadStatus.DONE, done, total));
        }

        cancelSync = false;
      }
    }));
  }
}

class Album {
  final int id;
  final String name;
  final String description;
  final int numberOfPhotos;
  final int? coverPhoto;

  Album({ required this.id, required this.name, required this.description, required this.numberOfPhotos, required this.coverPhoto });

  factory Album.fromMap(Map<String, dynamic> map) {
    var photos = List.from(map['photos']);

    return Album(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      numberOfPhotos: photos.length,
      coverPhoto: photos.isEmpty ? null : photos.first['id']
    );
  }
}

class Place {
  final int id;
  final String name;
  final String country;
  final int numberOfPhotos;
  final int? coverPhoto;

  Place({ required this.id, required this.name, required this.country, required this.numberOfPhotos, required this.coverPhoto });

  factory Place.fromMap(Map<String, dynamic> map) {
    var photos = List.from(map['photos']);

    return Place(
      id: map['id'],
      name: map['name'],
      country: map['address_country'],
      numberOfPhotos: photos.length,
      coverPhoto: photos.isEmpty ? null : photos.first['id']
    );
  }
}

class Photo {
  final int id;
  final String name;
  final bool favourite;
  final String? caption;
  final int width;
  final int height;
  final String checksum;
  final DateTime modifiedAt;
  final DateTime uploadedAt;

  Photo({ required this.id, required this.name, required this.favourite, required this.caption, required this.width, required this.height, required this.checksum, required this.modifiedAt, required this.uploadedAt });

  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
        id: map['id'],
        name: map['name'],
        favourite: map['favourite'],
        caption: map['caption'],
        width: map['width'],
        height: map['height'],
        checksum: map['checksum'],
        modifiedAt: DateTime.parse(map['modified_at']),
        uploadedAt: DateTime.parse(map['uploaded_at'])
    );
  }
}

enum UploadStatus {
  CANCELLED,
  CANCELLING,
  DONE,
  ERRORED,
  RUNNING,
  STARTING,
  UNSTARTED,
}

class UploadProgress {
  final UploadStatus status;
  final int complete;
  final int total;

  const UploadProgress(this.status, this.complete, this.total);

  get percent => (progress * 100).round();
  get progress => (1 / total) * complete;
}