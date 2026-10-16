// The current desktop Discuz slider reads mouse coordinates in its touch
// handlers. Translate actual finger movements only on that slider into the
// mouse events it expects; verification and SMS requests remain site-owned.
const smsLoginScript = r'''
(() => {
  document.querySelector('.pwLogintype [t="codelogin"]')?.click();
  if (window.keylolSmsTouchInstalled) return;
  window.keylolSmsTouchInstalled = true;
  let slider = null;
  function forward(event, type) {
    const touch = event.changedTouches[0];
    if (!touch || !slider) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    slider.dispatchEvent(new MouseEvent(type, {
      bubbles: true, cancelable: true, view: window,
      clientX: touch.clientX, clientY: touch.clientY,
      screenX: touch.screenX, screenY: touch.screenY,
      button: 0, buttons: type === 'mouseup' ? 0 : 1
    }));
  }
  document.addEventListener('touchstart', event => {
    slider = event.target.closest?.('.speedtest_slider') || null;
    if (slider) forward(event, 'mousedown');
  }, {capture: true, passive: false});
  document.addEventListener('touchmove', event => {
    if (slider) forward(event, 'mousemove');
  }, {capture: true, passive: false});
  for (const eventName of ['touchend', 'touchcancel']) {
    document.addEventListener(eventName, event => {
      if (!slider) return;
      forward(event, 'mouseup');
      slider = null;
    }, {capture: true, passive: false});
  }
})();
''';
