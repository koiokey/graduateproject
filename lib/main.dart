import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // 用於處理檔案路徑
import 'dart:convert'; // 用於 Base64 編碼
import 'app_state.dart'; // 添加這行導入
import 'package:http/http.dart' as http; // 導入 http 套件



void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 確保 Flutter 初始化
  await appState.init(); // 初始化 AppState 並載入保存的憑證
  final cameras = await availableCameras(); // 獲取可用相機
  runApp(MyApp(cameras: cameras));
}


class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final TextEditingController usernameController = TextEditingController(); // 新增 usernameController
  final TextEditingController passwordController = TextEditingController(); // 新增 passwordController


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
      },
    );
  }
}


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
  String serverResponse = '';
  bool isLoading = false;

 @override
  void initState() {
    super.initState();
    // 初始化時檢查是否有記住密碼
    if (appState.rememberMe) {
      // 已經在 AppState.init() 中載入了帳號密碼
    }
  }

 Future<void> _login() async {
  setState(() {
    isLoading = true;
    serverResponse = '';
  });

  // 第一个请求：验证账号密码
  final loginJsonData = {
    "username": widget.usernameController.text,
    "password": widget.passwordController.text,
    "requestType": "sql search",
    "data": {
      "sql": "SELECT CenterID, CenterAccount, CenterPassword FROM Accounts"
    }
  };


  try {
    // 发送第一个请求
    final loginResponse = await http.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(loginJsonData),
    );


    final loginResponseBody = loginResponse.body;
    setState(() {
      serverResponse = "登录响应:\n$loginResponseBody";
    });


    dynamic loginResponseData = jsonDecode(loginResponseBody);
   
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
        // 設置全局 CenterID
        appState.setCenterId(matchedCenterId);
        if (isValid && matchedCenterId != null) {
    appState.setCenterId(matchedCenterId);
   
    // 第二個請求：獲取患者列表
    final patientsJsonData = {
      "username": widget.usernameController.text,
      "password": widget.passwordController.text,
      "requestType": "sql search",
      "data": {
        "sql": "SELECT PatientID, PatientName FROM Patients WHERE CenterID = '$matchedCenterId'"
      }
    };


    final patientsResponse = await http.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(patientsJsonData),
    );


    final patientsResponseBody = patientsResponse.body;
    setState(() {
      serverResponse += "\n\n患者列表響應:\n$patientsResponseBody";
    });


    dynamic patientsResponseData = jsonDecode(patientsResponseBody);
   
    if (patientsResponseData is List && patientsResponseData.isNotEmpty) {
      // 直接傳遞原始數據，讓 AppState 處理類型轉換
      appState.setPatients(patientsResponseData);
    }
    appState.setCredentials(
    widget.usernameController.text, // 用户名
    widget.passwordController.text  // 密码
  );

    Navigator.pushReplacementNamed(context, '/home');
  }
      } else {
        throw Exception("帳號或密碼不正確");
      }
    } else {
      throw Exception("不支持模式");
    }
     await appState.saveCredentials();
      
   
  } catch (e) {
    setState(() {
      serverResponse += "\n\n错误详情:\n${e.toString()}";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("错误: ${e.toString()}")),
    );
  } finally {
    setState(() => isLoading = false);
    
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 登入表單部分...
              TextField(
                controller: widget.usernameController,
                decoration: InputDecoration(labelText: '帳號'),
              ),
              TextField(
                controller: widget.passwordController,
                decoration: InputDecoration(labelText: '密碼'),
                obscureText: true,
              ),
              ElevatedButton(
                onPressed: isLoading ? null : _login,
                child: isLoading ? CircularProgressIndicator() : Text('登入'),
              ),
             
              // 顯示伺服器回應
              if (serverResponse.isNotEmpty) ...[
                SizedBox(height: 20),
                Text('伺服器回應:', style: TextStyle(fontWeight: FontWeight.bold)),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText(
                      serverResponse,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


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

  // 登出方法
  Future<void> _logout(BuildContext context) async {
    // 清除所有登入狀態
    await appState.clearAll();
    
    // 導航回登入頁面並清除所有路由
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/', // 登入頁面路由
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
          // 登出按鈕
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
              onTap: () {},
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
                    // 藥單自動鍵值邏輯
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
  final List<String> medicines = ['止痛藥', '抗生素', '感冒藥', '降血壓藥'];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  File? _selectedImage;
  List<Map<String, dynamic>> _detections = []; // 存儲檢測結果


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
        widget.cameras[0], // 使用第一個相機（通常是後置相機）
        ResolutionPreset.medium,
      );


      await _cameraController!.initialize();
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


  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('相機未初始化')),
      );
      return;
    }


    try {
      final XFile picture = await _cameraController!.takePicture();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('照片已儲存: ${picture.path}')),
      );


        // 清除舊的檢測結果
    setState(() {
      _detections = [];
    });


      // 將照片轉換為 JSON
      final imageFile = File(picture.path);
      _convertImageToJson(imageFile, "Yolo"); // 傳入 "Yolo" 作為 requestType
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失敗: $e')),
      );
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
    // 讀取照片並轉換為 Base64
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);


    // 建立 JSON 物件
    final jsonData = {
      'username': widget.usernameController.text, // 從登入畫面獲取用戶名
      'password': widget.passwordController.text, // 從登入畫面獲取密碼
      'requestType': requestType, // 根據按鈕點擊事件傳入的值
      'data': {"image": "data:image/png;base64,$base64Image"}, // Base64 編碼的照片
    };


    // 將 JSON 物件轉換為字串
    final jsonString = jsonEncode(jsonData);


    // 將 JSON 資料傳送到伺服器
    final url = Uri.parse('https://project.1114580.xyz/data'); // 目標 URL
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'}, // 設置請求頭
      body: jsonString, // 傳送 JSON 資料
    );


    // 檢查伺服器回應
    if (response.statusCode == 200) {
      // 請求成功，解析 JSON 回應
      final responseData = jsonDecode(response.body);
      if (responseData['status'] == 'success') {
        // 將檢測結果存儲在狀態中
        setState(() {
          _detections = List<Map<String, dynamic>>.from(responseData['detections']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('伺服器回應錯誤: ${responseData['status']}')),
        );
      }
    } else {
      // 請求失敗
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('伺服器回應錯誤: ${response.statusCode}')),
      );
    }
  } catch (e) {
    // 處理例外
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('傳送失敗: $e')),
    );
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: '選擇藥物類別',
                border: OutlineInputBorder(),
              ),
              value: selectedMedicine,
              items: medicines.map((medicine) {
                return DropdownMenuItem(
                  value: medicine,
                  child: Text(medicine),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedMedicine = value;
                });
              },
            ),
            SizedBox(height: 20),
            if (_isLoading)
              CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              )
            else if (_isCameraInitialized)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: CameraPreview(_cameraController!),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _takePicture,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[300]),
                      child: Text('拍照辨識'),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
            // 顯示從相簿選擇的照片
            if (_selectedImage != null)
              Expanded(
                child: Image.file(_selectedImage!),
              ),
            SizedBox(height: 20),
            // 從相簿選擇照片的按鈕
            ElevatedButton(
              onPressed: _pickImageFromGallery,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[300]),
              child: Text('從相簿選擇照片'),
            ),
              SizedBox(height: 20),
          // 顯示檢測結果
          if (_detections.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _detections.length,
                itemBuilder: (context, index) {
                  final detection = _detections[index];
                  return ListTile(
                    title: Text('藥物名稱: ${detection['label']}'),
                    subtitle: Text('信心指數: ${detection['confidence'].toStringAsFixed(2)}'),
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
          "sql": "SELECT PatientID, Added_Day, DrugID, Timing, Dose FROM Medications WHERE PatientID = '$selectedPatientId'"
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
      final responseData = jsonDecode(responseBody);
     
      setState(() {
        serverResponse = responseBody;
        if (responseData is List) {
          medications = responseData;
        }
      });
    } catch (e) {
      setState(() {
        serverResponse = '錯誤: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('獲取藥物資料失敗: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateMedication(Map<String, dynamic> medication) async {
    final drugId = medication['DrugID']?.toString() ?? '';
    final patientId = medication['PatientID']?.toString() ?? '';

    // 控制器初始化
    final timingController = TextEditingController(text: medication['Timing']?.toString() ?? '');
    final doseController = TextEditingController(text: medication['Dose']?.toString() ?? '');
    final addedDayController = TextEditingController(text: medication['Added_Day']?.toString() ?? '');

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
              TextField(
                controller: addedDayController,
                decoration: InputDecoration(labelText: '添加日期 (YYYY-MM-DD)'),
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
              // 構建更新SQL語句
              final sql = """
                UPDATE Medications 
                SET Timing = '${timingController.text}',
                    Dose = '${doseController.text}',
                    Added_Day = '${addedDayController.text}'
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

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
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
              Text('藥物ID: ${medication['DrugID'] ?? '未知'}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('服用時間: ${medication['Timing'] ?? '無'}')),
                  Expanded(child: Text('劑量: ${medication['Dose'] ?? '無'}')),
                ],
              ),
              SizedBox(height: 8),
              Text('添加日期: ${medication['Added_Day'] ?? '無'}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawJsonViewer() {
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
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Text(
            serverResponse.isEmpty ? '無數據' : serverResponse,
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







