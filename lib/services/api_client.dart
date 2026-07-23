import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

/// Dilempar saat sebuah request gagal — baik karena error jaringan maupun
/// karena backend mengembalikan `success: false` / status non-2xx.
/// [message] sudah dalam bahasa yang siap ditampilkan ke pengguna.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Hasil terurai dari respons backend berformat standar:
/// `{ "success": true, "data": ..., "pagination": {...} }`.
class ApiResponse {
  /// Isi field `data` (bisa Map, List, atau null).
  final dynamic data;

  /// Field `pagination` bila endpoint mengembalikan daftar berhalaman.
  final Map<String, dynamic>? pagination;

  const ApiResponse({this.data, this.pagination});

  /// Akses `data` sebagai objek tunggal.
  Map<String, dynamic> get asMap =>
      data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};

  /// Akses `data` sebagai daftar objek.
  List<Map<String, dynamic>> get asList => data is List
      ? (data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];
}

/// Klien HTTP tunggal untuk seluruh aplikasi.
///
/// - Menyisipkan header `Authorization: Bearer <token>` otomatis (token dari
///   [SessionService]) kecuali `auth: false`.
/// - Mem-parsing amplop respons standar backend menjadi [ApiResponse].
/// - Menerjemahkan error jaringan menjadi [ApiException] berbahasa manusia.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await SessionService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    Map<String, String>? qp;
    if (query != null && query.isNotEmpty) {
      qp = <String, String>{};
      query.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          qp![key] = value.toString();
        }
      });
      if (qp.isEmpty) qp = null;
    }
    return Uri.parse('${ApiConfig.baseUrl}$normalized').replace(queryParameters: qp);
  }

  Future<ApiResponse> get(String path,
          {Map<String, dynamic>? query, bool auth = true}) =>
      _send(() async =>
          http.get(_uri(path, query), headers: await _headers(auth: auth)));

  Future<ApiResponse> post(String path, {Object? body, bool auth = true}) =>
      _send(() async => http.post(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<ApiResponse> put(String path, {Object? body, bool auth = true}) =>
      _send(() async => http.put(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<ApiResponse> patch(String path, {Object? body, bool auth = true}) =>
      _send(() async => http.patch(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<ApiResponse> delete(String path, {Object? body, bool auth = true}) =>
      _send(() async => http.delete(_uri(path),
          headers: await _headers(auth: auth), body: jsonEncode(body ?? {})));

  Future<ApiResponse> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(ApiConfig.timeout);
    } on SocketException {
      throw ApiException(
          'Tidak dapat terhubung ke server. Pastikan HP dan komputer berada di jaringan WiFi yang sama.');
    } on TimeoutException {
      throw ApiException('Koneksi ke server timeout. Coba lagi.');
    } on http.ClientException catch (e) {
      throw ApiException('Gangguan jaringan: ${e.message}');
    } catch (e) {
      throw ApiException('Terjadi kesalahan jaringan.');
    }

    dynamic decoded;
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = null;
      }
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;

    if (ok && !(decoded is Map && decoded['success'] == false)) {
      if (decoded is Map) {
        return ApiResponse(
          data: decoded.containsKey('data') ? decoded['data'] : decoded,
          pagination: decoded['pagination'] is Map
              ? Map<String, dynamic>.from(decoded['pagination'] as Map)
              : null,
        );
      }
      return ApiResponse(data: decoded);
    }

    throw ApiException(
      _errorMessage(decoded, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  String _errorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map) {
      final msg = decoded['error'] ?? decoded['message'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    }
    if (statusCode == 401) return 'Sesi berakhir. Silakan login kembali.';
    if (statusCode == 403) return 'Anda tidak berwenang mengakses data ini.';
    if (statusCode == 404) return 'Data tidak ditemukan.';
    if (statusCode >= 500) return 'Server sedang bermasalah. Coba lagi nanti.';
    return 'Permintaan gagal (kode $statusCode).';
  }
}
