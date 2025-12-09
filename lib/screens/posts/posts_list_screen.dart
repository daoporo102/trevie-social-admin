import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/post.dart';
import 'package:social_media_admin/services/post_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/create_post_dialog.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';

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
  int _totalPosts = 0;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  PostSortField _sortBy = PostSortField.datePublished;
  bool _ascending = false;
  String _searchQuery = '';

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
    if (_isLoading) return;

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
      _searchController.clear();
    });
    _loadPosts(refresh: true);
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài viết này?\n\n'
          'Hành động này không thể hoàn tác!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorBackgroundColor),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await _postService.deletePost(post.postId);

    if (!mounted) return;

    if (result == 'success') {
      displaySnackBar(
        'Đã xóa bài viết thành công',
        context,
        SnackBarType.success,
      );
      _loadPosts(refresh: true);
      _loadTotalCount();
    } else {
      displaySnackBar(result, context, SnackBarType.error);
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
          Row(
            children: [
              const SizedBox(width: 16.0),
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
              const SizedBox(width: 16.0),
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
        minWidth: 1000,
        dataRowHeight: 80,
        headingRowHeight: 56,
        columns: const [
          DataColumn2(
            label: Text(
              'Người đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
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
              'Ngày đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text(
              'Ngày chỉnh sửa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.M,
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
              ],
            ),
        ],
      ),
    );
  }

  DataRow2 _buildDataRow(Post post) {
    final isReshare = post.originalPostId != null;

    return DataRow2(
      cells: [
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
}
