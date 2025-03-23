// lib/pages/Auth/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;

  List<Widget> _buildPageIndicator() {
    List<Widget> indicators = [];
    for (int i = 0; i < _numPages; i++) {
      indicators.add(
        Container(
          width: 8.0,
          height: 8.0,
          margin: EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == i ? Colors.blue : Colors.grey,
          ),
        ),
      );
    }
    return indicators;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // Skip onboarding
                  Provider.of<UserState>(context, listen: false)
                      .completeOnboarding();
                },
                child: Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // First onboarding page
                  _buildOnboardingPage(
                    title: 'Welcome to Presence Point',
                    description:
                        'The easiest way to manage attendance and leaves',
                    image: Icons.access_time, // Replace with your image
                  ),
                  // Second onboarding page
                  _buildOnboardingPage(
                    title: 'Track Attendance',
                    description: 'Clock in and out with a single tap',
                    image: Icons.location_on, // Replace with your image
                  ),
                  // Third onboarding page
                  _buildOnboardingPage(
                    title: 'Manage Teams',
                    description: 'Create and manage your organization easily',
                    image: Icons.people, // Replace with your image
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(children: _buildPageIndicator()),
                  // Next/Done button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _numPages - 1) {
                        // If on last page, complete onboarding
                        Provider.of<UserState>(context, listen: false)
                            .completeOnboarding();
                      } else {
                        // Otherwise go to next page
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Text(
                        _currentPage == _numPages - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String description,
    required IconData image,
  }) {
    return Padding(
      padding: EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(image, size: 120.0, color: Colors.blue),
          SizedBox(height: 30.0),
          Text(
            title,
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15.0),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
