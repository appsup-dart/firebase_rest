# firebase

A library for reading and writing data to a Firebase database

## Usage

A simple usage example:

    import 'package:firebase/firebase.dart';

    main() {
      var ref = new Firebase("https://publicdata-weather.firebaseio.com/sanfrancisco/currently/cloudCover");

      var snapshot = ref.get();

      print(snapshot.val);
    }

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase/issues
