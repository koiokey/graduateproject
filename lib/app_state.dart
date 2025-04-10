import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  // Singleton pattern
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // State variables
  String? _centerId;
  List<dynamic> _patients = [];
  String? _currentPatientName;
  String? _currentPatientId;
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;

  // Getters
  String? get centerId => _centerId;
  List<dynamic> get patients => _patients;
  List<String> get patientNames => _patients.map((p) => p['PatientName'].toString()).toList();
  String? get currentPatientName => _currentPatientName;
  String? get currentPatientId => _currentPatientId;
  String? _username; // 存储用户名
  String? _password; // 存储密码

  // 获取用户名
  String? get username => _username;
  // 获取密码
  String? get password => _password;
   void setCredentials(String username, String password) {
    _username = username;
    _password = password;
  }

  // Setters
  void setCenterId(String id) {
    _centerId = id;
  }

  void setPatients(List<dynamic> patients) {
    _patients = patients;
  }

  void setCurrentPatient(String? name) {
    _currentPatientName = name;
    if (name != null) {
      // Find the corresponding patient ID
      var patient = _patients.firstWhere(
        (p) => p['PatientName'] == name,
        orElse: () => {'PatientID': null},
      );
      _currentPatientId = patient['PatientID']?.toString();
    } else {
      _currentPatientId = null;
    }
  }
  
     Future<void> init() async {
    await _loadCredentials();
  }

  // 載入保存的憑證
  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('rememberMe') ?? false;
    
    if (rememberMe) {
      usernameController.text = prefs.getString('savedUsername') ?? '';
      passwordController.text = prefs.getString('savedPassword') ?? '';
    }
  }

  // 保存憑證
  Future<void> saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);
    
    if (rememberMe) {
      await prefs.setString('savedUsername', usernameController.text);
      await prefs.setString('savedPassword', passwordController.text);
    } else {
      await prefs.remove('savedUsername');
      await prefs.remove('savedPassword');
    }
  }

  // 清除所有狀態
  Future<void> clearAll() async {
    _centerId = null;
    _patients = [];
    _currentPatientName = null;
    _currentPatientId = null;
    usernameController.clear();
    passwordController.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', false);
    rememberMe = false;
  }
}



// Global instance
final appState = AppState();