import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/l10n.dart';

import 'gallery.dart';
import 'login.dart';

void main() {
  runApp(PhotoselevenApp());
}

class PhotoselevenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: S.delegate.supportedLocales,
      title: 'photoseleven',
      onGenerateTitle: (context) => S.of(context).title,
      theme: ThemeData(
        primaryColor: Colors.black,
      ),
      initialRoute: '/galery',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/galery': (context) => GalleryScreen(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/login': (context) => LoginScreen(),
      },
    );
  }
}
