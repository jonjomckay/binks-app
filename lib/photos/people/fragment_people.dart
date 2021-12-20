import 'package:binks/contacts/contacts_model.dart';
import 'package:binks/extensions/iterables.dart';
import 'package:binks/main.dart';
import 'package:binks/photos/people/fragment_person.dart';
import 'package:binks/photos/photos_model.dart';
import 'package:binks/ui/grids.dart';
import 'package:cool_stepper_reloaded/cool_stepper_reloaded.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_bloc/flutter_form_bloc.dart';
import 'package:provider/provider.dart';

class PeopleClusterAssignCubit extends Cubit<Map<int, int>> {
  PeopleClusterAssignCubit() : super({});

  void assignPerson(int cluster, int person) {
    emit(Map.from(state)..addAll({
      cluster: person
    }));
  }
}

class PeopleClusterAssignScreen extends StatefulWidget {
  const PeopleClusterAssignScreen({Key? key}) : super(key: key);

  @override
  State<PeopleClusterAssignScreen> createState() => _PeopleClusterAssignScreenState();
}

class _PeopleClusterAssignScreenState extends State<PeopleClusterAssignScreen> {
  final Map<int, int> clusterPeople = Map();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Consumer2<PhotosModel, ContactsModel>(
        builder: (context, photosModel, contactsModel, child) {
          var pendingClusters = photosModel.faceClusters.where((c) => c.status == 'pending').toList();

          return BlocProvider(
            create: (context) => PeopleClusterAssignCubit(),
            child: Builder(
              builder: (context) {
                return CoolStepper(
                  isHeaderEnabled: false,
                  hasRoundedCorner: false,
                  config: CoolStepperConfig(
                    backButton: ElevatedButton(
                      onPressed: null,
                      child: Text('Previous'),
                    ),
                    nextButton: ElevatedButton(
                      onPressed: null,
                      child: Text('Next'),
                    ),
                  ),
                  onCompleted: () async {
                    LoadingDialog.show(context);

                    var cubit = context.read<PeopleClusterAssignCubit>();

                    for (var entry in cubit.state.entries) {
                      await photosModel.assignPersonToFaceCluster(entry.key, entry.value);
                    }

                    await photosModel.reloadFaceClusters(notify: true);
                    await photosModel.reloadPeople(notify: true);
                    await contactsModel.reloadContacts();

                    LoadingDialog.hide(context);

                    Navigator.pop(context);
                  },
                  steps: [...pendingClusters.map((e) => CoolStep(
                      content: Material(
                        child: Column(
                          children: [
                            ExtendedImage.network(e.montage, headers: {
                              'Authorization': AUTH_HEADER
                            }),
                            Container(
                              height: 400,
                              child: BlocBuilder<PeopleClusterAssignCubit, Map<int, int>>(
                                builder: (context, state) {
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 160
                                    ),
                                    itemCount: contactsModel.contacts.length,
                                    itemBuilder: (context, index) {
                                      var item = contactsModel.contacts[index];
                                      // var image = ExtendedImage.network(item, width: 96, height: 96, headers: {
                                      //   'Authorization': AUTH_HEADER
                                      // });

                                      return Container(
                                        color: state[e.id] == item.id ? Theme.of(context).focusColor : null,
                                        child: MaterialButton(
                                          onPressed: () => context.read<PeopleClusterAssignCubit>().assignPerson(e.id, item.id),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircleAvatar(backgroundImage: null, radius: 32),
                                              Container(
                                                  margin: const EdgeInsets.only(top: 12),
                                                  child: Text('${item.preferredName}', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                },
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(Icons.person_add),
                              label: Text('New person'),
                              onPressed: () => showDialog(context: context, builder: (context) => NewPersonDialog())
                            )
                          ],
                        ),
                      )
                  ))],
                );
              }
            )
          );
        },
      ),
    );
  }
}

class NewPersonFormBloc extends FormBloc<String, String> {
  final ContactsModel model;

  final fullName = TextFieldBloc(validators: [
    FieldBlocValidators.required
  ]);
  final preferredName = TextFieldBloc(validators: [
    FieldBlocValidators.required
  ]);

  NewPersonFormBloc(this.model) {
    addFieldBlocs(fieldBlocs: [
      fullName,
      preferredName
    ]);
  }

  @override
  void onSubmitting() async {
    try {
      await model.createNewContact(fullName.value, preferredName.value);
      emitSuccess();
    } catch (e, stackTrace) {
      // TODO: Send in failure. Change the errorResponseType in FormBloc<>?
      emitFailure();
    }
  }
}

class LoadingDialog extends StatelessWidget {
  static void show(BuildContext context, {Key? key}) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (_) => LoadingDialog(key: key),
  ).then((_) => FocusScope.of(context).requestFocus(FocusNode()));

  static void hide(BuildContext context) => Navigator.pop(context);

  LoadingDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Center(
        child: Card(
          child: Container(
            width: 80,
            height: 80,
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class NewPersonDialog extends StatefulWidget {
  const NewPersonDialog({Key? key}) : super(key: key);

  @override
  _NewPersonDialogState createState() => _NewPersonDialogState();
}

class _NewPersonDialogState extends State<NewPersonDialog> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ContactsModel>(builder: (context, model, child) {
      return BlocProvider(
        create: (context) => NewPersonFormBloc(model),
        child: Builder(builder: (context) {
          final formBloc = context.read<NewPersonFormBloc>();

          return FormBlocListener<NewPersonFormBloc, String, String>(
            onFailure: (context, state) => LoadingDialog.hide(context),
            onSubmitting: (context, state) => LoadingDialog.show(context),
            onSuccess: (context, state) async {
              Navigator.pop(context);
              LoadingDialog.hide(context);

              // TODO: Select the new person in the list
            },
            child: AlertDialog(
              title: Text('New person'),
              actions: [
                TextButton(onPressed: () async {
                  await formBloc.close();
                  Navigator.pop(context);
                }, child: Text('Cancel')),
                TextButton(onPressed: () async {
                  formBloc.submit();
                }, child: Text('Save')),
              ],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFieldBlocBuilder(
                    textFieldBloc: formBloc.fullName,
                    autofillHints: [AutofillHints.name, AutofillHints.givenName],
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      labelText: 'Full name',
                    ),
                  ),
                  TextFieldBlocBuilder(
                    textFieldBloc: formBloc.preferredName,
                    autofillHints: [AutofillHints.name, AutofillHints.nickname],
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      labelText: 'Preferred name',
                    ),
                  )
                ],
              ),
            ),
          );
        })
      );
    });
  }
}


