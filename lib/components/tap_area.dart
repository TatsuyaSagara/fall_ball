import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'package:fall_game/components/line.dart';
import 'package:fall_game/config.dart';

class TapArea extends PositionComponent with TapCallbacks,
                                       DragCallbacks {
  var _dragging = true;
  late Line line;
  final void Function(Vector2) dragAndTapCallback;

  TapArea({
    required this.dragAndTapCallback,
  }): super(
    position: Vector2.all(0),
    size: Vector2(Config.WORLD_WIDTH, Config.WORLD_HEIGHT * 1.1),
  ){
    priority = Config.PRIORITY_GAME_COMPONENT;
  }

  @override
  Future<void> onLoad() async {
    line = Line();
    line
      ..position.x = Config.WORLD_WIDTH * .5
      ..position.y = Config.WORLD_HEIGHT * .14;

    add(line);
  }

  // 指定された画像を指定されたサイズのボールをラインと一緒に表示する。
  void showLine(_nowBallImage, _nowBallSize, _nowBallRadius) {
    line.showLine(_nowBallImage, _nowBallSize, _nowBallRadius);
  }

  void hideLine() {
    line.hideLine();
  }

  // タップすると呼ばれる
  @override
  bool containsLocalPoint(Vector2 point) {
    _dragging = true;
    line.updateLine(point);
    return true;
  }

  // ドラッグ中に呼ばれる
  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragging = true;
    if (!line.updateLine(event.localPosition)) {
      _dragging = false;
    }
  }

  // ドラッグをやめる（タップを離す）と呼ばれる
  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _spawn();
  }

  // タップを離すと呼ばれる
  @override
  void onTapUp(TapUpEvent event) {
    _spawn();
  }

  void _spawn() {
    if (!_dragging) return;
    dragAndTapCallback(Vector2(line.position.x, Config.WORLD_HEIGHT * .14));
  }
}
