// Copyright (c) 2015, Rik Bellens. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library firebase.test;

import 'package:firebase_rest/firebase_rest.dart';
import 'package:test/test.dart';

void main() {
  group('Reading data', () {
    Firebase ref;
    setUp(() {
      ref = new Firebase(Uri.parse('https://publicdata-weather.firebaseio.com/'));
    });

    test('Reading value', () async {
      DataSnapshot snapshot = await ref.child('sanfrancisco/currently/cloudCover').get();
      expect(snapshot.val, new isInstanceOf<num>());
    });

    test('Limit query', () async {
      DataSnapshot snapshot = await ref.limitToFirst(4).get();
      expect(snapshot.val.keys.length, 4);
    });

    test('Order query', () async {
      return; //TODO: fallback when no index
      DataSnapshot snapshot = await ref.orderByChild("offset").limitToFirst(4).get();
      expect(snapshot.val.keys.length, 4);
    });
  });

  group('Writing data', () {
    Firebase ref;
    setUp(() {
      ref = new Firebase(Uri.parse('https://n6ufdauwqsdfmp.firebaseio-demo.com/'));
    });

    test('Setting data',() async {
      var fred = ref.child('fred/name');

      await fred.child('first').set('Fred');
      await fred.child('last').set('Flintstone');

      var v = (await fred.get()).val;

      expect(v["first"], "Fred");
      expect(v["last"], "Flintstone");

      await fred.set(null);

      var s = (await fred.get());

      expect(s.exists, isFalse);
    });

    test('Push and update', () async {
      var someone = await ref.push({
        "first": "Fred",
        "last": "Flintstone"
      });

      var v = (await someone.get()).val;

      expect(v["first"], "Fred");
      expect(v["last"], "Flintstone");

      await someone.update({ "first": 'Wilma' });

      v = (await someone.get()).val;

      expect(v["first"],"Wilma");
      expect(v["last"],"Flintstone");

      await someone.remove();
      var s = (await someone.get());

      expect(s.exists, isFalse);
    });


  });
}