class FragmentPeople extends StatelessWidget {
  final ScrollController scrollController;

  const FragmentPeople({Key? key, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TODO: This button should disappear and reappear on page switch, not swipe with the page
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.group_add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => PeopleClusterAssignScreen(),
        ))
      ),
      body: Consumer<PhotosModel>(
        builder: (context, model, child) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 8 / 10
            ),
            itemCount: model.people.length,
            itemBuilder: (context, index) {
              var person = model.people[index];
              var biggestFace = person.faces.sorted((a, b) => b.width!.compareTo(a.width!)).first;

              var image = ExtendedImage.network(biggestFace.thumb, headers: {
                'Authorization': AUTH_HEADER
              });

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FragmentPerson(person: person))),
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(backgroundImage: image.image, radius: 44),
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        child: Text(person.preferredName, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)
                      ),
                    ],
                  ),
                ),
              );

              return GridTileWithBackgroundImage(
                image: ExtendedImage.network(biggestFace.thumb, headers: {
                  'Authorization': AUTH_HEADER
                }),
                // TODO: This definitely isn't the right way
                title: person.preferredName,
                subtitle: '${person.faces.length} photos',
                maxTitleLines: 2,
                // subtitle: '${item.numberOfPhotos} $plural',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => FragmentPerson(person: person)));
                },
              );

              return Column(
                children: [
                  ExtendedImage.network(person.faces[0].thumb, headers: {
                    'Authorization': AUTH_HEADER
                  }),
                  Text('${person.preferredName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
