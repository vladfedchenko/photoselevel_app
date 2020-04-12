import 'dart:io';

import 'package:moor/moor.dart';
import 'package:moor_ffi/moor_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'gallery_models.dart';

part 'db.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db_dev.sqlite'));
    return VmDatabase(file);
  });
}

@UseMoor(tables: [Photos, Albums])
class PhotoselevenDB extends _$PhotoselevenDB {
  static final PhotoselevenDB _singleton = PhotoselevenDB._internal();

  factory PhotoselevenDB() {
    return _singleton;
  }

  PhotoselevenDB._internal() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Album>> get allAlbums => select(albums).get();

  Future<List<Album>> get allAlbumsDescending => (select(albums)
        ..orderBy(
            [(a) => OrderingTerm(expression: a.date, mode: OrderingMode.desc)]))
      .get();

  Future<Album> getAlbumOnDate(DateTime date) {
    return (select(albums)..where((a) => a.date.equals(date))).getSingle();
  }

  Future<List<Photo>> getAlbumPhotos(Album album) {
    return (select(photos)..where((p) => p.album.equals(album.id))).get();
  }

  Future<List<Photo>> getAlbumPhotosOrdered(Album album) {
    return (select(photos)
          ..where((p) => p.album.equals(album.id))
          ..orderBy([
            (p) => OrderingTerm(
                expression: p.createdOnText, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<Album> insertAlbum(AlbumsCompanion album) async {
    int id = await into(albums).insert(album);
    return (select(albums)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<Photo> insertPhoto(PhotosCompanion photosCompanion) async {
    int photoID = await transaction(() async {
      int id = await into(photos).insert(photosCompanion);

      var album = await (select(albums)
            ..where((a) => a.id.equals(photosCompanion.album.value)))
          .getSingle();

      await (update(albums)..where((a) => a.id.equals(album.id))).write(
        AlbumsCompanion(
          id: Value(album.id),
          date: Value(album.date),
          photosCount: Value(album.photosCount + 1),
        ),
      );

      return id;
    });

    return (select(photos)..where((a) => a.id.equals(photoID))).getSingle();
  }
}
