// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skycord_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SkycordUserAdapter extends TypeAdapter<SkycordUser> {
  @override
  final typeId = 0;

  @override
  SkycordUser read(BinaryReader reader) {
    var numOfFields = reader.readByte();
    var fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SkycordUser()
      ..skywardUrl = fields[1] as String
      ..username = fields[2] as String
      ..password = fields[3] as String
      ..isSubscribed = fields[4] as bool;
  }

  @override
  void write(BinaryWriter writer, SkycordUser obj) {
    writer
      ..writeByte(4)
      ..writeByte(1)
      ..write(obj.skywardUrl)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.password)
      ..writeByte(4)
      ..write(obj.isSubscribed);
  }
}
