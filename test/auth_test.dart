import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';
import 'package:flutter_oss_aliyun/src/model/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test the put object in Client', () async {
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
    auth.sign(req, 'examplebucket', 'exampleobject');
    expect(req.headers['Authorization'], '200');
  });
}
