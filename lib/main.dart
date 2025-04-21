import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // 用於處理檔案路徑
import 'dart:convert'; // 用於 Base64 編碼
import 'app_state.dart'; // 添加這行導入
import 'package:http/http.dart' as http; // 導入 http 套件
import 'package:flutter/services.dart'; // 用於 Clipboard



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
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
              cameras: cameras,
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
    });

    final loginJsonData = {
      "username": widget.usernameController.text,
      "password": widget.passwordController.text,
      "requestType": "sql search",
      "data": {
        "sql": "SELECT CenterID, CenterAccount, CenterPassword FROM accounts"
      }
    };

    try {
      final loginResponse = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginJsonData),
      );

      dynamic loginResponseData = jsonDecode(loginResponse.body);

      if (loginResponseData is List) {
        bool isValid = false;
        String? matchedCenterId;

        for (var account in loginResponseData) {
          if (account['CenterAccount'] == widget.usernameController.text &&
              account['CenterPassword'] == widget.passwordController.text) {
            isValid = true;
            matchedCenterId = account['CenterID']?.toString();
            break;
          }
        }

        if (isValid && matchedCenterId != null) {
          appState.setCenterId(matchedCenterId);

          final patientsJsonData = {
            "username": widget.usernameController.text,
            "password": widget.passwordController.text,
            "requestType": "sql search",
            "data": {
              "sql": "SELECT PatientID, PatientName FROM patients WHERE CenterID = '$matchedCenterId'"
            }
          };

          final patientsResponse = await http.post(
            Uri.parse('https://project.1114580.xyz/data'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(patientsJsonData),
          );

          dynamic patientsResponseData = jsonDecode(patientsResponse.body);

          if (patientsResponseData is List && patientsResponseData.isNotEmpty) {
            appState.setPatients(patientsResponseData);
          }

          appState.setCredentials(
            widget.usernameController.text,
            widget.passwordController.text,
          );

          await appState.saveCredentials();

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          throw Exception("帳號或密碼不正確");
        }
      } else {
        throw Exception("帳號或密碼不正確");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("錯誤: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
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
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: widget.passwordController,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[400],
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '登入',
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
  final List<CameraDescription> cameras;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  HomeScreen({
    required this.cameras,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedPatient;
  String? selectedPatientId;

  Future<void> _logout(BuildContext context) async {
    await appState.clearAll();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('長照輔助系統 (ID: ${appState.centerId ?? "未登入"})'),
        backgroundColor: Colors.grey[300],
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '登出',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.grey[300]),
              child: Text('選單', style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              title: Text('藥物辨識檢測'),
              onTap: () {
                Navigator.pushNamed(context, '/medicine_recognition');
              },
            ),
            ListTile(
              title: Text('藥單自動鍵值'),
              onTap: () {
                Navigator.pushNamed(context, '/prescription_capture');
              },
            ),
            ListTile(
              title: Text('患者資料管理'),
              onTap: () {
                if (selectedPatient != null) {
                  Navigator.pushNamed(
                    context,
                    '/patient_management',
                    arguments: {
                      'patientName': selectedPatient,
                      'patientId': selectedPatientId,
                    },
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('請先選擇病患')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: '選擇病患',
                border: OutlineInputBorder(),
              ),
              value: selectedPatient,
              items: appState.patientNames.map((name) {
                return DropdownMenuItem(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedPatient = value;
                });
                appState.setCurrentPatient(value);
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FeatureButton(
                  title: '藥物辨識檢測',
                  onPressed: () {
                    if (selectedPatient == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('請先選擇病患')),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, '/medicine_recognition');
                  },
                ),
                FeatureButton(
                  title: '藥單自動鍵值',
                  onPressed: () {
                    if (selectedPatient == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('請先選擇病患')),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, '/prescription_capture');
                  },
                ),
                FeatureButton(
                  title: '患者資料管理',
                  onPressed: () {
                    if (selectedPatient != null) {
                      Navigator.pushNamed(
                        context,
                        '/patient_management',
                        arguments: {
                          'patientName': selectedPatient,
                          'patientId': selectedPatientId,
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('請先選擇病患')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
  Offset? _focusPoint; // 儲存對焦點位置
  bool _isFocusing = false; // 標記是否正在對焦

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
      // 設置自動對焦
      await _cameraController!.setFocusMode(FocusMode.auto);
      // 禁用閃光燈
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

  Future<void> _takePictureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相機未初始化')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isProcessing = true;
    });

    try {
      // 確保自動對焦
      await _cameraController!.setFocusMode(FocusMode.auto);
      // 確保閃光燈關閉
      await _cameraController!.setFlashMode(FlashMode.off);

      // 可選：設置對焦點
      if (_focusPoint != null) {
        final screenSize = MediaQuery.of(context).size;
        await _setFocusPoint(_focusPoint!, screenSize);
      }

      // 等待對焦穩定
      await Future.delayed(Duration(milliseconds: 500));

      // 拍照
      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 上傳到伺服器
      final response = await http.post(
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

        await _fetchPatientMedications();
        await _compareMedications(detections);

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JsonResultScreen(
              annotatedImageBase64: annotatedImageBase64,
              jsonResponse: const JsonEncoder.withIndent('  ').convert(responseData),
              detections: detections,
              patientMedications: _patientMedications,
              mismatchedMedications: _mismatchedMedications,
              missingMedications: _missingMedications,
            ),
          ),
        );
      } else {
        throw Exception('伺服器返回錯誤: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
          _focusPoint = null;
        });
      }
    }
  }


  // 從相簿選擇照片
  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);


    if (image != null) {
      final imageFile = File(image.path);
      if (await imageFile.exists()) {
        setState(() {
          _selectedImage = imageFile; // 將選擇的照片儲存為 File
          _detections = [];
        });


        // 將照片轉換為 JSON
        _convertImageToJson(imageFile, "Yolo"); // 傳入 "Yolo" 作為 requestType
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('照片檔案不存在')),
        );
      }
    }
  }


   Future<void> _convertImageToJson(File imageFile, String requestType) async {
    try {
      setState(() => _isLoading = true);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final jsonData = {
        'username': widget.usernameController.text,
        'password': widget.passwordController.text,
        'requestType': requestType,
        'data': {"image": "data:image/png;base64,$base64Image"},
      };

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final detections = (responseData['detections'] as List?)
            ?.map((item) => item as Map<String, dynamic>)
            .toList() ?? <Map<String, dynamic>>[];
        final String? annotatedImageBase64 = responseData['image'] as String?;

        await _compareMedications(detections);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JsonResultScreen(
              annotatedImageBase64: annotatedImageBase64,
              jsonResponse: response.body,
              detections: detections,
              patientMedications: _patientMedications,
              mismatchedMedications: _mismatchedMedications,
              missingMedications: _missingMedications,
            ),
          ),
        );
      } else {
        throw Exception('服務器返回錯誤: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('傳送失敗: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
Future<void> _fetchPatientMedications() async {
  if (appState.currentPatientId == null) return;

  try {
    // 獲取當前日期，格式為 YYYY-MM-DD
    final currentDate = DateTime.now();
    final formattedCurrentDate = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": widget.usernameController.text,
        "password": widget.passwordController.text,
        "requestType": "sql search",
        "data": {
          "sql": """
           SELECT d.DrugName, m.Dose
          FROM (
                SELECT *
                FROM medications
                WHERE PatientID = '${appState.currentPatientId}'
                  AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$formattedCurrentDate'
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

    final responseData = jsonDecode(response.body);
    if (responseData is List) {
      setState(() {
        _patientMedications = responseData
            .map((item) => {
                  'drugName': item['DrugName']?.toString().toLowerCase() ?? '',
                  'dose': int.tryParse(item['Dose']?.toString() ?? '0') ?? 0,
                })
            .toList();
      });
    }
  } catch (e) {
    debugPrint('獲取患者藥物失敗: $e');
  }
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
Future<void> _compareMedications(List<Map<String, dynamic>> detections) async {
    await _fetchPatientMedications();

    final detectedLabels = detections
        .map((d) => d['label']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toList();

    setState(() {
      // 照片有但患者不應服用的藥物
      _mismatchedMedications = detections.where((d) {
        final label = d['label']?.toString().toLowerCase().trim();
        return label != null &&
            !_patientMedications.any((med) => med['drugName'] == label);
      }).toList();

      // 計算缺少的藥物和顆數
      _missingMedications = _patientMedications.map((med) {
        final drugName = med['drugName'] as String;
        final expectedDose = med['dose'] as int;
        // 計算檢測到的該藥物顆數
        final detectedCount = detectedLabels
            .where((label) => label == drugName)
            .length;
        // 計算缺少的顆數
        final missingCount = expectedDose - detectedCount;
        return {
          'drugName': drugName,
          'missingCount': missingCount > 0 ? missingCount : 0,
        };
      }).where((med) => (med['missingCount'] as int) > 0).toList();
    });
  }
}

class JsonResultScreen extends StatelessWidget {
  final String? annotatedImageBase64;
  final String jsonResponse;
  final List<Map<String, dynamic>> detections;
  final List<Map<String, dynamic>> patientMedications; // 修改類型
  final List<Map<String, dynamic>> mismatchedMedications;
  final List<Map<String, dynamic>> missingMedications; // 修改類型

  const JsonResultScreen({
    required this.annotatedImageBase64,
    required this.jsonResponse,
    required this.detections,
    required this.patientMedications,
    required this.mismatchedMedications,
    required this.missingMedications,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('辨識結果')),
      body: Column(
        children: [
          if (annotatedImageBase64 != null && annotatedImageBase64!.isNotEmpty)
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                base64Decode(annotatedImageBase64!.split(',').last),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text('圖片載入失敗'));
                },
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text('無標註圖片', style: TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: '藥物比對'),
                      Tab(text: '原始JSON'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildComparisonResult(),
                        _buildRawJsonViewer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonResult() {
  return SingleChildScrollView(
    child: Column(
      children: [
        // 患者應服用的藥物列表
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '患者應服用的藥物 (${patientMedications.length}種):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          children: patientMedications
              .map((med) => Chip(
                    label: Text('${med['drugName']} - ${med['dose']}顆'),
                    backgroundColor: Colors.green[100],
                  ))
              .toList(),
        ),
        Divider(),

        // 照片有但患者不應服用的藥物
        if (mismatchedMedications.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '不相符的藥物 (${mismatchedMedications.length}種):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ),
          ...mismatchedMedications.map((med) => ListTile(
                leading: Icon(Icons.warning, color: Colors.orange),
                title: Text(med['label']?.toString() ?? '未知標籤'),
                subtitle: Text('置信度: ${(med['confidence'] * 100).toStringAsFixed(2)}%'),
              )),
          Divider(),
        ],

        // 缺少的藥物和顆數
        if (missingMedications.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '缺少的藥物 (${missingMedications.length}種):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: missingMedications
                .map((med) => Chip(
                      label: Text('${med['drugName']} - ${med['missingCount']}顆'),
                      backgroundColor: Colors.blue[100],
                      deleteIcon: Icon(Icons.warning, size: 18),
                      onDeleted: () {},
                    ))
                .toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              '這些藥物應該出現但未在照片中辨識到',
              style: TextStyle(color: Colors.blue[800], fontSize: 14),
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildRawJsonViewer() {
    try {
      final jsonData = jsonDecode(jsonResponse);
      final formattedJson = JsonEncoder.withIndent('  ').convert(jsonData);
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            formattedJson,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    } catch (e) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Text(
            jsonResponse.isEmpty ? '無數據' : 'JSON解析錯誤: ${e.toString()}\n原始內容:\n$jsonResponse',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }
  }
}

//看患者吃的藥有哪些
class PatientManagementScreen extends StatefulWidget {
  @override
  _PatientManagementScreenState createState() => _PatientManagementScreenState();
}


class _PatientManagementScreenState extends State<PatientManagementScreen> {
  bool isLoading = false;
  String serverResponse = '';
  String requestJson = '';
  List<dynamic> medications = [];
  bool showRawJson = false;

  // 獲取當前患者資訊
  String? get selectedPatient => appState.currentPatientName;
  String? get selectedPatientId => appState.currentPatientId;

  @override
  void initState() {
    super.initState();
    _fetchPatientMedications();
  }

  Future<void> _fetchPatientMedications() async {
    if (selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未選擇患者，請返回首頁選擇患者')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      medications = [];
      serverResponse = '';
      requestJson = '';
    });

    try {
      final medicationsjsonData = {
        "username": appState.username ?? '',
        "password": appState.password ?? '',
        "requestType": "sql search",
        "data": {
          "sql": """
            SELECT m.PatientID, m.Added_Day, d.DrugName, m.Timing, m.Dose, m.DrugID
            FROM medications m
            INNER JOIN drugs d ON m.DrugID = d.DrugID
            INNER JOIN (
                SELECT DrugID, MAX(Added_Day) AS Latest_Added_Day
                FROM medications
                WHERE PatientID = '$selectedPatientId'
                GROUP BY DrugID
            ) latest ON m.DrugID = latest.DrugID AND m.Added_Day = latest.Latest_Added_Day
            WHERE m.PatientID = '$selectedPatientId'
          """
        }
      };

      setState(() {
        requestJson = JsonEncoder.withIndent('  ').convert(medicationsjsonData);
      });

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(medicationsjsonData),
      );

      final responseBody = response.body;

      // 調試：打印原始響應
      debugPrint('Server response body: $responseBody');

      // 檢查響應是否為空
      if (responseBody.isEmpty) {
        throw Exception('服務器返回空響應');
      }

      final responseData = jsonDecode(responseBody);

      // 調試：打印解析後的數據
      debugPrint('Parsed response data: $responseData');

      setState(() {
        serverResponse = responseBody;
        if (responseData is List) {
          medications = responseData;
        } else {
          throw Exception('預期 List 格式，但收到: ${responseData.runtimeType}');
        }
      });
    } catch (e) {
      setState(() {
        serverResponse = '';
        isLoading = false;
      });
      debugPrint('Error in _fetchPatientMedications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('獲取藥物資料失敗: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    debugPrint('Medication data: $medication');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _updateMedication(medication),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '藥物名稱: ${medication['DrugName']?.toString() ?? '未知'}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '服用時間: ${medication['Timing']?.toString() ?? '無'}',
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '劑量: ${medication['Dose']?.toString() ?? '無'}',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '添加日期: ${medication['Added_Day']?.toString() ?? '無'}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateMedication(Map<String, dynamic> medication) async {
    final drugId = medication['DrugID']?.toString() ?? '';
    final patientId = medication['PatientID']?.toString() ?? '';

    // 控制器初始化（移除 Added_Day）
    final timingController = TextEditingController(text: medication['Timing']?.toString() ?? '');
    final doseController = TextEditingController(text: medication['Dose']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('編輯藥物資訊'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timingController,
                decoration: InputDecoration(labelText: '服用時間'),
              ),
              TextField(
                controller: doseController,
                decoration: InputDecoration(labelText: '劑量'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 構建更新SQL語句（移除 Added_Day）
              final sql = """
                UPDATE Medications 
                SET Timing = '${timingController.text}',
                    Dose = '${doseController.text}'
                WHERE DrugID = '$drugId' AND PatientID = '$patientId'
              """;

              try {
                final updateData = {
                  "username": appState.username ?? '',
                  "password": appState.password ?? '',
                  "requestType": "sql update",
                  "data": {"sql": sql}
                };

                final response = await http.post(
                  Uri.parse('https://project.1114580.xyz/data'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(updateData),
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新成功')),
                  );
                  _fetchPatientMedications(); // 刷新列表
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('更新失敗: ${response.body}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('錯誤: $e')),
                );
              }

              Navigator.pop(context);
            },
            child: Text('更新'),
          ),
        ],
      ),
    );
  }

  Widget _buildRawJsonViewer() {
    if (serverResponse.isEmpty) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Text(
            '無數據',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }

    try {
      final jsonData = jsonDecode(serverResponse);
      final formattedJson = JsonEncoder.withIndent('  ').convert(jsonData);

      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            formattedJson,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    } catch (e) {
      debugPrint('JSON parsing error: $e');
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            'JSON解析錯誤: ${e.toString()}\n原始內容:\n$serverResponse',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('患者藥物資料'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchPatientMedications,
            tooltip: '重新載入',
          ),
          IconButton(
            icon: Icon(showRawJson ? Icons.list : Icons.code),
            onPressed: () => setState(() => showRawJson = !showRawJson),
            tooltip: showRawJson ? '顯示列表' : '顯示原始JSON',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('患者: $selectedPatient (ID: $selectedPatientId)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  if (showRawJson)
                    Expanded(child: _buildRawJsonViewer())
                  else
                    Expanded(
                      child: medications.isEmpty
                          ? Center(child: Text('沒有找到藥物記錄'))
                          : ListView.builder(
                              itemCount: medications.length,
                              itemBuilder: (context, index) {
                                return _buildMedicationCard(
                                    medications[index] as Map<String, dynamic>);
                              },
                            ),
                    ),
                  if (serverResponse.isNotEmpty && !showRawJson)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '共 ${medications.length} 筆記錄',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class FeatureButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const FeatureButton({
    required this.title, 
    required this.onPressed,
    Key? key,  // 添加 Key 參數
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
              fontSize: 18, 
              fontWeight: FontWeight.bold
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相機未初始化')),
      );
      return;
    }

    if (appState.currentPatientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先在首頁選擇病患')),
      );
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
      showLoadingDialog(context);

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

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

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

        // 隱藏 Loading 畫面
        hideLoadingDialog(context);

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
      // 隱藏 Loading 畫面
      hideLoadingDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理失敗: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _focusPoint = null;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (appState.currentPatientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先在首頁選擇病患')),
      );
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
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // 顯示 Loading 畫面
      showLoadingDialog(context);

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

        final response = await http.post(
          Uri.parse('https://project.1114580.xyz/data'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        debugPrint('Response Status: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');

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

          // 隱藏 Loading 畫面
          hideLoadingDialog(context);

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
      // 隱藏 Loading 畫面
      hideLoadingDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理失敗: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _focusPoint = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('藥單拍照'),
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
  final TextEditingController _usageController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _appearanceController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _syncAuthData(); // 同步認證數據
    _parseJsonResponse();
    _patientNameController.text = appState.currentPatientName ?? '未選擇患者';
    // 檢查登錄狀態
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  void _checkLoginStatus() {
    if (appState.usernameController.text.isEmpty || appState.passwordController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('請先登錄')),
          );
        }
      });
    }
  }

  void _syncAuthData() {
    if (appState.usernameController.text.isEmpty && widget.usernameController.text.isNotEmpty) {
      appState.usernameController.text = widget.usernameController.text;
    }
    if (appState.passwordController.text.isEmpty && widget.passwordController.text.isNotEmpty) {
      appState.passwordController.text = widget.passwordController.text;
    }
  }

  void _parseJsonResponse() {
    try {
      var jsonData = jsonDecode(widget.jsonResponse);
      if (jsonData is String) {
        jsonData = jsonDecode(jsonData);
      }
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('JSON 格式錯誤');
      }

      String usageText = '';
      final usage = jsonData['usage'];
      if (usage is List<dynamic>) {
        usageText = usage.map((e) => e?.toString() ?? '').join(', ');
      } else if (usage is Map<dynamic, dynamic>) {
        usageText = usage.values.map((e) => e?.toString() ?? '').join(', ');
      } else if (usage is String) {
        usageText = usage;
      } else if (usage != null) {
        usageText = usage.toString();
      }

      if (mounted) {
        setState(() {
          _medicationController.text = jsonData['medication']?.toString() ?? '';
          _usageController.text = usageText;
          _dosageController.text = jsonData['dosage']?.toString() ?? '';
          _appearanceController.text = jsonData['appearance']?.toString() ?? '';
          _daysController.text = jsonData['days']?.toString() ?? '';
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'JSON 解析錯誤: $e';
        });
      }
    }
  }

  String _sanitizeInput(String input) {
    return input.replaceAll("'", "''").replaceAll(';', '').replaceAll('--', '');
  }

  Future<bool> _verifyPatientAndDrug(String patientName, String drugName) async {
    try {
      final sanitizedPatientName = _sanitizeInput(patientName);
      final sanitizedDrugName = _sanitizeInput(drugName);

      final patientCheck = http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': appState.usernameController.text,
          'password': appState.passwordController.text,
          'requestType': 'sql search',
          'data': {
            'sql': "SELECT PatientID FROM patients WHERE PatientName = '$sanitizedPatientName'"
          },
        }),
      );

      final drugCheck = http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': appState.usernameController.text,
          'password': appState.passwordController.text,
          'requestType': 'sql search',
          'data': {
            'sql': "SELECT DrugID FROM drugs WHERE DrugName = '$sanitizedDrugName'"
          },
        }),
      );

      final responses = await Future.wait([patientCheck, drugCheck]);
      final patientResponse = responses[0];
      final drugResponse = responses[1];

      final patientData = jsonDecode(patientResponse.body);
      final drugData = jsonDecode(drugResponse.body);

      return patientResponse.statusCode == 200 &&
          drugResponse.statusCode == 200 &&
          patientData is List &&
          patientData.isNotEmpty &&
          drugData is List &&
          drugData.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _checkSimilarDrugName(String inputDrugName) async {
    try {
      final sanitizedDrugName = _sanitizeInput(inputDrugName);
      final sql = """
        SELECT DrugName
        FROM drugs
        WHERE levenshtein_enhanced(DrugName, '$sanitizedDrugName') <= 2
        LIMIT 1
      """;

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': appState.usernameController.text,
          'password': appState.passwordController.text,
          'requestType': 'sql search',
          'data': {'sql': sql}
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final responseData = jsonDecode(response.body);
      if (responseData is List && responseData.isNotEmpty) {
        return responseData[0]['DrugName']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _addDrugToDatabase(String drugName) async {
    try {
      final sanitizedDrugName = _sanitizeInput(drugName);
      final sql = """
        INSERT INTO drugs (DrugName)
        VALUES ('$sanitizedDrugName');
      """;

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': appState.usernameController.text,
          'password': appState.passwordController.text,
          'requestType': 'sql update',
          'data': {'sql': sql}
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('插入藥物失敗: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw e;
    }
  }

  void _showSimilarDrugDialog(String inputDrugName, String similarDrugName) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('找到相似的藥物名稱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您輸入的藥物名稱：$inputDrugName'),
            SizedBox(height: 8),
            Text('資料庫中的相似名稱：$similarDrugName'),
            SizedBox(height: 16),
            Text(
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
            child: Text('並不是這個藥名'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (mounted) {
                setState(() {
                  _medicationController.text = similarDrugName;
                });
                await _saveToServer();
              }
            },
            child: Text('確認上傳'),
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
        title: Text('確認新藥物'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您準備輸入的藥物名稱：$inputDrugName'),
            SizedBox(height: 16),
            Text(
              '現在尚未登記此種藥物 確認無誤後會先將藥物傳到資料庫後再更新患者資料',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    Navigator.of(context).pop();
                    if (!mounted) return;
                    setState(() {
                      _isSaving = true;
                    });
                    try {
                      _syncAuthData(); // 確保認證數據有效
                      if (appState.usernameController.text.isEmpty ||
                          appState.passwordController.text.isEmpty) {
                        throw Exception('認證數據無效，請重新登錄');
                      }
                      final success = await _addDrugToDatabase(inputDrugName);
                      if (!success) {
                        throw Exception('無法將藥物名稱添加到資料庫');
                      }
                      if (mounted) {
                        setState(() {
                          _medicationController.text = inputDrugName;
                        });
                      } else {
                        throw Exception('頁面已關閉，無法繼續保存');
                      }
                      await _saveToServer(force: true);
                      if (mounted && _scaffoldMessenger != null) {
                        _scaffoldMessenger!.showSnackBar(
                          SnackBar(content: Text('資料保存成功')),
                        );
                      }
                    } catch (e) {
                      if (mounted && _scaffoldMessenger != null) {
                        _scaffoldMessenger!.showSnackBar(
                          SnackBar(content: Text('錯誤: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                      }
                    }
                  },
            child: Text('確認上傳'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToServer({bool force = false}) async {
    if (_isSaving && !force) return;
    if (!mounted) return;

    if (appState.currentPatientName == null ||
        _medicationController.text.isEmpty ||
        _usageController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _daysController.text.isEmpty) {
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('請填寫所有必要字段')),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final username = appState.usernameController.text;
      final password = appState.passwordController.text;
      if (username.isEmpty || password.isEmpty) {
        throw Exception('認證數據無效，請重新登錄');
      }

      final patientName = _sanitizeInput(appState.currentPatientName!);
      final medication = _sanitizeInput(_medicationController.text);
      final timing = _sanitizeInput(_usageController.text);
      final dose = _sanitizeInput(_dosageController.text);
      final days = _sanitizeInput(_daysController.text);

      final doseNum = int.tryParse(dose);
      final daysNum = int.tryParse(days);
      if (doseNum == null || daysNum == null) {
        throw Exception('劑量和處方天數必須為數字');
      }

      final isValid = await _verifyPatientAndDrug(patientName, medication);
      if (!isValid) {
        final similarDrug = await _checkSimilarDrugName(medication);
        if (similarDrug != null) {
          if (mounted) _showSimilarDrugDialog(medication, similarDrug);
          return;
        } else {
          if (mounted) _showNewDrugConfirmationDialog(medication);
          return;
        }
      }

      final sql = """
        INSERT INTO medications (PatientID, DrugID, Timing, Dose, days)
        VALUES (
            (SELECT PatientID FROM patients WHERE PatientName = '$patientName'),
            (SELECT DrugID FROM drugs WHERE DrugName = '$medication'),
            '$timing',
            '$dose',
            '$days'
        );
      """;

      final response = await http.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'requestType': 'sql update',
          'data': {'sql': sql}
        }),
      );

      if (response.statusCode == 200) {
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(content: Text('資料保存成功')),
          );
          _resetForm();
        }
      } else {
        String errorMsg = '保存失敗: HTTP ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error']?.toString() ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('錯誤: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _resetForm() {
    if (!mounted) return;
    _medicationController.clear();
    _usageController.clear();
    _dosageController.clear();
    _appearanceController.clear();
    _daysController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _medicationController.dispose();
    _usageController.dispose();
    _dosageController.dispose();
    _appearanceController.dispose();
    _daysController.dispose();
    _scaffoldMessenger = null;
    super.dispose();
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
              TextField(
                controller: _usageController,
                decoration: const InputDecoration(
                  labelText: '用藥時間',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                onPressed: _isSaving ? null : _saveToServer,
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