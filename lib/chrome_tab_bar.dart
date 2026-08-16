/*! ChromeTabBar — Chrome 风格浏览器标签组件（零第三方依赖）
 *
 * 库只包含标签条本体，页面内容由使用方自定义（监听 controller 自行渲染）。
 *   - 形态：tab 高 34 / 条高 38，顶部圆角 8px，宽 72–240px 弹性等分；
 *           放不下时不再压缩，左侧出现矩形下拉按钮，收起剩余标签（激活项始终保持在可见窗口内）
 *   - 耳角：激活 tab 两侧 8px 外扩凹弧（concave flare），翼与工具栏同色连通；
 *           四分之一圆透明区透出邻 tab 真实背景（静止 = 标签条色，悬停 = 邻 tab 悬停色，天然联动）
 *   - 状态：激活 = 页面同色 / 默认透明 / 悬停微亮圆角 8；分隔线仅相邻非激活 tab 间 1px
 *   - 交互：单击切换、× / 中键关闭、关闭激活 tab 自动接右邻（无则左邻）、最后一个关闭自动补"新标签页"
 *   - 溢出：左侧下拉按钮弹出剩余标签菜单，可激活 / 关闭；点外部关闭
 *   - 键盘：roving focus + ←/→ 移动（含隐藏标签，窗口自动平移）+ Enter/Space 激活
 *   - 动效：悬停 / 关闭钮指数 ease-out 渐变（首帧即达 ~40%，~150ms 收敛）
 *
 * 用法：
 *   final controller = TabBarController(initialTabs: [TabData(title: '示例', url: 'example.com')]);
 *   ChromeTabBar(
 *     controller: controller,
 *     onChange: (e) { ... },        // e.type: add / activate / close / update
 *   );
 *   controller.add(TabData(title: '...'));   // 新增并激活，返回 id
 *   controller.close(id);                    // 关闭（自动激活邻 tab，空时自动补位）
 *   controller.activate(id);                 // 激活
 *   controller.update(id, title: '...');     // 更新数据
 *   controller.active();                     // 当前激活 id
 */
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;

// ============================================================
// 数据模型
// ============================================================

/// 标签数据（对应 web 版 data: { title, url, color }）
class TabData {
  const TabData({this.id, required this.title, this.url, this.color});

  /// 不传则自动分配 'tab-N'
  final String? id;
  final String title;
  final String? url;

  /// favicon 底色；不传则按默认色板轮换（add 时固化，之后不再随位置变化）
  final Color? color;
}

/// 变更事件类型（对应 web 版 onChange 的 e.type）
enum TabChangeType { add, activate, close, update }

class TabBarChangeEvent {
  const TabBarChangeEvent({
    required this.type,
    required this.id,
    this.data,
    this.nextId,
  });

  final TabChangeType type;
  final String id;
  final TabData? data;
  final String? nextId;
}

// ============================================================
// 样式令牌（对应 tab.css 的 --tab-* 变量）
// ============================================================

class TabBarStyle {
  const TabBarStyle({
    required this.stripBg,
    required this.pageBg,
    required this.fg,
    required this.fgMuted,
    required this.line,
    required this.hoverOverlay,
    required this.btnHover,
    required this.focus,
  });

  /// 标签条底色（--tab-strip-bg）
  final Color stripBg;

  /// 激活 tab / 工具栏色，同色连通（--tab-page-bg）
  final Color pageBg;

  /// 主文字（--tab-fg）
  final Color fg;

  /// 次级文字（--tab-fg-muted）
  final Color fgMuted;

  /// 分隔线 / 描边（--tab-line）
  final Color line;

  /// 非激活悬停叠加色（--tab-hover-bg，自带透明度）
  final Color hoverOverlay;

  /// 关闭 / 新建按钮悬停底色（--tab-btn-hover）
  final Color btnHover;

  /// 键盘焦点环（--tab-focus）
  final Color focus;

  /// 尺寸令牌（--tab-height / --tab-min-w / --tab-max-w / --tab-r）
  static const double tabHeight = 34;
  static const double stripTopPad = 4; // 条高 38 = 顶部留白 4 + tab 34
  static const double minTabWidth = 72;
  static const double maxTabWidth = 240;
  static const double radius = 8;

  /// 关闭按钮边长（对应 CSS .tabbar-close 16×16，radius 4）
  static const double closeSize = 16;

  factory TabBarStyle.of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const TabBarStyle light = TabBarStyle(
    stripBg: Color(0xFFDEE1E6),
    pageBg: Color(0xFFFFFFFF),
    fg: Color(0xFF202124),
    fgMuted: Color(0xFF5F6368),
    line: Color(0x29202124), // rgba(32,33,36,.16)
    hoverOverlay: Color(0x73FFFFFF), // rgba(255,255,255,.45)
    btnHover: Color(0x17202124), // rgba(32,33,36,.09)
    focus: Color(0xFF1A73E8),
  );

