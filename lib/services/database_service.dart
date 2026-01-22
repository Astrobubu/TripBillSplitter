import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/trip.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../models/change_log.dart';
import '../models/payment.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trip_bill_splitter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE trips ADD COLUMN iconCodePoint INTEGER DEFAULT 58688');
      await db.execute('ALTER TABLE trips ADD COLUMN colorValue INTEGER DEFAULT 4280391411');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // Trips table
    await db.execute('''
      CREATE TABLE trips (
        id $idType,
        name $textType,
        createdAt $textType,
        updatedAt TEXT,
        currency $textType,
        totalParticipants $intType,
        isArchived $intType,
        iconCodePoint $intType,
        colorValue $intType
      )
    ''');

    // People table
    await db.execute('''
      CREATE TABLE people (
        id $idType,
        name $textType,
        tripId $textType,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        description $textType,
        amount $realType,
        payerId $textType,
        tripId $textType,
        createdAt $textType,
        updatedAt TEXT,
        FOREIGN KEY (payerId) REFERENCES people (id) ON DELETE CASCADE,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Change log table
    await db.execute('''
      CREATE TABLE change_logs (
        id $idType,
        tripId $textType,
        changeType $intType,
        timestamp $textType,
        description $textType,
        metadata TEXT,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE payments (
        id $idType,
        tripId $textType,
        fromPersonId $textType,
        toPersonId $textType,
        amount $realType,
        status $intType,
        createdAt $textType,
        completedAt TEXT,
        note TEXT,
        FOREIGN KEY (tripId) REFERENCES trips (id) ON DELETE CASCADE,
        FOREIGN KEY (fromPersonId) REFERENCES people (id) ON DELETE CASCADE,
        FOREIGN KEY (toPersonId) REFERENCES people (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_expenses_tripId ON expenses(tripId)');
    await db.execute('CREATE INDEX idx_people_tripId ON people(tripId)');
    await db.execute('CREATE INDEX idx_change_logs_tripId ON change_logs(tripId)');
    await db.execute('CREATE INDEX idx_payments_tripId ON payments(tripId)');
  }

  // Trip CRUD operations
  Future<Trip> createTrip(Trip trip) async {
    final db = await instance.database;
    await db.insert('trips', trip.toMap());
    return trip;
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await instance.database;
    final result = await db.query(
      'trips',
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Trip.fromMap(json)).toList();
  }

  Future<Trip?> getTripById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Trip.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await instance.database;
    return db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<int> deleteTrip(String id) async {
    final db = await instance.database;
    return await db.delete(
      'trips',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Person CRUD operations
  Future<Person> createPerson(Person person) async {
    final db = await instance.database;
    await db.insert('people', person.toMap());
    return person;
  }

  Future<List<Person>> getPeopleByTripId(String tripId) async {
    final db = await instance.database;
    final result = await db.query(
      'people',
      where: 'tripId = ?',
      whereArgs: [tripId],
    );
    return result.map((json) => Person.fromMap(json)).toList();
  }

  Future<Person?> getPersonById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Person.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deletePerson(String id) async {
    final db = await instance.database;
    return await db.delete(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePerson(Person person) async {
    final db = await instance.database;
    return await db.update(
      'people',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  // Expense CRUD operations
  Future<Expense> createExpense(Expense expense) async {
    final db = await instance.database;
    await db.insert('expenses', expense.toMap());
    return expense;
  }

  Future<List<Expense>> getExpensesByTripId(String tripId) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Change Log operations
  Future<ChangeLogEntry> createChangeLog(ChangeLogEntry entry) async {
    final db = await instance.database;
    await db.insert('change_logs', entry.toMap());
    return entry;
  }

  Future<List<ChangeLogEntry>> getChangeLogsByTripId(String tripId, {int? limit}) async {
    final db = await instance.database;
    final result = await db.query(
      'change_logs',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((json) => ChangeLogEntry.fromMap(json)).toList();
  }

  // Payment operations
  Future<Payment> createPayment(Payment payment) async {
    final db = await instance.database;
    await db.insert('payments', payment.toMap());
    return payment;
  }

  Future<List<Payment>> getPaymentsByTripId(String tripId) async {
    final db = await instance.database;
    final result = await db.query(
      'payments',
      where: 'tripId = ?',
      whereArgs: [tripId],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Payment.fromMap(json)).toList();
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await instance.database;
    return db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(String id) async {
    final db = await instance.database;
    return await db.delete(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
