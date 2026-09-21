// Configuration backend for the personal website template.
//
// Does one thing only: allows the editor mode to write changes
// back to JSON files under assets/data.
//
// No third-party dependencies, uses dart:io only. Run directly with:
//
//   dart server/server.dart --data-dir assets/data --port 8090
//
// In production, use nginx to proxy /api/ to this port, so the
// frontend only talks to the same-origin /api/.
// Can also be compiled into a single executable:
//
//   dart compile exe server/server.dart -o transformer_blog-server
//
// Security note: write operations must include the X-Edit-Password
// request header. The password is read from the editPassword field
// in profile.json. Without it, anyone could modify your site via curl.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Allowed filenames for read/write, hardcoded whitelist to prevent path traversal.
const Set<String> _allowedFiles = <String>{
  'profile.json',
  'friendship.json',
  'articles.json',
};

/// Expected top-level structure for each file, validated before writing.
const Map<String, String> _expectedType = <String, String>{
  'profile.json': 'object',
  'friendship.json': 'array',
  'articles.json': 'array',
};

/// Request body size limit. Config files should never be this large.
const int _maxBodyBytes = 8 * 1024 * 1024;

Future<void> main(List<String> args) async {
  final Map<String, String> options = _parseArgs(args);
  final Directory dataDir = Directory(options['data-dir'] ?? 'assets/data');
  final int port = int.tryParse(options['port'] ?? '') ?? 8090;
  final String host = options['host'] ?? '127.0.0.1';
  final Directory? staticDir = options['static'] == null
      ? null
      : Directory(options['static']!);

  if (!dataDir.existsSync()) {
    stderr.writeln('Data directory does not exist: ${dataDir.absolute.path}');
    exitCode = 1;
    return;
  }

  final HttpServer server = await HttpServer.bind(host, port);
  stdout.writeln('Data directory: ${dataDir.absolute.path}');
  if (staticDir != null) {
    stdout.writeln('Static directory: ${staticDir.absolute.path}');
  }
  stdout.writeln('Listening: http://$host:$port');
  stdout.writeln(
    'Read API:  GET /api/data/<profile.json|friendship.json|articles.json>',
  );
  stdout.writeln(
    'Write API: PUT /api/data/<file>, requires X-Edit-Password header',
  );

  await for (final HttpRequest request in server) {
    try {
      await _handle(request, dataDir, staticDir);
    } on Exception catch (error) {
      stderr.writeln('Error handling request: $error');
      await _sendJson(
        request,
        HttpStatus.internalServerError,
        <String, Object?>{'ok': false, 'error': 'Internal server error'},
      );
    }
  }
}

Future<void> _handle(
  HttpRequest request,
  Directory dataDir,
  Directory? staticDir,
) async {
  final String path = request.uri.path;

  // Browsers send an OPTIONS preflight before custom-header requests.
  if (request.method == 'OPTIONS') {
    await _sendJson(request, HttpStatus.noContent, null);
    return;
  }

  if (path.startsWith('/api/data/')) {
    await _handleApi(request, dataDir, path.substring('/api/data/'.length));
    return;
  }

  if (path == '/api/health') {
    await _sendJson(request, HttpStatus.ok, <String, Object?>{'ok': true});
    return;
  }

  if (staticDir != null && request.method == 'GET') {
    await _serveStatic(request, staticDir);
    return;
  }

  await _sendJson(request, HttpStatus.notFound, <String, Object?>{
    'ok': false,
    'error': 'Endpoint not found',
  });
}

Future<void> _handleApi(
  HttpRequest request,
  Directory dataDir,
  String name,
) async {
  if (!_allowedFiles.contains(name)) {
    await _sendJson(request, HttpStatus.notFound, <String, Object?>{
      'ok': false,
      'error': 'Only files in $_allowedFiles are allowed',
    });
    return;
  }

  final File file = File('${dataDir.path}/$name');

  switch (request.method) {
    case 'GET':
      if (!file.existsSync()) {
        await _sendJson(request, HttpStatus.notFound, <String, Object?>{
          'ok': false,
          'error': '$name does not exist',
        });
        return;
      }
      final String body = await file.readAsString();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        )
        ..headers.set('Cache-Control', 'no-store');
      _applyCors(request);
      request.response.write(body);
      await request.response.close();

    case 'PUT':
      await _handleWrite(request, dataDir, file, name);

    default:
      await _sendJson(request, HttpStatus.methodNotAllowed, <String, Object?>{
        'ok': false,
        'error': 'Only GET and PUT are supported',
      });
  }
}