  static const TabBarStyle dark = TabBarStyle(
    stripBg: Color(0xFF202124),
    pageBg: Color(0xFF35363A),
    fg: Color(0xFFE8EAED),
    fgMuted: Color(0xFF9AA0A6),
    line: Color(0x29E8EAED), // rgba(232,234,237,.16)
    hoverOverlay: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    btnHover: Color(0x24E8EAED), // rgba(232,234,237,.14)
    focus: Color(0xFF8AB4F8),
  );
}

/// favicon 默认色板（对应 tab.js DEFAULT_PALETTE）
const List<Color> kDefaultPalette = [
  Color(0xFF3C2ECA),
  Color(0xFF6F6FFF),
  Color(0xFF22A5F7),
  Color(0xFF0F766E),
  Color(0xFFB73B2F),
  Color(0xFFBE185D),
];

/// 亮度 > 160 返回 true → favicon 用深色文字（对应 tab.js isLightColor）
bool _isLightColor(Color c) =>
    0.299 * (c.r * 255.0) + 0.587 * (c.g * 255.0) + 0.114 * (c.b * 255.0) > 160;

// ============================================================
// 控制器（对应 tab.js 的 TabBar 类）
// ============================================================

class TabBarController extends ChangeNotifier {
  /// [initialTabs] 初始化标签（静默：补 id / 默认色，首个自动激活，不触发事件）
  TabBarController({List<TabData> initialTabs = const [], this.onChange})
      : _tabs = <TabData>[] {
    for (final t in initialTabs) {
      _tabs.add(_resolve(t));
    }
    if (_tabs.isNotEmpty) _activeId = _tabs.first.id;
  }

  /// 对应 web 版 onChange 回调（e.type: add|activate|close|update）
  ValueChanged<TabBarChangeEvent>? onChange;

  final List<TabData> _tabs;
  String? _activeId;
  int _seq = 0;

  List<TabData> get tabs => List.unmodifiable(_tabs);
  String? active() => _activeId;
  int get count => _tabs.length;

  TabData? get(String id) {
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  int indexOf(String id) {
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].id == id) return i;
    }
    return -1;
  }

  /// 补 id 与默认 favicon 色（色板按序号轮换，固化到数据上）
  TabData _resolve(TabData t) {
    final id = t.id ?? 'tab-${++_seq}';
    _seq = math.max(_seq, _intSeqOf(id));
    final color = t.color ?? kDefaultPalette[_seq % kDefaultPalette.length];
    return TabData(id: id, title: t.title, url: t.url, color: color);
  }

  /// 新增标签（追加到末尾）。[activate] 默认 true；首个标签必然激活。
  String add(TabData data, {bool activate = true}) {
    final t = _resolve(data);
    if (get(t.id!) != null) return t.id!;
    _tabs.add(t);
    notifyListeners();
    if (activate || _tabs.length == 1) {
      this.activate(t.id!);
    }
    _emit(TabBarChangeEvent(type: TabChangeType.add, id: t.id!, data: t));
    return t.id!;
  }

  /// 关闭标签：关闭激活 tab 时自动激活右邻（无则左邻）；最后一个被关闭时自动补"新标签页"
  void close(String id) {
    final idx = indexOf(id);
    if (idx < 0) return;
    final wasActive = _activeId == id;
    _tabs.removeAt(idx);

    String? nextId;
    if (_tabs.isEmpty) {
      nextId = add(const TabData(title: '新标签页'));
    } else if (wasActive) {
      final next = _tabs[math.min(idx, _tabs.length - 1)];
      activate(next.id!);
      nextId = next.id;
    }
    notifyListeners();
    _emit(TabBarChangeEvent(type: TabChangeType.close, id: id, nextId: nextId));
  }

  /// 激活标签
  void activate(String id) {
    if (get(id) == null) return;
    _activeId = id;
    notifyListeners();
    _emit(TabBarChangeEvent(type: TabChangeType.activate, id: id, data: get(id)));
  }

  /// 更新标题 / 地址
  void update(String id, {String? title, String? url}) {
    final idx = indexOf(id);
    if (idx < 0) return;
    final old = _tabs[idx];
    _tabs[idx] = TabData(
      id: old.id,
      title: title ?? old.title,
      url: url ?? old.url,
      color: old.color,
    );
    notifyListeners();
    _emit(TabBarChangeEvent(type: TabChangeType.update, id: id, data: _tabs[idx]));
  }

  int _intSeqOf(String id) {
    final m = RegExp(r'tab-(\d+)$').firstMatch(id);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  void _emit(TabBarChangeEvent e) => onChange?.call(e);
}

// ============================================================
// 组件（对应 web 版 DOM/CSS 结构）
// ============================================================

class ChromeTabBar extends StatefulWidget {
  const ChromeTabBar({
    super.key,
    required this.controller,
    this.style,
    this.onChange,
    this.label = '浏览器标签页',
  });

