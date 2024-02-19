import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'google_maps.dart';
import 'notification_controller.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelGroupKey: "basic_channel_group",
      channelKey: "basic_channel",
      channelName: "basic_notif",
      channelDescription: "basic notification channel",
    )
  ], channelGroups: [
    NotificationChannelGroup(
        channelGroupKey: "basic_channel_group", channelGroupName: "basic_group")
  ]);

  bool isAllowedToSendNotification =
  await AwesomeNotifications().isNotificationAllowed();

  if (!isAllowedToSendNotification) {
    AwesomeNotifications().requestPermissionToSendNotifications();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => const MainListScreen(),
        '/login': (context) => const AuthScreen(isLogin: true),
        '/register': (context) => const AuthScreen(isLogin: false),
      },
    );
  }
}

class Exam{
  String course;
  String description;
  DateTime timestamp;

  Exam({
    required this.course,
    required this.timestamp,
    required this.description,
  });
}


enum PermissionGroup { locationAlways, locationWhenInUse }

class Location {
  String name;
  double latitude;
  double longitude;

  Location(this.name, this.latitude, this.longitude);
}

class NotificationService {
  int idCount = 0;
  bool locationNotificationActive = false;
  Location location = Location("University", 42.004186212873655, 21.409531941596985);
  DateTime? lastNotificationTime;

  NotificationService() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (locationNotificationActive) {
        checkLocationAndNotify();
      }
    });
  }

  void scheduleNotificationsForExistingExams(exams) {
    for (int i = 0; i < exams.length; i++) {
      scheduleNotification(exams[i]);
    }
  }

  void scheduleNotification(Exam exam) {
    final int notificationId = idCount++;

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: "basic_channel",
        title: exam.course,
        body: "You have an exam tomorrow!",
      ),
      schedule: NotificationCalendar(
        day: exam.timestamp.subtract(const Duration(days: 1)).day,
        month: exam.timestamp.subtract(const Duration(days: 1)).month,
        year: exam.timestamp.subtract(const Duration(days: 1)).year,
        hour: exam.timestamp.subtract(const Duration(days: 1)).hour,
        minute: exam.timestamp.subtract(const Duration(days: 1)).minute,
      ),
    );
  }

  Future<void> toggleLocationNotification() async {
    locationNotificationActive = !locationNotificationActive;

    if (locationNotificationActive) {
      checkLocationAndNotify();
    }
  }

  Future<void> checkLocationAndNotify() async {
    if (await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      bool theSameLocation = false;

      LocationService().getCurrentLocation().then((value) {
        if ((value.latitude < location.latitude + 0.01 &&
            value.latitude > location.latitude - 0.01) &&
            (value.longitude < location.longitude + 0.01 &&
                value.longitude > location.longitude - 0.01)) {
          theSameLocation = true;
        }

        if (theSameLocation && canSendNotification()) {
          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: idCount++,
              channelKey: "basic_channel",
              title: "Work!",
              body: "You have an exam soon!",
            ),
          );
          lastNotificationTime = DateTime.now();
        }
      });
    }
  }

  bool canSendNotification() {
    return lastNotificationTime == null ||
        DateTime.now().difference(lastNotificationTime!) >
            const Duration(minutes: 10);
  }
}
class CalendarWidget extends StatelessWidget {
  final List<Exam> exams;

  const CalendarWidget({super.key, required this.exams});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
      ),
      body: SfCalendar(
        view: CalendarView.month,
        dataSource: _getCalendarDataSource(),
        onTap: (CalendarTapDetails details) {
          if (details.targetElement == CalendarElement.calendarCell) {
            _handleDateTap(context, details.date!);
          }
        },
      ),
    );
  }

  _DataSource _getCalendarDataSource() {
    List<Appointment> appointments = [];

    for (var exam in exams) {
      appointments.add(Appointment(
        startTime: exam.timestamp,
        endTime: exam.timestamp.add(const Duration(hours: 2)),
        subject: exam.course,
      ));
    }

    return _DataSource(appointments);
  }

  void _handleDateTap(BuildContext context, DateTime selectedDate) {
    List<Exam> selectedExams = exams
        .where((exam) =>
    exam.timestamp.year == selectedDate.year &&
        exam.timestamp.month == selectedDate.month &&
        exam.timestamp.day == selectedDate.day)
        .toList();

    if (selectedExams.isNotEmpty) {
      _showExamsDialog(context, selectedDate, selectedExams);
    }
  }

  void _showExamsDialog(
      BuildContext context, DateTime selectedDate, List<Exam> exams) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Exams on ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: exams
                .map((exam) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exam.course}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Time: ${DateFormat.Hm().format(exam.timestamp)}',
                ),
                SizedBox(height: 4),
                Text(
                  'Description: ${exam.description}',
                ),
                SizedBox(height: 16),
              ],
            ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

}

