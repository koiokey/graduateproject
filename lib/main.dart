import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io'; // 用於處理檔案路徑
import 'dart:convert'; // 用於 Base64 編碼
import 'app_state.dart'; // 添加這行導入
import 'package:http/http.dart' as http; // 導入 http 套件
import 'package:flutter/services.dart'; // 用於 Clipboard
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'utils.dart';


AppState appState = AppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 appState
  final appState = AppState(); // 假設 AppState 有一個預設構造函數
  await appState.init();

  // 初始化 DrugImageManager，使用 appState 的認證資訊
  final drugImageManager = DrugImageManager();
  await drugImageManager.initialize(
    appState.usernameController.text,
    appState.passwordController.text,
  );

  // 獲取可用攝影機
  final cameras = await availableCameras();

  // 運行應用程式
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: MyApp(cameras: cameras),
    ),
  );
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(
        usernameController: usernameController,
        passwordController: passwordController,
      ),
      routes: {
        '/home': (context) => HomeScreen(
              usernameController: usernameController,
              passwordController: passwordController,
            ),
        '/medicine_recognition': (context) => MedicineRecognitionScreen(
              cameras: cameras,
              usernameController: usernameController,
              passwordController: passwordController,
            ),
        '/patient_management': (context) => PatientManagementScreen(),
        '/prescription_capture': (context) => PrescriptionCaptureScreen(
              cameras: cameras,
              usernameController: usernameController,
              passwordController: passwordController,
            ),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('錯誤')),
          body: Center(
            child: Text('找不到頁面: ${settings.name}'),
          ),
        ),
      ),
    );
  }
}
//登入
class LoginScreen extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  LoginScreen({
    required this.usernameController,
    required this.passwordController,
  });

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (appState.rememberMe) {
      // 已經在 AppState.init() 中載入了帳號密碼
    }
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
      _errorMessage = null; // 重置錯誤訊息
    });

    final loginJsonData = {
      "username": widget.usernameController.text,
      "password": widget.passwordController.text,
      "requestType": "sql verify",
      "data": {},
    };

    try {
      // 發送驗證請求
      final loginResponse = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginJsonData),
      );

      final loginResponseData = jsonDecode(loginResponse.body);

      // 檢查回應是否為包含 CenterName 和 CenterID 的 JSON
      if (loginResponseData is Map &&
          loginResponseData.containsKey('CenterName') &&
          loginResponseData.containsKey('CenterID')) {
        final matchedCenterId = loginResponseData['CenterID']?.toString();
        final matchedCenterName = loginResponseData['CenterName']?.toString();
        if (matchedCenterId == null) {
          throw Exception('伺服器未提供 CenterID');
        }

        // 設置 CenterID
        appState. setCenterData(matchedCenterId,matchedCenterName);

        // 保存憑證
        appState.setCredentials(
          widget.usernameController.text,
          widget.passwordController.text,
        );
        await appState.saveCredentials();

        // 導航到首頁
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        throw Exception('帳號或密碼不正確');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100], // 設置背景為淺綠色
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: widget.usernameController,
                  decoration: InputDecoration(
                    labelText: '帳號',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white, // 輸入框背景為白色
                  ),
                ),
                const SizedBox(height: 16),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TextField(
                      controller: widget.passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '密碼',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white, // 輸入框背景為白色
                      ),
                    ),
                    if (_errorMessage != null)
                      Positioned(
                        right: 0,
                        top: 60,
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[400], // 按鈕背景為深綠色
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '登錄',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//首頁
class HomeScreen extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const HomeScreen({
    super.key,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedPatient;
  String? selectedPatientId;
  String? _selectedEmployeeId; // Track selected employee
  bool _isLoading = true;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _employees = [];
  Map<String, bool> _buttonStates = {};
  String? _errorMessage;
  late AppState _appState;
  final TextEditingController _pairCodeController = TextEditingController();
  int _currentPage = 0; // 0 for patients page, 1 for employee/journal page

 void initState() {
    super.initState();
    // 初始化 _appState
    _appState = Provider.of<AppState>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 確保 username 和 password 有效
        final username = _appState.usernameController.text;
        final password = _appState.passwordController.text;
        
        _fetchPatients();
        _fetchEmployees();
        // 從 AppState 恢復 _selectedEmployeeId
        setState(() {
          _selectedEmployeeId = _appState.currentEmployeeId;
        });
      }
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = Provider.of<AppState>(context, listen: false);
    _appState.setHomeRefreshCallback(() async {
      await _fetchPatients();
      await _fetchEmployees();
    });
  }

  @override
  void dispose() {
    _appState.setHomeRefreshCallback(() {
      debugPrint('HomeScreen: Refresh callback cleared');
    });
    _pairCodeController.dispose();
    super.dispose();
  }

  String _getTimeOfDay() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 1 && hour < 11) {
      return '早上';
    } else if (hour >= 11 && hour < 16) {
      return '中午';
    } else {
      return '晚上';
    }
  }

  Future<void> _fetchPatients() async {
    if (!mounted) {
      debugPrint('HomeScreen is not mounted, aborting _fetchPatients');
      return;
    }

    if (_appState.centerId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '未找到中心 ID';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      final timeOfDay = _getTimeOfDay();
      String timingCondition;
      if (timeOfDay == '早上') {
        timingCondition = "'早餐前', '早餐後'";
      } else if (timeOfDay == '中午') {
        timingCondition = "'中餐前', '中餐後'";
      } else {
        timingCondition = "'晚餐前', '晚餐後', '睡前'";
      }

      final sql = '''
        SELECT 
          p.PatientName,
          p.PatientPicture,
          p.PatientID,
          m.state,
          m.Timing,
          m.Added_Day,
          m.days
        FROM patients p
        LEFT JOIN medications m ON p.PatientID = m.PatientID
          AND DATE_ADD(m.Added_Day, INTERVAL m.days DAY) >= '$currentDate'
          AND m.Timing IN ($timingCondition)
        WHERE p.CenterID = '${_appState.centerId}'
      ''';

      if (kDebugMode) {
        debugPrint('Executing Patient SQL: $sql');
      }

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (kDebugMode) {
        debugPrint('Patient Response status: ${response.statusCode}');
        debugPrint('Patient Response body: ${response.body}');
      }

      if (response.statusCode != 200) {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final Map<String, Map<String, dynamic>> patientMap = {};

      for (var item in data) {
        final patientId = item['PatientID']?.toString() ?? '未知ID';
        if (!patientMap.containsKey(patientId)) {
          patientMap[patientId] = {
            'PatientName': item['PatientName']?.toString() ?? '未知姓名',
            'PatientPicture': item['PatientPicture']?.toString(),
            'PatientID': patientId,
            'statusColor': Colors.green[100],
            'medications': <Map<String, dynamic>>[],
          };
        }
        if (item['state'] != null && item['Timing'] != null) {
          patientMap[patientId]!['medications'].add({
            'state': item['state'],
            'Timing': item['Timing'],
            'Added_Day': item['Added_Day'],
            'days': item['days'],
          });
        }
      }

      final patients = patientMap.values.toList();
      for (var patient in patients) {
        const orange = Color.fromARGB(255, 240, 207, 157);
        const red = Color.fromARGB(255, 221, 150, 145);
        const yellow = Color.fromARGB(255, 255, 196, 237);
        const green = Color.fromARGB(255, 178, 223, 180);

        Color statusColor = green;

        if (kDebugMode) {
          debugPrint('Processing patient ${patient['PatientID']}');
          debugPrint('Medications: ${patient['medications']}');
        }

        if (timeOfDay == '晚上') {
          bool hasOrange = false;

          for (var med in patient['medications']) {
            if (med['Timing'] == '晚餐前') {
              final state = int.tryParse(med['state']?.toString() ?? '1') ?? 1;
              if (kDebugMode) {
                debugPrint('晚餐前 state: $state');
              }
              if (state == 0) {
                statusColor = orange;
                hasOrange = true;
                break;
              } else if (state == 2 && statusColor != orange) {
                statusColor = red;
              }
            }
          }

          if (!hasOrange) {
            for (var med in patient['medications']) {
              if (med['Timing'] == '晚餐後') {
                final state = int.tryParse(med['state']?.toString() ?? '1') ?? 1;
                if (kDebugMode) {
                  debugPrint('晚餐後 state: $state');
                }
                if (state == 0) {
                  statusColor = orange;
                  hasOrange = true;
                  break;
                } else if (state == 2 && statusColor != orange) {
                  statusColor = red;
                }
              }
            }
          }

          if (!hasOrange && statusColor != red) {
            for (var med in patient['medications']) {
              if (med['Timing'] == '睡前') {
                final state = int.tryParse(med['state']?.toString() ?? '1') ?? 1;
                if (kDebugMode) {
                  debugPrint('睡前 state: $state');
                }
                if (state == 3) {
                  statusColor = yellow;
                }
              }
            }
          }
        } else {
          for (var med in patient['medications']) {
            final state = int.tryParse(med['state']?.toString() ?? '1') ?? 1;
            if (kDebugMode) {
              debugPrint('${med['Timing']} state: $state');
            }
            if (state == 0) {
              statusColor = orange;
              break;
            } else if (state == 2) {
              statusColor = red;
            }
          }
        }

        patient['statusColor'] = statusColor;
        if (kDebugMode) {
          debugPrint('Patient ${patient['PatientID']} Status Color: $statusColor');
        }
      }

      patients.sort((a, b) {
        final colorA = a['statusColor'] as Color;
        final colorB = b['statusColor'] as Color;

        const orange = Color.fromARGB(255, 240, 207, 157);
        const red = Color.fromARGB(255, 221, 150, 145);
        const yellow = Color.fromARGB(255, 255, 196, 237);
        const green = Color.fromARGB(255, 178, 223, 180);

        int getColorPriority(Color color) {
          if (color == orange) return 1;
          if (color == red) return 2;
          if (color == yellow) return 3;
          if (color == green) return 4;
          return 5;
        }

        return getColorPriority(colorA).compareTo(getColorPriority(colorB));
      });

      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fetch patients error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '獲取患者資料失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) {
      debugPrint('HomeScreen is not mounted, aborting _fetchEmployees');
      return;
    }

    if (_appState.centerId == null) {
      if (mounted) {
        setState(() {
          _employees = [];
          _buttonStates = {};
        });
      }
      return;
    }

    try {
      final sql = '''
        SELECT EmployeeID, EmployeeName
        FROM employees
        WHERE CenterID = '${_appState.centerId}' AND states = 1
      ''';

      if (kDebugMode) {
        debugPrint('Executing Employee SQL: $sql');
      }

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (kDebugMode) {
        debugPrint('Employee Response status: ${response.statusCode}');
        debugPrint('Employee Response body: ${response.body}');
      }

      if (response.statusCode != 200) {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final List<Map<String, dynamic>> employees = data.map((item) {
        return {
          'EmployeeID': item['EmployeeID']?.toString() ?? '未知ID',
          'EmployeeName': item['EmployeeName']?.toString() ?? '未知姓名',
        };
      }).toList();

      final Map<String, bool> buttonStates = {
        for (var employee in employees) employee['EmployeeID']: false
      };

      if (mounted) {
        setState(() {
          _employees = employees;
          _buttonStates = buttonStates;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fetch employees error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
      if (mounted) {
        setState(() {
          _employees = [];
          _buttonStates = {};
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _appState.clearAll();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (Route<dynamic> route) => false,
    );
  }

  bool _isValidBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return false;
    try {
      final cleanStr = base64Str.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
      if (cleanStr.length % 4 != 0) return false;
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
      return base64Pattern.hasMatch(cleanStr);
    } catch (e) {
      debugPrint('Invalid base64 string: $e');
      return false;
    }
  }

  void _showFunctionDialog(Map<String, dynamic> patient) {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('警告'),
          content: const Text('請先從右側選單中選擇員工！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('確定'),
            ),
          ],
        ),
      );
      return;
    }

    final patientName = patient['PatientName'] as String;
    final patientId = patient['PatientID'] as String;

    debugPrint('HomeScreen: Patient data - Name: $patientName, ID: $patientId');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('選擇功能 - $patientName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.green[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedPatient = patientName;
                    selectedPatientId = patientId;
                  });
                  _appState.setCurrentPatient(patientName, patientId);
                  Navigator.pushNamed(context, '/medicine_recognition');
                },
                child: const Text(
                  '藥物辨識檢測',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 150,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.green[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedPatient = patientName;
                    selectedPatientId = patientId;
                  });
                  _appState.setCurrentPatient(patientName, patientId);
                  Navigator.pushNamed(context, '/prescription_capture');
                },
                child: const Text(
                  '藥單自動鍵值',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 150,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.green[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedPatient = patientName;
                    selectedPatientId = patientId;
                  });
                  _appState.setCurrentPatient(patientName, patientId);
                  Navigator.pushNamed(
                    context,
                    '/patient_management',
                    arguments: {
                      'patientName': patientName,
                      'patientId': patientId,
                    },
                  );
                },
                child: const Text(
                  '患者資料管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientButton(Map<String, dynamic> patient) {
    final patientName = patient['PatientName'] as String? ?? '未知姓名';
    final patientPicture = patient['PatientPicture'] as String?;
    final statusColor = patient['statusColor'] as Color;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(8),
        backgroundColor: statusColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
      onPressed: () => _showFunctionDialog(patient),
      onLongPress: () => _showPatientOptionsDialog(context, patient),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _isValidBase64(patientPicture)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(patientPicture!),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey,
                ),
          const SizedBox(height: 8),
          Text(
            patientName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddPatientButton() {
    return ElevatedButton.icon(
      onPressed: () {
        _showAddPatientDialog(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[400],
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(
        Icons.add,
        color: Colors.white,
      ),
      label: const Text(
        '新增患者',
        style: TextStyle(fontSize: 18, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAddEmployeeButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EmployeeManagementScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[400],
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(
        Icons.person_add,
        color: Colors.white,
      ),
      label: const Text(
        '新增員工',
        style: TextStyle(fontSize: 18, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildReviewJournalButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReviewJournalScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[400],
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(
        Icons.book,
        color: Colors.white,
      ),
      label: const Text(
        '審核日誌',
        style: TextStyle(fontSize: 18, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPatientsPage() {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _patients.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await _fetchPatients();
                            await _fetchEmployees();
                          },
                          color: Colors.blue,
                          backgroundColor: Colors.white,
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: 0,
                            itemBuilder: (context, index) {
                              return const SizedBox.shrink();
                            },
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _fetchPatients();
                            await _fetchEmployees();
                          },
                          color: Colors.blue,
                          backgroundColor: Colors.white,
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: _patients.length,
                            itemBuilder: (context, index) {
                              return _buildPatientButton(_patients[index]);
                            },
                          ),
                        ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: _buildAddPatientButton(),
        ),
      ],
    );
  }

  Widget _buildEmployeeJournalPage() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchEmployees();
            },
            color: Colors.blue,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildAddEmployeeButton(),
                  const SizedBox(height: 16.0),
                  _buildReviewJournalButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
//第二個頁面
  Widget _buildBlankPage() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: _currentPage == 0
                ? _buildPatientsPage()
                : _buildEmployeeJournalPage(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPage = 0;
                    });
                  },
                  child: Container(
                    color: _currentPage == 0 ? Colors.grey[600] : Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text(
                      '患者管理',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Text(
                  '|',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPage = 1;
                    });
                  },
                  child: Container(
                    color: _currentPage == 1 ? Colors.grey[600] : Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: Text(
                      '員工與日誌',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
//新增患者介面設計
  void _showAddPatientDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '患者姓名',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final pickedImage = await _pickAndCropImage(dialogContext);
                        if (pickedImage != null && dialogContext.mounted) {
                          setDialogState(() {
                            selectedImage = pickedImage;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[400],
                      ),
                      icon: const Icon(Icons.photo_library, color: Colors.white),
                      label: const Text(
                        '選擇照片',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            '離開',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('請輸入患者姓名')),
                              );
                              return;
                            }
                            if (selectedImage == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('請選擇患者照片')),
                              );
                              return;
                            }
                            await _uploadPatientData(
                              dialogContext,
                              nameController.text,
                              selectedImage!,
                            );
                          },
                          child: const Text(
                            '確認上傳',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadPatientData(BuildContext context, String patientName, File imageFile) async {
    if (!context.mounted) {
      debugPrint('Context is not mounted, aborting upload');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (widget.usernameController.text.isEmpty || widget.passwordController.text.isEmpty) {
        throw Exception('用戶名或密碼為空');
      }
      if (_appState.centerId == null) {
        throw Exception('CenterID 未初始化');
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final sanitizedPatientName = patientName.replaceAll("'", "''");
      final sql = """
        INSERT INTO patients (PatientName, PatientPicture, CenterID)
        VALUES ('$sanitizedPatientName', '$base64Image', '${_appState.centerId}')
      """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql},
        }),
      );

      if (!context.mounted) {
        debugPrint('Context is not mounted after HTTP request');
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        if (mounted) {
          await _fetchPatients();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('患者新增成功')),
        );
      } else {
        throw Exception('上傳失敗: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!context.mounted) {
        debugPrint('Context is not mounted in catch block');
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('患者數據上傳失敗: $e');
      debugPrint('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('新增患者失敗: ${e.toString()}')),
      );
    }
  }

  Future<File?> _pickAndCropImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (pickedImage == null) {
        return null;
      }

      final File imageFile = File(pickedImage.path);
      if (!await imageFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選擇的圖片檔案不存在')),
        );
        return null;
      }

      if (await imageFile.length() > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片檔案過大，請選擇較小的圖片')),
        );
        return null;
      }

      final bytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法解碼圖片')),
        );
        return null;
      }

      final int size = decodedImage.width < decodedImage.height ? decodedImage.width : decodedImage.height;
      final img.Image croppedImage = img.copyCrop(
        decodedImage,
        x: (decodedImage.width - size) ~/ 2,
        y: (decodedImage.height - size) ~/ 2,
        width: size,
        height: size,
      );

      final img.Image resizedImage = img.copyResize(
        croppedImage,
        width: 640,
        height: 640,
        interpolation: img.Interpolation.average,
      );

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/resized_image.jpg');
      int quality = 70;
      await tempFile.writeAsBytes(img.encodeJpg(resizedImage, quality: quality));

      const maxFileSize = 500 * 1024;
      if (await tempFile.length() > maxFileSize) {
        quality = 50;
        await tempFile.writeAsBytes(img.encodeJpg(resizedImage, quality: quality));
      }

      if (await tempFile.length() > maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片壓縮後仍過大，請選擇其他圖片')),
        );
        return null;
      }

      if (!await tempFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('壓縮後的圖片檔案無法保存')),
        );
        return null;
      }

      return tempFile;
    } catch (e, stackTrace) {
      debugPrint('圖片選擇或處理失敗: $e');
      debugPrint('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片處理失敗: $e')),
      );
      return null;
    }
  }

  void _showPatientOptionsDialog(BuildContext context, Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showEditPatientDialog(context, patient);
                },
                child: const Text(
                  '更改',
                  style: TextStyle(color: Colors.blue, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showDeletePatientDialog(context, patient);
                },
                child: const Text(
                  '刪除',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPatientDialog(BuildContext context, Map<String, dynamic> patient) {
    final TextEditingController nameController = TextEditingController(text: patient['PatientName']?.toString() ?? '');
    File? selectedImage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black54,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                '修改患者資料',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '患者姓名',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final pickedImage = await _pickAndCropImage(dialogContext);
                        if (pickedImage != null && dialogContext.mounted) {
                          setDialogState(() {
                            selectedImage = pickedImage;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                      icon: const Icon(Icons.photo_library, color: Colors.white),
                      label: const Text(
                        '選擇照片',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: selectedImage != null
                          ? Image.file(
                              selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.grey,
                              ),
                            )
                          : _isValidBase64(patient['PatientPicture'])
                              ? Image.memory(
                                  base64Decode(patient['PatientPicture']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.broken_image,
                                    size: 100,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text(
                            '離開',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('請輸入患者姓名')),
                              );
                              return;
                            }
                            await _updatePatientData(
                              dialogContext,
                              patient['PatientID']?.toString() ?? '',
                              nameController.text,
                              selectedImage,
                            );
                          },
                          child: const Text(
                            '確認修改',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeletePatientDialog(BuildContext context, Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            '確認刪除？',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '確定要刪除患者 ${patient['PatientName'] ?? '未知姓名'} 的資料嗎？',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                '離開',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _deletePatientData(dialogContext, patient['PatientID']?.toString() ?? '');
              },
              child: const Text(
                '確認刪除',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePatientData(
    BuildContext context,
    String patientId,
    String patientName,
    File? imageFile,
  ) async {
    if (!context.mounted) {
      debugPrint('Context is not mounted, aborting update');
      return;
    }
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無效的患者 ID')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (widget.usernameController.text.isEmpty || widget.passwordController.text.isEmpty) {
        throw Exception('用戶名或密碼為空');
      }
      if (_appState.centerId == null) {
        throw Exception('CenterID 未初始化');
      }

      String? base64Image;
      if (imageFile != null) {
        final imageBytes = await imageFile.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      final sanitizedPatientName = patientName.replaceAll("'", "''");
      final sql = base64Image != null
          ? """
            UPDATE patients
            SET PatientName = '$sanitizedPatientName', PatientPicture = '$base64Image'
            WHERE PatientID = '$patientId' AND CenterID = '${_appState.centerId}'
          """
          : """
            UPDATE patients
            SET PatientName = '$sanitizedPatientName'
            WHERE PatientID = '$patientId' AND CenterID = '${_appState.centerId}'
          """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql},
        }),
      );

      if (!context.mounted) {
        debugPrint('Context is not mounted after HTTP request');
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        if (mounted) {
          await _fetchPatients();
          if (selectedPatientId == patientId) {
            setState(() {
              selectedPatient = patientName;
            });
            _appState.setCurrentPatient(patientName, patientId);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('患者資料修改成功')),
        );
      } else {
        throw Exception('修改失敗: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!context.mounted) {
        debugPrint('Context is not mounted in catch block');
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('患者資料修改失敗: $e');
      debugPrint('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改患者失敗: ${e.toString()}')),
      );
    }
  }

  Future<void> _deletePatientData(BuildContext context, String patientId) async {
    if (!context.mounted) {
      debugPrint('Context is not mounted, aborting delete');
      return;
    }
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無效的患者 ID')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (widget.usernameController.text.isEmpty || widget.passwordController.text.isEmpty) {
        throw Exception('用戶名或密碼為空');
      }
      if (_appState.centerId == null) {
        throw Exception('CenterID 未初始化');
      }

      final sql = """
        DELETE FROM patients
        WHERE PatientID = '$patientId' AND CenterID = '${_appState.centerId}'
      """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql},
        }),
      );

      if (!context.mounted) {
        debugPrint('Context is not mounted after HTTP request');
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        if (mounted) {
          await _fetchEmployees();
          if (selectedPatientId == patientId) {
            setState(() {
              selectedPatient = null;
              selectedPatientId = null;
            });
            _appState.setCurrentPatient(null, null);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('患者資料刪除成功')),
        );
      } else {
        throw Exception('刪除失敗: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      if (!context.mounted) {
        debugPrint('Context is not mounted in catch block');
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('患者資料刪除失敗: $e');
      debugPrint('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除患者失敗: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('長照輔助系統 (ID: ${_appState.centerName ?? "未登入"})'),
        backgroundColor: Colors.grey[300],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '登出',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.grey[300]),
              child: const Text('選單', style: TextStyle(fontSize: 20)),
            ),
            // 配對碼輸入框
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '配對碼:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _pairCodeController,
                decoration: const InputDecoration(
                  hintText: '輸入配對碼',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (value) {
                  // 當按下 Enter 鍵時，將配對碼保存到 AppState
                  if (value.isNotEmpty) {
                    _appState.setPairCode(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('配對碼已保存: $value')),
                    );
                  } else {
                    _appState.setPairCode(null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('配對碼已清除')),
                    );
                  }
                },
              ),
            ),
            // 動態員工按鈕
            ..._employees.map((employee) {
              final employeeId = employee['EmployeeID'] as String;
              final employeeName = employee['EmployeeName'] as String;
              return ListTile(
                title: Text('$employeeId.$employeeName'),
                trailing: _selectedEmployeeId == employeeId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedEmployeeId = employeeId;
                    _appState.setCurrentEmployee(employeeId); // 將選擇的員工 ID 寫入 AppState
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
      body: _buildBlankPage(),
    );
  }
}

