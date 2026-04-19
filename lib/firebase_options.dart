import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDES15YEYMMvklCrTijFSmtARPHBt0r6fY',
    appId: '1:52845022434:android:c7e60d9505b1c2939922bb',
    messagingSenderId: '52845022434',
    projectId: 'yugenmanga-1f805',
    storageBucket: 'yugenmanga-1f805.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDES15YEYMMvklCrTijFSmtARPHBt0r6fY',
    appId: '1:52845022434:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '52845022434',
    projectId: 'yugenmanga-1f805',
    storageBucket: 'yugenmanga-1f805.firebasestorage.app',
    iosBundleId: 'com.jepoydev.yugenmangaApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDES15YEYMMvklCrTijFSmtARPHBt0r6fY',
    appId: '1:52845022434:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '52845022434',
    projectId: 'yugenmanga-1f805',
    storageBucket: 'yugenmanga-1f805.firebasestorage.app',
    iosBundleId: 'com.jepoydev.yugenmangaApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDES15YEYMMvklCrTijFSmtARPHBt0r6fY',
    appId: '1:52845022434:web:d7f50d8a5f7fda209922bb',
    messagingSenderId: '52845022434',
    projectId: 'yugenmanga-1f805',
    authDomain: 'yugenmanga-1f805.firebaseapp.com',
    storageBucket: 'yugenmanga-1f805.firebasestorage.app',
  );
}