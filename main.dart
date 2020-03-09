import 'dart:io';
import 'dart:math';

import 'package:nyxx/Vm.dart' hide User;
import 'package:nyxx/nyxx.dart' hide User;
import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

main() async {
  final users = Map(); // TODO: Persist data
  final bot = NyxxVm(Platform.environment["SKYCORD_DISCORD_TOKEN"]);

  bot.onMessageReceived.listen((MessageEvent e) async {
    if (e.message.content == "s!help") {
      e.message.channel.send(content: "s!help - Display a help message\n"
                                      "s!login [username] [password] - Login to skycord\n"
                                      "s!roulette - Display a random assignment");
    } else if (e.message.content.startsWith("s!login")) {
      e.message.channel.send(content: "Validating credentials...");
      final splitContent = e.message.content.split(" ");
      final userDetails = UserDetails()
        ..skywardUrl = "https://skyward-fbprod.iscorp.com/scripts/wsisa.dll/WService=wsedufortbendtx/seplog01.w"
        ..username = splitContent[1]
        ..password = splitContent[2]
        ..channelId = e.message.channel.id;

      final skyward = await SkyCore(userDetails.skywardUrl);
      try {
        final user = await skyward.loginWith(userDetails.username, userDetails.password);
        e.message.channel.send(content: "Logged in as " + await user.getName());
        userDetails.skywardUser = user;
        users[e.message.author.id] = userDetails;
      } catch (error) {
        e.message.channel.send(content: "Failed to login");
      }
    } else if (e.message.content == "s!roulette") {
      if (users.containsKey(e.message.author.id)) {
        e.message.channel.send(content: "gimme a sec");
        final userDetails = users[e.message.author.id];
        final user = userDetails.skywardUser as User;
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

class UserDetails {
  String skywardUrl;

  String username;

  String password;

  Snowflake channelId;

  Assignment lastAssignment;

  User skywardUser;
}

extension TextUtils on String {
  bool isNullOrBlank() {
    return this == null || this.trim().isEmpty;
  }
}
