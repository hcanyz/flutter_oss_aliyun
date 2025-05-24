import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

class EncryptUtil {
  static String hmacSign(String secret, String payload) {
    final Hmac hmac = Hmac(sha1, utf8.encode(secret));
    final Digest digest = hmac.convert(utf8.encode(payload));
    return base64.encode(digest.bytes);
  }

  static List<int> hmacSign256Raw(List<int> key, String payload) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(payload));
    return digest.bytes;
  }

  static String sign256Hex(String payload) {
    final digest = sha256.convert(utf8.encode(payload));
    return hex.encode(digest.bytes);
  }

  /// use md5 to encrypt the bytes content
  static String md5FromBytes(List<int> bytes) {
    final Digest digest = md5.convert(bytes);
    return base64.encode(digest.bytes);
  }
}
