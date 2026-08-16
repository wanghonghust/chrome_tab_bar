## 0.2.0

* 右键菜单：右键 tab（或标签条空白区域）弹出上下文菜单——新建标签页 / 关闭（自绘线性图标）、分隔线、关闭左侧 / 关闭其他 / 关闭右侧（批量组，无图标）；不可用项自动禁用；键盘菜单键 / Shift+F10 在焦点 tab 处弹出。
* `TabBarController` 新增 `closeOthers` / `closeLeft` / `closeRight`（先切激活再批量关闭，事件流干净）。

## 0.1.1

* LICENSE 版权人更正（wanghonghust → wanghong）。

## 0.1.0

* Initial release.
* Chrome 风格标签条：tab 高 34 / 条高 38，宽 72–240px 弹性等分，激活 tab 8px 耳角与工具栏同色连通。
* 溢出下拉：标签放不下时左侧出现下拉按钮，展开剩余标签菜单（可激活 / 关闭）；激活项始终保持在可见窗口内。
* 交互：单击切换、× / 中键关闭、关闭激活 tab 自动接右邻、最后一个关闭自动补"新标签页"。
* 键盘：roving focus + ←/→ 移动 + Enter/Space 激活，Esc / 鼠标点击收起焦点环。
* 明暗主题（`TabBarStyle.light` / `dark`），零第三方依赖。
