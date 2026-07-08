import 'package:flutter/material.dart';
import 'package:medical_empanelment_nhpc/screens/login_page.dart';
import 'package:medical_empanelment_nhpc/screens/hospital_list_screen.dart';
import 'package:medical_empanelment_nhpc/screens/hospital_detail_screen.dart';
import 'models/hospital.dart';
import '/screens/initial_screen.dart';
import 'screens/report_error_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NHPC Medical App',
      // Add this to disable overscroll globally
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: NoOverscrollBehavior(),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialScreen(),
        '/login': (context) => const LoginPage(),
        '/hospitalList': (context) => const HospitalListPage(),
        '/reportError': (context) => const ReportErrorScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/hospitalDetails') {
          final hospital = settings.arguments as Hospital;
          return MaterialPageRoute(
            builder: (context) => HospitalDetailsPage(hospital: hospital),
          );
        }
        return null;
      },
    );
  }
}

// Custom ScrollBehavior to disable overscroll effects
class NoOverscrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Return child without any overscroll indicator
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(); // Prevents overscroll
  }
}

class ReportErrorFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const ReportErrorFAB({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.report_problem, color: Colors.white),
      label: const Text('Give Feedback', style: TextStyle(color: Colors.white)),
      backgroundColor: const Color.fromARGB(255, 37, 218, 234),
      heroTag: 'report_error_fab',
    );
  }
}
