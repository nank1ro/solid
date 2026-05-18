import 'dart:async';
import 'dart:math';

import '../domain/models.dart';

/// In-process mock chat backend. No network, no persistence — just timers and
/// random data. Behaves like a chat server would behave: streams of incoming
/// messages, typing bursts, presence flips, system notices, and a send call
/// that occasionally fails.
class ChatBackend {
  ChatBackend({int? seed}) : _rng = Random(seed);

  final Random _rng;
  int _msgCounter = 0;

  /// Per-channel broadcast controller for the typing-users stream. The
  /// stream is written to from two sources: the background "noise" loop in
  /// [typingUsers] (random users start typing then stop, even when no
  /// message follows) and the [incomingMessages] coroutine (every incoming
  /// message is preceded by ~1.5s of the sender's typing state, so the
  /// "X is typing…" indicator always shows before the message lands).
  final Map<String, StreamController<Set<String>>> _typingControllers = {};

  /// Last published typing-users snapshot per channel. Used to merge the
  /// "noise" loop and the message-precursor typing without losing state
  /// when both fire close together.
  final Map<String, Set<String>> _typingState = {};

  StreamController<Set<String>> _typingControllerFor(String channelId) {
    return _typingControllers.putIfAbsent(
      channelId,
      StreamController<Set<String>>.broadcast,
    );
  }

  void _publishTyping(String channelId, Set<String> ids) {
    _typingState[channelId] = ids;
    _typingControllerFor(channelId).add(ids);
  }

  static const seedChannels = <Channel>[
    Channel(id: 'general', name: '#general'),
    Channel(id: 'random', name: '#random'),
    Channel(id: 'dart', name: '#dart'),
    Channel(id: 'solid-help', name: '#solid-help'),
  ];

  static const seedUsers = <User>[
    User(id: 'bot-ada', displayName: 'Ada Lovelace', initials: 'AL'),
    User(id: 'bot-alan', displayName: 'Alan Turing', initials: 'AT'),
    User(id: 'bot-grace', displayName: 'Grace Hopper', initials: 'GH'),
    User(id: 'bot-edsger', displayName: 'Edsger Dijkstra', initials: 'ED'),
    User(id: 'bot-barbara', displayName: 'Barbara Liskov', initials: 'BL'),
    User(id: 'bot-tony', displayName: 'Tony Hoare', initials: 'TH'),
  ];

  static const _botUtterances = <String>[
    'has anyone tried the new build_runner?',
    'reading the docs for the third time and still confused',
    'just shipped a thing — finally',
    'what does this error mean: "type \'Null\' is not a subtype"',
    'time for coffee',
    'is it Friday yet',
    'TIL streams are not lists',
    'rebooted my laptop, it fixed the bug',
    'who broke the build',
    'PR review please when you have a sec',
    'how do you debounce a signal',
    'flutter doctor says I have no problems',
  ];

  Stream<Message> incomingMessages(String channelId) async* {
    while (true) {
      final wait = Duration(seconds: 4 + _rng.nextInt(5));
      await Future<void>.delayed(wait);
      final sender = seedUsers[_rng.nextInt(seedUsers.length)];
      // Announce the sender as "typing" BEFORE yielding the message so the
      // UI always shows "<name> is typing…" right before the new bubble
      // appears. Merge into the existing typing set so concurrent noise
      // events (from [typingUsers]) survive.
      final priorTyping = _typingState[channelId] ?? const <String>{};
      _publishTyping(channelId, {...priorTyping, sender.id});
      await Future<void>.delayed(
        Duration(milliseconds: 1200 + _rng.nextInt(600)),
      );
      yield Message(
        id: 'srv-${_msgCounter++}',
        channelId: channelId,
        senderId: sender.id,
        text: _botUtterances[_rng.nextInt(_botUtterances.length)],
        timestamp: DateTime.now(),
      );
      // Clear ONLY this sender from the typing set; leave any other
      // concurrently-typing users in place.
      final after = {..._typingState[channelId] ?? const <String>{}}
        ..remove(sender.id);
      _publishTyping(channelId, after);
    }
  }

  /// Per-channel typing stream. The ONLY writer is [incomingMessages],
  /// which publishes the sender as "typing" ~1.5s before yielding the
  /// message. There's no background-noise typing — every typing label the
  /// UI shows must be followed by a real message in the same channel,
  /// otherwise the user gets the confusing "X is typing… but no message
  /// arrives" effect.
  Stream<Set<String>> typingUsers(String channelId) {
    return _typingControllerFor(channelId).stream;
  }

  Stream<Map<String, Presence>> presence() async* {
    final state = <String, Presence>{
      for (final u in seedUsers) u.id: Presence.online,
    };
    yield Map.unmodifiable(state);
    while (true) {
      await Future<void>.delayed(Duration(seconds: 5 + _rng.nextInt(5)));
      final user = seedUsers[_rng.nextInt(seedUsers.length)];
      final next = Presence.values[_rng.nextInt(Presence.values.length)];
      state[user.id] = next;
      yield Map.unmodifiable(state);
    }
  }

  Stream<SystemNotice> systemNotices() async* {
    while (true) {
      await Future<void>.delayed(Duration(seconds: 20 + _rng.nextInt(40)));
      final kind = _rng.nextBool()
          ? SystemNoticeKind.info
          : SystemNoticeKind.warning;
      yield SystemNotice(
        kind: kind,
        message: kind == SystemNoticeKind.info
            ? 'Server tick: all systems nominal'
            : 'Connection wobble (reconnected)',
      );
    }
  }

  Future<Message> send(String channelId, String text, String senderId) async {
    final delay = Duration(milliseconds: 300 + _rng.nextInt(500));
    await Future<void>.delayed(delay);
    if (_rng.nextInt(10) == 0) {
      throw Exception('send failed (network blip)');
    }
    return Message(
      id: 'srv-${_msgCounter++}',
      channelId: channelId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );
  }

  void markTyping(String channelId, String userId) {
    // Mock no-op — a real backend would broadcast this to typingUsers
    // subscribers. We don't simulate self-typing because the UI exercises
    // the source-side Effect+Timer pattern regardless.
  }

  void dispose() {
    for (final c in _typingControllers.values) {
      c.close();
    }
    _typingControllers.clear();
    _typingState.clear();
  }
}
