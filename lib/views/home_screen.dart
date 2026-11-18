import 'package:flutter/material.dart';
import 'calendar_view.dart';
import 'session_generation_screen.dart';
import 'service_type_management_screen.dart';
import 'sync_bridge_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleGenerationSuccess() {
    setState(() {
      _selectedIndex = 0; // Navigate back to calendar tab
    });
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const CalendarView(),
      SessionGenerationScreen(onGenerationSuccess: _handleGenerationSuccess),
      const ServiceTypeManagementScreen(),
      const SyncBridgeScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF0F172A), // Slate 900
          selectedItemColor: const Color(0xFF6366F1), // Indigo 500
          unselectedItemColor: const Color(0xFF64748B), // Slate 500
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.0),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              activeIcon: Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1)),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_rounded),
              activeIcon: Icon(Icons.add_box_rounded, color: Color(0xFF6366F1)),
              label: 'Generate',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_rounded),
              activeIcon: Icon(Icons.medical_services_rounded, color: Color(0xFF6366F1)),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz_rounded),
              activeIcon: Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1)),
              label: 'AI Sync',
            ),
          ],
        ),
      ),
    );
  }
}