class _DataSource extends CalendarDataSource {
  _DataSource(List<Appointment> source) {
    appointments = source;
  }
}


class ExamWidget extends StatefulWidget {
  final Function(Exam) addExam;

  const ExamWidget({required this.addExam, super.key});

  @override
  ExamWidgetState createState() => ExamWidgetState();
}

class ExamWidgetState extends State<ExamWidget> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? datePicked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2025),
    );

    if (datePicked != null && datePicked != selectedDate) {
      setState(() {
        selectedDate = datePicked;
      });
    }
  }

  void _selectTime(BuildContext context) async {
    final TimeOfDay? timePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
    );

    if (timePicked != null && timePicked != selectedTime) {
      setState(() {
        selectedDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          timePicked.hour,
          timePicked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white30,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Предмет'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Забелешки'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                ElevatedButton(
                  child: const Text('Селектирај датум'),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Time: ${selectedDate.toLocal().toString().split(' ')[1].substring(0, 5)}'),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: const Text('Време'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Exam exam = Exam(
                  course: subjectController.text,
                  description: descriptionController.text,
                  timestamp: selectedDate,

                );
                widget.addExam(exam);
                Navigator.pop(context);
              },
              child: const Text('Додади'),
            ),
          ],
        ),
      ),
    );
  }
}

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Map'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(41.9981, 21.4254),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mk.ukim.finki.mis',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  42.004186212873655,
                  21.409531941596985,
                ),
                width: 100,
                height: 100,
                child: GestureDetector(
                  onTap: () {
                    // Show the alert dialog here
                    _showAlertDialog();
                  },
                  child: const Icon(Icons.pin_drop),
                ),
              )
            ],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Function to show the alert dialog
  Future<void> _showAlertDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Open Google Maps?'),
          content: const Text('Do you want to open Google Maps for routing?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                GoogleMaps.openGoogleMaps(
                    42.004186212873655,
                    21.409531941596985);
                Navigator.of(context).pop();
              },
              child: const Text('Open'),
            ),
          ],
        );
      },
    );
  }
}










class MainListScreen extends StatefulWidget {
  const MainListScreen({super.key});

  @override
  MainListScreenState createState() => MainListScreenState();
}

class MainListScreenState extends State<MainListScreen> {
  final List<Exam> exams = [
    Exam(course: 'VNP', timestamp: DateTime(2024, 1, 8, 14, 40), description: 'Да ги повторам последните предавања'),
    Exam(course: 'IPNKS', timestamp: DateTime(2024, 1, 9, 15, 30), description: 'Да изгледам ауд4 и ауд5'),
    Exam(course: 'MIS', timestamp: DateTime(2024, 1, 11, 12, 00), description: 'Лабараториска вежба'),
    Exam(course: 'MPIP', timestamp: DateTime(2024, 1, 22, 14, 00), description: 'Консултации во петок'),
    Exam(course: 'IPNKS', timestamp: DateTime(2024, 2, 21, 16, 15), description: 'Тест')
  ];

  bool _isLocationBasedNotificationsEnabled = false;
  @override
  void initState() {
    super.initState();

    AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceiveMethod,
        onDismissActionReceivedMethod:
        NotificationController.onDismissActionReceiveMethod,
        onNotificationCreatedMethod:
        NotificationController.onNotificationCreateMethod,
        onNotificationDisplayedMethod:
        NotificationController.onNotificationDisplayed);

