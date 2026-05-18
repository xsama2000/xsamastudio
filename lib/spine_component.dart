import 'dart:ui';

import 'package:flame/components.dart';
import 'package:spine_flutter/spine_flutter.dart';

/// كلاس يربط محرك Spine بمحرك Flame
class SpineComponent extends PositionComponent {
  final SkeletonDrawableFlutter _drawable;
  late final Bounds _bounds;
  final bool _ownsDrawable;

  SpineComponent(
    this._drawable, {
    bool ownsDrawable = true,
    super.position,
    super.scale,
    double super.angle = 0.0,
    Anchor super.anchor = Anchor.topLeft,
    super.priority,
  }) : _ownsDrawable = ownsDrawable {
    _drawable.update(0);
    _bounds = _drawable.skeleton.bounds;
    // تعيين حجم المكون بناءً على أبعاد الهيكل العظمي
    size = Vector2(_bounds.width, _bounds.height);
  }

  /// تحميل الشخصية مباشرة من ملفات الـ Assets
  static Future<SpineComponent> fromAssets(
    String atlasFile,
    String skeletonFile, {
    Vector2? position,
    Vector2? scale,
    double angle = 0.0,
    Anchor anchor = Anchor.topLeft,
    int? priority,
  }) async {
    final drawable =
        await SkeletonDrawableFlutter.fromAsset(atlasFile, skeletonFile);
    return SpineComponent(
      drawable,
      ownsDrawable: true,
      position: position,
      scale: scale,
      angle: angle,
      anchor: anchor,
      priority: priority,
    );
  }

  void Function(Skeleton skeleton)? onAfterAnimationApplied;

  @override
  void update(double dt) {
    _drawable.animationState.update(dt);
    _drawable.animationState.apply(_drawable.skeleton);
    onAfterAnimationApplied?.call(_drawable.skeleton);
    _drawable.skeleton.updateWorldTransform(Physics.update);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    // ضبط الإحداثيات لتتطابق مع نظام Flame
    canvas.translate(-_bounds.x, -_bounds.y);
    _drawable.renderToCanvas(canvas);
    canvas.restore();
  }

  Skeleton get skeleton => _drawable.skeleton;
  AnimationState get animationState => _drawable.animationState;

  @override
  void onRemove() {
    if (_ownsDrawable) _drawable.dispose();
    super.onRemove();
  }
}
