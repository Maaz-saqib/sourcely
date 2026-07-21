/// Chat Provider for Sourcely — manages chat state and messages.
library;



import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Message> _messages = [];
  String? _conversationId;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  String? _currentSpaceId;

  ChatProvider(this._apiService);

  List<Message> get messages => _messages;
  String? get conversationId => _conversationId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  /// Load chat history for a knowledge space
  Future<void> loadChatHistory(String spaceId) async {
    _currentSpaceId = spaceId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messages = await _apiService.getChatHistory(spaceId);
      if (_messages.isNotEmpty) {
        _conversationId = _messages.first.conversationId;
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load chat history';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a message to the agent
  Future<bool> sendMessage(String message) async {
    if (_currentSpaceId == null) return false;

    _isSending = true;
    _errorMessage = null;

    // Add optimistic user message
    final tempUserMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId ?? '',
      role: 'user',
      content: message,
      createdAt: DateTime.now().toIso8601String(),
    );
    _messages.add(tempUserMsg);
    notifyListeners();

    try {
      final response = await _apiService.sendChatMessage(
        knowledgeSpaceId: _currentSpaceId!,
        message: message,
        conversationId: _conversationId,
      );

      _conversationId = response['conversation_id'] as String?;

      // Build assistant message
      final assistantMsg = Message(
        id: response['message_id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _conversationId ?? '',
        role: 'assistant',
        content: response['answer'] as String,
        citations: (response['citations'] as List<dynamic>?)
            ?.map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList(),
        toolsUsed: (response['tools_used'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        createdAt: DateTime.now().toIso8601String(),
      );

      _messages.add(assistantMsg);
      _isSending = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // Remove optimistic message on failure
      _messages.removeLast();
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send message';
      _messages.removeLast();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear chat history (for switching spaces)
  void clearChat() {
    _messages = [];
    _conversationId = null;
    _currentSpaceId = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
