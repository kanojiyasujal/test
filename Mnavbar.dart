
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:fire/maps/audio.dart';
import 'package:fire/maps/profile.dart';
import 'package:flutter/material.dart';

import 'people.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  final items = const [
    Icon(Icons.settings, size: 30,),
    Icon(Icons.location_pin, size: 30,),
    Icon(Icons.search, size: 30,),
    Icon(Icons.location_history, size: 30,)
  ];

  int index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text('Curved Navigation Bar'),
        backgroundColor: Colors.blue[300],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        items: items,
        index: index,
        onTap: (selctedIndex){
          setState(() {
            index = selctedIndex;
          });
        },
        height: 70,
        backgroundColor: Colors.transparent,
        animationDuration: const Duration(milliseconds: 300),
        // animationCurve: ,
      ),
      body: Container(
        color: Colors.blue,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: getSelectedWidget(index: index)
      ),
    );
  }

  Widget getSelectedWidget({required int index}){
    Widget widget;
    switch(index){
      case 0:
        widget =  audio();
        break;
      case 1:
        widget = const Profile();
        break;
      default:
        widget = const People();
        break;
    }
    return widget;
  }
}
