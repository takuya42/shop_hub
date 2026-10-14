import 'selected_file_resources_stub.dart'
    if (dart.library.js_interop) 'selected_file_resources_web.dart'
    as platform;

// Picker-owned Blob URLs are no longer needed after copying image bytes.
void releaseSelectedFile(String path) => platform.releaseSelectedFile(path);
