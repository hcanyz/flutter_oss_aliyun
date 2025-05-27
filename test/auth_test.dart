import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';
import 'package:flutter_oss_aliyun/src/model/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {});
  test('test v4 signature', () async {
    final auth = Auth(
        accessKey: 'LTAI****************',
        accessSecret: 'yourAccessKeySecret',
        secureToken: '',
        expire: '',
        signatureVersion: SignatureVersion.v4,
        region: 'cn-hangzhou');
    // ignore: prefer_const_constructors
    final req = HttpRequest('/examplebucket/exampleobject', 'put', {}, {
      'content-disposition': 'attachment',
      'content-length': 3,
      'content-md5': 'ICy5YqxZB1uWSwcVLSNLcA==',
      'content-type': 'text/plain',
      'x-oss-date': 'text/plain',
    });
    auth.sign(req, 'examplebucket', 'exampleobject',
        date: DateTime.tryParse('20250411T064124Z'));
    print(req.headers['Authorization']);
    expect(req.headers['Authorization'],
        'OSS4-HMAC-SHA256 Credential=LTAI****************/20250411/cn-hangzhou/oss/aliyun_v4_request, AdditionalHeaders=content-disposition;content-length, Signature=d3694c2dfc5371ee6acd35e88c4871ac95a7ba01d3a2f476768fe61218590097');
  });
}
