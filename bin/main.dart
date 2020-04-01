import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/Vm.dart' hide User;
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart' hide User;
import 'package:skycord/skycord.dart';
import 'package:skycord/skycord_user.dart';
import 'package:skyscrapeapi/data_types.dart';

import '../lib/extensions.dart';

const boxName = "skyBox";
Box<SkycordUser> skycordUsers;
Nyxx bot;
final log = Logger("skycord");

main() async {
  setupDefaultLogging();

  Hive.registerAdapter(SkycordUserAdapter());
  log.info("Initializing $boxName");
  Hive.init(boxName);
  skycordUsers = await Hive.openBox<SkycordUser>(boxName);
  log.info("Opened $boxName");

  bot = NyxxVm(Platform.environment["SKYCORD_DISCORD_TOKEN"]);
  CommandsFramework(bot, prefix: "s!")..discoverCommands();
  bot.onReady.first.then((event) => bot.self.setPresence(game: Presence.of("s!help")));

  Timer.periodic(Duration(minutes: 30), (t) async {
    log.fine("Grade notification timer ran");
    for (SkycordUser skycordUser in skycordUsers.values.where((user) => user.isSubscribed)) {
      final discordUser = await skycordUser.getDiscordUser(bot);
      final userInfo = "${discordUser.tag} (${skycordUser.key})";
      log.finer("Checking for new grades for $userInfo");
      try {
        final newAssignments = await skycordUser.getNewAssignments();
        if (newAssignments.isNotEmpty) {
          log.finer("Detected ${newAssignments.length} new assignments for $userInfo");
          final skywardUser = await skycordUser.getSkywardUser();
          for (final assignment in newAssignments) {
            final embed = await createAssignmentEmbed(assignment, skywardUser, discordUser);
            discordUser.send(embed: embed);
          }
        }
      } catch (e) {
        log.severe("Encountered an error checking for new grades for $userInfo", e);
        print(e);
      }
    }
    log.fine("Grade notification timer finished");
  });
}

@Command("help")
Future<void> help(CommandContext ctx) async {
  ctx.reply(content: "s!help - Display a help message\n"
      "s!login - Interactive login\n"
      "s!oldlogin [skyward url] [username] [password] - Login to skycord\n"
      "s!logout - Logout from skycord\n"
      "s!subscribe - Subscribe to grade notifications\n"
      "s!unsubscribe - Unsubscribe from grade notifications\n"
      "s!roulette (tiny) - Display a random assignment\n"
      "s!battle [opponent] - Battle another user on the basis of random class grades\n"
      "\n"
      "Note: s!login is currently broken in direct messages, **use s!oldlogin instead**"
  );
}

