import 'dart:developer';

import 'package:binks/database.dart';
import 'package:binks/mood/mood_model.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class TagModel extends ChangeNotifier {
  Future<List<Tag>> listTags(DateTime date) async {
    log('Loading tags for $date');

    var database = await Database.readOnly();

    return (await database.query(TABLE_TAG, orderBy: 'tag ASC'))
        .map((e) => Tag.fromMap(e))
        .toList(growable: false);

    //
    // var moodTags = (await database.query(TABLE_MOOD_TAG, where: 'mood_date = ?', whereArgs: [toDateString(date)]))
    //     .map((e) => e['tag_id'] as int)
    //     .toList(growable: false);
    //
    // return (await database.query(TABLE_TAG, orderBy: 'tag ASC'))
    //     .map((e) => Tag.fromMap({
    //   ...e,
    //   'selected': moodTags.contains(e['id']) ? 1 : 0 // TODO
    // }))
    //     .toList(growable: false);
  }

  Future saveTag(String name) async {
    log('Saving tag with the name $name');

    var database = await Database.writable();

    // TODO: Use an object
    await database.insert(TABLE_TAG, {
      'tag': name
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.fail);

    notifyListeners();
  }
}