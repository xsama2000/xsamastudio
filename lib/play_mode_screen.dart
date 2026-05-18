import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import 'constants.dart';
import 'game.dart';

class PlayModeScreen extends StatefulWidget {
  final String characterData;
  const PlayModeScreen({super.key, required this.characterData});

  @override
  State<PlayModeScreen> createState() => _PlayModeScreenState();
}

class _PlayModeScreenState extends State<PlayModeScreen>
    with SingleTickerProviderStateMixin {
  late final CyberReplacedGame game;
  bool _isReady = false;
  bool _showSensitivitySettings = false;
  late AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    game = CyberReplacedGame(
        onPartUpdate: (_, {a, ax, ay, independent, op, sx, sy, x, y}) {});
    game.showJoystick = false;
    _loadCharacter();
  }

  Future<void> _loadCharacter() async {
    await game.ready();
    await game.player.importJson(widget.characterData);

    try {
      game.player.playAnimation(SpineAnimations.portal, loop: false);
      _introController.forward();
    } catch (_) {}

    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final baseUnit = isLandscape ? screenSize.height : screenSize.width;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // 1. The Game World
          if (_isReady) GameWidget(game: game),

          // 2. Dedicated Aim Touch Area (Left Side Overlay)
          if (_isReady)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: screenSize.width * 0.45,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  game.updateAimY(details.delta.dy);
                },
              ),
            ),

          // 3. Cinematic Loading Transition (Wrapped in IgnorePointer to allow touches below once faded)
          IgnorePointer(
            ignoring: _introController.isCompleted,
            child: FadeTransition(
              opacity: ReverseAnimation(_introController),
              child: Container(
                  color: Colors.black,
                  child: const Center(
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent))),
            ),
          ),

          // 4. UI Layer
          if (_isReady) ...[
            // Back Button
            Positioned(
              top: screenSize.height * 0.05,
              left: screenSize.width * 0.03,
              child: _circularBtn(Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context), Colors.white24,
                  size: baseUnit * 0.1),
            ),

            // Settings Button
            Positioned(
              top: screenSize.height * 0.05,
              right: screenSize.width * 0.03,
              child: _circularBtn(
                  _showSensitivitySettings
                      ? Icons.check_rounded
                      : Icons.tune_rounded,
                  () => setState(() =>
                      _showSensitivitySettings = !_showSensitivitySettings),
                  _showSensitivitySettings
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.white24,
                  size: baseUnit * 0.1),
            ),

            if (_showSensitivitySettings)
              Positioned(
                top: screenSize.height * 0.18,
                right: screenSize.width * 0.03,
                child: Container(
                  width: baseUnit * 0.4,
                  padding: EdgeInsets.all(baseUnit * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("حساسية التصويب",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: baseUnit * 0.025,
                              fontWeight: FontWeight.bold)),
                      Slider(
                        value: game.aimSensitivity,
                        min: 0.1,
                        max: 3.0,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) =>
                            setState(() => game.aimSensitivity = val),
                      ),
                      Text(game.aimSensitivity.toStringAsFixed(1),
                          style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: baseUnit * 0.02)),
                    ],
                  ),
                ),
              ),

            // Mode Indicator
            Positioned(
              top: screenSize.height * 0.06,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: baseUnit * 0.05, vertical: baseUnit * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.5),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          blurRadius: 15)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt,
                          color: Colors.cyanAccent, size: baseUnit * 0.04),
                      const SizedBox(width: 8),
                      Text(
                        "وضع المحاكاة القتالية",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: baseUnit * 0.035,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Joystick (Bottom Left)
            Positioned(
              bottom: screenSize.height * 0.05,
              left: screenSize.width * 0.05,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black38,
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15)
                  ],
                ),
                child: SizedBox(
                  width: baseUnit * 0.18,
                  height: baseUnit * 0.18,
                  child: Joystick(
                    mode: JoystickMode.horizontalAndVertical,
                    listener: (details) {
                      game.externalJoystickDelta =
                          Vector2(details.x, details.y);
                    },
                  ),
                ),
              ),
            ),

            // Action Buttons (Bottom Right)
            Positioned(
              bottom: screenSize.height * 0.04,
              right: screenSize.width * 0.05,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionBtn(
                          "زلاجة",
                          Icons.auto_awesome_motion_rounded,
                          game.player.isHovering
                              ? Colors.greenAccent
                              : Colors.white24, () {
                        setState(() {
                          game.player.isHovering = !game.player.isHovering;
                        });
                      }, size: baseUnit * 0.12),
                      SizedBox(width: baseUnit * 0.03),
                      if (game.player.isDead)
                        _actionBtn(
                            "إنعاش", Icons.auto_fix_high_rounded, Colors.amber,
                            () {
                          setState(() {
                            game.player.revive();
                          });
                        }, size: baseUnit * 0.12)
                      else
                        _actionBtn("موت", Icons.dangerous_rounded, Colors.grey,
                            () {
                          setState(() {
                            game.player
                                .playEditorAnimation(SpineAnimations.death);
                          });
                        }, size: baseUnit * 0.12),
                    ],
                  ),
                  SizedBox(height: baseUnit * 0.03),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionBtn("قفز", Icons.vertical_align_top_rounded,
                          Colors.blueAccent, () => game.jump(),
                          size: baseUnit * 0.16),
                      SizedBox(width: baseUnit * 0.03),
                      _actionBtn(
                          "إطلاق", Icons.gps_fixed_rounded, Colors.redAccent,
                          () {
                        game.shoot();
                      }, size: baseUnit * 0.16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _circularBtn(IconData icon, VoidCallback onTap, Color bg,
          {required double size}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      );

  Widget _actionBtn(
          String label, IconData icon, Color color, VoidCallback onTap,
          {required double size}) =>
      GestureDetector(
        onTapDown: (_) => onTap(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.6), width: 3),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 2),
                ],
              ),
              child: Icon(icon, color: color, size: size * 0.45),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.22,
                  shadows: [Shadow(color: color, blurRadius: 10)]),
            ),
          ],
        ),
      );
}
