import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';

import 'package:shuffle_gallery/PreloadViewPager.dart';
import 'package:shuffle_gallery/Util.dart';

const int kMaxRowCount = 8;
const int kGridRowCount = 4;
const int kListRowCount = 1;

enum ShuffleMode {
  Sequential, Random,
}

class MediaListView extends StatefulWidget {
  final AssetPathEntity _assetPathEntity;
  MediaListView(AssetPathEntity assetPathEntity)
      : _assetPathEntity = assetPathEntity;

  @override
  _MediaListViewState createState() => _MediaListViewState(_assetPathEntity);
}

class _MediaListViewState extends State<MediaListView> {

  bool _loading = false;
  final AssetPathEntity _albumPath;
  List<AssetEntity> _sequentialMediaPathList = [];
  List<AssetEntity> _randomMediaPathList = [];
  List<AssetEntity> _targetMediaPathList = [];
  ShuffleMode _shuffleMode = ShuffleMode.Random;
  Map<String, Widget> _preloadedImageMap = {};
  List<Widget> _removed_mediaList = [];
  int _currentPage = 0;
  int _lastPage = 0;
  int _rowCount = kGridRowCount;
  int _viewHeightRatio = 10;
  double _prevMaxScrollExtent = 0.0;
  double _nextLoadingScrollTarget = 0.0;
  int _thumbnailWidth = 1000;
  double _baseViewScale = 1.0;
  double _updatedViewScale = 1.0;

  _MediaListViewState(AssetPathEntity albumPath) : _albumPath = albumPath;

  @override
  void initState() {
    super.initState();
    developer.log('initState(), window.physicalSize: ${window.physicalSize}', name: 'SG');
    _thumbnailWidth = window.physicalSize.width ~/ _rowCount.toDouble();
    developer.log('initState(), _thumbnailWidth: $_thumbnailWidth', name: 'SG');
    _loading = true;
    initAsync();
  }

  Future<void> initAsync() async {
    if (await promptPermissionSetting()) {
      developer.log(
          'initAsync(), _albumPath.assetCount: ${_albumPath.assetCount}',
          name: 'SG');
      _sequentialMediaPathList = await _albumPath.getAssetListRange(
          start: 0, end: _albumPath.assetCount);
      _changeShuffleMode();
      _fetchMoreMediaThumbnail();
      setState(() {
        //TODO index check
        _loading = false;
      });
    }
    setState(() {
      _loading = false;
    });
  }

  _changeShuffleMode() {
    if (_shuffleMode == ShuffleMode.Random) {
      if (_sequentialMediaPathList.length != _randomMediaPathList.length) {
        _randomMediaPathList = List.from(_sequentialMediaPathList);
      }
      _targetMediaPathList = shuffle(_randomMediaPathList);
    } else { // ShuffleMode.Sequential
      _targetMediaPathList = _sequentialMediaPathList;
    }
  }

  _handleScrollEvent(ScrollNotification scroll) {
    //TODO scroll position check logic

    // developer.log('_handleScrollEvent(), '
    //     'pixels: ${scroll.metrics.pixels}, '
    //     'maxScrollExtent: ${scroll.metrics.maxScrollExtent}, '
    //     '_currentPage: $_currentPage, '
    //     '_lastPage: $_lastPage', name:'SG');
    double currentPos = scroll.metrics.pixels;
    double maxPos = scroll.metrics.maxScrollExtent;
    if (_prevMaxScrollExtent < maxPos) {
      _nextLoadingScrollTarget =
          _prevMaxScrollExtent + ((maxPos - _prevMaxScrollExtent) * 0.1);
      developer.log(
          '_handleScrollEvent(), updated _nextLoadingScrollTarget: $_nextLoadingScrollTarget',
          name: 'SG');
    }
    //developer.log('_handleScrollEvent(), _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG');
    if (_nextLoadingScrollTarget < currentPos) {
      _nextLoadingScrollTarget = maxPos;
      developer.log(
          '_handleScrollEvent(), updated temporary _nextLoadingScrollTarget: $_nextLoadingScrollTarget',
          name: 'SG');
      if (_currentPage != _lastPage) {
        _fetchMoreMediaThumbnail();
      } else {
        developer.log(
            '_handleScrollEvent(), current page is same with last page, _currentPage: $_currentPage, _lastPage: $_lastPage',
            name: 'SG');
      }
    }
    _prevMaxScrollExtent = maxPos;

    ///
    // if (((currentPos / maxPos) > 0.5)) {
    //   if (_currentPage != _lastPage) {
    //     if (_nextLoadingScrollTarget < currentPos) {
    //       _fetchMoreMediaThumbnail();
    //     } else {
    //       developer.log('_handleScrollEvent(), scroll not updated yet, _prevMaxScrollExtent: $_prevMaxScrollExtent, maxPos: $maxPos', name:'SG');
    //     }
    //   } else {
    //     developer.log('_handleScrollEvent(), current page is same with last page, _currentPage: $_currentPage, _lastPage: $_lastPage', name:'SG');
    //   }
    // }
  }

