import 'package:web/web.dart' as web;

void releaseSelectedFile(String path) {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}
