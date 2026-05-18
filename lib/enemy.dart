import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:leap/leap.dart';

class CyberEnemy extends JumperCharacter<LeapGame>
    with HasGameReference<LeapGame> {
  CyberEnemy({super.position}) {
    health = 2;
    add(JumperAccelerationBehavior());
    add(GravityAccelerationBehavior());
    add(CollisionDetectionBehavior());
    add(ApplyVelocityBehavior());
  }

  late SpriteComponent head;
  late SpriteComponent torso;
  late SpriteComponent handLeft;
  late SpriteComponent handRight;
  late SpriteComponent bootLeft;
  late SpriteComponent bootRight;

  final PositionComponent visuals = PositionComponent();
  double _elapsedTime = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(32, 64);
    walkSpeed = 80;

    // إعداد الحاوية المرئية لتسهيل القلْب (Flipping)
    visuals.size = size;
    add(visuals);

    // تحميل الصور مع تحديد أحجام مناسبة (Scaling)
    head = SpriteComponent(
      sprite: await game.loadSprite('player/power/head.png'),
      anchor: Anchor.center,
      size: Vector2.all(24), // تصغير الرأس
    );
    torso = SpriteComponent(
      sprite: await game.loadSprite('player/power/torso.png'),
      anchor: Anchor.center,
      size: Vector2(24, 30), // تصغير الجذع
    );
    handLeft = SpriteComponent(
      sprite: await game.loadSprite('player/power/hand_left.png'),
      anchor: Anchor.center,
      size: Vector2.all(16),
    );
    handRight = SpriteComponent(
      sprite: await game.loadSprite('player/power/hand_right.png'),
      anchor: Anchor.center,
      size: Vector2.all(16),
    );
    bootLeft = SpriteComponent(
      sprite: await game.loadSprite('player/power/boot_left.png'),
      anchor: Anchor.center,
      size: Vector2.all(18),
    );
    bootRight = SpriteComponent(
      sprite: await game.loadSprite('player/power/boot_right.png'),
      anchor: Anchor.center,
      size: Vector2.all(18),
    );

    // إضافة الأجزاء للحاوية
    visuals.addAll([head, torso, handLeft, handRight, bootLeft, bootRight]);

    // وضع "HOSTILE" فوق الرأس
    add(TextComponent(
      text: 'HOSTILE',
      textRenderer: TextPaint(
          style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
      position: Vector2(size.x / 2, -15),
      anchor: Anchor.center,
    ));

    walkDirection = HorizontalDirection.left;
    isWalking = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;

    // عكس الاتجاه عند الاصطدام بالجدران
    if (collisionInfo.left) {
      walkDirection = HorizontalDirection.right;
    } else if (collisionInfo.right) {
      walkDirection = HorizontalDirection.left;
    }

    // قلب الشخصية حسب اتجاه المشي
    if (walkDirection == HorizontalDirection.right) {
      visuals.scale.x = -1;
      visuals.position.x = size.x; // تعديل الموقع بسبب القلْب
    } else {
      visuals.scale.x = 1;
      visuals.position.x = 0;
    }

    _animateParts(dt);
  }

  void _animateParts(double dt) {
    final centerX = size.x / 2;
    final centerY = size.y / 2;

    // 1. حركة الطفو للجذع (Torso Bobbing)
    final bobbing = sin(_elapsedTime * 4) * 2;
    torso.position = Vector2(centerX, centerY + bobbing);

    // 2. الرأس يلحق الجذع مع حركة أبسط
    head.position = Vector2(centerX, centerY - 15 + bobbing * 0.5);

    // 3. حركة اليدين (Floating hands)
    handLeft.position =
        Vector2(centerX - 15, centerY + bobbing + sin(_elapsedTime * 3) * 3);
    handRight.position =
        Vector2(centerX + 15, centerY + bobbing + cos(_elapsedTime * 3) * 3);

    // 4. حركة الأقدام (Walking Animation)
    if (isWalking && velocity.x.abs() > 0.1) {
      // إذا كان يمشي، نستخدم حركة دائرية للأقدام
      final walkCycle = _elapsedTime * 10;
      bootLeft.position = Vector2(
          centerX - 8 + cos(walkCycle) * 5, size.y - 5 + sin(walkCycle) * 3);
      bootRight.position = Vector2(centerX + 8 + cos(walkCycle + pi) * 5,
          size.y - 5 + sin(walkCycle + pi) * 3);
    } else {
      // إذا كان واقفا، حركة بسيطة
      bootLeft.position =
          Vector2(centerX - 10, size.y - 5 + sin(_elapsedTime * 2) * 1);
      bootRight.position =
          Vector2(centerX + 10, size.y - 5 + cos(_elapsedTime * 2) * 1);
    }
  }

  @override
  void takeDamage(PhysicalEntity other) {
    health--;
    if (health <= 0) {
      removeFromParent();
    }
  }
}
