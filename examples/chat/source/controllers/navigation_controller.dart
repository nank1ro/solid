import 'package:solid_annotations/solid_annotations.dart';

import '../domain/models.dart';
import 'channels_controller.dart';

class NavigationController {
  NavigationController({required this.channels});

  final ChannelsController channels;

  @SolidState()
  String? currentChannelId;

  @SolidState()
  Channel? get currentChannel {
    final id = currentChannelId;
    if (id == null) return null;
    return channels.lookup(id);
  }

  void open(String id) {
    currentChannelId = id;
  }

  void closeCurrent() {
    currentChannelId = null;
  }
}
