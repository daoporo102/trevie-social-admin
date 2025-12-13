import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/services/post_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/post/approve_post_dialog.dart';
import 'package:social_media_admin/widgets/post/create_post_dialog.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';
import 'package:social_media_admin/widgets/post/delete_post_dialog.dart';
import 'package:social_media_admin/widgets/post/post_details_dialog.dart';
import 'package:social_media_admin/widgets/post/reject_post_dialog.dart';

class PostsListScreen extends StatefulWidget {
  const PostsListScreen({super.key});

  @override
  State<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends State<PostsListScreen> {
  final PostService _postService = PostService();
  final TextEditingController _searchController = TextEditingController();

  List<Post> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isDeletingPost =
      false; // add this state field near other booleans like _isLoading/_isLoadingMore
  int _totalPosts = 0;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  PostSortField _sortBy = PostSortField.datePublished;
  bool _ascending = false;
  String _searchQuery = '';

  // Add this new state variable
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadTotalCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _posts = [];
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      final result = await _postService.getPosts(
        limit: 20,
        lastDocument: refresh ? null : _lastDocument,
        searchQuery: _searchQuery,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
        ascending: _ascending,
        status: _selectedStatus,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _posts = result['posts'];
        } else {
          _posts.addAll(result['posts']);
        }
        _lastDocument = result['lastDocument'];
        _hasMore = result['hasMore'];
      });
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Lỗi khi tải danh sách bài viết',
        context,
        SnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadPosts();

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadTotalCount() async {
    final count = await _postService.getTotalPostsCount();
    if (mounted) {
      setState(() {
        _totalPosts = count;
      });
    }
  }

  void _applyFilters() {
    _loadPosts(refresh: true);
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _sortBy = PostSortField.datePublished;
      _ascending = false;
      _searchQuery = '';
      _selectedStatus = null; // Add this line
      _searchController.clear();
    });
    _loadPosts(refresh: true);
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DeletePostDialog(post: post),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isDeletingPost = true;
    });

    try {
      final result = await _postService.deletePost(post.postId);

      if (!mounted) return;

      if (result == 'success') {
        displaySnackBar(
          'Đã xóa bài viết thành công',
          context,
          SnackBarType.success,
        );
        // refresh list and counts
        _loadPosts(refresh: true);
        _loadTotalCount();
      } else {
        displaySnackBar(result, context, SnackBarType.error);
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(
          'Lỗi khi xóa bài viết: $e',
          context,
          SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingPost = false;
        });
      }
    }
  }

  Future<void> _showCreatePostDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreatePostDialog(
        onPostCreated: () {
          _loadPosts(refresh: true);
          _loadTotalCount();
        },
      ),
    );
  }

  Future<void> _openPostDetailDialog(Post post) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => Center(child: customCircularProgressIndicator()),
    );

    try {
      // Fetch fresh post details from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId)
          .get();

      // Close loading dialog
      closeLoading();

      // Small delay to ensure loading dialog is closed
      await Future.delayed(const Duration(milliseconds: 100));

      // Check mounted again after delay
      if (!mounted) return;

      // Check data & open details Dialog
      if (docSnapshot.exists && docSnapshot.data() != null) {
        await showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => PostDetailDialog(data: docSnapshot.data()!),
        );
      } else {
        displaySnackBar(
          'Bài viết không tồn tại hoặc đã bị xóa.',
          context,
          SnackBarType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close Loading Dialog if it is still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      avoidPrint('Error loading post details: $e');
      displaySnackBar(
        'Lỗi khi tải chi tiết bài viết: $e',
        context,
        SnackBarType.error,
      );
    }
  }

  void closeLoading() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text('Quản lý bài viết ($_totalPosts)'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
        // Add Create Post Button
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreatePostDialog,
            tooltip: 'Tạo bài viết mới',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPosts(refresh: true);
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
            child: _isLoading && _posts.isEmpty
                ? Center(child: customCircularProgressIndicator())
                : _posts.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy bài viết',
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
                    labelText: 'Tìm kiếm theo nội dung hoặc tên người đăng...',
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
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Filters Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              // Status Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả trạng thái'),
                    ),
                    DropdownMenuItem(value: 'active', child: Text('Đã duyệt')),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Bị từ chối'),
                    ),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('Đang xử lý'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),

              // Sort By
              DropdownButton<PostSortField>(
                value: _sortBy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                    _applyFilters();
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: PostSortField.datePublished,
                    child: Text('Ngày đăng'),
                  ),
                  DropdownMenuItem(
                    value: PostSortField.dateUpdated,
                    child: Text('Ngày chỉnh sửa'),
                  ),
                  DropdownMenuItem(
                    value: PostSortField.likes,
                    child: Text('Lượt thích'),
                  ),
                  DropdownMenuItem(
                    value: PostSortField.reshareCount,
                    child: Text('Lượt chia sẻ'),
                  ),
                ],
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
        minWidth: 1200, // Increased width to accommodate new columns
        dataRowHeight: 80,
        headingRowHeight: 56,
        columns: const [
          DataColumn2(
            label: Text(
              'Uid bài đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text(
              'Người đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text(
              'Nội dung',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text(
              'Hình ảnh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text(
              'Trạng thái',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text(
              'Ngày đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Tooltip(
              message: 'Ngày chỉnh sửa',
              child: Text(
                'Ngày chỉnh sửa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text(
              'Lượt thích',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text(
              'Chia sẻ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text(
              'Hành động',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
          ),
        ],
        rows: [
          ..._posts.map((post) => _buildDataRow(post)),
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
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
                const DataCell(SizedBox()),
              ],
            ),
        ],
      ),
    );
  }

  DataRow2 _buildDataRow(Post post) {
    final isReshare = post.originalPostId != null;

    // Check logic fail-over
    final isSystemFailover =
        post.status == 'active' && post.moderatedBy == 'system_failover';

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (post.status) {
      case 'active':
        statusColor = appPrimaryColor;
        statusText = 'Đã duyệt';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = errorBackgroundColor;
        statusText = 'Bị từ chối';
        statusIcon = Icons.cancel;
        break;
      case 'processing':
        statusColor = Colors.orange;
        statusText = 'Đang xử lý';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'pending_review':
        statusColor = infoBackgroundColor;
        statusText = 'Chờ duyệt';
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = secondaryColor;
        statusText = 'Không rõ';
        statusIcon = Icons.help_outline;
    }

    return DataRow2(
      cells: [
        // Uid
        DataCell(
          Text(
            post.postId,
            style: const TextStyle(
              fontSize: 13,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 4,
          ),
        ),
        // User Info
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: appPrimaryColor.withValues(alpha: 0.2),
                backgroundImage: post.profImage.isNotEmpty
                    ? NetworkImage(post.profImage)
                    : null,
                radius: 20,
                child: post.profImage.isEmpty
                    ? Icon(Icons.person, color: appPrimaryColor)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      post.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isReshare)
                      Text(
                        'Đã chia sẻ bài viết',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Post Content
        DataCell(
          Tooltip(
            message: post.postText,
            child: Text(
              post.postText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),

        // Image
        DataCell(
          post.postUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.postUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.broken_image, color: secondaryColor),
                  ),
                )
              : Icon(Icons.image_not_supported, color: secondaryColor),
        ),

        // Status Column
        DataCell(
          Container(
            alignment: Alignment.center,
            height: 80,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // check AI system failover in approve post
                  if (isSystemFailover) ...[
                    const SizedBox(height: 4),
                    Tooltip(
                      message:
                          post.aiReason ??
                          'Hệ thống tự động duyệt do AI mất kết nối',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off, // Icon thể hiện mất kết nối
                              size: 12,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Lỗi AI (Tự duyệt)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Admin Reason
                  if (post.status == 'rejected' &&
                      post.adminReason != null &&
                      post.adminReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: 'Admin: ${post.adminReason!}',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 12,
                              color: errorBackgroundColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                post.adminReason!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: errorBackgroundColor.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 4. AI Reason
                  if (post.status == 'rejected' &&
                      post.aiReason != null &&
                      post.aiReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: 'AI: ${post.aiReason!}',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smart_toy,
                              size: 12,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                post.aiReason!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Date Published
        DataCell(
          Text(
            DateFormat('HH:mm dd/MM/yyyy').format(post.datePublished),
            style: const TextStyle(fontSize: 13),
          ),
        ),

        // Date Updated
        DataCell(
          post.dateUpdated != null
              ? Text(
                  DateFormat('HH:mm dd/MM/yyyy').format(post.dateUpdated!),
                  style: const TextStyle(fontSize: 13),
                )
              : const Text(
                  'Chưa chỉnh sửa',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
        ),

        // Likes Count
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                post.likes.length.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),

        // Reshare Count
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, size: 16, color: appPrimaryColor),
              const SizedBox(width: 4),
              Text(
                post.reshareCount.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),

        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Details button
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'Xem chi tiết',
                color: primaryTextColor,
                onPressed: () async {
                  _openPostDetailDialog(post);
                },
              ),
              // Approve button (only for rejected/pending posts)
              if (post.status == 'rejected' || post.status == 'pending_review')
                IconButton(
                  icon: const Icon(Icons.check_circle, size: 20),
                  tooltip: 'Duyệt bài viết',
                  color: appPrimaryColor,
                  onPressed: () => _approvePost(post),
                ),
              // Reject button (only for active/pending/processing posts)
              if (post.status == 'active' ||
                  post.status == 'pending_review' ||
                  post.status == 'processing')
                IconButton(
                  icon: const Icon(Icons.block, size: 20),
                  tooltip: 'Từ chối bài viết',
                  color: Colors.orange,
                  onPressed: () => _rejectPost(post),
                ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Xóa',
                color: errorBackgroundColor,
                onPressed: () => _deletePost(post),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add this new method to approve posts
  Future<void> _approvePost(Post post) async {
    final isOverridingAdmin =
        post.adminReason != null && post.adminReason!.isNotEmpty;
    final isOverridingAI = post.aiReason != null && post.aiReason!.isNotEmpty;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ApprovePostDialog(
        post: post,
        isOverridingAdmin: isOverridingAdmin,
        isOverridingAI: isOverridingAI,
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // Update post status to active with admin moderation
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId)
          .update({
            'status': 'active',
            'adminReason': null, // Clear any previous admin reason
            'moderatedBy': 'admin', // Mark as admin-approved
            'moderatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      displaySnackBar(
        'Đã duyệt bài viết thành công',
        context,
        SnackBarType.success,
      );

      // Refresh the list
      _loadPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        displaySnackBar(
          'Lỗi khi duyệt bài viết: $e',
          context,
          SnackBarType.error,
        );
      }
    }
  }

  // Update the reject post method
  Future<void> _rejectPost(Post post) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RejectPostDialog(
        post: post,
        isOverridingAI: post.status == 'active' && post.moderatedBy == 'AI',
      ),
    );

    if (result == null || !mounted) return;

    final reason = result['reason'];
    if (reason == null || reason.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final adminEmail = user?.email ?? 'Unknown Admin';

      // Update post status to rejected with admin reason
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId)
          .update({
            'status': 'rejected',
            'adminReason': reason, // Set admin reason
            'moderatedBy': 'admin', // Mark as admin-moderated
            'moderatedByAdminEmail': adminEmail,
            'moderatedAt': FieldValue.serverTimestamp(),
            // Keep AI reason if it exists for reference
          });

      if (!mounted) return;

      displaySnackBar(
        'Đã từ chối bài viết thành công',
        context,
        SnackBarType.success,
      );

      // Refresh the list
      _loadPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        displaySnackBar(
          'Lỗi khi từ chối bài viết: $e',
          context,
          SnackBarType.error,
        );
      }
    }
  }
}