  /// 溢出下拉按钮的 Key（测试 / 使用方定位用）。
  /// 用 ValueKey 而非 GlobalKey：多条 ChromeTabBar 并存时不会产生重复 Key 冲突。
  static const Key overflowButtonKey = ValueKey('chrome_tab_bar_overflow');

  final TabBarController controller;

  /// 样式令牌；缺省按 Theme 亮度自动选择（对应 CSS 明暗主题）
  final TabBarStyle? style;

  /// 便捷回调（与 controller.onChange 同时触发）
  final ValueChanged<TabBarChangeEvent>? onChange;

  final String label;

  @override
  State<ChromeTabBar> createState() => _ChromeTabBarState();
}

/// 溢出时的可见窗口布局（画布只绘制 / 命中 [visibleStart, visibleStart + visibleCount)）
class _OverflowLayout {
  const _OverflowLayout({
    required this.tabWidth,
    required this.visibleCount,
    required this.visibleStart,
  });

  final double tabWidth;
  final int visibleCount;
  final int visibleStart;

  bool isVisible(int index) =>
      index >= visibleStart && index < visibleStart + visibleCount;
}

class _ChromeTabBarState extends State<ChromeTabBar> {
  /// 溢出窗口起始索引（持久化：激活 / 键盘焦点平移窗口，而非每次从 0 起）
  int _windowStart = 0;

  /// 最近一次布局结果（供 _ensureVisibleWindow 平移窗口时读取容量）
  _OverflowLayout? _layout;

  TabBarStyle get _style =>
      widget.style ?? TabBarStyle.of(Theme.of(context).brightness);

  @override
  void initState() {
    super.initState();
    // 便捷回调与 controller.onChange 链接（原有回调先触发），不覆盖
    final outer = widget.onChange;
    if (outer != null) {
      final prev = widget.controller.onChange;
      widget.controller.onChange =
          prev == null ? outer : (e) { prev(e); outer(e); };
    }
  }

  // ---- 布局：对应 CSS flex:1 1 0; min-width:72; max-width:240 ----
  double _tabWidth(double viewportInner, int n) {
    if (n == 0) return TabBarStyle.minTabWidth;
    return (viewportInner / n)
        .clamp(TabBarStyle.minTabWidth, TabBarStyle.maxTabWidth);
  }

  /// 溢出布局：可见 tab 按最小宽 72 算容量（至少 1 个），
  /// 窗口平移保证激活 tab 始终可见（激活隐藏 tab → 窗口跳转过去）
  _OverflowLayout _overflowLayout(double viewportInner, int count) {
    final c = widget.controller;
    final visibleCount = math
        .max(1, math.min(count, viewportInner ~/ TabBarStyle.minTabWidth));
    final tabWidth = (viewportInner / visibleCount)
        .clamp(TabBarStyle.minTabWidth, TabBarStyle.maxTabWidth);

    final activeIdx =
        c.active() == null ? 0 : math.max(0, c.indexOf(c.active()!));
    if (activeIdx < _windowStart) _windowStart = activeIdx;
    if (activeIdx >= _windowStart + visibleCount) {
      _windowStart = activeIdx - visibleCount + 1;
    }
    _windowStart = _windowStart.clamp(0, count - visibleCount);
    return _OverflowLayout(
      tabWidth: tabWidth,
      visibleCount: visibleCount,
      visibleStart: _windowStart,
    );
  }

