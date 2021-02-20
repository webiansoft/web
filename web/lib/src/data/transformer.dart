import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../fault.dart';
import '../headers.dart';
import '../options/request_options.dart';
import '../responses/response_body.dart';
import '../responses/responses.dart';
import '../utils.dart';

/// [Transformer] allows changes to the request/response data before
/// it is sent/received to/from the server.
///
/// Web has already implemented a [DefaultTransformer], and as the default
/// [Transformer]. If you want to custom the transformation of
/// request/response data, you can provide a [Transformer] by your self, and
/// replace the [DefaultTransformer] by setting the [Web.Transformer].

abstract class Transformer {
  /// `transformRequest` allows changes to the request data before it is
  /// sent to the server, but **after** the [RequestInterceptor].
  ///
  /// This is only applicable for request methods 'PUT', 'POST', and 'PATCH'
  Future<String> transformRequest(RequestOptions options);

  /// `transformResponse` allows changes to the response data  before
  /// it is passed to [ResponseInterceptor].
  ///
  /// **Note**: As an agreement, you must return the [response]
  /// when the Options.responseType is [ResponseType.stream].
  Future transformResponse(RequestOptions options, ResponseBody response);

  /// Deep encode the [Map<String, dynamic>] to percent-encoding.
  /// It is mostly used with  the "application/x-www-form-urlencoded" content-type.
  ///
  static String urlEncodeMap(Map map) {
    return encodeMap(map, (key, value) {
      if (value == null) return key;
      return '$key=${Uri.encodeQueryComponent(value.toString())}';
    });
  }
}

/// The default [Transformer] for [Web]. If you want to custom the transformation of
/// request/response data, you can provide a [Transformer] by your self, and
/// replace the [DefaultTransformer] by setting the [Web.Transformer].

typedef JsonDecodeCallback = dynamic Function(String);

class DefaultTransformer extends Transformer {
  DefaultTransformer({this.jsonDecodeCallback});

  JsonDecodeCallback? jsonDecodeCallback;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    var data = options.data ?? '';
    if (data is! String) {
      if (_isJsonMime(options.contentType)) {
        return json.encode(options.data);
      } else if (data is Map) {
        return Transformer.urlEncodeMap(data);
      }
    }
    return data.toString();
  }

  /// As an agreement, you must return the [response]
  /// when the Options.responseType is [ResponseType.stream].
  @override
  Future transformResponse(
      RequestOptions options, ResponseBody response) async {
    if (options.responseType == ResponseType.stream) {
      return response;
    }
    var length = 0;
    var received = 0;
    var showDownloadProgress = options.onReceiveProgress != null;
    if (showDownloadProgress) {
      length = -1;
      int.parse(response.headers[Headers.contentLengthHeader]?.first ?? '-1');
    }
    var completer = Completer();
    var stream =
        response.stream.transform<Uint8List>(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        sink.add(data);
        if (showDownloadProgress) {
          received += data.length;
          if (options.onReceiveProgress != null) {
            options.onReceiveProgress!(received, length);
          }
        }
      },
    ));
    // let's keep references to the data chunks and concatenate them later
    final chunks = <Uint8List>[];
    var finalSize = 0;
    StreamSubscription subscription = stream.listen(
      (chunk) {
        finalSize += chunk.length;
        chunks.add(chunk);
      },
      onError: (e) {
        completer.completeError(e);
      },
      onDone: () {
        completer.complete();
      },
      cancelOnError: true,
    );
    // ignore: unawaited_futures
    options.cancelToken?.whenCancel.then((_) {
      return subscription.cancel();
    });
    if (options.receiveTimeout != null && options.receiveTimeout! > 0) {
      try {
        await completer.future
            .timeout(Duration(milliseconds: options.receiveTimeout!));
      } on TimeoutException {
        await subscription.cancel();
        throw Fault(
          request: options,
          error: 'Receiving data timeout[${options.receiveTimeout}ms]',
          type: FaultType.RECEIVE_TIMEOUT,
        );
      }
    } else {
      await completer.future;
    }
    // we create a final Uint8List and copy all chunks into it
    final responseBytes = Uint8List(finalSize);
    var chunkOffset = 0;
    for (var chunk in chunks) {
      responseBytes.setAll(chunkOffset, chunk);
      chunkOffset += chunk.length;
    }

    if (options.responseType == ResponseType.bytes) return responseBytes;

    String? responseBody;
    if (options.responseDecoder != null) {
      responseBody = options.responseDecoder!(
          responseBytes, options, response..stream = Stream.empty());
    } else {
      responseBody = utf8.decode(responseBytes, allowMalformed: true);
    }
    if (responseBody.isNotEmpty &&
        options.responseType == ResponseType.json &&
        _isJsonMime(response.headers[Headers.contentTypeHeader]?.first)) {
      final callback = jsonDecodeCallback;
      if (callback != null) {
        return callback(responseBody);
      } else {
        return json.decode(responseBody);
      }
    }
    return responseBody;
  }

  bool _isJsonMime(String? contentType) {
    if (contentType == null) return false;
    return MediaType.parse(contentType).mimeType.toLowerCase() ==
        Headers.jsonMimeType.mimeType;
  }
}