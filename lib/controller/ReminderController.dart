import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../model/Reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../view/ReminderPage.dart';

tz.Location _local = tz.local;

class ReminderController extends GetxController {
  var reminders = <ReminderModel>[].obs;
  final String baseUrl = "http://10.0.2.2:8000/api/";
  late String? authToken;
  bool isLoading = false;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void onInit() {
    tz.initializeTimeZones();
    _loadToken();
    fetchReminders();
    _initNotifications();
    super.onInit();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('auth_token');
    print('Auth Token Loaded: $authToken');
    if (authToken == null) {
      Get.snackbar("Error", "No authentication token found!");
    }
    await fetchReminders();
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
  }

  Future<void> fetchReminders() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}Reminder'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        reminders.assignAll(data.map((e) => ReminderModel.fromJson(e)));
      }
    } catch (e) {
      print('Fetch Error: $e');
      Get.snackbar("Error", "Failed to load reminders");
    }
  }

  Future<bool> addReminder(ReminderModel reminder) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}addReminder'),
        headers: _headers,
        body: json.encode({
          'name': reminder.name,
          'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(reminder.time),
          'price': reminder.price,
          'collectedoprice': reminder.collectedoprice,
        }),
      );

      if (response.statusCode == 201) {
        final newReminder =
            ReminderModel.fromJson(json.decode(response.body)['data']);
        reminders.insert(0, newReminder);
        await _scheduleNotification(newReminder);
        update();
        return true;
      } else {
        print('Error ${response.statusCode}: ${response.body}');
        return false;
      }
      return false;
    } catch (e) {
      print('Error adding reminder: $e');
      Get.snackbar("Error", "Failed to add reminder");
      return false;
    }
  }

  Future<bool> deleteReminder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${baseUrl}deleteReminder/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        await _cancelNotification(id);
        await fetchReminders();
        return true;
      } else {
        print('Delete Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Delete Exception: $e');
      Get.snackbar("Error", "Failed to delete reminder");
      return false;
    }
  }

  Future<bool> updateReminder(ReminderModel reminder) async {
    try {
      final response = await http.put(
        Uri.parse('${baseUrl}updateReminder/${reminder.id}'),
        headers: _headers,
        body: json.encode({
          'name': reminder.name,
          'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(reminder.time),
          'price': reminder.price,
          'collectedoprice': reminder.collectedoprice,
        }),
      );

      if (response.statusCode == 200) {
        fetchReminders();
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar("Error", "Failed to update reminder");
      return false;
    }
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        Get.to(() => Reminders());
      },

    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _scheduleNotification(ReminderModel reminder) async {
    print('Scheduling notification at: ${reminder.time}');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =

        AndroidNotificationDetails(
      'reminder_channel',
      'Reminder Notifications',
      importance: Importance.max,
      priority: Priority.high,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.zonedSchedule(
      reminder.id!,
      'Payment Reminder: ${reminder.name}',
      'Amount: \$${reminder.price.toStringAsFixed(2)}',
      tz.TZDateTime.from(reminder.time, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('Notification $id cancelled');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }
}
