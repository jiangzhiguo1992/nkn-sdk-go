import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/schema/session.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage {
  static String get tableName => 'Messages';

  Database? get db => DB.currentDatabase;

  MessageStorage();

  static create(Database db, int version) async {
    // create table
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pid TEXT,
        msg_id TEXT,
        sender TEXT,
        receiver TEXT,
        target_id TEXT,
        type TEXT,
        topic TEXT,
        content TEXT,
        options TEXT,
        is_read BOOLEAN DEFAULT 0,
        is_success BOOLEAN DEFAULT 0,
        is_outbound BOOLEAN DEFAULT 0,
        is_send_error BOOLEAN DEFAULT 0,
        receive_time INTEGER,
        send_time INTEGER,
        delete_time INTEGER
      )''');
    // index
    await db.execute('CREATE INDEX index_messages_pid ON Messages (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id ON Messages (msg_id)');
    await db.execute('CREATE INDEX index_messages_sender ON Messages (sender)');
    await db.execute('CREATE INDEX index_messages_receiver ON Messages (receiver)');
    await db.execute('CREATE INDEX index_messages_target_id ON Messages (target_id)');
    await db.execute('CREATE INDEX index_messages_receive_time ON Messages (receive_time)');
    await db.execute('CREATE INDEX index_messages_send_time ON Messages (send_time)');
    await db.execute('CREATE INDEX index_messages_delete_time ON Messages (delete_time)');
    // query message
    await db.execute('CREATE INDEX index_messages_target_id_is_outbound ON Messages (target_id, is_outbound)');
    await db.execute('CREATE INDEX index_messages_target_id_type ON Messages (target_id, type)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (schema == null) return null;
    // duplicated
    if (schema.contentType != ContentType.piece) {
      List<MessageSchema> exists = await queryListByMsgIdType(schema.msgId, schema.contentType);
      if (exists.isNotEmpty) {
        logger.d("insertMessage - exists:$exists");
        return exists[0];
      }
    }
    // insert
    Map<String, dynamic> map = schema.toMap();
    int? id = await db?.insert(tableName, map);
    if (id != null && id > 0) {
      schema = MessageSchema.fromMap(map);
      logger.d("insertMessage - success - schema:$schema");
      return schema;
    }
    logger.w("insertMessage - fail - schema:$schema");
    return null;
  }

  Future<List<MessageSchema>> queryListByMsgIdType(String? msgId, String? type) async {
    if (msgId == null || msgId.isEmpty || type == null || type.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, type],
      );
      if (res == null || res.isEmpty) {
        logger.d("queryMessagesByMsgIdType - empty - msgId:$msgId - type:$type");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      res.forEach((map) => result.add(MessageSchema.fromMap(map)));
      logger.d("queryMessagesByMsgIdType - success - msgId:$msgId - type:$type - length:${result.length} - items:$result");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<int> queryCountByMsgId(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("queryCountByMsgId - msgId:$msgId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListCanReadByTargetId(String? targetId, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        orderBy: 'send_time desc',
        where: 'target_id = ? AND NOT type = ? AND NOT type = ?',
        whereArgs: [targetId, ContentType.piece, ContentType.receipt],
        limit: limit,
        offset: offset,
      );
      if (res == null || res.isEmpty) {
        logger.d("queryListCanReadByTargetId - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("queryListCanReadByTargetId - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<int> updateDeleteTime(String? msgId, DateTime? deleteTime) async {
    if (msgId == null || msgId.isEmpty) return 0;
    int? count = await db?.update(
      tableName,
      {
        'delete_time': deleteTime?.millisecondsSinceEpoch,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    logger.d("updateDeleteTime - count:$count - msgId:$msgId - deleteTime:$deleteTime}");
    return count ?? 0;
  }

  Future<int> unReadCountByNotSender(String? senderId) async {
    if (senderId == null || senderId.isEmpty) return 0;
    var res = await db?.query(
      tableName,
      columns: ['COUNT(id)'],
      where: 'sender != ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
      whereArgs: [senderId, 0, ContentType.piece, ContentType.receipt],
    );
    int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
    logger.d("unReadCountByNotSender - count:$count");
    return count ?? 0;
  }

  Future<int> unReadCountByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return 0;
    var res = await db?.query(
      tableName,
      columns: ['COUNT(id)'],
      where: 'target_id = ? AND is_read = ? AND NOT type = ? AND NOT type = ?',
      whereArgs: [targetId, 0, ContentType.piece, ContentType.receipt],
    );
    int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
    logger.d("unReadCountByTargetId - count:$count");
    return count ?? 0;
  }

  Future<int> readByMsgId(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return 0;
    int? count = await db?.update(
      tableName,
      {
        'is_read': 1,
      },
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
    return count ?? 0;
  }

  Future<int> readByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return 0;
    int? count = await db?.update(
      tableName,
      {
        'is_read': 1,
      },
      where: 'target_id = ?',
      whereArgs: [targetId],
    );
    return count ?? 0;
  }

  /// TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO

  Future<bool> receiveSuccess(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return false;
    int? result = await db?.update(tableName, {'is_success': 1});
    return result != null ? result > 0 : false;
  }

  /// ContentType is text, textExtension, media, audio counted to not read
  Future<List<SessionSchema>> getLastSession(int skip, int limit) async {
    List<Map<String, dynamic>>? res = await db?.query(
      '$tableName as m',
      columns: [
        'm.*',
        '(SELECT COUNT(id) from $tableName WHERE target_id = m.target_id AND is_outbound = 0 AND is_read = 0 '
            'AND (type = "text" '
            'or type = "textExtension" '
            'or type = "media" '
            'or type = "audio")) as not_read',
        'MAX(send_time)'
      ],
      where: "type = ? or type = ? or type = ? or type = ? or type = ?",
      whereArgs: [
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.image,
        ContentType.audio,
      ],
      groupBy: 'm.target_id',
      orderBy: 'm.send_time desc',
      limit: limit,
      offset: skip,
    );

    List<SessionSchema> list = <SessionSchema>[];
    if (res != null && res.length > 0) {
      for (var i = 0, length = res.length; i < length; i++) {
        var item = res[i];
        SessionSchema? model = await SessionSchema.fromMap(item);
        if (model != null) {
          list.add(model);
        }
      }
    }
    if (list.length > 0) {
      return list;
    }
    return [];
  }

  Future<SessionSchema?> getUpdateSession(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return null;
    List<Map<String, dynamic>>? res = await db?.query(
      '$tableName',
      where: 'target_id = ? AND is_outbound = 0 AND is_read = 0 AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
      whereArgs: [
        targetId,
        ContentType.text,
        ContentType.textExtension,
        ContentType.media,
        ContentType.audio,
        ContentType.image,
      ],
      orderBy: 'send_time desc',
    );

    if (res != null && res.length > 0) {
      Map info = res[0];
      SessionSchema? model = await SessionSchema.fromMap(info);
      model?.notReadCount = res.length;
      return model;
    } else {
      List<Map<String, dynamic>>? countResult = await db?.query(
        '$tableName',
        where: 'target_id = ? AND (type = ? or type = ? or type = ? or type = ? or type = ?)',
        whereArgs: [
          targetId,
          ContentType.text,
          ContentType.textExtension,
          ContentType.media,
          ContentType.audio,
          ContentType.image,
        ],
        orderBy: 'send_time desc',
      );
      if (countResult != null && countResult.length > 0) {
        Map info = countResult[0];
        SessionSchema? model = await SessionSchema.fromMap(info);
        model?.notReadCount = 0;
        return model;
      }
    }
    return null;
  }

  Future<int> deleteTargetChat(String targetId) async {
    return await db?.delete(tableName, where: 'target_id = ?', whereArgs: [targetId]) ?? 0;
  }
}
