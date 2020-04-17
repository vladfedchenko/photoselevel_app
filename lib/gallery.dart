import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:exif/exif.dart';
import 'package:http/http.dart' as http;
import 'package:moor/moor.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated/l10n.dart';
import 'models/db.dart';
import 'models/gallery_models.dart';
import 'widgets/album_widget.dart';

class GalleryScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with WidgetsBindingObserver {
  Directory _mediaDir = Directory('/storage/emulated/0/DCIM');
  SharedPreferences _sharedPreferences;
  Future<bool> _allowedStorage =
      Permission.storage.request().then((value) => value.isGranted);
  DateTime _processedTime = DateTime(0);
  Map<DateTime, AlbumWithPhotos> _albums = Map<DateTime, AlbumWithPhotos>();
  List<AlbumWithPhotos> _sortedAlbums = List<AlbumWithPhotos>();
  bool _loadOngoing = false;
  Future<bool> _initialLoadFinished;

  Widget _buildGallery() {
    return ListView.separated(
      itemCount: _sortedAlbums.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.all(3),
        child: AlbumWidget(_sortedAlbums[index]),
      ),
      separatorBuilder: (_, __) => Divider(),
    );
  }

  Future<AlbumWithPhotos> _getAlbum(DateTime day) {
    return Future(() async {
      AlbumWithPhotos workAlbum;
      if (this._albums.containsKey(day)) {
        workAlbum = this._albums[day];
      } else {
        Album tmp = await PhotoselevenDB().getAlbumOnDate(day);
        if (tmp == null) {
          tmp = await PhotoselevenDB()
              .insertAlbum(AlbumsCompanion(date: Value(day)));
        }
        workAlbum = AlbumWithPhotos(tmp);
        this._albums[day] = workAlbum;
        setState(() {
          this._sortedAlbums = this._albums.values.toList();
          this._sortedAlbums.sort((a, b) => b.album.date.compareTo(a.album.date));
        });
      }
      return workAlbum;
    });
  }

  Uri _getServerUri(String path) {
    String server = _sharedPreferences.getString('server');
    if (server.startsWith('https')) {
      return Uri.https(server.split('://')[1], path);
    } else {
      return Uri.http(server.split('://')[1], path);
    }
  }

  Future<bool> _doInitialLoad() async {
    _sharedPreferences = await SharedPreferences.getInstance();
    if (!(_sharedPreferences.containsKey('username'))) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    var albumsList = await PhotoselevenDB().allAlbums;
    for (var album in albumsList) {
      this._albums[album.date] = AlbumWithPhotos(album);
    }

    this._sortedAlbums = this._albums.values.toList();
    this._sortedAlbums.sort((a, b) => b.album.date.compareTo(a.album.date));

    if (_sharedPreferences.containsKey('mediaLoadTime')) {
      _processedTime =
          DateTime.parse(_sharedPreferences.getString('mediaLoadTime'));
    }
    _tryLoadNewData(); // careful here, possible deadlock
    return true;
  }

  Future<void> _loadNewLocalPhotos(List<File> photosList) async {
    for (File photoFile in photosList) {
      var exifData = await readExifFromFile(photoFile);
      if (exifData.containsKey('EXIF DateTimeOriginal') &&
          exifData.containsKey('EXIF SubSecTimeOriginal')) {
        // Creating ID
        List<String> dayTime =
            exifData['EXIF DateTimeOriginal'].printable.split(' ');
        assert(dayTime.length == 2);
        String dateTimeID = dayTime[0].replaceAll(':', '-') +
            ' ${dayTime[1]}' +
            '.' +
            exifData['EXIF SubSecTimeOriginal'].printable;

        DateTime createdOn = DateTime.parse(dateTimeID);
        if (dayTime[1].startsWith('24:')) {
          // Library returns 12 AM as 24 and not 00 making day jump
          createdOn = createdOn.subtract(Duration(days: 1));
        }
        DateTime day = DateTime(createdOn.year, createdOn.month, createdOn.day);

        AlbumWithPhotos workAlbum = await _getAlbum(day);
        assert(workAlbum != null);

        if (!(await workAlbum.photoDates).contains(createdOn)) {
          await workAlbum.addPhoto(
            localUrl: photoFile.uri.toFilePath(),
            createdOn: createdOn,
          );
        }
      }
    }
  }

  Widget _noMediaPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          S.of(context).noStoragePermission,
          style: TextStyle(color: Theme.of(context).errorColor, fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _tryLoadNewData() async {
    if (await _allowedStorage) {
      if (await _initialLoadFinished && !_loadOngoing) {
        _loadOngoing = true;
        var photosList = _mediaDir
            .list(recursive: true)
            .where((el) => el is File)
            .cast<File>()
            .where(
                (f) => f.lastModifiedSync().compareTo(this._processedTime) > 0)
            .where((el) => el.path.endsWith('jpg'))
            .toList();
        await this._loadNewLocalPhotos(await photosList);
        this._processedTime = DateTime.now();
        _sharedPreferences.setString(
            'mediaLoadTime', this._processedTime.toString());

        await _uploadNewPhotos();
        _loadOngoing = false;
      }
    }
  }

  Future<void> _uploadNewPhotos() async {
    List<Photo> toUpload = await PhotoselevenDB().unuploadedPhotos;
    for (Photo photo in toUpload) {
      var photoFile = File(photo.localUrl);
      if (photoFile.existsSync()) {
        var request = http.StreamedRequest(
          'POST',
          _getServerUri(
              path.join('api/gallery/media', path.basename(photo.localUrl))),
        );
        request.headers.addAll({
          'Content-Type': 'image/jpeg',
          'Authorization':
              'Bearer ${this._sharedPreferences.getString("accessToken")}'
        });
        request.contentLength = await photoFile.length();
        photoFile
            .openRead()
            .listen(request.sink.add, onDone: () => request.sink.close());
        try {
          http.StreamedResponse respStream = await request.send();

          if (respStream.statusCode == 201) {
            http.Response response = await http.Response.fromStream(respStream);
            var respJson = json.decode(response.body);
            await PhotoselevenDB().markPhotoUploaded(
                photo, _getServerUri(respJson['request_path']).toString());
          }
        } on SocketException {
          // Thrown when server down and regular Request used
          // TODO: notify that upload failed
          break;
        } on HandshakeException {
          // Thrown when sending https request to http server
          // TODO: notify that upload failed
          break;
        }
        on StateError {
          // Thrown when server down and StreamedRequest used
          // TODO: notify that upload failed
          break;
        }
      } else {
        // TODO: remove file from DB.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: _allowedStorage,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data) {
            return _buildGallery();
          } else if (snapshot.hasError ||
              (snapshot.hasData && !snapshot.data)) {
            return _noMediaPermission();
          } else {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(100),
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryLoadNewData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    _initialLoadFinished = _doInitialLoad();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }
}
