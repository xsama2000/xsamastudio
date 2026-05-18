import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:leap/leap.dart';
import 'package:tiled/tiled.dart' as tiled;

import 'player.dart';
import 'constants.dart';

class CyberReplacedGame extends LeapGame {
  final Function(String name,
      {double? x,
      double? y,
      double? a,
      double? sx,
      double? sy,
      double? ax,
      double? ay,
      double? op,
      bool? independent}) onPartUpdate;

  bool testMode = true;
  bool showJoystick = true;
  bool isMirroring = false;
  bool isSelectionLocked = false;
  String? selectedPartName;

  Vector2 externalJoystickDelta = Vector2.zero();
  double aimSensitivity = 1.0;

  CyberReplacedGame({required this.onPartUpdate})
      : super(tileSize: 16, world: LeapWorld()) {
    player = SpinePlayer();
  }

  late final SpinePlayer player;
  late final JoystickComponent joystick;
  LeapMap? _customLeapMap;

  void updateAimY(double dy) {
    if (!isLoaded) return;
    // حساسية موزونة تعتمد على الإعدادات
    player.aimY = (player.aimY - dy * 1.5 * aimSensitivity).clamp(-300, 600);
  }

  @override
  LeapMap get leapMap => _customLeapMap!;

  @override
  Future<void> onLoad() async {
    final map = tiled.TiledMap(
        width: 100,
        height: 20,
        tileWidth: 16,
        tileHeight: 16,
        orientation: tiled.MapOrientation.orthogonal,
        renderOrder: tiled.RenderOrder.rightDown);

    // نضمن أن القوائم الأساسية قابلة للتعديل والفرز (Growable)
    map.layers = <tiled.Layer>[];
    map.tilesets = <tiled.Tileset>[];

    // نستخدم List.generate لضمان إنشاء قائمة بيانات قابلة للتعديل
    map.layers.add(
      tiled.TileLayer(
        name: 'Ground',
        width: 100,
        height: 20,
        data: List<int>.generate(2000, (i) => 0),
      ),
    );

    final renderableMap =
        await RenderableTiledMap.fromTiledMap(map, Vector2.all(16));
    _customLeapMap =
        LeapMap(tileSize: 16, tiledMap: TiledComponent(renderableMap));
    await world.add(_customLeapMap!);

    await super.onLoad();

    camera.viewfinder.zoom = 1.5;
    camera.viewfinder.anchor = Anchor.center;

    final ground =
        GroundTile(position: Vector2(-1000, 500), size: Vector2(2000, 100));
    world.add(ground);

    player.position = Vector2(0, 300);

    // تأكد من أننا نتعامل مع الـ Tags كمجموعة قابلة للتعديل
    if (!player.solidTags.contains(CommonTags.ground)) {
      player.solidTags.add(CommonTags.ground);
    }

    // يجب استخدام await للتأكد من اكتمال تحميل اللاعب وملفات الـ Spine قبل البدء
    await world.add(player);

    // جعل الكاميرا تتبع اللاعب بنعومة (Smoothing)
    camera.follow(player, maxSpeed: 400);
    camera.viewfinder.anchor = const Anchor(0.5, 0.28);

    joystick = JoystickComponent(
      knob: CircleComponent(
          radius: 20, paint: Paint()..color = const Color(0x88FFFFFF)),
      background: CircleComponent(
          radius: 40, paint: Paint()..color = const Color(0x22FFFFFF)),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    if (showJoystick) {
      camera.viewport.add(joystick);
    }
  }

  void updatePart(String name,
      {double? x,
      double? y,
      double? a,
      double? sx,
      double? sy,
      double? ax,
      double? ay,
      double? op,
      bool? independent}) {
    if (!isLoaded) return;
    player.updatePart(name,
        x: x,
        y: y,
        a: a,
        sx: sx,
        sy: sy,
        ax: ax,
        ay: ay,
        op: op,
        independent: independent ?? false);

    // Call the UI callback if needed
    onPartUpdate(name,
        x: x,
        y: y,
        a: a,
        sx: sx,
        sy: sy,
        ax: ax,
        ay: ay,
        op: op,
        independent: independent);
  }

  void handleTap(Vector2 position) {
    if (isSelectionLocked) return;
    // نتأكد من أن اللاعب قد تم تحميله قبل الوصول إليه لتجنب LateInitializationError
    if (!isLoaded) return;

    try {
      if ((player.position - position).length < 100) {
        selectedPartName = "visuals";
      }
    } catch (_) {}
  }

  void jump() {
    if (player.collisionInfo.down) {
      player.velocity.y = -350;
    }
  }

  void shoot() {
    player.playEditorAnimation(SpineAnimations.shoot);
    player.playMuzzleSequence();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;

    double dx = 0;
    if (showJoystick) {
      if (joystick.relativeDelta.length > 0.1) {
        dx = joystick.relativeDelta.x;
      }
    } else {
      if (externalJoystickDelta.length > 0.1) {
        dx = externalJoystickDelta.x;
      }
    }

    player.velocity.x = dx * 300;
  }
}

class GroundTile extends PhysicalEntity {
  GroundTile({required super.position, required super.size});
  @override
  Future<void> onLoad() async {
    super.onLoad();
    tags.add(CommonTags.ground);
  }

  @override
  void render(ui.Canvas canvas) {
    canvas.drawRect(
        size.toRect(), ui.Paint()..color = const ui.Color(0xFF111111));
  }
}
