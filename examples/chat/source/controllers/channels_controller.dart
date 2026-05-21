import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../domain/models.dart';

class ChannelsController {
  ChannelsController() {
    channels.addAll(ChatBackend.seedChannels);
  }

  @SolidState()
  List<Channel> channels = [];

  @SolidState()
  int get channelCount => channels.length;

  Channel? lookup(String id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }
}
