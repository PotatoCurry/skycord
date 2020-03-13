import 'package:hive/hive.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'main.dart';

part 'skycord_user.g.dart';

@HiveType()
class SkycordUser extends HiveObject {
  @HiveField(0)
  String discordId;

  @HiveField(1)
  String skywardUrl;

  @HiveField(2)
  String username;

  @HiveField(3)
  String password;

  @HiveField(4)
  bool isSubscribed = false;

  Future<User> getSkywardUser() async {
    if (!cachedLogins.containsKey(discordId)) {
      final skywardUser = await SkyCore.login(username, password, skywardUrl);
      cachedLogins[discordId] = skywardUser;
    }
    return cachedLogins[discordId];
  }
}
