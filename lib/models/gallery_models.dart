import 'package:flutter/cupertino.dart';

class Photo {
  final Uri _uri;
  final DateTime _createdOn;
  bool _isLocal;

  Photo({@required Uri uri, @required DateTime createdOn, bool isLocal = true})
      : _uri = uri,
        _createdOn = createdOn,
        _isLocal = isLocal;

  DateTime get createdOn => _createdOn;
}

class Album {
  final DateTime _date;
  final Set<Photo> _photos = Set<Photo>();
  List<Photo> _sortedByTime = List<Photo>();

  Album({@required DateTime date}) : _date = date;

  void addPhotos(Iterable<Photo> photos) {
    this._photos.addAll(photos);
    this._reloadSortedList();
  }

  void addPhoto(Photo photo) {
    if (this._photos.add(photo)) {
      this._reloadSortedList();
    }
  }

  void _reloadSortedList(){
    _sortedByTime = this._photos.toList();
    _sortedByTime.sort((a, b) => a.createdOn.compareTo(b.createdOn));
  }

  void removePhotos(Iterable<Photo> photos) {
    this._photos.removeAll(photos);
    this._reloadSortedList();
  }

  void removePhoto(Photo photo) {
    if (this._photos.remove(photo)) {
      this._reloadSortedList();
    }
  }

  List<Photo> get sortedByTime => this._sortedByTime;
}
