import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nmobile/blocs/chat/auth_bloc.dart';
import 'package:nmobile/blocs/chat/auth_event.dart';
import 'package:nmobile/blocs/chat/auth_state.dart';
import 'package:nmobile/blocs/chat/chat_bloc.dart';
import 'package:nmobile/blocs/client/client_state.dart';
import 'package:nmobile/blocs/client/nkn_client_bloc.dart';
import 'package:nmobile/blocs/contact/contact_bloc.dart';
import 'package:nmobile/blocs/contact/contact_event.dart';
import 'package:nmobile/blocs/contact/contact_state.dart';
import 'package:nmobile/blocs/nkn_client_caller.dart';
import 'package:nmobile/components/CommonUI.dart';
import 'package:nmobile/components/button.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/helpers/global.dart';
import 'package:nmobile/helpers/hash.dart';
import 'package:nmobile/helpers/local_storage.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/db/topic_repo.dart';
import 'package:nmobile/model/popular_channel.dart';
import 'package:nmobile/schemas/chat.dart';
import 'package:nmobile/schemas/contact.dart';
import 'package:nmobile/model/group_chat_helper.dart';
import 'package:nmobile/schemas/message.dart';
import 'package:nmobile/schemas/message_item.dart';
import 'package:nmobile/screens/chat/authentication_helper.dart';
import 'package:nmobile/screens/chat/channel.dart';
import 'package:nmobile/screens/chat/message.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/log_tag.dart';
import 'package:oktoast/oktoast.dart';

class MessagesTab extends StatefulWidget {
  final TimerAuth timerAuth;

  MessagesTab(this.timerAuth);

