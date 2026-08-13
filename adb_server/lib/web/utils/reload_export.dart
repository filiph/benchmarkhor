import 'reload.dart' if (dart.library.js_interop) 'reload_web.dart' as impl;

void reloadLocation() {
  impl.reloadPage();
}