  //test
  _fetchMoreMediaThumbnail() async {
    developer.log(
        '_fetchMoreMediaThumbnail(), _lastPage: $_lastPage, _currentPage $_currentPage',
        name: 'SG');
    _lastPage = _currentPage;
    if (await promptPermissionSetting()) {
      final int loadingItemCount = _rowCount * _rowCount * _viewHeightRatio;
      developer.log('_fetchMoreMediaThumbnail(), loadingItemCount: $loadingItemCount',
          name: 'SG');
      int begin = _preloadedImageMap.length;
      int end = begin;
      if (begin + loadingItemCount > _albumPath.assetCount) {
        end = _albumPath.assetCount;
        developer.log('_fetchMoreMediaThumbnail(), end is assetCount: $end', name: 'SG');
      } else {
        end += loadingItemCount;
        developer.log('_fetchMoreMediaThumbnail(), end is added loadingItemCount: $end',
            name: 'SG');
      }

      //List<Widget> temp = [];
      Map<String, Widget> temp = {};
      for (int i = begin; i < end; ++i) {
        temp[_targetMediaPathList[i].id] = (FutureBuilder<dynamic>(
            //TODO thumb size
            future: _targetMediaPathList[i].thumbDataWithSize(_thumbnailWidth, _thumbnailWidth),
            builder: (BuildContext context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done)
                return Image.memory(
                  snapshot.data,
                  fit: BoxFit.cover,
                );
              else
                //TODO this case
                return Container();
            }));
      }
      setState(() {
        if (temp.length > 0) {
          developer.log('_fetchMoreMediaThumbnail(), loaded temp.length: ${temp.length}',
              name: 'SG');
          _preloadedImageMap.addAll(temp);
          developer.log('_fetchMoreMediaThumbnail(), _mediaList: ${_preloadedImageMap.length}',
              name: 'SG');
          _currentPage++;
        } else {
          developer.log('_fetchMoreMediaThumbnail(), no more load item', name: 'SG');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //   systemNavigationBarColor: Colors.blue, // navigation bar color
    //   statusBarColor: Colors.white, // status bar color
    // ));
    return Scaffold(
        body: _loading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : _getAlbumView(),
      );
  }

  _getAlbumView() {
    //developer.log('_getAlbumView called', name: 'SG');
    return GestureDetector(
      //TODO zoomin out
      onScaleStart: (ScaleStartDetails details) {
        _baseViewScale = _updatedViewScale;
        print(_baseViewScale);
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        _updatedViewScale = _baseViewScale * details.scale;
      },
      onScaleEnd: (details) {
        print(_updatedViewScale);
        print(details);
        setState(() {
          double ratio = _updatedViewScale / _baseViewScale;
          print(ratio);
          if (details.pointerCount == 1) {
            if (ratio > 1.2) {
              _rowCount = _rowCount > 1 ? _rowCount - 1 : _rowCount;
            } else if (ratio < 0.8) {
              _rowCount = _rowCount < kMaxRowCount ? _rowCount + 1 : _rowCount;
            }
          }
        });
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scroll) {
          _handleScrollEvent(scroll);
          return true;
        },
        child: CustomScrollView(
          slivers: <Widget>[
            _getSliverActionBar(),
            _getAlbumViewByRowCount(),
          ],
        ),
      ),
    );
  }

  _getSliverActionBar() {
    return SliverAppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(_albumPath.name),
      floating: true,
      actions: <Widget>[
        IconButton(
            icon: _getShuffleIcon(), onPressed: () => _onShuffleModeChanged()),
        IconButton(
            icon: _getAlbumModeIcon(), onPressed: () => _onAlbumModeChange()),
      ],
    );
  }

  _getAlbumModeIcon() {
    if (_rowCount == kListRowCount) {
      return Icon(Icons.view_comfy);
    } else {
      return Icon(Icons.line_weight);
    }
  }

  _onAlbumModeChange() {
    setState(() {
      if (_rowCount == kListRowCount) {
        _rowCount = kGridRowCount;
      } else {
        _rowCount = kListRowCount;
      }
    });
  }

  _getShuffleIcon() {
    if (_shuffleMode == ShuffleMode.Random) {
      return Icon(Icons.sort);
    } else {
      return Icon(Icons.shuffle);
    }
  }

  _onShuffleModeChanged() {
    //developer.log('_onShuffleModeChanged', name: 'SG');
    setState(() {
      if (_shuffleMode == ShuffleMode.Random) {
        _shuffleMode = ShuffleMode.Sequential;
      } else {
        _shuffleMode = ShuffleMode.Random;
      }
      _changeShuffleMode();
    });
  }

  _getAlbumViewByRowCount() {
    if (_rowCount == 1) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    PreloadViewPager(_targetMediaPathList, index),
              ));
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
              child: Card(
                color: Colors.grey[300],
                elevation: 4.0,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: AspectRatio(
                  aspectRatio: _targetMediaPathList[index].width / _targetMediaPathList[index].height,
                  child: _getImageView(index),//_mediaList[index],
                ),
              ),
            ),
          );
        }, childCount: _preloadedImageMap.length),
      );
    } else {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _rowCount,
          mainAxisSpacing: 1.0,
          crossAxisSpacing: 1.0,
          //childAspectRatio: 0.66,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      PreloadViewPager(_targetMediaPathList, index),
                ));
              },
              child: Container(
                //TODO use hero
                child: Hero(
                  tag: _targetMediaPathList[index].id.toString(),
                  child : _preloadedImageMap[_targetMediaPathList[index].id] ?? Container(),
                ),
              ),
            );
          },
          childCount: _preloadedImageMap.length,
        ),
      );
    }
  }

  //TODO integration with PreloadViewPager's _getImageView
  Widget _getImageView(int position) {
    final int index = position;
    developer.log('position: $position', name: 'SG');
    return FutureBuilder<File?>(
      future: _targetMediaPathList[index].file,
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData == false || snapshot.hasError) {
          //TODO handle error
          return Image.asset('images/no_thumb.png');
        } else {
          return Image.file(snapshot.data as File,);
        }
      },
    );
  }
}
