import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_media_admin/models/comment.dart';
import 'package:social_media_admin/services/comment_service.dart';
import 'package:social_media_admin/utils/colors.dart';
import 'package:social_media_admin/utils/global_variables.dart';
import 'package:social_media_admin/utils/utils.dart';
import 'package:social_media_admin/widgets/custom_snack_bar.dart';

class CommentsListScreen extends StatefulWidget {
  const CommentsListScreen({super.key});

  @override
  State<CommentsListScreen> createState() => _CommentsListScreenState();
}

class _CommentsListScreenState extends State<CommentsListScreen> {
  final CommentService _commentService = CommentService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _authorNameController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _allPosts = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _totalComments = 0;

  // Filters
  String? _selectedPostId;
  String _authorNameFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  CommentSortField _sortBy = CommentSortField.datePublished;
  bool _ascending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadComments();
    _loadTotalCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authorNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final posts = await _commentService.getAllPosts();
    if (mounted) {
      setState(() {
        _allPosts = posts;
      });
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _comments = [];
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      final result = await _commentService.getAllComments(
        limit: 50,
        lastDocument: refresh ? null : _lastDocument,
        searchQuery: _searchQuery,
        postId: _selectedPostId,
        authorName: _authorNameFilter,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
        ascending: _ascending,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _comments = result['comments'];
        } else {
          _comments.addAll(result['comments']);
        }
        _lastDocument = result['lastDocument'];
        _hasMore = result['hasMore'];
      });
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(
        'Lỗi khi tải danh sách bình luận: $e',
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

    await _loadComments();

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadTotalCount() async {
    final count = await _commentService.getTotalCommentsCount();
    if (mounted) {
      setState(() {
        _totalComments = count;
      });
    }
  }

  void _applyFilters() {
    _loadComments(refresh: true);
  }

  void _resetFilters() {
    setState(() {
      _selectedPostId = null;
      _authorNameFilter = '';
      _startDate = null;
      _endDate = null;
      _sortBy = CommentSortField.datePublished;
      _ascending = false;
      _searchQuery = '';
      _searchController.clear();
      _authorNameController.clear();
    });
    _loadComments(refresh: true);
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bình luận này?\n\n'
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

    try {
      final result = await _commentService.deleteComment(postId, commentId);

      if (!mounted) return;

      if (result == 'success') {
        displaySnackBar(
          'Đã xóa bình luận thành công',
          context,
          SnackBarType.success,
        );
        _loadComments(refresh: true);
        _loadTotalCount();
      } else {
        displaySnackBar(result, context, SnackBarType.error);
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(
          'Lỗi khi xóa bình luận: $e',
          context,
          SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBackgroundColor,
      appBar: AppBar(
        title: Text('Quản lý bình luận ($_totalComments)'),
        backgroundColor: webBackgroundColor,
        foregroundColor: primaryTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadComments(refresh: true);
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
            child: _isLoading && _comments.isEmpty
                ? Center(child: customCircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy bình luận',
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
                    labelText: 'Tìm kiếm theo nội dung hoặc tên tác giả...',
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
              // Post Filter - FIXED VERSION
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedPostId,
                  decoration: InputDecoration(
                    labelText: 'Lọc theo bài viết',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  isExpanded: true, // ADD THIS LINE
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả bài viết'),
                    ),
                    ..._allPosts.map((post) {
                      final postText = post['postText'] as String;
                      final displayText = postText.length > 30
                          ? '${postText.substring(0, 30)}...'
                          : postText;
                      return DropdownMenuItem(
                        value: post['postId'],
                        child: Tooltip(
                          message: postText,
                          child: Text(
                            displayText,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1, // ADD THIS LINE
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPostId = value;
                    });
                    _applyFilters();
                  },
                ),
              ),

              // Author Name Filter
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _authorNameController,
                  decoration: InputDecoration(
                    labelText: 'Lọc theo tên tác giả',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: _authorNameFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _authorNameFilter = '';
                                _authorNameController.clear();
                              });
                              _applyFilters();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _authorNameFilter = value;
                    });
                    _applyFilters();
                  },
                ),
              ),

              // Sort By
              DropdownButton<CommentSortField>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(
                    value: CommentSortField.datePublished,
                    child: Text('Sắp xếp: Ngày đăng'),
                  ),
                  DropdownMenuItem(
                    value: CommentSortField.name,
                    child: Text('Sắp xếp: Tên tác giả'),
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
        minWidth: 1000,
        dataRowHeight: 80,
        headingRowHeight: 56,
        columns: const [
          DataColumn2(
            label: Text(
              'Người đăng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text(
              'Nội dung bình luận',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text(
              'Bài viết',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.L,
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
              'Hành động',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            size: ColumnSize.S,
          ),
        ],
        rows: [
          ..._comments.map((item) => _buildDataRow(item)),
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
              ],
            ),
        ],
      ),
    );
  }

  DataRow2 _buildDataRow(Map<String, dynamic> item) {
    final Comment comment = item['comment'];
    final String postId = item['postId'] ?? '';
    final String postText = item['postText'] ?? '';
    final String postAuthor = item['postAuthor'] ?? 'Unknown';
    // Handle null values with null-aware operators
    final String name = (item['name'] as String?) ?? comment.name;
    final String profilePic =
        (item['profilePic'] as String?) ?? comment.profilePic;

    return DataRow2(
      cells: [
        // User Info
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: appPrimaryColor.withValues(alpha: 0.2),
                backgroundImage: profilePic.isNotEmpty
                    ? NetworkImage(profilePic)
                    : null,
                radius: 20,
                child: profilePic.isEmpty
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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comment Text
        DataCell(
          Tooltip(
            message: comment.commentText,
            child: Text(
              comment.commentText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),

        // Post Link
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: postText,
                child: Text(
                  postText.length > 50
                      ? '${postText.substring(0, 50)}...'
                      : postText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                'Bởi: $postAuthor',
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        // Date Published
        DataCell(
          Text(
            DateFormat('HH:mm dd/MM/yyyy').format(comment.datePublished),
            style: const TextStyle(fontSize: 13),
          ),
        ),

        // Date Updated
        DataCell(
          comment.dateUpdated != null
              ? Text(
                  DateFormat('HH:mm dd/MM/yyyy').format(comment.dateUpdated!),
                  style: const TextStyle(fontSize: 13),
                )
              : const Text(
                  'Chưa chỉnh sửa',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
        ),

        // Actions
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            tooltip: 'Xóa',
            color: errorBackgroundColor,
            onPressed: () => _deleteComment(postId, comment.commentId),
          ),
        ),
      ],
    );
  }
}
