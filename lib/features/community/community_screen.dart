import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';

/// Community Forum Screen
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await SupabaseService.getPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) => _buildPostCard(_posts[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePostDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No posts yet'),
          const SizedBox(height: 8),
          const Text('Be the first to share something!', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final title = post['title'] ?? '';
    final body = post['body'] ?? '';
    final userName = post['users']?['name'] ?? 'Anonymous';
    final upvotes = post['upvotes'] ?? 0;
    final downvotes = post['downvotes'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;
    final photos = post['photos'] as List? ?? [];
    final videoUrl = post['video_url'];
    final documentUrl = post['document_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPostDetail(post),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', 
                          style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text(userName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                
                // Body preview
                Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                
                // Media indicators
                if (photos.isNotEmpty || videoUrl != null || documentUrl != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (photos.isNotEmpty) 
                        Chip(avatar: const Icon(Icons.photo, size: 16), label: Text('${photos.length} photo(s)')),
                      if (videoUrl != null)
                        const Chip(avatar: Icon(Icons.videocam, size: 16), label: Text('Video')),
                      if (documentUrl != null)
                        const Chip(avatar: Icon(Icons.description, size: 16), label: Text('Document')),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Actions
                Row(
                  children: [
                    _buildVoteButton(Icons.thumb_up_outlined, upvotes, () => _vote(post['id'], 'up')),
                    const SizedBox(width: 16),
                    _buildVoteButton(Icons.thumb_down_outlined, downvotes, () => _vote(post['id'], 'down')),
                    const Spacer(),
                    Icon(Icons.comment_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('$commentCount', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton(IconData icon, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(onCreated: _loadPosts)),
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  Future<void> _vote(String postId, String type) async {
    await SupabaseService.votePost(postId: postId, type: type);
    _loadPosts();
  }
}

/// Post Detail Screen with comments
class PostDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await SupabaseService.getComments(widget.post['id']);
    setState(() => _comments = comments);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post['title'] ?? '';
    final body = post['body'] ?? '';
    final userName = post['users']?['name'] ?? 'Anonymous';

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                      ),
                      const SizedBox(width: 12),
                      Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  // Body
                  Text(body, style: Theme.of(context).textTheme.bodyLarge),
                  
                  const Divider(height: 32),
                  
                  // Comments
                  Text('Comments (${_comments.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  
                  ..._comments.map((c) => _buildCommentTile(c)),
                ],
              ),
            ),
          ),
          
          // Comment input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Add a comment...', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    if (_commentController.text.isNotEmpty) {
                      await SupabaseService.addComment(postId: widget.post['id'], body: _commentController.text);
                      _commentController.clear();
                      _loadComments();
                    }
                  },
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final userName = comment['users']?['name'] ?? 'Anonymous';
    final body = comment['body'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

/// Create Post Screen with media upload
class CreatePostScreen extends StatefulWidget {
  final VoidCallback onCreated;

  const CreatePostScreen({super.key, required this.onCreated});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  List<XFile> _selectedPhotos = [];
  XFile? _selectedVideo;
  PlatformFile? _selectedDocument;
  bool _isUploading = false;

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _selectedPhotos = images);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _selectedVideo = video);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedDocument = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<String>? photoUrls;
      String? videoUrl;
      String? documentUrl;

      // Upload photos
      if (_selectedPhotos.isNotEmpty) {
        photoUrls = await SupabaseService.uploadPhotos(_selectedPhotos);
      }

      // Upload video
      if (_selectedVideo != null) {
        videoUrl = await SupabaseService.uploadVideo(_selectedVideo);
      }

      // Upload document
      if (_selectedDocument != null) {
        documentUrl = await SupabaseService.uploadDocument(_selectedDocument);
      }

      // Create post
      await SupabaseService.createPostWithMedia(
        title: _titleController.text,
        body: _bodyController.text,
        photoUrls: photoUrls,
        videoUrl: videoUrl,
        documentUrl: documentUrl,
      );

      if (mounted) {
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _submit,
                  child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'What do you want to share?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            
            // Media section
            Text('Attach Media (Optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _MediaButton(
                    icon: Icons.photo_library,
                    label: _selectedPhotos.isEmpty ? 'Photos' : '${_selectedPhotos.length} selected',
                    onTap: _pickPhotos,
                    isSelected: _selectedPhotos.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.videocam,
                    label: _selectedVideo == null ? 'Video' : 'Selected',
                    onTap: _pickVideo,
                    isSelected: _selectedVideo != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.description,
                    label: _selectedDocument == null ? 'Document' : _selectedDocument!.name,
                    onTap: _pickDocument,
                    isSelected: _selectedDocument != null,
                  ),
                ),
              ],
            ),
            
            // Preview selected photos
            if (_selectedPhotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPhotos.length,
                  itemBuilder: (context, index) => Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(child: Icon(Icons.photo, color: AppColors.primary.withValues(alpha: 0.5))),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _selectedPhotos.removeAt(index)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
