# firebase_rest for Dart

A [Dart][dart] library for reading and writing data to a Firebase database.

This library uses the Firebase's REST API
and works on both server (`dart:io`) and client (`dart:html`).

## Usage

A simple usage example:

    import 'package:firebase_rest/firebase_rest.dart';

    main() async {
      var uri = Uri.parse("https://publicdata-weather.firebaseio.com/sanfrancisco/currently/cloudCover");
      var ref = new Firebase(uri);

      var snapshot = await ref.get();

      print(snapshot.val);
    }

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase/issues
[dart]: https://www.dartlang.org