    NotificationService().scheduleNotificationsForExistingExams(exams);
  }

  void _scheduleNotificationsForExistingExams() {
    for (int i = 0; i < exams.length; i++) {
      _scheduleNotification(exams[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('201163 exam list'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_add),
            color: _isLocationBasedNotificationsEnabled
                ? Colors.amberAccent
                : Colors.grey,
            onPressed: _toggleLocationNotifications,
          ),
          IconButton(onPressed: _openMap, icon: const Icon(Icons.map)),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _openCalendar,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => FirebaseAuth.instance.currentUser != null
                ? _addExamFunction(context)
                : _navigateToSignInPage(context),
          ),
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: _signOut,
          ),
        ],
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: exams.length,
        itemBuilder: (context, index) {
          final course = exams[index].course;
          final description = exams[index].description;
          final timestamp = exams[index].timestamp;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(9.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description ,
                    style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black45),
                  ),

                  const SizedBox(height: 9.0),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(timestamp),
                    style: const TextStyle(color: Colors.blue),
                  ),

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }
  void _toggleLocationNotifications() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Based Notifications"),
          content: _isLocationBasedNotificationsEnabled
              ? const Text("You have turned off location-based notifications")
              : const Text("You have turned on location-based notifications"),
          actions: [
            TextButton(
              onPressed: () {
                NotificationService().toggleLocationNotification();
                setState(() {
                  _isLocationBasedNotificationsEnabled =
                  !_isLocationBasedNotificationsEnabled;
                });
                Navigator.pop(context);
              },
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }
  void _openMap() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const MapWidget()));
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarWidget(exams: exams),
      ),
    );
  }

  void _scheduleNotification(Exam exam) {
    final int notificationId = exams.indexOf(exam);

    AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: notificationId,
            channelKey: "basic_channel",
            title: exam.course,
            body: "You have an exam tomorrow!"),
        schedule: NotificationCalendar(
            day: exam.timestamp.subtract(const Duration(days: 1)).day,
            month: exam.timestamp.subtract(const Duration(days: 1)).month,
            year: exam.timestamp.subtract(const Duration(days: 1)).year,
            hour: exam.timestamp.subtract(const Duration(days: 1)).hour,
            minute: exam.timestamp.subtract(const Duration(days: 1)).minute));
  }

  void _navigateToSignInPage(BuildContext context) {
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  Future<void> _addExamFunction(BuildContext context) async {
    return showModalBottomSheet(
        context: context,
        builder: (_) {
          return GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ExamWidget(
              addExam: _addExam,
            ),
          );
        });
  }

  void _addExam(Exam exam) {
    setState(() {
      exams.add(exam);
      _scheduleNotification(exam);
    });
  }
}

class AuthScreen extends StatefulWidget {
  final bool isLogin;

  const AuthScreen({super.key, required this.isLogin});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
  GlobalKey<ScaffoldMessengerState>();

  Future<void> _authAction() async {
    try {
      if (widget.isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        _showSuccessDialog(
            "Login Successful", "You have successfully logged in!");
        _navigateToHome();
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        _showSuccessDialog(
            "Registration Successful", "You have successfully registered!");
        _navigateToLogin();
      }
    } catch (e) {
      _showErrorDialog(
          "Authentication Error", "Error during authentication: $e");
    }
  }

  void _showSuccessDialog(String title, String message) {
    _scaffoldKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _navigateToHome() {
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacementNamed(context, '/');
    });
  }

  void _navigateToLogin() {
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  void _navigateToRegister() {
    Future.delayed(Duration.zero, () {
      Navigator.pushReplacementNamed(context, '/register');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.isLogin ? const Text("Најава") : const Text("Регистрирај се"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authAction,
              child: Text(widget.isLogin ? "Најави се" : "Регистрирај корисник"),
            ),
            if (!widget.isLogin)
              TextButton(
                onPressed: _navigateToLogin,
                child: const Text('Веќе имате акаунт? Најави се'),
              ),
            if (widget.isLogin)
              TextButton(
                onPressed: _navigateToRegister,
                child: const Text('Креирај акаунт'),
              ),
            TextButton(
              onPressed: _navigateToHome,
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }
}



