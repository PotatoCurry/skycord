import 'package:hive/hive.dart';
import 'package:nyxx/nyxx.dart' as Nyxx;
import 'package:skyscrapeapi/sky_core.dart';

import 'extensions.dart';

part 'skycord_user.g.dart';

@HiveType(typeId: 0)
class SkycordUser extends HiveObject {
  // Hive field 0 was intended to store Discord IDs, but was never used

  @HiveField(1)
  String _skywardUrl;

  @HiveField(2)
  String _username;

  @HiveField(3)
  String _password;

  @HiveField(4)
  bool isSubscribed;

  SkycordUser(
      this._skywardUrl,
      this._username,
      this._password,
      {this.isSubscribed = true}
  );

  User _skywardUser;

  List<Assignment> _previousAssignments;

  List<Assignment> _previousEmptyAssignments = List();

  Future<Nyxx.User> getDiscordUser(Nyxx.Nyxx bot) async {
    return bot.getUser(Nyxx.Snowflake(key));
  }

  Future<User> getSkywardUser() async {
    return _skywardUser ??= await SkyCore.login(
        _username,
        _password,
        _skywardUrl
    );
  }

  Future<List<Assignment>> getNewAssignments() async {
    final skywardUser = await getSkywardUser();
    final gradebook = await skywardUser.getGradebook(forceRefresh: true);
    final assignments = gradebook.getAllAssignments();
    final newlyFilledAssignments = _getNewlyFilledAssignments(assignments);
    final newlyEnteredAssignments = _getNewlyEnteredAssignments(assignments);
    return newlyFilledAssignments + newlyEnteredAssignments;
  }

  List<Assignment> _getNewlyEnteredAssignments(List<Assignment> assignments) {
    if (_previousAssignments == null) {
      _previousAssignments = assignments;
      return List();
    }
    List<Assignment> newlyEnteredAssignments = assignments
        .where((assignment) => !_previousAssignments.contains(assignment) && assignment.getDecimal() != null)
        .toList();
    _previousAssignments = assignments;
    return newlyEnteredAssignments;
  }

  List<Assignment> _getNewlyFilledAssignments(List<Assignment> assignments) {
    final emptyAssignments = assignments
        .where((assignment) => assignment.isNotGraded())
        .toList();
    final newlyFilledAssignments = _previousEmptyAssignments
        .where((assignment) => !emptyAssignments.contains(assignment))
        .toList();
    _previousEmptyAssignments = emptyAssignments;
    return newlyFilledAssignments;
  }
}
