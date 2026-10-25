// Android, iOS e Windows: a "sessão" dura enquanto o app está aberto.
bool _marked = false;

/// Se esta sessão do navegador (aba) já marcou o login.
bool isBrowserSessionMarked() => _marked;

void markBrowserSession() => _marked = true;

/// Remove da barra de endereço os parâmetros de links de e-mail (só na Web).
void clearUrlQuery() {}
