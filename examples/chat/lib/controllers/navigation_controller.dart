import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import '../domain/models.dart';
import 'channels_controller.dart';

class NavigationController implements Disposable {
  NavigationController({required this.channels});

  final ChannelsController channels;

  final currentChannelId = Signal<String?>(null, name: 'currentChannelId');

  late final currentChannel = Computed<Channel?>(() {
    final id = currentChannelId.value;
    if (id == null) return null;
    return channels.lookup(id);
  }, name: 'currentChannel');

  void open(String id) {
    currentChannelId.value = id;
  }

  void closeCurrent() {
    currentChannelId.value = null;
  }

  @override
  void dispose() {
    currentChannel.dispose();
    currentChannelId.dispose();
  }
}
