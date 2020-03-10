import 'dart:io';

import 'package:nyxx/Vm.dart' hide User;
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart' hide User;
import 'package:skyscrapeapi/data_types.dart';

import 'extensions.dart';
import 'skycord_user.dart';

final skycordUsers = Map<Snowflake, SkycordUser>();

main() async {
  final bot = NyxxVm(Platform.environment["SKYCORD_DISCORD_TOKEN"]);
  CommandsFramework(bot, prefix: "s!")..discoverCommands();

  bot.onReady.first.then((event) => print("Bot ready"));
}

@Command("help")
Future<void> help(CommandContext ctx) async {
  ctx.reply(content: "s!help - Display a help message\n"
      "s!login - Interactive login (Does not work in DMs)\n"
      "s!oldlogin [skyward url] [username] [password] - Login to skycord\n"
      "s!roulette - Display a random assignment");
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
  final skycordUser = SkycordUser()
    ..skywardUrl = skywardUrl
    ..username = username
    ..password = password;

  await ctx.channel.send(content: "Validating credentials...");
  ctx.channel.startTypingLoop();
  try {
    final user = await skycordUser.getSkywardUser();
    skycordUsers[ctx.author.id] = skycordUser;
    ctx.channel.send(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.channel.send(content: "Login failed");
  } finally {
    ctx.channel.stopTypingLoop();
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
  ctx.channel.startTypingLoop();
  final skycordUser = SkycordUser()
    ..skywardUrl = splitContent[1]
    ..username = splitContent[2]
    ..password = splitContent[3];

  try {
    final user = await skycordUser.getSkywardUser();
    skycordUsers[ctx.author.id] = skycordUser;
    ctx.reply(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.reply(content: "Login failed");
  } finally {
    ctx.channel.stopTypingLoop();
  }
}

@Command("roulette", typing: true)
Future<void> roulette(CommandContext ctx) async {
  if (skycordUsers.containsKey(ctx.author.id)) {
    final skycordUser = skycordUsers[ctx.author.id];
    final user = await skycordUser.getSkywardUser();
    final gradebook = await user.getGradebook();
    final assignments = await gradebook.quickAssignments;
    final assignment = await assignments.random();
    final assignmentDetails = await user.getAssignmentDetailsFrom(assignment);
    final skywardName = await user.getName();
    final embed = EmbedBuilder()
      ..title = "${assignment.assignmentName} (${assignment.getIntGrade() ?? "Empty"})"
      ..description
      ..timestamp = DateTime.now().toUtc()
      ..addAuthor((author)  {
        author.name = skywardName;
        author.iconUrl = ctx.author.avatarURL();
      })
      ..addFooter((footer) { // TODO: Add icon
        footer.text = "Powered by SkyScrapeAPI";
      });
    for (AssignmentProperty property in assignmentDetails)
      embed.addField(name: property.infoName, content: property.info.isNullOrBlank() ? "Empty" : property.info, inline: true);

    ctx.reply(embed: embed);
  } else {
    ctx.reply(content: "Not yet registered");
  }
}

@Command("battle")
Future<void> battle(CommandContext ctx) async {
  if (!skycordUsers.containsKey(ctx.author.id)) {
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
  if (!skycordUsers.containsKey(opponent.id)) {
    ctx.reply(content: opponent.mention + " hasn't registered with skycord");
    return;
  }
  ctx.reply(content: "Do you accept this challenge, ${opponent.mention}? (Y/N)");
  final response = (await ctx.nextMessageBy(opponent)).message.content;
  if (response.toUpperCase().startsWith("Y")) {
    await ctx.reply(content: "Let the battle begin!");
    ctx.channel.startTypingLoop();
  } else {
    ctx.reply(content: opponent.mention + " declined to battle");
    return;
  }

  final skywardAuthor = await skycordUsers[ctx.author.id].getSkywardUser();
  final skywardOpponent = await skycordUsers[opponent.id].getSkywardUser();
//  await skywardAuthor;
//  await skywardOpponent;
  final authorHistory = await skywardAuthor.getHistory();
  final opponentHistory = await skywardOpponent.getHistory();
  final authorClasses = authorHistory.take(authorHistory.length - 1)
      .expand((schoolYear) => schoolYear.classes);
  final opponentClasses = opponentHistory.take(authorHistory.length - 1)
      .expand((schoolYear) => schoolYear.classes);
  // Original idea was to find common classes - too many naming discrepancies
  //  final commonClasses = authorClasses.where(
  //          (histClass) =>
  //              opponentClasses.map((cls) => cls.name).contains(histClass.name)
  //  );
  final authorClass = authorClasses.random() as HistoricalClass;
  final opponentClass = opponentClasses.random() as HistoricalClass;
  final authorGrade = int.tryParse(authorClass.grades.last) ?? authorClass.grades.last;
  final opponentGrade = int.tryParse(opponentClass.grades.last) ?? opponentClass.grades.last;
  if (authorGrade is int && opponentGrade is int) {
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
    ctx.reply(content:
        "$winner's higher grade of $winnerGrade in $winnerClass"
        " wins over $loser's grade of $loserGrade in $loserClass"
    );
  } else {
    ctx.reply(content:
        "${ctx.author.mention} achieved a $authorGrade in ${authorClass.name},"
        " while ${opponent.mention} achieved a $opponentGrade in ${opponentClass.name}"
    );
  }
  ctx.channel.stopTypingLoop();
}
