import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'myhome_local.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<void> init() async {
    await database;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    debugPrint('SQLite path: $path');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        state TEXT,
        photo TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_profiles (
        user_id TEXT PRIMARY KEY,
        id TEXT,
        monthly_salary REAL,
        other_income REAL,
        commitments REAL,
        savings REAL,
        down_payment REAL,
        affordability_score REAL,
        recommended_budget REAL,
        risk_level TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT,
        name TEXT,
        total_amount REAL,
        monthly_payment REAL,
        interest_rate REAL,
        remaining_months INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_debts_user_id ON debts(user_id)',
    );

    await db.execute('''
      CREATE TABLE property_preferences (
        user_id TEXT PRIMARY KEY,
        id TEXT,
        purpose TEXT,
        property_type TEXT,
        price_range TEXT,
        bedrooms INTEGER,
        preferred_state TEXT,
        important_factors TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_ids (
        user_id TEXT NOT NULL,
        listing_id TEXT NOT NULL,
        PRIMARY KEY (user_id, listing_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE properties (
        listing_id TEXT PRIMARY KEY,
        price INTEGER,
        property_type TEXT,
        bedrooms INTEGER,
        bathrooms INTEGER,
        built_up TEXT,
        full_address TEXT,
        district TEXT,
        state TEXT,
        tenure TEXT,
        description TEXT,
        facilities TEXT,
        photo_urls TEXT,
        listing_url TEXT,
        agent_name TEXT,
        lat REAL,
        lng REAL,
        scraped_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE property_states (
        state TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_flags (
        user_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        pending INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, kind)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }
}
