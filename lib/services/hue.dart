import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hue/domain/repos/bridge_discovery_repo.dart';
import 'package:flutter_hue/flutter_hue.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HueService {
  
  static HueService instance = HueService();
  
  Bridge? bridge;
  HueNetwork? network;
  Room? room;

  Future alarm() async {
    var groupedLight = room!.servicesAsResources.whereType<GroupedLight>().first;
    var flip = false;
    network!.put();
    int times = 5;
    for (var i = 0; i < times*2; i++) {
      flip = !flip;
      groupedLight.on = LightOn(isOn: flip);
      await network!.put();
      await Future.delayed(Duration(seconds: 1));
    }
    groupedLight.on = LightOn(isOn: true);
    await network!.put();
  }
  
  Future initialise() async {
    var settingsBox = Hive.box("settings");
    if (settingsBox.get("hue-enabled", defaultValue: false)) {
      String? bridgeId = settingsBox.get("hue-bridge", defaultValue: null);
      if (bridgeId == null) {
        log("No bridge configured");
        return;
      }
      var saved = await BridgeDiscoveryRepo.fetchSavedBridges();
      bridge = saved.firstWhereOrNull((element) => element.bridgeId == bridgeId);
      log("Started hue service! (Success: ${bridge != null})");

      if (bridge != null && settingsBox.get("hue-room", defaultValue: null) != null) {
        network = HueNetwork(bridges: [bridge!]);
        await network!.fetchAllType(ResourceType.room);
        await network!.fetchAllType(ResourceType.groupedLight);
        String? selectedRoomId = settingsBox.get("hue-room", defaultValue: null);
        room = network!.rooms.firstWhereOrNull((element) => selectedRoomId == element.id);
        room!.bridge = bridge;
        room!.hueNetwork = network;
        print(room?.hueNetwork);
        if (room != null) {
          log("Room is fully setup!");
        }
      } else {
        log("No room selected");
      }
    }
  }
  
}