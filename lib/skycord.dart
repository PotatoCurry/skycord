import 'package:nyxx/nyxx.dart' as Nyxx;
import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'extensions.dart';

Future<Nyxx.EmbedBuilder> createAssignmentEmbed(Assignment assignment, User skywardUser, Nyxx.User discordUser, {bool tiny = false}) async {
  final assignmentDetails = await skywardUser.getAssignmentDetailsFrom(assignment)
    ..retainWhere((property) => property.info != null && property.info.isNotBlank());
  final skywardInfo = await skywardUser.getStudentProfile();

  final embed = Nyxx.EmbedBuilder()
    ..title = "${assignment.name} (${assignment.getIntGrade() ?? "Empty"})"
    ..timestamp = DateTime.now().toUtc()
    ..addAuthor((author)  {
      author.name = skywardInfo.name;
      author.iconUrl = discordUser.avatarURL();
    })
    ..addFooter((footer) {
      footer.text = "Powered by SkyScrapeAPI";
      footer.iconUrl = "https://clearhall.dev/assets/img/skymobile_icon.png";
    });
  if (tiny) {
    final property = assignmentDetails.first;
    embed.addField(
        name: property.infoName,
        content: property.info
    );
  } else {
    for (AssignmentProperty property in assignmentDetails)
      embed.addField(
          name: property.infoName,
          content: property.info,
          inline: true
      );
  }

  if (skywardInfo.studentAttributes.containsKey("Student Image Href Link"))
    embed.thumbnailUrl = skywardInfo.studentAttributes["Student Image Href Link"];

  return embed;
}

Future<HistoricalClass> getRandomHistoricalClass(User user) async {
  final authorHistory = await user.getHistory();
  final authorClasses = authorHistory.take(authorHistory.length - 1)
      .expand((schoolYear) => schoolYear.classes)
      .where((histClass) => int.tryParse(histClass.grades.last) != null);
  return authorClasses.random();
}
