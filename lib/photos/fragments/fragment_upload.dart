import 'package:binks/photos/photos_model.dart';
import 'package:binks/sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FragmentUpload extends StatefulWidget {
  const FragmentUpload({Key? key}) : super(key: key);

  @override
  _FragmentUploadState createState() => _FragmentUploadState();
}

class _FragmentUploadState extends State<FragmentUpload> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload')
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: StreamBuilder<UploadProgress?>(
          stream: Sync.instance.syncProgress(),
          builder: (context, snapshot) {
            var progress = snapshot.data;
            if (progress == null) {
              return UploadPending(onClick: () async {
                await Sync.instance.sync();
              });
            }

            return UploadHappening();
          },
        ),
      ),
    );
  }
}

class UploadPending extends StatelessWidget {
  final void Function() onClick;

  const UploadPending({Key? key, required this.onClick}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(Icons.upload),
        label: Text('Start upload'),
        onPressed: onClick,
      ),
    );
  }
}

class UploadHappening extends StatefulWidget {
  const UploadHappening({Key? key}) : super(key: key);

  @override
  _UploadHappeningState createState() => _UploadHappeningState();
}

class _UploadHappeningState extends State<UploadHappening> {

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotosModel>(builder: (context, model, child) {
      return StreamBuilder<UploadProgress?>(
        stream: Sync.instance.syncProgress(),
        builder: (context, snapshot) {
          var progress = snapshot.data;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }

          var error = snapshot.error;
          if (error != null) {
            // TODO
          }

          Widget button = Container();
          switch (progress.status) {
            case UploadStatus.CANCELLED:
            case UploadStatus.ERRORED:
              button = ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Restart'),
                onPressed: () async {
                  await Sync.instance.sync();
                },
              );
              break;
            case UploadStatus.CANCELLING:
              button = ElevatedButton.icon(
                icon: Icon(Icons.cancel),
                label: Text('Cancel'),
                onPressed: null,
              );
              break;
            case UploadStatus.DONE:
            case UploadStatus.UNSTARTED:
              button = ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Sync'),
                onPressed: () async {
                  await Sync.instance.sync();
                },
              );
              break;
            case UploadStatus.RUNNING:
            case UploadStatus.STARTING:
              button = ElevatedButton.icon(
                icon: Icon(Icons.cancel),
                label: Text('Cancel'),
                onPressed: () async {
                  await Sync.instance.stop();
                },
              );
              break;
          }

          Widget progressBar = progress.status == UploadStatus.STARTING
            ? LinearProgressIndicator()
            : LinearProgressIndicator(value: progress.progress);

          Widget progressText;

          if (progress.status == UploadStatus.STARTING) {
            progressText = Text('Starting sync');
          } else if (progress.status == UploadStatus.CANCELLING) {
            progressText = Text('Cancelling sync');
          } else {
            progressText = Text('${progress.complete} / ${progress.total} (${progress.percent}%)');
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: progressBar,
              ),
              progressText,
              button
            ],
          );
        },
      );
    });
  }
}


