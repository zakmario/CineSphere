import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyCNjyZw_UGSF0ODx8iCkGk0BLNsgwr1QFA",
            authDomain: "cinesphere-app-3f710.firebaseapp.com",
            projectId: "cinesphere-app-3f710",
            storageBucket: "cinesphere-app-3f710.firebasestorage.app",
            messagingSenderId: "72965730433",
            appId: "1:72965730433:web:bd27c9711272de80be1d80"));
  } else {
    await Firebase.initializeApp();
  }
}
