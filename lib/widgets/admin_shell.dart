import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:social_media_admin/responsive/responsive_layout.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/widgets/network_status_banner.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return NetworkStatusBanner(
      child: ResponsiveLayout(
        mobileBody: _buildMobileWarning(),
        desktopBody: _buildDesktopLayout(),
        tabletBody: _buildTabletLayout(),
      ),
    );
  }

  // Mobile Warning (<600px)
  Widget _buildMobileWarning() {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.desktop_windows_outlined,
                size: 80,
                color: appPrimaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Trang quản trị không hỗ trợ thiết bị di động.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vui lòng truy cập trang quản trị từ máy tính để có trải nghiệm tốt nhất.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: secondaryColor),
              ),
              const SizedBox(height: 32),
              Text(
                'Yêu cầu độ phân giải tối thiểu: 600px',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Desktop layout ( >900px )
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(isCollapsible: false, width: 250),
          // Main Content
          Expanded(
            child: Container(color: webBackgroundColor, child: widget.child),
          ),
        ],
      ),
    );
  }

  // Tablet layout (600-900px)
  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Collapsible Sidebar - INCREASED from 70 to 80px
          _buildSidebar(
            isCollapsible: true,
            width: _isSidebarCollapsed ? 80 : 200,
          ),
          // Main Content
          Expanded(
            child: Container(color: webBackgroundColor, child: widget.child),
          ),
        ],
      ),
    );
  }

  // Sidebar Widget
  Widget _buildSidebar({required bool isCollapsible, required double width}) {
    final isActuallyCollapsed = isCollapsible && _isSidebarCollapsed;

    return AnimatedContainer(
      // Add key to force rebuild when collapse state changes
      key: ValueKey(isActuallyCollapsed),
      duration: const Duration(milliseconds: 300),
      width: width,
      color: webBackgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            child: isActuallyCollapsed
                ? Center(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isSidebarCollapsed = false;
                        });
                      },
                      icon: Icon(
                        Icons.menu_open_outlined,
                        color: appPrimaryColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SvgPicture.asset(
                          'assets/images/trevie.svg',
                          height: 64,
                        ),
                      ),
                      if (isCollapsible)
                        IconButton(
                          icon: Icon(Icons.menu, color: appPrimaryColor),
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = true;
                            });
                          },
                        ),
                    ],
                  ),
          ),
          Divider(color: secondaryColor, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: 'Bảng Điều Khiển',
                  route: '/dashboard',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.people,
                  title: 'Người Dùng',
                  route: '/users',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.article_outlined,
                  title: 'Bài Viết',
                  route: '/posts',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.comment,
                  title: 'Bình luận',
                  route: '/comments',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.report,
                  title: 'Báo Cáo',
                  route: '/reports',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.report,
                  title: 'Vi phạm',
                  route: '/violations',
                  isCollapsed: isActuallyCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.settings,
                  title: 'Cài đặt',
                  route: '/settings',
                  isCollapsed: isActuallyCollapsed,
                ),
              ],
            ),
          ),
          Divider(color: secondaryColor, height: 1),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Đăng Xuất',
            route: '/logout',
            isCollapsed: isActuallyCollapsed,
            isLogout: true,
          ),
        ],
      ),
    );
  }

  // Menu Item Widget
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String route,
    required bool isCollapsed,
    bool isLogout = false,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isSelected = currentRoute == route;

    return Tooltip(
      message: isCollapsed ? title : '',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? appPrimaryColor : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isCollapsed
            ? InkWell(
                onTap: () => context.go(route),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: isSelected ? onPrimaryColor : secondaryColor,
                  ),
                ),
              )
            : ListTile(
                leading: Icon(
                  icon,
                  color: isSelected ? onPrimaryColor : secondaryColor,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? onPrimaryColor : secondaryColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () => context.go(route),
              ),
      ),
    );
  }
}
