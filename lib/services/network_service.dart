import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Stream controller for network status
  final _networkStatusController = StreamController<bool>.broadcast();
  
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  
  NetworkService() {
    _initConnectivity();
  }

  // Initialize connectivity monitoring
  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  // Check initial connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = 
          await _connectivity.checkConnectivity();
      return _isConnected(results);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  // Update connection status based on connectivity results
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isConnected = _isConnected(results);
    _networkStatusController.add(isConnected);
  }

  // Helper to determine if device is connected
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}