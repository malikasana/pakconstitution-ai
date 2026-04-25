import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pakconstitution.db');

    return openDatabase(
      path,
      version: 2, // bumped from 1 to 2 for summary column migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        summary TEXT,
        refs TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conv_id 
      ON messages (conversation_id)
    ''');
  }

  // Migration: version 1 → 2 adds summary column
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN summary TEXT');
    }
  }

  // ── CONVERSATIONS ─────────────────────────────────────────────

  Future<void> insertConversation(Conversation conv) async {
    final db = await database;
    await db.insert('conversations', conv.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    final maps = await db.query('conversations', orderBy: 'updated_at DESC');
    return maps.map(Conversation.fromMap).toList();
  }

  Future<Conversation?> getConversation(String id) async {
    final db = await database;
    final maps = await db.query('conversations',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  Future<void> updateConversation(Conversation conv) async {
    final db = await database;
    await db.update('conversations', conv.toMap(),
        where: 'id = ?', whereArgs: [conv.id]);
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllConversations() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
  }

  // ── MESSAGES ─────────────────────────────────────────────────

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert('messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    final maps = await db.query('messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC');
    return maps.map(Message.fromMap).toList();
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ── SUMMARY CIRCULAR BUFFER ───────────────────────────────────
  // Deletes oldest assistant summaries beyond maxTurns per conversation.
  // Full answers (content) are never deleted — only excess summaries are cleared.
  Future<void> pruneOldSummaries(String conversationId, int maxTurns) async {
    final db = await database;

    // Get all assistant messages for this conversation oldest first
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ? AND role = ?',
      whereArgs: [conversationId, 'assistant'],
      orderBy: 'created_at ASC',
    );

    if (maps.length <= maxTurns) return; // nothing to prune

    // How many excess summaries to clear
    final excess = maps.length - maxTurns;
    final toNullify = maps.take(excess).map((m) => m['id'] as String).toList();

    // Clear summary on old messages — keep content intact
    for (final id in toNullify) {
      await db.update(
        'messages',
        {'summary': null},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}