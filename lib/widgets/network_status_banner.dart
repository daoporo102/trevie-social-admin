import 'package:flutter/material.dart';
import 'package:social_media_admin/services/network_service.dart';
import 'package:social_media_admin/utils/colors.dart';

class NetworkStatusBanner extends StatefulWidget {
  final Widget child;

  const NetworkStatusBanner({super.key, required this.child});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  final NetworkService _networkService = NetworkService();
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenToNetworkChanges();
  }

  Future<void> _checkInitialConnectivity() async {
    final isConnected = await _networkService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _showBanner = !isConnected;
      });
    }
  }

  void _listenToNetworkChanges() {
    _networkService.networkStatusStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _showBanner = !isConnected;
        });

        // Auto-hide banner after 3 seconds when connection is restored
        if (isConnected) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showBanner = false;
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _isConnected ? appPrimaryColor : errorBackgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: onPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected
                        ? 'Kết nối Internet đã được khôi phục'
                        : 'Không có kết nối Internet',
                    style: const TextStyle(
                      color: onPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}