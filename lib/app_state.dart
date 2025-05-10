import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState with ChangeNotifier {
  // Singleton pattern
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // State variables
  String? _centerId;
  String? _centerName;
  List<dynamic> _patients = [];
  String? _currentPatientName;
  String? _currentPatientId;
  String? _currentEmployeeId; // 新增 currentEmployeeId 屬性
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  String? _username;
  String? _password;
// 新增配對碼屬性
  String? _pairCode;
  // Callback to trigger HomeScreen refresh
  VoidCallback? _onHomeRefresh;

  // Getters
  String? get centerId => _centerId;
  String? get centerName => _centerName;
  String? get pairCode => _pairCode;
  List<dynamic> get patients => _patients;
  List<String> get patientNames => _patients.map((p) => p['PatientName'].toString()).toList();
  String? get currentPatientName => _currentPatientName;
  String? get currentPatientId => _currentPatientId;
  String? get currentEmployeeId => _currentEmployeeId; // 新增 getter
  String? get username => _username;
  String? get password => _password;

  // Setters
  void setCredentials(String username, String password) {
    _username = username;
    _password = password;
    usernameController.text = username;
    passwordController.text = password;
    notifyListeners();
  }
  // 新增設置配對碼的方法
  void setPairCode(String? code) {
    _pairCode = code;
    notifyListeners();
  }

  void setCenterData(String? id, String? name) {
    _centerId = id;
    _centerName = name;
    notifyListeners();
  }

  void setPatients(List<dynamic> patients) {
    _patients = patients;
    notifyListeners();
  }

  void setCurrentPatient(String? name, String? id) {
    _currentPatientName = name;
    _currentPatientId = id;
    debugPrint('AppState: Set current patient - Name: $name, ID: $id');
    notifyListeners();
  }

  void setCurrentEmployee(String? employeeId) { // 新增方法
    _currentEmployeeId = employeeId;
    debugPrint('AppState: Set current employee - ID: $employeeId');
    notifyListeners();
  }

  // Set the callback for HomeScreen refresh
  void setHomeRefreshCallback(VoidCallback callback) {
    _onHomeRefresh = callback;
    debugPrint('AppState: Home refresh callback set');
  }

  // Trigger HomeScreen data refresh
  void refreshHomeData() {
    debugPrint('AppState: Triggering home data refresh');
    _onHomeRefresh?.call();
    notifyListeners();
  }

  Future<void> init() async {
    await _loadCredentials();
  }

  // Load saved credentials
  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      _username = prefs.getString('savedUsername') ?? '';
      _password = prefs.getString('savedPassword') ?? '';
      _centerId = prefs.getString('centerId') ?? '';
      _centerName = prefs.getString('centerName') ?? '';
      _currentPatientName = prefs.getString('currentPatientName') ?? '';
      _currentPatientId = prefs.getString('currentPatientId') ?? '';
      _currentEmployeeId = prefs.getString('currentEmployeeId') ?? ''; // 載入 currentEmployeeId
      usernameController.text = _username ?? '';
      passwordController.text = _password ?? '';
      debugPrint('AppState: Loaded credentials - PatientID: $_currentPatientId, EmployeeID: $_currentEmployeeId');
    }
    notifyListeners();
  }

  // Save credentials
  Future<void> saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);

    if (rememberMe) {
      await prefs.setString('savedUsername', _username ?? '');
      await prefs.setString('savedPassword', _password ?? '');
      await prefs.setString('centerId', _centerId ?? '');
      await prefs.setString('centerName', _centerName ?? '');
      await prefs.setString('currentPatientName', _currentPatientName ?? '');
      await prefs.setString('currentPatientId', _currentPatientId ?? '');
      await prefs.setString('currentEmployeeId', _currentEmployeeId ?? ''); // 保存 currentEmployeeId
      debugPrint('AppState: Saved credentials - PatientID: $_currentPatientId, EmployeeID: $_currentEmployeeId');
    } else {
      await prefs.remove('savedUsername');
      await prefs.remove('savedPassword');
      await prefs.remove('centerId');
      await prefs.remove('centerName');
      await prefs.remove('currentPatientName');
      await prefs.remove('currentPatientId');
      await prefs.remove('currentEmployeeId'); // 移除 currentEmployeeId
    }
    notifyListeners();
  }

  // Clear all state
  Future<void> clearAll() async {
    _centerId = null;
    _centerName = null;
    _patients = [];
    _currentPatientName = null;
    _currentPatientId = null;
    _username = null;
    _password = null;
    usernameController.clear();
    passwordController.clear();
    _onHomeRefresh = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    rememberMe = false;
    debugPrint('AppState: Cleared all state');
    notifyListeners();
  }
}

// Global instance
final appState = AppState();