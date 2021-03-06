import 'dart:async';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:binks/database.dart';
import 'package:binks/extensions/iterables.dart';
import 'package:binks/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:r_crypto/r_crypto.dart';

// TODO: Extract
Future<Map<String, dynamic>> requestGet(Dio dio, String path, {int? limit, int? offset}) async {
  Map<String, dynamic> query = {};
  if (limit != null) {
    query['limit'] = '$limit';
  }
  if (offset != null) {
    query['offset'] = '$offset';
  }

  var response = await dio.getUri(Uri.http(HOSTNAME, path, query),
      options: Options(headers: {'Authorization': AUTH_HEADER}));

  var body = response.data;
  if (body.isEmpty || response.statusCode != 200) {
    // TODO
    throw Exception('Oh dear: ${response.data}');
  }

  return body;
}

Future<Map<String, dynamic>> requestPost(Dio dio, String path, Map<String, dynamic> data) async {
  var response = await dio.postUri(Uri.http(HOSTNAME, path),
      data: data, options: Options(headers: {'Authorization': AUTH_HEADER}));

  var body = response.data;
  if (response.statusCode != 201 && response.statusCode != 202 && response.statusCode != 204) {
    // TODO
    throw Exception('Oh dear: ${response.data}');
  }

  return body;
}


class PhotosModel extends ChangeNotifier {
  final Dio dio;

  List<Album> _albums = [];
  List<FaceCluster> _faceClusters = [];
  List<Face> _faces = [];
  List<Person> _people = [];
  List<Photo> _photos = [];
  List<Place> _places = [];

  PhotosModel(this.dio);

  List<Album> get albums => List.unmodifiable(_albums);

  List<FaceCluster> get faceClusters => List.unmodifiable(_faceClusters);

  List<Face> get faces => List.unmodifiable(_faces);

  List<Person> get people => List.unmodifiable(_people);

  List<Photo> get photos => List.unmodifiable(_photos);

  List<Place> get places => List.unmodifiable(_places);

  bool cancelSync = false;

  Future reloadData() async {
    await reloadAlbums();
    await reloadFaceClusters();
    await reloadFaces();
    await reloadPeople();
    await reloadPhotos();
    await reloadPlaces();

    notifyListeners();
  }

