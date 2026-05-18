import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../domain/models.dart';

class ChannelsController {
  // Seed the collection field directly. Writing to `channels` from a
  // constructor body would trigger solidart's reactive flush, which can
  // re-enter mid-construction when the controller is built lazily from
  // an `@SolidEffect` (via `Provider.create`).
  @SolidState()
  List<Channel> channels = [...ChatBackend.seedChannels];

  @SolidState()
  int get channelCount => channels.length;

  Channel? lookup(String id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }
}
