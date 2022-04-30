import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:shared_preferences/shared_preferences.dart';

import 'aboutPageWidget.dart';
import 'souvenir.dart';
import 'api/notification_push.dart';
import 'substringFinder.dart';
import 'themes.dart' as themes;

//TODO add a real icon
//TODO save method should merge double saves
//TODO Notifs still dont work (Myb try a free online service?)

void main() {
  AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          defaultColor: Colors.teal,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'scheduled_channel',
          channelName: 'Scheduled Notifications',
          defaultColor: Colors.teal,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
      debug: true);
  runApp(const MeApp());
}

class MeApp extends StatelessWidget {
  const MeApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Blabliblu',
        theme: themes.MainTheme,
        darkTheme: themes.DarkTheme,
        home: MyHomePage(title: 'Blabliblu', storage: CounterStorage()));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title, required this.storage})
      : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final CounterStorage storage;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class CounterStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/counter.txt');
  }

  Future<String> readCounter() async {
    try {
      final file = await _localFile;

      // Read the file
      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      // If encountering an error, return 0
      return "";
    }
  }

  Future<File> writeCounter(String counter) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString(counter);
  }
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  int _counter = 4;
  DateTime today = DateTime.now();

  String filePath = "##############";

  bool showContent = false;
  bool schedulNotifs = false;

  List<TextEditingController> controllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
      controllers.add(TextEditingController());
    });
  }

  void resetCounter() {
    setState(() {
      _counter = 4;
      controllers = [controllers[0], controllers[1], controllers[2]];
    });
  }

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    asyncLoader();
  }

  void asyncLoader() async {
    await Future.delayed(const Duration(milliseconds: 2), () {});
    Directory dir = await getApplicationDocumentsDirectory();
    filePath = dir.path;
    setState(() {
      widget.storage.readCounter().then((String message) {
        if (message != "") {
          inFile = message;
        } else {
          inFile = "{\"Memory\" : [{}";
        }

        final String jsond = inFile + "]}";
        final parsedJson = jsonDecode(jsond);
        final a = Memoir.fromJson(parsedJson);

        if (a.memo.last['Date'].toString() ==
            [today.day, today.month, today.year].toString()) {
          _counter = a.memo.last['souvenirs'].length + 1;
          controllers = [];
          for (int i = 0; i < _counter - 1; i++) {
            controllers.add(TextEditingController());
            controllers.last.text = a.memo.last['souvenirs'][i];
          }
        }

        SharedPreferences.getInstance().then((value) {
          try {
            schedulNotifs =
                value.getBool("notifs")! ? value.getBool("notifs")! : false;
          } catch (e) {
            print(e);
          }
          try {
            showContent =
                value.getBool("contentS")! ? value.getBool("contentS")! : false;
          } catch (e) {
            print(e);
          }
        });

        AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
          if (!isAllowed) {
            showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text("Allow notifications"),
                      content: const Text(
                          "Our app would like to send you notifications"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            createReminderNotification(1, 18, 30);
                            createReminderNotification(2, 18, 30);
                            createReminderNotification(3, 18, 30);
                            createReminderNotification(4, 18, 30);
                            createReminderNotification(5, 18, 30);
                            createReminderNotification(6, 18, 30);
                            createReminderNotification(7, 18, 30);
                          },
                          child: const Text(
                            'Don\'t Allow',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        ),
                        TextButton(
                            onPressed: () => AwesomeNotifications()
                                .requestPermissionToSendNotifications()
                                .then((value) => Navigator.pop(context)),
                            child: const Text(
                              'Allow',
                              style: TextStyle(
                                color: Colors.teal,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ))
                      ],
                    ));
          }
        });
      });
    });
  }

  String inFile = "";

  void showWhatIsInside() {
    widget.storage.readCounter().then((String message) {
      if (message == "{\"Memory\" : [{}") {
        inFile = "{\"Memory\" : [{}";
      }
      saveDay();
      showDialog(
          context: context,
          builder: (context) {
            String value = showContent ? message : "Saved";
            return AlertDialog(content: Text(value));
            // TODO Style alerts
          });
    });
  }

  void saveDay() {
    String jsonResult = inFile;
    String jsond = jsonResult + "]}";
    final parsedJson = jsonDecode(jsond);

    final a = Memoir.fromJson(parsedJson);
    if (a.memo.last['Date'].toString() ==
        [today.day, today.month, today.year].toString()) {
      final indexes = findSubs(inFile, "},{");
      inFile = inFile.substring(0, indexes.last + 1);
      jsond = inFile + "]}";
//now we do some noraml shit
      jsonResult += ",{";
      jsonResult +=
          "\"Date\" : [${today.day},${today.month},${today.year}],\"souvenirs\":[";
      for (int i = 0; i < controllers.length; i++) {
        jsonResult += "\"" + controllers[i].text + "\"";
        if (i < controllers.length - 1) {
          jsonResult += ",";
        }
      }
      jsonResult += "]}";
    } else {
      jsonResult += ",{";
      jsonResult +=
          "\"Date\" : [${today.day},${today.month},${today.year}],\"souvenirs\":[";
      for (int i = 0; i < controllers.length; i++) {
        jsonResult += "\"" + controllers[i].text + "\"";
        if (i < controllers.length - 1) {
          jsonResult += ",";
        }
      }
      jsonResult += "]}";
    }
    widget.storage.writeCounter(jsonResult);
  }

  late AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final Future<String> _waiting = Future<String>.delayed(
      const Duration(seconds: 2),
      () => 'Data Loaded',
    );
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return FutureBuilder<String>(
      future: _waiting, // a previously-obtained Future<String> or null
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        List<Widget> children;
        if (snapshot.hasData) {
          children = [
            Stack(
              children: <Widget>[
                Center(
                  child: Image.asset("assets/images/shamBG.png"),
                ),
                Center(
                  // Center is a layout widget. It takes a single child and positions it
                  // in the middle of the parent.
                  child: Container(
                    //color: Theme.of(context).backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: ListView.builder(
                        itemCount: _counter + 1,
                        itemBuilder: (BuildContext context, int index) {
                          if (index == 0) {
                            return buildDateLabel("${today.day}",
                                "${today.month}", "${today.year}");
                          } else if (index == _counter) {
                            return buildAddButton("oe");
                          }
                          return buildSouvenirCard(controllers[index - 1]);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            )
          ];
        } else if (snapshot.hasError) {
          children = <Widget>[
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Error: ${snapshot.error}'),
            )
          ];
        } else {
          children = const <Widget>[
            Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Awaiting result...'),
            )
          ];
        }
        return Scaffold(
          backgroundColor: Theme.of(context).backgroundColor,
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text(widget.title),
          ),
          drawer: Drawer(
            child: Container(
              color: Theme.of(context).backgroundColor,
              child: ListView(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("Blabliblu",
                            style: Theme.of(context).textTheme.headline1),
                        Text("Every day, just type 3 good things that happend.",
                            style: Theme.of(context).textTheme.headline2),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.info,
                      color: Theme.of(context).textTheme.subtitle2?.color,
                    ),
                    title: Text(
                      "About",
                      style: Theme.of(context).textTheme.subtitle2,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AboutPage(
                                    pathE: filePath,
                                  )));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.history,
                      color: Theme.of(context).textTheme.subtitle2?.color,
                    ),
                    title: Text(
                      "Diary",
                      style: Theme.of(context).textTheme.subtitle2,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HistoryPage(
                                    storage: widget.storage,
                                    fileStor: inFile,
                                    context: context,
                                  )));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.settings,
                      color: Theme.of(context).textTheme.subtitle2?.color,
                    ),
                    title: Text(
                      "Options",
                      style: Theme.of(context).textTheme.subtitle2,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SettingsPage(
                                    storage: widget.storage,
                                    home: this,
                                  )));
                    },
                  ),
                ],
              ),
            ),
          ),
          body: children[0], //normalement c'est bon
          floatingActionButton: FloatingActionButton(
            onPressed: showWhatIsInside,
            tooltip: 'Increment',
            child: const Icon(Icons.check),
          ), // This trailing comma makes auto-formatting nicer for build methods.
        );
      },
    );
  }

  Widget buildSouvenirCard(TextEditingController controller) {
    return Card(
      elevation: 3.0,
      color: Theme.of(context).cardTheme.color,
      child: Container(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 0, 2),
          child: TextField(
            controller: controller,
            maxLines: null,
            style: Theme.of(context).textTheme.headline5,
            decoration: const InputDecoration(
              hintText: "Enter your good moment",
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAddButton(String s) {
    return Card(
      color: Theme.of(context).primaryColor,
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32.0),
        side: BorderSide.none,
      ),
      child: IconButton(
        icon: const Icon(Icons.add),
        color: Theme.of(context).backgroundColor,
        iconSize: 50,
        onPressed: () {
          _incrementCounter();
        },
      ),
    );
  }

  Widget buildDateLabel(String d, String m, String y) {
    return Card(
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        color: Theme.of(context).backgroundColor,
        child: Center(
          child: Text(
            d + "/" + m + "/" + y,
            style: Theme.of(context).textTheme.headline3,
          ),
        ));
  }
}

// ignore: must_be_immutable
class HistoryPage extends StatefulWidget {
  HistoryPage(
      {Key? key,
      required this.storage,
      required this.fileStor,
      required this.context})
      : super(key: key);

  List<String> getValues() {
    return [""];
  }

  CounterStorage storage;
  String fileStor;
  BuildContext context;
  Widget buildSouvenirCard(int D, int M, int Y, List<String> souv) {
    List<Widget> cards = [
      Text(
        "$D/$M/$Y",
        style: Theme.of(context).textTheme.headline4,
      )
    ];
    for (int i = 0; i < souv.length; i++) {
      Widget card = Card(
        elevation: 1,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              souv[i],
              style: Theme.of(context).textTheme.headline5,
            ),
          ),
        ),
      );
      cards.add(card);
    }
    return Card(
        elevation: 0.5,
        color: Theme.of(context).focusColor,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Center(child: Column(children: cards))));
  }

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          title: Text(
            "Diary",
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
        body: ListView(
          children: [
            FutureBuilder<String>(
              future: widget.storage
                  .readCounter(), // a previously-obtained Future<String> or null
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                //List<Widget> days;
                List<Widget> children;
                if (snapshot.hasData) {
                  final String jsond = widget.fileStor + "]}";

                  final parsedJson = jsonDecode(jsond);

                  final b = Memoir.fromJson(parsedJson);

                  final souv = b.memo.sublist(1);

                  List<Widget> finalList = [];
                  for (int i = 0; i < souv.length; i++) {
                    finalList.add(widget.buildSouvenirCard(
                        souv[i]['Date'][0],
                        souv[i]['Date'][1],
                        souv[i]['Date'][2],
                        List<String>.from(souv[i]['souvenirs'])));
                  }
                  finalList.add(Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        "Nothing more to see here, try to write every day to see the lenght of this list getting longer",
                        style: Theme.of(context).textTheme.headline6,
                      )));
                  children = <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).primaryColor,
                      size: 60,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                          child: ListBody(
                        children: finalList,
                      )),
                    ),
                  ];
                } else if (snapshot.hasError) {
                  children = <Widget>[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Error: ${snapshot.error}'),
                    )
                  ];
                } else {
                  children = const <Widget>[
                    SizedBox(
                      child: CircularProgressIndicator(),
                      width: 60,
                      height: 60,
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('Awaiting result...'),
                    )
                  ];
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: children,
                  ),
                );
              },
            ),
          ],
        ));
  }
}

