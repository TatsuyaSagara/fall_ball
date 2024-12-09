import 'package:fall_game/features/ui/dialogs/gameover_dialog.dart';
import 'package:fall_game/features/ui/dialogs/title_dialog.dart';
import 'package:fall_game/features/ui/dialogs/waiting_dialog.dart';
import 'package:fall_game/core/services/connectivity_provider.dart';
import 'package:fall_game/features/game/factories/fallingItem_factory.dart';
import 'package:fall_game/features/game/multi_game.dart';
import 'package:fall_game/features/ui/labels/lobby_number.dart';
import 'package:fall_game/features/ui/labels/next_item.dart';
import 'package:fall_game/features/ui/labels/opponent_score.dart';
import 'package:fall_game/features/ui/labels/player_score.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame/components.dart';

import 'package:fall_game/features/game/components/tap_area.dart';
import 'package:fall_game/base/base.dart';
import 'package:fall_game/features/game/components/background.dart';
import 'package:fall_game/features/game/components/wall.dart';
import 'package:fall_game/features/game/components/audio.dart';
import 'package:fall_game/app/config.dart';

class FallGameWorld extends Base
  with HasGameReference<Forge2DGame>,
       TapCallbacks,
       DragCallbacks
{
  final images = Flame.images;

  late final PlayerScore playerScore;
  late final OpponentScore opponentScore;
  late final NextItem nextItem;
  late final LobbyNumber lobbyNumber;

  late final TitleDialog titleDialog;
  late final GameoverDialog gameoverDialog;
  late final WaitingDialog waitingDialog;
  // late final PositionComponent _waitingDialog;

  late final TapArea tapArea;

  late final MultiGame _multiGame;
  bool _isMulti = false;

  late final ConnectivityProvider _connectivityProvider;

  late FallingItemFactory fallingItemFactory;

  FallGameWorld()
  {
    Audio.bgmPlay(Audio.AUDIO_TITLE);
  }

  void chain() {
    if (_isMulti) {
      _multiGame.chain.addChain();
    }
  }

  // プレイ中かつ落下中のみアイテムをスポーンし、落下位置確認用ラインを消す。
  void spawn(position) {
    if (!_isPlaying()) return;
    if (fallingItemFactory.isFallingItem()) return;
    fallingItemFactory.spawn(position);
    Audio.play(Audio.AUDIO_SPAWN);
    tapArea.hideLine();
  }

  // Singleボタンが押されたら呼ばれる
  void singleStart() {
    _isMulti = false;
    moveToStartState();
  }

  // Multiボタンが押されたら呼ばれる
  void multiStart() async {
    _isMulti = true;
    _multiGame.onWaiting();
    moveToPreparationState();
  }

  // 接続中にCANCELボタンが押されたら呼ばれる
  void cancelWaiting() async {
    _multiGame.removeWaitingChannel();
    moveToTitleState();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ビューファインダーの設定(左上の座標を0,0として扱う)
    await _initializeCamera();

    // UI
    playerScore = await PlayerScore.create();
    opponentScore = await OpponentScore.create();
    nextItem = await NextItem.create();
    lobbyNumber = await LobbyNumber.create();

    titleDialog = await TitleDialog();
    gameoverDialog = await GameoverDialog();
    waitingDialog = await WaitingDialog();

    add(playerScore.label);
    add(opponentScore.label);
    add(nextItem.label);
    add(lobbyNumber.label);

    await titleDialog.initialize();
    await gameoverDialog.initialize();
    await waitingDialog.initialize();

    // 画像やオーディオの読み込み
    await _loadAssets();

    // 必要なコンポーネントや依存関係の初期化
    _setupConnectivityListener();
    _setupMultiGame();
    _setupFactories();

    // 壁や背景などの描画要素を追加
    _setupUIComponents();

    // GameBoard.signedIn();
    // _gameOverScreen = createGameOverScreen();
  }

  @override
  void title() {
    super.title();

    // 接続中画面非表示
    waitingDialog.hide(this);
    // drawWaitingDialog(false);

    // ゲームオーバ非表示
    gameoverDialog.hide(this);

    // タイトル表示
    titleDialog.show(this);  
  }

  @override
  void preparation() {
    super.preparation();

    waitingDialog.show(this);
    _multiGame.onWaitingUpdate();
  }

  @override
  void start() {
    super.start();

    var nextItemType = (fallingItemFactory.getNextFallingItemAttributes().type + 1);
    nextItem.update(nextItemType);

    opponentScore.reset();
    playerScore.reset();

    // タイトル非表示
    titleDialog.hide(this);

    // 落下アイテム削除
    fallingItemFactory.deleteAllFallingItem(this.children);

    waitingDialog.hide(this);
    Audio.bgmStop();
    Audio.bgmPlay(Audio.AUDIO_BGM);
    // Playステータスへ繊維
    moveToPlayingState();

    if (_isMulti) {
      opponentScore.show();
    }

    _showLine();
  }

  @override
  void play() {
    super.play();

    if (_isMulti) {
      _multiGame.onPlayUpdate(playerScore.score, _isGameOver());
    }

    if (_isGameOver()) {
      moveToGameOverState();
    }
  }

  @override
  void gameover() {
    super.gameover();

    // 連鎖
    if (_isMulti) {
      _multiGame.chain.stopChain();
    }

    // 落下アイテム消去
    fallingItemFactory.deleteAllFallingItem(this.children);
    // drawGameOverScreen(true);
    gameoverDialog.show(this);
    Audio.bgmStop();
    Audio.bgmPlay(Audio.AUDIO_TITLE);
  }

  @override
  void end() {
    super.end();

    // 得点（リーダーボード）
    // GameBoard.leaderboardScore(_scoreLabel.score);
    // プレイ回数と平均得点（リーダーボード）
    // GameBoard.playCountAndAverageScore(_scoreLabel.score);

    // 落下アイテム消去
    tapArea.hideLine();

    // Titleステータスへ遷移
    moveToTitleState();
  }

  Future<void> _initializeCamera() async {
    game.camera.viewfinder.anchor = Anchor.topLeft;
  }

  Future<void> _loadAssets() async {
    await game.images.loadAllImages();
    await Audio.load();
  }

  void _setupFactories() {
    fallingItemFactory = FallingItemFactory();
    add(fallingItemFactory);
    fallingItemFactory.eventBus.subscribe(fallingItemFactory.ON_FALL_COMPLETE, (_) {
      // アイテムの落下が完了したら呼ばれ、次のアイテムの番号をNEXTに表示
      var item = fallingItemFactory.nextFallingItemIndex + 1;
      nextItem.update(item);
    });
    fallingItemFactory.eventBus.subscribe(fallingItemFactory.ON_MERGE_ITEM, (score) {
      // アイテムがマージされたら呼ばれ、アイテムのスコア更新
      playerScore.update(score);
    });
  }

  void _setupUIComponents() {
    tapArea = TapArea(dragAndTapCallback: spawn );
    add(tapArea);

    createWall().forEach(add);
    _addForegroundAndBackground();
  }

  Future<void> _addForegroundAndBackground() async {
    final foregroundImage = await images.load(Config.IMAGE_FOREGROUND);
    createForegound(foregroundImage).forEach(add);
    final backgroundImage = await images.load(Config.IMAGE_BACKGROUND);
    createBackgound(backgroundImage).forEach(add);
  }

  void _setupConnectivityListener() {
    _connectivityProvider = ConnectivityProvider();
    _connectivityProvider.addListener(_onConnectivityChanged);
  }

  bool _isPlaying() {
    return isPlayingState();
  }

  void _onMultiGameStart() {
    moveToStartState();
  }

  void _onMultiGameOver() {
    moveToGameOverState();
  }

  void _showLine() {
    tapArea.showLine(
        fallingItemFactory.getNowFallingItemAttributes().image,
        fallingItemFactory.getNowFallingItemAttributes().size,
        fallingItemFactory.getNowFallingItemAttributes().radius);
  }

  bool _isGameOver() {
    return fallingItemFactory.onScreenFallingItems.any((item) =>
        item.body.position.y < Config.WORLD_HEIGHT * 0.2 && !item.falling);
  }

  void _setupMultiGame() {
    _multiGame = MultiGame();
    _multiGame.addGameStartCallback(_onMultiGameStart);
    _multiGame.addGameOverCallback(_onMultiGameOver);
    _multiGame.opponentScore.addListener(_updateOpponentScoreLabel);
    _multiGame.opponetBall.addListener(_updateOpponentBall);
    _multiGame.memberCount.addListener(_updateLobbyMemberCount);
  }

  void _onConnectivityChanged() {
    if (_connectivityProvider.isOnline) {
      _multiGame.onOnline();
    } else {
      _multiGame.onOffline();
    }
  }

  void _updateOpponentBall() {
    var chain = _multiGame.opponetBall.value;
    for (int i = 0; i < chain; i++) {
      fallingItemFactory.randomSpawn();
    }
    _multiGame.opponetBall.value = 0;
  }

  void  _updateLobbyMemberCount() {
    var count = _multiGame.memberCount.value;
    lobbyNumber.update(count);
  }

  void _updateOpponentScoreLabel() {
    var score = _multiGame.opponentScore.value;
    opponentScore.update(score);
  }
}