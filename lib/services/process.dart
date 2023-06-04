import 'dart:convert';
import 'dart:io';

class ProcessService {

  static Future execFile(String file) async {
    if (Platform.isLinux) {
      await Process.run("xdg-open", [file]);
    } else {
      await Process.run("powershell", ["-Command", "start", file]);
    }
  }

  static void execScript(String content) async {
    File file;
    if (Platform.isLinux) {
      file = File("exec.sh");
      file.writeAsStringSync(content);
      await Process.run(file.absolute.path, []);
      file.deleteSync();
    } else {
      file = File("exec.ps1");
      file.writeAsStringSync(content);
      await execFile(file.absolute.path);
      //file.deleteSync();
    }
  }

}