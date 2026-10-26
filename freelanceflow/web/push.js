// Web Push do Trabalhei: inscreve o navegador no service worker próprio
// (push-sw.js, escopo ./push/) e expõe a API usada pelo app em
// window.trabalheiPush. O service worker do Flutter não é afetado.
(function () {
  var SCOPE = './push/';

  function keyBytes(base64url) {
    var b64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) b64 += '=';
    var bin = atob(b64);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  async function activeRegistration() {
    var reg = await navigator.serviceWorker.register('push-sw.js', { scope: SCOPE });
    var worker = reg.installing || reg.waiting;
    if (!reg.active && worker) {
      await new Promise(function (resolve) {
        worker.addEventListener('statechange', function () {
          if (worker.state === 'activated') resolve();
        });
      });
    }
    return reg;
  }

  async function currentSubscription() {
    if (!supported()) return null;
    var reg = await navigator.serviceWorker.getRegistration(SCOPE);
    return reg ? reg.pushManager.getSubscription() : null;
  }

  window.trabalheiPush = {
    supported: supported,
    permission: function () {
      return supported() ? Notification.permission : 'unsupported';
    },
    // Pede permissão e devolve a inscrição em JSON, ou null se negada.
    subscribe: async function (vapidPublicKey) {
      if ((await Notification.requestPermission()) !== 'granted') return null;
      var reg = await activeRegistration();
      var sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: keyBytes(vapidPublicKey),
        });
      }
      return JSON.stringify(sub.toJSON());
    },
    endpoint: async function () {
      var sub = await currentSubscription();
      return sub ? sub.endpoint : null;
    },
    // Cancela a inscrição deste navegador e devolve o endpoint removido.
    unsubscribe: async function () {
      var sub = await currentSubscription();
      if (!sub) return null;
      var endpoint = sub.endpoint;
      await sub.unsubscribe();
      return endpoint;
    },
  };

  // Clique na notificação com o app já aberto: o service worker manda a rota.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (event) {
      if (event.data && event.data.type === 'trabalhei-open' && event.data.route) {
        location.hash = event.data.route;
      }
    });
  }
})();
