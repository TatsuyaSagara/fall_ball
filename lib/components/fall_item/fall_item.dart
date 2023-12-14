import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:fall_game/config.dart';

class FallItem extends BodyComponent with ContactCallbacks {

  final image;
  final size;
  final radius;
  final positionex;
  final type;
  final density;
  final bump;
  final fadeInDuration;
  final void Function(FallItem, Object, Contact) contactCallback;

  // 落下情報
  var _falling;
  bool get falling => _falling;

  // 削除状態
  var _deleted;
  bool get deleted => _deleted;
  set deleted(bool b) {
    _deleted = b;
  }

  FallItem({
    required this.image,
    required this.size,
    required this.radius,
    required this.positionex,
    required this.type,
    required this.density,
    required this.bump,
    required this.fadeInDuration,
    required void this.contactCallback(FallItem item, Object other, Contact contact),
  }){
    _falling = true;
    _deleted = false;
    priority = Config.PRIORITY_FALL_ITEM;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    renderBody = false;
    this.add(
      SpriteComponent(
        sprite: Sprite(image),
        size: size,
        anchor: Anchor.center,
      )
      ..add(OpacityEffect.fadeOut( EffectController( duration: 0.0)))
      ..add(OpacityEffect.fadeIn(EffectController(duration: this.fadeInDuration)))
    );
  }

  @override
  Body createBody() {
    final shape = CircleShape();
    shape.radius = radius;
    positionex.y += bump; // 位置調整

    final fixtureDef = FixtureDef(shape)
      ..density = density // 密度
      ..friction = 0.5 // 摩擦
      ..restitution = 0.0 // 反発
      ..filter.categoryBits = Config.CATEGORY_BALL
      ..filter.maskBits = Config.CATEGORY_BALL | Config.CATEGORY_DOWN_WALL | Config.CATEGORY_LEFT_WALL | Config.CATEGORY_RIGHT_WALL;

    final bodyDef = BodyDef()
      ..userData = this // To be able to determine object in collision
      ..position = this.positionex
      ..angle = (this.positionex.x + this.positionex.y) / 2 * 3.14
      ..angularDamping = 0.6
      ..type = BodyType.dynamic;
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void beginContact(Object other, Contact contact) {
    _falling = false;
    contactCallback(this, other, contact);
  }

  void removeItem() async {
    _deleted = true;
    // world.add(
    //   SpriteComponent(
    //     sprite: Sprite(this.image),
    //     size: this.size,
    //     position: this.position,
    //     anchor: Anchor.center,
    //   )
    //   ..add(OpacityEffect.fadeOut(EffectController(duration: .1)))
    //   ..add( SizeEffect.to( this.size * 1.3, EffectController(duration: .1))),
    // );
    this.removeFromParent();
  }
}
