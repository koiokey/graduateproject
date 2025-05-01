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
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'utils.dart';

AppState appState = AppState();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.init();
  final cameras = await availableCameras();
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
    "requestType": "sql verify",
    "data": {
      
    }
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
      if (matchedCenterId == null) {
        throw Exception('伺服器未提供 CenterID');
      }

      // 設置 CenterID
      appState.setCenterId(matchedCenterId);

      // 可選：儲存 CenterName（如果需要）
      //appState.setCenterName(loginResponseData['CenterName']);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('錯誤: ${e.toString()}')),
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
  bool _isLoading = true;
  List<Map<String, dynamic>> _patients = [];
  String? _errorMessage;
 late AppState _appState; // 保存 AppState 引用

 @override
  void initState() {
    super.initState();
    // 使用 post-frame 回調延遲調用 _fetchPatients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchPatients();
      }
    });
  }
@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保存 AppState 引用並註冊刷新回調
    _appState = Provider.of<AppState>(context, listen: false);
    _appState.setHomeRefreshCallback(_fetchPatients);
  }

  @override
  void dispose() {
    // 使用保存的 _appState 引用清理回調，避免使用 context
    _appState.setHomeRefreshCallback(() {
      debugPrint('HomeScreen: Refresh callback cleared');
    });
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

  if (appState.centerId == null) {
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
      timingCondition = "'晚餐前', '晚餐後'";
    }

    final sql = '''
      SELECT 
        p.PatientName,
        p.PatientPicture,
        p.PatientID,
        m.state
      FROM patients p
      LEFT JOIN medications m ON p.PatientID = m.PatientID
        AND DATE_ADD(m.Added_Day, INTERVAL m.days DAY) >= '$currentDate'
        AND m.Timing IN ($timingCondition)
      WHERE p.CenterID = '${appState.centerId}'
    ''';

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
      if (item['state'] != null) {
        patientMap[patientId]!['medications'].add({'state': item['state']});
      }
    }

    final patients = patientMap.values.toList();
    for (var patient in patients) {
      Color statusColor = const Color.fromARGB(255, 178, 223, 180);
      for (var med in patient['medications']) {
        final state = int.tryParse(med['state']?.toString() ?? '1') ?? 1;
        if (state == 0) {
          statusColor = const Color.fromARGB(255, 240, 207, 157);
          break;
        } else if (state == 2) {
          statusColor = const Color.fromARGB(255, 221, 150, 145);
        }
      }
      patient['statusColor'] = statusColor;
      debugPrint('Patient ${patient['PatientID']} Status Color: $statusColor');
    }

    patients.sort((a, b) {
      final colorA = a['statusColor'] as Color;
      final colorB = b['statusColor'] as Color;

      const orange = Color.fromARGB(255, 240, 207, 157);
      const red = Color.fromARGB(255, 221, 150, 145);
      const green = Color.fromARGB(255, 178, 223, 180);

      int getColorPriority(Color color) {
        if (color == orange) return 1;
        if (color == red) return 2;
        if (color == green) return 3;
        return 4;
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
    debugPrint('Fetch patients error: $e');
    debugPrint('StackTrace: $stackTrace');
    if (mounted) {
      setState(() {
        _errorMessage = '獲取患者資料失敗: $e';
        _isLoading = false;
      });
    }
  }
}

  Future<void> _logout(BuildContext context) async {
    await appState.clearAll();
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
    final patientName = patient['PatientName'] as String;
    final patientId = patient['PatientID'] as String;
  
  debugPrint('HomeScreen: Patient data - Name: $patientName, ID: $patientId'); // 新增：檢查 patient 資料

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
                  appState.setCurrentPatient(patientName,patientId);
                  Navigator.pushNamed(context, '/medicine_recognition');
                },
                child: Text(
                  '藥物辨識檢測',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 8),
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
                  appState.setCurrentPatient(patientName,patientId);
                  Navigator.pushNamed(context, '/prescription_capture');
                },
                child: Text(
                  '藥單自動鍵值',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 8),
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
                  appState.setCurrentPatient(patientName,patientId);
                  Navigator.pushNamed(
                    context,
                    '/patient_management',
                    arguments: {
                      'patientName': patientName,
                      'patientId': patientId,
                    },
                  );
                },
                child: Text(
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
            child: Text('取消'),
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
      backgroundColor: statusColor, // 使用 statusColor 作為按鈕背景顏色
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
                    color: Colors.grey, // 修正為灰色
                  ),
                ),
              )
            : const Icon(
                Icons.person,
                size: 60,
                color: Colors.grey, // 圖標使用固定灰色
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

  Widget _buildBlankPage() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _patients.isEmpty
                        ? Center(
                            child: Text(
                              '無患者資料',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.all(8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _showAddPatientDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[400],
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                '新增患者',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                      decoration: InputDecoration(
                        labelText: '患者姓名',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
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
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      label: Text(
                        '選擇照片',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 16),
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
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.grey,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.grey,
                            ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text(
                            '離開',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('請輸入患者姓名')),
                              );
                              return;
                            }
                            if (selectedImage == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('請選擇患者照片')),
                              );
                              return;
                            }
                            await _uploadPatientData(
                              dialogContext,
                              nameController.text,
                              selectedImage!,
                            );
                          },
                          child: Text(
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
    if (appState.centerId == null) {
      throw Exception('CenterID 未初始化');
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final sanitizedPatientName = patientName.replaceAll("'", "''");
    final sql = """
      INSERT INTO patients (PatientName, PatientPicture, CenterID)
      VALUES ('$sanitizedPatientName', '$base64Image', '${appState.centerId}')
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
          SnackBar(content: Text('選擇的圖片檔案不存在')),
        );
        return null;
      }

      if (await imageFile.length() > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('圖片檔案過大，請選擇較小的圖片')),
        );
        return null;
      }

      final bytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法解碼圖片')),
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
          SnackBar(content: Text('圖片壓縮後仍過大，請選擇其他圖片')),
        );
        return null;
      }

      if (!await tempFile.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('壓縮後的圖片檔案無法保存')),
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
                      decoration: InputDecoration(
                        labelText: '患者姓名',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
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
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      label: Text(
                        '選擇照片',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 16),
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
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.grey,
                              ),
                            )
                          : _isValidBase64(patient['PatientPicture'])
                              ? Image.memory(
                                  base64Decode(patient['PatientPicture']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.broken_image,
                                    size: 100,
                                    color: Colors.grey,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          child: Text(
                            '離開',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('請輸入患者姓名')),
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
                          child: Text(
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
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                '離開',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _deletePatientData(dialogContext, patient['PatientID']?.toString() ?? '');
              },
              child: Text(
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
      SnackBar(content: Text('無效的患者 ID')),
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
    if (appState.centerId == null) {
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
          WHERE PatientID = '$patientId' AND CenterID = '${appState.centerId}'
        """
        : """
          UPDATE patients
          SET PatientName = '$sanitizedPatientName'
          WHERE PatientID = '$patientId' AND CenterID = '${appState.centerId}'
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
          appState.setCurrentPatient(patientName, patientId);
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
      SnackBar(content: Text('無效的患者 ID')),
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
    if (appState.centerId == null) {
      throw Exception('CenterID 未初始化');
    }

    final sql = """
      DELETE FROM patients
      WHERE PatientID = '$patientId' AND CenterID = '${appState.centerId}'
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
            selectedPatient = null;
            selectedPatientId = null;
          });
          appState.setCurrentPatient(null, null);
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
                if (selectedPatient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('請先選擇病患')),
                  );
                  return;
                }
                Navigator.pushNamed(context, '/medicine_recognition');
              },
            ),
            ListTile(
              title: Text('藥單自動鍵值'),
              onTap: () {
                if (selectedPatient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('請先選擇病患')),
                  );
                  return;
                }
                Navigator.pushNamed(context, '/prescription_capture');
              },
            ),
            ListTile(
              title: Text('患者資料管理'),
              onTap: () {
                if (selectedPatient != null && selectedPatientId != null) {
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
            ListTile(
              title: Text('患者本身管理'),
              onTap: () {
                Navigator.pushNamed(context, '/patient_self_management');
              },
            ),
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
    debugPrint('PrescriptionCaptureScreen is not mounted in _setFocusPoint');
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
    Navigator.of(context, rootNavigator: true).pop();
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
            timing: timing, // 傳遞 timing
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

  if (_isProcessing) return;

  setState(() {
    _isProcessing = true;
  });

  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
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

      showLoadingDialog(context);

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final jsonData = {
        'username': widget.usernameController.text,
        'password': widget.passwordController.text,
        'requestType': 'Yolo',
        'data': {'image': 'data:image/png;base64,$base64Image'},
      };

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<Map<String, dynamic>> detections = (responseData['detections'] as List?)
            ?.cast<Map<String, dynamic>>()
            .toList() ?? [];
        final String? annotatedImageBase64 = responseData['image'] as String?;

        final results = await Future.wait([
          _compareMedications(detections),
          _formatJson(responseData),
        ]);

        final String formattedJson = results[1] as String;

        // 獲取 timing 值
        final String timing = await _fetchPatientMedications();

        hideLoadingDialog(context);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JsonResultScreen(
              annotatedImageBase64: annotatedImageBase64,
              jsonResponse: formattedJson,
              detections: detections,
              patientMedications: _patientMedications,
              mismatchedMedications: _mismatchedMedications,
              missingMedications: _missingMedications,
              timing: timing, // 傳遞 timing
            ),
          ),
        );
      } else {
        throw Exception('服務器返回錯誤: ${response.statusCode}');
      }
    } else {
      throw Exception('照片檔案不存在');
    }
  } catch (e) {
    hideLoadingDialog(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('傳送失敗: $e')),
    );
  } finally {
    setState(() {
      _isProcessing = false;
      _focusPoint = null;
    });
  }
}

 Future<String> _fetchPatientMedications() async {
  if (appState.currentPatientId == null) {
    debugPrint('患者 ID 為空，無法查詢藥物');
    return ''; // 如果無患者 ID，返回空字符串
  }

  final currentDate = DateTime.now();
  final formattedCurrentDate =
      "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

  if (_lastFetchedTiming == _selectedTiming &&
      _lastFetchedDate == formattedCurrentDate &&
      _patientMedications.isNotEmpty) {
    debugPrint('使用緩存的患者藥物數據');
    // 返回緩存的 Timing 值，根據 _selectedTiming 計算
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
            SELECT d.DrugName, m.Dose
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
        setState(() {
          _patientMedications = responseData
              .map((item) => {
                    'drugName': item['DrugName']?.toString().toLowerCase().trim() ?? '',
                    'dose': int.tryParse(item['Dose']?.toString() ?? '0') ?? 0,
                  })
              .where((med) => med['drugName'] is String && (med['drugName'] as String).isNotEmpty)
              .toList();
          _lastFetchedTiming = _selectedTiming;
          _lastFetchedDate = formattedCurrentDate;
        });
        return timingValue; // 返回最終的 Timing 值（例如 '早餐前'）
      } else {
        throw Exception('無效的資料格式');
      }
    }
    return timingValue; // 如果 API 回應失敗，返回計算的 timingValue
  } catch (e) {
    debugPrint('獲取患者藥物失敗: $e');
    setState(() {
      _errorMessage = '獲取藥物資料失敗: $e';
    });
    return ''; // 錯誤時返回空字符串
  }
}

  Future<void> _compareMedications(List<Map<String, dynamic>> detections) async {
    final detectedLabels = detections
        .map((d) => d['label']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();

    final patientMedMap = {
      for (var med in _patientMedications)
        med['drugName'] as String: med['dose'] as int
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
            final expectedDose = entry.value;
            final detectedCount = detectedLabels.where((label) => label == drugName).length;
            final missingCount = expectedDose - detectedCount;
            return {
              'drugName': drugName,
              'missingCount': missingCount > 0 ? missingCount : 0,
            };
          })
          .where((med) => (med['missingCount'] as int) > 0)
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
                          _fetchPatientMedications(); // 重新查詢藥物
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

      final currentDate = DateTime.now().toIso8601String().split('T')[0];

      final sql = '''
        UPDATE medications
        SET state = 1
        WHERE PatientID = '$patientId'
        AND DATE_ADD(Added_Day, INTERVAL days DAY) >= '$currentDate'
        AND Timing = '${widget.timing}'
      ''';

      final jsonData = {
        'username': appState.usernameController.text,
        'password': appState.passwordController.text,
        'requestType': 'sql update',
        'data': {'sql': sql},
      };

      final formattedJson = const JsonEncoder.withIndent('  ').convert(jsonData);
      debugPrint('Request JSON:\n$formattedJson');

      final response = await HttpClient.instance.post(
        Uri.parse('https://project.1114580.xyz/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonData),
      );

      debugPrint('HTTP Response Status Code: ${response.statusCode}');
      debugPrint('HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('藥物狀態更新成功')),
        );
        // 導航到首頁並清除導航堆棧
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
        // 觸發首頁資料刷新
        Provider.of<AppState>(context, listen: false).refreshHomeData();
      } else {
        throw Exception('更新失敗: HTTP ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
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
    // Create a combined list of medications, prioritizing missing medications
    final combinedMedications = <Map<String, dynamic>>[];
    final missingDrugNames = widget.missingMedications.map((med) => med['drugName']?.toString()).toSet();

    // Add missing medications first
    combinedMedications.addAll(widget.missingMedications.map((med) => {
          'drugName': med['drugName'],
          'missingCount': med['missingCount'],
          'isMissing': true,
        }));

    // Add patient medications that are not in missing medications
    combinedMedications.addAll(widget.patientMedications
        .where((med) => !missingDrugNames.contains(med['drugName']?.toString()))
        .map((med) => {
              'drugName': med['drugName'],
              'dose': med['dose'],
              'isMissing': false,
            }));

    return Column(
      children: [
        // 照片有但患者不應服用的藥物
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

        // 患者藥物狀態列表
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '患者藥物狀態 (${combinedMedications.length}種):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (combinedMedications.isNotEmpty)
          ...combinedMedications.map((med) => ListTile(
                leading: med['isMissing']
                    ? const Icon(Icons.cancel, color: Colors.red)
                    : const Icon(Icons.check_circle, color: Colors.green),
                title: Text(med['drugName']?.toString() ?? '未知藥物'),
                subtitle: Text(med['isMissing']
                    ? '缺少數量: ${med['missingCount']}顆'
                    : '劑量: ${med['dose']}顆'),
              ))
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              '無藥物數據',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        const Divider(),

        // 添加「確認完畢」按鈕
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
    '早餐後',
    '中餐後',
    '晚餐後',
    '早餐前',
    '中餐前',
    '晚餐前',
    '睡前',
  ];

  @override
  void initState() {
    super.initState();
    _loadArguments();
  }

  void _loadArguments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          _selectedPatientName = args['patientName']?.toString();
          _selectedPatientId = args['patientId']?.toString();
        });
        _fetchMedications();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '無效的患者資料';
        });
      }
    });
  }

  Future<void> _fetchMedications() async {
    if (_selectedPatientId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未選擇患者';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
          setState(() {
            _medications = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        } else {
          throw Exception('資料格式錯誤');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '錯誤: $e';
      });
    }
  }

  Future<void> _deleteMedication(String drugId, String addedDay) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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
              WHERE DrugID = '$drugId' AND PatientID = '$_selectedPatientId'
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
      setState(() {
        _isLoading = false;
        _errorMessage = '錯誤: $e';
      });
    }
  }

  Future<void> _updateMedication({
  required String drugId,
  required String addedDay,
  required String timing,
  required String dose,
  required String days,
}) async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final sanitizedTiming = timing.replaceAll("'", "''");
    final sanitizedDose = dose.replaceAll("'", "''");
    final sanitizedDays = days.replaceAll("'", "''");

    // 換成yyyy-MM-dd HH:mm:ss
    final parsedDateTime = DateTime.parse(addedDay);
    final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDateTime);

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
            AND PatientID = '$_selectedPatientId'
            AND Timing = '$sanitizedTiming'
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
    setState(() {
      _isLoading = false;
      _errorMessage = '錯誤: $e';
    });
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
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
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
              if (int.tryParse(doseController.text) == null ||
                  int.parse(doseController.text) <= 0 ||
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
      formattedAddedDay = medication['Added_Day'].toString(); // Fallback to raw string
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

  final List<String> _usageOptions = [
    '早餐後',
    '中餐後',
    '晚餐後',
    '早餐後,中餐後',
    '早餐後,晚餐後',
    '中餐後,晚餐後',
    '早餐後,中餐後,晚餐後',
    '早餐前',
    '中餐前',
    '晚餐前',
    '早餐前,中餐前',
    '早餐前,晚餐前',
    '中餐前,晚餐前',
    '早餐前,中餐前,晚餐前',
    '睡前',
  ];

  @override
  void initState() {
    super.initState();
    _syncAuthData();
    _checkLoginStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _parseJsonResponse();
      }
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
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('請先登錄')),
          );
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
      if (jsonData is String) {
        jsonData = jsonDecode(jsonData);
      }
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('JSON 格式錯誤');
      }

      String usageText = '';
      final usage = jsonData['usage'];
      if (usage is List<dynamic>) {
        usageText = usage.map((e) => e?.toString() ?? '').join(',');
      } else if (usage is String) {
        usageText = usage;
      } else if (usage != null) {
        usageText = usage.toString();
      }

      final validTimes = ['早餐後', '中餐後', '晚餐後', '早餐前', '中餐前', '晚餐前', '睡前'];
      final usageParts = usageText
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && validTimes.contains(e))
          .toList();
      usageText = usageParts.join(',');

      String? matchedOption = _usageOptions.contains(usageText) ? usageText : null;

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
  try {
    final sanitizedPatientName = _sanitizeInput(patientName);
    final sanitizedDrugName = _sanitizeInput(drugName);

    // 主查詢：直接查詢 patients 和 drugs 表
    final sql = """
      SELECT 
        p.PatientID AS patient_id,
        d.DrugID AS drug_id
      FROM patients p, drugs d
      WHERE TRIM(LOWER(p.PatientName)) = '$sanitizedPatientName'
      AND TRIM(LOWER(d.DrugName)) = '$sanitizedDrugName'
    """;

    print('Executing SQL: $sql');
    print('Sanitized PatientName: $sanitizedPatientName');
    print('Sanitized DrugName: $sanitizedDrugName');

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

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode != 200) {
      print('Non-200 response: ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body);
    print('Parsed data: $data');

    // 處理可能的回應格式
    if (data is List && data.isNotEmpty && data[0] is Map<String, dynamic>) {
      final result = data[0];
      if (result['patient_id'] != null && result['drug_id'] != null) {
        return {
          'patient_id': result['patient_id'],
          'drug_id': result['drug_id']
        };
      }
    } else if (data is Map<String, dynamic> && data['patient_id'] != null && data['drug_id'] != null) {
      return {
        'patient_id': data['patient_id'],
        'drug_id': data['drug_id']
      };
    }

    // 備用查詢：如果主查詢失敗，嘗試單獨查詢 drugs 表
    final fallbackSql = """
      SELECT DrugID, DrugName
      FROM drugs
      WHERE TRIM(LOWER(DrugName)) = '$sanitizedDrugName'
    """;

    print('Executing fallback SQL: $fallbackSql');

    final fallbackResponse = await HttpClient.instance.post(
      Uri.parse('https://project.1114580.xyz/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _cachedUsername,
        'password': _cachedPassword,
        'requestType': 'sql search',
        'data': {'sql': fallbackSql}
      }),
    );

    print('Fallback response status: ${fallbackResponse.statusCode}');
    print('Fallback response body: ${fallbackResponse.body}');

    if (fallbackResponse.statusCode == 200) {
      final fallbackData = jsonDecode(fallbackResponse.body);
      print('Fallback parsed data: $fallbackData');
      if (fallbackData is List && fallbackData.isNotEmpty) {
        print('Found DrugName in fallback: ${fallbackData[0]['DrugName']}');
      }
    }

    return null;
  } catch (e, stackTrace) {
    print('Error in _verifyPatientAndDrug: $e');
    print('Stack trace: $stackTrace');
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

  Future<bool> _addDrugToDatabase(String drugName) async {
    try {
      final sanitizedDrugName = _sanitizeInput(drugName);
      final sql = """
        INSERT INTO drugs (DrugName)
        VALUES ('$sanitizedDrugName');
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
                      final success = await _addDrugToDatabase(inputDrugName);
                      if (!success) {
                        throw Exception('無法將藥物名稱添加到資料庫');
                      }
                      if (mounted) {
                        setState(() {
                          _medicationController.text = inputDrugName;
                        });
                        await _saveToServer(force: true);
                        if (_scaffoldMessenger != null) {
                          _scaffoldMessenger!.showSnackBar(
                            SnackBar(content: Text('資料保存成功')),
                          );
                        }
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

  setState(() {
    _isSaving = true;
  });

  try {
    // 驗證必要字段
    if (appState.currentPatientName == null ||
        _medicationController.text.isEmpty ||
        _selectedUsage == null ||
        _dosageController.text.isEmpty ||
        _daysController.text.isEmpty) {
      throw Exception('請填寫所有必要字段');
    }

    final patientName = _sanitizeInput(appState.currentPatientName!);
    final medication = _sanitizeInput(_medicationController.text);
    final dose = _sanitizeInput(_dosageController.text);
    final days = _sanitizeInput(_daysController.text);

    // 驗證劑量和天數為數字
    final doseNum = int.tryParse(dose);
    final daysNum = int.tryParse(days);
    if (doseNum == null || daysNum == null) {
      throw Exception('劑量和處方天數必須為數字');
    }

    // 驗證用藥時間
    final usageTimes = _selectedUsage!.split(',').map((e) => e.trim()).toList();
    if (usageTimes.isEmpty) {
      throw Exception('用藥時間無效');
    }

    final validTimes = ['早餐後', '中餐後', '晚餐後', '早餐前', '中餐前', '晚餐前', '睡前'];
    final invalidTimes = usageTimes.where((time) => !validTimes.contains(time)).toList();
    if (invalidTimes.isNotEmpty) {
      throw Exception('無效的用藥時間: ${invalidTimes.join(', ')}');
    }

    // 檢查患者和藥物是否存在
    final verificationResult = await _verifyPatientAndDrug(patientName, medication);

    if (verificationResult != null) {
      // 藥物和患者存在，直接插入資料庫
      final patientId = verificationResult['patient_id'];
      final drugId = verificationResult['drug_id'];

      final sqlValues = usageTimes.map((timing) {
        final sanitizedTiming = _sanitizeInput(timing);
        return "('$patientId', '$drugId', '$sanitizedTiming', '$dose', '$days')";
      }).join(',');

      final sql = """
        INSERT INTO medications (PatientID, DrugID, Timing, Dose, days)
        VALUES $sqlValues;
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

      if (response.statusCode != 200) {
        String errorMsg = '保存失敗: HTTP ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error']?.toString() ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }

      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('資料保存成功')),
        );
        _resetForm();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
        Provider.of<AppState>(context, listen: false).refreshHomeData();
      }
    } else {
      // 藥物不存在，檢查是否有相似藥物
      final similarDrug = await _checkSimilarDrugName(medication);
      if (mounted) {
        if (similarDrug != null) {
          _showSimilarDrugDialog(medication, similarDrug);
        } else {
          _showNewDrugConfirmationDialog(medication);
        }
      }
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
                    setState(() {
                      _selectedUsage = newValue;
                    });
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