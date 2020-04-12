import 'dart:io';

import 'package:moor/moor.dart';

import 'db.dart';

class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get album => integer()();

  TextColumn get localUrl => text().nullable()();

  TextColumn get remoteUrl => text().nullable()();

  TextColumn get createdOnText => text()();

  BoolColumn get existLocal => boolean().withDefault(const Constant(true))();

  BoolColumn get existRemote => boolean().withDefault(const Constant(false))();
}

class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  IntColumn get photosCount => integer().withDefault(const Constant(0))();
}

class AlbumWithPhotos {
  final Album album;
  Future<List<Photo>> _photosOrdered;
  Future<Set<DateTime>> _photoDates;

  AlbumWithPhotos(this.album);

  Future<Set<DateTime>> get photoDates {
    if (_photoDates == null) {
      _photoDates = this.photosOrdered.then(
          (l) => Set()..addAll(l.map((p) => DateTime.parse(p.createdOnText))));
    }
    return _photoDates;
  }

  Future<List<Photo>> get photosOrdered {
    if (this._photosOrdered == null) {
      _photosOrdered = PhotoselevenDB().getAlbumPhotosOrdered(album);
    }
    return _photosOrdered;
  }

  void _reloadPhotos() {
    this._photosOrdered = null; // will be fetched lazily when requested
    this._photoDates = null;
  }

  Future<void> addPhoto(
      {@required DateTime createdOn, @required String localUrl}) async {
    await PhotoselevenDB().insertPhoto(PhotosCompanion(
      album: Value(album.id),
      createdOnText: Value(createdOn.toString()),
      localUrl: Value(localUrl),
    ));
    this._reloadPhotos();
  }
}
