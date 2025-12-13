import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/user.dart' as model;
import 'package:social_media_admin/services/admin_auth_service.dart';
import 'package:social_media_admin/services/user_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/user/add_user_dialog.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/services/admin_management_service.dart';
import 'package:social_media_admin/widgets/user/delete_user_dialog.dart';
import 'package:social_media_admin/widgets/user/suspend_user_dialog.dart';
import 'package:social_media_admin/widgets/user/update_user_dialog.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final AdminAuthService _adminAuthService = AdminAuthService(); // Add this
  bool _showDeletedUsers = false;

  List<model.User> _users = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _totalUsers = 0;
  int _totalDeletedUsers = 0;

  // Filters
  UserStatus _selectedStatus = UserStatus.all;
  DateTime? _startDate;
  DateTime? _endDate;
  UserSortField _sortBy = UserSortField.createdAt;
  bool _ascending = false;
  String _searchQuery = '';

  bool _isSuperAdmin = false;
  final AdminManagementService _adminService = AdminManagementService();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadTotalCount();
    _loadTotalDeletedUsersCount();
    _checkPermissionBtn();
  }

  Future<void> _checkPermissionBtn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      final status = await _adminService.checkAdminStatus(user!.email!);
      setState(() {
        // Chỉ Super Admin mới được thấy nút tạo user
        _isSuperAdmin = status['isSuperAdmin'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddUserDialog() async {
    // First, refresh the token to ensure we have the latest claims
    await _adminAuthService.refreshUserToken();

    // Check if user is super admin
    final isSuperAdmin = await _adminAuthService.isSuperAdmin();

    if (!isSuperAdmin) {
      if (!mounted) return;
      displaySnackBar(
        'Chỉ Super Admin mới có thể tạo người dùng mới',
        context,
        SnackBarType.error,
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddUserDialog(
        onUserCreated: () {
          // Callback when user is successfully created
          _loadUsers(refresh: true);
          _loadTotalCount();
        },
      ),
    );
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _users = [];
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      final result = _showDeletedUsers
          ? await _userService.getDeletedUsers(
              limit: 20,
              lastDocument: refresh ? null : _lastDocument,
            )
          : await _userService.getUsers(
              limit: 20,
              lastDocument: refresh ? null : _lastDocument,
              searchQuery: _searchQuery,
              status: _selectedStatus,
              startDate: _startDate,
              endDate: _endDate,
              sortBy: _sortBy,
              ascending: _ascending,
              includeDeleted: false, // Explicitly exclude deleted users
            );

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _users = result['users'];
        } else {
          _users.addAll(result['users']);
        }
        _lastDocument = result['lastDocument'];
        _hasMore = result['hasMore'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      displaySnackBar(
        'Lỗi khi tải người dùng: $e',
        context,
        SnackBarType.error,
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadUsers();

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _loadTotalCount() async {
    final count = await _userService.getTotalUsersCount();
    if (mounted) {
      setState(() {
        _totalUsers = count;
      });
    }
  }

  Future<void> _loadTotalDeletedUsersCount() async {
    final count = await _userService.getTotalDeletedUsersCount();
    if (mounted) {
      setState(() {
        _totalDeletedUsers = count;
      });
    }
  }

  void _applyFilters() {
    _loadUsers(refresh: true);
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = UserStatus.all;
      _startDate = null;
      _endDate = null;
      _sortBy = UserSortField.createdAt;
      _ascending = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadUsers(refresh: true);
  }

  Future<void> _toggleSuspension(model.User user) async {
    // Show suspension dialog
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          SuspendUserDialog(user: user, isCurrentlySuspended: user.isSuspended),
    );

    // User cancelled
    if (reason == null || !mounted) return;

    // Empty string means activating (no reason needed)
    final shouldSuspend = !user.isSuspended;
    final finalReason = shouldSuspend ? reason : '';

    final result = await _userService.toggleUserSuspension(
      user.uid,
      !user.isSuspended,
      finalReason,
    );

    if (!mounted) return;

    if (result == 'success') {
      displaySnackBar(
        shouldSuspend ? 'Đã đình chỉ người dùng' : 'Đã kích hoạt người dùng',
        context,
        SnackBarType.success,
      );
      _loadUsers(refresh: true);
    } else {
      displaySnackBar(
        'Lỗi khi thay đổi trạng thái người dùng: $result',
        context,
        SnackBarType.error,
      );
    }
  }

  Future<void> _deleteUser(model.User user) async {
    // Show confirmation dialog
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteUserDialog(user: user),
    );

    // User cancelled
    if (reason == null || !mounted) return;

    final result = await _userService.deleteUser(user.uid, reason);

    if (!mounted) return;

    if (result == 'success') {
      displaySnackBar('Đã xóa người dùng', context, SnackBarType.success);
      _loadUsers(refresh: true);
      _loadTotalCount();
      _loadTotalDeletedUsersCount();
    } else {
      displaySnackBar(result, context, SnackBarType.error);
    }
  }

  // Restore method
  Future<void> _restoreUser(model.User user) async {
    final result = await _userService.restoreUser(user.uid);

    if (!mounted) return;

    if (result == 'success') {
      displaySnackBar('Đã khôi phục người dùng', context, SnackBarType.success);
      _loadUsers(refresh: true);
      _loadTotalCount();
      _loadTotalDeletedUsersCount();
    } else {
      displaySnackBar(result, context, SnackBarType.error);
    }
  }

  // Add permanent delete method
  Future<void> _permanentlyDeleteUser(model.User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: webBackgroundColor,
        title: const Text(
          'Xác nhận xóa vĩnh viễn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: errorBackgroundColor,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa VĨNH VIỄN người dùng "${user.displayName}"?\n\n'
          'Hành động này KHÔNG THỂ HOÀN TÁC!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: errorBackgroundColor,
              backgroundColor: errorBackgroundColor.withValues(alpha: 0.1),
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await _userService.permanentlyDeleteUser(user.uid);

    if (!mounted) return;

    if (result == 'success') {
      displaySnackBar(
        'Đã xóa vĩnh viễn người dùng',
        context,
        SnackBarType.success,
      );
      _loadUsers(refresh: true);
      _loadTotalCount();
      _loadTotalDeletedUsersCount();
    } else {
      displaySnackBar(result, context, SnackBarType.error);
    }
  }

  Future<void> _showUpdateUserDialog(model.User user) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateUserDialog(
        user: user,
        onUserUpdated: () {
          _loadUsers(refresh: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text(
          _showDeletedUsers
              ? 'Thùng rác ($_totalDeletedUsers)'
              : 'Quản lí người dùng ($_totalUsers)',
        ),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
        actions: [
          // Add a refresh token button for debugging
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _adminAuthService.refreshUserToken();

              if (context.mounted) {
                displaySnackBar(
                  'Đã làm mới phiên đăng nhập',
                  context,
                  SnackBarType.success,
                );
              }
            },
            tooltip: 'Làm mới phiên đăng nhập',
          ),
          // Add a Create new User Button (only show when not in trash view)
          if (!_showDeletedUsers && _isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddUserDialog,
              tooltip: 'Thêm người dùng mới',
            ),
          IconButton(
            icon: Icon(
              _showDeletedUsers ? Icons.people : Icons.delete_forever_outlined,
            ),
            onPressed: () {
              setState(() {
                _showDeletedUsers = !_showDeletedUsers;
              });
              _loadUsers(refresh: true);
            },
            tooltip: _showDeletedUsers
                ? 'Hiển thị người dùng hoạt động'
                : 'Hiển thị thùng rác',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsers(refresh: true);
              _loadTotalCount();
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          _buildFiltersSection(),

          // Data Table
          Expanded(
            child: _isLoading && _users.isEmpty
                ? Center(child: customCircularProgressIndicator())
                : _users.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy người dùng',
                      style: TextStyle(fontSize: 16, color: secondaryColor),
                    ),
                  )
                : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm theo tên hoặc email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12.0),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.search),
                label: const Text('Tìm kiếm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimaryColor,
                  foregroundColor: onPrimaryColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 20.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16.0, height: 16.0),

          // Filters Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              // Status Filter
              DropdownButton<UserStatus>(
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(
                    value: UserStatus.all,
                    child: Text('Tất cả trạng thái'),
                  ),
                  DropdownMenuItem(
                    value: UserStatus.active,
                    child: Text('Đang hoạt động'),
                  ),
                  DropdownMenuItem(
                    value: UserStatus.suspended,
                    child: Text('Đã bị đình chỉ'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _applyFilters();
                  }
                },
                hint: const Text('Trạng thái'),
              ),

              // Sort By Filter
              DropdownButton<UserSortField>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(
                    value: UserSortField.createdAt,
                    child: Text('Sắp xếp: Ngày tạo'),
                  ),
                  DropdownMenuItem(
                    value: UserSortField.displayName,
                    child: Text('Sắp xếp: Tên hiển thị'),
                  ),
                  DropdownMenuItem(
                    value: UserSortField.followers,
                    child: Text('Sắp xếp: Người theo dõi'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                    _applyFilters();
                  }
                },
                hint: const Text('Sắp xếp theo'),
              ),

              // Sort Order
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: secondaryColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: IconButton(
                  icon: Icon(
                    _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () {
                    setState(() {
                      _ascending = !_ascending;
                    });
                    _applyFilters();
                  },
                  tooltip: _ascending ? 'Tăng dần' : 'Giảm dần',
                ),
              ),

              // Reset Filters
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Xoá bộ lọc'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 900,
        dataRowHeight: 56, // Increase row height
        headingRowHeight: 56,
        columns: [
          const DataColumn2(
            label: Text(
              'Ảnh đại diện',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          const DataColumn2(
            label: Text(
              'Tên hiển thị',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
          ),
          const DataColumn2(
            label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
            size: ColumnSize.L,
          ),
          const DataColumn2(
            label: Text(
              'Ngày đăng ký',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
          ),
          // Add "Ngày xóa" column only when showing deleted users
          if (_showDeletedUsers)
            const DataColumn2(
              label: Text(
                'Ngày xóa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
            ),
          // Followers/Following or Reason column
          if (!_showDeletedUsers)
            const DataColumn2(
              label: Text(
                'Người theo dõi / Đang theo dõi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
            )
          else
            const DataColumn2(
              label: Text(
                'Lý do xoá',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
            ),
          const DataColumn2(
            label: Text(
              'Trạng thái',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          // Add suspension reason column for active users
          if (!_showDeletedUsers)
            const DataColumn2(
              label: Text(
                'Lý do đình chỉ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
            ),
          const DataColumn2(
            label: Text(
              'Hành động',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
          ),
        ],
        rows: [
          ..._users.map((user) => _buildDataRow(user)),
          if (_hasMore)
            DataRow2(
              cells: [
                DataCell(
                  Center(
                    child: _isLoadingMore
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: customCircularProgressIndicator(),
                          )
                        : TextButton(
                            onPressed: _loadMore,
                            child: const Text('Tải thêm'),
                          ),
                  ),
                ),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                // Add extra cell for "Ngày xóa" column when showing deleted users
                if (_showDeletedUsers) const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
              ],
            ),
        ],
      ),
    );
  }

  DataRow2 _buildDataRow(model.User user) {
    return DataRow2(
      cells: [
        // Avatar
        DataCell(
          CircleAvatar(
            backgroundColor: appPrimaryColor.withValues(alpha: 0.2),
            backgroundImage: user.photoUrl.isNotEmpty
                ? NetworkImage(user.photoUrl)
                : null,
            radius: 20,
            child: user.photoUrl.isEmpty
                ? Icon(Icons.person, color: appPrimaryColor)
                : null,
          ),
        ),

        // Display Name
        DataCell(
          Text(
            user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),

        // Email
        DataCell(Text(user.email)),

        // Created At
        DataCell(Text(DateFormat('dd/MM/yyyy').format(user.createdAt))),

        // Deleted At (only in trash view)
        if (_showDeletedUsers)
          DataCell(
            Text(
              user.deletedAt != null
                  ? DateFormat('HH:mm dd/MM/yyyy').format(user.deletedAt!)
                  : 'N/A',
              style: TextStyle(fontSize: 13, color: secondaryColor),
            ),
          ),

        // Conditionally show Followers/Following OR Deletion Reason
        DataCell(
          _showDeletedUsers
              ? // Show deletion reason when in trash view
                (user.deletionReason != null && user.deletionReason!.isNotEmpty
                    ? Tooltip(
                        message: user.deletionReason!,
                        child: Text(
                          user.deletionReason!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: secondaryColor),
                        ),
                      )
                    : Text(
                        'Không có lý do',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ))
              : // Show followers/following when in normal view
                Text('${user.followers.length} / ${user.following.length}'),
        ),

        // Status
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: user.isDeleted
                  ? secondaryColor
                  : user.isSuspended
                  ? Colors.orange.withValues(alpha: 0.1)
                  : appPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                user.isDeleted
                    ? 'Đã bị xóa'
                    : user.isSuspended
                    ? 'Đã đình chỉ'
                    : 'Đang hoạt động',
                style: TextStyle(
                  color: user.isDeleted
                      ? onPrimaryColor
                      : user.isSuspended
                      ? Colors.orange
                      : appPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Suspension Reason (new dedicated column for active users)
        if (!_showDeletedUsers)
          DataCell(
            user.isSuspended &&
                    user.suspensionReason != null &&
                    user.suspensionReason!.isNotEmpty
                ? Tooltip(
                    message: user.suspensionReason!,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.suspensionReason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    '-',
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
          ),

        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: user.isDeleted
                ? [
                    //Restore button for deleted users
                    IconButton(
                      icon: const Icon(Icons.restore, size: 20),
                      tooltip: 'Khôi phục',
                      color: appPrimaryColor,
                      onPressed: () => _restoreUser(user),
                    ),
                    // Permanent delete button
                    IconButton(
                      icon: const Icon(Icons.delete_forever, size: 20),
                      tooltip: 'Xóa vĩnh viễn',
                      color: errorBackgroundColor,
                      onPressed: () => _permanentlyDeleteUser(user),
                    ),
                  ]
                : [
                    // View/Edit - UPDATE USER
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Chỉnh sửa',
                      color: infoBackgroundColor,
                      onPressed: () => _showUpdateUserDialog(user),
                    ),

                    // Suspend/Activate
                    IconButton(
                      icon: Icon(
                        user.isSuspended ? Icons.check_circle : Icons.block,
                        size: 20,
                      ),
                      onPressed: () => _toggleSuspension(user),
                      tooltip: user.isSuspended ? 'Kích hoạt' : 'Đình chỉ',
                      color: user.isSuspended ? appPrimaryColor : Colors.orange,
                    ),

                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteUser(user),
                      tooltip: 'Xóa',
                      color: errorBackgroundColor,
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}
