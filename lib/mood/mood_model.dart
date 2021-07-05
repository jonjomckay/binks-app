import 'dart:developer';

import 'package:binks/database.dart';
import 'package:binks/extensions/iterables.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

String toDateString(DateTime date) {
  var d = date.day.toString().padLeft(2, '0');
  var m = date.month.toString().padLeft(2, '0');
  var y = date.year.toString().padLeft(4, '0');

  return '$y-$m-$d';
}

class Mood {
  final DateTime date;
  final int? mood;
  final String? comment;
  final Set<Tag> tags;

  Mood({required this.date, this.mood, this.comment, required this.tags});

  factory Mood.fromMap(Map<String, dynamic> map, Set<Tag> tags) {
    return Mood(
      date: DateTime.parse(map['date']),
      comment: map['comment'],
      mood: map['mood'],
      tags: tags
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': toDateString(date),
      'comment': comment,
      'mood': mood,
    };
  }
}

class Tag {
  final int id;
  final String tag;

  Tag({required this.id, required this.tag});

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'],
      tag: map['tag'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag': tag,
    };
  }
}

class MoodModel extends ChangeNotifier {
  Future<Map<DateTime, Mood>> listMoods(int numberOfDates) async {
    log('Loading all moods');

    var database = await Database.readOnly();

    // TODO: Limit this
    var result = await database.rawQuery('SELECT m.date, m.comment, m.mood, t.id AS t_id, t.tag AS t_tag FROM $TABLE_MOOD m LEFT JOIN $TABLE_MOOD_TAG mt ON mt.mood_date = m.date LEFT JOIN $TABLE_TAG t ON mt.tag_id = t.id ORDER BY m.date DESC LIMIT $numberOfDates');

    return result.groupBy((e) => e['date']).map((key, value) {
      Set<Tag> tags = Set();

      if (value.first['t_id'] != null) {
        // If we have any tags, map them
        tags = value
            .map((e) => Tag(id: e['t_id'] as int, tag: e['t_tag'] as String))
            .toSet();
      }

      var mood = Mood.fromMap(value.first, tags);

      return MapEntry(mood.date, mood);
    });
  }

  Future saveMood(Mood mood) async {
    log('Saving mood for ${mood.date}');

    var database = await Database.writable();

    await database.insert(TABLE_MOOD, mood.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

    notifyListeners();
  }

  Future saveMoodComment(DateTime date, String comment) async {
    log('Saving mood comment for $date');

    var database = await Database.writable();

    var exists = sqflite.Sqflite.firstIntValue(await database.query(TABLE_MOOD, where: 'date = ?', whereArgs: [toDateString(date)]));
    if (exists == 0) {
      await database.insert(TABLE_MOOD, {
        'date': toDateString(date),
        'comment': comment
      });
    } else {
      await database.update(TABLE_MOOD, {
        'date': toDateString(date),
        'comment': comment
      }, where: 'date = ?', whereArgs: [toDateString(date)]);
    }

    notifyListeners();
  }

  Future saveMoodTags(DateTime date, List<Tag> tags) async {
    log('Saving mood tags for $date');

    var database = await Database.writable();

    var batch = database.batch();

    // Remove any existing tags for the mood
    batch.delete(TABLE_MOOD_TAG, where: 'mood_date = ?', whereArgs: [toDateString(date)]);

    // Add the current set of tags
    for (var tag in tags) {
      batch.insert(TABLE_MOOD_TAG, {
        'mood_date': toDateString(date),
        'tag_id': tag.id
      });
    }

    await batch.commit();

    notifyListeners();
  }

  Future ensureMood(DateTime date) async {
    log('Ensuring mood record exists for $date');

    var database = await Database.writable();

    await database.insert(TABLE_MOOD, Mood(date: date, tags: Set()).toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
  }

  Future<Mood> findMood(DateTime date) async {
    log('Loading mood for $date');

    var database = await Database.readOnly();

    Set<Tag> tags = Set();

    var result = await database.rawQuery('SELECT m.date, m.comment, m.mood, t.id AS t_id, t.tag AS t_tag FROM $TABLE_MOOD m LEFT JOIN $TABLE_MOOD_TAG mt ON mt.mood_date = m.date LEFT JOIN $TABLE_TAG t ON mt.tag_id = t.id WHERE m.date = ?', [toDateString(date)]);
    if (result.first['t_id'] != null) {
      // If we have any tags, map them
      tags = result
          .map((e) => Tag(id: e['t_id'] as int, tag: e['t_tag'] as String))
          .toSet();
    }

    return Mood.fromMap(result.first, tags);
  }
}
