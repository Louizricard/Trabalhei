// Service worker só de notificações push (escopo ./push/, registrado por
// push.js). Mostra o aviso e, no clique, abre o app na rota da notificação.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { body: event.data ? event.data.text() : '' };
  }
  var route = data.route || '/notifications';
  event.waitUntil(
    self.registration.showNotification(data.title || 'Trabalhei', {
      body: data.body || '',
      icon: '../icons/Icon-192.png',
      badge: '../icons/Icon-maskable-192.png',
      tag: route,
      data: { route: route },
    }),
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var route = (event.notification.data && event.notification.data.route) || '/notifications';
  var appUrl = new URL('../', self.registration.scope).href;
  event.waitUntil(
    (async function () {
      var windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (var i = 0; i < windows.length; i++) {
        if (windows[i].url.indexOf(appUrl) === 0) {
          windows[i].postMessage({ type: 'trabalhei-open', route: route });
          return windows[i].focus();
        }
      }
      return self.clients.openWindow(appUrl + '#' + route);
    })(),
  );
});
