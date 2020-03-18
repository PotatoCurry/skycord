import 'package:nyxx/nyxx.dart' hide User;
import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'extensions.dart';

Future<EmbedBuilder> createAssignmentEmbed(Assignment assignment, User user) async {
  final assignmentDetails = await user.getAssignmentDetailsFrom(assignment);
  final skywardName = await user.getName();

  final embed = EmbedBuilder()
    ..title = "${assignment.assignmentName} (${assignment.getIntGrade() ?? "Empty"})"
    ..description
    ..timestamp = DateTime.now().toUtc()
    ..addAuthor((author)  {
      author.name = skywardName;
//      author.iconUrl = ctx.author.avatarURL(); TODO: Set to student picture
    })
    ..addFooter((footer) { // TODO: Add icon
      footer.text = "Powered by SkyScrapeAPI";
    });
  for (AssignmentProperty property in assignmentDetails) {
    embed.addField(
        name: property.infoName,
        content: property.info.isNullOrBlank() ? "Empty" : property.info, inline: true
    );
  }

  return embed;
}

Future<HistoricalClass> getRandomHistoricalClass(User user) async {
  final authorHistory = await user.getHistory();
  final authorClasses = authorHistory.take(authorHistory.length - 1)
      .expand((schoolYear) => schoolYear.classes)
      .where((histClass) => int.tryParse(histClass.grades.last) != null);
  return authorClasses.random();
}
