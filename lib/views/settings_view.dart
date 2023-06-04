// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_hue/domain/repos/bridge_discovery_repo.dart';
import 'package:flutter_hue/domain/repos/flutter_hue_maintenance_repo.dart';
import 'package:flutter_hue/flutter_hue.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:wayki2/services/hue.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box("settings").listenable(),
      builder: (BuildContext context, box, Widget? child) {
        return SettingsList(sections: [
          SettingsSection(
            tiles: [
              SettingsTile.switchTile(
                initialValue: box.get("hue-enabled", defaultValue: false) as bool,
                onToggle: (v) {
                  box.put("hue-enabled", v).then((value) => HueService.instance.initialise());
                },
                title: Text("Philipps Hue Integration"),
                leading: Icon(FontAwesomeIcons.lightbulb),
              )
            ],
            title: Text("Co-Actions"),
          ),
          if (box.get("hue-enabled", defaultValue: false))
            SettingsSection(
              tiles: [
                SettingsTile.navigation(
                  leading: Icon(FontAwesomeIcons.microchip),
                  title: Text("Bridge"),
                  description: Text(box.get("hue-bridge", defaultValue: "No bridge selected")),
                  trailing: TextButton(onPressed: () {
                    var initialContext = context;
                    showDialog(context: context, builder: (context) => Dialog(
                      child: TextField(onSubmitted: (s) {
                        Navigator.pop(context);
                        showBridgeConnecting(initialContext, s);
                      },),
                    ));
                  }, child: Text("Manual IP"),),
                  onPressed: (context) {
                    showSearchBridgesDialog(context);
                  },
                ),
                if (HueService.instance.bridge != null) SettingsTile.navigation(
                  leading: Icon(FontAwesomeIcons.groupArrowsRotate),
                  title: Text("Selected Room"),
                  description: Text(box.get("hue-room", defaultValue: "No room selected")),
                  onPressed: (context) async {
                    var network = HueNetwork(bridges: [HueService.instance.bridge!]);
                    await network.fetchAllType(ResourceType.room);
                    await network.fetchAllType(ResourceType.groupedLight);
                    var selectedRoom = await showSearch(context: context, delegate: RoomSearchDelegate(network.rooms));
                    if (selectedRoom != null) {
                      box.put("hue-room", selectedRoom.id);
                      await HueService.instance.initialise();
                    }
                  },
                ),
                if (HueService.instance.room != null) SettingsTile.navigation(
                  leading: Icon(FontAwesomeIcons.flask),
                  title: Text("Test Alarm"),
                  onPressed: (context) async {
                    HueService.instance.alarm();
                  },
                )
              ],
              title: Text("Philipps Hue"),
            )
        ]);
      },
    );
  }

  void showBridgeConnecting(BuildContext context, String bridgeIp) => showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: 256 + 128,
            child: FutureBuilder<Bridge?>(
              future: BridgeDiscoveryRepo.firstContact(bridgeIpAddr: bridgeIp),
              builder: (context,snapshot) {
                if (!snapshot.hasData) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Connecting to bridge...", style: Theme.of(context).textTheme.titleMedium),
                      Text("Please press the bridge button",  style: Theme.of(context).textTheme.bodyMedium),
                      SizedBox(
                        height: 16,
                      ),
                      CircularProgressIndicator()
                    ],
                  );
                }

                if (snapshot.data == null) {
                  return Text("Connection failed!");
                }
                Hive.box("settings").put("hue-bridge", snapshot.data!.bridgeId)
                    .then((value) => HueService.instance.initialise())
                    .then((value) => Navigator.pop(context));
                return Text("Connection successful! Seting up hue service...");
              },
            ),
          )
      )
    )
  );

  Future<dynamic> showSearchBridgesDialog(BuildContext context) {
    var initialContext = context;
    return showDialog(
      context: context,
      builder: (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 256 + 128,
                child: FutureBuilder<List<String>>(
                    future: BridgeDiscoveryRepo.discoverBridges(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Searching for Bridges...", style: Theme.of(context).textTheme.titleMedium,),
                            SizedBox(
                              height: 16,
                            ),
                            CircularProgressIndicator()
                          ],
                        );
                      }

                      return Wrap(
                        runAlignment: WrapAlignment.center,
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: snapshot.data!
                            .map((e) => ActionChip(
                                onPressed: () {
                                  Navigator.pop(context);
                                  print("Selected $e");
                                  showBridgeConnecting(initialContext, e);
                                },
                                label: Text(e)))
                            .toList(),
                      );
                    }),
              ),
            ),
          ));
  }
}


class RoomSearchDelegate extends SearchDelegate<Room> {
  List<Room> rooms;

  RoomSearchDelegate(this.rooms);

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
    return ListView(
      children: rooms
          .map((e) => ListTile(
        title: Text(e.metadata.name),
        subtitle: Text(e.metadata.archetype.name),
        onTap: () {
          close(context, e);
        },
      )).toList(),
    );
  }

}