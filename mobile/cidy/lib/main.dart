import 'package:flutter/material.dart';

void main() {
  runApp(Cidy());
}

class Cidy extends StatefulWidget {
  const Cidy({super.key});

  @override
  State<StatefulWidget> createState() {
    return CidyState();
  }
}

class CidyState extends State<Cidy> {
  var counter = 0;

  void increaseCounter() {
    setState(() {
      counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Cidy')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Counter: $counter'),
              ElevatedButton(
                onPressed: increaseCounter,
                child: Text('Increase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
