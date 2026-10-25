import 'dart:js_interop';
import 'dart:js_interop_unsafe';

const _key = 'trabalhei-sessao-aberta';

JSObject get _sessionStorage => globalContext['sessionStorage'] as JSObject;

/// Se esta aba já marcou o login (o sessionStorage some ao fechar a aba).
bool isBrowserSessionMarked() =>
    _sessionStorage.callMethod<JSAny?>('getItem'.toJS, _key.toJS) != null;

void markBrowserSession() =>
    _sessionStorage.callMethod<JSAny?>('setItem'.toJS, _key.toJS, '1'.toJS);

/// Remove da barra de endereço os parâmetros de links de e-mail
/// (`?token_hash=...`), mantendo a rota do app (`#/...`).
void clearUrlQuery() {
  final location = globalContext['location'] as JSObject;
  final path = (location['pathname'] as JSString).toDart;
  final hash = (location['hash'] as JSString).toDart;
  final history = globalContext['history'] as JSObject;
  // callMethodVarArgs: com callMethod, um primeiro argumento null faz o
  // dart2js chamar replaceState() sem argumentos, o que lança erro.
  history.callMethodVarArgs<JSAny?>('replaceState'.toJS, [
    null,
    ''.toJS,
    '$path$hash'.toJS,
  ]);
}
