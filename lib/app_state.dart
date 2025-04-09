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
  void clearAll() {
    _centerId = null;
    _patients = [];
    _currentPatientName = null;
    _currentPatientId = null;
    _username = null;
    _password = null;
    usernameController.clear();
    passwordController.clear();
  }
}

// Global instance
final appState = AppState();