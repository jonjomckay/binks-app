import 'dart:async';
import 'dart:developer';

import 'package:async_builder/async_builder.dart';
import 'package:binks/mood/mood_constants.dart';
import 'package:binks/mood/mood_model.dart';
import 'package:binks/mood/tag_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class MoodScreen extends StatelessWidget {
  const MoodScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var date = ModalRoute.of(context)!.settings.arguments as DateTime;

    return _MoodScreen(date: date);
  }
}

class _MoodScreen extends StatefulWidget {
  final DateTime date;

  const _MoodScreen({Key? key, required this.date}) : super(key: key);

  @override
  __MoodScreenState createState() => __MoodScreenState();
}

class __MoodScreenState extends State<_MoodScreen> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    MoodModel().ensureMood(widget.date);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TODO
        title: Text('Mood: ${widget.date}'),
      ),
      body: Consumer<TagModel>(
        builder: (context, tagModel, child) {
          return AsyncBuilder<List<Tag>>(
            future: tagModel.listTags(widget.date),
            retain: true,
            waiting: (context) => Center(child: CircularProgressIndicator()),
            builder: (context, tags) {
              return Consumer<MoodModel>(
                builder: (context, moodModel, child) {
                  return AsyncBuilder<Mood>(
                    future: moodModel.findMood(widget.date),
                    retain: true,
                    waiting: (context) => Center(child: CircularProgressIndicator()),
                    builder: (context, mood) {
                      if (mood == null) {
                        // TODO: This should never be possible
                        return Container();
                      }

                      return Column(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            height: 64,
                            child: GridView.count(crossAxisCount: 10, shrinkWrap: true, children: [
                              ...List.generate(10, (index) => Container(
                                margin: mood.mood == index ? EdgeInsets.zero : EdgeInsets.all(6),
                                child: InkWell(
                                  child: CircleAvatar(
                                    child: Text('$index', style: TextStyle(
                                        fontWeight: FontWeight.bold
                                    )),
                                    backgroundColor: MOOD_COLORS[index][0],
                                    foregroundColor: MOOD_COLORS[index][1],
                                  ),
                                  onTap: () async => await moodModel.saveMood(Mood(
                                    comment: mood.comment,
                                    date: widget.date,
                                    mood: index,
                                    tags: Set()
                                  )),
                                ),
                              ))
                            ]),
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: TextFormField(
                              maxLines: 4,
                              initialValue: mood.comment,
                              onChanged: (value) async {
                                if (_debounce?.isActive ?? false) {
                                  _debounce?.cancel();
                                }

                                _debounce = Timer(const Duration(milliseconds: 500), () async {
                                  await moodModel.saveMoodComment(widget.date, value);
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'What happened today?',
                              ),
                            ),
                          ),
                          Container(
                            alignment: Alignment.centerLeft,
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 16,
                              children: [
                                ...(tags ?? []).map((tag) => TagChip(
                                  tag: tag,
                                  selected: mood.tags.map((e) => e.id).toSet(),
                                  onSelected: (tag, selected) async {
                                    List<Tag> tags;
                                    if (selected) {
                                      tags = [
                                        ...mood.tags,
                                        tag
                                      ];
                                    } else {
                                      tags = mood.tags
                                          .where((e) => e.id != tag.id)
                                          .toList();
                                    }

                                    await moodModel.saveMoodTags(widget.date, tags);
                                  },
                                )),
                                TagChip(
                                  icon: Icon(Icons.add, size: 16),
                                  tag: Tag(id: 0, tag: 'Add tag'),
                                  selected: Set(),
                                  onSelected: (tag, selected) {
                                    // TODO: Show dialog, and on save, reload tags from model, but keep state
                                    showDialog(context: context, builder: (context) {
                                      String tagName = '';

                                      return AlertDialog(
                                        title: Text('Add tag'),
                                        content: TextFormField(
                                          autofocus: true,
                                          onChanged: (value) => tagName = value,
                                          decoration: InputDecoration(
                                            hintText: 'Enter a tag name'
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text('Cancel')
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              try {
                                                await tagModel.saveTag(tagName);
                                              } catch (e, stackTrace) {
                                                log('Unable to save the tag', error: e, stackTrace: stackTrace);

                                                if (e is DatabaseException) {
                                                  if (e.isUniqueConstraintError()) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                      content: Text('A tag with that name already exists!'),
                                                    ));
                                                    return;
                                                  }
                                                }

                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                  content: Text('Unable to save the tag: $e'),
                                                ));
                                              }

                                              Navigator.pop(context);
                                            },
                                            child: Text('Save')
                                          )
                                        ],
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final Icon? icon;
  final Tag tag;
  final Set<int> selected;
  final Function(Tag tag, bool selected) onSelected;

  const TagChip({Key? key, required this.tag, required this.selected, required this.onSelected, this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: this.icon,
      label: Text(tag.tag),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: selected.contains(tag.id),
      onSelected: (bool value) {
        this.onSelected(tag, value);
      },
    );
  }
}

