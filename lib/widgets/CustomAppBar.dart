import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final GlobalKey<ScaffoldState> scaffoldKey; // ✅ Ensure this key is required

  const CustomAppBar({Key? key, required this.title, required this.scaffoldKey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.amber,
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: false, // ✅ Prevents default back button
      leading: IconButton(
        icon: Icon(Icons.menu),
        onPressed: () {
          scaffoldKey.currentState
              ?.openDrawer(); // ✅ Opens the drawer correctly
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.account_circle_rounded),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/profile");
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
