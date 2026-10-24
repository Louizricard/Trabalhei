# Trabalhei — app Flutter

Código do aplicativo. A documentação completa (modelo de negócio, backend, como rodar) está no
[README da raiz](../README.md).

```bash
cp dart_defines.example.json dart_defines.json   # preencha SUPABASE_URL e SUPABASE_ANON_KEY
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```
