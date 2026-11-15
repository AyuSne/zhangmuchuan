// 文章页的小型运行时：阅读进度与回到顶部（issue #13）。
//
// 渐进增强：脚本失败时进度条保持 hidden，回到顶部保持不可见；
// prefers-reduced-motion 下锚点与回顶瞬时完成，不做平滑滚动。
(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  // 滚动与尺寸变化共用一个 rAF 节流，回调里只读一次布局。
  function onScrollThrottled(callback) {
    var frame = 0;
    function schedule() {
      if (frame) {
        return;
      }
      frame = window.requestAnimationFrame(function () {
        frame = 0;
        callback();
      });
    }
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule, { passive: true });
    schedule();
  }

  function initReadProgress() {
    var bar = document.querySelector('[data-td-read-progress]');
    var fill = bar && bar.querySelector('[data-td-read-progress-fill]');
    if (!bar || !fill) {
      return;
    }
    bar.hidden = false;
    onScrollThrottled(function () {
      var max = document.documentElement.scrollHeight - window.innerHeight;
      var ratio = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
      fill.style.transform = 'scaleX(' + ratio + ')';
    });
  }

  function initBackToTop() {
    var button = document.querySelector('[data-td-back-top]');
    if (!button) {
      return;
    }
    onScrollThrottled(function () {
      // 1.2 屏之后才淡入：读者确实读进去了，而不是停在文首。
      button.toggleAttribute('data-td-visible', window.scrollY > window.innerHeight * 1.2);
    });
    button.addEventListener('click', function () {
      window.scrollTo({
        top: 0,
        left: 0,
        behavior: reduceMotion.matches ? 'auto' : 'smooth'
      });
      // 回到顶部后按钮会重新隐藏；把焦点交给正文，避免它停在一个不可见的控件上。
      var main = document.getElementById('td-main-content');
      if (main && typeof main.focus === 'function') {
        main.focus({ preventScroll: true });
      }
    });
  }

  initReadProgress();
  initBackToTop();
})();