//藥丸
class MedicineRecognitionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  MedicineRecognitionScreen({
    required this.cameras,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  _MedicineRecognitionScreenState createState() => _MedicineRecognitionScreenState();
}

class _MedicineRecognitionScreenState extends State<MedicineRecognitionScreen> {
  String? selectedMedicine;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  File? _selectedImage;
  List<Map<String, dynamic>> _detections = [];
  List<Map<String, dynamic>> _patientMedications = [];
  List<Map<String, dynamic>> _mismatchedMedications = [];
  List<Map<String, dynamic>> _missingMedications = [];
  bool _isProcessing = false;
  Offset? _focusPoint;
  bool _isFocusing = false;
  String? _selectedTiming = '飯前';
  String? _lastFetchedTiming;
  String? _lastFetchedDate;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    debugPrint('Selected Patient ID: ${appState.currentPatientId}');
    if (appState.currentPatientId != null) {
      _fetchPatientMedications();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = '找不到可用相機';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '相機初始化失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getTimeOfDay() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 1 && hour < 11) {
      return '早上';
    } else if (hour >= 11 && hour < 16) {
      return '中午';
    } else {
      return '晚上';
    }
  }

  Future<void> _setFocusPoint(Offset point, Size screenSize) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (!mounted) {
      debugPrint('MedicineRecognitionScreen is not mounted in _setFocusPoint');
      return;
    }

    setState(() {
      _focusPoint = point;
      _isFocusing = true;
    });

    try {
      final double x = point.dx / screenSize.width;
      final double y = point.dy / screenSize.height;

      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isFocusing = false;
        });
      }
    } catch (e) {
      debugPrint('設置對焦點失敗: $e');
      if (mounted) {
        setState(() {
          _isFocusing = false;
        });
      }
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                '正在處理照片...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<String> _formatJson(Map<String, dynamic> responseData) async {
    return await compute((data) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }, responseData);
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相機未初始化')),
      );
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);

      if (_focusPoint != null) {
        final screenSize = MediaQuery.of(context).size;
        await _setFocusPoint(_focusPoint!, screenSize);
      }

      await Future.delayed(Duration(milliseconds: 500));
      showLoadingDialog(context);

      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'Yolo',
          'data': {'image': 'data:image/jpeg;base64,$base64Image'}
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<Map<String, dynamic>> detections = (responseData['detections'] as List?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];
        final String? annotatedImageBase64 = responseData['image'] as String?;

        // 並行執行
        final results = await Future.wait([
          _compareMedications(detections),
          _formatJson(responseData),
        ]);

        final String formattedJson = results[1] as String;

        // 獲取 timing 值
        final String timing = await _fetchPatientMedications();

        hideLoadingDialog(context);

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JsonResultScreen(
              annotatedImageBase64: annotatedImageBase64,
              jsonResponse: formattedJson,
              detections: detections,
              patientMedications: _patientMedications,
              mismatchedMedications: _mismatchedMedications,
              missingMedications: _missingMedications,
              timing: timing,
            ),
          ),
        );
      } else {
        throw Exception('伺服器返回錯誤: ${response.statusCode}');
      }
    } catch (e) {
      hideLoadingDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理失敗: $e')),
      );
    } finally {
      hideLoadingDialog(context);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _focusPoint = null;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (appState.currentPatientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先在首頁選擇病患')),
      );
      return;
    }

    if (_isProcessing) {
      debugPrint('處理中，無法選擇新照片');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      debugPrint('選擇照片: ${image?.path}');

      if (image == null) {
        debugPrint('未選擇照片');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final imageFile = File(image.path);
      if (await imageFile.exists()) {
        setState(() {
          _selectedImage = imageFile;
          _detections = [];
        });

        debugPrint('顯示載入對話框');
        showLoadingDialog(context);

        final imageBytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        debugPrint('照片轉換為 Base64 完成，長度: ${base64Image.length}');

        final jsonData = {
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'Yolo',
          'data': {'image': 'data:image/png;base64,$base64Image'},
        };

        debugPrint('發送 HTTP 請求: $jsonData');
        final response = await HttpClient.instance.post(
          Uri.parse('https://project.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(jsonData),
        );

        debugPrint('HTTP 回應狀態碼: ${response.statusCode}');
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          debugPrint('回應資料: $responseData');

          final List<Map<String, dynamic>> detections = (responseData['detections'] as List?)
              ?.cast<Map<String, dynamic>>()
              .toList() ?? [];
          final String? annotatedImageBase64 = responseData['image'] as String?;
          debugPrint('解析出 detections: $detections, annotatedImageBase64: ${annotatedImageBase64 != null}');

          final results = await Future.wait([
            _compareMedications(detections),
            _formatJson(responseData),
          ]);
          debugPrint('並行任務完成');

          final String formattedJson = results[1] as String;
          debugPrint('格式化 JSON 完成: $formattedJson');

          // 獲取 timing 值
          final String timing = await _fetchPatientMedications();
          debugPrint('獲取 timing: $timing');

          if (!mounted) {
            debugPrint('頁面已銷毀，無法導航到 JsonResultScreen');
            return;
          }

          debugPrint('準備導航到 JsonResultScreen');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JsonResultScreen(
                annotatedImageBase64: annotatedImageBase64,
                jsonResponse: formattedJson,
                detections: detections,
                patientMedications: _patientMedications,
                mismatchedMedications: _mismatchedMedications,
                missingMedications: _missingMedications,
                timing: timing,
              ),
            ),
          );
          debugPrint('導航到 JsonResultScreen 完成');
        } else {
          throw Exception('服務器返回錯誤: ${response.statusCode}');
        }
      } else {
        throw Exception('照片檔案不存在');
      }
    } catch (e, stackTrace) {
      debugPrint('處理失敗: $e\n堆疊追蹤: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('傳送失敗: $e')),
      );
    } finally {
      try {
        debugPrint('關閉載入對話框');
        hideLoadingDialog(context);
      } catch (e) {
        debugPrint('關閉載入對話框失敗: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _focusPoint = null;
        });
      }
    }
  }

  Future<Map<String, String>> _fetchDrugAppearances(List<String> drugIds) async {
    if (drugIds.isEmpty) return {};

    try {
      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.usernameController.text,
          'password': widget.passwordController.text,
          'requestType': 'sql search',
          'data': {
            'sql': "SELECT DrugID, drugappearance FROM drugs WHERE DrugID IN (${drugIds.map((id) => "'$id'").join(',')})",
          },
        }),
      );

      debugPrint('Fetch DrugAppearance HTTP Response Status: ${response.statusCode}');
      debugPrint('Fetch DrugAppearance HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return Map.fromEntries(data.map((item) => MapEntry(
              item['DrugID'].toString(),
              item['drugappearance']?.toString() ?? '',
            )));
      }
      return {};
    } catch (e) {
      debugPrint('Fetch DrugAppearance error: $e');
      return {};
    }
  }

  Future<String> _fetchPatientMedications() async {
    if (appState.currentPatientId == null) {
      debugPrint('患者 ID 為空，無法查詢藥物');
      return '';
    }

    final currentDate = DateTime.now();
    final formattedCurrentDate =
        "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

    if (_lastFetchedTiming == _selectedTiming &&
        _lastFetchedDate == formattedCurrentDate &&
        _patientMedications.isNotEmpty) {
      debugPrint('使用緩存的患者藥物數據');
      final timeOfDay = _getTimeOfDay();
      if (_selectedTiming == '睡前') {
        return '睡前';
      }
      final timingMap = {
        '早上': {'飯前': '早餐前', '飯後': '早餐後'},
        '中午': {'飯前': '中餐前', '飯後': '中餐後'},
        '晚上': {'飯前': '晚餐前', '飯後': '晚餐後'},
      };
      return timingMap[timeOfDay]?[_selectedTiming] ?? '早餐前';
    }

    try {
      String timingCondition = '';
      String timingValue = '';
      final timeOfDay = _getTimeOfDay();
      if (_selectedTiming == '睡前') {
        timingCondition = "AND Timing = '睡前'";
        timingValue = '睡前';
      } else {
        final timingMap = {
          '早上': {'飯前': '早餐前', '飯後': '早餐後'},
          '中午': {'飯前': '中餐前', '飯後': '中餐後'},
          '晚上': {'飯前': '晚餐前', '飯後': '晚餐後'},
        };
        timingValue = timingMap[timeOfDay]?[_selectedTiming] ?? '早餐前';
        timingCondition = "AND Timing = '$timingValue'";
      }

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": widget.usernameController.text,
          "password": widget.passwordController.text,
          "requestType": "sql search",
          "data": {
            "sql": """
              SELECT d.DrugName, m.Dose, m.DrugID
              FROM (
                    SELECT *
                    FROM medications
                    WHERE PatientID = '${appState.currentPatientId}'
                      AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$formattedCurrentDate'
                      $timingCondition
                    ) m
                    JOIN drugs d ON m.DrugID = d.DrugID
                    JOIN (
                        SELECT DrugID, MAX(Added_Day) AS Latest_Added_Day
                        FROM medications
                        WHERE PatientID = '${appState.currentPatientId}'
                          AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$formattedCurrentDate'
                        GROUP BY DrugID
                    ) latest
                    ON m.DrugID = latest.DrugID AND m.Added_Day = latest.Latest_Added_Day;
            """
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Medications API Response: $responseData');
        if (responseData is List) {
          // 提取 DrugID 和其他資料
          final medications = responseData
              .map((item) => {
                    'drugName': item['DrugName']?.toString().toLowerCase().trim() ?? '',
                    'dose': double.tryParse(item['Dose']?.toString() ?? '0') ?? 0,
                    'DrugID': item['DrugID']?.toString() ?? '',
                  })
              .where((med) => med['drugName'] is String && (med['drugName'] as String).isNotEmpty)
              .toList();

          // 批量查詢 drugappearance
          final drugIds = medications.map((med) => med['DrugID'] as String).toList();
          final appearances = await _fetchDrugAppearances(drugIds);

          // 將 drugappearance 加入 medications
          final updatedMedications = medications.map((med) {
            final drugId = med['DrugID'] as String;
            return {
              ...med,
              'drugappearance': appearances[drugId] ?? '',
            };
          }).toList();

          if (mounted) {
            setState(() {
              _patientMedications = updatedMedications;
              _lastFetchedTiming = _selectedTiming;
              _lastFetchedDate = formattedCurrentDate;
            });
          }
          return timingValue;
        } else {
          throw Exception('無效的資料格式');
        }
      }
      return timingValue;
    } catch (e) {
      debugPrint('獲取患者藥物失敗: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '獲取藥物資料失敗: $e';
        });
      }
      return '';
    }
  }

 Future<void> _compareMedications(List<Map<String, dynamic>> detections) async {
  final detectedLabels = detections
      .map((d) => d['label']?.toString().toLowerCase().trim())
      .whereType<String>()
      .toSet();

  final patientMedMap = {
    for (var med in _patientMedications)
      med['drugName'] as String: {
        'dose': med['dose'] as double,
        'DrugID': med['DrugID'] as String,
        'drugappearance': med['drugappearance'] as String,
      }
  };

  setState(() {
    _mismatchedMedications = detections
        .where((d) {
          final label = d['label']?.toString().toLowerCase().trim();
          return label != null && !patientMedMap.containsKey(label);
        })
        .toList();

    _missingMedications = patientMedMap.entries
        .map((entry) {
          final drugName = entry.key;
          final expectedDose = entry.value['dose'] as double;
          final drugId = entry.value['DrugID'] as String;
          final drugAppearance = entry.value['drugappearance'] as String;
          final detectedCount = detectedLabels.where((label) => label == drugName).length;
          final missingCount = expectedDose - detectedCount;
          return {
            'drugName': drugName,
            'missingCount': missingCount > 0.0 ? missingCount : 0.0,
            'DrugID': drugId,
            'drugappearance': drugAppearance, // 直接加入 drugappearance
          };
        })
        .where((med) => (med['missingCount'] as double) > 0)
        .toList();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('藥物辨識檢測'),
        backgroundColor: Colors.grey[300],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('正在分析藥物...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_isCameraInitialized)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 8,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CameraPreview(_cameraController!),
                          ),
                          GestureDetector(
                            onTapDown: (details) {
                              final screenSize = MediaQuery.of(context).size;
                              _setFocusPoint(details.localPosition, screenSize);
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: _focusPoint != null
                                    ? Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _isFocusing ? Colors.yellow : Colors.white,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: '用藥時段',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedTiming,
                      items: ['飯前', '飯後', '睡前'].map((timing) {
                        return DropdownMenuItem(
                          value: timing,
                          child: Text(timing),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTiming = value;
                          _fetchPatientMedications();
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _takePictureAndAnalyze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(
                        _isProcessing ? '處理中...' : '拍照並立即辨識',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  '從相簿選擇照片',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class JsonResultScreen extends StatefulWidget {
  final String? annotatedImageBase64;
  final String jsonResponse;
  final List<Map<String, dynamic>> detections;
  final List<Map<String, dynamic>> patientMedications;
  final List<Map<String, dynamic>> mismatchedMedications;
  final List<Map<String, dynamic>> missingMedications;
  final String timing; // 新增 timing 參數

  const JsonResultScreen({
    required this.annotatedImageBase64,
    required this.jsonResponse,
    required this.detections,
    required this.patientMedications,
    required this.mismatchedMedications,
    required this.missingMedications,
    required this.timing, // 新增
    Key? key,
  }) : super(key: key);

  @override
  _JsonResultScreenState createState() => _JsonResultScreenState();
}

class _JsonResultScreenState extends State<JsonResultScreen> {
  bool _isUpdating = false;

  Future<void> _confirmMedications() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      final patientId = appState.currentPatientId;
      if (patientId == null) {
        throw Exception('未選擇患者');
      }

      final employeeId = appState.currentEmployeeId;
      if (employeeId == null) {
        throw Exception('未選擇員工');
      }

      final currentDate = DateTime.now().toIso8601String().split('T')[0];

      // 第一個 SQL：更新藥物狀態
      final updateSql = '''
        UPDATE medications
        SET state = 1
        WHERE PatientID = '$patientId'
        AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$currentDate'
        AND Timing = '${widget.timing}'
      ''';

      final updateJsonData = {
        'username': appState.usernameController.text,
        'password': appState.passwordController.text,
        'requestType': 'sql update',
        'data': {'sql': updateSql},
      };

      final formattedUpdateJson = const JsonEncoder.withIndent('  ').convert(updateJsonData);
      debugPrint('Update Request JSON:\n$formattedUpdateJson');

      final updateResponse = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateJsonData),
      );

      debugPrint('Update HTTP Response Status Code: ${updateResponse.statusCode}');
      debugPrint('Update HTTP Response Body: ${updateResponse.body}');

      if (updateResponse.statusCode != 200) {
        throw Exception('更新藥物狀態失敗: HTTP ${updateResponse.statusCode}, 訊息: ${updateResponse.body}');
      }

      // 第二個 SQL：插入記錄
      final insertSql = '''
        INSERT INTO records (EmployeeID, PatientID, Type, EntryDatetime, DescribeMean)
        VALUES (
          '$employeeId',
          '$patientId',
          'yolo',
          NOW(),
          '以檢查${widget.timing}要吃的部分'
        )
      ''';

      final insertJsonData = {
        'username': appState.usernameController.text,
        'password': appState.passwordController.text,
        'requestType': 'sql update',
        'data': {'sql': insertSql},
      };

      final formattedInsertJson = const JsonEncoder.withIndent('  ').convert(insertJsonData);
      debugPrint('Insert Request JSON:\n$formattedInsertJson');

      final insertResponse = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(insertJsonData),
      );

      debugPrint('Insert HTTP Response Status Code: ${insertResponse.statusCode}');
      debugPrint('Insert HTTP Response Body: ${insertResponse.body}');

      if (insertResponse.statusCode != 200) {
        throw Exception('插入記錄失敗: HTTP ${insertResponse.statusCode}, 訊息: ${insertResponse.body}');
      }

      // 兩者都成功後顯示成功訊息並導航
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('藥物狀態更新成功')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
      Provider.of<AppState>(context, listen: false).refreshHomeData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _showDrugImageDialog(String drugName) async {
  final drugImageManager = DrugImageManager();
  debugPrint('Looking for image of $drugName');
  debugPrint('Available drug image paths: ${drugImageManager.drugImagePaths}');

  // 標準化大小寫，查找匹配的圖片路徑
  String? imagePath = drugImageManager.drugImagePaths[drugName];
  if (imagePath == null) {
    final lowerCaseDrugName = drugName.toLowerCase();
    imagePath = drugImageManager.drugImagePaths.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == lowerCaseDrugName,
          orElse: () => const MapEntry('', ''),
        )
        .value;
    debugPrint('Normalized image path for $drugName: $imagePath');
  }

  // 檢查文件存在性
  if (imagePath != null && imagePath.isNotEmpty) {
    final file = File(imagePath);
    final exists = await file.exists();
    debugPrint('File exists at $imagePath: $exists');
    if (exists) {
      final length = await file.length();
      debugPrint('File size: $length bytes');
    } else {
      debugPrint('File inaccessible or does not exist');
    }
  }

  // 確保 UI 更新
  if (mounted) {
    setState(() {});
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('藥物照片: $drugName'),
      content: SizedBox(
        width: double.maxFinite,
        height: 200,
        child: imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
            ? Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to load image at $imagePath: $error');
                  return const Text('圖片載入失敗');
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('無照片可用'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _uploadDrugImage(drugName),
                    child: const Text('上傳照片'),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    ),
  );
}

  Future<void> _uploadDrugImage(String drugName) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    if (!await imageFile.exists()) return;

    final directory = await getApplicationDocumentsDirectory();
    final drugImagesDir = Directory('${directory.path}/drug_images');
    if (!await drugImagesDir.exists()) {
      await drugImagesDir.create(recursive: true);
    }

    final cleanDrugName = drugName.replaceAll(RegExp(r'[\/\\\?\*:"<>|]'), '_');
    final newImageFile = File('${drugImagesDir.path}/$cleanDrugName.png');
    await imageFile.copy(newImageFile.path);

    final drugImageManager = DrugImageManager();
    drugImageManager.drugImagePaths[cleanDrugName] = newImageFile.path;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('drugImagePaths', jsonEncode(drugImageManager.drugImagePaths));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('照片上傳成功')),
    );

    // 關閉對話框並重新顯示
    Navigator.pop(context);
    _showDrugImageDialog(drugName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('辨識結果')),
      body: Column(
        children: [
          if (widget.annotatedImageBase64 != null && widget.annotatedImageBase64!.isNotEmpty)
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                base64Decode(widget.annotatedImageBase64!.split(',').last),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('圖片載入失敗'));
                },
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text('無標註圖片', style: TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: _buildComparisonResult(),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildComparisonResult() {
  final combinedMedications = <Map<String, dynamic>>[];
  final missingDrugNames = widget.missingMedications.map((med) => med['drugName']?.toString()).toSet();

  // 處理缺少的藥物
  combinedMedications.addAll(widget.missingMedications.map((med) => {
        'drugName': med['drugName'],
        'missingCount': med['missingCount'],
        'drugappearance': med['drugappearance'] ?? '', // 使用提前加入的 drugappearance
        'isMissing': true,
      }));

  // 處理患者藥物，排除已標記為缺少的藥物
  combinedMedications.addAll(widget.patientMedications
      .where((med) => !missingDrugNames.contains(med['drugName']?.toString()))
      .map((med) {
    double? dose;
    final rawDose = med['dose'];
    if (rawDose is num) {
      dose = rawDose.toDouble();
    }
    final formattedDose = dose != null
        ? (dose == dose.floorToDouble() ? dose.toDouble().toString() : dose.toStringAsFixed(2))
        : '未知';
    return {
      'drugName': med['drugName'],
      'dose': formattedDose,
      'rawDose': dose,
      'drugappearance': med['drugappearance'] ?? '',
      'isMissing': false,
    };
  }));

  return Column(
    children: [
      if (widget.mismatchedMedications.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            '不應該出現在照片裡的藥物:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ),
        ...widget.mismatchedMedications.map((med) => ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: Text(med['label']?.toString() ?? '未知標籤'),
              subtitle: Text('置信度: ${(med['confidence'] * 100).toStringAsFixed(2)}%'),
            )),
        const Divider(),
      ],
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          '患者藥物狀態 (${combinedMedications.length}種):',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      if (combinedMedications.isNotEmpty)
        ...combinedMedications.map((med) {
          final drugAppearance = med['drugappearance'] as String?;
          return ListTile(
            onLongPress: () => _showDrugImageDialog(med['drugName']?.toString() ?? ''),
            leading: med['isMissing']
                ? const Icon(Icons.cancel, color: Colors.red)
                : const Icon(Icons.check_circle, color: Colors.green),
            title: Text(med['drugName']?.toString() ?? '未知藥物'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med['isMissing']
                    ? '缺少數量: ${med['missingCount']}顆'
                    : '劑量: ${med['dose']}顆'),
                if (drugAppearance != null && drugAppearance.isNotEmpty)
                  Text('藥物外觀: $drugAppearance'),
              ],
            ),
          );
        })
      else
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            '無藥物數據',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[400],
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isUpdating ? null : _confirmMedications,
          child: _isUpdating
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  '確認完畢',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
        ),
      ),
    ],
  );
}
}

