import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/header/header.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/components/wallet/item.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/wallet/create_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/import_nkn_wallet.dart';
import 'package:nmobile/screens/wallet/recieve_nkn.dart';
import 'package:nmobile/screens/wallet/send_nkn.dart';
import 'package:nmobile/services/task_service.dart';
import 'package:nmobile/utils/image_utils.dart';

class WalletHome extends StatefulWidget {
  static const String routeName = '/wallet/home';
  @override
  _WalletHomeState createState() => _WalletHomeState();
}

class _WalletHomeState extends State<WalletHome> with SingleTickerProviderStateMixin {
  FilteredWalletsBloc _filteredWalletsBloc;
  WalletsBloc _walletsBloc;
  StreamSubscription _walletSubscription;
  final GetIt locator = GetIt.instance;

  double _totalNkn = 0;

  @override
  void initState() {
    super.initState();
    locator<TaskService>().queryNknWalletBalanceTask();
    _walletsBloc = BlocProvider.of<WalletsBloc>(Global.appContext);
    _walletSubscription = _walletsBloc.listen((state) {
      if (state is WalletsLoaded) {
        _totalNkn = 0;
        state.wallets.forEach((x) => _totalNkn += x.balance ?? 0);
      }
    });

    _filteredWalletsBloc = BlocProvider.of<FilteredWalletsBloc>(context);
  }

  @override
  void dispose() {
    _walletSubscription.cancel();
    super.dispose();
  }

  _send() {
    _filteredWalletsBloc.add(LoadWalletFilter(null));
    Navigator.of(context).pushNamed(SendNknScreen.routeName);
  }

  _recieve() {
    _filteredWalletsBloc.add(LoadWalletFilter(null));
    Navigator.of(context).pushNamed(ReceiveNknScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: Header(
        titleChild: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Label(
            NMobileLocalizations.of(context).my_wallets,
            type: LabelType.h2,
          ),
        ),
        hasBack: false,
        backgroundColor: DefaultTheme.primaryColor,
        action: PopupMenuButton(
          icon: loadAssetIconsImage('more', width: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (int result) {
            switch (result) {
              case 0:
                Navigator.of(context).pushNamed(CreateNknWalletScreen.routeName);
                break;
              case 1:
                Navigator.of(context).pushNamed(ImportNknWalletScreen.routeName);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Label(
                NMobileLocalizations.of(context).no_wallet_create,
                type: LabelType.display,
              ),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Label(
                NMobileLocalizations.of(context).import_wallet,
                type: LabelType.display,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: BodyBox(
          padding: const EdgeInsets.only(top: 4, left: 20, right: 20),
          child: BlocBuilder<WalletsBloc, WalletsState>(
            builder: (context, state) {
              if (state is WalletsLoaded) {
                return ListView(
                  padding: EdgeInsets.only(top: 14.h),
                  children: state.wallets
                      .map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: WalletItem(type: WalletType.nkn, schema: w),
                        ),
                      )
                      .toList(),
                );
              }
              return ListView();
            },
          ),
        ),
      ),
    );
  }
}