  Future<void> reloadAlbums({bool notify = false}) async {
    log('Listing all albums');
    var content = await requestGet(dio, '/photos/api/v1/albums/');

    _albums = List.from(content['results']).map((e) => Album.fromMap(e)).toList();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> reloadFaceClusters({bool notify = false}) async {
    log('Listing all face clusters');

    var content = await requestGet(dio, '/photos/api/v1/face-clusters/');

    _faceClusters = List.from(content['results']).map((e) => FaceCluster.fromMap(e)).toList();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> reloadFaces({bool notify = false}) async {
    log('Listing all faces');

    var content = await requestGet(dio, '/photos/api/v1/faces/');

    _faces = List.from(content['results']).map((e) => Face.fromMap(e)).toList();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> reloadPeople({bool notify = false}) async {
    log('Listing all people');

    var content = await requestGet(dio, '/photos/api/v1/people/');

    _people = List.from(content['results'])
        .map((e) => Person.fromMap(e))
        .sorted((a, b) => a.preferredName.compareTo(b.preferredName))
        .toList();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> reloadPhotos({bool notify = false}) async {
    log('Listing all photos');

    var startedAt = DateTime.now();

    await enumerateLocalPhotos(startedAt, (error, [stackTrace]) async {
      log('Something broke', error: error, stackTrace: stackTrace);
    }).value;

    var database = await Database.writable();

    // TODO: Do I need to fetch the entire photo here? We do it again later
    var existingPhotos = (await database.query(TABLE_PHOTO))
        .map((e) => Photo.fromLocal(e))
        .toSet();

    var existingChecksums = Map.fromEntries(existingPhotos.map((e) => MapEntry(e.checksum, e.localId)));

    var content =
        await requestGet(dio, '/photos/api/v1/photos/', limit: 999999, offset: 0);

    var remotePhotos = List.from(content['results'])
        .map((e) => Photo.fromRemote(e))
        .toSet();

    // for (var localPhoto in localPhotos) {
    //   if (remotePhotos.contains(localPhoto)) {
    //     continue;
    //   }
    //
    //   remotePhotos.add(localPhoto);
    // }

    // Store the photos locally
    var batch = database.batch();

    // batch.delete(TABLE_PHOTO, where: 'location = ?', whereArgs: ['remote']);

    for (var remotePhoto in remotePhotos) {
      if (existingChecksums.containsKey(remotePhoto.checksum)) {
        var localId = existingChecksums[remotePhoto.checksum];

        batch.update(TABLE_PHOTO, {
          ...remotePhoto.toMap(localId: localId),
          'touched_at': startedAt.millisecondsSinceEpoch,
        }, where: 'local_id = ?', whereArgs: [localId]);
      } else {
        batch.insert(TABLE_PHOTO, {
          ...remotePhoto.toMap(),
          'touched_at': startedAt.millisecondsSinceEpoch
        });
      }
    }

    await batch.commit();

    _photos = (await database.query(TABLE_PHOTO))
        .map((e) => Photo.fromDatabase(e))
        .sorted((a, b) => b.modifiedAt.compareTo(a.modifiedAt))
        .toSet()
        .toList();

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> reloadPlaces({bool notify = false}) async {
    log('Listing all places');
    var content = await requestGet(dio, '/photos/api/v1/places/');

    _places = List.from(content['results']).map((e) => Place.fromMap(e)).toList();

    if (notify) {
      notifyListeners();
    }
  }

  // TODO: This always checksums new photos, which is quite intense. Therefore on first refresh, nothing is shown for ages
  CancelableOperation<void> enumerateLocalPhotos(DateTime startedAt,
      Function(Object, [StackTrace?]) onError) {
    return CancelableOperation.fromFuture(Future(() async {
      try {
        log('Enumerating all local photos');

        var database = await Database.writable();

        // await database.delete(TABLE_PHOTO);

        var albums = await PhotoManager.getAssetPathList(hasAll: true, onlyAll: true, type: RequestType.image);
        var localPhotos = (await database.query(TABLE_PHOTO, columns: ['local_id'], where: 'local_id IS NOT NULL'))
            .map((e) => e['local_id'] as String)
            .distinctBy((e) => e)
            .toSet();

        // var remotePhotos = (await database.query(TABLE_PHOTO, columns: ['remote_id']))
        //     .map((e) => e['remote_id'] as String)
        //     .distinctBy((e) => e)
        //     .toSet();

        var checksums = Map.fromEntries((await database.query(TABLE_PHOTO, columns: ['id', 'checksum']))
            .map((e) => MapEntry(e['checksum'] as String, e['id'] as int))
            .toSet());

        for (var album in albums) {
          var pageSize = 50;
          var maxPages = (album.assetCount / pageSize).ceil();
          // var maxPages = 3;

          for (var page = 0; page <= maxPages; page++) {
            var items = await album.getAssetListPaged(page, pageSize);
            var batch = database.batch();

            for (var item in items) {
              // TODO: There must be a better way of doing this
              if (cancelSync) {
                return;
              }

              var data = {
                'name': item.title ?? await item.titleAsync,
                'location': 'local',
                'local_id': item.id,
                'width': item.width,
                'height': item.height,
                'modified_at': item.modifiedDateTime.millisecondsSinceEpoch,
                'touched_at': startedAt.millisecondsSinceEpoch
              };

              // If we already have this local photo stored, update it with the metadata
              if (localPhotos.contains(item.id)) {
                batch.update(TABLE_PHOTO, data, where: 'local_id = ?', whereArgs: [item.id]);
                continue;
              }

              var file = await item.originFile;
              if (file == null) {
                log('No file found for ${item.id}');
                continue;
              }

              // TODO: This is run for photos that are both local and remote, but it shouldn't be. It should only be for new photos

              // TODO: This takes a while on first run, so provide a notification or something with progress
              // TODO: Do we need to wait for this to finish before listing local photos? I don't think so
              log('Generating checksum for ${file.path}');

              var hash = convert(rHash.filePath(HashType.blake3(), file.path));

              // If we already have the checksum, but it's not a local photo, it means we have it as a remote photo
              if (checksums.containsKey(hash)) {
                batch.update(TABLE_PHOTO, data, where: 'id = ?', whereArgs: [checksums[hash]]);
                continue;
              }

              // Otherwise, we need to actually just insert the local photo
              batch.insert(TABLE_PHOTO, {
                ...data,
                'local_id': item.id,
                'checksum': hash,
                'created_at': item.createDateTime.millisecondsSinceEpoch
              });
            }

            await batch.commit();
          }
        }

        // Now remove any old local photos from the database that no longer exist
        var deleted = await database.delete(TABLE_PHOTO,
            where: 'touched_at != ? AND remote_id IS NULL',
            whereArgs: [startedAt.millisecondsSinceEpoch]);

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

  CancelableOperation<void> syncPhotos(
      Function(UploadProgress?) onNext,
      Function(UploadProgress) onDone,
      Function(Object, [StackTrace?]) onError) {
    return CancelableOperation.fromFuture(Future(() async {
      await onNext(UploadProgress(UploadStatus.STARTING, 1, 1));

      var startedAt = DateTime.now();

      await enumerateLocalPhotos(startedAt, onError).valueOrCancellation();
      await uploadAllPhotos(onNext, onDone, onError).valueOrCancellation();
    }), onCancel: () async {
      cancelSync = true;
      // TODO: 0, 1?
      await onNext(UploadProgress(UploadStatus.CANCELLING, 0, 1));
    });
  }

  CancelableOperation<void> uploadAllPhotos(
      Function(UploadProgress?) onNext,
      Function(UploadProgress) onDone,
      Function(Object, [StackTrace?]) onError) {
    int done = 0;
    int total = 1;

    return CancelableOperation.fromFuture(Future(() async {
      log('Uploading all photos');

      // Refresh the list of all the remote photos, so we have their checksums
      await reloadPhotos();

      try {
        var result = await PhotoManager.requestPermissionExtend();
        if (result != PermissionState.authorized) {
          // TODO
          await onError(Exception(
              'Permission is required to access your photos! Please try again.'));
          return;
        }

        var database = await Database.writable();

        var existingChecksums =
            this.photos.where((element) => element.location == PhotoLocation.Remote).map((e) => e.checksum).toSet();

        // If any images with the same checksum exist, we don't need to upload them
        var photosToUpload =
            (await database.query(TABLE_PHOTO, columns: ['item_id', 'checksum']))
                .where((e) => !existingChecksums.contains(e['checksum']))
                .toList();

        total = photosToUpload.length;

        for (var photo in photosToUpload) {
          if (cancelSync) {
            return;
          }

          await onNext(UploadProgress(UploadStatus.RUNNING, done, total));

          log('Uploading ${photo['item_id']}');

          var item = await AssetEntity.fromId(photo['item_id'] as String);
          if (item == null) {
            continue;
          }

          var file = await item.file;
          if (file == null) {
            continue;
          }

          var formData = FormData.fromMap({
            'image': await MultipartFile.fromFile(file.path,
                filename: await item.titleAsync),
            'modified_at': file.lastModifiedSync().toIso8601String()
          });

          try {
            var response = await dio.postUri(
                Uri.http(HOSTNAME, '/photos/api/v1/photos/upload/'),
                data: formData,
                options: Options(headers: {'Authorization': AUTH_HEADER}));
          } catch (e, stackTrace) {
            log('Unable to upload ${photo['item_id']}', error: e, stackTrace: stackTrace);
          }

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

  Future assignPersonToFaceCluster(int cluster, int person) async {
    log('Assigning the person $person to the face cluster $cluster');

    var response = await dio.patchUri(Uri.http(HOSTNAME, '/photos/api/v1/face-clusters/$cluster/'), data: {
      'person': {
        'id': person
      }
    }, options: Options(headers: {
      'Authorization': AUTH_HEADER
    }));

    if (response.statusCode != 200 && response.statusCode != 204) {
      // TODO
      throw Exception('Oh no');
    }
  }


}

class CurrentPhotoModel extends ChangeNotifier {
  final PhotosModel photosModel;

  CurrentPhotoModel({ required this.photosModel });

  Photo? currentPhoto;

  void setCurrentPhoto(double? page) {
    // TODO: Should probably debounce this, as it fires on every 0.05 of a page swipe
    if (page == null) {
      return;
    }

    currentPhoto = photosModel.photos[page.round()];
    notifyListeners();
  }
}

class Album {
  final int id;
  final String name;
  final String description;
  final int numberOfPhotos;

  Album(
      {required this.id,
      required this.name,
      required this.description,
      required this.numberOfPhotos});

  factory Album.fromMap(Map<String, dynamic> map) {
    var photos = List.from(map['photos']);

    return Album(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        numberOfPhotos: photos.length,
    );
  }
}

class Area {
  final String? area;
  final String? country;
  int numberOfPhotos;

  Area(
      {required this.area,
      required this.country,
      required this.numberOfPhotos});
}

class FaceCluster {
  final int id;
  final List<Face> faces;
  final String montage;
  final String status;

  FaceCluster({required this.id, required this.faces, required this.montage, required this.status});

  factory FaceCluster.fromMap(Map<String, dynamic> map) {
    var faces = List.from(map['faces']).map((e) => Face.fromMap(e)).toList();

    return FaceCluster(
      id: map['id'],
      faces: faces,
      montage: map['montage'],
      status: map['status']
    );
  }
}

class Face {
  final int id;
  final String thumb;
  // TODO: These shouldn't be nullable
  final int? width;
  final int? height;
  final int? photo;

  Face({required this.id, required this.thumb, required this.width, required this.height, required this.photo });

  factory Face.fromMap(Map<String, dynamic> map) {
    var photo = map['photo'] == null
      ? null
      : map['photo']['id'];

    return Face(id: map['id'], thumb: map['thumb'], width: map['width'], height: map['height'], photo: photo);
  }
}

class Person {
  final int id;
  final String fullName;
  final String preferredName;
  final List<Face> faces;

  Person({required this.id, required this.fullName, required this.preferredName, required this.faces});

  factory Person.fromMap(Map<String, dynamic> map) {
    var faces = List.from(map['faces']).map((e) => Face.fromMap(e)).toList();

    return Person(
      id: map['id'],
      fullName: map['full_name'],
      preferredName: map['preferred_name'],
      faces: faces
    );
  }
}

class Place {
  final int id;
  final String name;
  final String category;
  final String type;
  final String? amenity;
  final String? locality;
  final String? area;
  final String? country;
  final int numberOfPhotos;
  final int? coverPhoto;

  Place(
      {required this.id,
      required this.name,
      required this.category,
      required this.type,
      required this.amenity,
      required this.locality,
      required this.area,
      required this.country,
      required this.numberOfPhotos,
      required this.coverPhoto});

  factory Place.fromMap(Map<String, dynamic> map) {
    var photos = List.from(map['photos']);

    return Place(
        id: map['id'],
        name: map['name'] ?? '',
        category: map['category'],
        type: map['type'],
        amenity: map['amenity'],
        locality: map['locality'],
        area: map['area'],
        country: map['address_country'],
        numberOfPhotos: photos.length,
        coverPhoto: photos.isEmpty ? null : photos.first['id']);
  }
}

enum PhotoLocation {
  Local,
  Remote,
}

class Photo {
  final int id;
  final String? localId;
  final int? remoteId;
  final String name;
  final bool favourite;
  final String? caption;
  final PhotoLocation location;
  final int width;
  final int height;
  final int? placeId;
  final String checksum;
  final Map<String, dynamic>? exifData;
  final DateTime modifiedAt;
  final DateTime uploadedAt;

  Photo(
      {required this.id,
      this.localId,
      this.remoteId,
      required this.name,
      this.favourite = false,
      this.caption,
      required this.location,
      required this.width,
      required this.height,
      this.placeId,
      required this.checksum,
      required this.exifData,
      required this.modifiedAt,
      required this.uploadedAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo &&
          runtimeType == other.runtimeType &&
          checksum == other.checksum;

  @override
  int get hashCode => checksum.hashCode;

  factory Photo.fromDatabase(Map<String, dynamic> map) {
    return Photo(
        id: map['id'], // TODO
        localId: map['local_id'],
        remoteId: map['remote_id'] == null ? null : int.parse(map['remote_id']),
        name: map['name'],
        favourite: map['favourite'] == 1,
        caption: map['caption'],
        location: map['location'] == 'local' ? PhotoLocation.Local : PhotoLocation.Remote,
        width: map['width'],
        height: map['height'],
        placeId: map['place'] == null ? null : map['place']['id'],
        checksum: map['checksum'],
        exifData: map['exif_data'],
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modified_at']),
        uploadedAt: DateTime.fromMillisecondsSinceEpoch(map['touched_at']));
  }

  factory Photo.fromLocal(Map<String, dynamic> map) {
    return Photo(
        id: map['id'],
        localId: map['local_id'] as String?,
        // TODO: Name needs to be inserted into the database, so we can use it here
        name: '',
        location: PhotoLocation.Local,
        // TODO: Dimensions need to be inserted into the database, so we can use them here
        width: 0,
        height: 0,
        checksum: map['checksum'] as String,
        exifData: null, // TODO
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        uploadedAt: DateTime.fromMillisecondsSinceEpoch(map['touched_at'] as int)
    );
  }

  factory Photo.fromRemote(Map<String, dynamic> map) {
    return Photo(
        id: -1, // TODO
        remoteId: map['id'],
        name: map['name'],
        favourite: map['favourite'],
        caption: map['caption'],
        location: PhotoLocation.Remote,
        width: map['width'],
        height: map['height'],
        placeId: map['place'] == null ? null : map['place']['id'],
        checksum: map['checksum'],
        exifData: map['exif_data'],
        modifiedAt: DateTime.parse(map['modified_at']),
        uploadedAt: DateTime.parse(map['uploaded_at']));
  }

  Map<String, dynamic> toMap({String? localId, int? remoteId}) {
    return {
      'local_id': localId ?? this.localId,
      'remote_id': remoteId ?? this.remoteId,
      'name': name,
      'favourite': favourite ? 1 : 0,
      'caption': caption,
      'location': location == PhotoLocation.Local ? 'local' : 'remote',
      'width': width,
      'height': height,
      'place_id': placeId,
      'checksum': checksum,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'created_at': uploadedAt.millisecondsSinceEpoch
    };
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

  get percent {
    if (complete == 0 && total == 0) {
      return 100;
    }

    return (progress * 100).round();
  }

  get progress {
    if (complete == 0 && total == 0) {
      return 100.0;
    }

    return (1 / total) * complete;
  }
}
