// Cliente mínimo do protocolo DevTools (WebSocket nativo do Node 22+).

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export function connect(url) {
  const ws = new WebSocket(url);
  let id = 0;
  const pending = new Map();
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
    }
  };
  const send = (method, params = {}, sessionId) =>
    new Promise((resolve, reject) => {
      const msgId = ++id;
      pending.set(msgId, { resolve, reject });
      ws.send(JSON.stringify({ id: msgId, method, params, sessionId }));
    });
  return new Promise((resolve) => (ws.onopen = () => resolve({ ws, send })));
}

/** Espera o navegador abrir a porta de depuração e devolve o WebSocket dele. */
export async function browserSocket(port) {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`);
      return (await res.json()).webSocketDebuggerUrl;
    } catch {
      await sleep(200);
    }
  }
  throw new Error('Navegador não respondeu na porta de depuração.');
}
