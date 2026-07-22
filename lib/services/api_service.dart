/// API service for Sourcely — HTTP client for the FastAPI backend.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'dart:io';
import 'dart:async';


import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/constants.dart';
import '../models/knowledge_space.dart';
import '../models/source.dart';
import '../models/message.dart';
import '../models/conversation.dart';

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
        if (body['error'] != null && body['error']['message'] != null) {
          message = body['error']['message'];
        } else {
          message = body['detail'] ?? 'Request failed';
        }
      } catch (_) {
        message = 'Request failed with status ${response.statusCode}';
      }
      throw ApiException(message, response.statusCode);
    }
  }

  Future<http.Response> _execute(Future<http.Response> Function() requestFunc) async {
    try {
      final response = await requestFunc().timeout(const Duration(seconds: 60));
      _handleError(response);
      return response;
    } on SocketException catch (_) {
      throw ApiException('Network error: Please check your internet connection.', 0);
    } on TimeoutException catch (_) {
      throw ApiException('Request timed out. Please try again.', 408);
    } on http.ClientException catch (e) {
      throw ApiException('Client error: ${e.message}', 0);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e', 0);
    }
  }

  // ─── Knowledge Spaces ───────────────────────────────────────

  /// Create a new knowledge space
  Future<KnowledgeSpace> createKnowledgeSpace(String name) async {
    final response = await _execute(() => http.post(
      Uri.parse('$baseUrl/knowledge-spaces'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    ));
    return KnowledgeSpace.fromJson(jsonDecode(response.body));
  }

  /// List all knowledge spaces
  Future<List<KnowledgeSpace>> listKnowledgeSpaces() async {
    final response = await _execute(() => http.get(
      Uri.parse('$baseUrl/knowledge-spaces'),
      headers: _headers,
    ));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => KnowledgeSpace.fromJson(e)).toList();
  }

  /// Get a knowledge space with its sources
  Future<Map<String, dynamic>> getKnowledgeSpace(String id) async {
    final response = await _execute(() => http.get(
      Uri.parse('$baseUrl/knowledge-spaces/$id'),
      headers: _headers,
    ));
    return jsonDecode(response.body);
  }

  Future<void> deleteKnowledgeSpace(String id) async {
    await _execute(() => http.delete(
      Uri.parse('$baseUrl/knowledge-spaces/$id'),
      headers: _headers,
    ));
  }

  // ─── Sources ────────────────────────────────────────────────

  /// Add a link source (YouTube or URL)
  Future<Source> addLinkSource({
    required String knowledgeSpaceId,
    required String sourceType,
    required String sourceUrl,
    String? originalName,
  }) async {
    final response = await _execute(() => http.post(
      Uri.parse('$baseUrl/sources'),
      headers: _headers,
      body: jsonEncode({
        'knowledge_space_id': knowledgeSpaceId,
        'source_type': sourceType,
        'source_url': sourceUrl,
        'original_name': originalName,
      }),
    ));
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
    final response = await _execute(() => http.get(
      Uri.parse('$baseUrl/sources/$sourceId/status'),
      headers: _headers,
    ));
    final data = jsonDecode(response.body);
    // The status endpoint returns a partial source, fill in missing fields
    return Source(
      id: data['id'],
      knowledgeSpaceId: '',
      type: '',
      status: data['status'],
      errorMessage: data['error_message'],
      chunkCount: data['chunkCount'],
      createdAt: '',
    );
  }
  Future<void> deleteSource(String sourceId) async {
    await _execute(() => http.delete(
      Uri.parse('$baseUrl/sources/$sourceId'),
      headers: _headers,
    ));
  }

  // ─── Conversations ───────────────────────────────────────────

  /// Create a new conversation
  Future<Conversation> createConversation(String spaceId, {String name = "New Conversation"}) async {
    final response = await _execute(() => http.post(
      Uri.parse('$baseUrl/knowledge-spaces/$spaceId/conversations'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    ));
    return Conversation.fromJson(jsonDecode(response.body));
  }

  /// List conversations for a space
  Future<List<Conversation>> listConversations(String spaceId) async {
    final response = await _execute(() => http.get(
      Uri.parse('$baseUrl/knowledge-spaces/$spaceId/conversations'),
      headers: _headers,
    ));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Conversation.fromJson(e)).toList();
  }

  /// Update conversation name
  Future<Conversation> updateConversation(String conversationId, String name) async {
    final response = await _execute(() => http.patch(
      Uri.parse('$baseUrl/conversations/$conversationId'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    ));
    return Conversation.fromJson(jsonDecode(response.body));
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await _execute(() => http.delete(
      Uri.parse('$baseUrl/conversations/$conversationId'),
      headers: _headers,
    ));
  }

  // ─── Chat ───────────────────────────────────────────────────

  /// Send a chat message to the agent
  Future<Map<String, dynamic>> sendChatMessage({
    required String conversationId,
    required String message,
    List<String>? mentionedSourceIds,
  }) async {
    final response = await _execute(() => http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/chat'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        if (mentionedSourceIds != null) 'mentioned_source_ids': mentionedSourceIds,
      }),
    ));
    return jsonDecode(response.body);
  }

  /// Get chat history for a conversation
  Future<List<Message>> getChatHistory(String conversationId) async {
    final response = await _execute(() => http.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: _headers,
    ));
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Message.fromJson(e)).toList();
  }

  /// Export a message as a PDF
  Future<String> exportMessagePdf(String messageId) async {
    final response = await _execute(() => http.post(
      Uri.parse('$baseUrl/messages/$messageId/export-pdf'),
      headers: _headers,
    ));
    return jsonDecode(response.body)['url'] as String;
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
