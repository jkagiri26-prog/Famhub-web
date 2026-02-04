import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('famhub.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Initial schema if needed
  }

  Future<List<Map<String, dynamic>>> getTechDevices() async {
    // Returning mock data to match your UI requirements
    return [
      {'title': 'Soil Probe A', 'status': 'Online', 'iconCode': 0xe56d, 'colorHex': '0xFF4CAF50'},
      {'title': 'Cattle Tracker', 'status': 'Low Batt', 'iconCode': 0xeb20, 'colorHex': '0xFFFF9800'},
      {'title': 'Gate Camera', 'status': 'Online', 'iconCode': 0xe4f3, 'colorHex': '0xFF2196F3'},
      {'title': 'Silo Monitor', 'status': 'Offline', 'iconCode': 0xe39d, 'colorHex': '0xFFF44336'},
    ];
  }
}