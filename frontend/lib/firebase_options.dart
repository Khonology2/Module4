// Pure Dart FirebaseOptions placeholder to satisfy analyzer in non-Flutter context
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBm965H53a4Y94791AUXZNFM5ZnVvg6fU',
    appId: '1:406588005230:web:f39765b9adb38110787f7f',
    messagingSenderId: '406588005230',
    projectId: 'flow-space-d70d2',
    authDomain: 'flow-space-d70d2.firebaseapp.com',
    storageBucket: 'flow-space-d70d2.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBm965H53a4Y94791AUXZNFM5ZnVvg6fU',
    appId: '1:406588005230:android:f39765b9adb38110787f7f',
    messagingSenderId: '406588005230',
    projectId: 'flow-space-d70d2',
    storageBucket: 'flow-space-d70d2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBm965H53a4Y94791AUXZNFM5ZnVvg6fU',
    appId: '1:406588005230:ios:f39765b9adb38110787f7f',
    messagingSenderId: '406588005230',
    projectId: 'flow-space-d70d2',
    storageBucket: 'flow-space-d70d2.firebasestorage.app',
    iosBundleId: 'com.example.khono',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCBm965H53a4Y94791AUXZNFM5ZnVvg6fU',
    appId: '1:406588005230:ios:f39765b9adb38110787f7f',
    messagingSenderId: '406588005230',
    projectId: 'flow-space-d70d2',
    storageBucket: 'flow-space-d70d2.firebasestorage.app',
    iosBundleId: 'com.example.khono',
  );
}
