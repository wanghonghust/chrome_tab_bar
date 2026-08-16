/*! browser_tab_bar 演示 app — 与 ../../index.html（web 版）一比一复刻
 * 浏览器卡片 = 标签条(browser_tab_bar) + 工具栏(omnibox，自定义) + 内容区(当前标签页，自定义)
 * 演示重点：内容与工具栏全部由使用方渲染，库只提供标签条。
 */
import 'package:flutter/material.dart';

import 'package:browser_tab_bar/browser_tab_bar.dart';

void main() {
  runApp(const TabDemoApp());
}

class TabDemoApp extends StatelessWidget {
  const TabDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPage();
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final TabBarController _controller;
  ThemeMode _mode = ThemeMode.system; // 初始跟随系统
  int _apiSeq = 0;

  // 工具栏 / 内容区联动数据（对应 index.html 的 #url / #pageTitle / #pageUrl）
  String _url = 'developer.mozilla.org/zh-CN/docs/Web/CSS';
  String _title = 'MDN Web Docs';

  @override
  void initState() {
    super.initState();
    _controller = TabBarController(
      // 与 index.html 初始 4 个标签一致（含颜色）
      initialTabs: const [
        TabData(
          title: 'MDN Web Docs',
          url: 'developer.mozilla.org/zh-CN/docs/Web/CSS',
          color: Color(0xFF3C2ECA),
        ),
        TabData(
          title: 'GitHub · trae/tab-component',
          url: 'github.com/trae/tab-component',
          color: Color(0xFF22A5F7),
        ),
        TabData(
          title: '掘金 · 优质技术开发社区',
          url: 'juejin.cn',
          color: Color(0xFF6F6FFF),
        ),
        TabData(
          title: '腾讯文档 · 在线协作',
          url: 'docs.qq.com',
          color: Color(0xFFA9AEFF),
        ),
      ],
      onChange: _onTabChange,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabChange(TabBarChangeEvent e) {
    if (e.type == TabChangeType.activate) {
      setState(() {
        _url = e.data?.url ?? '新标签页';
        _title = e.data?.title ?? '新标签页';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // DemoPage 直接持有 MaterialApp：_mode 初始 system = 跟随系统
    // （对应 index.html 的 matchMedia + localStorage 主题切换）
    return MaterialApp(
      title: '浏览器 Tab 组件 · TabBar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F3F4),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101012),
        useMaterial3: true,
      ),
      themeMode: _mode,
      home: Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final isDark = brightness == Brightness.dark;
          // 演示页配色（对应 index.html 的 style 块）
          final cardBg = isDark ? const Color(0xFF35363A) : Colors.white;
          final pageBg = isDark
              ? const Color(0xFF101012)
              : const Color(0xFFF1F3F4);
          final fg = isDark ? const Color(0xFFE8EAED) : const Color(0xFF202124);
          final fgMuted = isDark
              ? const Color(0xFF9AA0A6)
              : const Color(0xFF5F6368);
          final line = isDark
              ? const Color(0x29E8EAED)
              : const Color(0x29202124);

          return Scaffold(
            backgroundColor: pageBg,
            body: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 880,
                  clipBehavior: Clip.hardEdge,
                  constraints: const BoxConstraints(maxWidth: 880),
                  margin: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.4)
                            : const Color(0x1F202124), // rgba(32,33,36,.12)
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- 标签条（组件本体）----
                      BrowserTabBar(controller: _controller),

                      // ---- 工具栏：与激活 tab 同色连通 ----
                      // 上移 1px 压住标签条底边：工具栏不透明且画序在后，
                      // 可完整覆盖拼缝像素，消除分数 DPI（125%/150% 缩放）下
                      // 两个同色面拼接处抗锯齿混出的标签条灰色细线
                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border(bottom: BorderSide(color: line)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 26,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF202124)
                                        : const Color(0xFFDEE1E6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 11,
                                        color: fgMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _url,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: fgMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.refresh,
                                        size: 12,
                                        color: fgMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _IconButton(
                                icon: isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                color: fgMuted,
                                hoverColor: isDark
                                    ? const Color(0x24E8EAED)
                                    : const Color(0x17202124),
                                tooltip: '切换明暗主题',
                                onTap: _toggleTheme,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- 内容区 ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '当前标签页',
                              style: TextStyle(fontSize: 12, color: fgMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _url == '新标签页' || _url.isEmpty ? '(空地址)' : _url,
                              style: TextStyle(
                                fontSize: 12,
                                color: fgMuted,
                                fontFamily: 'Consolas',
                                fontFamilyFallback: const ['monospace'],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ApiButton(
                                  label: 'add() 新增标签',
                                  fg: fg,
                                  line: line,
                                  hover: isDark
                                      ? const Color(0x24E8EAED)
                                      : const Color(0x17202124),
                                  onTap: _apiAdd,
                                ),
                                _ApiButton(
                                  label: 'close(active) 关闭当前',
                                  fg: fg,
                                  line: line,
                                  hover: isDark
                                      ? const Color(0x24E8EAED)
                                      : const Color(0x17202124),
                                  onTap: _apiClose,
                                ),
                                _ApiButton(
                                  label: 'update() 修改标题',
                                  fg: fg,
                                  line: line,
                                  hover: isDark
                                      ? const Color(0x24E8EAED)
                                      : const Color(0x17202124),
                                  onTap: _apiRename,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '交互：单击切换 · 中键或 × 关闭 · Tab 聚焦后 ←/→ 移动、Enter 激活 · 标签过多时左侧下拉按钮展开剩余标签',
                              style: TextStyle(fontSize: 12, color: fgMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- API 按钮（对应 index.html 的 api-row）----
  void _apiAdd() {
    _apiSeq += 1;
    _controller.add(
      TabData(title: 'API 标签 $_apiSeq', url: 'example.com/$_apiSeq'),
    );
  }

  void _apiClose() {
    final id = _controller.active();
    if (id != null) _controller.close(id);
  }

  void _apiRename() {
    final id = _controller.active();
    if (id == null) return;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    _controller.update(id, title: '标题已更新 · $hh:$mm:$ss');
  }

  void _toggleTheme() {
    setState(() {
      // 对应 index.html：cur = 显式主题 || 系统偏好 → 取反
      final platformDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
      final effectiveDark = switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => platformDark,
      };
      _mode = effectiveDark ? ThemeMode.light : ThemeMode.dark;
    });
  }
}

/// 圆形图标按钮（对应 .icon-btn）
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color hoverColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hover ? widget.hoverColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 14, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// API 演示按钮（对应 .api-row button：描边圆角 8，悬停微亮）
class _ApiButton extends StatefulWidget {
  const _ApiButton({
    required this.label,
    required this.fg,
    required this.line,
    required this.hover,
    required this.onTap,
  });

  final String label;
  final Color fg;
  final Color line;
  final Color hover;
  final VoidCallback onTap;

  @override
  State<_ApiButton> createState() => _ApiButtonState();
}

class _ApiButtonState extends State<_ApiButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: widget.line),
            borderRadius: BorderRadius.circular(8),
            color: _hover ? widget.hover : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.fg,
            ),
          ),
        ),
      ),
    );
  }
}
