import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spine_flutter/spine_flutter.dart' hide Color, Slider;

import 'game.dart';
import 'play_mode_screen.dart';
import 'player.dart';

// --- Project Model ---
class Project {
  String id;
  String name;
  DateTime lastModified;

  Project({required this.id, required this.name, required this.lastModified});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastModified': lastModified.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'],
        name: json['name'],
        lastModified: DateTime.parse(json['lastModified']),
      );
}

class PartNode {
  final String id;
  final String label;
  final List<PartNode> children;
  PartNode(this.id, this.label, {this.children = const []});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSpineFlutter();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();
  runApp(MaterialApp(
    title: 'Sprout Studio',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.cyan,
      fontFamily: 'Roboto',
      useMaterial3: true,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: SproutStudioHome(),
    ),
  ));
}

class SproutStudioHome extends StatefulWidget {
  const SproutStudioHome({super.key});

  @override
  State<SproutStudioHome> createState() => _SproutStudioHomeState();
}

class _SproutStudioHomeState extends State<SproutStudioHome> {
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final String? projectsJson = prefs.getString('sprout_projects');
    if (projectsJson != null) {
      final List<dynamic> list = jsonDecode(projectsJson);
      setState(() {
        _projects = list.map((item) => Project.fromJson(item)).toList();
        _projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProjectsList() async {
    final prefs = await SharedPreferences.getInstance();
    final String json = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await prefs.setString('sprout_projects', json);
  }

  Future<void> _createNewProject() async {
    String? name = await _showNameDialog("مشروع جديد", "");
    if (name != null && name.isNotEmpty) {
      final newProject = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        lastModified: DateTime.now(),
      );
      setState(() {
        _projects.insert(0, newProject);
      });
      await _saveProjectsList();
      if (mounted) _openProject(newProject);
    }
  }

  Future<void> _renameProject(Project project) async {
    String? newName = await _showNameDialog("تعديل اسم المشروع", project.name);
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        project.name = newName;
        project.lastModified = DateTime.now();
        _projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      });
      await _saveProjectsList();
    }
  }

  Future<void> _deleteProject(Project project) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف المشروع"),
        content:
            Text("هل أنت متأكد من حذف '${project.name}'؟ لا يمكن التراجع."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("حذف", style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('project_data_${project.id}');
      setState(() {
        _projects.remove(project);
      });
      await _saveProjectsList();
    }
  }

  void _openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: RigEditor(project: project),
        ),
      ),
    ).then((_) => _loadProjects());
  }

  Future<String?> _showNameDialog(String title, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "اسم المشروع..."),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text("موافق")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          if (_isLoading)
            const SliverFillRemaining(
                child: const Center(child: CircularProgressIndicator()))
          else if (_projects.isEmpty)
            _buildEmptyState()
          else
            _buildProjectGrid(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("مشروع جديد",
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text("Sprout Studio",
            style: const TextStyle(
                fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.cyan, Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Icon(Icons.auto_awesome_mosaic_rounded,
                size: 80, color: Colors.white.withAlpha(50)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SliverFillRemaining(
      child: const Center(
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text("لا توجد مشاريع حالياً",
                style: const TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            const Text("ابدأ بإنشاء أول شخصية لك الآن",
                style: const TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final p = _projects[index];
            return _buildProjectCard(p);
          },
          childCount: _projects.length,
        ),
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return GestureDetector(
      onTap: () => _openProject(project),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.cyan.withAlpha(50), width: 1),
          boxShadow: const [
            const BoxShadow(color: Colors.black54, blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Icon(Icons.person_pin_rounded,
                    size: 48, color: Colors.cyan),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          "آخر تعديل: ${project.lastModified.day}/${project.lastModified.month}",
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  _buildProjectMenu(project),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectMenu(Project project) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.white54),
      onSelected: (value) {
        if (value == 'rename') _renameProject(project);
        if (value == 'delete') _deleteProject(project);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: const Text("تعديل الاسم")),
        const PopupMenuItem(
            value: 'delete',
            child: const Text("حذف المشروع",
                style: const TextStyle(color: Colors.red))),
      ],
    );
  }
}

// --- Editor Screen: RigEditor ---
class RigEditor extends StatefulWidget {
  final Project project;
  const RigEditor({super.key, required this.project});
  @override
  State<RigEditor> createState() => _RigEditorState();
}

class _RigEditorState extends State<RigEditor> {
  late final CyberReplacedGame game;
  String? selectedPart;
  double posX = 0, posY = 0, angle = 0, scaleX = 1.0, scaleY = 1.0;
  double anchorX = 0.5, anchorY = 0.5, opacity = 1.0;
  int activeTab = 0;
  bool isPanelVisible = true;
  bool isHierarchyVisible = true;
  bool independentMovement = false;

  final List<String> _history = [];
  int _historyIndex = -1;

  List<PartNode> hierarchy = [];
  Map<String, String> partTranslations = {"visuals": "كامل الجسم (Visuals)"};

  @override
  void initState() {
    super.initState();
    game = CyberReplacedGame(
        onPartUpdate: (p, {x, y, a, sx, sy, ax, ay, op, independent = false}) {
      if (mounted) {
        if (p == selectedPart) {
          Future.microtask(() {
            if (mounted) {
              setState(() {
                if (x != null) posX = x;
                if (y != null) posY = y;
                if (a != null) angle = a;
                if (sx != null) scaleX = sx;
                if (sy != null) scaleY = sy;
                if (ax != null) anchorX = ax;
                if (ay != null) anchorY = ay;
                if (op != null) opacity = op;
              });
            }
          });
        }
      }
    });

    _initProjectLoad();
  }

  Future<void> _initProjectLoad() async {
    // ننتظر حتى يتم تحميل اللعبة والمكونات بالكامل
    try {
      await (game as dynamic).ready();
    } catch (_) {
      // Fallback if ready is a getter in this version
      await (game as dynamic).ready;
    }

    if (mounted) {
      setState(() {
        hierarchy = [
          PartNode("visuals", "كامل الجسم"),
          PartNode("hip", "الحوض"),
          PartNode("torso", "الصدر السفلي"),
          PartNode("torso2", "الصدر الأوسط"),
          PartNode("torso3", "الصدر العلوي"),
          PartNode("neck", "الرقبة"),
          PartNode("head", "الرأس"),
          PartNode("front-upper-arm", "العضد الأمامي"),
          PartNode("front-bracer", "الساعد الأمامي"),
          PartNode("front-fist", "القبضة الأمامية"),
          PartNode("rear-upper-arm", "العضد الخلفي"),
          PartNode("rear-bracer", "الساعد الخلفي"),
          PartNode("gun", "السلاح"),
          PartNode("front-thigh", "الفخذ الأمامي"),
          PartNode("front-shin", "الساق الأمامي"),
          PartNode("front-foot", "القدم الأمامي"),
          PartNode("rear-thigh", "الفخذ الخلفي"),
          PartNode("rear-shin", "الساق الخلفي"),
          PartNode("rear-foot", "القدم الخلفي"),
        ];

        final translationMap = {
          "hip": "الحوض",
          "head": "الرأس",
          "neck": "الرقبة",
          "torso": "الجذع",
          "torso2": "الصدر",
          "torso3": "الصدر العلوي",
          "goggles": "النظارات",
          "front-arm-group": "الذراع الأمامية",
          "front-upper-arm": "العضد الأمامي",
          "front-bracer": "الساعد الأمامي",
          "front-fist": "القبضة الأمامية",
          "front-leg-group": "الساق الأمامية",
          "front-thigh": "الفخذ الأمامي",
          "front-shin": "الساق الأمامية",
          "front-foot": "القدم الأمامية",
          "rear-arm-group": "الذراع الخلفية",
          "rear-upper-arm": "العضد الخلفي",
          "rear-bracer": "الساعد الخلفي",
          "gun": "السلاح",
          "rear-leg-group": "الساق الخلفية",
          "rear-thigh": "الفخذ الخلفي",
          "rear-shin": "الساق الخلفية",
          "rear-foot": "القدم الخلفية",
        };
        for (var name in game.player.editorToBoneMap.keys) {
          partTranslations[name] = translationMap[name] ?? name;
        }
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('project_data_${widget.project.id}');
      if (saved != null) {
        await game.player.importJson(saved);
        _history.clear();
        _history.add(saved);
        _historyIndex = 0;
        _syncUIWithPart();
      } else {
        final initial = game.player.exportJson();
        _history.add(initial);
        _historyIndex = 0;
      }
    } catch (e) {
      debugPrint("Error loading project: $e");
    }
  }

  void _pushHistory() {
    final state = game.player.exportJson();
    if (_historyIndex >= 0 && _history[_historyIndex] == state) return;

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(state);
    if (_history.length > 50) _history.removeAt(0);
    _historyIndex = _history.length - 1;

    _autoSave(state);
    setState(() {});
  }

  Future<void> _autoSave(String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('project_data_${widget.project.id}', state);

      final String? projectsJson = prefs.getString('sprout_projects');
      if (projectsJson != null) {
        final List<dynamic> list = jsonDecode(projectsJson);
        final List<Project> projects =
            list.map((item) => Project.fromJson(item)).toList();
        final idx = projects.indexWhere((p) => p.id == widget.project.id);
        if (idx != -1) {
          projects[idx].lastModified = DateTime.now();
          await prefs.setString('sprout_projects',
              jsonEncode(projects.map((p) => p.toJson()).toList()));
        }
      }
    } catch (_) {}
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        game.player.importJson(_history[_historyIndex]);
        _syncUIWithPart();
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        game.player.importJson(_history[_historyIndex]);
        _syncUIWithPart();
      });
    }
  }

  Future<void> _savePersistent() async {
    final state = game.player.exportJson();
    await _autoSave(state);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: const Text("تم حفظ المشروع بنجاح!",
          textAlign: TextAlign.right, textDirection: TextDirection.rtl),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _addNewAttachment() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      String? name = await _showNameDialog("تسمية الملحق الجديد", "ملحق 1");
      if (name != null && name.isNotEmpty) {
        final bytes = await image.readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();

        await game.player.addCustomAttachment(name, frameInfo.image);
        setState(() {
          selectedPart = name;
          game.selectedPartName = name;
          _syncUIWithPart();
        });
        _pushHistory();
      }
    }
  }

  Future<String?> _showNameDialog(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text("موافق")),
          ],
        ),
      ),
    );
  }

  void _syncUIWithPart() {
    if (selectedPart != null && game.isLoaded) {
      try {
        final p = game.player.getPart(selectedPart!);
        final s = game.player.getSpriteForPart(selectedPart!);
        setState(() {
          posX = p.position.x;
          posY = p.position.y;
          angle = p.angle;
          scaleX = p.scale.x;
          scaleY = p.scale.y;
          anchorX = p.anchor.x;
          anchorY = p.anchor.y;
          opacity = (s != null) ? s.opacity : 1.0;
        });
      } catch (e) {
        debugPrint("Sync UI error: $e");
      }
    }
  }

  void _showJsonDialog() {
    final controller = TextEditingController(text: game.player.exportJson());
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تبادل البيانات (JSON)"),
          content: TextField(
            controller: controller,
            maxLines: 8,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "قم بلصق كود الشخصية هنا..."),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () {
                try {
                  game.player.importJson(controller.text);
                  Navigator.pop(ctx);
                  setState(() => _syncUIWithPart());
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("خطأ في البيانات: $e")));
                }
              },
              child: const Text("استيراد"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) {
              game.handleTap(
                  Vector2(details.localPosition.dx, details.localPosition.dy));
            },
            child: GameWidget(game: game),
          ),

          // Top Header Bar
          Positioned(
            left: 20,
            top: 40,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconBtn(Icons.close_rounded, () => Navigator.pop(context),
                    Colors.white24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyan.withAlpha(100))),
                  child: Text(widget.project.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.cyan)),
                ),
                _iconBtn(Icons.save_rounded, _savePersistent,
                    Colors.cyan.withAlpha(100)),
                _iconBtn(Icons.play_arrow_rounded, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayModeScreen(
                        characterData: game.player.exportJson(),
                      ),
                    ),
                  );
                }, Colors.green.withAlpha(100)),
              ],
            ),
          ),

          // Left Panel Toggle
          Positioned(
            left: isHierarchyVisible ? 240 : 0,
            top: 110,
            child: _toggleButton(
                onTap: () =>
                    setState(() => isHierarchyVisible = !isHierarchyVisible),
                icon: isHierarchyVisible
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                isLeft: true),
          ),
          // Right Panel Toggle
          Positioned(
            right: isPanelVisible ? 280 : 0,
            top: 110,
            child: _toggleButton(
                onTap: () => setState(() => isPanelVisible = !isPanelVisible),
                icon: isPanelVisible ? Icons.chevron_right : Icons.chevron_left,
                isLeft: false),
          ),

          // Hierarchy Sidebar (Left)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isHierarchyVisible ? 0 : -240,
            top: 0,
            bottom: 0,
            child: _glassPanel(
                width: 240,
                isLeft: true,
                child: Column(children: [
                  _buildHierarchyHeader(),
                  Expanded(child: _buildCategorizedHierarchy())
                ])),
          ),

          // Inspector Sidebar (Right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: isPanelVisible ? 0 : -280,
            top: 0,
            bottom: 0,
            child: _glassPanel(
                width: 280,
                isLeft: false,
                child: Column(children: [
                  _buildInspectorHeader(),
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(children: [
                            _buildTabs(),
                            const Divider(color: Colors.white10, height: 32),
                            if (selectedPart != null) _buildActiveTabContent()
                          ]))),
                  _buildBottomActions()
                ])),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, Color bg) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: Colors.white)),
      );

  Widget _toggleButton(
          {required VoidCallback onTap,
          required IconData icon,
          required bool isLeft}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            width: 36,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.horizontal(
                    left: isLeft ? Radius.zero : const Radius.circular(8),
                    right: isLeft ? const Radius.circular(8) : Radius.zero),
                border:
                    Border.all(color: Colors.cyan.withAlpha(80), width: 0.5)),
            child: Icon(icon, color: Colors.cyan, size: 20)),
      );

  Widget _glassPanel(
          {required double width,
          required Widget child,
          required bool isLeft}) =>
      Container(
        width: width,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withAlpha(220),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 15,
                  offset: Offset(isLeft ? 5 : -5, 0))
            ],
            border: Border(
                left: isLeft
                    ? BorderSide.none
                    : const BorderSide(color: Colors.cyan, width: 0.5),
                right: isLeft
                    ? const BorderSide(color: Colors.cyan, width: 0.5)
                    : BorderSide.none)),
        child: child,
      );

  Widget _buildHierarchyHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
        child: const Row(children: [
          Icon(Icons.account_tree_rounded, color: Colors.cyan, size: 20),
          SizedBox(width: 8),
          Text("الهيكل والملحقات",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white))
        ]),
      );

  Widget _buildCategorizedHierarchy() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _sectionTitle("الهيكل الأساسي", Icons.boy_rounded),
        ...hierarchy.map((node) => _buildPartTree(node)),
        const SizedBox(height: 20),
        _sectionTitle("الملحقات الخارجية", Icons.auto_awesome_motion_rounded),
        if (game.player.customAttachments.isEmpty)
          const Padding(
              padding: const EdgeInsets.all(12),
              child: const Text("لا توجد ملحقات حالياً",
                  style: const TextStyle(fontSize: 11, color: Colors.white24)))
        else
          ...game.player.customAttachments.keys
              .map((name) => _buildPartItem(name, name, depth: 0)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _addNewAttachment,
          icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
          label: const Text("إضافة ملحق جديد",
              style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.withAlpha(30),
              foregroundColor: Colors.cyan,
              side: const BorderSide(color: Colors.cyan, width: 0.5)),
        ),
      ],
    );
  }

  Widget _buildPartTree(PartNode node, {int depth = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPartItem(node.id, node.label, depth: depth),
        if (node.children.isNotEmpty)
          ...node.children
              .map((child) => _buildPartTree(child, depth: depth + 1)),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.cyan.withAlpha(150)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white38))
        ]),
      );

  Widget _buildPartItem(String id, String label, {int depth = 0}) {
    bool isSelected = selectedPart == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPart = id;
          game.selectedPartName = id;
          _syncUIWithPart();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: isSelected
                ? Colors.cyan.withOpacity(0.2)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected
                    ? Colors.cyan.withOpacity(0.6)
                    : Colors.white.withOpacity(0.05),
                width: 1)),
        child: Row(children: [
          Icon(Icons.layers_outlined,
              size: 14, color: isSelected ? Colors.cyanAccent : Colors.white38),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                  overflow: TextOverflow.ellipsis))
        ]),
      ),
    );
  }

  Widget _buildInspectorHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("مفتش العناصر",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text("تعديل الخصائص الهندسية",
                  style: const TextStyle(fontSize: 10, color: Colors.white38)),
            ]),
      );

  Widget _buildTabs() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _tabIcon(0, Icons.open_with_rounded, "الأبعاد"),
        _tabIcon(1, Icons.auto_fix_high_rounded, "المظهر"),
        _tabIcon(2, Icons.settings_suggest_rounded, "النظام"),
        _tabIcon(3, Icons.movie_creation_rounded, "الحركة"),
      ]);

  Widget _tabIcon(int index, IconData icon, String label) {
    bool active = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => activeTab = index),
      child: Column(children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: active ? Colors.cyan.withAlpha(50) : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon,
                color: active ? Colors.cyan : Colors.white38, size: 24)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: active ? Colors.cyan : Colors.white38)),
      ]),
    );
  }

  Widget _buildActiveTabContent() {
    // نمنع الوصول لبيانات اللاعب إذا لم يتم تحميل الهيكل العظمي بعد
    if (!game.isLoaded) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.cyan),
              SizedBox(height: 16),
              Text("جاري تحميل الهيكل...",
                  style: TextStyle(color: Colors.white38, fontSize: 12))
            ],
          ),
        ),
      );
    }

    switch (activeTab) {
      case 0:
        return Column(children: [
          _switchRow("تحريك مستقل (فصل الأبناء)", independentMovement,
              (v) => setState(() => independentMovement = v)),
          const Divider(color: Colors.white10),
          _controlRow(
              "الموقع الأفقي",
              posX,
              -1000,
              1000,
              1,
              (v) => game.updatePart(selectedPart!,
                  x: v, independent: independentMovement),
              onEnd: _pushHistory),
          _controlRow(
              "الموقع الرأسي",
              posY,
              -1000,
              1000,
              1,
              (v) => game.updatePart(selectedPart!,
                  y: v, independent: independentMovement),
              onEnd: _pushHistory),
          _controlRow("زاوية الدوران", angle, -6.28, 6.28, 0.05,
              (v) => game.updatePart(selectedPart!, a: v, independent: true),
              onEnd: _pushHistory),
          _controlRow("طول العضو", scaleY, 0.1, 10.0, 0.05,
              (v) => game.updatePart(selectedPart!, sy: v, independent: true),
              onEnd: _pushHistory),
          _controlRow("سمك العضو", scaleX, 0.1, 10.0, 0.05,
              (v) => game.updatePart(selectedPart!, sx: v, independent: true),
              onEnd: _pushHistory),
          _switchRow("الربط المتماثل (Mirror)", game.isMirroring,
              (v) => setState(() => game.isMirroring = v)),
          _switchRow("قلب الشخصية (Flip)", game.player.visuals.scale.x < 0,
              (v) {
            setState(() {
              game.player.visuals.scale.x = v ? -1.0 : 1.0;
              game.player.visuals.position.x = v ? game.player.size.x : 0;
            });
          }),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
                    onPressed: _historyIndex > 0 ? _undo : null,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text("تراجع"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white))),
            const SizedBox(width: 8),
            Expanded(
                child: ElevatedButton.icon(
                    onPressed:
                        _historyIndex < _history.length - 1 ? _redo : null,
                    icon: const Icon(Icons.redo_rounded, size: 18),
                    label: const Text("تقديم"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white))),
          ]),
        ]);
      case 1:
        return Column(children: [
          _controlRow("نقطة الارتكاز X", anchorX, 0, 1, 0.05,
              (v) => game.updatePart(selectedPart!, ax: v),
              onEnd: _pushHistory),
          _controlRow("نقطة الارتكاز Y", anchorY, 0, 1, 0.05,
              (v) => game.updatePart(selectedPart!, ay: v),
              onEnd: _pushHistory),
          _controlRow("الشفافية", opacity, 0, 1, 0.05,
              (v) => game.updatePart(selectedPart!, op: v),
              onEnd: _pushHistory),
          const Divider(color: Colors.white10),
          _buildAttachmentSelector("تعبير العين", "eye", [
            "eye-indifferent",
            "eye-surprised",
          ]),
          const SizedBox(height: 12),
          _buildAttachmentSelector("وضعية الفم", "mouth", [
            "mouth-smile",
            "mouth-oooo",
            "mouth-grind",
          ]),
          const SizedBox(height: 12),
          _buildHandPoseSelector(),
        ]);
      case 2:
        return Column(children: [
          _controlRow(
              "ترتيب الطبقة",
              game.player.getPart(selectedPart!).priority.toDouble(),
              -20,
              20,
              1,
              (v) => setState(() =>
                  game.player.getPart(selectedPart!).priority = v.toInt()),
              onEnd: _pushHistory),
        ]);
      case 3:
        return Column(children: [
          _switchRow("وضع المحاكاة (Live)", game.testMode,
              (v) => setState(() => game.testMode = v)),
          _switchRow("قفل التحديد اليدوي", game.isSelectionLocked,
              (v) => setState(() => game.isSelectionLocked = v)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _poseBtn("قفز", "Jump")),
            const SizedBox(width: 8),
            Expanded(child: _poseBtn("هجوم", "Attack")),
            const SizedBox(width: 8),
            Expanded(child: _poseBtn("ثبات", "Idle"))
          ]),
          const SizedBox(height: 16),
          _controlRow("سرعة المشي", game.player.walkSpeed, 0, 30, 1,
              (v) => setState(() => game.player.walkSpeed = v)),
          _controlRow("نعومة الحركة", game.player.lerpSpeed, 1, 50, 1,
              (v) => setState(() => game.player.lerpSpeed = v)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
              onPressed: _showJsonDialog,
              icon: const Icon(Icons.cloud_sync_rounded),
              label: const Text("تبادل البيانات (JSON)"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade900,
                  minimumSize: const Size(double.infinity, 45))),
        ]);
      default:
        return Container();
    }
  }

  Widget _buildHandPoseSelector() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("وضعية اليد",
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<HandPose>(
                    value: game.player.currentHandPose,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF222222),
                    items: HandPose.values
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text(_translateHandPose(e))))
                        .toList(),
                    onChanged: (v) {
                      game.player.setHandPose(v!);
                      setState(() => _syncUIWithPart());
                      _pushHistory();
                    }))),
      ]);

  Widget _buildAttachmentSelector(
      String label, String slot, List<String> options) {
    String? current = "";
    try {
      current =
          game.player.visuals.skeleton.findSlot(slot)?.pose.attachment?.name;
    } catch (_) {}

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      const SizedBox(height: 4),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  value: options.contains(current) ? current : options.first,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF222222),
                  items: options
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    game.player.setAttachment(slot, v);
                    setState(() {});
                    _pushHistory();
                  }))),
    ]);
  }

  String _translateHandPose(HandPose p) {
    switch (p) {
      case HandPose.idle:
        return "طبيعية";
      case HandPose.fist:
        return "قبضة مغلقة";
      case HandPose.trigger:
        return "وضعية إطلاق";
      case HandPose.grip:
        return "إمساك سلاح";
    }
  }

  Widget _buildBottomActions() => Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black26,
      child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: _savePersistent,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text("حفظ المشروع",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12)))));

  Widget _poseBtn(String label, String p) => ElevatedButton(
      onPressed: () => _applyPose(p),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
      child: Text(label));

  Widget _switchRow(String label, bool val, ValueChanged<bool> cb) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        Switch(
            value: val,
            onChanged: cb,
            activeTrackColor: Colors.cyan.withAlpha(100),
            activeThumbColor: Colors.cyan,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)
      ]));

  void _applyPose(String pose) {
    if (pose == "Jump") {
      game.player.playEditorAnimation("jump");
    } else if (pose == "Idle") {
      game.player.playEditorAnimation("idle");
    } else if (pose == "Attack") {
      game.player.playEditorAnimation("shoot");
    }
    setState(() => _syncUIWithPart());
  }

  Widget _controlRow(String label, double val, double min, double max,
          double step, ValueChanged<double> cb,
          {VoidCallback? onEnd}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(val.toStringAsFixed(2),
                style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'))
          ]),
          Row(children: [
            GestureDetector(
                onTap: () {
                  cb((val - step).clamp(min, max));
                  onEnd?.call();
                },
                child: const Icon(Icons.remove_circle_outline,
                    color: Colors.white24, size: 20)),
            Expanded(
                child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14)),
                    child: Slider(
                        value: val.clamp(min, max),
                        min: min,
                        max: max,
                        onChanged: cb,
                        onChangeEnd: (v) => onEnd?.call()))),
            GestureDetector(
                onTap: () {
                  cb((val + step).clamp(min, max));
                  onEnd?.call();
                },
                child: const Icon(Icons.add_circle_outline,
                    color: Colors.white24, size: 20)),
          ]),
        ]),
      );
}
