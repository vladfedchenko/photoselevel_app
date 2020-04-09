import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';

import 'generated/l10n.dart';

class GalleryScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with WidgetsBindingObserver {
  Directory _mediaDir = Directory('/storage/emulated/0/DCIM/Camera');
  bool _allowedStorage = false;
  List<File> _photos = List<File>();

  Widget _buildGallery() {
    return Scrollbar(
      child: GridView.builder(
        itemCount: _photos.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemBuilder: (context, index) {
          return FutureBuilder(
            future: _toFuture(_photos[index]),
            builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (!snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Image.file(
                      _photos[index],
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    ),
                  );
                } else {
                  return Center(
                    child: Icon(
                      Icons.error,
                      color: Colors.redAccent,
                    ),
                  );
                }
              } else {
                return Padding(
                  child: CircularProgressIndicator(),
                  padding: const EdgeInsets.all(50),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<File> _toFuture(File photoFile) async {
    return photoFile;
  }

  Widget _noMediaPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          S.of(context).noStoragePermission,
          style: TextStyle(color: Colors.redAccent, fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onPermissionChanged(bool newPermission) async {
    if (newPermission) {
      var futurePhotos = await _mediaDir
          .list()
          .where((el) => el is File)
          .where((el) => el.path.endsWith('jpg'))
          .toList();
      _photos = futurePhotos.whereType<File>().toList();
    }
    setState(() {
      _allowedStorage = newPermission;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(),
        body: _allowedStorage ? _buildGallery() : _noMediaPermission());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_allowedStorage) {
        _onPermissionChanged(_allowedStorage);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    Permission.storage.request().then((value) {
      _onPermissionChanged(value.isGranted);
    });
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }
}
