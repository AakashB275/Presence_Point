import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/CustomAppBar.dart';
import '../widgets/CustomDrawer.dart';

class NewOrganisation extends StatefulWidget {
  const NewOrganisation({super.key});

  @override
  State<NewOrganisation> createState() => _NewOrganisationState();
}

class _NewOrganisationState extends State<NewOrganisation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("New Organisation"),
          centerTitle: true,
          backgroundColor: Colors.amber,
        ),
        body: SingleChildScrollView(
          child: Container(
            color: Colors.white,
            child: Column(children: [
              SizedBox(height: 30),
              Text(
                "Create an Organisation",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 30),
              Text(
                "Join an Organisation",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              )
            ]),
          ),
        ));
  }
}
