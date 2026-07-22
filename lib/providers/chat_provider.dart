/// Chat Provider for Sourcely — manages conversations and chat state.
library;

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Conversation? _currentConversation;
  String? _currentSpaceId;
  
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  ChatProvider(this._apiService);

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  /// Load conversations for a knowledge space
  Future<void> loadConversations(String spaceId) async {
    _currentSpaceId = spaceId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _apiService.listConversations(spaceId);
      if (_conversations.isNotEmpty) {
        await loadConversation(_conversations.first);
      } else {
        _currentConversation = null;
        _messages = [];
        _isLoading = false;
        notifyListeners();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to load conversations';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load a specific conversation
  Future<void> loadConversation(Conversation conversation) async {
    if (_currentConversation?.id == conversation.id) return;

    // Cleanup current if empty
    if (_currentConversation != null && _messages.isEmpty && !_isSending && !_isLoading) {
      try {
        await _apiService.deleteConversation(_currentConversation!.id);
        _conversations.removeWhere((c) => c.id == _currentConversation!.id);
      } catch (_) {}
    }

    _currentConversation = conversation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messages = await _apiService.getChatHistory(conversation.id);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to load chat history';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Create a new conversation
  Future<void> createNewConversation() async {
    if (_currentSpaceId == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final newConvo = await _apiService.createConversation(_currentSpaceId!);
      _conversations.insert(0, newConvo);
      await loadConversation(newConvo);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to create conversation';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a conversation's name
  Future<bool> updateConversationName(String id, String newName) async {
    try {
      final updatedConvo = await _apiService.updateConversation(id, newName);
      final index = _conversations.indexWhere((c) => c.id == id);
      if (index >= 0) {
        _conversations[index] = updatedConvo;
        if (_currentConversation?.id == id) {
          _currentConversation = updatedConvo;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to rename conversation';
      notifyListeners();
      return false;
    }
  }

  /// Delete a conversation
  Future<bool> deleteConversation(String id) async {
    try {
      await _apiService.deleteConversation(id);
      _conversations.removeWhere((c) => c.id == id);
      
      if (_currentConversation?.id == id) {
        _currentConversation = null;
        _messages = [];
        if (_conversations.isNotEmpty) {
          await loadConversation(_conversations.first);
        }
      } else {
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to delete conversation';
      notifyListeners();
      return false;
    }
  }

  /// Send a message to the agent
  Future<bool> sendMessage(String message, {List<String>? mentionedSourceIds}) async {
    if (_currentSpaceId == null) return false;

    _isSending = true;
    _errorMessage = null;
    
    if (_currentConversation == null) {
      // Create a conversation if one doesn't exist
      try {
        final newConvo = await _apiService.createConversation(_currentSpaceId!, name: message.length > 30 ? '${message.substring(0, 30)}...' : message);
        _conversations.insert(0, newConvo);
        _currentConversation = newConvo;
      } catch (e) {
        _errorMessage = e is ApiException ? e.message : 'Failed to create conversation';
        _isSending = false;
        notifyListeners();
        return false;
      }
    }

    // Add optimistic user message
    final tempUserMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _currentConversation!.id,
      role: 'user',
      content: message,
      createdAt: DateTime.now().toIso8601String(),
    );
    _messages.add(tempUserMsg);
    notifyListeners();

    try {
      final response = await _apiService.sendChatMessage(
        conversationId: _currentConversation!.id,
        message: message,
        mentionedSourceIds: mentionedSourceIds,
      );

      // Build assistant message
      final assistantMsg = Message(
        id: response['message_id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _currentConversation!.id,
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
      _errorMessage = e is ApiException ? e.message : 'Failed to send message';
      _messages.removeLast();
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  /// Export conversation to PDF
  Future<String?> exportConversation(String messageId) async {
    try {
      final url = await _apiService.exportMessagePdf(messageId);
      return url;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Failed to export to PDF';
      notifyListeners();
      return null;
    }
  }

  /// Clear chat history (for switching spaces)
  void clearChat() {
    if (_currentConversation != null && _messages.isEmpty && !_isSending && !_isLoading) {
      _apiService.deleteConversation(_currentConversation!.id).catchError((_) {});
    }

    _messages = [];
    _conversations = [];
    _currentConversation = null;
    _currentSpaceId = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
