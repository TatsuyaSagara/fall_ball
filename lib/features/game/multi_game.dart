import 'package:fall_game/app/config.dart';
import 'package:fall_game/core/modules/chain.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EnemyBallStatus {
  late String userid;
  late double height;
}

class MultiGame {
  late RealtimeChannel _gameChannel;
  late RealtimeChannel _waitingChannel;
  late RealtimeChannel _matchChannel;

  List<String> _userids = [];
  final myUserId = const Uuid().v4();
  late var _sentScores = 0;
  late var _sentEnemyBallHeight= 0.0;
  final supabase = Supabase.instance.client;
  String opponent = "";
  late double? enemyBallState = null;
  late List<EnemyBallStatus> enemyBallState2 = [];

  // 通知
  final ValueNotifier<int> opponentScore = ValueNotifier<int>(0); // 相手のスコア
  final ValueNotifier<int> opponetBall = ValueNotifier<int>(0); // 連鎖数
  final ValueNotifier<int> memberCount = ValueNotifier<int>(0);   // 参加人数

  // スコアを更新する関数を作成
  void _updateOpponentScore(int score) {
    opponentScore.value = score;
  }

  void Function()? _multiGameStartCallback;
  void Function()? _multiGameOverCallback;

  final Chain chain = Chain();

  MultiGame() {
    onOnline();
  }

  void addGameStartCallback(callback) => _multiGameStartCallback = callback;
  void addGameOverCallback(callback) => _multiGameOverCallback = callback;

