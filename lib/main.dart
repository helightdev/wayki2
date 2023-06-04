import 'package:flutter/material.dart';
import 'package:flutter_hue/domain/repos/flutter_hue_maintenance_repo.dart';
import 'package:flutter_hue/domain/repos/local_storage_repo.dart';
import 'package:flutter_hue/flutter_hue.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wayki2/blocs/clock_cubit.dart';
import 'package:wayki2/services/hue.dart';
import 'package:wayki2/services/wakelock.dart';
import 'package:wayki2/views/script_view.dart';
import 'package:wayki2/views/timer_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockService.keepAlive();
  FlutterHueMaintenanceRepo.maintainBridges();
  await Hive.initFlutter();
  await Hive.openBox("scripts");
  await Hive.openBox("settings");
  HueService.instance.initialise();
  runApp(const MyApp());
}

RelativeRect getOffsetFromKey(GlobalKey key) {
  var context = key.currentContext!;
  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final offset = renderBox.localToGlobal(Offset.zero);
  final left = offset.dx;
  final top = offset.dy + renderBox.size.height;
  final right = left + renderBox.size.width;
  return RelativeRect.fromLTRB(left, top, right, 0.0);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ClockCubit(),
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const TimerView(),
      ),
    );
  }
}