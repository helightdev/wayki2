// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wayki2/action.dart';
import 'package:wayki2/blocs/clock_cubit.dart';
import 'package:wayki2/main.dart';
import 'package:wayki2/services/hue.dart';
import 'package:wayki2/services/process.dart';
import 'package:wayki2/services/wakelock.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wayki2/views/script_view.dart';
import 'package:wayki2/views/settings_view.dart';

class TimerView extends StatelessWidget {
  const TimerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wayki2"),
        centerTitle: true,
        actions: [
          IconButton.filledTonal(
              onPressed: () {
                showDialog(context: context, builder: (context) => const SettingsView());
              },
              icon: const Icon(FontAwesomeIcons.gear)),
          const SizedBox(
            width: 8,
          ),
          IconButton.filledTonal(
              onPressed: () {
                showDialog(context: context, builder: (context) => const ScriptView());
              },
              icon: const Icon(FontAwesomeIcons.code)),
          const SizedBox(
            width: 16,
          )
        ],
      ),
      body: BlocBuilder<ClockCubit, ClockState>(
        builder: (context, state) {
          if (state is ClockUnset) {
            return _buildUnset(context);
          } else if (state is ClockRunning) {
            return RunningClock(
              clockState: state,
            );
          }
          return Container();
        },
      ),
    );
  }

  Stack _buildUnset(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SizedBox(
              width: 128,
              height: 128,
              child: CircularProgressIndicator(
                strokeWidth: 12,
                value: 1,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              )),
        ),
        Center(child: Builder(builder: (context) {
          var buttonKey = GlobalKey();
          return GestureDetector(
            key: buttonKey,
            onTap: () async {
              _showStartMenu(context, buttonKey);
            },
            child: Icon(
              Icons.play_arrow,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }))
      ],
    );
  }

  Future<dynamic> _showStartMenu(BuildContext context, GlobalKey<State<StatefulWidget>> buttonKey) {
    return showMenu(context: context, position: getOffsetFromKey(buttonKey), items: [startScriptEntry(context), startFileEntry(context), startNoopEntry(context)]);
  }

  PopupMenuItem<dynamic> startNoopEntry(BuildContext context) {
    return PopupMenuItem(
        onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
            var date = (await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.utc(3000)))!;
            var time = (await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(DateTime.now())))!;
            var target = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            BlocProvider.of<ClockCubit>(context).start(DateTime.now(), target, NoopAction());
          });
        },
        padding: EdgeInsets.zero,
        child: const ListTile(
          title: Text("No Action"),
          leading: SizedBox(width: 32, child: Icon(FontAwesomeIcons.hourglass)),
        ));
  }

  PopupMenuItem<dynamic> startFileEntry(BuildContext context) {
    return PopupMenuItem(
        onTap: () {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
            var result = (await FilePicker.platform.pickFiles())!;
            var date = (await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.utc(3000)))!;
            var time = (await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(DateTime.now())))!;
            var target = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            BlocProvider.of<ClockCubit>(context).start(DateTime.now(), target, FileAction(result.paths.first!));
          });
        },
        padding: EdgeInsets.zero,
        child: const ListTile(
          title: Text("File"),
          leading: SizedBox(width: 32, child: Icon(FontAwesomeIcons.file)),
        ));
  }

  PopupMenuItem<dynamic> startScriptEntry(BuildContext context) {
    return PopupMenuItem(
        onTap: () async {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
            var script = (await showSearch(context: context, delegate: ScriptSearchDelegate()))!;
            var date = (await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.utc(3000)))!;
            var time = (await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(DateTime.now())))!;
            var target = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            BlocProvider.of<ClockCubit>(context).start(DateTime.now(), target, ScriptAction(script));
          });
        },
        padding: EdgeInsets.zero,
        child: const ListTile(
          title: Text("Script"),
          leading: SizedBox(width: 32, child: Icon(FontAwesomeIcons.code)),
        ));
  }
}

class RunningClock extends StatefulWidget {
  final ClockRunning clockState;

  const RunningClock({super.key, required this.clockState});

  @override
  State<RunningClock> createState() => _RunningClockState();
}

class _RunningClockState extends State<RunningClock> {
  bool isCancelled = false;

  @override
  void initState() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isCancelled == true) {
        timer.cancel();
        cancel();
        return;
      }
      if (DateTime.now().isAfter(widget.clockState.target)) {
        timer.cancel();
        cancel();
        widget.clockState.action.execute();
        if (Hive.box("settings").get("hue-enabled", defaultValue: false)) HueService.instance.alarm();
        return;
      }
      WakelockService.keepAlive();
      setState(() {});
    });
    super.initState();
  }

  void cancel() {
    BlocProvider.of<ClockCubit>(context).reset();
    isCancelled = true;
  }

  @override
  void dispose() {
    isCancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var wholeDist = widget.clockState.target.difference(widget.clockState.started).inSeconds.abs();
    var timeLeft = DateTime.now().difference(widget.clockState.target);
    var currentDist = timeLeft.inSeconds.abs();
    print("$wholeDist : $currentDist");
    var passed = currentDist / wholeDist;
    return Stack(
      children: [
        Center(
          child: SizedBox(
              width: 128,
              height: 128,
              child: CircularProgressIndicator(
                strokeWidth: 12,
                value: passed,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              )),
        ),
        Center(child: Builder(builder: (context) {
          var buttonKey = GlobalKey();
          return GestureDetector(
            key: buttonKey,
            onTap: () async {
              cancel();
            },
            child: Icon(
              Icons.stop,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }))
      ],
    );
  }
}

class ScriptSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return null;
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return null;
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    var q = query.toLowerCase().replaceAll(" ", "");
    var ids = Hive.box("scripts").keys.cast<String>().where((element) => element.toLowerCase().replaceAll(" ", "").contains(q)).toList();
    return ListView(
      children: ids
          .map((e) => ListTile(
                title: Text(e),
                onTap: () {
                  close(context, e);
                },
              ))
          .toList(),
    );
  }
}
