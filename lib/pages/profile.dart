import 'package:flutter/material.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _Profile createState() => _Profile();
}

class _Profile extends State<Profile> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.amber,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Avatar
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white10,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage("assets/atharv pic.jpg"),
                backgroundColor: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Text(
              "User name",
              style: TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profile Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(color: Colors.grey[500], thickness: 1, endIndent: 20),
                  Text(
                    "Joined On: 12/05/2023",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    "Last Login: 12/05/2023",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuItem(Icons.category, "Categories"),
                _buildMenuItem(Icons.person_add, "Invite Friends"),
                _buildMenuItem(Icons.notifications, "Notifications"),
                _buildMenuItem(Icons.delete, "Clear Transactions"),
              ],
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Sign Out",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF393E46),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          SizedBox(width: 12),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
