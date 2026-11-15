// 左侧文章目录在 1000px 以下变成抽屉（issue #13）。
//
// OINK 的侧栏隔离逻辑按 768px 划分桌面与移动：768–999 之间它仍把面板当桌面栏，
// 既不会把关着的抽屉移出无障碍树，也会让从桌面带下来的“收起”状态把打开后的
// 抽屉内容标成 inert。关着的抽屉由 CSS visibility 收进无障碍树；这里只清掉
// 桌面收起态并解除它留下的 inert/aria-hidden，让抽屉打开后真的能用。
(function () {
  'use strict';

  var html = document.documentElement;
  var narrow = window.matchMedia('(max-width: 999.98px)');

  function releaseSidebar() {
    if (!narrow.matches) {
      return;
    }
    if (html.getAttribute('data-td-shell-sidebar') === 'collapsed') {
      html.removeAttribute('data-td-shell-sidebar');
    }
    var panel = document.querySelector('#td-shell-sidebar .td-shell-sidebar__panel');
    if (!panel) {
      return;
    }
    Array.prototype.forEach.call(panel.children, function (child) {
      child.inert = false;
    });
    panel.removeAttribute('aria-hidden');
  }

  narrow.addEventListener('change', releaseSidebar);
  releaseSidebar();
  new MutationObserver(releaseSidebar).observe(html, {
    attributes: true,
    attributeFilter: ['data-td-shell-sidebar']
  });
})();
