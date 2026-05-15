enum MessageStatus { pending, confirmed, failed }

class Message {
  const Message({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.confirmed,
  });

  final String id;
  final String channelId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  Message copyWith({String? id, MessageStatus? status}) => Message(
    id: id ?? this.id,
    channelId: channelId,
    senderId: senderId,
    text: text,
    timestamp: timestamp,
    status: status ?? this.status,
  );
}

class User {
  const User({
    required this.id,
    required this.displayName,
    required this.initials,
  });

  final String id;
  final String displayName;
  final String initials;
}

class Channel {
  const Channel({required this.id, required this.name});

  final String id;
  final String name;
}

enum Presence { online, offline, typing }

enum SystemNoticeKind { info, warning }

class SystemNotice {
  const SystemNotice({required this.kind, required this.message});

  final SystemNoticeKind kind;
  final String message;
}
