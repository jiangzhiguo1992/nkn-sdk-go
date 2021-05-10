import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_eth.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/detail_nkn.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/theme/theme.dart';
import 'package:nmobile/utils/assets.dart';

class WalletHomeListLayout extends StatefulWidget {
  @override
  _WalletHomeListLayoutState createState() => _WalletHomeListLayoutState();
}

class _WalletHomeListLayoutState extends State<WalletHomeListLayout> {
  // TODO:GG params
  // WalletsBloc _walletsBloc;
  // StreamSubscription _walletSubscription;
  // final GetIt locator = GetIt.instance;
  //
  // double _totalNkn = 0;
  bool _allBackedUp = false;

  //
  // // ignore: non_constant_identifier_names
  // LOG _LOG;

  @override
  void initState() {
    super.initState();
    // TODO:GG bloc
//     _LOG = LOG(tag);
//     locator<TaskService>().queryNknWalletBalanceTask();
//     _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
//     _walletSubscription = _walletsBloc.listen((state) {
//       if (state is WalletsLoaded) {
//         _totalNkn = 0;
//         _allBackedUp = true;
//         state.wallets.forEach((w) => _totalNkn += w.balance ?? 0);
//         state.wallets.forEach((w) {
// //          NLog.d('w.isBackedUp: ${w.isBackedUp}, w.name: ${w.name}');
//           _allBackedUp = w.isBackedUp && _allBackedUp;
//         });
//         setState(() {
// //          NLog.d('_allBackedUp: $_allBackedUp');
//         });
//       }
//     });
  }

  @override
  void dispose() {
    // TODO:GG bloc
    // _walletSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);

    return Layout(
      header: Header(
        titleChild: Padding(
          padding: EdgeInsets.only(left: 20),
          child: Label(
            _localizations.my_wallets,
            type: LabelType.h2,
            color: application.theme.fontLightColor,
          ),
        ),
        childTail: _allBackedUp
            ? SizedBox.shrink()
            : TextButton(
                onPressed: _onNotBackedUpTipClicked,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFF5B800),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _localizations.not_backed_up,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: SkinTheme.bodySmallFontSize, color: application.theme.strongColor),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ],
                ),
                // onPressed: _onNotBackedUpTipClicked,
              ),
        actions: [
          PopupMenuButton(
            icon: assetIcon('more', width: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (int result) async {
              final walletType = await BottomDialog.of(context).showWalletTypeSelect(
                title: _localizations.select_wallet_type,
                desc: _localizations.select_wallet_type_desc,
              );
              switch (result) {
                case 0:
                  // create
                  if (walletType == WalletType.nkn) {
                    Navigator.pushNamed(context, WalletCreateNKNScreen.routeName);
                  } else if (walletType == WalletType.eth) {
                    Navigator.pushNamed(context, WalletCreateETHScreen.routeName);
                  }
                  break;
                case 1:
                  // import
                  if (walletType == WalletType.nkn || walletType == WalletType.eth) {
                    Navigator.pushNamed(context, WalletImportScreen.routeName, arguments: {
                      WalletImportScreen.argWalletType: walletType,
                    });
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 0,
                child: Label(
                  _localizations.no_wallet_create,
                  type: LabelType.display,
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Label(
                  _localizations.import_wallet,
                  type: LabelType.display,
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoaded) {
            return ListView.builder(
              padding: EdgeInsets.only(top: 22, bottom: 86),
              itemCount: state.wallets?.length ?? 0,
              itemBuilder: (context, index) {
                WalletSchema wallet = state.wallets[index];
                if (index == 1) wallet.type = WalletType.eth; // TODO:GG test
                return Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                  child: WalletItem(
                    schema: wallet,
                    type: wallet.type,
                    onTap: () {
                      Navigator.pushNamed(context, WalletDetailNKNScreen.routeName, arguments: {
                        WalletDetailNKNScreen.argWallet: wallet,
                        WalletDetailNKNScreen.argListIndex: index,
                      });
                    },
                    bgColor: application.theme.backgroundLightColor,
                    radius: BorderRadius.circular(8),
                  ),
                );
              },
            );
          }
          return ListView();
        },
      ),
    );
  }

  _onNotBackedUpTipClicked() {
    // WalletNotBackedUpDialog.of(context).show(() {
    //   // TODO:GG
    //   // BottomDialog.of(context).showSelectWalletDialog(title: NL10ns.of(context).select_asset_to_backup, callback: _listen);
    // });
  }

// _listen(WalletSchema ws) {
//   NLog.d(ws);
//   Future(() async {
//     final future = ws.getPassword();
//     future.then((password) async {
//       if (password != null) {
//         if (ws.type == WalletSchema.ETH_WALLET) {
//           String keyStore = await ws.getKeystore();
//           EthWallet ethWallet = Ethereum.restoreWallet(name: ws.name, keystore: keyStore, password: password);
//           Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
//             'wallet': null,
//             'keystore': ethWallet.keystore,
//             'address': (await ethWallet.address).hex,
//             'publicKey': ethWallet.pubkeyHex,
//             'seed': ethWallet.privateKeyHex,
//             'name': ethWallet.name,
//           });
//         } else {
//           try {
//             var wallet = await ws.exportWallet(password);
//             if (wallet['address'] == ws.address) {
//               Navigator.of(context).pushNamed(NknWalletExportScreen.routeName, arguments: {
//                 'wallet': wallet,
//                 'keystore': wallet['keystore'],
//                 'address': wallet['address'],
//                 'publicKey': wallet['publicKey'],
//                 'seed': wallet['seed'],
//                 'name': ws.name,
//               });
//             } else {
//               showToast(NL10ns.of(context).password_wrong);
//             }
//           } catch (e) {
//             if (e.message == ConstUtils.WALLET_PASSWORD_ERROR) {
//               showToast(NL10ns.of(context).password_wrong);
//             }
//           }
//         }
//       }
//     });
//   });
// }
}