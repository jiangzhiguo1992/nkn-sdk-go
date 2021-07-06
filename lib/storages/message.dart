import 'dart:convert';
import 'dart:typed_data';

import 'package:nkn_sdk_flutter/utils/hex.dart';
import 'package:nmobile/common/db.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/message.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageStorage with Tag {
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
    await db.execute('CREATE INDEX index_messages_pid ON $tableName (pid)');
    await db.execute('CREATE INDEX index_messages_msg_id ON $tableName (msg_id)');
    await db.execute('CREATE INDEX index_messages_target_id ON $tableName (target_id)');
    await db.execute('CREATE INDEX index_messages_msg_id_type ON $tableName (msg_id, type)');
    await db.execute('CREATE INDEX index_messages_is_outbound_is_read ON $tableName (is_outbound, is_read)');
    await db.execute('CREATE INDEX index_messages_target_id_is_outbound_is_read ON $tableName (target_id, is_outbound, is_read)');
    await db.execute('CREATE INDEX index_messages_target_id_type_send_time ON $tableName (target_id, type, send_time)');
  }

  Future<MessageSchema?> insert(MessageSchema? schema) async {
    if (schema == null) return null;
    try {
      Map<String, dynamic> map = schema.toMap();
      int? id = await db?.insert(tableName, map);
      if (id != null && id > 0) {
        schema = MessageSchema.fromMap(map);
        logger.d("$TAG - insert - success - schema:$schema");
        return schema;
      }
      logger.w("$TAG - insert - empty - schema:$schema");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<bool> delete(String msgId) async {
    if (msgId.isEmpty) return false;
    try {
      int? result = await db?.delete(
        tableName,
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (result != null && result > 0) {
        logger.d("$TAG - delete - success - msgId:$msgId");
        return true;
      }
      logger.w("$TAG - delete - empty - msgId:$msgId");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> deleteByType(String msgId, String contentType) async {
    if (msgId.isEmpty || contentType.isEmpty) return false;
    try {
      int? result = await db?.delete(
        tableName,
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      if (result != null && result > 0) {
        logger.d("$TAG - deleteByType - success - msgId:$msgId - contentType:$contentType");
        return true;
      }
      logger.w("$TAG - deleteByType - empty - msgId:$msgId - contentType:$contentType");
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  // Future<int> deleteList(List<MessageSchema>? list) async {
  //   if (list == null || list.isEmpty) return 0;
  //   try {
  //     Batch? batch = db?.batch();
  //     for (MessageSchema schema in list) {
  //       batch?.delete(
  //         tableName,
  //         where: 'msg_id = ?',
  //         whereArgs: [schema.msgId],
  //       );
  //     }
  //     List<Object?>? results = await batch?.commit();
  //     int count = 0;
  //     if (results != null && results.isNotEmpty) {
  //       for (Object? result in results) {
  //         if (result != null && (result as int) > 0) {
  //           count += result;
  //         }
  //       }
  //     }
  //     if (count >= list.length) {
  //       logger.d("$TAG - deleteList - success - count:$count");
  //       return count;
  //     } else if (count > 0) {
  //       logger.w("$TAG - deleteList - lost - lost:${list.length - count}");
  //       return count;
  //     }
  //     logger.w("$TAG - deleteList - empty - list:$list");
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return 0;
  // }

  Future<MessageSchema?> queryByPid(Uint8List? pid) async {
    if (pid == null || pid.isEmpty) return null;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'pid = ?',
        whereArgs: [pid],
      );
      if (res != null && res.length > 0) {
        MessageSchema schema = MessageSchema.fromMap(res.first);
        logger.d("$TAG - queryByPid - success - pid:$pid - schema:$schema");
        return schema;
      }
      logger.d("$TAG - queryByPid - empty - pid:$pid ");
    } catch (e) {
      handleError(e);
    }
    return null;
  }

  Future<List<MessageSchema>> queryList(String? msgId) async {
    if (msgId == null || msgId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryList - empty - msgId:$msgId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryList - success - msgId:$msgId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<List<MessageSchema>> queryListByType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListByType - empty - msgId:$msgId - contentType:$contentType");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListByType - success - msgId:$msgId - contentType:$contentType - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<int> queryCountByType(String? msgId, String? contentType) async {
    if (msgId == null || msgId.isEmpty || contentType == null || contentType.isEmpty) return 0;
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'msg_id = ? AND type = ?',
        whereArgs: [msgId, contentType],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("$TAG - queryCount - msgId:$msgId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListCanDisplayReadByTargetId(String? targetId, {int offset = 0, int limit = 20}) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'target_id = ? AND NOT type = ?', // AND NOT type = ?
        whereArgs: [targetId, ContentType.piece], // , ContentType.receipt],
        offset: offset,
        limit: limit,
        orderBy: 'send_time desc',
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListCanReadByTargetId - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListCanReadByTargetId - success - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  // Future<List<MessageSchema>> queryListUnRead() async {
  //   try {
  //     List<Map<String, dynamic>>? res = await db?.query(
  //       tableName,
  //       columns: ['*'],
  //       where: 'is_outbound = ? AND is_read = ?', // AND NOT type = ?', // AND NOT type = ?',
  //       whereArgs: [0, 0], // , ContentType.piece], // , ContentType.receipt],
  //     );
  //     if (res == null || res.isEmpty) {
  //       logger.d("$TAG - queryListUnRead - empty");
  //       return [];
  //     }
  //     List<MessageSchema> result = <MessageSchema>[];
  //     String logText = '';
  //     res.forEach((map) {
  //       MessageSchema item = MessageSchema.fromMap(map);
  //       logText += "\n$item";
  //       result.add(item);
  //     });
  //     logger.d("$TAG - queryListUnRead- length:${result.length} - items:$logText");
  //     return result;
  //   } catch (e) {
  //     handleError(e);
  //   }
  //   return [];
  // }

  Future<int> unReadCount() async {
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'is_outbound = ? AND is_read = ?', // AND NOT type = ?', //  AND NOT type = ?',
        whereArgs: [0, 0], // , ContentType.piece], // , ContentType.receipt],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("$TAG - unReadCount - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<List<MessageSchema>> queryListUnReadByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return [];
    try {
      List<Map<String, dynamic>>? res = await db?.query(
        tableName,
        columns: ['*'],
        where: 'target_id = ? AND is_outbound = ? AND is_read = ?', // AND NOT type = ?', // AND NOT type = ?',
        whereArgs: [targetId, 0, 0], // , ContentType.piece], // , ContentType.receipt],
      );
      if (res == null || res.isEmpty) {
        logger.d("$TAG - queryListUnReadByTargetId - empty - targetId:$targetId");
        return [];
      }
      List<MessageSchema> result = <MessageSchema>[];
      String logText = '';
      res.forEach((map) {
        MessageSchema item = MessageSchema.fromMap(map);
        logText += "\n$item";
        result.add(item);
      });
      logger.d("$TAG - queryListUnReadByTargetId - targetId:$targetId - length:${result.length} - items:$logText");
      return result;
    } catch (e) {
      handleError(e);
    }
    return [];
  }

  Future<int> unReadCountByTargetId(String? targetId) async {
    if (targetId == null || targetId.isEmpty) return 0;
    try {
      var res = await db?.query(
        tableName,
        columns: ['COUNT(id)'],
        where: 'target_id = ? AND is_outbound = ? AND is_read = ?', // AND NOT type = ?', //  AND NOT type = ?',
        whereArgs: [targetId, 0, 0], // , ContentType.piece], // , ContentType.receipt],
      );
      int? count = Sqflite.firstIntValue(res ?? <Map<String, dynamic>>[]);
      logger.d("$TAG - unReadCountByTargetId - targetId:$targetId - count:$count");
      return count ?? 0;
    } catch (e) {
      handleError(e);
    }
    return 0;
  }

  Future<bool> updatePid(String? msgId, Uint8List? pid) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'pid': pid != null ? hexEncode(pid) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("$TAG - updatePid - count:$count - msgId:$msgId - pid:$pid}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateSendTime(String? msgId, DateTime? sendTime) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'send_time': sendTime?.millisecondsSinceEpoch ?? DateTime.now(),
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("$TAG - updateSendTime - count:$count - msgId:$msgId - sendTime:$sendTime}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateOptions(String? msgId, Map<String, dynamic>? options) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'options': options != null ? jsonEncode(options) : null,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("$TAG - updateOptions - count:$count - msgId:$msgId - options:$options}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateDeleteTime(String? msgId, DateTime? deleteTime) async {
    if (msgId == null || msgId.isEmpty) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'delete_time': deleteTime?.millisecondsSinceEpoch,
        },
        where: 'msg_id = ?',
        whereArgs: [msgId],
      );
      logger.d("$TAG - updateDeleteTime - count:$count - msgId:$msgId - deleteTime:$deleteTime}");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }

  Future<bool> updateMessageStatus(MessageSchema? schema) async {
    if (schema == null) return false;
    try {
      int? count = await db?.update(
        tableName,
        {
          'is_outbound': schema.isOutbound ? 1 : 0,
          'is_send_error': schema.isSendError ? 1 : 0,
          'is_success': schema.isSuccess ? 1 : 0,
          'is_read': schema.isRead ? 1 : 0,
        },
        where: 'msg_id = ?',
        whereArgs: [schema.msgId],
      );
      logger.d("$TAG - updateMessageStatus - schema:$schema");
      return (count ?? 0) > 0;
    } catch (e) {
      handleError(e);
    }
    return false;
  }
}