//看患者吃的藥有哪些
class PatientManagementScreen extends StatefulWidget {
  @override
  _PatientManagementScreenState createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _medications = [];
  String? _selectedPatientName;
  String? _selectedPatientId;
  String? _selectedTiming = '全部'; // Default dropdown value for filtering

  final List<String> _timingOptions = [
    '全部',
    '早餐前',
    '中餐前',
    '晚餐前',
    '早餐後',
    '中餐後',
    '晚餐後',
    '睡前',
  ];

  @override
  void initState() {
    super.initState();
    _loadArguments();
  }

  void _loadArguments() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return; // 確保 widget 仍存在
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          _selectedPatientName = args['patientName']?.toString();
          _selectedPatientId = args['patientId']?.toString();
        });
      }
      _fetchMedications();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '無效的患者資料';
        });
      }
    }
  });
}@override
void dispose() {
  super.dispose();
}
 Future<void> _fetchMedications() async {
  if (_selectedPatientId == null) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未選擇患者';
      });
    }
    return;
  }

  if (mounted) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  try {
    final currentDate = DateTime.now();
    final formattedCurrentDate = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

    String timingCondition = '';
    if (_selectedTiming != '全部') {
      final sanitizedTiming = _selectedTiming!.replaceAll("'", "''");
      timingCondition = "AND m.Timing = '$sanitizedTiming'";
    }

    final response = await HttpClient.instance.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': appState.usernameController.text,
        'password': appState.passwordController.text,
        'requestType': 'sql search',
        'data': {
          'sql': """
            SELECT m.PatientID, m.Added_Day, d.DrugName, m.Timing, m.Dose, m.DrugID, m.days, DATEDIFF(DATE_ADD(m.Added_Day, INTERVAL m.days DAY), CURRENT_DATE) - 1 AS DaysRemaining
            FROM medications m
            INNER JOIN drugs d ON m.DrugID = d.DrugID
            INNER JOIN (
                SELECT DrugID, MAX(Added_Day) AS Latest_Added_Day
                FROM medications
                WHERE PatientID = '$_selectedPatientId'
                GROUP BY DrugID
            ) latest ON m.DrugID = latest.DrugID AND m.Added_Day = latest.Latest_Added_Day
            WHERE m.PatientID = '$_selectedPatientId'
            AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$formattedCurrentDate'
            $timingCondition
          """
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        if (mounted) {
          setState(() {
            _medications = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('資料格式錯誤');
      }
    } else {
      throw Exception('伺服器錯誤: ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '錯誤: $e';
      });
    }
  }
}