@Command("login")
Future<void> login(CommandContext ctx) async {
  if ((await ctx.author.dmChannel) == ctx.channel) {
    ctx.reply(content: "Interactive login is known to have issues in direct messages, use s!oldlogin");
    return;
  }

  ctx.reply(content: "Skyward URL?");
  final skywardUrl = (await ctx.nextMessageByAuthor()).message.content;
  ctx.reply(content: "Username?");
  final username = (await ctx.nextMessageByAuthor()).message.content;
  ctx.reply(content: "Password?");
  final password = (await ctx.nextMessageByAuthor()).message.content;
  final skycordUser = SkycordUser(skywardUrl, username, password);

  await ctx.channel.send(content: "Validating credentials...");
  ctx.channel.startTyping();
  try {
    final user = await skycordUser.getSkywardUser();
    skycordUsers.put(ctx.author.id.id, skycordUser);
    ctx.channel.send(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.channel.send(content: "Login failed");
  }
}

@Command("oldlogin")
Future<void> oldLogin(CommandContext ctx) async {
  final splitContent = ctx.message.content.split(" ");
  if (splitContent.length != 4) {
    ctx.reply(content: "Invalid number of arguments");
    return;
  }
  await ctx.reply(content: "Validating credentials...");
  ctx.channel.startTyping();
  final skycordUser = SkycordUser(
      splitContent[1],
      splitContent[2],
      splitContent[3]
  );

  try {
    final user = await skycordUser.getSkywardUser();
    skycordUsers.put(ctx.author.id.id, skycordUser);
    ctx.reply(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.reply(content: "Login failed");
  }
}

@Command("logout")
Future<void> logout(CommandContext ctx) async {
  if (skycordUsers.containsKey(ctx.author.id.id)) {
    final skycordUser = skycordUsers.get(ctx.author.id.id);
    skycordUser.delete();
    ctx.reply(content: "Logged out");
  } else {
    ctx.reply(content: "Not registered");
  }
}

@Command("subscribe")
Future<void> subscribe(CommandContext ctx) async {
  if (skycordUsers.containsKey(ctx.author.id.id)) {
    final skycordUser = skycordUsers.get(ctx.author.id.id);
    skycordUser..isSubscribed = true;
    skycordUser.save();
    ctx.reply(content: "Subscribed to grade notifications");
  } else {
    ctx.reply(content: "Not yet registered");
  }
}

@Command("unsubscribe")
Future<void> unsubscribe(CommandContext ctx) async {
  if (skycordUsers.containsKey(ctx.author.id.id)) {
    final skycordUser = skycordUsers.get(ctx.author.id.id);
    skycordUser..isSubscribed = false;
    skycordUser.save();
    ctx.reply(content: "Unsubscribed from grade notifications");
  } else {
    ctx.reply(content: "Not yet registered");
  }
}

@Command("search", typing: true)
Future<void> search(CommandContext ctx) async {
  final args = ctx.message.content.split(" ")..removeAt(0);
  if (args.isEmpty) {
    ctx.reply(content: "No search query given");
    return;
  }
  final query = args.join(" ");

  final skycordUser = skycordUsers.get(ctx.author.id.id);
  final user = await skycordUser.getSkywardUser();
  final gradebook = await user.getGradebook();
  final assignments = await gradebook.quickAssignments;

  final assignmentID = int.tryParse(query);
  Iterable<Assignment> matchingAssignments;
  if (assignmentID != null)
    matchingAssignments = assignments.where((assignment) =>
        assignment.assignmentID == assignmentID
    );
  else
    matchingAssignments = assignments.where((assignment) =>
        assignment.name.contains(RegExp(query, caseSensitive: false))
    );
  if (matchingAssignments.isEmpty) {
    ctx.reply(content: "No matching assignments found");
    return;
  }

  final embed = await createAssignmentEmbed(
      matchingAssignments.random(),
      user,
      ctx.author,
      tiny: true
  );
  ctx.reply(embed: embed);
}

@Command("roulette", typing: true)
Future<void> roulette(CommandContext ctx) async {
  if (skycordUsers.containsKey(ctx.author.id.id)) {
    final tiny = ctx.message.content.toLowerCase().contains("tiny");
    final skycordUser = skycordUsers.get(ctx.author.id.id);
    final user = await skycordUser.getSkywardUser();
    final gradebook = await user.getGradebook();
    final assignments = await gradebook.quickAssignments;

    Assignment assignment;
    do {
      assignment = await assignments.random();
    } while (assignment.getIntGrade() == null);
    final embed = await createAssignmentEmbed(
        assignment,
        user,
        ctx.author,
        tiny: tiny
    );
    ctx.reply(embed: embed);
  } else {
    ctx.reply(content: "Not yet registered");
  }
}

@Command("battle")
Future<void> battle(CommandContext ctx) async {
  if (!skycordUsers.containsKey(ctx.author.id.id)) {
    ctx.reply(content: "Not yet registered");
    return;
  }
  if (ctx.message.mentionEveryone) {
    ctx.reply(content: "No");
    return;
  }
  if (ctx.message.mentions.isEmpty) {
    ctx.reply(content: "You need to mention another user");
    return;
  }
  final opponent = ctx.message.mentions.values.first;
  if (ctx.author == opponent) {
    ctx.reply(content: "You can't battle yourself");
    return;
  }
  if (!skycordUsers.containsKey(opponent.id.id)) {
    ctx.reply(content: opponent.mention + " hasn't registered with skycord");
    return;
  }

  ctx.reply(content: "Do you accept this challenge, ${opponent.mention}? (Y/N)");
  final opponentConsents = await ctx.nextMessagesBy(opponent, limit: 10)
      .map((event) => event.message.content.toUpperCase())
      .firstWhere(
          (content) => content.startsWith(RegExp(r"^[YN]")),
          orElse: () => "N"
      ).then((response) => response.startsWith("Y"))
      .timeout(Duration(minutes: 1), onTimeout: () {
          return false;
      });
  if (opponentConsents) {
    await ctx.reply(content: "Let the battle begin!");
    ctx.channel.startTyping();
  } else {
    ctx.reply(content: opponent.mention + " declined to battle");
    return;
  }

  final authorSkywardFuture = skycordUsers.get(ctx.author.id.id).getSkywardUser();
  final opponentSkyward = skycordUsers.get(opponent.id.id).getSkywardUser();
  final authorClassFuture = getRandomHistoricalClass(await authorSkywardFuture);
  final opponentClassFuture = getRandomHistoricalClass(await opponentSkyward);

  final authorClass = await authorClassFuture;
  final opponentClass = await opponentClassFuture;
  final authorGrade = int.parse(authorClass.grades.last);
  final opponentGrade = int.parse(opponentClass.grades.last);

  var winner, winnerClass, winnerGrade;
  var loser, loserClass, loserGrade;
  if (authorGrade > opponentGrade) {
    winner = ctx.author.mention;
    winnerClass = authorClass.name;
    winnerGrade = authorGrade;
    loser = opponent.mention;
    loserClass = opponentClass.name;
    loserGrade = opponentGrade;
  } else {
    winner = opponent.mention;
    winnerClass = opponentClass.name;
    winnerGrade = opponentGrade;
    loser = ctx.author.mention;
    loserClass = authorClass.name;
    loserGrade = authorGrade;
  }

  if (winnerGrade == loserGrade) {
    ctx.reply(content:
        "Both $winner and $loser achieved a $winnerGrade in"
        " $winnerClass and $loserClass, respectively"
    );
  } else {
    ctx.reply(content:
        "$winner's higher grade of $winnerGrade in $winnerClass"
        " wins over $loser's grade of $loserGrade in $loserClass"
    );
  }
}
