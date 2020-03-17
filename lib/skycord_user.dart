import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart' as Nyxx;
import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'extensions.dart';

part 'skycord_user.g.dart';

@HiveType(typeId: 0)
class SkycordUser extends HiveObject {
  // Hive field 0 was intended to store Discord IDs, but was never used

  @HiveField(1)
  String skywardUrl;

  @HiveField(2)
  String username;

  @HiveField(3)
  String password;

  @HiveField(4)
  bool isSubscribed = false;

  User skywardUser;

  List<Assignment> previousEmptyAssignments = List();

  Future<Nyxx.User> getDiscordUser(Nyxx.Nyxx bot) async {
    return bot.getUser(Nyxx.Snowflake(key));
  }

  Future<User> getSkywardUser() async {
    return skywardUser ??= await SkyCore.login(username, password, skywardUrl);
  }

  Future<List<Assignment>> getNewAssignments() async {
    final skywardUser = await getSkywardUser();
    final gradebook = await skywardUser.getGradebook();
    final emptyAssignments = gradebook.quickAssignments
        .where((assignment) => assignment.isNotGraded())
        .toList();

    final newAssignments = previousEmptyAssignments
        .where((assignment) => !emptyAssignments.contains(assignment))
        .toList();
    previousEmptyAssignments = emptyAssignments;
    return newAssignments;
  }
}
