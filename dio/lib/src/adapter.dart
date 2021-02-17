import 'dart:convert';
import 'dart:typed_data';

import 'options.dart';
import 'redirect_record.dart';

typedef CancelWrapper = Future Function(Future);
typedef VoidCallback = dynamic Function();

/// HttpAdapter is a bridge between Dio and HttpClient.
///
/// Dio: Implements a standard and friendly API for developers.
///
/// HttpClient: It is what actually makes the http requests.
///
/// We can use any HttpClient not just "dart:io:HttpClient" to
/// make Http requests. All we need is to provide a [HttpClientAdapter].
///
/// The default HttpClientAdapter for Dio is [DefaultHttpClientAdapter].
///
/// ```dart
/// dio.httpClientAdapter = DefaultHttpClientAdapter();
/// ```
abstract class HttpClientAdapter {
  /// We should implement this method to make real http requests.
  ///
  /// [options]: The request options
  ///
  /// [requestStream] The request stream, It will not be null
  /// only when http method is one of "POST","PUT","PATCH"
  /// and the request body is not empty.
  ///
  /// We should give priority to using requestStream(not options.data) as request data.
  /// because supporting stream ensures the `onSendProgress` works.
  ///
  /// [cancelFuture]: When the request is cancelled, then [cancelFuture] will be resolved!
  /// you can listen to its cancel event, for example:
  ///
  /// ```dart
  ///  cancelFuture?.then((_)=>print("request cancelled!"))
  /// ```
  /// [cancelFuture]: will be null when the request is not set [CancelToken].

  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>> requestStream,
    Future? cancelFuture,
  );

  void close({bool force = false});
}

class ResponseBody {
  ResponseBody(
    this.stream,
    this.statusCode, {
    this.headers = const {},
    this.statusMessage,
    this.isRedirect = false,
    this.redirects,
  });

  /// The response stream
  Stream<Uint8List> stream;

  /// the response headers
  late Map<String, List<String>> headers;

  /// Http status code
  int? statusCode;

  /// Returns the reason phrase associated with the status code.
  /// The reason phrase must be set before the body is written
  /// to. Setting the reason phrase after writing to the body.
  String? statusMessage;

  /// Whether this response is a redirect.
  final bool isRedirect;

  List<RedirectRecord>? redirects;

  Map<String, dynamic> extra = {};

  ResponseBody.fromString(
    String text,
    this.statusCode, {
    this.headers = const {},
    this.statusMessage,
    this.isRedirect = false,
  }) : stream = Stream.fromIterable(
            utf8.encode(text).map((e) => Uint8List.fromList([e])).toList());

  ResponseBody.fromBytes(
    List<int> bytes,
    this.statusCode, {
    this.headers = const {},
    this.statusMessage,
    this.isRedirect = false,
  }) : stream = Stream.fromIterable(
            bytes.map((e) => Uint8List.fromList([e])).toList());
}
