import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter_oss_aliyun/src/extension/date_extension.dart';
import 'package:flutter_oss_aliyun/src/model/request.dart';
import 'package:flutter_oss_aliyun/src/model/signed_parameters.dart';
import 'package:flutter_oss_aliyun/src/util/encrypt.dart';

enum SignatureVersion {
  v1,
  v4;
}

class Auth {
  Auth({
    required this.accessKey,
    required this.accessSecret,
    required this.secureToken,
    required this.expire,
    this.signatureVersion = SignatureVersion.v1,
    this.region,
  }) : assert(signatureVersion == SignatureVersion.v1 ||
            region?.isNotEmpty == true);

  final String accessKey;
  final String accessSecret;
  final String secureToken;
  final String expire;
  final SignatureVersion signatureVersion;
  final String? region;

  factory Auth.fromJson(Map<String, dynamic> json) {
    return Auth(
      accessKey: json['AccessKeyId'] as String,
      accessSecret: json['AccessKeySecret'] as String,
      secureToken: json['SecurityToken'] as String,
      expire: json['Expiration'] as String,
    );
  }

  bool get isExpired => DateTime.now().isAfter(DateTime.parse(expire));

  String get encodedToken => secureToken.replaceAll("+", "%2B");

  /// access aliyun need authenticated, this is the implementation refer to the official document.
  /// [req] include the request headers information that use for auth.
  /// [bucket] is the name of bucket used in aliyun oss
  /// [key] is the object name in aliyun oss, alias the 'filepath/filename'
  void sign(HttpRequest req, String bucket, String key) {
    req.headers['Authorization'] = signatureVersion == SignatureVersion.v1
        ? _makeSignatureV1(req, bucket, key)
        : _makeSignatureV4(req, bucket, key);
  }

  /// the signature of file
  /// [expires] expired time (seconds)
  /// [bucket] is the name of bucket used in aliyun oss
  /// [key] is the object name in aliyun oss, alias the 'filepath/filename'
  String getSignature(
    int expires,
    String bucket,
    String key, {
    Map<String, dynamic>? params,
  }) {
    final String queryString = params == null
        ? ""
        : params.entries
            .where((entry) => entry.key.toLowerCase().startsWith('x-oss-'))
            .map((entry) => "${entry.key}=${entry.value}")
            .join("&");
    final String paramString = queryString.isEmpty ? "" : "&$queryString";

    final String stringToSign = [
      "GET",
      "",
      '',
      expires,
      "${_getResourceString(bucket, key, {})}?security-token=$secureToken$paramString"
    ].join("\n");
    final String signed = EncryptUtil.hmacSign(accessSecret, stringToSign);

    return Uri.encodeFull(signed).replaceAll("+", "%2B");
  }

  /// see https://help.aliyun.com/zh/oss/developer-reference/include-signatures-in-the-authorization-header
  /// sign the string use hmac
  String _makeSignatureV1(HttpRequest req, String bucket, String fileKey) {
    req.headers['x-oss-date'] = DateTime.now().toGMTString();
    req.headers['x-oss-security-token'] = secureToken;

    final String contentMd5 = req.headers['content-md5'] ?? '';
    final String contentType = req.headers['content-type'] ?? '';
    final String date = req.headers['x-oss-date'] ?? '';
    final String headerString = _getHeaderString(req);
    final String resourceString =
        _getResourceString(bucket, fileKey, req.param);
    final String stringToSign = [
      req.method,
      contentMd5,
      contentType,
      date,
      headerString,
      resourceString
    ].join("\n");

    final signature = EncryptUtil.hmacSign(accessSecret, stringToSign);

    return "OSS $accessKey:$signature";
  }

  /// sign the header information
  String _getHeaderString(HttpRequest req) {
    final List<String> ossHeaders = req.headers.keys
        .where((key) => key.toLowerCase().startsWith('x-oss-'))
        .toList();
    if (ossHeaders.isEmpty) return '';
    ossHeaders.sort((s1, s2) => s1.compareTo(s2));

    return ossHeaders.map((key) => "$key:${req.headers[key]}").join("\n");
  }

  /// sign the resource part information
  String _getResourceString(
    String bucket,
    String fileKey,
    Map<String, dynamic> param,
  ) {
    String path = "/";
    if (bucket.isNotEmpty) path += "$bucket/";
    if (fileKey.isNotEmpty) path += fileKey;
    final String signedParamString = param.keys
        .where((key) => SignParameters.signedParams.contains(key))
        .map((item) => "$item=${param[item]}")
        .join("&");
    if (signedParamString.isNotEmpty) {
      path += "?$signedParamString";
    }

    return path;
  }

  /// see https://help.aliyun.com/zh/oss/developer-reference/recommend-to-use-signature-version-4
  String _makeSignatureV4(HttpRequest req, String bucket, String fileKey) {
    final region = this.region;
    if (region == null) {
      throw ArgumentError("v4 signature Auth must have region");
    }

    // final now = DateTime.now().toUtc();
    // final signDateIso8601 = now.toOssIso8601String();
    // final signDate = now.yyyyMMdd();
    final signDateIso8601 = '20250411T064124Z';
    final signDate = '20250411';
    const hashedPayLoad = 'UNSIGNED-PAYLOAD';

    req.headers['x-oss-content-sha256'] = hashedPayLoad;
    req.headers['x-oss-date'] = signDateIso8601;
    if (secureToken.isNotEmpty) {
      req.headers['x-oss-security-token'] = secureToken;
    }

    final scope = '$signDate/$region/oss/aliyun_v4_request';

    final additionalHeaders = (req.headers.keys
            .where((header) =>
                !header.startsWith('x-oss-') &&
                header != 'content-type' &&
                header != 'content-md5')
            .map((header) => header.toLowerCase())
            .toList()
          ..sort())
        .join(';');

    String path = '/';
    if (bucket.isNotEmpty) path += '$bucket/';
    if (fileKey.isNotEmpty) path += Uri.decodeComponent(fileKey);

    final canonicalUri = path;

    final canonicalQuery = (req.param.entries
            .map((entry) =>
                '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
            .toList()
          ..sort())
        .join('&');

    final canonicalHeaders = (req.headers.entries
            .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
            .toList()
          ..sort())
        .join('\n');

    final httpVerb = req.method.toUpperCase();
    final canonicalRequest = EncryptUtil.sign256Hex(
        '$httpVerb\n$canonicalUri\n$canonicalQuery\n$canonicalHeaders\n\n$additionalHeaders\n$hashedPayLoad');

    const hashAlgorithm = 'OSS4-HMAC-SHA256';

    final stringToSign =
        '$hashAlgorithm\n$signDateIso8601\n$scope\n$canonicalRequest';

    final v4Sk = utf8.encode('aliyun_v4$accessSecret');
    final dateKey = EncryptUtil.hmacSign256Raw(v4Sk, signDate);
    final dateRegionKey = EncryptUtil.hmacSign256Raw(dateKey, region);
    final dateRegionOssKey = EncryptUtil.hmacSign256Raw(dateRegionKey, 'oss');
    final signingKey =
        EncryptUtil.hmacSign256Raw(dateRegionOssKey, 'aliyun_v4_request');

    final signature =
        hex.encode(EncryptUtil.hmacSign256Raw(signingKey, stringToSign));

    final credential = '$accessKey/$scope';

    return "$hashAlgorithm Credential=$credential, AdditionalHeaders=$additionalHeaders, Signature=$signature";
  }
}