  /// 键盘 roving focus 移入隐藏区时平移窗口（焦点环保持可见）
  void _ensureVisibleWindow(int index) {
    final l = _layout;
    if (l == null || l.isVisible(index)) return;
    setState(() {
      _windowStart =
          index < l.visibleStart ? index : index - l.visibleCount + 1;
      _windowStart =
          _windowStart.clamp(0, widget.controller.count - l.visibleCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Semantics(
          label: widget.label,
          child: Container(
            // .tabbar：高 38（顶 4 + tab 34），右侧留 4
            height: TabBarStyle.stripTopPad + TabBarStyle.tabHeight,
            padding: const EdgeInsets.only(
              top: TabBarStyle.stripTopPad,
              right: 4,
            ),
            color: style.stripBg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // ---- 宽度配账（必须与 Row 实际占位一致，否则内容画出界压到 + 按钮）----
                // 总宽 = 右留白 4 + 新建按钮 40 + (溢出时下拉按钮 36) + tab 内容区
                final total = constraints.maxWidth;
                final count = c.count;
                final base = total - 4 - _NewTabButton.footprint; // 无溢出内容宽
                final withBtn = base - _OverflowButton.footprint; // 溢出内容宽
                // 溢出判定：按最小宽 72 都放不下才算溢出（此时插入下拉按钮）
                final over =
                    count > 0 && count * TabBarStyle.minTabWidth > base;
                // Padding(16) 之后的内容宽 = Expanded 宽 - 耳角留白，tabWidth 按它均分
                final contentW = over ? withBtn : base;
                if (!over) _windowStart = 0;
                final layout = over
                    ? _overflowLayout(contentW, count)
                    : _OverflowLayout(
                        tabWidth: _tabWidth(contentW, count),
                        visibleCount: count,
                        visibleStart: 0,
                      );
                _layout = layout;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (over)
                      _OverflowButton(
                        key: ChromeTabBar.overflowButtonKey,
                        controller: c,
                        style: style,
                        hiddenTabs: [
                          for (var i = 0; i < count; i++)
                            if (!layout.isVisible(i)) c.tabs[i],
                        ],
                      ),
                    Expanded(
                      child: Padding(
                        // 左右留白给首尾耳角（对应 .tabbar-scroll padding: 0 8px）
                        padding: const EdgeInsets.symmetric(
                          horizontal: TabBarStyle.radius,
                        ),
                        child: _TabsArea(
                          controller: c,
                          style: style,
                          tabWidth: layout.tabWidth,
                          visibleStart: layout.visibleStart,
                          visibleCount: layout.visibleCount,
                          onEnsureVisible: _ensureVisibleWindow,
                        ),
                      ),
                    ),
                    _NewTabButton(
                      style: style,
                      onTap: () => c.add(const TabData(title: '新标签页')),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// 标签画布 + 指针/键盘交互（独立 State，保证 hover 即时响应）
// ============================================================

/// 悬停状态、150ms 动效与命中检测全部收敛在这个小部件内：
/// 动效期间只有这一块 setState + RepaintBoundary 内重绘，
/// 不牵动外层 LayoutBuilder / 滚动结构，避免整条 tab 栏逐帧重建。
class _TabsArea extends StatefulWidget {
  const _TabsArea({
    required this.controller,
    required this.style,
    required this.tabWidth,
    required this.visibleStart,
    required this.visibleCount,
    this.onEnsureVisible,
  });

  final TabBarController controller;
  final TabBarStyle style;
  final double tabWidth;

  /// 可见窗口起始索引（溢出时 > 0）
  final int visibleStart;

  /// 可见窗口内标签数（= controller.count 时无溢出）
  final int visibleCount;

  /// 键盘焦点移出窗口时通知父级平移窗口
  final ValueChanged<int>? onEnsureVisible;

  @override
  State<_TabsArea> createState() => _TabsAreaState();
}

class _TabsAreaState extends State<_TabsArea> with TickerProviderStateMixin {
  // ---- 交互状态 ----
  int? _hoverIndex; // 悬停 tab
  int? _hoverCloseIndex; // 悬停关闭按钮
  int _focusIndex = 0; // 键盘焦点 tab（roving）
  bool _stripFocused = false; // 焦点环仅在有焦点时显示（对应 :focus-visible）

  // ---- 动效渐变量（悬停底色 / 关闭钮透明度）----
  final Map<int, double> _hoverAmt = {};
  final Map<int, double> _closeAmt = {};
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final FocusNode _focusNode = FocusNode();

  /// TextPainter 缓存（标题 / favicon 字符）：文本 layout 昂贵，
  /// 缓存后动效帧只做绘制，不再逐帧排版。
  final Map<String, TextPainter> _textCache = {};

  /// 指数趋近时间常数（秒）：一帧 ~16ms 即达 ~38%，约 150ms 收敛 99%。
  /// 对应 CSS transition ease 的快起步段，避免线性推进前几帧不可见。
  static const double _tau = 0.033;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_TabsArea old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    for (final tp in _textCache.values) {
      tp.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    final f = _focusNode.hasFocus;
    if (f != _stripFocused) setState(() => _stripFocused = f);
  }

  void _onControllerChanged() {
    // 标签集 / 激活态变化：收敛悬停 / 焦点索引并重建本组件
    //（画布重绘由 painter 的 repaint 监听保证）
    setState(() {
      final n = widget.controller.count;
      if (_hoverIndex != null && _hoverIndex! >= n) _hoverIndex = null;
      if (_hoverCloseIndex != null && _hoverCloseIndex! >= n) {
        _hoverCloseIndex = null;
      }
      if (n > 0) _focusIndex = _focusIndex.clamp(0, n - 1);
    });
    _startAnim();
  }

  // ---- 动效驱动：指数 ease-out，~150ms 收敛 ----
  void _startAnim() {
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;
    final decay = math.exp(-dt / _tau);
    final c = widget.controller;
    var settled = true;

    _hoverAmt.removeWhere((k, _) => k >= c.count);
    _closeAmt.removeWhere((k, _) => k >= c.count);

    final activeIdx = c.active() == null ? -1 : c.indexOf(c.active()!);
    for (var i = 0; i < c.count; i++) {
      settled &= _approach(_hoverAmt, i, i == _hoverIndex ? 1.0 : 0.0, decay);
      settled &= _approach(
          _closeAmt, i, (i == activeIdx || i == _hoverIndex) ? 1.0 : 0.0, decay);
    }
    if (settled) _ticker.stop();
    setState(() {});
  }

  bool _approach(Map<int, double> m, int i, double target, double decay) {
    var next = target + ((m[i] ?? 0.0) - target) * decay;
    if ((target - next).abs() < 0.002) next = target;
    m[i] = next;
    return next == target;
  }

  // ---- 命中检测（内容坐标系：x 已减去左右 8px 耳角留白）----
  // 返回绝对索引（含 visibleStart 偏移），窗口外返回 null
  int? _tabAt(Offset p) {
    if (p.dy < 0 || p.dy > TabBarStyle.tabHeight) return null;
    final i = widget.visibleStart + (p.dx / widget.tabWidth).floor();
    return (i >= widget.visibleStart &&
            i < widget.visibleStart + widget.visibleCount)
        ? i
        : null;
  }

  /// [p] 是窗口内坐标（首个可见 tab 为 0），关闭钮命中按"窗口相对索引"计算；
  /// 不可直接用绝对索引 i（含 visibleStart 偏移），否则溢出时命中区整体右移
  bool _inClose(Offset p, int i) {
    final rel = i - widget.visibleStart;
    final x0 = rel * widget.tabWidth + widget.tabWidth - 8 - TabBarStyle.closeSize;
    final top = (TabBarStyle.tabHeight - TabBarStyle.closeSize) / 2; // 垂直居中
    return p.dx >= x0 &&
        p.dx <= x0 + TabBarStyle.closeSize &&
        p.dy >= top &&
        p.dy <= top + TabBarStyle.closeSize;
  }

  void _updateHover(Offset local) {
    final i = _tabAt(local);
    final closeIdx = (i != null && _inClose(local, i)) ? i : null;
    if (i != _hoverIndex || closeIdx != _hoverCloseIndex) {
      setState(() {
        _hoverIndex = i;
        _hoverCloseIndex = closeIdx;
      });
      _startAnim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tabW = widget.tabWidth;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: _hoverCloseIndex != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onExit: (_) => _updateHover(const Offset(-1, -1)),
        // localPosition 已是内容坐标（本组件在 Padding(8) 之内），
        // 不可再减耳角留白，否则命中区整体右移 8px
        onHover: (e) => _updateHover(e.localPosition),
        child: Listener(
          // 中键关闭（对应 auxclick button === 1）
          onPointerDown: (e) {
            if (e.buttons & kMiddleMouseButton != 0) {
              final i = _tabAt(e.localPosition);
              if (i != null) c.close(c.tabs[i].id!);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final p = d.localPosition;
              final i = _tabAt(p);
              if (i == null) return;
              if (_inClose(p, i)) {
                c.close(c.tabs[i].id!);
              } else {
                setState(() => _focusIndex = i);
                c.activate(c.tabs[i].id!);
                // 鼠标交互后收起焦点环（对应 :focus-visible 只在键盘导航时显示）；
                // 需要键盘导航时按 Tab 重新聚焦
                _focusNode.unfocus();
              }
            },
            child: RepaintBoundary(
              child: SizedBox(
                width: tabW * math.max(widget.visibleCount, 1),
                height: TabBarStyle.tabHeight,
                child: CustomPaint(
                  painter: _TabStripPainter(
                    controller: c,
                    style: widget.style,
                    tabWidth: tabW,
                    visibleStart: widget.visibleStart,
                    visibleCount: widget.visibleCount,
                    hoverIndex: _hoverIndex,
                    hoverCloseIndex: _hoverCloseIndex,
                    focusIndex: _stripFocused ? _focusIndex : -1,
                    // 传快照副本：动效地图由 Ticker 原地修改，若新旧 painter
                    // 共享同一实例，shouldRepaint 的逐值比较会退化为自比较
                    // （恒等），导致渐变帧永不重绘、hover 卡在旧值。
                    hoverAmt: Map.of(_hoverAmt),
                    closeAmt: Map.of(_closeAmt),
                    textCache: _textCache,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 键盘：roving focus + ←/→ 环绕移动 + Enter/Space 激活 ----
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final c = widget.controller;
    if (c.count == 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final dir = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      final next = (_focusIndex + dir + c.count) % c.count;
      setState(() => _focusIndex = next);
      // 焦点移入溢出隐藏区 → 平移可见窗口，焦点环保持可见
      widget.onEnsureVisible?.call(next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      c.activate(c.tabs[_focusIndex].id!);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      // Esc 收起焦点环（保持激活态不变）
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

// ============================================================
// 新建按钮（.tabbar-new：28×28 圆角正方形，左距 12，底距 3）
// ============================================================

class _NewTabButton extends StatefulWidget {
  const _NewTabButton({required this.style, required this.onTap});

  /// 在标签条内占据的水平空间（左距 12 + 宽 28），供宽度配账使用
  static const double footprint = 40;

  final TabBarStyle style;
  final VoidCallback onTap;

  @override
  State<_NewTabButton> createState() => _NewTabButtonState();
}

class _NewTabButtonState extends State<_NewTabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          // 对应 CSS .tabbar-new { margin: 0 0 3px 12px }
          padding: const EdgeInsets.only(left: 12, bottom: 3),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(
              painter: _NewTabPainter(style: widget.style, hovered: _hover),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewTabPainter extends CustomPainter {
  const _NewTabPainter({required this.style, required this.hovered});

  final TabBarStyle style;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    if (hovered) {
      // 圆角正方形悬停底（radius 6）
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ),
        Paint()..color = style.btnHover,
      );
    }
    // + 图标：12×12 十字，线宽 1.4，圆头
    final p = Paint()
      ..color = hovered ? style.fg : style.fgMuted
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c + const Offset(0, -6), c + const Offset(0, 6), p);
    canvas.drawLine(c + const Offset(-6, 0), c + const Offset(6, 0), p);
  }

  @override
  bool shouldRepaint(_NewTabPainter old) =>
      old.hovered != hovered || old.style != style;
}

// ============================================================
// 溢出下拉按钮 + 剩余标签菜单
// ============================================================

/// 矩形下拉按钮：点击弹出 OverlayPortal 菜单列出被窗口裁掉的标签，可激活 / 关闭。
class _OverflowButton extends StatefulWidget {
  const _OverflowButton({
    super.key,
    required this.controller,
    required this.style,
    required this.hiddenTabs,
  });

  final TabBarController controller;
  final TabBarStyle style;
  final List<TabData> hiddenTabs;

  /// 溢出按钮在标签条内占据的水平空间（左距 8 + 宽 28）
  static const double footprint = 36;

  @override
  State<_OverflowButton> createState() => _OverflowButtonState();
}

class _OverflowButtonState extends State<_OverflowButton> {
  final OverlayPortalController _menuController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  /// 按钮 + 菜单同组：点按钮不触发菜单的 onTapOutside（避免"关闭又立即重开"）
  final Object _tapGroup = Object();

  bool _hover = false;
  bool _open = false;

  void _toggle() {
    if (_menuController.isShowing) {
      _menuController.hide();
    } else {
      _menuController.show();
    }
    setState(() => _open = _menuController.isShowing);
  }

  void _closeMenu() {
    if (_menuController.isShowing) _menuController.hide();
    if (_open) setState(() => _open = false);
  }

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      width: 264,
      child: CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4), // 菜单悬在按钮下方 4px
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _closeMenu(),
          child: _OverflowMenu(
            style: widget.style,
            tabs: widget.hiddenTabs,
            onActivate: (id) {
              // 激活后父级布局会把窗口平移过去，菜单内容随 rebuild 更新；
              // 保持菜单打开便于连续切换
              widget.controller.activate(id);
            },
            onClose: (id) => widget.controller.close(id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 与新建按钮同底边基线：left 8 + 28 宽（圆角正方形，同 + 按钮）
      padding: const EdgeInsets.only(left: 8, bottom: 3),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _menuController,
          overlayChildBuilder: _buildOverlay,
          child: TapRegion(
            groupId: _tapGroup,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: _toggle,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Semantics(
                    label: '剩余标签页',
                    button: true,
                    child: CustomPaint(
                      painter: _OverflowChevronPainter(
                        style: widget.style,
                        hovered: _hover || _open,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 按钮图标：悬停 / 打开时圆角矩形底 + 下箭头（chevron）
class _OverflowChevronPainter extends CustomPainter {
  const _OverflowChevronPainter({required this.style, required this.hovered});

  final TabBarStyle style;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    if (hovered) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ),
        Paint()..color = style.btnHover,
      );
    }
    final p = Paint()
      ..color = hovered ? style.fg : style.fgMuted
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // chevron-down：宽 9，深 4.5
    canvas.drawLine(c + const Offset(-4.5, -2), c + const Offset(0, 2.5), p);
    canvas.drawLine(c + const Offset(4.5, -2), c + const Offset(0, 2.5), p);
  }

  @override
  bool shouldRepaint(_OverflowChevronPainter old) =>
      old.hovered != hovered || old.style != style;
}

/// 下拉菜单本体：Material 卡片（pageBg + line 描边 + 圆角 8 + 阴影）
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.style,
    required this.tabs,
    required this.onActivate,
    required this.onClose,
  });

  final TabBarStyle style;
  final List<TabData> tabs;
  final ValueChanged<String> onActivate;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.canvas,
      color: style.pageBg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: style.line),
      ),
      child: tabs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                '没有更多标签',
                style: TextStyle(fontSize: 12, color: style.fgMuted),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                // padding 放滚动视图内部作用于条目：滚动条贴卡片边缘，
                // 条目悬停高亮仍与描边留 6px
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final t in tabs)
                        _OverflowMenuItem(
                          key: ValueKey(t.id),
                          tab: t,
                          style: style,
                          onActivate: () => onActivate(t.id!),
                          onClose: () => onClose(t.id!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// 菜单项：favicon + 标题 + 关闭按钮（32 高，悬停整行高亮）
class _OverflowMenuItem extends StatefulWidget {
  const _OverflowMenuItem({
    super.key,
    required this.tab,
    required this.style,
    required this.onActivate,
    required this.onClose,
  });

  final TabData tab;
  final TabBarStyle style;
  final VoidCallback onActivate;
  final VoidCallback onClose;

  @override
  State<_OverflowMenuItem> createState() => _OverflowMenuItemState();
}

class _OverflowMenuItemState extends State<_OverflowMenuItem> {
  bool _hover = false;
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final tab = widget.tab;
    final favColor = tab.color ?? kDefaultPalette[0];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        child: Container(
          height: 32,
          // 悬停高亮：圆角 6。用 btnHover 而非 hoverOverlay——
          // 菜单底是 pageBg（浅色 = 白），hoverOverlay 是半透明白叠上去不可见；
          // btnHover（浅色 9% 深灰 / 深色 14% 浅灰）在页面色表面上两主题均可见
          decoration: BoxDecoration(
            color: _hover ? s.btnHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // favicon：16×16 圆角 8 + 首字符（与标签条一致）
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: favColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab.title.characters.first,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    color: _isLightColor(favColor)
                        ? const Color(0xFF1A1A1F)
                        : const Color(0xFFFFFFFF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: s.fg),
                ),
              ),
              const SizedBox(width: 4),
              // 关闭按钮：20×20 命中区，图标 12；悬停圆角方形底 + 图标加深。
              // 底色用 line（浅色 16% 深灰）：行 hover 已是 btnHover(9%)，
              // 同色叠同色不可见；line 叠上去才有效果，两主题均成立
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _closeHover = true),
                onExit: (_) => setState(() => _closeHover = false),
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _closeHover ? s.line : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: _closeHover ? s.fg : s.fgMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 标签条绘制（耳角核心）
// ============================================================

class _TabStripPainter extends CustomPainter {
  /// repaint: controller —— 激活/增删/更新时 controller notifyListeners，
  /// 直接 markNeedsPaint 立即重绘画布（激活态不在 shouldRepaint 比较项内，
  /// 靠本监听保证切换立即生效，不依赖动效副作用）。
  _TabStripPainter({
    required this.controller,
    required this.style,
    required this.tabWidth,
    required this.visibleStart,
    required this.visibleCount,
    required this.hoverIndex,
    required this.hoverCloseIndex,
    required this.focusIndex,
    required this.hoverAmt,
    required this.closeAmt,
    required this.textCache,
  }) : super(repaint: controller);

  final TabBarController controller;
  final TabBarStyle style;
  final double tabWidth;
  final int visibleStart;
  final int visibleCount;
  final int? hoverIndex;
  final int? hoverCloseIndex;
  final int focusIndex;
  final Map<int, double> hoverAmt;
  final Map<int, double> closeAmt;

  /// TextPainter 缓存（来自 _TabsAreaState，跨帧复用）
  final Map<String, TextPainter> textCache;

  static const double _r = TabBarStyle.radius;
  static const double _h = TabBarStyle.tabHeight;

  /// 激活 tab 完整形状：本体（顶部两角圆角 r）+ 两侧外扩凹弧翼。
  /// 翼 = tab 侧边缘外侧 8×8 方块减去「以外上角为圆心的四分之一圆」，
  /// 四分之一圆区域不涂色 → 透出邻 tab / 标签条真实背景（含悬停色，天然联动）。
  /// 绘制顺序上激活形状在非激活悬停层之后，等价 CSS z-index:1。
  static Path activePath(double w) {
    final p = Path();
    p.moveTo(_r, 0);
    p.lineTo(w - _r, 0);
    p.arcToPoint(Offset(w, _r), radius: const Radius.circular(_r));
    p.lineTo(w, _h - _r);
    // 右耳角：圆心在方块外上角 (w+r, h-r)，弧从 (w, h-r) 凹向外侧到 (w+r, h)
    p.arcToPoint(
      Offset(w + _r, _h),
      radius: const Radius.circular(_r),
      clockwise: false,
    );
    p.lineTo(-_r, _h);
    // 左耳角：圆心在方块外上角 (-r, h-r)，弧从 (-r, h) 到 (0, h-r)
    p.arcToPoint(
      Offset(0, _h - _r),
      radius: const Radius.circular(_r),
      clockwise: false,
    );
    p.lineTo(0, _r);
    p.arcToPoint(const Offset(_r, 0), radius: const Radius.circular(_r));
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tabs = controller.tabs;
    final end = math.min(visibleStart + visibleCount, tabs.length);
    for (var i = visibleStart; i < end; i++) {
      canvas.save();
      canvas.translate((i - visibleStart) * tabWidth, 0);
      _paintTab(canvas, i, tabs[i]);
      canvas.restore();
    }
  }

  void _paintTab(Canvas canvas, int index, TabData tab) {
    final activeId = controller.active();
    final isActive = tab.id == activeId;
    final w = tabWidth;

    if (!isActive) {
      // ---- 1) 悬停底色：圆角 8，透明度随 150ms 渐变 ----
      final amt = hoverAmt[index] ?? 0.0;
      if (amt > 0.001) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & Size(w, _h),
            const Radius.circular(_r),
          ),
          Paint()..color = style.hoverOverlay.withValues(alpha: style.hoverOverlay.a * amt),
        );
      }
      // ---- 2) 分隔线：仅左邻可见且非激活时，画在左边缘（1×18，top 8）----
      if (index > visibleStart && controller.tabs[index - 1].id != activeId) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 8, 1, 18),
          Paint()..color = style.line,
        );
      }
    } else {
      // ---- 3) 激活：本体 + 耳角翼（后画覆盖邻层，翼外透明区透出邻 tab 背景）----
      canvas.drawPath(activePath(w), Paint()..color = style.pageBg);
    }

    // ---- 4) 键盘焦点环（四周内缩 2px，线宽 1.2，仅 :focus-visible）----
    // 底边必须抬离 tab 底缘：集成方工具栏会上叠标签条底缘 ~1px 消 DPI 拼缝
    // （见 README 集成提示），贴底绘制会被遮住一截，导致底边看起来比顶边细
    if (index == focusIndex) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, w - 4, _h - 4),
          const Radius.circular(_r - 2),
        ),
        Paint()
          ..color = style.focus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // ---- 5) favicon：16×16 圆角 8 + 首字符（亮度自动对比色）----
    final favRect = const Rect.fromLTWH(8, 9, 16, 16);
    final favColor = tab.color ?? kDefaultPalette[index % kDefaultPalette.length];
    canvas.drawRRect(
      RRect.fromRectAndRadius(favRect, const Radius.circular(_r)),
      Paint()..color = favColor,
    );
    _paintLetter(canvas, favRect, tab.title, favColor);

    // ---- 6) 标题：12px 单行省略；激活 = 主色 w500，其余 = 次级灰 w400 ----
    final labelW = w - 56; // 8 + 16(fav) + 8 + 16(close) + 8
    if (labelW > 12) {
      final tp = _titleOf(tab, isActive, labelW);
      tp.paint(canvas, Offset(32, (_h - tp.height) / 2));
    }

    // ---- 7) 关闭按钮：16×16；激活常显 / 悬停 150ms 渐显 ----
    final vis = isActive ? 1.0 : (closeAmt[index] ?? 0.0);
    if (vis > 0.01) {
      final c = Offset(w - 8 - TabBarStyle.closeSize / 2, _h / 2);
      if (hoverCloseIndex == index) {
        // 悬停底色：16×16 圆角矩形（radius 4，对应 CSS border-radius: 4px）
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c,
              width: TabBarStyle.closeSize,
              height: TabBarStyle.closeSize,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = style.btnHover,
        );
      }
      final base = hoverCloseIndex == index ? style.fg : style.fgMuted;
      final p = Paint()
        ..color = base.withValues(alpha: base.a * vis)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      // × 图标 9px（对应 CLOSE_SVG width/height=9，viewBox 10 等比缩放）
      final h = 4.5; // 半径
      canvas.drawLine(c + Offset(-h, -h), c + Offset(h, h), p);
      canvas.drawLine(c + Offset(h, -h), c + Offset(-h, h), p);
    }
  }

  /// 标题 TextPainter（缓存）：文本 layout 昂贵，动效帧直接复用
  TextPainter _titleOf(TabData tab, bool isActive, double maxW) {
    // 键必须包含主题色：TextPainter 的 TextSpan 固化了颜色，
    // 深浅主题切换若复用旧实例，会出现"浅色模式下浅灰文字画在白色激活 tab 上"
    final key =
        'title|$isActive|${style.fg}|${style.fgMuted}|${tab.title}|${maxW.round()}';
    return textCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: tab.title,
          style: TextStyle(
            fontSize: 12,
            height: 18 / 12,
            color: isActive ? style.fg : style.fgMuted,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW);
    });
  }

  /// favicon 字符 TextPainter（缓存）
  TextPainter _letterOf(String ch, Color color) {
    final key = 'letter|$ch|$color';
    return textCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            fontSize: 12,
            height: 1.0,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void _paintLetter(Canvas canvas, Rect rect, String title, Color bg) {
    final color = _isLightColor(bg)
        ? const Color(0xFF1A1A1F)
        : const Color(0xFFFFFFFF);
    final tp = _letterOf(title.characters.first, color);
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TabStripPainter old) =>
      old.controller != controller ||
      old.style != style ||
      old.tabWidth != tabWidth ||
      old.visibleStart != visibleStart ||
      old.visibleCount != visibleCount ||
      old.hoverIndex != hoverIndex ||
      old.hoverCloseIndex != hoverCloseIndex ||
      old.focusIndex != focusIndex ||
      !_mapEq(old.hoverAmt, hoverAmt) ||
      !_mapEq(old.closeAmt, closeAmt);

  static bool _mapEq(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
