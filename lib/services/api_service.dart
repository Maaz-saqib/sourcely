/// API service for Sourcely — HTTP client for the FastAPI backend.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';
import '../models/knowledge_space.dart';
import '../models/source.dart';
import '../models/message.dart';

class ApiService {
  final String baseUrl;
  String? _accessToken;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  /// Set the access token for authenticated requests
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Common headers including auth token
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Handle response errors
  void _handleError(http.Response response) {
    if (response.statusCode >= 400) {
      String message;
      try {
        final body = jsonDecode(response.body);
        message = body['detail'] ?? 'Request failed';
      } catch (_) {
        message = 'Request failed with status ${response.statusCode}';
      }
      throw ApiException(message, response.statusCode);
    }
  }

  // ─── Knowledge Spaces ───────────────────────────────────────

  /// Create a new knowledge space
  Future<KnowledgeSpace> createKnowledgeSpace(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/knowledge-spaces'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _handleError(response);
    return KnowledgeSpace.fromJson(jsonDecode(response.body));
  }

  /// List all knowledge spaces
  Future<List<KnowledgeSpace>> listKnowledgeSpaces() async {
    final response = await http.get(
      Uri.parse('$baseUrl/knowledge-spaces'),
      headers: _headers,
    );
    _handleError(response);
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => KnowledgeSpace.fromJson(e)).toList();
  }

  /// Get a knowledge space with its sources
  Future<Map<String, dynamic>> getKnowledgeSpace(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/knowledge-spaces/$id'),
      headers: _headers,
    );
    _handleError(response);
    return jsonDecode(response.body);
  }

  /// Delete a knowledge space
  Future<void> deleteKnowledgeSpace(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/knowledge-spaces/$id'),
      headers: _headers,
    );
    _handleError(response);
  }

  // ─── Sources ────────────────────────────────────────────────

  /// Add a link source (YouTube or URL)
  Future<Source> addLinkSource({
    required String knowledgeSpaceId,
    required String sourceType,
    required String sourceUrl,
    String? originalName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sources'),
      headers: _headers,
      body: jsonEncode({
        'knowledge_space_id': knowledgeSpaceId,
        'source_type': sourceType,
        'source_url': sourceUrl,
        'original_name': originalName,
      }),
    );
    _handleError(response);
    return Source.fromJson(jsonDecode(response.body));
  }

  /// Upload a file source (PDF or DOCX)
  Future<Source> uploadFileSource({
    required String knowledgeSpaceId,
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/sources/upload'),
    );

    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.fields['knowledge_space_id'] = knowledgeSpaceId;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _handleError(response);
    return Source.fromJson(jsonDecode(response.body));
  }

  /// Poll source ingestion status
  Future<Source> getSourceStatus(String sourceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sources/$sourceId/status'),
      headers: _headers,
    );
    _handleError(response);
    final data = jsonDecode(response.body);
    // The status endpoint returns a partial source, fill in missing fields
    return Source(
      id: data['id'],
      knowledgeSpaceId: '',
      type: '',
      status: data['status'],
      errorMessage: data['error_message'],
      chunkCount: data['chunk_count'],
      summary: data['summary'],
      quiz: (data['quiz'] as List<dynamic>?)
          ?.map((e) => QuizItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: '',
    );
  }
  Future<void> deleteSource(String sourceId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sources/$sourceId'),
      headers: _headers,
    );
    _handleError(response);
  }

  // ─── Chat ───────────────────────────────────────────────────

  /// Send a chat message to the agent
  Future<Map<String, dynamic>> sendChatMessage({
    required String knowledgeSpaceId,
    required String message,
    String? conversationId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/knowledge-spaces/$knowledgeSpaceId/chat'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId, // ignore: use_null_aware_elements
      }),
    );
    _handleError(response);
    return jsonDecode(response.body);
  }

  /// Get chat history for a knowledge space
  Future<List<Message>> getChatHistory(String knowledgeSpaceId, {String? conversationId}) async {
    var url = '$baseUrl/knowledge-spaces/$knowledgeSpaceId/messages';
    if (conversationId != null) {
      url += '?conversation_id=$conversationId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );
    _handleError(response);
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Message.fromJson(e)).toList();
  }
}

/// Custom API exception
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
