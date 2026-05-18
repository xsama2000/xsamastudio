import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:leap/leap.dart';
import 'package:spine_flutter/spine_flutter.dart';

import 'game.dart';
import 'spine_component.dart';
import 'constants.dart';

enum HandPose { idle, fist, trigger, grip }

class SpinePlayer extends JumperCharacter
    with HasGameReference<CyberReplacedGame> {
  late SpineComponent visuals;

  double lerpSpeed = 15;
  HandPose currentHandPose = HandPose.idle;

  final Map<String, PositionComponent> _partMap = {};
  final Map<String, ui.Image> customAttachments = {};

  final Map<String, String> editorToBoneMap = {
    "head": "head",
    "neck": "neck",
    "torso": "torso",
    "torso2": "torso2",
    "torso3": "torso3",
    "goggles": "goggles",
    "front-arm-group": "front-upper-arm",
    "front-upper-arm": "front-upper-arm",
    "front-bracer": "front-bracer",
    "front-fist": "front-fist",
    "front-leg-group": "front-thigh",
    "front-thigh": "front-thigh",
    "front-shin": "front-shin",
    "front-foot": "front-foot",
    "rear-arm-group": "rear-upper-arm",
    "rear-upper-arm": "rear-upper-arm",
    "rear-bracer": "rear-bracer",
    "gun": "gun",
    "rear-leg-group": "rear-thigh",
    "rear-thigh": "rear-thigh",
    "rear-shin": "rear-shin",
    "rear-foot": "rear-foot",
  };

  final List<String> animations = [
    'idle',
    'walk',
    'run',
    'jump',
    'shoot',
    'hit',
    'death',
    'portal',
    'aim'
  ];

  SpinePlayer() {
    addAll([
      JumperAccelerationBehavior(),
      GravityAccelerationBehavior(),
      CollisionDetectionBehavior(),
      ApplyVelocityBehavior(),
    ]);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(50, 160);

    visuals = await SpineComponent.fromAssets(
      AppAssets.spineboyAtlas,
      AppAssets.spineboySkeleton,
    );

    visuals.scale = Vector2(EditorConstants.defaultScale, EditorConstants.defaultScale);
    visuals.position = Vector2(size.x / 2, size.y);
    visuals.anchor = Anchor.bottomCenter;

    add(visuals);
    _partMap["visuals"] = visuals;

    setAttachment(SpineBones.muzzle, null);
    setAttachment(SpineBones.muzzleRing, null);
    setAttachment(SpineBones.muzzleGlow, null);
    setAttachment(SpineAnimations.portal, null);

    visuals.onAfterAnimationApplied = (skeleton) {
      final crosshair = skeleton.findBone(SpineBones.crosshair);
      if (crosshair != null) {
        crosshair.pose.x = aimX;
        crosshair.pose.y = aimY;
      }
    };

    setAttachment(SpineBones.crosshair, SpineBones.crosshair);

    for (var bone in visuals.skeleton.bones) {
      if (bone != null && bone.data.name.toLowerCase().contains(SpineBones.muzzle)) {
        bone.pose.scaleX = 1.0;
        bone.pose.scaleY = 1.0;
      }
    }

    _playAnimation(SpineAnimations.idle);
  }

  Vector2 get muzzleWorldPosition {
    final bone = visuals.skeleton.findBone(SpineBones.gunTip) ??
        visuals.skeleton.findBone(SpineBones.muzzle) ??
        visuals.skeleton.findBone("gun");

    if (bone != null) {
      return position +
          Vector2((size.x / 2) + (bone.appliedPose.worldX * visuals.scale.x),
              size.y - (bone.appliedPose.worldY * visuals.scale.y.abs()) - 15);
    }
    return position + Vector2(size.x / 2, size.y / 2);
  }

  double aimX = 500;
  double aimY = 200;

  Future<void> playMuzzleSequence() async {
    const muzzleSlot = SpineBones.muzzle;
    const ringSlot = SpineBones.muzzleRing;
    const glowSlot = SpineBones.muzzleGlow;

    try {
      setAttachment(glowSlot, "muzzle-glow");
      for (int i = 1; i <= 5; i++) {
        setAttachment(muzzleSlot, "muzzle0$i");
        await Future.delayed(const Duration(milliseconds: 25));
      }
      setAttachment(muzzleSlot, null);
      setAttachment(glowSlot, null);
      setAttachment(ringSlot, "muzzle-ring");
      await Future.delayed(const Duration(milliseconds: 120));
      setAttachment(ringSlot, null);
    } catch (_) {
      setAttachment(muzzleSlot, null);
      setAttachment(ringSlot, null);
      setAttachment(glowSlot, null);
    }
  }

  void revive() {
    if (!isDead) return;
    try {
      final entry = visuals.animationState.setAnimation(0, SpineAnimations.death, false);
      entry.timeScale = -1.2;
      entry.trackTime = entry.animation.duration;

      Future.delayed(const Duration(milliseconds: 850), () {
        if (!isRemoved) {
          isDead = false;
          _currentAnim = "";
          _playAnimation(SpineAnimations.idle);
        }
      });
    } catch (_) {
      isDead = false;
    }
  }

  void playEditorAnimation(String name) {
    if (name == SpineAnimations.death) {
      isDead = true;
      playAnimation(SpineAnimations.death, loop: false);
      final crosshair = visuals.skeleton.findBone(SpineBones.crosshair);
      if (crosshair != null) {
        crosshair.pose.x = 200;
        crosshair.pose.y = -300;
        visuals.skeleton.updateWorldTransform(Physics.update);
      }
      return;
    }

    if (name == SpineAnimations.shoot) {
      try {
        final entry = visuals.animationState.setAnimation(1, SpineAnimations.shoot, false);
        entry.setMixDuration = 0;
        entry.mixAttachmentThreshold = 1.0;
        visuals.animationState.addEmptyAnimation(1, 0.2, 0.1);
      } catch (e) {}
    } else if (animations.contains(name)) {
      _playAnimation(name);
    }
  }

  List<String> get boneNames {
    try {
      final names = <String>[];
      for (var i = 0; i < visuals.skeleton.bones.length; i++) {
        final b = visuals.skeleton.bones[i];
        if (b != null) names.add(b.data.name);
      }
      return names;
    } catch (e) {
      return editorToBoneMap.keys.toList();
    }
  }

  bool isHovering = false;
  @override
  bool isDead = false;

  bool _wasGrounded = true;

  void updatePart(String name,
      {double? x,
      double? y,
      double? a,
      double? sx,
      double? sy,
      double? ax,
      double? ay,
      double? op,
      bool independent = false}) {
    if (!isLoaded) return;
    if (name == SpineBones.crosshair) {
      if (x != null) aimX = x;
      if (y != null) aimY = y;
      return;
    }
    if (_partMap.containsKey(name)) {
      final p = _partMap[name]!;
      if (x != null) p.position.x = x;
      if (y != null) p.position.y = y;
      if (a != null) p.angle = a;
      if (sx != null) p.scale.x = sx;
      if (sy != null) p.scale.y = sy;
      if (ax != null || ay != null) {
        p.anchor = Anchor(ax ?? p.anchor.x, ay ?? p.anchor.y);
      }
      if (op != null && p is SpriteComponent) p.opacity = op;
      return;
    }
    final bone = visuals.skeleton.findBone(name) ??
        visuals.skeleton.findBone(editorToBoneMap[name] ?? "");
    if (bone != null) {
      if (x != null) bone.pose.x = x;
      if (y != null) bone.pose.y = y;
      if (a != null) bone.pose.rotation = a * (180 / 3.14159);
      if (sx != null) bone.pose.scaleX = sx;
      if (sy != null) bone.pose.scaleY = sy;
      visuals.skeleton.updateWorldTransform(Physics.update);
      return;
    }
  }

  PositionComponent getPart(String name) {
    if (_partMap.containsKey(name)) return _partMap[name]!;
    final bone = visuals.skeleton.findBone(name) ??
        visuals.skeleton.findBone(editorToBoneMap[name] ?? "");
    if (bone != null) {
      return PositionComponent(
        position: Vector2(bone.pose.x, bone.pose.y),
        angle: bone.pose.rotation * (3.14159 / 180),
        scale: Vector2(bone.pose.scaleX, bone.pose.scaleY),
      );
    }
    return visuals;
  }

  SpriteComponent? getSpriteForPart(String name) =>
      (_partMap[name] is SpriteComponent)
          ? (_partMap[name] as SpriteComponent)
          : null;

  Future<void> addCustomAttachment(String name, ui.Image image) async {
    customAttachments[name] = image;
    final component = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2(image.width.toDouble(), image.height.toDouble()),
      anchor: Anchor.center,
    );
    _partMap[name] = component;
    visuals.add(component);
  }

  void setHandPose(HandPose pose) => currentHandPose = pose;

  void setAttachment(String slotName, String? attachmentName) {
    if (!isLoaded) return;
    try {
      if (attachmentName == null) {
        visuals.skeleton.findSlot(slotName)?.pose.attachment = null;
      } else {
        visuals.skeleton.setAttachment(slotName, attachmentName);
      }
    } catch (e) {
      debugPrint("SetAttachment Error: $e");
    }
  }

  void playAnimation(String name, {int track = 0, bool loop = true}) {
    if (!isLoaded) return;
    try {
      visuals.animationState.setAnimation(track, name, loop);
    } catch (e) {}
  }

  String exportJson() {
    final boneData = <String, dynamic>{};
    editorToBoneMap.forEach((key, boneName) {
      final b = visuals.skeleton.findBone(boneName);
      if (b != null) {
        boneData[key] = {
          'x': b.pose.x,
          'y': b.pose.y,
          'a': b.pose.rotation,
          'sx': b.pose.scaleX,
          'sy': b.pose.scaleY
        };
      }
    });
    final attachments = <String, String?>{};
    for (var slot in visuals.skeleton.slots) {
      if (slot != null &&
          slot.data.name.contains(RegExp(r'mouth|eye|goggles'))) {
        attachments[slot.data.name] = slot.pose.attachment?.name;
      }
    }
    return jsonEncode({
      'lerpSpeed': lerpSpeed,
      'walkSpeed': walkSpeed,
      'bones': boneData,
      'attachments': attachments,
      'parts': _partMap
          .map((k, v) => MapEntry(k, {'x': v.x, 'y': v.y, 'a': v.angle}))
    });
  }

  Future<void> importJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr);
      final bones = data['bones'] as Map<String, dynamic>?;
      bones?.forEach((name, val) {
        updatePart(name,
            x: val['x']?.toDouble(),
            y: val['y']?.toDouble(),
            a: (val['a'] as num?)?.toDouble() != null
                ? (val['a'] as num).toDouble() * (3.14159 / 180)
                : null,
            sx: val['sx']?.toDouble(),
            sy: val['sy']?.toDouble());
      });
      final attachments = data['attachments'] as Map<String, dynamic>?;
      attachments?.forEach((slot, attachment) {
        setAttachment(slot, attachment as String?);
      });
    } catch (e) {
      debugPrint("Import Error: $e");
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;

    if (game.testMode) {
      final joystickDelta = game.externalJoystickDelta;
      final bool isGrounded = collisionInfo.down;

      if (isGrounded && !_wasGrounded) {
        visuals.scale.y = EditorConstants.defaultScale - 0.02;
        Future.delayed(const Duration(milliseconds: 100), () {
          visuals.scale.y = EditorConstants.defaultScale;
        });
      }
      _wasGrounded = isGrounded;

      if (isDead && joystickDelta.length > 0.3) {
        isDead = false;
        _currentAnim = "";
        _playAnimation(SpineAnimations.idle);
      }
      if (isDead) return;

      final baseScale = visuals.scale.y.abs();
      if (joystickDelta.x.abs() > 0.05) {
        visuals.scale.x = (joystickDelta.x > 0 ? 1 : -1) * baseScale;
      }

      if (isHovering) {
        _playAnimation(SpineAnimations.hoverboard);
      } else if (!collisionInfo.down) {
        _playAnimation(SpineAnimations.jump);
      } else if (joystickDelta.length > 0.6) {
        _playAnimation(SpineAnimations.run);
      } else if (joystickDelta.length > 0.1) {
        _playAnimation(SpineAnimations.walk);
      } else {
        _playAnimation(SpineAnimations.idle);
      }

      if (_currentTrack2Anim != SpineAnimations.aim) {
        try {
          visuals.animationState.setAnimation(2, SpineAnimations.aim, true);
          _currentTrack2Anim = SpineAnimations.aim;
        } catch (_) {}
      }
    }
  }

  String _currentAnim = "";
  String _currentTrack2Anim = "";
  void _playAnimation(String name, {bool loop = true, double mix = 0.2}) {
    if (_currentAnim == name) return;
    _currentAnim = name;
    try {
      visuals.animationState.setAnimation(0, name, loop).setMixDuration = mix;
    } catch (e) {}
  }
}