  void onOnline() {
    _gameChannel = supabase.channel(
      'game',
      opts: const RealtimeChannelConfig(self: true),
    );
    _gameChannel.onPresenceSync((payload) {
      print('[onOnline] >>> onPresenceSync');
      final presenceState = _gameChannel.presenceState();
      final onlineUsers = presenceState.map((element) => (element.presences.first).payload['user_id'] as String).toList();
      memberCount.value = onlineUsers.length;
    }).onPresenceJoin((payload) {
      print('[onOnline] >>> onPresenceJoin');
    }).onPresenceLeave((payload) {
      print('[onOnline] >>> onPresenceLeave');
    }).subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('[onOnline] >>> onSubscrive');
        await _gameChannel.track({'user_id': myUserId});
      }
    });
  }

  void onOffline(){
    try{
      _waitingChannel.untrack();
      _waitingChannel.unsubscribe();
    } catch(e) {}
  }

  // MULTIを押したら呼ばれる
  void onWaiting() {
    _waitingChannel = supabase.channel(
      'waiting',
      opts: const RealtimeChannelConfig(self: true),
    );
    _waitingChannel.onPresenceSync((payload) {
      final presenceState = _waitingChannel.presenceState();
      _userids = presenceState.map((element) => (element.presences.first).payload['user_id'] as String).toList();
    }).onPresenceJoin((payload) {
    }).onPresenceLeave((payload) {
      _waitingChannel.untrack();
      _waitingChannel.unsubscribe();
    }).onBroadcast(event: 'game_start', callback: (payload) {
      if (payload.length == 0) return;
      if (payload['participants'] == null) return;
      final participantIds = List<String>.from(payload['participants']);
      if (participantIds.contains(myUserId)) {
        final gameId = payload['game_id'] as String;
        _onGameStarted(gameId);
      }
    }).subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('[onWaiting] >>> onSubscrive / ${myUserId} / ${status}');
        await _waitingChannel.track({'user_id': myUserId});
      }
    });
  }

  // preのupdateで呼ばれる
  Future<void> onWaitingUpdate() async {
    await Future.delayed(Duration.zero);
    if (_userids.length <= Config.OTHER_PLAYER_COUNT) {
      return;
    }

    var playUserId = _userids.where((userId) => userId != myUserId).take(2).toList();
    playUserId.add(myUserId);
    var gameId = const Uuid().v4();
    print('[waiting] >>> send game_start / gameId:${gameId} / _userids:${_userids} / playUserId:${playUserId}');
    _userids.clear();
    await _waitingChannel.sendBroadcastMessage(
      event: 'game_start',
      payload: {
        'participants': playUserId,
        'game_id': gameId,
      },
    );
  }

  // play状態中のupdate時に呼ばれる
  void sendScore(score) async {
    if (_sentScores != score) {
      _sendScoreMessage(score);
      _sentScores = score;
    }
  }

  // play状態中のupdate時に呼ばれる
  void sendEnemyBallHeight(height) {
    if (_sentEnemyBallHeight != height) {
      _sendEnemyBallHeight(height);
      _sentEnemyBallHeight = height;
    }
  }

  // play状態中のupdate時に呼ばれる
  void resetAndSendGameOver() async {
    _sentScores = 0;
    _sentEnemyBallHeight = 0.0;
    _sendGameOverMessage();
  }

  // play状態中のupdate時に呼ばれる
  void sendChain() async {
    _sendChainMessage();
  }

  // // play状態中のupdate時に呼ばれる
  // void onPlayUpdate(score, height, isGameover) async {
    // if (isGameover) {
    //   _sentScores = 0;
    //   _sentEnemyBallHeight = 0.0;
    //   _sendGameOverMessage();
    // }

    // _sendChainMessage();

    // if (_sentEnemyBallHeight != height) {
    //   _sendEnemyBallHeight(height);
    //   _sentEnemyBallHeight = height;
    // }

    // if (_sentScores != score) {
    //   _sendScoreMessage(score);
    //   _sentScores = score;
    // }
  // }

  Future<void> _sendGameOverMessage() async {
    await _matchChannel.sendBroadcastMessage(
      event: 'game_over',
      payload: {},
    );
  }

  Future<void> _sendChainMessage() async {
    if (chain.sendChains > 0) {
      await _matchChannel.sendBroadcastMessage(
        event: 'game_chain',
        payload: {
          'chain' : chain.sendChains,
          'send_id' : myUserId,
        },
      );
      chain.clearSendChains();
    }
  }

  Future<void> _sendEnemyBallHeight(height) async {
    if (height > 0.0) {
      await _matchChannel.sendBroadcastMessage(
        event: 'game_enemy_ball_height',
        payload: {
          'enemy_ball_height': height.toDouble(),
          'send_id' : myUserId,
        },
      );
    }
  }

  Future<void> _sendScoreMessage(score) async {
    await _matchChannel.sendBroadcastMessage(
      event: 'game_score',
      payload: {
        'score': score,
        'send_id' : myUserId,
      },
    );
  }

  void removeWaitingChannel() async {
    print('[waiting] >>> remove _waitingChannel');
    await supabase.removeChannel(_waitingChannel);
  }

  void removeGameChannel() async {
    print('[match] >>> remove _matchChannel');
    await supabase.removeChannel(_matchChannel);
  }

  void _onGameStarted(gameId) async {
    await Future.delayed(Duration.zero);
    
    _sentScores = 0;
    _sentEnemyBallHeight = 0.0;

    _matchChannel = supabase.channel(
      gameId,
      opts: const RealtimeChannelConfig(self: true)
    );
    _matchChannel.onPresenceLeave((payload) {
      _matchChannel.untrack();
      _matchChannel.unsubscribe();
    }).onBroadcast(event: 'game_score', callback: (payload) {
      final score = payload['score'] as int;
      final sendId = payload['send_id'] as String;
      if (sendId != myUserId) {
        _updateOpponentScore(score);
      }
    }).onBroadcast(event: 'game_enemy_ball_height', callback: (payload) {
      // final enemy_ball_height = payload['enemy_ball_height'] as double;
      final enemy_ball_height = (payload['enemy_ball_height'] as num).toDouble();
      final sendId = payload['send_id'] as String;
      if (sendId != myUserId) {
        print('enemy_ball_height: $enemy_ball_height');
        enemyBallState = enemy_ball_height;
        ///////////////////////////////////////////////////
        print('----- BEFORE --------------------');
        for (var status in enemyBallState2) {
          print('UserID: ${status.userid}, Height: ${status.height}');
        }
        ///////////////////////////////////////////////////
        // bool bbb = false;
        // for (int i=0; i < enemyBallState2.length; i++) {
        //   if (enemyBallState2[i].userid == sendId) {
        //     enemyBallState2[i].height = enemy_ball_height;
        //     bbb = true;
        //     break;
        //   }
        // }
        // if (!bbb) {
        //   // 新しい状態を追加
        //   var newStatus = EnemyBallStatus();
        //   newStatus.userid = sendId;
        //   newStatus.height = enemy_ball_height;
        //   enemyBallState2.add(newStatus);
        // }
        ///////////////////////////////////////////////////
        // 既存のユーザーIDを持つ状態を探す
        var existingStatus = enemyBallState2.firstWhere(
          (e) => e.userid == sendId,
          orElse: () => EnemyBallStatus()..userid = '',
        );

        if (existingStatus.userid == sendId) {
          // 見つかった場合は高さを更新
          existingStatus.height = enemy_ball_height;
        } else {
          // 見つからない場合は新しい状態を追加
          enemyBallState2.add(EnemyBallStatus()
            ..userid = sendId
            ..height = enemy_ball_height);
        }
        print('----- AFTER --------------------');
        for (var status in enemyBallState2) {
          print('UserID: ${status.userid}, Height: ${status.height}');
        }
        ///////////////////////////////////////////////////
      }
    }).onBroadcast(event: 'game_chain', callback: (payload) {
      final sendId = payload['send_id'] as String;
      final chain = payload['chain'] as int;
      if (sendId != myUserId) {
        print('chain(1): $chain');
        opponetBall.value = chain;
        // _onOpponentChainAttack(chain);
      }
    }).onBroadcast(event: 'game_over', callback: (payload) {
      print('[game] >>> game_over');
      removeGameChannel();
      _multiGameOverCallback?.call();
    }).subscribe();
    // }).subscribe((status, [_]) async {
    //   print('[_onGameStarted] >>> onSubscrive');
    //   await _matchChannel.track({'user_id': myUserId});
    // });

    removeWaitingChannel();

    _multiGameStartCallback?.call();
  }
}