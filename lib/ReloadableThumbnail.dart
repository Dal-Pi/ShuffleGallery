import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class ReloadableThumbnailController {
  List<_ReloadableThumbnailState> _reloadableThumbnailStateList = [];

  void _setState(_ReloadableThumbnailState state) {
    _reloadableThumbnailStateList.add(state);
  }

  void setThumbnailWidth(int newWidth) {
    for (var state in _reloadableThumbnailStateList) {
      state._loadThumbnailByWidth(newWidth);
    }
  }
}

class ReloadableThumbnail extends StatefulWidget {
  ReloadableThumbnail({
    Key? key,
    required this.mediaPathEntity,
    required this.initialWidth,
    this.controller,
  });
  final AssetEntity mediaPathEntity;
  final int initialWidth;
  final ReloadableThumbnailController? controller;

  @override
  _ReloadableThumbnailState createState() => _ReloadableThumbnailState();
}

class _ReloadableThumbnailState extends State<ReloadableThumbnail> {
  static const int kDefaultThumbWidth = 200;
  Widget _currentThumbnail = Container();
  int _currentWidth = kDefaultThumbWidth;
  ReloadableThumbnailController? _controller;
  bool isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.initialWidth;
    _controller = widget.controller;
    _controller?._setState(this);

    _loadThumbnail();
  }

  @override
  Widget build(BuildContext context) {
    developer.log('_ReloadableThumbnailState(${widget.mediaPathEntity.title}) build called _currentWidth = $_currentWidth', name: 'SG');
    return _currentThumbnail;
  }

  @override
  void dispose() {
    super.dispose();
    developer.log('_loadThumbnailByWidth dispose called title = ${widget.mediaPathEntity.title}', name: 'SG');
    //_controller = null;
    isDisposed = true;
  }

  _loadThumbnailByWidth(int newWidth) {
    developer.log('_loadThumbnailByWidth called newWidth = $newWidth', name: 'SG');
    _currentWidth = newWidth;
    _loadThumbnail();
    //TODO task
    // if (_currentWidth < newWidth) {
    //   _currentWidth = newWidth;
    //   developer.log('_loadThumbnailByWidth _currentWidth changed to $_currentWidth', name: 'SG');
    //   _loadThumbnail();
    // }
  }

  Future<void> _loadThumbnail() async {
    var media = widget.mediaPathEntity;
    var prevThumbnail = _currentThumbnail;
    var thumbnail = FutureBuilder<dynamic>(
        future: media.thumbDataWithSize(
            _currentWidth,
            (_currentWidth.toDouble() * _getRatioByOrientation()).toInt()),
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            developer.log('_loadThumbnail ${widget.mediaPathEntity.title} _currentWidth = $_currentWidth', name: 'SG');
            return Image.memory(
              snapshot.data,
              fit: BoxFit.none,
            );
          } else {
            return prevThumbnail;
          }
        });
    if (!isDisposed) {
      setState(() {
        _currentThumbnail = thumbnail;
      });
    }
    else {
      developer.log('_loadThumbnail isDisposed case not set state title = ${widget.mediaPathEntity.title}', name: 'SG');
    }
  }

  double _getRatioByOrientation() {
    var media = widget.mediaPathEntity;
    if ((media.orientation == 90)
        || (media.orientation == 270)) {
      return media.height / media.width;
    } else {
      return media.width / media.height;
    }
  }
}