Future<void> _deleteMedication(String drugId, String addedDay, String timing, String drugName) async {
  if (mounted) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  final patientId = appState.currentPatientId;
  final employeeId = appState.currentEmployeeId;

  if (employeeId == null) {
    throw Exception('未選擇員工');
  }

  try {
    final parsedDateTime = DateTime.parse(addedDay);
    final formattedDateTime = DateFormat('yyyy-MM-dd').format(parsedDateTime);

    final describeMean = '將$_selectedPatientName於$formattedDateTime$timing的$drugName刪除';

    final response = await HttpClient.instance.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': appState.usernameController.text,
        'password': appState.passwordController.text,
        'requestType': 'sql update',
        'data': {
          'sql': """
            DELETE FROM medications
            WHERE DrugID = '$drugId' AND PatientID = '$patientId';
            
            INSERT INTO records (EmployeeID, PatientID, Type, EntryDatetime, DescribeMean)
            VALUES (
              '$employeeId',
              '$patientId',
              '刪除患者藥物資料',
              NOW(),
              '$describeMean'
            );
          """
        },
      }),
    );

    if (response.statusCode == 200) {
      await _fetchMedications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('刪除成功')),
        );
      }
    } else {
      throw Exception('刪除失敗: ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '錯誤: $e';
      });
    }
  }
}

