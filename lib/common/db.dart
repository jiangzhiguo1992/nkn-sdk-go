import 'package:nmobile/common/contact/contact.dart';
import 'package:nmobile/helpers/error.dart';
import 'package:nmobile/schema/contact.dart';
import 'package:nmobile/storages/contact.dart';
import 'package:nmobile/storages/device_info.dart';
import 'package:nmobile/storages/message.dart';
import 'package:nmobile/storages/session.dart';
import 'package:nmobile/storages/topic.dart';
import 'package:nmobile/utils/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DB {
  static const String NKN_DATABASE_NAME = 'nkn';
  static int currentDatabaseVersion = 4;
  static Database? currentDatabase;

  String publicKey;

  DB({required this.publicKey});

  static Future<Database> _openDB(String publicKey, String password) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    logger.i("DB - path:$path - key:$publicKey - pwd:$password");
    var db = await openDatabase(
      path,
      password: password,
      version: currentDatabaseVersion,
      singleInstance: true,
      onCreate: (Database db, int version) async {
        logger.i("DB - create - version:$version");
        await ContactStorage.create(db, version);
        await TopicStorage.create(db, version);
        // await SubscriberRepo.create(db, version);
        await SessionStorage.create(db, version);
        await MessageStorage.create(db, version);
        await DeviceInfoStorage.create(db, version);

        // create contact me
        try {
          ContactSchema? contactMe = await ContactSchema.createByType(publicKey, type: ContactType.me);
          if (contactMe == null) return;
          Map<String, dynamic> contactMap = await contactMe.toMap();
          int id = await db.insert(ContactStorage.tableName, contactMap);
          logger.i("DB - contact me insert schema:${id > 0 ? contactMe : null}");
        } catch (e) {
          handleError(e);
        }
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        logger.i("DB - upgrade - old:$oldVersion - new:$newVersion");
        // TODO:GG index sync
        // TODO:GG deviceInfo create
        // TODO:GG session data move
        // TODO:GG topic fields change
        // TODO:GG delete message(receipt) + read message(piece + contactOptions)
        // TODO:GG take care old version any upgrade
        // if (newVersion >= dataBaseVersionV2) {
        //   await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
        //   await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
        // }
        // if (newVersion >= dataBaseVersionV3 && oldVersion == 2){
        //   await TopicRepo.updateTopicTableToV3(db);
        //   await SubscriberRepo.updateTopicTableToV3(db);
        // }
        if (oldVersion < 4 && newVersion >= 4) {
          await SessionStorage.create(db, newVersion);
        }
      },
      onOpen: (Database db) async {
        logger.i("DB - open");
      },
    );
    // await NKNDataManager.upgradeTopicTable2V3(db, dataBaseVersionV3);
    // await NKNDataManager.upgradeContactSchema2V3(db, dataBaseVersionV3);
    // await NKNDataManager.updateSubscriberV3ToV4(db);

    return db;
  }

  static open(String publicKey, String password) async {
    //if (currentDatabase != null) return; // bug!
    currentDatabase = await _openDB(publicKey, password);
  }

  close() async {
    await currentDatabase?.close();
    currentDatabase = null;
  }

  delete() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, '${NKN_DATABASE_NAME}_$publicKey.db');
    try {
      await deleteDatabase(path);
    } catch (e) {
      logger.e('DB - Close db error', e);
    }
  }
}
