import 'package:skyscrapeapi/data_types.dart';
import 'package:skyscrapeapi/sky_core.dart';

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
