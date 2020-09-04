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
      {this.isSubscribed = false}
  );

  User _skywardUser;

  List<Assignment> _previousEmptyAssignments = List();

  Map<String, Assignment> _previousRecentAssignments = Map();

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

  List<Assignment> _getNewlyFilledAssignments(List<Assignment> assignments) {
    final emptyAssignments = assignments
        .where((assignment) => assignment.isNotGraded())
        .toList();
    final newAssignments = _previousEmptyAssignments
        .where((assignment) => !emptyAssignments.contains(assignment))
        .toList();
    _previousEmptyAssignments = emptyAssignments;
    return newAssignments;
  }

  List<Assignment> _getNewlyEnteredAssignments(List<Assignment> assignments) {
    Map<String, List<Assignment>> assignmentsByClass = Map();
    for (final assignment in assignments) {
      assignmentsByClass.putIfAbsent(assignment.courseID, () => List());
      assignmentsByClass[assignment.courseID]
        ..add(assignment);
    }
    final newAssignments = List<Assignment>();
    for (final recentGrade in _previousRecentAssignments.entries) {
      final classAssignments = assignmentsByClass[recentGrade.key];
      final newClassAssignments = classAssignments
          .sublist(classAssignments.indexOf(recentGrade.value) + 1);
      newAssignments.addAll(newClassAssignments);
    }
    _previousRecentAssignments = assignmentsByClass
        .map((courseId, assignments) => MapEntry(courseId, assignments.last));
    return newAssignments;
  }
}
