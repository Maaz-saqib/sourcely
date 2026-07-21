/// Spaces Provider for Sourcely — manages Knowledge Spaces state.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/knowledge_space.dart';
import '../models/source.dart';
import '../services/api_service.dart';

class SpacesProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<KnowledgeSpace> _spaces = [];
  List<Source> _currentSources = [];
  KnowledgeSpace? _currentSpace;
  bool _isLoading = false;
  String? _errorMessage;

  SpacesProvider(this._apiService);

  List<KnowledgeSpace> get spaces => _spaces;
  List<Source> get currentSources => _currentSources;
  KnowledgeSpace? get currentSpace => _currentSpace;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all knowledge spaces
  Future<void> loadSpaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _spaces = await _apiService.listKnowledgeSpaces();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load knowledge spaces';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new knowledge space
  Future<KnowledgeSpace?> createSpace(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final space = await _apiService.createKnowledgeSpace(name);
      _spaces.insert(0, space);
      _isLoading = false;
      notifyListeners();
      return space;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to create knowledge space';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Delete a knowledge space
  Future<bool> deleteSpace(String id) async {
    try {
      await _apiService.deleteKnowledgeSpace(id);
      _spaces.removeWhere((s) => s.id == id);
      if (_currentSpace?.id == id) {
        _currentSpace = null;
        _currentSources = [];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete knowledge space';
      notifyListeners();
      return false;
    }
  }

  /// Load a specific space with its sources
  Future<void> loadSpaceDetail(String spaceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiService.getKnowledgeSpace(spaceId);

      _currentSpace = KnowledgeSpace.fromJson(data);
      _currentSources = (data['sources'] as List<dynamic>?)
              ?.map((e) => Source.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load knowledge space';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a link source (YouTube/URL) to the current space
  Future<Source?> addLinkSource({
    required String sourceType,
    required String sourceUrl,
    String? originalName,
  }) async {
    if (_currentSpace == null) return null;

    try {
      final source = await _apiService.addLinkSource(
        knowledgeSpaceId: _currentSpace!.id,
        sourceType: sourceType,
        sourceUrl: sourceUrl,
        originalName: originalName,
      );
      _currentSources.insert(0, source);
      _updateSourceCount(1);
      notifyListeners();
      return source;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to add source';
      notifyListeners();
      return null;
    }
  }

  /// Upload a file source to the current space
  Future<Source?> uploadFileSource({
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    if (_currentSpace == null) return null;

    try {
      final source = await _apiService.uploadFileSource(
        knowledgeSpaceId: _currentSpace!.id,
        fileName: fileName,
        fileBytes: fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes),
        mimeType: mimeType,
      );
      _currentSources.insert(0, source);
      _updateSourceCount(1);
      notifyListeners();
      return source;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to upload file';
      notifyListeners();
      return null;
    }
  }

  /// Refresh the status of a processing source
  Future<void> refreshSourceStatus(String sourceId) async {
    try {
      final updated = await _apiService.getSourceStatus(sourceId);
      final index = _currentSources.indexWhere((s) => s.id == sourceId);
      if (index >= 0) {
        final existing = _currentSources[index];
        _currentSources[index] = Source(
          id: existing.id,
          knowledgeSpaceId: existing.knowledgeSpaceId,
          type: existing.type,
          originalName: existing.originalName,
          sourceUrl: existing.sourceUrl,
          status: updated.status,
          errorMessage: updated.errorMessage,
          chunkCount: updated.chunkCount,
          createdAt: existing.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {
      // Silently fail — polling will retry
    }
  }

  Future<void> deleteSource(String sourceId) async {
    try {
      await _apiService.deleteSource(sourceId);
      _currentSources.removeWhere((s) => s.id == sourceId);
      _updateSourceCount(-1);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete source';
      notifyListeners();
    }
  }

  void _updateSourceCount(int delta) {
    if (_currentSpace != null) {
      final newCount = (_currentSpace!.sourceCount + delta).clamp(0, 9999);
      _currentSpace = _currentSpace!.copyWith(sourceCount: newCount);
      
      final index = _spaces.indexWhere((s) => s.id == _currentSpace!.id);
      if (index >= 0) {
        _spaces[index] = _currentSpace!;
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
