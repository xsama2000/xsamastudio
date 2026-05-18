import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:leap/leap.dart';

/// كلاس يدير سلسلة ضربة البرق السينمائية
class LightningStrikeSequence extends PositionComponent with HasGameReference<LeapGame> {
  LightningStrikeSequence({required super.position});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _startSequence();
  }

  void _startSequence() async {
    // 1. مرحلة الصاعقة (بداية البرق)
    final bolt = CyberEffect(
      position: Vector2(0, -100), // تبدأ من أعلى قليلاً
      effectPath: 'Lightning/Lightning_beginning',
      frameCount: 5,
      effectSize: Vector2(100, 300),
      stepTime: 0.04,
    );
    add(bolt);

    // ننتظر قليلاً ثم نضع البرق الدوري
    await Future.delayed(const Duration(milliseconds: 150));

    // 2. مرحلة البرق على الأرض (Lightning Spot)
    final spot = CyberEffect(
      position: Vector2(0, 0),
      effectPath: 'Lightning/Lightning_spot',
      frameCount: 4,
      effectSize: Vector2(120, 60),
      stepTime: 0.05,
    );
    add(spot);

    // 3. مرحلة النار (تخرج مكان ضربة الصاعقة)
    await Future.delayed(const Duration(milliseconds: 200));
    final fire = CyberEffect(
      position: Vector2(0, -10),
      effectPath: 'Fire/Fire',
      frameCount: 6,
      effectSize: Vector2(80, 80),
      stepTime: 0.08,
    );
    add(fire);

    // 4. المرحلة الأخيرة: الدخان (يظهر بعد انطفاء النار)
    await Future.delayed(const Duration(milliseconds: 400));
    final smoke = CyberEffect(
      position: Vector2(0, -20),
      effectPath: 'Smoke/Smoke',
      frameCount: 6,
      effectSize: Vector2(100, 100),
      stepTime: 0.1,
    );
    add(smoke);

    // تدمير الكومبوننت الرئيسي بعد انتهاء السلسلة بالكامل
    await Future.delayed(const Duration(seconds: 1));
    removeFromParent();
  }
}

class CyberEffect extends SpriteAnimationComponent with HasGameReference<LeapGame> {
  final String effectPath;
  final int frameCount;
  final double stepTime;
  final Vector2 effectSize;

  CyberEffect({
    required super.position,
    required this.effectPath,
    required this.frameCount,
    this.stepTime = 0.05,
    required this.effectSize,
    super.priority = 2000,
  }) : super(size: effectSize, anchor: Anchor.center, removeOnFinish: true);

  @override
  Future<void> onLoad() async {
    final sprites = <Sprite>[];
    for (var i = 1; i <= frameCount; i++) {
      try {
        // سيتم البحث عن الصور في المسار المعطى (مثلاً: effects/fire/fire_1.png)
        final sprite = await game.loadSprite('$effectPath$i.png');
        sprites.add(sprite);
      } catch (e) {
        debugPrint('Error loading effect frame $i from $effectPath: $e');
      }
    }
    
    if (sprites.isNotEmpty) {
      animation = SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: false);
    } else {
      removeFromParent();
    }
  }
}

/// كلاس مخصص للطلقات التي تعتمد على المؤثرات الجديدة
class EffectBullet extends PhysicalEntity with HasGameReference<LeapGame> {
  final String bulletPath;
  final String explosionPath;
  final int bulletFrames;
  final int explosionFrames;
  final double velocityX;
  final Vector2 bulletSize;
  final Vector2 explosionSize;

  EffectBullet({
    required super.position,
    required this.velocityX,
    required this.bulletPath,
    required this.explosionPath,
    required this.bulletFrames,
    required this.explosionFrames,
    required this.bulletSize,
    required this.explosionSize,
  }) : super(priority: 15) {
    velocity.x = velocityX;
    size = bulletSize;
  }

  late final SpriteAnimationComponent _animComp;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    final sprites = <Sprite>[];
    for (var i = 1; i <= bulletFrames; i++) {
      sprites.add(await game.loadSprite('$bulletPath$i.png'));
    }
    
    _animComp = SpriteAnimationComponent(
      animation: SpriteAnimation.spriteList(sprites, stepTime: 0.05, loop: true),
      size: size,
      anchor: Anchor.center,
    );
    add(_animComp);
    
    add(CollisionDetectionBehavior());
    add(ApplyVelocityBehavior());
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // سيتم استيراد CyberEnemy لاحقاً عند استخدام هذا الملف
    // حالياً نكتفي بالمنطق الأساسي
    bool shouldExplode = false;
    
    // فحص التصادم (سيتم ربطه بـ CyberEnemy في الملف الرئيسي)
    if (collisionInfo.left || collisionInfo.right) {
      shouldExplode = true;
    }

    if (shouldExplode) {
      _explode();
    }

    if (leapWorld.isOutside(this)) {
      removeFromParent();
    }
  }

  void _explode() {
    final explosion = CyberEffect(
      position: position.clone(),
      effectPath: explosionPath,
      frameCount: explosionFrames,
      effectSize: explosionSize,
    );
    game.world.add(explosion);
    removeFromParent();
  }
}