Future<void> _updateMedication({
  required String drugId,
  required String addedDay,
  required String timing,
  required String dose,
  required String days,
}) async {
  if (mounted) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  final patientId = appState.currentPatientId;
  final employeeId = appState.currentEmployeeId;

  if (employeeId == null) {
    throw Exception('未選擇員工');
  }

  try {
    final sanitizedTiming = timing.replaceAll("'", "''");
    final sanitizedDose = dose.replaceAll("'", "''");
    final sanitizedDays = days.replaceAll("'", "''");

    final parsedDateTime = DateTime.parse(addedDay);
    final formattedDateTime = DateFormat('yyyy-MM-dd').format(parsedDateTime);

    String describeMean = '';
    try {
      final originalMedication = _medications.firstWhere(
        (med) {
          final medDrugId = med['DrugID'].toString();
          final medTiming = med['Timing'].toString();
          final medAddedDay = med['Added_Day'].toString();
          final inputAddedDay = addedDay;
          print('Comparing: medDrugId=$medDrugId, medTiming=$medTiming, medAddedDay=$medAddedDay, inputAddedDay=$inputAddedDay');
          return medDrugId == drugId &&
                 medTiming == timing &&
                 medAddedDay == inputAddedDay;
        },
        orElse: () => <String, dynamic>{},
      );

      print('Original Medication found: $originalMedication');

      if (originalMedication.isNotEmpty) {
        final originalDose = originalMedication['Dose'].toString();
        final originalDays = originalMedication['days'].toString();
        final drugName = originalMedication['DrugName']?.toString() ?? '未知藥物';

        if (originalDose != dose && originalDays == days) {
          describeMean = '將$_selectedPatientName於$formattedDateTime$timing$drugName的劑量從$originalDose修改成$dose';
        } else if (originalDose == dose && originalDays != days) {
          describeMean = '將$_selectedPatientName於$formattedDateTime$timing$drugName的處方天數從$originalDays修改成$days';
        } else if (originalDose != dose && originalDays != days) {
          describeMean = '將$_selectedPatientName於$formattedDateTime$timing$drugName的劑量從$originalDose修改成$dose，處方天數從$originalDays修改成$days';
        } else {
          describeMean = '檢查$_selectedPatientName於$formattedDateTime$timing$drugName的用藥記錄';
        }
      } else {
        print('未找到匹配的原始藥物記錄: drugId=$drugId, addedDay=$addedDay, timing=$timing');
      }
    } catch (e) {
      print('生成描述失敗: $e');
    }

    print('Current _medications: $_medications');

    final payload = {
      'username': appState.usernameController.text,
      'password': appState.passwordController.text,
      'requestType': 'sql update',
      'data': {
        'sql': """
          UPDATE medications
          SET Dose = '$sanitizedDose', days = '$sanitizedDays'
          WHERE DrugID = '$drugId' 
            AND Added_Day = '$formattedDateTime'
            AND PatientID = '$patientId'
            AND Timing = '$sanitizedTiming';
          
          INSERT INTO records (EmployeeID, PatientID, Type, EntryDatetime, DescribeMean)
          VALUES (
            '$employeeId',
            '$patientId',
            '修改患者藥物資料',
            NOW(),
            '$describeMean'
          );
        """
      },
    };

    print('JSON Payload: ${jsonEncode(payload)}');

    final response = await HttpClient.instance.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      await _fetchMedications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新成功')),
        );
      }
    } else {
      throw Exception('更新失敗: ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = '錯誤: $e';
      });
    }
  }
}

void _showEditDialog(Map<String, dynamic> medication) {
  final doseController = TextEditingController(text: medication['Dose'].toString());
  final daysController = TextEditingController(text: medication['days'].toString());
  String? selectedTiming = medication['Timing'];
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('編輯藥物資訊'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: doseController,
                decoration: const InputDecoration(
                  labelText: '劑量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入劑量';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return '劑量必須為正整數';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: daysController,
                decoration: const InputDecoration(
                  labelText: '處方天數',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入處方天數';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '處方天數必須為正整數';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (doseController.text.isEmpty || daysController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請填寫所有字段')),
                );
                return;
              }
              if (double.tryParse(doseController.text) == null ||
                  double.parse(doseController.text) <= 0 ||
                  int.tryParse(daysController.text) == null ||
                  int.parse(daysController.text) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('劑量和處方天數必須為正整數')),
                );
                return;
              }

              Navigator.of(context).pop();
              await _updateMedication(
                drugId: medication['DrugID'].toString(),
                addedDay: medication['Added_Day'].toString(),
                timing: selectedTiming!,
                dose: doseController.text,
                days: daysController.text,
              );
              doseController.dispose();
              daysController.dispose();
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
}

