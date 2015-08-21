# firebase_rest

A library for reading and writing data to a Firebase database.

This library uses the firebase's REST api and works on both server and client.

## Usage

A simple usage example:

    import 'package:firebase_rest/firebase_rest.dart';

    main() async {
      var ref = new Firebase(Uri.parse("https://publicdata-weather.firebaseio.com/sanfrancisco/currently/cloudCover"));

      var snapshot = await ref.get();

      print(snapshot.val);
    }

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase/issues
