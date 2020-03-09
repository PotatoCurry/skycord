import 'dart:io';
import 'dart:math';

import 'package:nyxx/Vm.dart' hide User;
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart' hide User;
import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

final users = Map<Snowflake, SkycordUser>(); // TODO: Persist data

main() async {
  final bot = NyxxVm(Platform.environment["SKYCORD_DISCORD_TOKEN"], ignoreExceptions: false);
  CommandsFramework(bot, prefix: "s!")..discoverCommands();

  bot.onMessageReceived.listen((MessageEvent e) async {
    if (e.message.content == "s!help") {
      e.message.channel.send(content: "s!help - Display a help message\n"
                                      "s!login - Interactive login (Does not work in DMs)\n"
                                      "s!oldlogin [skyward url] [username] [password] - Login to skycord\n"
                                      "s!roulette - Display a random assignment");
    } else if (e.message.content.startsWith("s!oldlogin")) {
      e.message.channel.send(content: "Validating credentials...");
      final splitContent = e.message.content.split(" ");
      final skycordUser = SkycordUser()
        ..skywardUrl = splitContent[1]
        ..username = splitContent[2]
        ..password = splitContent[3];

      try {
        final user = await skycordUser.getSkywardUser();
        users[e.message.author.id] = skycordUser;
        e.message.channel.send(content: "Logged in as " + await user.getName());
      } catch (error) {
        e.message.channel.send(content: "Login failed");
      }
    } else if (e.message.content == "s!roulette") {
      if (users.containsKey(e.message.author.id)) {
        e.message.channel.send(content: "Fetching grades...");
        final skycordUser = users[e.message.author.id];
        final user = skycordUser.skywardUser;
        final gradebook = await user.getGradebook();
        final assignments = await gradebook.quickAssignments;
        final assignment = await assignments[Random().nextInt(assignments.length)];
        final assignmentDetails = await user.getAssignmentDetailsFrom(assignment);
        final embed = EmbedBuilder()
          ..title = "${assignment.assignmentName} (${assignment.getIntGrade() ?? "Empty"})"
          ..description
          ..timestamp = DateTime.now().toUtc()
          ..addAuthor((author)  {
            author.name = e.message.author.username; // await user.getName();
            author.iconUrl = e.message.author.avatarURL();
          })
          ..addFooter((footer) { // TODO: Add icon
            footer.text = "Powered by SkyScrapeAPI";
          });
        for (AssignmentProperty property in assignmentDetails) {
          embed.addField(name: property.infoName, content: property.info.isNullOrBlank() ? "Empty" : property.info, inline: true);
        }

        e.message.channel.send(embed: embed);
      } else {
        e.message.channel.send(content: "Not yet registered");
      }
    }
  });
}

@Command("login")
login(CommandContext ctx) async {
  ctx.reply(content: "Skyward URL?");
  print('a');
  final skywardUrl = (await ctx.nextMessageByAuthor()).message.content;
  print('b');
  ctx.reply(content: "Username?");
  print('c');
  final username = (await ctx.nextMessageByAuthor()).message.content;
  print('d');
  ctx.reply(content: "Password?");
  print('e');
  final password = (await ctx.nextMessageByAuthor()).message.content;
  print('f');
  final skycordUser = SkycordUser()
    ..skywardUrl = skywardUrl
    ..username = username
    ..password = password;

  ctx.channel.send(content: "Validating credentials...");
  try {
    final user = await skycordUser.getSkywardUser();
    users[ctx.author.id] = skycordUser;
    ctx.channel.send(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.channel.send(content: "Login failed");
  }
}

class SkycordUser {
  String skywardUrl;

  String username;

  String password;

  User skywardUser;

  bool isSubscribed = false;

  Assignment lastAssignment;

  Future<User> getSkywardUser() async {
    if (skywardUser == null) {
      final user = await SkyCore.login(username, password, skywardUrl);
      skywardUser = user;
    }
    return skywardUser;
  }
}

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
