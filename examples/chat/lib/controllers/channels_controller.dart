import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import '../backend/chat_backend.dart';
import '../domain/models.dart';

class ChannelsController implements Disposable {
  ChannelsController() {
    channels.addAll(ChatBackend.seedChannels);
  }

  final channels = ListSignal<Channel>([], name: 'channels');

  late final channelCount = Computed<int>(
    () => channels.length,
    name: 'channelCount',
  );

  Channel? lookup(String id) {
    for (final c in channels.value) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void dispose() {
    channelCount.dispose();
    channels.dispose();
  }
}
