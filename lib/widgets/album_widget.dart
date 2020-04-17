import 'dart:io';

import 'package:app/models/db.dart';
import 'package:app/models/gallery_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AlbumWidget extends StatefulWidget {
  final AlbumWithPhotos _album;

  AlbumWidget(this._album);

  @override
  State<StatefulWidget> createState() => _AlbumWidgetState(this._album);
}

class _AlbumWidgetState extends State<AlbumWidget> {
  final AlbumWithPhotos _album;
  bool _photosReady = false;
  List<Photo> _photos;

  _AlbumWidgetState(this._album);

  @override
  Widget build(BuildContext context) {
    if (_photosReady) {
      return Column(
        children: _buildRows(_photos),
      );
    } else {
      return Column(
        children: _buildEmpty(),
      );
    }
  }

  List<Widget> _buildEmpty() {
    int n = _album.album.photosCount;
    List<Widget> rows = List<Widget>();
    rows.add(_buildTitle());

    for (int i = 0; i < n; i += 3) {
      Row row = Row(
        children: <Widget>[
          _buildRowChild(null),
          _buildRowChild(null),
          _buildRowChild(null),
        ],
      );

      rows.add(row);
    }
    return rows;
  }

  List<Widget> _buildRows(List<Photo> photos) {
    int n = photos.length;
    List<Widget> rows = List<Widget>();
    rows.add(_buildTitle());

    for (int i = 0; i < n; i += 3) {
      Row row = Row(
        children: <Widget>[
          _buildRowChild(i < n ? photos[i] : null),
          _buildRowChild(i + 1 < n ? photos[i + 1] : null),
          _buildRowChild(i + 2 < n ? photos[i + 2] : null),
        ],
      );

      rows.add(row);
    }
    return rows;
  }

  Widget _buildRowChild(Photo photo) {
    if (photo != null && !File(photo.localUrl).existsSync()) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Container(
              color: Theme.of(context).errorColor,
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: EdgeInsets.all(1),
          child: photo != null
              ? Image.file(
                  File(photo.localUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 150,
                )
              : Container(),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(_album.album.date.toString());
  }

  void _photosResetCallback() {
    setState(() {
      this._photosReady = false;
    });

    this._album.photosOrdered.then((value) {
      setState(() {
        this._photosReady = true;
        this._photos = value;
      });
    });
  }

  @override
  void dispose() {
    this._album.removePhotoResetCallback(this._photosResetCallback);
    super.dispose();
  }

  @override
  void initState() {
    this._album.photosOrdered.then((value) {
      setState(() {
        this._photosReady = true;
        this._photos = value;
      });
    });
    this._album.addPhotoResetCallback(this._photosResetCallback);
    super.initState();
  }
}
