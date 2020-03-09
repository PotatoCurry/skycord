import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart';

extension TextUtils on String {
  bool isNullOrBlank() {
    return this == null || this.trim().isEmpty;
  }
}

extension ContextUtils on CommandContext {
  Future<MessageReceivedEvent> nextMessageByAuthor() {
    return nextMessagesWhere((event) => event.message.author == author).first;
  }
}
