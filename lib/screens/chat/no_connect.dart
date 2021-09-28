import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/wallet/wallet_bloc.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';
import 'package:nmobile/components/button/button.dart';
import 'package:nmobile/components/dialog/loading.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/wallet/dropdown.dart';
import 'package:nmobile/generated/l10n.dart';
import 'package:nmobile/schema/wallet.dart';
import 'package:nmobile/screens/wallet/create_nkn.dart';
import 'package:nmobile/screens/wallet/import.dart';
import 'package:nmobile/utils/asset.dart';

class ChatNoConnectLayout extends BaseStateFulWidget {
  @override
  _ChatNoConnectLayoutState createState() => _ChatNoConnectLayoutState();
}

class _ChatNoConnectLayoutState extends BaseStateFulWidgetState<ChatNoConnectLayout> {
  String? dbUpdateTip;
  StreamSubscription? _upgradeTipListen;

  WalletBloc? _walletBloc;
  StreamSubscription? _walletAddSubscription;

  bool loaded = false;
  WalletSchema? _selectWallet;

  @override
  void onRefreshArguments() {}

  @override
  void initState() {
    super.initState();
    // db signIn dialogCallback
    _upgradeTipListen = dbCommon.upgradeTipStream.listen((String? tip) {
      // sync with
      if ((dbUpdateTip == null || dbUpdateTip!.isEmpty) && (tip?.isNotEmpty == true)) {
        Loading.dismiss();
      } else if ((dbUpdateTip?.isNotEmpty == true) && (tip == null || tip.isEmpty)) {
        Loading.show();
      }
      setState(() {
        dbUpdateTip = tip;
      });
    });

    // wallet
    _walletBloc = BlocProvider.of<WalletBloc>(this.context);
    _walletAddSubscription = _walletBloc?.stream.listen((event) {
      _refreshWalletDefault();
    });

    // default
    _refreshWalletDefault();
    dbUpdateTip = null;
  }

  @override
  void dispose() {
    _upgradeTipListen?.cancel();
    _walletAddSubscription?.cancel();
    super.dispose();
  }

  _refreshWalletDefault() async {
    WalletSchema? _defaultSelect = await walletCommon.getDefault();
    if (_defaultSelect == null) {
      List<WalletSchema> wallets = await walletCommon.getWallets();
      if (wallets.isNotEmpty) {
        _defaultSelect = wallets[0];
      }
    }
    setState(() {
      loaded = true;
      _selectWallet = _defaultSelect;
    });
  }

  @override
  Widget build(BuildContext context) {
    S _localizations = S.of(context);
    double headImageWidth = Global.screenWidth() * 0.55;
    double headImageHeight = headImageWidth / 3 * 2;

    return Stack(
      children: [
        Layout(
          headerColor: application.theme.primaryColor,
          header: Header(
            titleChild: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Label(
                _localizations.menu_chat,
                type: LabelType.h2,
                color: application.theme.fontLightColor,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 60, bottom: 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Asset.image(
                  'chat/messages.png',
                  width: headImageWidth,
                  height: headImageHeight,
                ),
                SizedBox(height: 50),
                Column(
                  children: [
                    Label(
                      _localizations.chat_no_wallet_title,
                      type: LabelType.h2,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 5),
                    Label(
                      _localizations.click_connect,
                      type: LabelType.bodyRegular,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                SizedBox(height: 30),
                this._selectWallet == null || !loaded
                    ? SizedBox(height: 30)
                    : Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
                        child: WalletDropdown(
                          onTapWave: false,
                          onSelected: (v) {
                            setState(() {
                              _selectWallet = v;
                            });
                          },
                          wallet: this._selectWallet!,
                          onlyNKN: true,
                        ),
                      ),
                SizedBox(height: 20),
                !loaded
                    ? SizedBox.shrink()
                    : this._selectWallet == null
                        ? Column(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Button(
                                  text: _localizations.no_wallet_create,
                                  width: double.infinity,
                                  fontColor: application.theme.fontLightColor,
                                  backgroundColor: application.theme.primaryColor,
                                  onPressed: () {
                                    WalletCreateNKNScreen.go(context);
                                  },
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Button(
                                  text: _localizations.no_wallet_import,
                                  width: double.infinity,
                                  fontColor: application.theme.fontLightColor,
                                  backgroundColor: application.theme.primaryColor.withAlpha(80),
                                  onPressed: () {
                                    WalletImportScreen.go(context, WalletType.nkn);
                                  },
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Button(
                                  width: double.infinity,
                                  text: _localizations.connect,
                                  onPressed: () async {
                                    await clientCommon.signIn(
                                      this._selectWallet,
                                      fetchRemote: true,
                                      dialogVisible: (show, tryCount) {
                                        if (tryCount > 1) return;
                                        show ? Loading.show() : Loading.dismiss();
                                      },
                                    );
                                  },
                                ),
                              )
                            ],
                          ),
              ],
            ),
          ),
        ),
        dbUpdateTip?.isNotEmpty == true
            ? Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: Global.screenHeight() / 4,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 10),
                      CircularProgressIndicator(
                        backgroundColor: Colors.white,
                      ),
                      SizedBox(height: 25),
                      Label(
                        dbUpdateTip ?? "",
                        type: LabelType.display,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        fontWeight: FontWeight.w500,
                      ),
                      SizedBox(height: 15),
                      Label(
                        "数据库升级中,请勿退出app或离开此页面!", // TODO:GG locale dbUpgrade
                        type: LabelType.display,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox.shrink(),
      ],
    );
  }
}
