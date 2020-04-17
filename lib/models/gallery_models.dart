import 'package:moor/moor.dart';
import 'package:path/path.dart' as path;

import 'db.dart';

class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get filename => text()();

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
  final Set<Function> _onPhotosResetCallbacks = Set<Function>();
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
    for (var f in _onPhotosResetCallbacks) {
      f();
    }
  }

  void addPhotoResetCallback(Function f) {
    _onPhotosResetCallbacks.add(f);
  }

  void removePhotoResetCallback(Function f) {
    _onPhotosResetCallbacks.remove(f);
  }

  Future<void> addPhoto(
      {@required DateTime createdOn, @required String localUrl}) async {
    await PhotoselevenDB().insertPhoto(PhotosCompanion(
      album: Value(album.id),
      filename: Value(path.basename(localUrl)),
      createdOnText: Value(createdOn.toString()),
      localUrl: Value(localUrl),
    ));
    this._reloadPhotos();
  }
}
