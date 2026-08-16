// ChromeTabBar 组件测试：控制器逻辑 + 组件渲染冒烟测试
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:browser_tab_bar/browser_tab_bar.dart';

void main() {
  group('TabBarController 逻辑（对应 tab.js 行为）', () {
    test('初始化：自动分配 id、固化 favicon 色、首个自动激活', () {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      );
      expect(c.count, 2);
      expect(c.tabs[0].id, 'tab-1');
      expect(c.tabs[1].id, 'tab-2');
      expect(c.active(), 'tab-1');
      expect(c.tabs[0].color, isNotNull); // 默认色板固化
    });

    test('add：默认激活新标签', () {
      final c = TabBarController();
      final id = c.add(const TabData(title: 'X'));
      expect(c.active(), id);
      expect(c.get(id)!.title, 'X');
    });

    test('close 激活 tab → 接右邻；关闭最后一个 → 自动补"新标签页"', () {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B'), TabData(title: 'C')],
      );
      // 关闭激活的 A（index 0）→ 激活右邻 B
      c.close('tab-1');
      expect(c.active(), 'tab-2');
      // 关闭 C（非激活）→ 激活不变
      c.close('tab-3');
      expect(c.active(), 'tab-2');
      // 关闭最后一个 B → 自动补位
      c.close('tab-2');
      expect(c.count, 1);
      expect(c.tabs.first.title, '新标签页');
      expect(c.active(), isNotNull);
    });

    test('close 尾部激活 tab → 接左邻', () {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      );
      c.activate('tab-2');
      c.close('tab-2');
      expect(c.active(), 'tab-1');
    });

    test('update：修改标题与地址', () {
      final c = TabBarController(initialTabs: const [TabData(title: 'A')]);
      c.update('tab-1', title: 'A2', url: 'a.com');
      expect(c.get('tab-1')!.title, 'A2');
      expect(c.get('tab-1')!.url, 'a.com');
    });

    test('onChange 事件流：activate / close / add', () {
      final events = <TabChangeType>[];
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A')],
      )..onChange = (e) => events.add(e.type);

      c.add(const TabData(title: 'B')); // activate + add
      c.close(c.active()!); // 关闭 B → activate(A) + close
      expect(events, [
        TabChangeType.activate,
        TabChangeType.add,
        TabChangeType.activate,
        TabChangeType.close,
      ]);
    });
  });

  group('ChromeTabBar 组件渲染', () {
    testWidgets('渲染不抛异常，且布局高度为 38', (tester) async {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'MDN Web Docs'), TabData(title: 'GitHub')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChromeTabBar(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ChromeTabBar)).height,
        TabBarStyle.stripTopPad + TabBarStyle.tabHeight,
      );
    });

    testWidgets('点击第二个标签后激活', (tester) async {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: ChromeTabBar(controller: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 视口 600 - 16 留白 = 584；584/2 = 292 → clamp 到 240。
      // 点击 x = 8(留白) + 240 + 100 即第二个标签
      await tester.tapAt(const Offset(8 + 240 + 100, 4 + 17));
      await tester.pumpAndSettle();

      expect(c.active(), 'tab-2');
    });

    testWidgets('点击关闭按钮（命中区与绘制对齐）关闭对应标签', (tester) async {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: ChromeTabBar(controller: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // tab 宽 240；第二个 tab 关闭按钮（16×16）中心：
      // 内容 x = 8(留白) + 240 + 240 - 16 = 464，y = 4(条顶留白) + 17
      await tester.tapAt(const Offset(8 + 240 + 240 - 16, 4 + 17));
      await tester.pumpAndSettle();

      // 关闭的是 tab-2（激活 tab → 自动激活右邻，无则左邻 tab-1）
      expect(c.count, 1);
      expect(c.tabs.first.title, 'A');
    });

    testWidgets('主题切换后标题颜色随主题更新（文本缓存键含主题）', (tester) async {
      final key = GlobalKey();
      var dark = false;
      late StateSetter setOuter;
      final c = TabBarController(initialTabs: const [TabData(title: 'AA')]);

      // toImage/toByteData 依赖真实异步（引擎侧 completer），
      // 必须包在 tester.runAsync 里：fake-async 测试区中 await 永不完成 → 挂死
      Future<double> titleLum(bool darkest) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        var bytes = Uint8List(0);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          bytes = (await image.toByteData())!.buffer.asUint8List();
        });
        var best = darkest ? 1.0 : 0.0;
        // 标题区：x∈[34,46]，y∈[8,32]（测试字体为实心方块，命中字形即取到文字色）
        for (var y = 8; y <= 32; y++) {
          for (var x = 34; x <= 46; x++) {
            final o = (y * boundary.size.width.toInt() + x) * 4;
            final r = bytes[o];
            final g = bytes[o + 1];
            final b = bytes[o + 2];
            final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
            best = darkest ? math.min(best, lum) : math.max(best, lum);
          }
        }
        return best;
      }

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            setOuter = setState;
            return MaterialApp(
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child:
                      SizedBox(width: 300, child: ChromeTabBar(controller: c)),
                ),
              ),
            );
          },
        ),
      );

      void toggle() => setOuter(() => dark = !dark);

      // 浅色：激活 tab 白底，标题必须存在深色像素（#202124）
      await tester.pumpAndSettle();
      expect(await titleLum(true), lessThan(0.5));

      // 切深色再回浅色各一次，确保跨主题复用缓存的路径被覆盖
      toggle();
      await tester.pumpAndSettle();
      // 深色：激活 tab 深底，标题必须存在亮色像素（#E8EAED）
      expect(await titleLum(false), greaterThan(0.7));

      toggle();
      await tester.pumpAndSettle();
      expect(await titleLum(true), lessThan(0.5));
    });
  });

  group('溢出下拉（标签放不下时左侧按钮展开剩余标签）', () {
    // 宽 300：内容宽 = 300-4(右留白)-40(+) = 256；溢出时再减下拉按钮 36 → 220，
    // 可见容量 220~/72 = 3；8 个标签 → 溢出，隐藏 5 个
    Widget wrap(TabBarController c) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: ChromeTabBar(controller: c)),
          ),
        );

    testWidgets('溢出时出现下拉按钮；标签减少到放得下时按钮消失', (tester) async {
      final c = TabBarController(
        initialTabs: [for (var i = 0; i < 8; i++) TabData(title: '标签 $i')],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 8×72=576 > 256(无按钮内容宽) → 溢出
      expect(find.byKey(ChromeTabBar.overflowButtonKey), findsOneWidget);

      // 关到 3 个：3×72=216 ≤ 256 → 放得下，按钮消失
      c.close('tab-8');
      await tester.pumpAndSettle();
      c.close('tab-7');
      await tester.pumpAndSettle();
      c.close('tab-6');
      await tester.pumpAndSettle();
      c.close('tab-5');
      await tester.pumpAndSettle();
      expect(c.count, 4); // 4×72=288 > 256 仍溢出 → 按钮保留
      expect(find.byKey(ChromeTabBar.overflowButtonKey), findsOneWidget);

      c.close('tab-4');
      await tester.pumpAndSettle();
      expect(c.count, 3);
      expect(find.byKey(ChromeTabBar.overflowButtonKey), findsNothing);
    });

    testWidgets('点开菜单显示剩余标签；激活隐藏 tab 后窗口跳转、菜单同步', (tester) async {
      final c = TabBarController(
        initialTabs: [for (var i = 0; i < 8; i++) TabData(title: '标签 $i')],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 初始窗口 [0,3)，隐藏 3..7；激活 tab-1（index 0）
      await tester.tap(find.byKey(ChromeTabBar.overflowButtonKey));
      await tester.pumpAndSettle();

      // 标签条本体是 CustomPaint 绘制文本，find.text 只会命中菜单项
      expect(find.text('标签 3'), findsOneWidget);
      expect(find.text('标签 7'), findsOneWidget);
      expect(find.text('标签 0'), findsNothing); // 可见窗口内的不在菜单里

      // 激活隐藏的"标签 5"（tab-6）
      await tester.tap(find.text('标签 5'));
      await tester.pumpAndSettle();

      expect(c.active(), 'tab-6');
      // 窗口跳转到包含 index 5：[3,6) → 菜单里应出现标签 0/1/2，不再有标签 5
      expect(find.text('标签 5'), findsNothing);
      expect(find.text('标签 0'), findsOneWidget);
      expect(find.text('标签 7'), findsOneWidget); // 6、7 仍在隐藏区

      // 点外部关闭菜单
      await tester.tapAt(const Offset(290, 200));
      await tester.pumpAndSettle();
      expect(find.text('标签 7'), findsNothing);
    });

    testWidgets('菜单内关闭隐藏标签', (tester) async {
      final c = TabBarController(
        initialTabs: [for (var i = 0; i < 8; i++) TabData(title: '标签 $i')],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChromeTabBar.overflowButtonKey));
      await tester.pumpAndSettle();

      // 菜单第一项是"标签 3"（隐藏区首个），点它的关闭图标
      expect(find.text('标签 3'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(c.count, 7);
      expect(c.get('tab-4'), isNull); // 标签 3 = tab-4 已被关闭
      expect(find.text('标签 3'), findsNothing);
      expect(find.text('标签 4'), findsOneWidget); // 菜单仍开着并已同步
    });
  });
}
