import 'package:hive_flutter/hive_flutter.dart';
import 'package:wayki2/services/process.dart';

abstract class Action {
  void execute();
}

class FileAction extends Action {
  String file;

  FileAction(this.file);

  @override
  void execute() {
    ProcessService.execFile(file);
  }
}

class ScriptAction extends Action {
  String scriptId;
  ScriptAction(this.scriptId);

  @override
  void execute() {
    var script = Hive.box("scripts").get(scriptId);
    ProcessService.execScript(script);
  }
}

class NoopAction extends Action {
  @override
  void execute() {

  }
}