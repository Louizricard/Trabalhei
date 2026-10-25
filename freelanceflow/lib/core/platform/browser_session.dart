/// Recursos do navegador usados pelo app web; nas outras plataformas, versões
/// equivalentes em memória.
library;

export 'browser_session_stub.dart'
    if (dart.library.js_interop) 'browser_session_web.dart';
