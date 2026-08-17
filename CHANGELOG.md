## 0.2.2

* New-tab (+) button spacing widened: 5px gap to the last tab (matching the button's bottom margin, both up from 3px), and the inter-tab separator style now extends to the + button: a 1×18 divider is painted flush against the last visible tab's right edge (takes no layout space; hides while that tab is active, same as separators between tabs).
* Overflow dropdown button now mirrors the + button exactly: same 28×28 size, same 5px bottom margin, a 4px margin to the strip's left edge and a 5px gap to the first tab (with a matching separator painted flush against the first tab's left edge, hidden while that tab is active); the popup menu narrows from 264 to 220.
* Tooltips: the + button, the overflow button and each tab's close button now show tooltips on hover — customizable via `newTabTooltip` / `overflowButtonTooltip` / `closeButtonTooltip` (pass `null` to disable; close button defaults to "关闭").
* New-tab customization: `newTabLabel` overrides the title used by the + button, the context menu's "New tab" and the auto-created tab after closing the last one (falls back to `controller.newTabLabel`); `newTabIcon` replaces the default hand-drawn cross with any widget.

## 0.2.1

* Active tab outline border + strip-bottom separator: new style token `TabBarStyle.activeBorder` (defaults to the divider color; pass `null` to disable both).
* 1px outline on the active tab itself (top edge, sides, ears), excluding the bottom edge — it keeps blending with the toolbar below.
* The bottom separator fills the strip's last pixel row and runs to both ends of the bar, painted beneath all tabs (Chrome-style stacking): the active tab's fill and ear wings naturally eclipse the middle, the line emerges from behind the ear curves — intersection makes the joint, no butt-joint seams. The separator also covers the junction seam with the toolbar (no toolbar overlap needed).

## 0.2.0

* Context menu: right-click a tab (or the empty strip area) opens the menu — New tab / Close (hand-drawn linear icon), divider, Close to the left / Close others / Close to the right (bulk group, no icons); unavailable items are disabled automatically; keyboard Menu / Shift+F10 opens it on the focused tab.
* `TabBarController` gains `closeOthers` / `closeLeft` / `closeRight` (switch activation first, then bulk-close, with a clean event stream).

## 0.1.1

* LICENSE copyright holder corrected (wanghonghust → wanghong).

## 0.1.0

* Initial release.
* Chrome-style tab strip: tab height 34 / strip height 38, flexible equal-width tabs (72–240px), active tab with 8px ears blending into the toolbar.
* Overflow dropdown: when tabs no longer fit, a dropdown button appears on the left listing hidden tabs (activate / close from the menu); the active tab always stays visible.
* Interactions: click to switch, x / middle-click to close, closing the active tab activates the right neighbor, closing the last tab auto-creates a "New Tab".
* Keyboard: roving focus + arrow keys to move + Enter/Space to activate, Esc / click to dismiss the focus ring.
* Light and dark themes (`TabBarStyle.light` / `dark`), zero third-party dependencies.
