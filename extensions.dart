import 'dart:math';

import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart';

extension TextUtils on String {
  bool isNullOrBlank() {
    return this == null || this.trim().isEmpty;
  }
}

extension IterableUtils on Iterable {
  T random<T>() {
    return elementAt(Random().nextInt(length));
  }
}

extension ContextUtils on CommandContext {
  Future<MessageReceivedEvent> nextMessageBy(User user) {
    return nextMessagesWhere((event) => event.message.author == user).first;
  }

  Future<MessageReceivedEvent> nextMessageByAuthor() {
    return nextMessageBy(author);
  }
}