Widget _buildMedicationCard(Map<String, dynamic> medication) {
  String formattedAddedDay;
  try {
    final addedDay = DateTime.parse(medication['Added_Day']);
    formattedAddedDay = DateFormat('yyyy-MM-dd').format(addedDay);
  } catch (e) {
    formattedAddedDay = medication['Added_Day'].toString();
  }

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    child: ListTile(
      title: Text(
        '藥物: ${medication['DrugName']}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('用藥時間: ${medication['Timing']}'),
          Text('劑量: ${medication['Dose']}'),
          Text('處方天數: ${medication['days']}'),
          Text('藥物食用倒數: ${medication['DaysRemaining'] >= 0 ? medication['DaysRemaining'] : 0} 天'),
          Text('添加日期: $formattedAddedDay'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              _showEditDialog(medication);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認刪除'),
                  content: Text('確定要刪除 ${medication['DrugName']} 的記錄嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _deleteMedication(
                          medication['DrugID'].toString(),
                          medication['Added_Day'].toString(),
                          medication['Timing'].toString(), // 添加 timing
                          medication['DrugName'].toString(), // 添加 drugName
                        );
                      },
                      child: const Text('確認'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('患者資料管理: ${_selectedPatientName ?? "未選擇"}'),
        backgroundColor: Colors.grey[300],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedTiming,
                        decoration: const InputDecoration(
                          labelText: '用藥時間篩選',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _timingOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedTiming = newValue;
                            });
                            _fetchMedications();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _medications.isEmpty
                            ? const Center(child: Text('無用藥記錄'))
                            : ListView.builder(
                                itemCount: _medications.length,
                                itemBuilder: (context, index) {
                                  return _buildMedicationCard(_medications[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

//按鈕類別
class FeatureButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const FeatureButton({
    required this.title,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: Colors.green[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}


//OCR
class PrescriptionCaptureScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const PrescriptionCaptureScreen({
    required this.cameras,
    required this.usernameController,
    required this.passwordController,
    Key? key,
  }) : super(key: key);

  @override
  _PrescriptionCaptureScreenState createState() => _PrescriptionCaptureScreenState();
}

class _PrescriptionCaptureScreenState extends State<PrescriptionCaptureScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;
  Offset? _focusPoint;
  bool _isFocusing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _errorMessage = '找不到可用相機';
        _isLoading = false;
      });
      return;
    }

    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '相機初始化失敗: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _setFocusPoint(Offset point, Size screenSize) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _focusPoint = point;
      _isFocusing = true;
    });

    try {
      final double x = point.dx / screenSize.width;
      final double y = point.dy / screenSize.height;

      await _cameraController!.setFocusPoint(Offset(x, y));
      await _cameraController!.setExposurePoint(Offset(x, y));
      await Future.delayed(Duration(milliseconds: 500));

      setState(() {
        _isFocusing = false;
      });
    } catch (e) {
      debugPrint('設置對焦點失敗: $e');
      setState(() {
        _isFocusing = false;
      });
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                '正在處理照片...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相機未初始化')),
        );
      }
      return;
    }

    if (appState.currentPatientName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('請先在首頁選擇病患')),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final username = widget.usernameController.text;
      final password = widget.passwordController.text;
      debugPrint('Username: $username');
      debugPrint('Password: $password');

      if (username.isEmpty || password.isEmpty) {
        throw Exception('用戶名或密碼為空');
      }

      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);

      if (_focusPoint != null) {
        final screenSize = MediaQuery.of(context).size;
        await _setFocusPoint(_focusPoint!, screenSize);
      }

      await Future.delayed(Duration(milliseconds: 500));

      // 顯示 Loading 畫面
      if (mounted) {
        showLoadingDialog(context);
      }

      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();
      final base64Image = base64Encode(bytes);

      final requestBody = jsonEncode({
        'username': username,
        'password': password,
        'requestType': 'ppocr',
        'data': {'image': 'data:image/jpeg;base64,$base64Image'}
      });
      debugPrint('Request Body: $requestBody');

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (!mounted) {
        debugPrint('PrescriptionCaptureScreen is not mounted after HTTP request');
        return;
      }

      // 隱藏 Loading 畫面
      hideLoadingDialog(context);

      if (response.statusCode == 200) {
        // 驗證響應是否為有效 JSON 物件
        try {
          final jsonData = jsonDecode(response.body);
          if (jsonData is String) {
            try {
              jsonDecode(jsonData);
            } catch (e) {
              throw Exception('服務器返回純文本或無效 JSON: $jsonData');
            }
          } else if (jsonData is! Map<String, dynamic>) {
            throw Exception('服務器返回非物件 JSON: ${jsonData.runtimeType}');
          }
        } catch (e) {
          debugPrint('Invalid JSON Response: $e');
          throw Exception('服務器返回無效 JSON: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('照片上傳成功')),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrescriptionResultScreen(
              jsonResponse: response.body,
              usernameController: widget.usernameController,
              passwordController: widget.passwordController,
            ),
          ),
        );
      } else {
        String errorMsg = '上傳失敗: HTTP ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error']?.toString() ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('處理失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _focusPoint = null;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (appState.currentPatientName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('請先在首頁選擇病患')),
        );
      }
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final username = widget.usernameController.text;
      final password = widget.passwordController.text;
      debugPrint('Username: $username');
      debugPrint('Password: $password');

      if (username.isEmpty || password.isEmpty) {
        throw Exception('用戶名或密碼為空');
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      // 顯示 Loading 畫面
      if (mounted) {
        showLoadingDialog(context);
      }

      final imageFile = File(image.path);
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        final requestBody = jsonEncode({
          'username': username,
          'password': password,
          'requestType': 'ppocr',
          'data': {'image': 'data:image/jpeg;base64,$base64Image'}
        });
        debugPrint('Request Body: $requestBody');

        final response = await HttpClient.instance.post(
          Uri.parse('https://project.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');

        if (!mounted) {
          debugPrint('PrescriptionCaptureScreen is not mounted after HTTP request');
          return;
        }

        // 隱藏 Loading 畫面
        hideLoadingDialog(context);

        if (response.statusCode == 200) {
          // 驗證響應是否為有效 JSON 物件
          try {
            final jsonData = jsonDecode(response.body);
            if (jsonData is String) {
              try {
                jsonDecode(jsonData);
              } catch (e) {
                throw Exception('服務器返回純文本或無效 JSON: $jsonData');
              }
            } else if (jsonData is! Map<String, dynamic>) {
              throw Exception('服務器返回非物件 JSON: ${jsonData.runtimeType}');
            }
          } catch (e) {
            debugPrint('Invalid JSON Response: $e');
            throw Exception('服務器返回無效 JSON: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('照片上傳成功')),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionResultScreen(
                jsonResponse: response.body,
                usernameController: widget.usernameController,
                passwordController: widget.passwordController,
              ),
            ),
          );
        } else {
          String errorMsg = '上傳失敗: HTTP ${response.statusCode}';
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['error']?.toString() ?? errorMsg;
          } catch (_) {}
          throw Exception(errorMsg);
        }
      } else {
        throw Exception('照片檔案不存在');
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('處理失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _focusPoint = null;
        });
      }
    }
  }

 void _goBackToHome() {
    // 回到 HomeScreen，保留現有頁面狀態
    Navigator.popUntil(context, ModalRoute.withName('/home'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('藥單拍照'),
        backgroundColor: Colors.grey[300],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToHome, // 自定義返回按鈕，直接回到 HomeScreen
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('正在初始化相機...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_isCameraInitialized)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 8,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CameraPreview(_cameraController!),
                          ),
                          GestureDetector(
                            onTapDown: (details) {
                              final screenSize = MediaQuery.of(context).size;
                              _setFocusPoint(details.localPosition, screenSize);
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: _focusPoint != null
                                    ? Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _isFocusing ? Colors.yellow : Colors.white,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _takePicture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(
                        _isProcessing ? '處理中...' : '拍照',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  '從相簿選擇照片',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrescriptionResultScreen extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String jsonResponse;

  PrescriptionResultScreen({
    required this.usernameController,
    required this.passwordController,
    required this.jsonResponse,
  });

  @override
  _PrescriptionResultScreenState createState() => _PrescriptionResultScreenState();
}

class _PrescriptionResultScreenState extends State<PrescriptionResultScreen> {
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _appearanceController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  String? _selectedUsage;
  String? _errorMessage;
  bool _isSaving = false;
  ScaffoldMessengerState? _scaffoldMessenger;
  String? _cachedUsername;
  String? _cachedPassword;
  final Debouncer _saveDebouncer = Debouncer(Duration(milliseconds: 500));
  Map<String, Map<String, dynamic>> _verificationCache = {}; // 快取驗證結果

  final List<String> _usageOptions = [
    '早餐前', '中餐前', '晚餐前', '早餐前,中餐前', '早餐前,晚餐前', '中餐前,晚餐前', '早餐前,中餐前,晚餐前',
    '早餐後', '中餐後', '晚餐後', '早餐後,中餐後', '早餐後,晚餐後', '中餐後,晚餐後', '早餐後,中餐後,晚餐後', '睡前',
  ];

  @override
  void initState() {
    super.initState();
    _syncAuthData();
    _checkLoginStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _parseJsonResponse();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _saveDebouncer.cancel();
    _patientNameController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _appearanceController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _checkLoginStatus() {
    if (_cachedUsername == null || _cachedPassword == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          _scaffoldMessenger?.showSnackBar(const SnackBar(content: Text('請先登錄')));
        }
      });
    }
  }

  void _syncAuthData() {
    if (_cachedUsername == null && widget.usernameController.text.isNotEmpty) {
      _cachedUsername = widget.usernameController.text;
      appState.usernameController.text = _cachedUsername!;
    }
    if (_cachedPassword == null && widget.passwordController.text.isNotEmpty) {
      _cachedPassword = widget.passwordController.text;
      appState.passwordController.text = _cachedPassword!;
    }
  }

  void _parseJsonResponse() {
    try {
      var jsonData = jsonDecode(widget.jsonResponse);
      if (jsonData is String) jsonData = jsonDecode(jsonData);
      if (jsonData is! Map<String, dynamic>) throw Exception('JSON 格式錯誤');

      String usageText = '';
      final usage = jsonData['usage'];
      if (usage is List<dynamic>) usageText = usage.map((e) => e?.toString() ?? '').join(',');
      else if (usage is String) usageText = usage;
      else if (usage != null) usageText = usage.toString();

      final validTimes = ['早餐前', '中餐前', '晚餐前', '早餐後', '中餐後', '晚餐後', '睡前'];
      final usageParts = usageText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && validTimes.contains(e))
          .toList();
      usageText = usageParts.join(',');

      final matchedOption = _usageOptions.contains(usageText) ? usageText : null;

      if (mounted) {
        setState(() {
          _patientNameController.text = appState.currentPatientName ?? '';
          _medicationController.text = jsonData['medication']?.toString() ?? '';
          _selectedUsage = matchedOption ?? _usageOptions[0];
          _dosageController.text = jsonData['dosage']?.toString() ?? '';
          _appearanceController.text = jsonData['appearance']?.toString() ?? '';
          _daysController.text = jsonData['days']?.toString() ?? '';
          _errorMessage = matchedOption == null && usageText.isNotEmpty
              ? 'JSON 用藥時間無效，已設置為默認值'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedUsage = _usageOptions[0];
          _errorMessage = 'JSON 解析錯誤: $e';
        });
      }
    }
  }

  String _sanitizeInput(String input) {
    return input.replaceAll("'", "''").replaceAll(';', '').replaceAll('--', '');
  }

  Future<Map<String, dynamic>?> _verifyPatientAndDrug(String patientName, String drugName) async {
    final cacheKey = '$patientName|$drugName';
    if (_verificationCache.containsKey(cacheKey)) return _verificationCache[cacheKey];

    try {
      final sanitizedPatientName = _sanitizeInput(patientName);
      final sanitizedDrugName = _sanitizeInput(drugName);

      final sql = """
        SELECT p.PatientID AS patient_id, d.DrugID AS drug_id
        FROM patients p, drugs d
        WHERE TRIM(LOWER(p.PatientName)) = '$sanitizedPatientName'
        AND TRIM(LOWER(d.DrugName)) = '$sanitizedDrugName'
      """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _cachedUsername,
          'password': _cachedPassword,
          'requestType': 'sql search',
          'data': {'sql': sql}
        }),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty && data[0] is Map<String, dynamic>) {
        final result = data[0];
        if (result['patient_id'] != null && result['drug_id'] != null) {
          _verificationCache[cacheKey] = {
            'patient_id': result['patient_id'],
            'drug_id': result['drug_id']
          };
          return _verificationCache[cacheKey];
        }
      } else if (data is Map<String, dynamic> && data['patient_id'] != null && data['drug_id'] != null) {
        _verificationCache[cacheKey] = {
          'patient_id': data['patient_id'],
          'drug_id': data['drug_id']
        };
        return _verificationCache[cacheKey];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _checkSimilarDrugName(String inputDrugName) async {
    try {
      final sanitizedDrugName = _sanitizeInput(inputDrugName);
      final sql = """
        SELECT DrugName
        FROM drugs
        WHERE levenshtein_enhanced(DrugName, '$sanitizedDrugName') <= 2
        AND DrugName != '$sanitizedDrugName'
        LIMIT 1
      """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _cachedUsername,
          'password': _cachedPassword,
          'requestType': 'sql search',
          'data': {'sql': sql}
        }),
      );

      if (response.statusCode != 200) return null;

      final responseData = jsonDecode(response.body);
      if (responseData is List && responseData.isNotEmpty) {
        return responseData[0]['DrugName']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _addDrugToDatabase(String drugName, String drugAppearance) async {
    try {
      final sanitizedDrugName = _sanitizeInput(drugName);
      final sanitizedDrugAppearance = _sanitizeInput(drugAppearance);
      final sql = """
        INSERT INTO drugs (DrugName, DrugAppearance)
        VALUES ('$sanitizedDrugName', '$sanitizedDrugAppearance');
      """;

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _cachedUsername,
          'password': _cachedPassword,
          'requestType': 'sql update',
          'data': {'sql': sql}
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw e;
    }
  }

  void _showSimilarDrugDialog(String inputDrugName, String similarDrugName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('找到相似的藥物名稱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您輸入的藥物名稱：$inputDrugName'),
            const SizedBox(height: 8),
            Text('資料庫中的相似名稱：$similarDrugName'),
            const SizedBox(height: 16),
            const Text(
              '在資料庫裡有找到相似的名稱 請確認是否是這名稱',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showNewDrugConfirmationDialog(inputDrugName);
            },
            child: const Text('並不是這個藥名'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (mounted) {
                setState(() => _medicationController.text = similarDrugName);
                await _saveToServer();
              }
            },
            child: const Text('確認上傳'),
          ),
        ],
      ),
    );
  }

  void _showNewDrugConfirmationDialog(String inputDrugName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認新藥物'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您準備輸入的藥物名稱：$inputDrugName'),
            const SizedBox(height: 16),
            const Text(
              '現在尚未登記此種藥物 確認無誤後會先將藥物傳到資料庫後再更新患者資料',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    Navigator.of(context).pop();
                    if (!mounted) return;
                    setState(() => _isSaving = true);
                    try {
                      final success = await _addDrugToDatabase(inputDrugName, _appearanceController.text);
                      if (!success) throw Exception('無法將藥物名稱添加到資料庫');
                      if (mounted) {
                        setState(() => _medicationController.text = inputDrugName);
                        await _saveToServer(force: true);
                        if (_scaffoldMessenger != null) {
                          _scaffoldMessenger!.showSnackBar(const SnackBar(content: Text('資料保存成功')));
                        }
                      }
                    } catch (e) {
                      if (mounted && _scaffoldMessenger != null) {
                        _scaffoldMessenger!.showSnackBar(SnackBar(content: Text('錯誤: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
            child: const Text('確認上傳'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToServer({bool force = false}) async {
    if (_isSaving && !force) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      if (appState.currentPatientName == null || _medicationController.text.isEmpty ||
          _selectedUsage == null || _dosageController.text.isEmpty || _daysController.text.isEmpty) {
        throw Exception('請填寫所有必要字段');
      }
      final employeeId = appState.currentEmployeeId;
      if (employeeId == null) throw Exception('未選擇員工');

      final patientName = _sanitizeInput(appState.currentPatientName!);
      final medication = _sanitizeInput(_medicationController.text);
      final dose = _sanitizeInput(_dosageController.text);
      final days = _sanitizeInput(_daysController.text);

      final doseNum = double.tryParse(dose);
      final daysNum = int.tryParse(days);
      if (doseNum == null || daysNum == null) throw Exception('劑量和處方天數必須為數字');

      final usageTimes = _selectedUsage!.split(',').map((e) => e.trim()).toList();
      if (usageTimes.isEmpty) throw Exception('用藥時間無效');

      final validTimes = ['早餐前', '中餐前', '晚餐前', '早餐後', '中餐後', '晚餐後', '睡前'];
      if (usageTimes.any((time) => !validTimes.contains(time))) {
        throw Exception('無效的用藥時間');
      }

      // 使用快取的驗證結果
      final verificationResult = await _verifyPatientAndDrug(patientName, medication);
      if (verificationResult != null) {
        final patientId = verificationResult['patient_id'];
        final drugId = verificationResult['drug_id'];

        // 整合所有 SQL 語句為單一事務
        final sqlStatements = usageTimes.map((timing) {
          final sanitizedTiming = _sanitizeInput(timing);
          return """
            INSERT INTO medications (PatientID, DrugID, Timing, Dose, days)
            VALUES ('$patientId', '$drugId', '$sanitizedTiming', '$dose', '$days');
            INSERT INTO records (EmployeeID, PatientID, Type, EntryDatetime, DescribeMean)
            VALUES ('$employeeId', '$patientId', 'ocr', NOW(), '新增$patientName $sanitizedTiming 的藥物進資料庫');
          """;
        }).join('');

        final sql = """
          BEGIN;
          $sqlStatements
          COMMIT;
        """;

        // 準備並發送單一 SQL 更新請求
        final sqlUpdateRequestBody = {
          'username': _cachedUsername,
          'password': _cachedPassword,
          'requestType': 'sql update',
          'data': {'sql': sql}
        };

        final sqlUpdateResponse = await http.post(
          Uri.parse('https://project.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(sqlUpdateRequestBody),
        );

        if (sqlUpdateResponse.statusCode != 200) {
          throw Exception('保存失敗: HTTP ${sqlUpdateResponse.statusCode}');
        }

        // 並行發送 sendDataToPC 請求
        final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
        final pairCode = appState.pairCode;
        final sendDataToPCData = usageTimes.map((timing) => {
          'patient_name': patientName,
          'medication': medication,
          'usage': [timing],
          'dosage': doseNum,
          'appearance': _appearanceController.text.isNotEmpty ? _appearanceController.text : '未知',
          'days': daysNum,
        }).toList();

        final sendDataToPCRequestBody = {
          'username': _cachedUsername,
          'password': _cachedPassword,
          'requestType': 'sendDataToPC',
          'data': {'ocr': sendDataToPCData, 'id': pairCode}
        };

        final sendDataToPCResponse = await http.post(
          Uri.parse('https://connect.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(sendDataToPCRequestBody),
        );

        if (sendDataToPCResponse.statusCode != 200) {
          debugPrint('Send Data to PC failed: HTTP ${sendDataToPCResponse.statusCode}');
        }

        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(const SnackBar(content: Text('資料保存成功')));
          _resetForm();
          Navigator.pop(context);
          Provider.of<AppState>(context, listen: false).refreshHomeData();
        }
      } else {
        final similarDrug = await _checkSimilarDrugName(medication);
        if (mounted) {
          if (similarDrug != null) _showSimilarDrugDialog(medication, similarDrug);
          else _showNewDrugConfirmationDialog(medication);
        }
      }
    } catch (e) {
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(SnackBar(content: Text('錯誤: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    if (!mounted) return;
    _medicationController.clear();
    _dosageController.clear();
    _appearanceController.clear();
    _daysController.clear();
    setState(() {
      _selectedUsage = _usageOptions[0];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('藥單辨識結果'),
        backgroundColor: Colors.grey[300],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              TextField(
                controller: _patientNameController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '患者姓名',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: '藥物名稱',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUsage,
                decoration: const InputDecoration(
                  labelText: '用藥時間',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _usageOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedUsage = newValue);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: '劑量',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _appearanceController,
                decoration: const InputDecoration(
                  labelText: '藥物外觀',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: '處方天數',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _saveDebouncer.run(() => _saveToServer()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[400],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? '保存中...' : '保存',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


//員工修改
class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  _EmployeeManagementScreenState createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late AppState _appState;
  late ScaffoldMessengerState _scaffoldMessenger;
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchEmployees();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = Provider.of<AppState>(context, listen: false);
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    if (!mounted || _appState.centerId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);
      final sql = '''
        SELECT EmployeeID, EmployeeName, EmployeePicture, states
        FROM employees
        WHERE CenterID = '${_appState.centerId}' AND states = 1
      ''';

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json', 'Accept-Encoding': 'gzip'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode != 200) throw Exception('伺服器錯誤: ${response.statusCode}');
      final data = jsonDecode(response.body) as List<dynamic>;
      if (mounted) {
        setState(() {
          _employees = data.map((item) {
            final picture = item['EmployeePicture']?.toString();
            return {
              'EmployeeID': item['EmployeeID']?.toString() ?? '未知ID',
              'EmployeeName': item['EmployeeName']?.toString() ?? '未知姓名',
              'EmployeePicture': picture,
              'state': item['state'] as int? ?? 1,
            };
          }).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = '獲取員工資料失敗: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEmployee(Map<String, dynamic> employee) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認停用？'),
        content: Text('確定要停用員工 ${employee['EmployeeName']} 嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (!mounted) return;
              try {
                final sql = '''
                  UPDATE employees
                  SET states = 0
                  WHERE EmployeeID = '${employee['EmployeeID']}' AND CenterID = '${_appState.centerId}'
                ''';
                final response = await http.post(
                  Uri.parse('https://project.1114580.xyz/data'),
                  headers: {'Content-Type': 'application/json', 'Accept-Encoding': 'gzip'},
                  body: jsonEncode({
                    'username': _appState.usernameController.text,
                    'password': _appState.passwordController.text,
                    'requestType': 'sql update',
                    'data': {'sql': sql},
                  }),
                );
                if (response.statusCode == 200) {
                  if (mounted) {
                    await _fetchEmployees();
                    _scaffoldMessenger.showSnackBar(const SnackBar(content: Text('員工已停用')));
                  }
                } else throw Exception('停用失敗: HTTP ${response.statusCode}');
              } catch (e) {
                if (mounted) _scaffoldMessenger.showSnackBar(SnackBar(content: Text('停用員工失敗: $e')));
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  bool _isValidBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return false;
    try {
      final cleanStr = base64Str.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
      return cleanStr.length % 4 == 0 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanStr);
    } catch (e) {
      return false;
    }
  }

  Future<File?> _pickAndCropImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedImage == null) return null;

      final imageFile = File(pickedImage.path);
      if (!await imageFile.exists() || await imageFile.length() > 5 * 1024 * 1024) return null;

      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      final size = decodedImage.width < decodedImage.height ? decodedImage.width : decodedImage.height;
      final croppedImage = img.copyCrop(decodedImage, x: (decodedImage.width - size) ~/ 2, y: (decodedImage.height - size) ~/ 2, width: size, height: size);
      final resizedImage = img.copyResize(croppedImage, width: 640, height: 640, interpolation: img.Interpolation.average);

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/resized_image.jpg');
      int quality = 70;
      await tempFile.writeAsBytes(img.encodeJpg(resizedImage, quality: quality));

      if (await tempFile.length() > 500 * 1024) {
        quality = 50;
        await tempFile.writeAsBytes(img.encodeJpg(resizedImage, quality: quality));
      }

      return await tempFile.length() > 500 * 1024 ? null : tempFile;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('圖片處理失敗: $e')));
      return null;
    }
  }

  Future<void> _addEmployee() async {
    if (!mounted) return;
    final employeeName = _nameController.text.trim();
    if (employeeName.isEmpty) {
      _scaffoldMessenger.showSnackBar(const SnackBar(content: Text('請輸入員工姓名')));
      return;
    }

    try {
      String? base64Image = _selectedImage != null ? base64Encode(await _selectedImage!.readAsBytes()) : null;
      final sql = '''
        INSERT INTO employees (EmployeeName, EmployeePicture, CenterID, states)
        VALUES ('${employeeName.replaceAll("'", "''")}', ${base64Image ?? 'null'}, '${_appState.centerId}', 1)
      ''';
      print(sql);
      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json', 'Accept-Encoding': 'gzip'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode == 200) {
        await _fetchEmployees();
        _scaffoldMessenger.showSnackBar(const SnackBar(content: Text('員工已新增')));
      } else throw Exception('新增失敗: HTTP ${response.statusCode}');
    } catch (e) {
      _scaffoldMessenger.showSnackBar(SnackBar(content: Text('新增員工失敗: $e')));
    }
  }

  Future<void> _updateEmployee(String employeeId) async {
    if (!mounted) return;
    final employeeName = _nameController.text.trim();
    if (employeeName.isEmpty) {
      _scaffoldMessenger.showSnackBar(const SnackBar(content: Text('請輸入員工姓名')));
      return;
    }

    try {
      String? base64Image = _selectedImage != null ? base64Encode(await _selectedImage!.readAsBytes()) : null;
      final sql = '''
        UPDATE employees
        SET EmployeeName = '${employeeName.replaceAll("'", "''")}', EmployeePicture = ${base64Image ?? 'null'}
        WHERE EmployeeID = '$employeeId' AND CenterID = '${_appState.centerId}'
      ''';
      print(sql);
      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json', 'Accept-Encoding': 'gzip'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode == 200) {
        await _fetchEmployees();
        _scaffoldMessenger.showSnackBar(const SnackBar(content: Text('員工已更新')));
      } else throw Exception('更新失敗: HTTP ${response.statusCode}');
    } catch (e) {
      _scaffoldMessenger.showSnackBar(SnackBar(content: Text('更新員工失敗: $e')));
    }
  }

  void _showAddEmployeeDialog() {
    _nameController.clear();
    _selectedImage = null;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '員工姓名',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedImage = await _pickAndCropImage(dialogContext);
                    if (pickedImage != null && dialogContext.mounted) setDialogState(() => _selectedImage = pickedImage);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('選擇照片', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.grey))
                      : const Icon(Icons.person, size: 100, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('離開', style: TextStyle(color: Colors.white))),
                    TextButton(
                      onPressed: () async {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('請輸入員工姓名')));
                          return;
                        }
                        await _addEmployee();
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      },
                      child: const Text('確認上傳', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditEmployeeDialog(Map<String, dynamic> employee) {
    _nameController.text = employee['EmployeeName'] ?? '';
    _selectedImage = null;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '員工姓名',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedImage = await _pickAndCropImage(dialogContext);
                    if (pickedImage != null && dialogContext.mounted) setDialogState(() => _selectedImage = pickedImage);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[400]),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text('選擇照片', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.grey))
                      : _isValidBase64(employee['EmployeePicture'])
                          ? Image.memory(base64Decode(employee['EmployeePicture']), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.grey))
                          : const Icon(Icons.person, size: 100, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('離開', style: TextStyle(color: Colors.white))),
                    TextButton(
                      onPressed: () async {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('請輸入員工姓名')));
                          return;
                        }
                        Navigator.of(dialogContext).pop(); // 先關閉彈出視窗
                        await _updateEmployee(employee['EmployeeID']); // 然後執行更新操作
                      },
                      child: const Text('確認修改', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddEmployeeButton() {
    return ElevatedButton.icon(
      onPressed: _showAddEmployeeDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[400],
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('新增員工', style: TextStyle(fontSize: 18, color: Colors.white), overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('員工管理'), backgroundColor: Colors.grey[300]),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _employees.isEmpty
                        ? const Center(child: Text('無員工資料'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _employees.length,
                            itemBuilder: (context, index) {
                              final employee = _employees[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.person, size: 50),
                                  title: Text('${employee['EmployeeID']}.${employee['EmployeeName']}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showEditEmployeeDialog(employee),
                                        tooltip: '修改',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteEmployee(employee),
                                        tooltip: '停用',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildAddEmployeeButton(),
          ),
        ],
      ),
    );
  }
}
//審核日誌
class ReviewJournalScreen extends StatefulWidget {
  const ReviewJournalScreen({Key? key}) : super(key: key);

  @override
  State<ReviewJournalScreen> createState() => _ReviewJournalScreenState();
}

class _ReviewJournalScreenState extends State<ReviewJournalScreen> {
  late AppState _appState;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _patients = [];
  List<String> _types = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _limit = 10;
  int _offset = 0;
  bool _hasMore = true;

  String? _selectedEmployeeId;
  String? _selectedPatientId;
  String? _selectedType;
  DateTime? _selectedDate;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preLoadData();
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore &&
          !_isLoading) {
        _fetchMoreRecords();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = Provider.of<AppState>(context, listen: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preLoadData() async {
    if (_appState.cachedEmployees.isNotEmpty) {
      if (mounted) {
        setState(() {
          _employees = _appState.cachedEmployees;
        });
      }
    }
    if (_appState.cachedPatients.isNotEmpty) {
      if (mounted) {
        setState(() {
          _patients = _appState.cachedPatients;
        });
      }
    }
    final cacheKey = _generateCacheKey();
    final cachedRecords = _appState.getCachedRecords(cacheKey);
    if (cachedRecords != null) {
      if (mounted) {
        setState(() {
          _records = cachedRecords;
          _isLoading = false;
        });
      }
    }

    await Future.wait([
      _fetchEmployees(),
      _fetchPatients(),
      _fetchRecords(isRefresh: true, initialLoad: true),
    ]);
  }

  Future<void> _fetchEmployees() async {
    if (_appState.cachedEmployees.isNotEmpty) {
      if (mounted) {
        setState(() {
          _employees = _appState.cachedEmployees;
          _isLoading = _records.isEmpty;
        });
      }
      return;
    }

    if (_appState.centerId == null) {
      debugPrint('Center ID is null, skipping employee fetch');
      _employees = [];
      return;
    }

    try {
      final sql = '''
        SELECT EmployeeID, EmployeeName
        FROM employees
        WHERE CenterID = '${_appState.centerId}' AND states = 1
      ''';

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final List<Map<String, dynamic>> employees = data.map((item) {
        final employeeName = item['EmployeeName']?.toString() ?? '';
        return <String, dynamic>{
          'EmployeeID': item['EmployeeID']?.toString() ?? '未知ID',
          'EmployeeName': employeeName.isEmpty ? '未知姓名' : employeeName,
        };
      }).toList();

      _appState.cacheEmployees(employees);

      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = _records.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      if (mounted) {
        setState(() {
          _employees = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPatients() async {
    if (_appState.cachedPatients.isNotEmpty) {
      if (mounted) {
        setState(() {
          _patients = _appState.cachedPatients;
        });
      }
      return;
    }

    if (_appState.centerId == null) {
      debugPrint('Center ID is null, skipping patient fetch');
      _patients = [];
      return;
    }

    try {
      final sql = '''
        SELECT DISTINCT PatientID, PatientName
        FROM patients
        WHERE CenterID = '${_appState.centerId}'
      ''';

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final List<Map<String, dynamic>> patients = data.map((item) {
        final patientName = item['PatientName']?.toString() ?? item['PatientID']?.toString() ?? '';
        return <String, dynamic>{
          'PatientID': item['PatientID']?.toString() ?? '',
          'PatientName': patientName.isEmpty ? '無名稱' : patientName,
        };
      }).toList();

      _appState.cachePatients(patients);

      if (mounted) {
        setState(() {
          _patients = patients;
        });
      }
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      if (mounted) {
        setState(() {
          _patients = [];
        });
      }
    }
  }

  String _generateCacheKey() {
    return '${_selectedEmployeeId ?? ''}_${_selectedPatientId ?? ''}_${_selectedType ?? ''}_${_selectedDate?.toIso8601String() ?? ''}_$_offset';
  }

  Future<void> _fetchRecords({bool isRefresh = true, bool initialLoad = false}) async {
    if (_appState.centerId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '未找到中心 ID';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (isRefresh) {
        _offset = 0;
        _hasMore = true;
        if (!initialLoad) {
          if (mounted) {
            setState(() {
              _records = [];
              _isLoading = true;
            });
          }
        }
      }

      final cacheKey = _generateCacheKey();
      final cachedRecords = _appState.getCachedRecords(cacheKey);
      if (cachedRecords != null && !isRefresh) {
        if (mounted) {
          setState(() {
            _records.addAll(cachedRecords);
            _isLoading = false;
            _isLoadingMore = false;
            _offset += _limit;
            _hasMore = cachedRecords.length == _limit;
          });
        }
        return;
      }

      List<String> conditions = [];
      if (_selectedEmployeeId != null) conditions.add("EmployeeID = '$_selectedEmployeeId'");
      if (_selectedPatientId != null) conditions.add("PatientID = '$_selectedPatientId'");
      if (_selectedType != null) conditions.add("Type = '$_selectedType'");
      if (_selectedDate != null) {
        final dateStr = _selectedDate!.toIso8601String().split('T')[0];
        conditions.add("DATE(EntryDatetime) = '$dateStr'");
      }
      String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

      final sql = '''
        SELECT EmployeeID, PatientID, Type, EntryDatetime, DescribeMean
        FROM records
        $whereClause
        ORDER BY EntryDatetime DESC
        LIMIT $_limit OFFSET $_offset
      ''';

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final List<Map<String, dynamic>> records = data.map((item) {
        return {
          'EmployeeID': item['EmployeeID']?.toString() ?? '',
          'PatientID': item['PatientID']?.toString() ?? '',
          'Type': item['Type']?.toString() ?? '',
          'EntryDatetime': item['EntryDatetime']?.toString() ?? '',
          'DescribeMean': item['DescribeMean']?.toString() ?? '',
        };
      }).toList();

      if (_types.isEmpty) {
        final typeSql = '''
          SELECT DISTINCT Type
          FROM records
        ''';
        final typeResponse = await http.post(
          Uri.parse('https://project.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _appState.usernameController.text,
            'password': _appState.passwordController.text,
            'requestType': 'sql search',
            'data': {'sql': typeSql},
          }),
        );

        if (typeResponse.statusCode == 200) {
          final typeData = jsonDecode(typeResponse.body) as List<dynamic>;
          _types = typeData.map((item) => item['Type']?.toString() ?? '').toList();
        } else {
          throw Exception('獲取操作類型失敗: ${typeResponse.statusCode}');
        }
      }

      _appState.cacheRecords(cacheKey, records);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _records = records;
          } else {
            _records.addAll(records);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
          _offset += _limit;
          _hasMore = records.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '獲取日誌資料失敗: $e';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _fetchRecords(isRefresh: false);
  }

  String _getEmployeeName(String employeeId) {
    final employee = _employees.firstWhere(
      (emp) => emp['EmployeeID'] == employeeId,
      orElse: () => <String, dynamic>{'EmployeeID': '', 'EmployeeName': ''},
    );
    return employee['EmployeeName']?.toString() ?? '';
  }

  String _getPatientName(String patientId) {
    final patient = _patients.firstWhere(
      (pat) => pat['PatientID'] == patientId,
      orElse: () => <String, dynamic>{'PatientID': '', 'PatientName': ''},
    );
    return patient['PatientName']?.toString() ?? patientId;
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  Future<void> _addMedicationRecord() async {
    if (_appState.centerId == null) return;

    try {
      final employee = _employees.firstWhere((emp) => emp['EmployeeName'] == 'Dr. Emily',
          orElse: () => <String, dynamic>{'EmployeeID': ''});
      final employeeId = employee['EmployeeID'];
      final patientId = '2133';
      final type = '早餐後';
      final describeMean = '新增2133的藥物';
      final entryDatetime = DateTime.now().toIso8601String();

      final sql = '''
        INSERT INTO records (EmployeeID, PatientID, Type, EntryDatetime, DescribeMean, CenterID)
        VALUES ('$employeeId', '$patientId', '$type', '$entryDatetime', '$describeMean', '${_appState.centerId}')
      ''';

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _appState.usernameController.text,
          'password': _appState.passwordController.text,
          'requestType': 'sql execute',
          'data': {'sql': sql},
        }),
      );

      if (response.statusCode == 200) {
        _fetchRecords(isRefresh: true);
      } else {
        throw Exception('新增記錄失敗: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '新增記錄失敗: $e';
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? currentSelectedDate = _selectedDate; // 臨時儲存當前選中日期
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('選擇日期'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    child: CalendarDatePicker(
                      initialDate: currentSelectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      onDateChanged: (DateTime value) {
                        setState(() {
                          currentSelectedDate = value; // 更新臨時選中日期
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, null); // 取消，不改變日期
                        },
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, DateTime(0)); // 清空，使用 Unix 紀元作為清空標記
                        },
                        child: const Text('清空'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, currentSelectedDate); // 確認，傳回當前選中的日期
                        },
                        child: const Text('確認'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      if (picked == DateTime(0)) {
        // 檢測到清空操作
        if (mounted) {
          setState(() {
            _selectedDate = null;
          });
          _fetchRecords();
        }
      } else if (picked != _selectedDate && mounted) {
        // 正常選擇日期
        setState(() {
          _selectedDate = picked;
        });
        _fetchRecords();
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      FocusScope.of(context).unfocus();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('審核日誌'),
        backgroundColor: Colors.grey[300],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addMedicationRecord,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final input = textEditingValue.text.trim().toLowerCase();
                      if (input.isEmpty) {
                        return _employees.map((emp) => emp['EmployeeName'] as String);
                      }
                      return _employees
                          .map((emp) => emp['EmployeeName'] as String)
                          .where((name) => name.toLowerCase().contains(input));
                    },
                    onSelected: (String selection) {
                      debugPrint('員工選擇: $selection'); // 添加調試日誌
                      final selectedEmployee = _employees.firstWhere(
                        (emp) => emp['EmployeeName'] == selection,
                        orElse: () => <String, dynamic>{'EmployeeID': null},
                      );
                      if (_selectedEmployeeId != selectedEmployee['EmployeeID']) {
                        setState(() {
                          _selectedEmployeeId = selectedEmployee['EmployeeID'];
                        });
                        FocusScope.of(context).unfocus(); // 嘗試收起鍵盤
                        _fetchRecords();
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: '篩選員工',
                          border: const OutlineInputBorder(),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      controller.clear();
                                      _selectedEmployeeId = null;
                                    });
                                    _fetchRecords();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (value) {
                          debugPrint('員工提交: $value'); // 添加調試日誌
                          final selectedEmployee = _employees.firstWhere(
                            (emp) => emp['EmployeeName'] == value,
                            orElse: () => <String, dynamic>{'EmployeeID': null},
                          );
                          if (_selectedEmployeeId != selectedEmployee['EmployeeID']) {
                            setState(() {
                              _selectedEmployeeId = selectedEmployee['EmployeeID'];
                            });
                            FocusScope.of(context).unfocus();
                            _fetchRecords();
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final input = textEditingValue.text.trim().toLowerCase();
                      if (input.isEmpty) {
                        return _patients.map((pat) => pat['PatientName'] as String);
                      }
                      return _patients
                          .map((pat) => pat['PatientName'] as String)
                          .where((name) => name.toLowerCase().contains(input));
                    },
                    onSelected: (String selection) {
                      debugPrint('病患選擇: $selection'); // 添加調試日誌
                      final selectedPatient = _patients.firstWhere(
                        (pat) => pat['PatientName'] == selection,
                        orElse: () => <String, dynamic>{'PatientID': null},
                      );
                      if (_selectedPatientId != selectedPatient['PatientID']) {
                        setState(() {
                          _selectedPatientId = selectedPatient['PatientID'];
                        });
                        FocusScope.of(context).unfocus(); // 嘗試收起鍵盤
                        _fetchRecords();
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: '篩選病患',
                          border: const OutlineInputBorder(),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      controller.clear();
                                      _selectedPatientId = null;
                                    });
                                    _fetchRecords();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (value) {
                          debugPrint('病患提交: $value'); // 添加調試日誌
                          final selectedPatient = _patients.firstWhere(
                            (pat) => pat['PatientName'] == value,
                            orElse: () => <String, dynamic>{'PatientID': null},
                          );
                          if (_selectedPatientId != selectedPatient['PatientID']) {
                            setState(() {
                              _selectedPatientId = selectedPatient['PatientID'];
                            });
                            FocusScope.of(context).unfocus();
                            _fetchRecords();
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final input = textEditingValue.text.trim().toLowerCase();
                      if (input.isEmpty) {
                        return _types;
                      }
                      return _types.where((type) => type.toLowerCase().contains(input));
                    },
                    onSelected: (String selection) {
                      debugPrint('操作類型選擇: $selection'); // 添加調試日誌
                      if (_selectedType != selection) {
                        setState(() {
                          _selectedType = selection;
                        });
                        FocusScope.of(context).unfocus(); // 嘗試收起鍵盤
                        _fetchRecords();
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: '篩選操作類型',
                          border: const OutlineInputBorder(),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      controller.clear();
                                      _selectedType = null;
                                    });
                                    _fetchRecords();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (value) {
                          debugPrint('操作類型提交: $value'); // 添加調試日誌
                          if (_selectedType != value) {
                            setState(() {
                              _selectedType = value;
                            });
                            FocusScope.of(context).unfocus();
                            _fetchRecords();
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: TextEditingController(
                          text: _selectedDate == null
                              ? ''
                              : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                        ),
                        decoration: const InputDecoration(
                          labelText: '篩選日期',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _records.isEmpty
                        ? const Center(child: Text('無日誌資料'))
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _records.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _records.length && _hasMore) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final record = _records[index];
                              final employeeName = _getEmployeeName(record['EmployeeID']);
                              final patientName = _getPatientName(record['PatientID']);
                              final formattedDateTime = _formatDateTime(record['EntryDatetime']);
                              return Card(
                                key: ValueKey(record['EntryDatetime']),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$employeeName ${record['DescribeMean']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '操作功能: ${record['Type']}\n修改時間: $formattedDateTime',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    ),
  );
}
}
//預載圖片
class DrugImageManager {
  static final DrugImageManager _instance = DrugImageManager._internal();
  factory DrugImageManager() => _instance;
  DrugImageManager._internal();

  // 手動定義版本號，每次更新應用程式版本時修改此值
  static const String appVersion = '1.0.2'; // 假設當前版本為 1.0.0

  Map<String, String> _drugImagePaths = {};
  Map<String, String> get drugImagePaths => _drugImagePaths;

  Future<void> initialize(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // 從 SharedPreferences 中獲取儲存的版本號
    final storedVersion = prefs.getString('appVersion');
    debugPrint('DrugImageManager: Current version: $appVersion');
    debugPrint('DrugImageManager: Stored version: $storedVersion');

    // 檢查版本是否更新
    bool shouldRefreshImages = storedVersion == null || storedVersion != appVersion;
    debugPrint('DrugImageManager: Should refresh images: $shouldRefreshImages');

    if (shouldRefreshImages) {
      // 版本更新，清除圖片並重新下載
      await _clearDrugImages();
      await _downloadDrugImages(username, password);
      // 更新儲存的版本號
      await prefs.setString('appVersion', appVersion);
      debugPrint('DrugImageManager: Updated stored version to $appVersion');
    } else {
      // 版本未變，從 SharedPreferences 載入圖片路徑
      final drugPaths = prefs.getString('drugImagePaths');
      debugPrint('DrugImageManager: Loaded drugPaths from SharedPreferences: $drugPaths');
      if (drugPaths != null) {
        try {
          _drugImagePaths = Map<String, String>.from(jsonDecode(drugPaths));
        } catch (e) {
          debugPrint('DrugImageManager: Failed to parse drugPaths: $e');
          _drugImagePaths = {};
        }
      }
    }
    debugPrint('DrugImageManager initialized. Paths: $_drugImagePaths');
  }

  Future<void> _clearDrugImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final drugImagesDir = Directory('${directory.path}/drug_images');
      if (await drugImagesDir.exists()) {
        await drugImagesDir.delete(recursive: true);
        debugPrint('DrugImageManager: Cleared drug_images directory');
      }
      _drugImagePaths.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('drugImagePaths');
      debugPrint('DrugImageManager: Cleared drugImagePaths from SharedPreferences');
    } catch (e) {
      debugPrint('DrugImageManager: Failed to clear drug images: $e');
    }
  }
  Future<void> _processImage(Map<String, dynamic> item) async {
    final drugName = item['DrugName']?.toString().trim() ?? '';
    final base64Image = item['drugpicture']?.toString() ?? '';
    if (drugName.isNotEmpty && base64Image.isNotEmpty) {
      final imageBytes = base64Decode(base64Image);
      final directory = await getApplicationDocumentsDirectory();
      final cleanDrugName = drugName.replaceAll(RegExp(r'[\/\\\?\*:"<>|]'), '_');
      final imageFile = File('${directory.path}/drug_images/$cleanDrugName.png');
      await imageFile.writeAsBytes(imageBytes);
      _drugImagePaths[drugName] = imageFile.path;
    }
  }
  Future<void> _downloadDrugImages(String username, String password) async {
    try {
      debugPrint('DrugImageManager: Starting download of drug images...');
      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'getPhoto',
        }),
      );
      
      debugPrint('DrugImageManager: HTTP Response Status: ${response.statusCode}');
      debugPrint('DrugImageManager: HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('DrugImageManager: Downloaded drug data: $data');
        final directory = await getApplicationDocumentsDirectory();
        final drugImagesDir = Directory('${directory.path}/drug_images');
        if (!await drugImagesDir.exists()) {
          await drugImagesDir.create(recursive: true);
          debugPrint('DrugImageManager: Created directory at ${drugImagesDir.path}');
        }

        for (var item in data) {
          final drugName = item['DrugName']?.toString().trim() ?? '';
          final base64Image = item['drugpicture']?.toString() ?? '';

          debugPrint('DrugImageManager: Processing drugName: $drugName');
          if (drugName.isNotEmpty && base64Image.isNotEmpty) {
            try {
              final imageBytes = base64Decode(base64Image);
              final cleanDrugName = drugName.replaceAll(RegExp(r'[\/\\\?\*:"<>|]'), '_');
              final imageFile = File('${drugImagesDir.path}/$cleanDrugName.png');
              await imageFile.writeAsBytes(imageBytes);
              _drugImagePaths[drugName] = imageFile.path;
              debugPrint('DrugImageManager: Saved image for $drugName at ${imageFile.path}');
            } catch (e) {
              debugPrint('DrugImageManager: Failed to decode/save image for $drugName: $e');
            }
          } else {
            debugPrint('DrugImageManager: Skipped $drugName: Empty drugName or image');
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('drugImagePaths', jsonEncode(_drugImagePaths));
        debugPrint('DrugImageManager: Saved drugImagePaths to SharedPreferences: $_drugImagePaths');
      } else {
        throw Exception('下載藥物圖片失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('DrugImageManager: 下載藥物圖片錯誤: $e');
    }
  }
}