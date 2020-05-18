import 'dart:math';

import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart';
import 'package:skyscrapeapi/sky_core.dart' hide User;

extension TextUtils on String {
  bool isBlank() {
    return trim().isEmpty;
  }

  bool isNotBlank() {
    return !isBlank();
  }
}

extension IterableUtils on Iterable {
  T random<T>() {
    return elementAt(Random().nextInt(length));
  }
}

extension ContextUtils on CommandContext {
  Stream<MessageReceivedEvent> nextMessagesBy(User user, {int limit = 100}) {
    return nextMessagesWhere((event) => event.message.author == user, limit: limit);
  }

  Future<MessageReceivedEvent> nextMessageBy(User user) {
    return nextMessagesBy(user).first;
  }

  Future<MessageReceivedEvent> nextMessageByAuthor() {
    return nextMessageBy(author);
  }
}

extension AssignmentUtils on Assignment {
  bool isNotGraded() {
    return attributes["grade"] == null;
  }
}
