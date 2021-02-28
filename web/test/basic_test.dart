// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:web/web.dart';

void main() {
  test('#test headers', () {
    var headers = Headers.fromMap({
      'set-cookie': ['k=v', 'k1=v1'],
      'content-length': ['200'],
      'test': ['1', '2'],
    });
    headers.add('SET-COOKIE', 'k2=v2');
    assert(headers.value('content-length') == '200');
    expect(Future(() => headers.value('test')), throwsException);
    assert(headers['set-cookie']?.length == 3);
    headers.remove('set-cookie', 'k=v');
    assert(headers['set-cookie']?.length == 2);
    headers.removeAll('set-cookie');
    assert(headers['set-cookie'] == null);
    var ls = [];
    headers.forEach((k, list) {
      ls.addAll(list);
    });
    assert(ls.length == 3);
    assert(headers.toString() == 'content-length: 200\ntest: 1\ntest: 2\n');
    headers.set('content-length', '300');
    assert(headers.value('content-length') == '300');
    headers.set('content-length', ['400']);
    assert(headers.value('content-length') == '400');

    var headers1 = Headers();
    headers1.set('xx', 'v');
    assert(headers1.value('xx') == 'v');
    headers1.clear();
    assert(headers1.map.isEmpty == true);
  });

  test('#send with an invalid URL', () {
    expect(Web().get('http://http.invalid').catchError((e) => throw e.error),
        throwsA(const TypeMatcher<SocketException>()));
  });

  test('#cancellation', () async {
    var web = Web();
    final token = CancelToken();
    Timer(Duration(milliseconds: 10), () {
      token.cancel('cancelled');
      web.httpClientAdapter.close(force: true);
    });

    var url = 'https://accounts.google.com';
    expect(
        web
            .get(url, cancelToken: token)
            .catchError((e) => throw CancelToken.isCancel(e)),
        throwsA(isTrue));
  });

  test('#url encode ', () {
    var data = {
      'a': '你好',
      'b': [5, '6'],
      'c': {
        'd': 8,
        'e': {
          'a': 5,
          'b': [66, 8]
        }
      }
    };
    var result =
        'a=%E4%BD%A0%E5%A5%BD&b%5B%5D=5&b%5B%5D=6&c%5Bd%5D=8&c%5Be%5D%5Ba%5D=5&c%5Be%5D%5Bb%5D%5B%5D=66&c%5Be%5D%5Bb%5D%5B%5D=8';
    expect(Transformer.urlEncodeMap(data), result);
  });
}
