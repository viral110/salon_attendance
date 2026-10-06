import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'config/app_colors.dart';
import 'modules/attendance/controllers/face_attendance_controller.dart';
import 'modules/navigation/main_navigation_page.dart';
import 'modules/staff/controllers/staff_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app orientation strictly to Portrait mode (prevents landscape rotation)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Get.put(StaffController());
  Get.put(FaceAttendanceController());

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const SalonAttendanceApp(),
    ),
  );
}

class SalonAttendanceApp extends StatelessWidget {
  const SalonAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Staff Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      home: const MainNavigationPage(),
    );
  }
}
