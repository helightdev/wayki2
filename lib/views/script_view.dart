import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/powershell.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:wayki2/services/process.dart';

class ScriptView extends StatelessWidget {
  const ScriptView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ValueListenableBuilder(
              valueListenable: Hive.box("scripts").listenable(),
              builder: (BuildContext context, Box<dynamic> value, Widget? child) {
                var model = ScriptModel(context);
                return AsyncPaginatedDataTable2(
                  header: Row(children: [
                    const Text("Scripts")
                  ],),
                  columns: const [DataColumn2(label: Text("Name"))],
                  source: model,
                  wrapInCard: false,
                  actions: [IconButton.filledTonal(onPressed: () async {
                    var dataKey = const Uuid().v4();
                    await Hive.box("scripts").put(dataKey, "echo Hello World!");
                    if (context.mounted) {
                      showDialog(context: context, builder: (context) => SingleScriptView(dataKey: dataKey));
                      model.refreshDatasource();
                    }
                  }, icon: const Icon(Icons.add)),
                    IconButton.filledTonal(onPressed: () async {
                      Navigator.pop(context);
                    }, icon: const Icon(Icons.exit_to_app))
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ScriptModel extends AsyncDataTableSource {
  BuildContext context;

  ScriptModel(this.context);

  @override
  Future<AsyncRowsResponse> getRows(int start, int end) async {
    var box = Hive.box("scripts");
    var keys = box.keys.toList();
    var selection = keys.skip(start).take(end - start).map((e) => MapEntry(e as String, box.get(e) as String)).toList();

    return AsyncRowsResponse(
        keys.length,
        selection
            .map((e) => DataRow2(
                    cells: [
                      DataCell(Text(e.key)),
                    ],
                    onTap: () {
                      showDialog(context: context, builder: (context) => SingleScriptView(dataKey: e.key));
                    }))
            .toList());
  }
}

class SingleScriptView extends StatefulWidget {
  final String dataKey;

  const SingleScriptView({Key? key, required this.dataKey}) : super(key: key);

  @override
  State<SingleScriptView> createState() => _SingleScriptViewState();
}

class _SingleScriptViewState extends State<SingleScriptView> {
  late CodeController controller;
  late String dataKey;

  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey();

  @override
  void initState() {
    dataKey = widget.dataKey;
    var content = Hive.box("scripts").get(dataKey, defaultValue: "");
    controller = CodeController(
      text: content,
      language: Platform.isWindows ? powershell : bash,
    );
    controller.analyzeCode();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(controller: TextEditingController(text: dataKey), onSubmitted: (s) async {
            var previousKey = dataKey;
            var content = controller.text;
            dataKey = s;
            await Hive.box("scripts").put(dataKey, content);
            await Hive.box("scripts").delete(previousKey);
          },),
          actions: [
            IconButton.filledTonal(onPressed: () {
              ProcessService.execScript(controller.text);
            }, icon: Icon(Icons.play_arrow)),
            SizedBox(width: 8,),
            IconButton.filledTonal(onPressed: () {
              Hive.box("scripts").put(dataKey, controller.text);
              var ref = messengerKey.currentState!.showSnackBar(const SnackBar(content: Text("Script saved!")));
              Future.delayed(Duration(milliseconds: 500)).then((value) {
                try {ref.close();}catch(_){}
              });
              }, icon: Icon(Icons.save)),
            SizedBox(width: 8,),
            IconButton.filledTonal(onPressed: () {
              Hive.box("scripts").delete(dataKey);
              Navigator.pop(context);
            }, icon: Icon(Icons.delete)),
            SizedBox(width: 16,)
          ],
        ),
        body: ValueListenableBuilder(
            valueListenable: Hive.box("scripts").listenable(),
            builder: (context, box, _) {
              var value = box.get(dataKey);
              controller.text = value;
              return CodeTheme(
                  data: CodeThemeData(styles: darculaTheme),
                  child: CodeField(
                      expands: true,
                      controller: controller
                  ));
            }),
      ),
    );
  }
}
