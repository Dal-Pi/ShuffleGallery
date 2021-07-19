import 'dart:async';
import 'dart:math';
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

const String kGifStr = 'gif';

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
  Map<String, int> _preloadedImageWidthMap = {};
  int _currentPage = 0;
  int _lastPage = 0;
  //TODO rowCount setter
  int _rowCount = kGridRowCount;
  int _viewHeightRatio = 10;
  double _prevMaxScrollExtent = 0.0;
  double _nextLoadingScrollTarget = 0.0;
  int _thumbnailWidthByRow = 200;
  double _deviceWidthInLP = 800;
  double _baseViewScale = 1.0;
  double _updatedViewScale = 1.0;

  _MediaListViewState(AssetPathEntity albumPath) : _albumPath = albumPath;

  @override
  void initState() {
    super.initState();
    _renewalThumbWidth();

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
      setState(() {
        //TODO index check
        _loading = false;
      });
      _fetchMoreMediaThumbnail();
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //   systemNavigationBarColor: Colors.blue, // navigation bar color
    //   statusBarColor: Colors.white, // status bar color
    // ));
    developer.log('** build cache size = ${_preloadedImageMap.length}', name: 'SG');
    _deviceWidthInLP = MediaQuery.of(context).size.width;
    developer.log('** build _deviceWidthInLP $_deviceWidthInLP', name: 'SG');
    _renewalThumbWidth();

    return Scaffold(
      body: _loading
          ? Center(
        child: CircularProgressIndicator(),
      )
          : _getAlbumView(),
    );
  }

  void _renewalThumbWidth() {
    _thumbnailWidthByRow = _deviceWidthInLP ~/ _rowCount;
    _thumbnailWidthByRow *= 2;
    developer.log('initState(), _renewalThumbWidth _thumbnailWidthByRow: $_thumbnailWidthByRow', name: 'SG');
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

  //TODO for debug
  Widget _getErrorView() {
    return Container(
      color: Colors.red,
    );
  }

  Widget _getEmptyView() {
    return Container(
      color: Colors.grey[300],
    );
  }

  bool _needToReloadThumbnail(String id) {
    var currentWidth = _preloadedImageWidthMap[id] ?? _thumbnailWidthByRow;
    //developer.log('_needToReloadThumbnail currentWidth = $currentWidth , _thumbnailWidthByRow = $_thumbnailWidthByRow', name: 'SG');
    return currentWidth < _thumbnailWidthByRow;
  }

  Widget _getThumbnailView(AssetEntity mediaEntity) {
    return FutureBuilder<dynamic>(
      future: mediaEntity.thumbDataWithSize(
        _thumbnailWidthByRow,
        (_thumbnailWidthByRow.toDouble() * _getRatioByOrientation(mediaEntity)).toInt()),
      builder: (BuildContext context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          developer.log('_getThumbnailView FutureBuilder ${mediaEntity.title} with width = $_thumbnailWidthByRow', name: 'SG');
          var thumbnail = Image.memory(
            snapshot.data,
            fit: BoxFit.cover,
          );
          //save to cache
          _preloadedImageMap[mediaEntity.id] = thumbnail;
          return thumbnail;
        } else {
          developer.log('_getThumbnailView FutureBuilder ${mediaEntity.title} empty view', name: 'SG');
          return _getEmptyView();
        }
      }
    );
  }

  //TODO logic can be arranged
  Widget _getThumbnailViewByCache(AssetEntity mediaEntity) {
    if (_preloadedImageMap.containsKey(mediaEntity.id)) {
      if (_needToReloadThumbnail(mediaEntity.id) == false) {
        developer.log('_getThumbnailViewByCache cache case : ${mediaEntity.title}', name: 'SG');
        //TODO debug color
        return _preloadedImageMap[mediaEntity.id] ?? Container(color: Colors.blue);//_getEmptyView();
      } else {
        developer.log('_getThumbnailViewByCache re-load case : ${mediaEntity.title}', name: 'SG');
        _preloadedImageMap[mediaEntity.id] = _getThumbnailView(mediaEntity);
        _preloadedImageWidthMap[mediaEntity.id] = max(_preloadedImageWidthMap[mediaEntity.id] ?? _thumbnailWidthByRow, _thumbnailWidthByRow);
        //TODO debug color
        return _preloadedImageMap[mediaEntity.id] ?? Container(color: Colors.green);//_getEmptyView();
      }
    } else {
      developer.log('_getThumbnailViewByCache load case : ${mediaEntity.title}', name: 'SG');
      _preloadedImageMap[mediaEntity.id] = _getThumbnailView(mediaEntity);
      _preloadedImageWidthMap[mediaEntity.id] = max(_preloadedImageWidthMap[mediaEntity.id] ?? _thumbnailWidthByRow, _thumbnailWidthByRow);
      //TODO debug color
      return _preloadedImageMap[mediaEntity.id] ?? _getErrorView();//_getEmptyView();
    }
  }

  _fetchMoreMediaThumbnail() async {
    developer.log(
        '_fetchMoreMediaThumbnail(), _lastPage: $_lastPage, _currentPage $_currentPage',
        name: 'SG');
    _lastPage = _currentPage;
    if (await promptPermissionSetting()) {
      final int targetLoadingItemCount = _rowCount * _rowCount * _viewHeightRatio;
      developer.log('_fetchMoreMediaThumbnail(), targetLoadingItemCount: $targetLoadingItemCount',
          name: 'SG');
      int begin = _preloadedImageMap.length;
      int end = begin;
      if (begin + targetLoadingItemCount > _albumPath.assetCount) {
        end = _albumPath.assetCount;
        developer.log('_fetchMoreMediaThumbnail(), but end is assetCount: $end', name: 'SG');
      } else {
        end += targetLoadingItemCount;
        developer.log('_fetchMoreMediaThumbnail(), so end is added loadingItemCount: $end',
            name: 'SG');
      }

      //List<Widget> temp = [];
      Map<String, Widget> temp = {};
      Map<String, int> tempWidth = {};
      for (int i = begin; i < end; ++i) {
        temp[_targetMediaPathList[i].id] =
            //_getThumbnailView(_targetMediaPathList[i]);
            _getThumbnailViewByCache(_targetMediaPathList[i]);
        tempWidth[_targetMediaPathList[i].id] = _thumbnailWidthByRow;
      }
      setState(() {
        if (temp.length > 0) {
          developer.log('_fetchMoreMediaThumbnail(), loaded temp.length: ${temp.length}',
              name: 'SG');
          _preloadedImageMap.addAll(temp);
          _preloadedImageWidthMap.addAll(tempWidth);
          developer.log('_fetchMoreMediaThumbnail(), _mediaList.length: ${_preloadedImageMap.length}',
              name: 'SG');
          _currentPage++;
        } else {
          developer.log('_fetchMoreMediaThumbnail(), no more load item', name: 'SG');
        }
      });
    }
  }

  _getAlbumView() {
    //developer.log('_getAlbumView called', name: 'SG');
    return GestureDetector(
      //TODO zoomin out
      onScaleStart: (ScaleStartDetails details) {
        _baseViewScale = _updatedViewScale;
        //print(_baseViewScale);
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        _updatedViewScale = _baseViewScale * details.scale;
      },
      onScaleEnd: (details) {
        //print(_updatedViewScale);
        //print(details);
        //TODO arrange
        setState(() {
          double ratio = _updatedViewScale / _baseViewScale;
          //print(ratio);
          if (details.pointerCount == 1) {
            if (ratio > 1.2) {
              _rowCount = _rowCount > 1 ? _rowCount - 1 : _rowCount;
            } else if (ratio < 0.8) {
              _rowCount = _rowCount < kMaxRowCount ? _rowCount + 1 : _rowCount;
            }
          }
        });
        _renewalThumbWidth();
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

  //TODO integrate _getAspectRatioByOrientation
  double _getRatioByOrientation(AssetEntity mediaEntity) {
    var width = mediaEntity.width;
    var height = mediaEntity.height;
    var orientation = mediaEntity.orientation;

    if ((orientation == 90)
        || (orientation == 270)) {
      return height / width;
    } else {
      return width / height;
    }
  }

  //TODO integrate _getRatioByOrientation
  double _getAspectRatioByOrientation(int index) {
    if ((_targetMediaPathList[index].orientation == 90)
        || (_targetMediaPathList[index].orientation == 270)) {
      return _targetMediaPathList[index].height / _targetMediaPathList[index].width;
    } else {
      return _targetMediaPathList[index].width / _targetMediaPathList[index].height;
    }
  }

  _getImageByExtension(AssetEntity mediaEntity) {
    if (mediaEntity.title!.endsWith(kGifStr)) {
      //developer.log('_getImageByExtension gif case : ${_targetMediaPathList[index].title}', name: 'SG');
      return _getGifImageView(mediaEntity);
    } else {
      //developer.log('_getImageByExtension normal case : ${_targetMediaPathList[index].title}', name: 'SG');
      return _getThumbnailViewByCache(mediaEntity);
    }
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
                color: Colors.white,
                elevation: 4.0,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: AspectRatio(
                  aspectRatio: _getAspectRatioByOrientation(index),
                  child: _getImageByExtension(_targetMediaPathList[index]),
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
                //TODO distinguish filetype (gif etc)..
                //child: _getThumbnailViewByCache(_targetMediaPathList[index]),
                child: _getImageByExtension(_targetMediaPathList[index]),
              ),
            );
          },
          childCount: _preloadedImageMap.length,
        ),
      );
    }
  }

  Widget _getGifImageView(AssetEntity mediaEntity) {
    if (_rowCount == kListRowCount) {
      return _getGifImage(mediaEntity);
    } else { //gridview
      //TODO separate for adding play button
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            child: _getThumbnailViewByCache(mediaEntity),
          ),

          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(5.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: Container(
                  color: Colors.grey.withOpacity(0.5),
                  child: Padding(
                    padding: EdgeInsets.all(3.0),
                    child: Text(
                      kGifStr.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _getGifImage(AssetEntity mediaEntity) {
    return FutureBuilder<File?>(
      future: mediaEntity.file,
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData == false || snapshot.hasError) {
          return _getEmptyView();
        } else {
          return Image.file(
            snapshot.data as File,
          );
        }
      },
    );
  }
}
