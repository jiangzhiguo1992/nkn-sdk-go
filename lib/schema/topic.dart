import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:nmobile/utils/utils.dart';
import 'package:nmobile/utils/path.dart';
import 'package:path/path.dart';

import 'option.dart';

class TopicType {
  static int publicTopic = 1;
  static int privateTopic = 2;
}

class TopicSchema {
  int id;
  String topic;
  File avatar;
  int count;
  DateTime lastUpdatedTime;
  int expireAt;
  bool isTop;
  int topicType;
  bool joined;
  OptionsSchema options;
  String topicName;
  String owner;
  String topicShort;

  TopicSchema({
    this.id,
    this.topic,
    this.avatar,
    this.count,
    this.lastUpdatedTime,
    this.expireAt,
    this.topicType,
    this.isTop = false,
    this.joined = false,
    this.options,
  }) : assert(topic != null && topic.isNotEmpty) {
    topicType = isPrivateTopicReg(topic) ? TopicType.privateTopic : TopicType.publicTopic;
    if (options == null) {
      options = OptionsSchema();
    }
    if (topicType == TopicType.privateTopic) {
      int index = topic.lastIndexOf('.');
      topicName = topic.substring(0, index);
      owner = topic.substring(index + 1);

      topicShort = topicName + '.' + owner.substring(0, 8);
    } else {
      topicName = topic;
      owner = null;

      topicShort = topicName;
    }
  }

  static TopicSchema fromMap(Map<String, dynamic> e) {
    if (e == null) {
      return null;
    }
    var topicSchema = TopicSchema(
      id: e['id'],
      topic: e['topic'],
      joined: e['joined'] == 1,
      count: e['count'],
      topicType: e['type'],
      lastUpdatedTime: e['time_update'] != null ? DateTime.fromMillisecondsSinceEpoch(e['time_update']) : null,
      expireAt: e['expire_at'],
      isTop: e['is_top'] == 1,
    );

    if (e['avatar'] != null && e['avatar'].toString().length > 0) {
      topicSchema.avatar = File(join(Global.applicationRootDirectory.path, e['avatar']));
    }
    if (e['options'] != null) {
      try {
        Map<String, dynamic> options = jsonDecode(e['options']);
        topicSchema.options = OptionsSchema(
          updateBurnAfterTime: options['updateBurnAfterTime'],
          deleteAfterSeconds: options['deleteAfterSeconds'],
          backgroundColor: Color(options['backgroundColor']),
          color: Color(options['color']),
        );
      } on FormatException catch (e) {
        logger.e(e);
      }
    }
    if (topicSchema.options == null) {
      topicSchema.options = OptionsSchema();
    }
    return topicSchema;
  }

  Map<String, dynamic> toMap() {
    if (options == null) {
      options = OptionsSchema();
    }

    Map<String, dynamic> map = {
      'id': id,
      'topic': topic,
      'count': count,
      'avatar': avatar != null ? Path.getLocalContactAvatar(chatCommon.id, avatar.path) : null,
      'options': jsonEncode(options.toMap()),
      'last_updated_time': lastUpdatedTime?.millisecondsSinceEpoch,
      'is_top': isTop ? 1 : 0,
      'expire_at': expireAt,
      'type': topicType,
      'joined': joined,
    };
    return map;
  }

}
