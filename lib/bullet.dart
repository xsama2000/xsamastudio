import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:leap/leap.dart';

import 'enemy.dart';

class Bullet extends PhysicalEntity {
  Bullet({
    required super.position,
    required double velocityX,
  }) : super(priority: 15) {
    velocity.x = velocityX;
    size = Vector2(6, 6); // حجم أصغر ودائري
    velocity.y = 0;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // تأثير توهج كروي (Plasma Orb)
    add(CircleComponent(
      radius: 4,
      paint: Paint()
        ..color = const Color(0xFFFF0066) // لون نيوتن محمر
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    ));

    add(CircleComponent(
      radius: 2,
      position: Vector2(1, 1),
      paint: Paint()..color = Colors.white, // لب أبيض مشع
    ));

    // Bullets shouldn't be affected by gravity
    gravityRate = 0;

    add(CollisionDetectionBehavior());
    add(ApplyVelocityBehavior());
  }

  @override
  void update(double dt) {
    super.update(dt);

    for (final other in collisionInfo.allCollisions) {
      if (other is CyberEnemy) {
        other.takeDamage(this);
        _explode();
        return;
      }
    }

    if (collisionInfo.left || collisionInfo.right) {
      _explode();
    }

    if (leapGame.world.isOutside(this)) {
      removeFromParent();
    }
  }

  void _explode() {
    // Simple particle-like effect on hit
    removeFromParent();
  }
}
