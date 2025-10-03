import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    try {
      if (Platform.isAndroid) {
        print('Loading Android Firebase configuration');
        return android;
      } else if (Platform.isIOS) {
        print('Loading iOS Firebase configuration');
        return ios;
      }
    } catch (e) {
      print('Error detecting platform: $e');
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
        apiKey: "AIzaSyCdMf127-hee7Bs6f9dXYWwFZe3LzDtpzg",
        authDomain: "nudge-965c2.firebaseapp.com",
        projectId: "nudge-965c2",
        storageBucket: "nudge-965c2.firebasestorage.app",
        messagingSenderId: "40187814474",
        appId: "1:40187814474:web:5ee6d05692a546139efcb3",
        measurementId: "G-W4D7X08ZQ7"
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCdMf127-hee7Bs6f9dXYWwFZe3LzDtpzg",
      authDomain: "nudge-965c2.firebaseapp.com",
      projectId: "nudge-965c2",
      storageBucket: "nudge-965c2.firebasestorage.app",
      messagingSenderId: "40187814474",
      appId: "1:40187814474:web:5ee6d05692a546139efcb3",
      measurementId: "G-W4D7X08ZQ7",
      iosClientId: '40187814474-11mli98p5sdgjl2ve9h230hifooahh6j.apps.googleusercontent.com', // For Google Sign-In
      iosBundleId: 'com.nudge.shay', // Make sure this matches exactly
  );
}