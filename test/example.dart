
import 'package:firebase_rest/firebase_rest.dart';

main() async {
  var ref = new Firebase(Uri.parse("https://publicdata-weather.firebaseio.com/sanfrancisco/currently/cloudCover"));

  var snapshot = await ref.get();

  print(snapshot.val);
}