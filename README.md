# browser_tab_bar

**English** | [中文](#中文)

A Chrome-style browser tab bar (pure UI library). **Contains only the tab strip itself — page content is up to you**: drive tab add/close/activate/update through `TabBarController`, and render whatever content you like for the active tab.

## Screenshots

| Light | Dark |
| --- | --- |
| ![Light theme](snapshot/Snipaste_2026-08-16_12-06-50.png) | ![Dark theme](snapshot/Snipaste_2026-08-16_12-06-10.png) |

![Overflow dropdown](snapshot/Snipaste_2026-08-16_12-07-02.png)

## Features

- Chrome look: tab height 34 / strip height 38, top corner radius 8px, flexible equal-width tabs (72–240px)
- Overflow dropdown: when tabs no longer fit, a square dropdown button appears on the left listing the hidden tabs (activate / close from the menu); the active tab always stays in the visible window
- Active tab has 8px concave-flare "ears" on both sides, blending into the toolbar below; the transparent quarters reveal the real background of neighboring tabs
- Active tab outline border: `TabBarStyle.activeBorder` strokes the active tab (top edge, sides, ears, 1px) and draws a separator along the strip bottom running to both ends of the bar — painted beneath all tabs (Chrome-style stacking), so the active tab and its ears naturally eclipse the middle and the line emerges from behind the ear curves with no junction seams; `null` disables both
- Interactions: click to switch, × / middle-click to close, closing the active tab activates the right neighbor (or left if none), closing the last tab auto-creates a "New Tab"
- Tooltips: the + button, the overflow button and each tab's close button show tooltips on hover (`newTabTooltip` / `overflowButtonTooltip` / `closeButtonTooltip`, `null` to disable)
- Context menu: right-click a tab (or empty strip area) opens the menu — New tab / Close / Close tabs to the left / Close other tabs / Close tabs to the right; unavailable items are disabled automatically. Keyboard: Menu key / Shift+F10 opens it on the focused tab
- Keyboard: roving focus + ←/→ to move (including hidden tabs, the visible window auto-pans) + Enter/Space to activate
- Animations: hover / close-button exponential ease-out fades (~150ms)
- Light & dark themes: `TabBarStyle.light` / `TabBarStyle.dark`; defaults to `Theme.brightness`
- Zero third-party dependencies

## Usage

```dart
import 'package:browser_tab_bar/browser_tab_bar.dart';

final controller = TabBarController(
  initialTabs: const [TabData(title: 'Docs', url: 'flutter.dev')],
);

// Read / operate
controller.tabs;            // List<TabData>
controller.active();        // active id
controller.add(const TabData(title: 'New Tab'));
controller.close(id);
controller.activate(id);
controller.update(id, title: 'New title', url: 'example.com');
controller.closeOthers(id); // close everything except [id]
controller.closeLeft(id);   // close all tabs to the left of [id]
controller.closeRight(id);  // close all tabs to the right of [id]

// Listen for changes (activate / add / close) and render your own content
controller.onChange = (event) => setState(() { /* your content */ });

// Put up the strip (height 38, fills the available width)
BrowserTabBar(controller: controller);

// Optional customization: new-tab title / icon, button tooltips
BrowserTabBar(
  controller: controller,
  newTabLabel: 'New Tab',                      // + button / context menu / auto-created tab
  newTabIcon: const Icon(Icons.add, size: 16), // null = default hand-drawn cross
  newTabTooltip: 'New tab (Ctrl+T)',           // null disables
  overflowButtonTooltip: 'More tabs',          // null disables
  closeButtonTooltip: 'Close tab',             // tab close buttons, null disables
);
```

The content area is entirely yours — `BrowserTabBar` renders no tab content.

Integration note: the active tab and the toolbar below it share the same color and are meant to visually connect. Give your toolbar an opaque background and place it directly below the strip — with the default `activeBorder`, the bottom separator fills the strip's last pixel row and covers the junction (see `example/lib/main.dart`). If you disable `activeBorder` (null), overlap the toolbar ~1px onto the strip (`Transform.translate(0, -1)`) to hide a hairline seam at fractional DPI scales.

## Example

The `example/` folder is a complete demo app (tab strip + custom omnibox toolbar + custom content area, via path dependency):

```
cd example
flutter run
```

## Tests

```
flutter test
```

---

# 中文

[English](#english) | **中文**

Chrome 风格浏览器标签栏组件（纯 UI 库）。**只包含标签条本体，页面内容由使用方自定义**：通过 `TabBarController` 驱动标签增删改查，自行渲染激活标签对应的内容。

## 截图

| 浅色 | 深色 |
| --- | --- |
| ![浅色主题](snapshot/Snipaste_2026-08-16_12-06-50.png) | ![深色主题](snapshot/Snipaste_2026-08-16_12-06-10.png) |

![溢出下拉](snapshot/Snipaste_2026-08-16_12-07-02.png)

## 特性

- Chrome 形态：tab 高 34 / 条高 38，顶部圆角 8px，宽 72–240px 弹性等分
- 溢出下拉：标签放不下时左侧出现矩形下拉按钮，展开剩余标签菜单（可激活 / 关闭）；激活项始终保持在可见窗口内
- 激活 tab 两侧 8px 耳角（concave flare），与工具栏同色连通；透明区透出邻 tab 真实背景
- 激活 tab 轮廓描边：`TabBarStyle.activeBorder` 为激活 tab 画 1px 描边（顶边、两侧、耳角），并沿标签条底部画整条分隔线——画在所有 tab 之下（Chrome 同款层叠），激活 tab 与耳角自然遮蔽中段，线自耳角弧两侧穿出，无对接缝；传 `null` 全部关闭
- 交互：单击切换、× / 中键关闭、关闭激活 tab 自动接右邻（无则左邻）、最后一个关闭自动补"新标签页"
- Tooltip：+ 按钮、溢出下拉按钮与 tab 关闭钮悬停显示提示（`newTabTooltip` / `overflowButtonTooltip` / `closeButtonTooltip` 可自定义，传 `null` 关闭）
- 右键菜单：右键 tab（或标签条空白区域）弹出菜单——新建标签页 / 关闭 / 关闭左侧 / 关闭其他 / 关闭右侧；不可用项自动禁用；键盘菜单键 / Shift+F10 在焦点 tab 处弹出
- 键盘：roving focus + ←/→ 移动（含隐藏标签，可见窗口自动平移）+ Enter/Space 激活
- 动效：悬停 / 关闭钮指数 ease-out 渐变（~150ms）
- 明暗主题：`TabBarStyle.light` / `TabBarStyle.dark`，不传则跟随 `Theme.brightness`
- 零第三方依赖

## 用法

```dart
import 'package:browser_tab_bar/browser_tab_bar.dart';

final controller = TabBarController(
  initialTabs: const [TabData(title: '文档', url: 'flutter.dev')],
);

// 读取/操作
controller.tabs;            // List<TabData>
controller.active();        // 激活 id
controller.add(const TabData(title: '新标签页'));
controller.close(id);
controller.activate(id);
controller.update(id, title: '新标题', url: 'example.com');
controller.closeOthers(id); // 关闭除 [id] 外的所有标签
controller.closeLeft(id);   // 关闭 [id] 左侧的所有标签
controller.closeRight(id);  // 关闭 [id] 右侧的所有标签

// 监听变化（activate / add / close），据此渲染你自己的内容区
controller.onChange = (event) => setState(() { /* 自定义内容 */ });

// 放入标签条（高度 38，自动占满宽度）
BrowserTabBar(controller: controller);

// 可选自定义：新标签文本 / 图标、按钮 tooltip
BrowserTabBar(
  controller: controller,
  newTabLabel: '新标签页',                      // + 按钮 / 右键"新建" / 自动补位的标题
  newTabIcon: const Icon(Icons.add, size: 16), // 不传 = 默认手绘十字
  newTabTooltip: '新建标签页 (Ctrl+T)',         // 传 null 关闭
  overflowButtonTooltip: '更多标签页',          // 传 null 关闭
  closeButtonTooltip: '关闭标签页',             // tab 关闭钮，传 null 关闭
);
```

内容区完全由你决定——`BrowserTabBar` 不渲染任何标签内容。

集成提示：激活 tab 与下方工具栏是"同色连通"的，工具栏请使用不透明背景色，直接紧贴标签条下方即可——默认 `activeBorder` 的底部分隔线铺满标签条最底一行，已盖住拼接缝（演示见 `example/lib/main.dart`）。若关闭 `activeBorder`（传 `null`），请让工具栏上叠标签条 ~1px（`Transform.translate(0, -1)`）以消除分数 DPI 下的拼缝灰线。

## 运行示例

`example/` 是完整演示 app（标签条 + 自定义 omnibox 工具栏 + 自定义内容区，path 依赖本包）：

```
cd example
flutter run
```

## 测试

```
flutter test
```