Future<void> _handleWrite(
  HttpRequest request,
  Directory dataDir,
  File file,
  String name,
) async {
  // Re-read the password on every write so changing profile.json
  // does not require a service restart.
  final String? expected = await _readPassword(dataDir);
  if (expected == null || expected.isEmpty) {
    await _sendJson(request, HttpStatus.forbidden, <String, Object?>{
      'ok': false,
      'error':
          'editPassword is not configured in profile.json, write API disabled',
    });
    return;
  }

  final String? provided = _decodePassword(
    request.headers.value('X-Edit-Password'),
  );
  if (provided == null || provided != expected) {
    await _sendJson(request, HttpStatus.unauthorized, <String, Object?>{
      'ok': false,
      'error': 'Incorrect password',
    });
    return;
  }

  final String body = await _readBody(request);
  if (body.isEmpty) {
    await _sendJson(request, HttpStatus.badRequest, <String, Object?>{
      'ok': false,
      'error': 'Request body is empty',
    });
    return;
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    await _sendJson(request, HttpStatus.badRequest, <String, Object?>{
      'ok': false,
      'error': 'Invalid JSON',
    });
    return;
  }

  // Reject if the top-level structure is wrong, to avoid corrupting site data.
  final String expectedType = _expectedType[name]!;
  final bool typeOk = expectedType == 'object'
      ? decoded is Map<String, dynamic>
      : decoded is List;
  if (!typeOk) {
    await _sendJson(request, HttpStatus.badRequest, <String, Object?>{
      'ok': false,
      'error': '$name expects a top-level JSON $expectedType',
    });
    return;
  }

  // Write to a temp file first, then rename, to avoid corruption
  // if the process is killed mid-write.
  final File temp = File('${file.path}.tmp');
  await temp.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(decoded)}\n',
    flush: true,
  );
  await temp.rename(file.path);

  stdout.writeln('${DateTime.now().toIso8601String()} Wrote $name');
  await _sendJson(request, HttpStatus.ok, <String, Object?>{
    'ok': true,
    'file': name,
  });
}

Future<String?> _readPassword(Directory dataDir) async {
  try {
    final File file = File('${dataDir.path}/profile.json');
    if (!file.existsSync()) return null;
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return null;
    final Object? password = decoded['editPassword'];
    return password is String ? password : null;
  } on Exception {
    return null;
  }
}

Future<String> _readBody(HttpRequest request) async {
  final BytesBuilder builder = BytesBuilder();
  int total = 0;
  await for (final List<int> chunk in request) {
    total += chunk.length;
    if (total > _maxBodyBytes) {
      throw const FormatException('Request body too large');
    }
    builder.add(chunk);
  }
  return utf8.decode(builder.takeBytes());
}

Future<void> _serveStatic(HttpRequest request, Directory staticDir) async {
  final String relative = request.uri.path == '/'
      ? '/index.html'
      : request.uri.path;
  final File file = File('${staticDir.path}$relative');
  if (!file.existsSync()) {
    await _sendJson(request, HttpStatus.notFound, <String, Object?>{
      'ok': false,
      'error': 'File not found',
    });
    return;
  }
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = _contentTypeOf(relative);
  await request.response.addStream(file.openRead());
  await request.response.close();
}

ContentType _contentTypeOf(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js'))
    return ContentType('application', 'javascript', charset: 'utf-8');
  if (path.endsWith('.json'))
    return ContentType('application', 'json', charset: 'utf-8');
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.css'))
    return ContentType('text', 'css', charset: 'utf-8');
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.otf')) return ContentType('font', 'otf');
  if (path.endsWith('.ttf')) return ContentType('font', 'ttf');
  return ContentType.binary;
}

Future<void> _sendJson(
  HttpRequest request,
  int status,
  Map<String, Object?>? body,
) async {
  request.response
    ..statusCode = status
    ..headers.set('Cache-Control', 'no-store');
  _applyCors(request);
  if (body != null) {
    request.response
      ..headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      )
      ..write(jsonEncode(body));
  }
  await request.response.close();
}

/// Decodes the password from the request header.
///
/// The frontend percent-encodes the password before putting it in the
/// header, because HTTP headers only allow ASCII. Chinese characters
/// in the password would cause the request to fail without encoding.
/// Pure ASCII passwords are unaffected by encode/decode.
/// If decoding fails (e.g., old unencoded requests), the raw value is used.
String? _decodePassword(String? raw) {
  if (raw == null) return null;
  try {
    return Uri.decodeComponent(raw);
  } on FormatException {
    return raw;
  }
}

/// Allows cross-origin requests during development when the frontend
/// runs on a different port.
///
/// The write API is protected by a password, so opening the origin here
/// is safe.
void _applyCors(HttpRequest request) {
  request.response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type, X-Edit-Password');
}

Map<String, String> _parseArgs(List<String> args) {
  final Map<String, String> options = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (!arg.startsWith('--')) continue;
    final String key = arg.substring(2);
    if (key == 'static') {
      // --static can be followed by a directory, or omitted (defaults to build/web)
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        options[key] = args[++i];
      } else {
        options[key] = 'build/web';
      }
      continue;
    }
    if (i + 1 < args.length) {
      options[key] = args[++i];
    }
  }
  return options;
}
