import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/prefs.dart';
import 'package:presence_point_2/pages/new_organisation.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<String> _titles = [
    "Welcome to Our App",
    "Track Your Work Efficiently",
    "Join an Organization"
  ];

  final List<String> _descriptions = [
    "Easily manage your tasks and track work hours.",
    "Stay productive with smart tracking and insights.",
    "Connect with your organization to get started."
  ];

  void _completeOnboarding() async {
    await Prefs.setFirstTimeUser(false);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => NewOrganisation()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _titles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_titles[index],
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Text(_descriptions[index], textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _titles.length,
              (index) => Container(
                margin: EdgeInsets.all(4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _currentPage == _titles.length - 1
                ? _completeOnboarding
                : () => _controller.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut),
            child: Text(
                _currentPage == _titles.length - 1 ? "Get Started" : "Next"),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
