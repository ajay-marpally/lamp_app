import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import 'notification_service.dart';

/// Supabase service for database operations
/// Updated to match actual database schema
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ==================== AUTH ====================

  static User? get currentUser => client.auth.currentUser;

  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ==================== USER PROFILE ====================

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('Users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  static Future<void> upsertUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await client.from('Users').upsert({
      'id': userId,
      ...data,
    });
  }

  // ==================== HABITS ====================

  /// Get all habits assigned to a protégé with habit details
  static Future<List<Map<String, dynamic>>> getAssignedHabits(String protegeId) async {
    final response = await client
        .from('habit_assignments')
        .select('''
          id,
          protege_id,
          habit_id,
          assigned_at,
          repetition_days,
          habits (
            id,
            name,
            description,
            icon_url,
            is_active
          )
        ''')
        .eq('protege_id', protegeId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get all available habits
  static Future<List<Map<String, dynamic>>> getAllHabits() async {
    final response = await client
        .from('habits')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Log a habit completion
  static Future<void> logHabit({
    required String habitId,
    required String protegeId,
    required DateTime date,
    String? startTime,
    int? durationMinutes,
    String? beforeFeeling,
    String? afterFeeling,
    String? notes,
  }) async {
    // Insert the habit log
    await client.from('habit_logs').insert({
      'habit_id': habitId,
      'protege_id': protegeId,
      'date': date.toIso8601String().split('T')[0],
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'before_feeling': beforeFeeling,
      'after_feeling': afterFeeling,
      'notes': notes,
      'verification_status': 'approved', // Auto-approve as per user request
    });

    // Update streak
    await _updateHabitStreak(protegeId, habitId, date);
  }

  /// Update habit streak after logging
  static Future<void> _updateHabitStreak(String protegeId, String habitId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    
    // Get current streak record
    final existing = await client
        .from('habit_streaks')
        .select()
        .eq('protege_id', protegeId)
        .eq('habit_id', habitId)
        .maybeSingle();

    if (existing != null) {
      final lastLogged = existing['last_logged_date'] as String?;
      int currentStreak = existing['current_streak'] ?? 0;
      int longestStreak = existing['longest_streak'] ?? 0;

      // Check if this extends the streak (logged yesterday)
      if (lastLogged != null) {
        final lastDate = DateTime.parse(lastLogged);
        final diff = date.difference(lastDate).inDays;
        
        if (diff == 1) {
          // Consecutive day - extend streak
          currentStreak++;
        } else if (diff == 0) {
          // Same day - no change
        } else {
          // Streak broken - reset
          currentStreak = 1;
        }
      } else {
        currentStreak = 1;
      }

      longestStreak = currentStreak > longestStreak ? currentStreak : longestStreak;

      await client.from('habit_streaks').update({
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_logged_date': dateStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      // Create new streak record
      await client.from('habit_streaks').insert({
        'protege_id': protegeId,
        'habit_id': habitId,
        'current_streak': 1,
        'longest_streak': 1,
        'last_logged_date': dateStr,
      });
    }
  }

  /// Get habit streaks for a protégé
  static Future<List<Map<String, dynamic>>> getHabitStreaks(String protegeId) async {
    final response = await client
        .from('habit_streaks')
        .select('''
          id,
          habit_id,
          current_streak,
          longest_streak,
          last_logged_date,
          habits (name)
        ''')
        .eq('protege_id', protegeId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get total current streak (sum of all habit streaks)
  static Future<int> getTotalCurrentStreak(String protegeId) async {
    final streaks = await getHabitStreaks(protegeId);
    int maxStreak = 0;
    for (final s in streaks) {
      final current = s['current_streak'] ?? 0;
      if (current > maxStreak) maxStreak = current;
    }
    return maxStreak;
  }

  /// Get habit logs for a protégé
  static Future<List<Map<String, dynamic>>> getHabitLogs({
    required String protegeId,
    String? habitId,
    int? limit,
  }) async {
    // Build query with filters first, then order and limit
    var query = client
        .from('habit_logs')
        .select('''
          id,
          habit_id,
          date,
          start_time,
          duration_minutes,
          before_feeling,
          after_feeling,
          notes,
          verification_status,
          created_at,
          habits (name)
        ''')
        .eq('protege_id', protegeId);

    if (habitId != null) {
      query = query.eq('habit_id', habitId);
    }

    // Apply order and limit
    final orderedQuery = query.order('date', ascending: false);
    
    final response = limit != null 
        ? await orderedQuery.limit(limit)
        : await orderedQuery;
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get habit analytics for display
  static Future<Map<String, dynamic>> getHabitAnalytics({required String protegeId}) async {
    final logs = await client
        .from('habit_logs')
        .select('id, date, habit_id')
        .eq('protege_id', protegeId);

    final logList = List<Map<String, dynamic>>.from(logs);
    final uniqueDates = <String>{};
    final uniqueHabits = <String>{};

    for (final log in logList) {
      uniqueDates.add(log['date'] ?? '');
      uniqueHabits.add(log['habit_id'] ?? '');
    }

    final streaks = await getHabitStreaks(protegeId);
    int maxStreak = 0;
    int totalCurrentStreak = 0;
    for (final s in streaks) {
      final current = s['current_streak'] ?? 0;
      final longest = s['longest_streak'] ?? 0;
      if (current > maxStreak) maxStreak = current;
      if (longest > maxStreak) maxStreak = longest;
      totalCurrentStreak += current as int;
    }

    return {
      'total_logs': logList.length,
      'unique_days': uniqueDates.length,
      'unique_habits': uniqueHabits.length,
      'current_streak': totalCurrentStreak,
      'longest_streak': maxStreak,
    };
  }

  /// Get weekly habit completion data for chart
  static Future<List<Map<String, dynamic>>> getWeeklyHabitData(String protegeId) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final response = await client
        .from('habit_logs')
        .select('date')
        .eq('protege_id', protegeId)
        .gte('date', weekAgo.toIso8601String().split('T')[0])
        .lte('date', now.toIso8601String().split('T')[0]);

    // Count logs per day
    final logList = List<Map<String, dynamic>>.from(response);
    final dayCounts = <String, int>{};
    
    for (final log in logList) {
      final date = log['date'] as String;
      dayCounts[date] = (dayCounts[date] ?? 0) + 1;
    }

    // Build last 7 days data
    final List<Map<String, dynamic>> weekData = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateStr = day.toIso8601String().split('T')[0];
      weekData.add({
        'date': dateStr,
        'day': _getDayName(day.weekday),
        'count': dayCounts[dateStr] ?? 0,
      });
    }

    return weekData;
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  // ==================== TASKS ====================

  /// Get tasks assigned to a protégé
  /// NOTE: protege_id in task_assignments is TEXT, not UUID
  static Future<List<Map<String, dynamic>>> getAssignedTasks(String protegeId) async {
    final response = await client
        .from('task_assignments')
        .select('''
          id,
          task_id,
          protege_id,
          chaperone_id,
          status,
          remarks,
          assigned_at,
          completed_at,
          tasks (
            id,
            name,
            description,
            type,
            video_url,
            photos,
            document_url,
            deadline
          )
        ''')
        .eq('protege_id', protegeId)
        .order('assigned_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Update task status (assigned -> ToVerify -> verified)
  static Future<void> updateTaskStatus({
    required String assignmentId,
    required String status,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
    };

    if (status == 'ToVerify') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    } else if (status == 'verified') {
      updates['reviewed_at'] = DateTime.now().toIso8601String();
    }

    await client
        .from('task_assignments')
        .update(updates)
        .eq('id', assignmentId);
  }

  /// Create a new task
  static Future<Map<String, dynamic>> createTask({
    required String name,
    String? description,
    required String createdBy,
    DateTime? deadline,
    String? type,
    String? videoUrl,
    String? documentUrl,
  }) async {
    final response = await client.from('tasks').insert({
      'name': name,
      'description': description,
      'created_by': createdBy,
      'assigned_by': createdBy,
      'deadline': deadline?.toIso8601String(),
      'type': type,
      'video_url': videoUrl,
      'document_url': documentUrl,
    }).select().single();
    return response;
  }

  /// Assign a task to a protégé
  /// NOTE: protege_id and chaperone_id are TEXT in the schema
  static Future<void> assignTask({
    required String taskId,
    required String protegeId,
    required String assignedBy,
  }) async {
    await client.from('task_assignments').insert({
      'task_id': taskId,
      'protege_id': protegeId,
      'chaperone_id': assignedBy,
      'assigned_by_role': 'chaperone',
      'status': 'assigned',
    });
  }

  /// Get tasks created by chaperone
  static Future<List<Map<String, dynamic>>> getTasksCreatedBy(String chaperoneId) async {
    final response = await client
        .from('tasks')
        .select()
        .eq('created_by', chaperoneId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get task assignments for chaperone's proteges
  static Future<List<Map<String, dynamic>>> getChaperoneTaskAssignments(String chaperoneId) async {
    final response = await client
        .from('task_assignments')
        .select('''
          id,
          task_id,
          protege_id,
          status,
          assigned_at,
          completed_at,
          tasks (name, description)
        ''')
        .eq('chaperone_id', chaperoneId)
        .order('assigned_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Delete a task and its assignments
  static Future<void> deleteTask(String taskId) async {
    // Delete assignments first (due to foreign key constraints)
    await client.from('task_assignments').delete().eq('task_id', taskId);
    
    // Delete the task
    await client.from('tasks').delete().eq('id', taskId);
  }

  /// Delete a task assignment
  static Future<void> deleteTaskAssignment(String assignmentId) async {
    await client.from('task_assignments').delete().eq('id', assignmentId);
  }

  // ==================== CHAPERONE ====================

  /// Get protégés assigned to a chaperone
  static Future<List<Map<String, dynamic>>> getAssignedProteges(String chaperoneId) async {
    final response = await client
        .from('chaperone_protege')
        .select('''
          id,
          protege_id,
          protege_name,
          assigned_at,
          Users!chaperone_protege_protege_id_fkey (
            id,
            Name,
            email,
            currentStreak
          )
        ''')
        .eq('chaperone_id', chaperoneId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get chaperone dashboard stats
  static Future<Map<String, dynamic>?> getChaperoneDashboard(String chaperoneId) async {
    final response = await client
        .from('chaperone_dashboard')
        .select()
        .eq('chaperone_id', chaperoneId)
        .maybeSingle();
    return response;
  }

  /// Get pending habit logs for chaperone to review
  static Future<List<Map<String, dynamic>>> getPendingHabitLogs(String chaperoneId) async {
    // Get protégé IDs first
    final proteges = await getAssignedProteges(chaperoneId);
    final protegeIds = proteges.map((p) => p['protege_id']).toList();

    if (protegeIds.isEmpty) return [];

    final response = await client
        .from('habit_logs')
        .select('''
          id,
          habit_id,
          protege_id,
          date,
          before_feeling,
          after_feeling,
          notes,
          verification_status,
          habits (name),
          Users!habit_logs_protege_id_fkey (Name)
        ''')
        .inFilter('protege_id', protegeIds)
        .eq('verification_status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Verify a habit log
  static Future<void> verifyHabitLog({
    required String logId,
    required String verifiedBy,
    required String status, // 'approved' or 'rejected'
    String? notes,
  }) async {
    await client.from('habit_logs').update({
      'verification_status': status,
      'verified_by': verifiedBy,
      'verified_at': DateTime.now().toIso8601String(),
      'verification_notes': notes,
    }).eq('id', logId);
  }

  /// Add feedback on a habit log
  static Future<void> addHabitFeedback({
    required String habitLogId,
    required String chaperoneId,
    String? feedback,
    int? rating,
  }) async {
    await client.from('habit_feedback').insert({
      'habit_log_id': habitLogId,
      'chaperone_id': chaperoneId,
      'feedback': feedback,
      'rating': rating,
    });
  }

  // ==================== HOME SUMMARY ====================

  /// Get protégé home summary
  static Future<Map<String, dynamic>?> getProtegeSummary(String protegeId) async {
    final response = await client
        .from('protege_home_summary')
        .select()
        .eq('protege_id', protegeId)
        .maybeSingle();
    return response;
  }

  /// Assign a habit to a protégé
  static Future<void> assignHabit({
    required String protegeId,
    required String habitId,
    required List<int> repetitionDays,
  }) async {
    await client.from('habit_assignments').insert({
      'protege_id': protegeId,
      'habit_id': habitId,
      'repetition_days': repetitionDays,
    });
  }

  // ==================== NOTIFICATIONS ====================

  static final List<RealtimeChannel> _notificationChannels = [];

  /// Initialize real-time listeners for notifications
  static Future<void> initNotificationListeners(String userId) async {
    // Clear existing channels
    disposeNotificationListeners();

    // Listen for new task assignments
    final taskChannel = client
        .channel('public:task_assignments:protege_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'task_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'protege_id',
            value: userId,
          ),
          callback: (payload) async {
            // Fetch task details for proper notification
            final taskId = payload.newRecord['task_id'] as String;
            final task = await client
                .from('tasks')
                .select('name')
                .eq('id', taskId)
                .maybeSingle();
            
            final taskName = task?['name'] ?? 'New Task';
            
            NotificationService().showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: 'New Task Assigned',
              body: 'You have been assigned: $taskName',
              payload: '/protege/tasks',
            );
          },
        )
        .subscribe();

    // Listen for new habit assignments
    final habitChannel = client
        .channel('public:habit_assignments:protege_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'habit_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'protege_id',
            value: userId,
          ),
          callback: (payload) async {
            // Fetch habit details
            final habitId = payload.newRecord['habit_id'] as String;
            final habit = await client
                .from('habits')
                .select('name')
                .eq('id', habitId)
                .maybeSingle();

            final habitName = habit?['name'] ?? 'New Habit';

            NotificationService().showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: 'New Habit Assigned',
              body: 'Start practicing: $habitName',
              payload: '/protege/habits',
            );
          },
        )
        .subscribe();

    _notificationChannels.add(taskChannel);
    _notificationChannels.add(habitChannel);
  }

  /// Dispose notification listeners
  static void disposeNotificationListeners() {
    for (final channel in _notificationChannels) {
      client.removeChannel(channel);
    }
    _notificationChannels.clear();
  }

  /// Schedule notifications for task deadlines
  static Future<void> scheduleTaskDeadlineNotifications(String userId) async {
    // Cancel existing scheduled notifications to avoid duplicates
    await NotificationService().cancelAllNotifications();

    final tasks = await getAssignedTasks(userId);

    for (final assignment in tasks) {
      final task = assignment['tasks'];
      if (task == null || task['deadline'] == null) continue;
      
      final deadlineStr = task['deadline'] as String;
      final deadline = DateTime.parse(deadlineStr);
      final now = DateTime.now();

      // If deadline is in the future
      if (deadline.isAfter(now)) {
        // Schedule reminder 24 hours before
        final reminderTime = deadline.subtract(const Duration(hours: 24));
        if (reminderTime.isAfter(now)) {
          await NotificationService().scheduleNotification(
            id: assignment['id'].hashCode,
            title: 'Task Due Tomorrow',
            body: 'Task "${task['name']}" is due heavily tomorrow!',
            scheduledDate: reminderTime,
            payload: '/protege/tasks',
          );
        }

        // Schedule reminder 1 hour before
        final urgentTime = deadline.subtract(const Duration(hours: 1));
        if (urgentTime.isAfter(now)) {
           await NotificationService().scheduleNotification(
            id: assignment['id'].hashCode + 1,
            title: 'Task Due Soon',
            body: 'Task "${task['name']}" is due in 1 hour!',
            scheduledDate: urgentTime,
            payload: '/protege/tasks',
          );
        }
      }
    }
  }

  // ==================== ADMIN METHODS ====================

  /// Get admin stats (total users, proteges, chaperones)
  static Future<Map<String, int>> getAdminStats() async {
    final users = await client.from('users').select('role');
    final userList = List<Map<String, dynamic>>.from(users);
    
    return {
      'users': userList.length,
      'proteges': userList.where((u) => u['role'] == 'protege').length,
      'chaperones': userList.where((u) => u['role'] == 'chaperone').length,
      'admins': userList.where((u) => u['role'] == 'admin').length,
    };
  }

  /// Get all users (admin only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await client.from('users').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Create user invite
  static Future<void> createInvite({required String email, required String role}) async {
    await client.from('user_invites').insert({
      'email': email,
      'role': role,
      'invited_by': currentUser?.id,
    });
    
    // Send invite email via Supabase Auth
    await client.auth.signInWithOtp(email: email);
  }

  /// Get pending invites
  static Future<List<Map<String, dynamic>>> getPendingInvites() async {
    final response = await client.from('user_invites').select().order('invited_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Create habit (admin only)
  static Future<void> createHabit({required String name, String? description}) async {
    await client.from('habits').insert({
      'name': name,
      'description': description,
      'created_by': currentUser?.id,
    });
  }

  /// Get filtered KPIs for export
  static Future<List<Map<String, dynamic>>> getFilteredKPIs(double taskMin, double habitMin) async {
    // Get all proteges with their stats
    final proteges = await client.from('users').select('id, name, email').eq('role', 'protege');
    final protegeList = List<Map<String, dynamic>>.from(proteges);
    
    final results = <Map<String, dynamic>>[];
    
    for (final protege in protegeList) {
      final protegeId = protege['id'];
      
      // Calculate task completion
      final tasks = await client.from('task_assignments').select('status').eq('protege_id', protegeId);
      final taskList = List<Map<String, dynamic>>.from(tasks);
      final totalTasks = taskList.length;
      final completedTasks = taskList.where((t) => t['status'] == 'verified').length;
      final taskPercent = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;
      
      // Calculate habit consistency (days logged in last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final logs = await client
          .from('habit_logs')
          .select('date')
          .eq('protege_id', protegeId)
          .gte('date', thirtyDaysAgo.toIso8601String().split('T')[0]);
      final logList = List<Map<String, dynamic>>.from(logs);
      final uniqueDays = logList.map((l) => l['date']).toSet().length;
      final habitPercent = (uniqueDays / 30) * 100;
      
      // Apply filters
      if (taskPercent >= taskMin && habitPercent >= habitMin) {
        results.add({
          'name': protege['name'] ?? 'Unknown',
          'email': protege['email'] ?? '',
          'task_completion_percent': taskPercent,
          'habit_consistency_percent': habitPercent,
        });
      }
    }
    
    return results;
  }

  // ==================== COMMUNITY METHODS ====================

  /// Get all posts with user info and vote counts
  static Future<List<Map<String, dynamic>>> getPosts() async {
    final response = await client
        .from('posts')
        .select('*, users(name)')
        .order('created_at', ascending: false);
    
    final posts = List<Map<String, dynamic>>.from(response);
    
    // Get vote counts for each post
    for (final post in posts) {
      final reactions = await client
          .from('post_reactions')
          .select('reaction_type')
          .eq('post_id', post['id']);
      final reactionList = List<Map<String, dynamic>>.from(reactions);
      post['upvotes'] = reactionList.where((r) => r['reaction_type'] == 'up').length;
      post['downvotes'] = reactionList.where((r) => r['reaction_type'] == 'down').length;
      
      final comments = await client
          .from('comments')
          .select('id')
          .eq('post_id', post['id']);
      post['comment_count'] = List.from(comments).length;
    }
    
    return posts;
  }

  /// Create a new post
  static Future<void> createPost({required String title, required String body}) async {
    await client.from('posts').insert({
      'title': title,
      'body': body,
      'user_id': currentUser?.id,
    });
  }

  /// Vote on a post
  static Future<void> votePost({required String postId, required String type}) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    // Check if user already voted
    final existing = await client
        .from('post_reactions')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId);
    
    if (List.from(existing).isNotEmpty) {
      // Update existing vote
      await client
          .from('post_reactions')
          .update({'reaction_type': type})
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      // Insert new vote
      await client.from('post_reactions').insert({
        'post_id': postId,
        'user_id': userId,
        'reaction_type': type,
      });
    }
  }

  /// Get comments for a post
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response = await client
        .from('comments')
        .select('*, users(name)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Add a comment to a post
  static Future<void> addComment({required String postId, required String body}) async {
    await client.from('comments').insert({
      'post_id': postId,
      'user_id': currentUser?.id,
      'body': body,
    });
  }

  // ==================== STORAGE METHODS ====================

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    try {
      final filePath = '${currentUser?.id}/$path';
      await client.storage.from(bucket).uploadBinary(
        filePath,
        bytes as dynamic,
        fileOptions: FileOptions(contentType: contentType),
      );
      
      // Get public URL
      final publicUrl = client.storage.from(bucket).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  /// Create a post with optional media attachments
  static Future<void> createPostWithMedia({
    required String title,
    required String body,
    List<String>? photoUrls,
    String? videoUrl,
    String? documentUrl,
  }) async {
    await client.from('posts').insert({
      'title': title,
      'body': body,
      'user_id': currentUser?.id,
      'photos': photoUrls,
      'video_url': videoUrl,
      'document_url': documentUrl,
    });
  }

  /// Upload multiple photos and return their URLs
  static Future<List<String>> uploadPhotos(List<dynamic> files) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last;
      final path = 'posts/${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
      
      final url = await uploadFile(
        bucket: 'media',
        path: path,
        bytes: bytes,
        contentType: 'image/$extension',
      );
      if (url != null) urls.add(url);
    }
    return urls;
  }

  /// Upload a video and return its URL
  static Future<String?> uploadVideo(dynamic file) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last;
    final path = 'posts/${DateTime.now().millisecondsSinceEpoch}.$extension';
    
    return await uploadFile(
      bucket: 'media',
      path: path,
      bytes: bytes,
      contentType: 'video/$extension',
    );
  }

  /// Upload a document and return its URL
  static Future<String?> uploadDocument(dynamic file) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last;
    final path = 'posts/${DateTime.now().millisecondsSinceEpoch}.$extension';
    
    String contentType = 'application/octet-stream';
    if (extension == 'pdf') contentType = 'application/pdf';
    if (extension == 'doc' || extension == 'docx') contentType = 'application/msword';
    
    return await uploadFile(
      bucket: 'media',
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
  }

  // ==================== INVITE SYSTEM ====================

  /// Verify invite by email and code
  static Future<Map<String, dynamic>?> verifyInvite({
    required String email,
    required String code,
  }) async {
    final response = await client
        .from('user_invites')
        .select()
        .eq('email', email)
        .eq('invite_code', code)
        .isFilter('accepted_at', null)
        .gte('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();
    
    return response;
  }

  /// Get predefined interests
  static Future<List<Map<String, dynamic>>> getPredefinedInterests() async {
    final response = await client
        .from('predefined_interests')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get predefined courses
  static Future<List<Map<String, dynamic>>> getPredefinedCourses() async {
    final response = await client
        .from('predefined_courses')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Complete invite registration
  static Future<void> completeInviteRegistration({
    required String email,
    required String password,
    required String name,
    required String role,
    required List<String> interests,
    required List<String> courses,
    required String inviteId,
    String? chaperoneId,
  }) async {
    // Sign up user
    final authResponse = await client.auth.signUp(
      email: email,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Failed to create account');
    }

    final userId = authResponse.user!.id;

    // Create user profile
    await client.from('users').insert({
      'id': userId,
      'email': email,
      'name': name,
      'role': role,
      'interests': interests,
      'courses': courses,
      'chaperone_id': chaperoneId,
    });

    // If protege and chaperone assigned, create relationship
    if (role == 'protege' && chaperoneId != null) {
      await client.from('chaperone_protege').insert({
        'chaperone_id': chaperoneId,
        'protege_id': userId,
        'protege_name': name,
      });
    }

    // Mark invite as accepted
    await client.from('user_invites').update({
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', inviteId);

    // Sign out (user needs to login fresh)
    await client.auth.signOut();
  }

  /// Create invite with optional chaperone assignment
  static Future<Map<String, dynamic>> createInviteWithCode({
    required String email,
    required String role,
    String? chaperoneId,
  }) async {
    final response = await client.from('user_invites').insert({
      'email': email,
      'role': role,
      'invited_by': currentUser?.id,
      'chaperone_id': chaperoneId,
    }).select().single();
    
    return response;
  }

  /// Admin: Add interest
  static Future<void> addInterest(String name, String? description) async {
    await client.from('predefined_interests').insert({
      'name': name,
      'description': description,
    });
  }

  /// Admin: Add course
  static Future<void> addCourse(String name, String? description) async {
    await client.from('predefined_courses').insert({
      'name': name,
      'description': description,
    });
  }

  /// Get chaperone details for protege
  static Future<Map<String, dynamic>?> getChaperoneDetails(String chaperoneId) async {
    final response = await client
        .from('users')
        .select('id, name, email, phone, location')
        .eq('id', chaperoneId)
        .maybeSingle();
    return response;
  }

  /// Get available chaperones (with less than 5 proteges)
  static Future<List<Map<String, dynamic>>> getAvailableChaperones() async {
    final chaperones = await client
        .from('users')
        .select('id, name, email, interests')
        .eq('role', 'chaperone');
    
    final chaperoneList = List<Map<String, dynamic>>.from(chaperones);
    
    // Filter to those with < 5 proteges
    final available = <Map<String, dynamic>>[];
    for (final chap in chaperoneList) {
      final proteges = await client
          .from('chaperone_protege')
          .select('id')
          .eq('chaperone_id', chap['id']);
      if (List.from(proteges).length < 5) {
        chap['protege_count'] = List.from(proteges).length;
        available.add(chap);
      }
    }
    
    return available;
  }

  /// Assign protege to chaperone (admin/manual)
  static Future<void> assignProtegeToChaperone({
    required String protegeId,
    required String chaperoneId,
    required String protegeName,
  }) async {
    // Remove existing assignment if any
    await client.from('chaperone_protege').delete().eq('protege_id', protegeId);
    
    // Create new assignment
    await client.from('chaperone_protege').insert({
      'chaperone_id': chaperoneId,
      'protege_id': protegeId,
      'protege_name': protegeName,
    });
    
    // Update user's chaperone_id
    await client.from('users').update({
      'chaperone_id': chaperoneId,
    }).eq('id', protegeId);
  }
}