// ignore: must_be_immutable
class SettingsPage extends StatefulWidget {
  SettingsPage({Key? key, required this.storage, required this.home})
      : super(key: key);

  CounterStorage storage;
  _MyHomePageState home;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          title: Text("History", style: Theme.of(context).textTheme.headline2),
        ),
        body: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                "Memory settings",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            TextButton(
                onPressed: () {
                  widget.storage.writeCounter("{\"Memory\":[{}");
                  widget.home.inFile = "{\"Memory\":[{}";
                  // ignore: avoid_print
                  print('or');
                },
                child: const Text(
                  "Delete Memory",
                  style: TextStyle(fontSize: 18),
                )),
            TextButton(
                onPressed: () {
                  widget.home.resetCounter();
                },
                child: const Text(
                  "Reset Memory List Lenght",
                  style: TextStyle(fontSize: 18),
                )),
            //Notifs
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                "Application settings",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            CheckboxListTile(
              title: Text(
                'Animate Slowly',
                style: Theme.of(context).textTheme.subtitle1,
              ),
              value: timeDilation != 1.0,
              onChanged: (bool? value) {
                setState(() {
                  timeDilation = value! ? 3.0 : 1.0;
                });
              },
              secondary: Icon(
                Icons.hourglass_empty,
                color: Theme.of(context).textTheme.subtitle1?.color,
              ),
            ),
            CheckboxListTile(
              title: Text(
                'Show Memory Content (Debug)',
                style: Theme.of(context).textTheme.subtitle1,
              ),
              value: widget.home.showContent,
              onChanged: (bool? value) {
                setState(() {
                  widget.home.showContent = value! ? true : false;
                  SharedPreferences.getInstance().then((value) {
                    value.setBool("contentS", widget.home.showContent);
                  });
                });
              },
              secondary: Icon(
                Icons.ad_units,
                color: Theme.of(context).textTheme.subtitle1?.color,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                "Application settings",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            const Divider(),
            CheckboxListTile(
              title: Text(
                'Send Notifs',
                style: Theme.of(context).textTheme.subtitle1,
              ),
              value: widget.home.schedulNotifs,
              onChanged: (bool? value) {
                setState(() {
                  widget.home.schedulNotifs = value! ? true : false;

                  SharedPreferences.getInstance().then((value) {
                    value.setBool("notifs", widget.home.schedulNotifs);
                  });

                  if (!widget.home.schedulNotifs) {
                    cancelScheduledNotifications();
                  } else {
                    showTimePicker(
                            context: context, initialTime: TimeOfDay.now())
                        .then((TimeOfDay? value) {
                      createReminderNotification(1, value!.hour, value.minute);
                      createReminderNotification(2, value.hour, value.minute);
                      createReminderNotification(3, value.hour, value.minute);
                      createReminderNotification(4, value.hour, value.minute);
                      createReminderNotification(5, value.hour, value.minute);
                      createReminderNotification(6, value.hour, value.minute);
                      createReminderNotification(7, value.hour, value.minute);
                    });
                  }
                });
              },
              secondary: Icon(
                Icons.ad_units,
                color: Theme.of(context).textTheme.subtitle1?.color,
              ),
            ),
          ],
        ));
  }
}
