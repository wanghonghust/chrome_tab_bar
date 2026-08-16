// BrowserTabBar 组件测试：控制器逻辑 + 组件渲染冒烟测试
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
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

  group('BrowserTabBar 组件渲染', () {
    testWidgets('渲染不抛异常，且布局高度为 38', (tester) async {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'MDN Web Docs'), TabData(title: 'GitHub')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrowserTabBar(controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BrowserTabBar)).height,
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
              child: BrowserTabBar(controller: c),
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
              child: BrowserTabBar(controller: c),
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
                      SizedBox(width: 300, child: BrowserTabBar(controller: c)),
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

    testWidgets('activeBorder：tab 本体描边保留；底部两侧延伸整条且激活处断开', (tester) async {
      // 视口 300、2 标签激活第二个：tabW = 256/2 = 128，激活 tab x∈[136,264]，
      // 线画在所有 tab 之下：耳角翼遮蔽至弧线处 ≈[130.8,269.2] 中段无墨，
      // 线自耳角弧两侧穿出（Chrome 同款层叠）。采样点：
      //  A(185, 4)  激活 tab 顶边空白处 —— tab 本体描边（变暗）
      //  B(2, 37)   条最左端底部 —— 左侧延伸线（变暗）
      //  B2(290,37) 条最右端底部 —— 右侧延伸线（变暗）
      //  C(200,37)  激活 tab 底部 —— 缺口处无线（两版一致）
      // toImage/toByteData 依赖真实异步，须包 tester.runAsync（见主题色测试）。
      Future<int> px(TabBarStyle? style, int x, int y) async {
        final key = GlobalKey();
        final c = TabBarController(
          initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 300,
                  child: BrowserTabBar(controller: c, style: style),
                ),
              ),
            ),
          ),
        );
        c.activate('tab-2');
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        var bytes = Uint8List(0);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          bytes = (await image.toByteData())!.buffer.asUint8List();
        });
        return bytes[(y * boundary.size.width.toInt() + x) * 4];
      }

      // 关闭描边的浅色主题（其余令牌与 light 一致）
      const noBorder = TabBarStyle(
        stripBg: Color(0xFFDEE1E6),
        pageBg: Color(0xFFFFFFFF),
        fg: Color(0xFF202124),
        fgMuted: Color(0xFF5F6368),
        line: Color(0x29202124),
        hoverOverlay: Color(0x73FFFFFF),
        btnHover: Color(0x17202124),
        focus: Color(0xFF1A73E8),
      );

      expect(TabBarStyle.light.activeBorder, isNotNull); // 默认开启
      // A：激活 tab 本体顶边描边
      final aWith = await px(null, 185, 4); // 缺省 style → 跟随亮色主题
      final aWithout = await px(noBorder, 185, 4);
      expect(aWithout, greaterThan(250)); // 无描边：接近纯白
      expect(aWith, lessThan(aWithout - 10)); // 描边使顶边变暗
      // B / B2：底部左右两侧延伸线（叠 stripBg 亮底变暗）
      final blWith = await px(null, 2, 37);
      final blWithout = await px(noBorder, 2, 37);
      expect(blWithout, greaterThan(215)); // stripBg 亮底（r≈222）
      expect(blWith, lessThan(blWithout - 8));
      final brWith = await px(null, 290, 37);
      final brWithout = await px(noBorder, 290, 37);
      expect(brWith, lessThan(brWithout - 8));
      // C：激活 tab 底部缺口处无线
      final gWith = await px(null, 200, 37);
      final gWithout = await px(noBorder, 200, 37);
      expect(gWith, greaterThan(250)); // 激活 tab 白底
      expect((gWith - gWithout).abs(), lessThan(6));
    });
  });

  group('溢出下拉（标签放不下时左侧按钮展开剩余标签）', () {
    // 宽 300：内容宽 = 300-4(右留白)-40(+) = 256；溢出时再减下拉按钮 36 → 220，
    // 可见容量 220~/72 = 3；8 个标签 → 溢出，隐藏 5 个
    Widget wrap(TabBarController c) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 300, child: BrowserTabBar(controller: c)),
          ),
        );

    testWidgets('溢出时出现下拉按钮；标签减少到放得下时按钮消失', (tester) async {
      final c = TabBarController(
        initialTabs: [for (var i = 0; i < 8; i++) TabData(title: '标签 $i')],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 8×72=576 > 256(无按钮内容宽) → 溢出
      expect(find.byKey(BrowserTabBar.overflowButtonKey), findsOneWidget);

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
      expect(find.byKey(BrowserTabBar.overflowButtonKey), findsOneWidget);

      c.close('tab-4');
      await tester.pumpAndSettle();
      expect(c.count, 3);
      expect(find.byKey(BrowserTabBar.overflowButtonKey), findsNothing);
    });

    testWidgets('点开菜单显示剩余标签；激活隐藏 tab 后窗口跳转、菜单同步', (tester) async {
      final c = TabBarController(
        initialTabs: [for (var i = 0; i < 8; i++) TabData(title: '标签 $i')],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 初始窗口 [0,3)，隐藏 3..7；激活 tab-1（index 0）
      await tester.tap(find.byKey(BrowserTabBar.overflowButtonKey));
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

      await tester.tap(find.byKey(BrowserTabBar.overflowButtonKey));
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

  group('TabBarController 批量关闭（右键菜单同款 API）', () {
    test('closeOthers：保留目标并切激活，事件流干净', () {
      final events = <String>[];
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
        ],
      )..onChange = (e) => events.add('${e.type.name}:${e.id}');

      c.closeOthers('tab-2');
      expect(c.count, 1);
      expect(c.tabs.single.id, 'tab-2');
      expect(c.active(), 'tab-2');
      // 先 activate 到保留项，被关的都不是激活项（不触发 close 的邻位接续）
      expect(events, ['activate:tab-2', 'close:tab-1', 'close:tab-3']);
    });

    test('closeOthers：目标已激活不产生多余 activate；仅剩自身时 no-op', () {
      final events = <TabChangeType>[];
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      )..onChange = (e) => events.add(e.type);

      c.closeOthers('tab-1');
      expect(c.count, 1);
      expect(events, [TabChangeType.close]);

      events.clear();
      c.closeOthers('tab-1');
      expect(c.count, 1);
      expect(events, isEmpty);
    });

    test('closeRight：激活项在被关范围内 → 先切到目标；尾项 no-op', () {
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
          TabData(title: 'D'),
        ],
      );
      c.activate('tab-4');
      c.closeRight('tab-2');
      expect(c.tabs.map((t) => t.id), ['tab-1', 'tab-2']);
      expect(c.active(), 'tab-2');

      c.closeRight('tab-2'); // tab-2 已是最后一项 → 无事发生
      expect(c.count, 2);
    });

    test('closeLeft：激活项在被关范围内 → 先切到目标；首项 no-op', () {
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
        ],
      );
      c.activate('tab-1');
      c.closeLeft('tab-2');
      expect(c.tabs.map((t) => t.id), ['tab-2', 'tab-3']);
      expect(c.active(), 'tab-2');

      c.closeLeft('tab-2'); // tab-2 已是首项 → 无事发生
      expect(c.count, 2);
    });
  });

  group('右键菜单（tab / 空白区域 + 菜单项禁用态）', () {
    Widget wrap(TabBarController c, {double width = 600}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: width, child: BrowserTabBar(controller: c)),
          ),
        );

    Future<void> rightClick(WidgetTester tester, Offset at) async {
      final g = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('右键 tab 弹出菜单；点"关闭右侧标签页"生效并收起', (tester) async {
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
        ],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 宽 600：内容宽 556，3 tab 均分 ~185.3；右键中间 tab（index 1）
      await rightClick(tester, const Offset(8 + 185 + 90, 21));

      expect(find.text('新建标签页'), findsOneWidget);
      expect(find.text('关闭左侧标签页'), findsOneWidget);
      await tester.tap(find.text('关闭右侧标签页'));
      await tester.pumpAndSettle();

      expect(c.tabs.map((t) => t.title), ['A', 'B']);
      expect(find.text('关闭右侧标签页'), findsNothing); // 执行后菜单收起
    });

    testWidgets('右键 tab："关闭其他标签页"生效；剩余单标签时批量项禁用', (tester) async {
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
        ],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      // 右键中间 tab → 关闭其他：仅剩 B 且激活
      await rightClick(tester, const Offset(8 + 185 + 90, 21));
      await tester.tap(find.text('关闭其他标签页'));
      await tester.pumpAndSettle();
      expect(c.tabs.map((t) => t.title), ['B']);
      expect(c.active(), 'tab-2');

      // 单标签重开菜单：关闭左/其他/右侧全禁用（"关闭"仍可用——关掉会补新标签页）
      await rightClick(tester, const Offset(8 + 90, 21));
      await tester.tap(find.text('关闭其他标签页'));
      await tester.pumpAndSettle();
      expect(c.count, 1); // 禁用项点击无效
      expect(find.text('关闭其他标签页'), findsOneWidget); // 菜单保持打开
    });

    testWidgets('右键首项："关闭左侧标签页"禁用（点击无效、菜单保持）', (tester) async {
      final c = TabBarController(
        initialTabs: const [
          TabData(title: 'A'),
          TabData(title: 'B'),
          TabData(title: 'C'),
        ],
      );
      await tester.pumpWidget(wrap(c));
      await tester.pumpAndSettle();

      await rightClick(tester, const Offset(8 + 90, 21)); // 首个 tab
      await tester.tap(find.text('关闭左侧标签页'));
      await tester.pumpAndSettle();

      expect(c.count, 3);
      expect(find.text('关闭左侧标签页'), findsOneWidget);
    });

    testWidgets('空白区域右键：仅"新建标签页"可用；点外部关闭菜单', (tester) async {
      final c = TabBarController(
        initialTabs: const [TabData(title: 'A'), TabData(title: 'B')],
      );
      await tester.pumpWidget(wrap(c, width: 800));
      await tester.pumpAndSettle();

      // 宽 800：2 tab 各 240（clamp 上限），tab 总宽 480；x=700 在标签条空白区
      await rightClick(tester, const Offset(700, 21));
      expect(find.text('新建标签页'), findsOneWidget);

      // 空白右键：无目标 tab，关闭系列全禁用
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(c.count, 2);

      // 新建可用
      await tester.tap(find.text('新建标签页'));
      await tester.pumpAndSettle();
      expect(c.count, 3);

      // 再弹一次，点菜单外部关闭
      await rightClick(tester, const Offset(700, 21));
      expect(find.text('新建标签页'), findsOneWidget);
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(find.text('新建标签页'), findsNothing);
    });
  });
}