  @override
  _MessagesTabState createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin, Tag {
  List<MessageItem> _messagesList = <MessageItem>[];

  AuthBloc _authBloc;
  ChatBloc _chatBloc;
  ContactBloc _contactBloc;

  StreamSubscription _chatSubscription;
  ScrollController _scrollController = ScrollController();
  int _limit = 20;
  int _skip = 20;
  bool loading = false;
  List<PopularChannel> populars;
  bool isHideTip = false;

  int timeBegin = 0;

  @override
  void initState() {
    super.initState();

    timeBegin = DateTime.now().millisecondsSinceEpoch;

    isHideTip = SpUtil.getBool(LocalStorage.WALLET_TIP_STATUS, defValue: false);
    populars = PopularChannel.defaultData();

    _authBloc = BlocProvider.of<AuthBloc>(context);
    _chatBloc = BlocProvider.of<ChatBloc>(context);
    _contactBloc = BlocProvider.of<ContactBloc>(context);

    _refreshMessage();

    _scrollController.addListener(() {
      double offsetFromBottom = _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
      if (offsetFromBottom < 50 && !loading) {
        loading = true;
        _loadMore().then((v) {
          loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }

  _refreshMessage() async{
    _updateTopicBlock();
    var res = await MessageItem.getLastMessageList(limit: _limit);
    if (res == null) return;
    Global.debugLog('Refresh got message count is'+res.length.toString());
    _contactBloc.add(LoadContact(address: res.map((x) => x.topic != null ? x.sender : x.targetId).toList()));
    _skip = 20;
    _messagesList = (res);
  }

  _routeToGroupChatPage(topicName) async{
    final topic = await GroupChatHelper.fetchTopicInfoByName(topicName);
    Navigator.of(context).pushNamed(ChatGroupPage.routeName, arguments: ChatSchema(type: ChatType.Channel, topic: topic)).then((value){
      if (value == true){
        _refreshMessage();
      }
    });
  }

  _updateTopicBlock() async{
    if (Global.upgradedGroupBlockHeight == true){
      Global.debugLog('_updateTopicBlock begin');
      Global.upgradedGroupBlockHeight = false;
      NKNClientCaller.fetchBlockHeight().then((blockHeight) {
        Global.debugLog('_updateTopicBlock end___'+blockHeight.toString());
        if (blockHeight == null || blockHeight == 0){
          return;
        }
        TopicRepo().getAllTopics().then((topicList){
          for(Topic topic in topicList){
            Global.debugLog('检索Topic:__'+topic.topic+'__'+topic.blockHeightExpireAt.toString());
            if (topic.blockHeightExpireAt == -1 || topic.blockHeightExpireAt == null){
              final String topicHash = genTopicHash(topic.name);
              NKNClientCaller.getSubscription(topicHash: topicHash, subscriber: NKNClientCaller.pubKey).then((subscription){
                if (subscription['expiresAt'] != null){
                  TopicRepo().updateOwnerExpireBlockHeight(topic.name, int.parse(subscription['expiresAt'].toString()));
                  Global.debugLog('升级'+topic.topic+'成功'+'__'+subscription.toString());
                }
              });
            }
            else if ((topic.blockHeightExpireAt - blockHeight) < (400000-300000)){
              String topicName = topic.topic;
              if (topic.isPrivate == false){
                Global.debugLog('更新Topic:' +topic.topic+'__Topic块高度:'+topic.blockHeightExpireAt.toString());
                GroupChatHelper.subscribeTopic(
                    topicName: topicName,
                    chatBloc: _chatBloc,
                    callback: (success, e) {
                      Global.debugLog('_updateTopicBlock success');
                    });

                final String topicHash = genTopicHash(topic.name);
                NKNClientCaller.getSubscription(topicHash: topicHash, subscriber: NKNClientCaller.pubKey).then((subscription) {
                  if (subscription['expiresAt'] != null){
                    TopicRepo().updateOwnerExpireBlockHeight(topic.name, int.parse(subscription['expiresAt'].toString()));
                    Global.debugLog('更新'+topic.topic+'成功'+'__'+subscription.toString());
                  }
                });
              }
              else{
                /// Update PrivateChannel Logic

              }
            }
            else{
              Global.debugLog('topic订阅未过期:__'+topic.topic);
              Global.debugLog('Topic themeID +'+topic.themeId.toString());
              // final String topicHash = genTopicHash(topic.name);
              // final Map<String, dynamic> subscription = await account.client.getSubscription(topicHash: topicHash, subscriber: account.client.myChatId);
              // if (subscription['expiresAt'] != null){
              //   await TopicRepo(db).updateOwnerExpireBlockHeight(topic.name, 0);
              //   Global.debugLog('测试重制'+topic.topic+'成功'+'__'+subscription.toString());
              // }
            }
          }
        });
      });
    }
  }

  Future _loadMore() async {
    if (Global.clientCreated == false){
      return;
    }
    var res = await MessageItem.getLastMessageList(limit: _limit, offset: _skip);
    if (res != null) {
      _skip += res.length;
      _contactBloc.add(LoadContact(address: res.map((x) => x.topic != null ? x.sender : x.targetId).toList()));
      setState(() {
        _messagesList.addAll(res);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState){
        if (authState is AuthToUserState){
          _messagesList.clear();
          _refreshMessage();
          _authBloc.add(AuthSuccessEvent());
        }
        return BlocBuilder<NKNClientBloc, NKNClientState>(
          builder: (context, clientState){
            if (clientState is NKNConnectedState){
              _updateTopicBlock();
            }
            if (clientState is NKNConnectedState ||
            clientState is NKNConnectingState) {
              return BlocBuilder<ContactBloc, ContactState>(
                builder: (context, contactState) {
                  if (contactState is ContactLoaded){
                    return BlocBuilder<ChatBloc, ChatState>(
                      builder: (context, chatState) {
                        if (chatState is MessageUpdateState){
                          _refreshMessage();
                          _chatBloc.add(RefreshMessageEndEvent());
                        }
                        if (_messagesList != null && _messagesList.length > 0) {
                          _messagesList.sort((a, b) => a.isTop ? (b.isTop ? -1 /*hold position original*/ : -1) : (b.isTop ? 1 : b.lastReceiveTime.compareTo(a.lastReceiveTime)));
                          return _messageListWidget();
                        } else {
                          return _noMessageWidget();
                        }
                      },
                    );
                  }
                  if (_messagesList != null && _messagesList.length > 0) {
                    _messagesList.sort((a, b) => a.isTop ? (b.isTop ? -1 /*hold position original*/ : -1) : (b.isTop ? 1 : b.lastReceiveTime.compareTo(a.lastReceiveTime)));
                    return _messageListWidget();
                  }
                  return _noMessageWidget();
                },
              );
            }
            return _noMessageWidget();
          },
        );
      },
    );
  }

  showMenu(MessageItem item, int index) {
    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
          children: [
            SimpleDialogOption(
              child: Row(
                children: [
                  Icon(item.isTop ? Icons.vertical_align_bottom : Icons.vertical_align_top).pad(r: 12),
                  Text(item.isTop ? NL10ns.of(context).top_cancel : NL10ns.of(context).top),
                ],
              ).pad(t: 8, b: 4),
              onPressed: () async {
                Navigator.of(context).pop();
                final top = !item.isTop;
                final numChanges = await (item.topic == null
                    ? ContactSchema.setTop(item.targetId, top)
                    : TopicRepo().updateIsTop(item.topic.topic, top)); // TopicSchema.setTop(db, item.topic.topic, top));
                if (numChanges > 0) {
                  setState(() {
                    item.isTop = top;
                    _messagesList.remove(item);
                    _messagesList.insert(0, item);
                  });
                }
              },
            ),
            SimpleDialogOption(
              child: Row(
                children: [
                  Icon(Icons.delete_outline).pad(r: 12),
                  Text(NL10ns.of(context).delete),
                ],
              ).pad(t: 4, b: 8),
              onPressed: () {
                Navigator.of(context).pop();
                MessageItem.deleteTargetChat(item.targetId).then((numChanges) {
                  if (numChanges > 0) {
                    setState(() {
                      _messagesList.remove(item);
                    });
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _noMessageWidget(){
    return Flex(
      direction: Axis.vertical,
      children: <Widget>[
        Expanded(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.only(top: 0),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Container(
                    child: Flex(
                      direction: Axis.vertical,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Label(
                              NL10ns.of(context).popular_channels,
                              type: LabelType.h3,
                              textAlign: TextAlign.left,
                            ).pad(l: 20)
                          ],
                        ),
                        Container(
                          height: 188,
                          margin: 0.pad(t: 8),
                          child: ListView.builder(
                              itemCount: populars.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return getPopularItemView(index, populars.length, populars[index]);
                              }),
                        ),
                        Expanded(
                          flex: 0,
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(top: 32),
                                child: Label(
                                  NL10ns.of(context).chat_no_messages_title,
                                  type: LabelType.h2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 8, left: 0, right: 0),
                                child: Label(
                                  NL10ns.of(context).chat_no_messages_desc,
                                  type: LabelType.bodyRegular,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            ],
                          ),
                        ),
                        Button(
                          width: -1,
                          height: 54,
                          padding: 0.pad(l: 36, r: 36),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              loadAssetIconsImage('pencil', width: 24, color: DefaultTheme.backgroundLightColor).pad(r: 12),
                              Label(NL10ns.of(context).new_message, type: LabelType.h3)
                            ],
                          ),
                          onPressed: () async {
                            if (TimerAuth.authed) {
                              var address = await BottomDialog.of(context)
                                  .showInputAddressDialog(title: NL10ns.of(context).new_whisper, hint: NL10ns.of(context).enter_or_select_a_user_pubkey);
                              if (address != null) {
                                ContactSchema contact = ContactSchema(type: ContactType.stranger, clientAddress: address);
                                await contact.insertContact();
                                Navigator.of(context)
                                    .pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
                              }
                            } else {
                              widget.timerAuth.ensureVerifyPassword(context);
                            }
                          },
                        ).pad(t: 54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageListWidget(){
    return Flex(
      direction: Axis.vertical,
      children: [
        getTipView(),
        Expanded(
          flex: 1,
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 72),
            controller: _scrollController,
            itemCount: _messagesList.length,
            itemBuilder: (BuildContext context, int index) {
              var item = _messagesList[index];
              return BlocBuilder<ContactBloc, ContactState>(
                builder: (context, state) {
                  if (state is ContactLoaded) {
                    Widget widget;
                    if (item.topic != null) {
                      widget = getTopicItemView(item, state);
                    } else {
                      widget = getSingleChatItemView(item, state);
                    }
                    return InkWell(
                      onLongPress: () {
                        showMenu(item, index);
                      },
                      child: widget,
                    );
                  } else {
                    return Container();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget getPopularItemView(int index, int length, PopularChannel model) {
    return Container(
      child: Container(
        width: 120,
        height: 120,
        margin: 8.pad(l: 20, r: index == length - 1 ? 20 : 12),
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor2, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              margin: 0.pad(t: 20),
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: model.titleBgColor, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Label(
                  model.title,
                  type: LabelType.h3,
                  color: model.titleColor,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Label(
              model.subTitle,
              type: LabelType.h4,
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 90.w,
                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
                  decoration: BoxDecoration(color: Color(0xFF5458F7), borderRadius: BorderRadius.circular(100)),
                  child: InkWell(
                    onTap: () {
                      if (TimerAuth.authed) {
                        _subscription(model);
                      } else {
                        widget.timerAuth.ensureVerifyPassword(context);
                      }
                    },
                    child: Center(
                      child: Text(
                        NL10ns.of(context).subscribe,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  _subscription(PopularChannel popular) async {
    EasyLoading.show();
    GroupChatHelper.subscribeTopic(
        topicName: popular.topic,
        chatBloc: _chatBloc,
        callback: (success, e) async {
          EasyLoading.dismiss();
          if (success) {
            _routeToGroupChatPage(popular.topic);
          } else {
            if (e.toString().contains('duplicate subscription exist in block')){
              _routeToGroupChatPage(popular.topic);
            }
            else{
              showToast(e.toString());
            }
          }
        });
  }

  getTipView() {
    if (isHideTip) {
      return Container();
    } else {
      return Container(
        margin: 20.pad(t: 25, b: 0),
        padding: 0.pad(b: 16),
        width: double.infinity,
        decoration: BoxDecoration(color: DefaultTheme.backgroundColor2, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colours.blue_0f_a1p, borderRadius: BorderRadius.circular(8)),
              child: Center(child: loadAssetIconsImage('lock', width: 24, color: DefaultTheme.primaryColor)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Label(
                    NL10ns.of(context).private_messages,
                    type: LabelType.h3,
                  ).pad(t: 16),
                  Label(
                    NL10ns.of(context).private_messages_desc,
                    type: LabelType.bodyRegular,
                    softWrap: true,
                  ).pad(t: 4),
                  Label(
                    NL10ns.of(context).learn_more,
                    type: LabelType.bodySmall,
                    color: DefaultTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ).pad(t: 6),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                SpUtil.putBool(LocalStorage.WALLET_TIP_STATUS, true);
                setState(() {
                  isHideTip = true;
                });
              },
              child: loadAssetIconsImage('close', width: 16, color: Colours.gray_81).center.sized(w: 48, h: 48),
            )
          ],
        ),
      );
    }
  }

  Widget getTopicItemView(MessageItem item, ContactLoaded state) {
    var contact = state.getContactByAddress(item.sender);
    if (contact == null) {
      return Container();
    }
    Widget contentWidget;
    // double topFontSize = 16;
    double bottomFontSize = 14;
    String draft = LocalStorage.getChatUnSendContentFromId(NKNClientCaller.pubKey, item.targetId);
    if (draft != null && draft.length > 0) {
      contentWidget = Row(
        children: <Widget>[
          Label(
            NL10ns.of(context).placeholder_draft,
            type: LabelType.bodySmall,
            color: Colors.red,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 5),
          Label(
            draft,
            type: LabelType.bodySmall,
            overflow: TextOverflow.ellipsis,
            fontSize: bottomFontSize,
          ),
        ],
      );
    }
    else if (item.contentType == ContentType.nknImage) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            Label(
              contact.name + ': ',
              maxLines: 1,
              type: LabelType.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            loadAssetIconsImage('image', width: 14, color: DefaultTheme.fontColor2),
          ],
        ),
      );
    }
    else if (item.contentType == ContentType.ChannelInvitation) {
      contentWidget = Label(
        contact.name + ': ' + NL10ns.of(context).channel_invitation,
        type: LabelType.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        fontSize: bottomFontSize,
      );
    }
    else if (item.contentType == ContentType.eventSubscribe) {
      contentWidget = Label(
        NL10ns.of(context).joined_channel,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
        fontSize: bottomFontSize,
      );
    }
    else {
      contentWidget = Label(
        contact.name + ': ' + item.content,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
        fontSize: bottomFontSize,
      );
    }
    List<Widget> topicWidget = [
      Label(item.topic.shortName,
          fontSize: 18,
          type: LabelType.h4
      ),
    ];
    if (item.topic.type == TopicType.private) {
      topicWidget.insert(0, loadAssetIconsImage('lock', width: 18, color: DefaultTheme.primaryColor));
    }
    return InkWell(
      onTap: () async {
        _routeToGroupChatPage(item.topic.topic);
      },
      child: Container(
        color: item.isTop ? Colours.light_fb : Colours.transparent,
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.only(left: 16, right: 16),
              child: CommonUI.avatarWidget(
                radiusSize: 24,
                topic: item.topic,
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: item.isTop ? Colours.light_e5 : Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: topicWidget),
                          contentWidget.pad(t: 6),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Label(
                          Format.timeFormat(item.lastReceiveTime),
                          type: LabelType.bodySmall,
                          fontSize: DefaultTheme.chatTimeSize,
                        ).pad(r: 20, b: 6),
                        _unReadWidget(item),
                      ],
                    ).pad(l: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unReadWidget(MessageItem item){
    String countStr = item.notReadCount.toString();
    if (item.notReadCount > 99){
      countStr = '99+';
      return Container(
        margin: EdgeInsets.only(right: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Container(
              color: Colours.purple_57,
              height: 25,
              width: 25,
              child: Center(
                child: Text(countStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              )
          ),
        ),
      );
    }
    if (item.notReadCount > 0){
      return Container(
        margin: EdgeInsets.only(right: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Container(
              color: Colours.purple_57,
              height: 25,
              width: 25,
              child: Center(
                child: Text(countStr,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
          ),
        ),
      );
    }
    return Container();
  }

  Widget getSingleChatItemView(MessageItem item, ContactLoaded state) {
    var contact = state.getContactByAddress(item.targetId);
    if (contact == null) return Container();

    Widget contentWidget;
    String draft = LocalStorage.getChatUnSendContentFromId(NKNClientCaller.pubKey, item.targetId);
    if (draft != null && draft.length > 0) {
      contentWidget = Row(
        children: <Widget>[
          Label(
            NL10ns.of(context).placeholder_draft,
            type: LabelType.bodySmall,
            color: Colors.red,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(width: 5.w),
          Label(
            draft,
            type: LabelType.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (item.contentType == ContentType.nknImage) {
      contentWidget = Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          children: <Widget>[
            loadAssetIconsImage('image', width: 16.w, color: DefaultTheme.fontColor2),
          ],
        ),
      );
    } else if (item.contentType == ContentType.ChannelInvitation) {
      contentWidget = Label(
        NL10ns.of(context).channel_invitation,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    } else if (item.contentType == ContentType.eventSubscribe) {
      contentWidget = Label(
        NL10ns.of(context).joined_channel,
        maxLines: 1,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      contentWidget = Label(
        item.content,
        type: LabelType.bodySmall,
        overflow: TextOverflow.ellipsis,
      );
    }
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(ChatSinglePage.routeName, arguments: ChatSchema(type: ChatType.PrivateChat, contact: contact));
      },
      child: Container(
        color: item.isTop ? Colours.light_fb : Colours.transparent,
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.only(left: 16, right: 16),
              child: CommonUI.avatarWidget(
                  radiusSize: 24,
                  contact: contact,
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(width: 0.6, color: item.isTop ? Colours.light_e5 : Colours.light_e9))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Label(contact.name, type: LabelType.h4),
                          contentWidget.pad(t: 6),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Label(
                          Format.timeFormat(item.lastReceiveTime),
                          type: LabelType.bodySmall,
                          fontSize: DefaultTheme.chatTimeSize,
                        ).pad(r: 20, b: 6),
                        _unReadWidget(item),
                      ],
                    ).pad(l: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
