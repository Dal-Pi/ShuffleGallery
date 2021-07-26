import 'dart:async';
import 'dart:ui';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:shuffle_gallery/MediaListView.dart';
import 'package:shuffle_gallery/Util.dart';

//test
import 'package:permission_handler/permission_handler.dart';

// void main() {
//   runApp(AlbumListView());
// }

const String kNoThumbnailMediaId = '-100';

enum AlbumViewState {
  Loading, NotGranted, Granted,
}

class AlbumListView extends StatefulWidget {
  @override
  _AlbumListViewState createState() => _AlbumListViewState();
}

class _AlbumListViewState extends State<AlbumListView> {
  List<AssetPathEntity> _albumPathList = [];
  List<AssetEntity> _firstMediaPathList = [];
  int _currentPage = 0;
  int _lastPage = 0;
  List<Widget> _albumThumbnailList = [];
  AlbumViewState _albumViewState = AlbumViewState.Loading;
  int _thumbnailWidth = 1000;


  //TODO remove
  //test
  // AssetPathEntity _albumPath = AssetPathEntity();
  // List<AssetEntity> _mediaPathList = [];
  // List<Widget> _mediaList = [];
  int _rowCount = 3;
  int _viewHeightRatio = 2;
  double _prevMaxScrollExtent = 0.0;
  double _nextLoadingScrollTarget = 0.0;

  @override
  void initState() {
    super.initState();
    developer.log('initState(), window.physicalSize: ${window.physicalSize}', name: 'SG');
    _thumbnailWidth = window.physicalSize.width ~/ _rowCount.toDouble();
    developer.log('initState(), _thumbnailWidth: $_thumbnailWidth', name: 'SG');
    _albumViewState = AlbumViewState.Loading;
    initAsync();
  }

  Future<void> initAsync() async {
    bool allowedPermission = await promptPermissionSetting();
    developer.log('_allowedPermission: $allowedPermission', name:'SG_Log');
    if (allowedPermission) {
      List<AssetPathEntity> albumPaths = await PhotoManager.getAssetPathList(type: RequestType.image);
      print(albumPaths);

      //log
      for (var assetPathEntity in albumPaths) {
        developer.log('name: ${assetPathEntity.name}, count: ${assetPathEntity.assetCount}', name:'SG_Log');
      }

      if (albumPaths.length > 0) {
        _albumPathList = [albumPaths[0], ...shuffle(albumPaths.sublist(1))];
        _albumPathList[0].name = 'All';
        for (var albumPath in _albumPathList) {
          List<AssetEntity> mediaPathList = await albumPath.getAssetListRange(start: 0, end: 1);
          if (mediaPathList.length > 0) {
            _firstMediaPathList.add(mediaPathList[0]);
          } else {
            //TODO check no_thumbnail
            developer.log('_handleScrollEvent(), there is no first media', name:'SG_Log');
            _firstMediaPathList.add(AssetEntity(id: kNoThumbnailMediaId, typeInt: 1, height: _thumbnailWidth, width: _thumbnailWidth));
          }
        }
      } else {
        developer.log('_handleScrollEvent(), updated _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG_Log');
      }

      //test
      //_albumPath = _albumPathList[0];
      // _mediaPathList = await _albumPathList[0]
      //     .getAssetListPaged(_currentPage, kItemCountByPage);
      // print(_mediaPathList);

      //test
      // developer.log('initAsync(), _albumPath.assetCount: ${_albumPath.assetCount}', name:'SG_Log');
      // _mediaPathList = shuffle(
      //     await _albumPath
      //         .getAssetListRange(start: 0, end: _albumPath.assetCount)
      // );
      _fetchMoreAlbumThumbnail();
    }
    setState(() {
      _albumViewState = allowedPermission
          ? AlbumViewState.Granted
          : AlbumViewState.NotGranted;
    });
  }

  _handleScrollEvent(ScrollNotification scroll) {
    double currentPos = scroll.metrics.pixels;
    double maxPos = scroll.metrics.maxScrollExtent;
    if (_prevMaxScrollExtent < maxPos) {
      _nextLoadingScrollTarget = _prevMaxScrollExtent + ((maxPos - _prevMaxScrollExtent) * 0.1);
      developer.log('_handleScrollEvent(), updated _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG_Log');
    }
    //developer.log('_handleScrollEvent(), _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG_Log');
    if (_nextLoadingScrollTarget < currentPos) {
      _nextLoadingScrollTarget = maxPos;
      developer.log('_handleScrollEvent(), updated temporary _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG_Log');
      if (_currentPage != _lastPage) {
        _fetchMoreAlbumThumbnail();
      } else {
        developer.log('_handleScrollEvent(), current page is same with last page, _currentPage: $_currentPage, _lastPage: $_lastPage', name:'SG_Log');
      }
    }
    _prevMaxScrollExtent = maxPos;
  }

  //test
  _fetchMoreAlbumThumbnail() async {
    developer.log('_fetchMoreAlbumThumbnail(), _lastPage: $_lastPage, _currentPage $_currentPage', name:'SG_Log');
    _lastPage = _currentPage;
    if (await promptPermissionSetting()) {
      final int loadingItemCount = _rowCount * _rowCount * _viewHeightRatio;
      developer.log('_fetchMoreAlbumThumbnail(), loadingItemCount: $loadingItemCount', name:'SG_Log');

      int begin = _albumThumbnailList.length;
      int end = begin;
      if (begin + loadingItemCount > _albumPathList.length) {
        end = _albumPathList.length;
        developer.log('_fetchMoreAlbumThumbnail(), end is _albumPathList.length: $end', name:'SG_Log');
      } else {
        end += loadingItemCount;
        developer.log('_fetchMoreAlbumThumbnail(), end is added loadingItemCount: $end', name:'SG_Log');
      }

      List<Widget> temp = [];
      for (int i = begin; i < end; ++i) {
        temp.add(
            FutureBuilder<dynamic>(
              //TODO thumb size
                future: _firstMediaPathList[i].thumbDataWithSize(_thumbnailWidth, _thumbnailWidth),
                builder: (BuildContext context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Image.memory(
                      snapshot.data,
                      fit: BoxFit.cover,
                    );
                  }
                  else {
                    //TODO this case
                    return Container(color: Colors.grey);
                  }
                }
            )
        );
      }
      setState(() {
        if (temp.length > 0) {
          developer.log('_fetchMoreAlbumThumbnail(), loaded temp.length: ${temp.length}', name:'SG_Log');
          _albumThumbnailList.addAll(temp);
          developer.log('_fetchMoreAlbumThumbnail(), _albumThumbnailList.length: ${_albumThumbnailList.length}', name:'SG_Log');
          _currentPage++;
        } else {
          developer.log('_fetchMoreAlbumThumbnail(), no more load item', name:'SG_Log');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      //systemNavigationBarColor: Colors.white70, // navigation bar color
      statusBarColor: Colors.white12, // status bar color
    ));
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: Scaffold(
        body: _getBody(),
      ),
    );
  }

  Widget _getBody() {
    if (_albumViewState == AlbumViewState.Loading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(flex: 1, child:Container(),),
          Expanded(flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30.0),
                  child: Image.asset('assets/icon_full.png'),
                ),
                //Text('Shuffling Albums...'),
              ],
            ),
          ),
          Expanded(flex: 1, child:Container(),),
        ],
      );
    } else if (_albumViewState == AlbumViewState.Granted) {
      return _getAlbumView();
    } else { // _albumViewState == AlbumViewState.NotGranted
      return _getPermissionRequestView();
    }
  }

  _getPermissionRequestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 50.0),
          Text('Shuffle Gallery requires storage permissions.'),
          TextButton(
              onPressed: () {
                initAsync();
                setState(() {
                  _albumViewState = AlbumViewState.Loading;
                });
              },
              child: Text('Check Permission Again'),
          ),
          Text('Or, edit the permissions in the app settings'),
          Text('and select \'Check Permission Again\''),
          TextButton(
            onPressed: () {
              openAppSettings();
            },
            child: Text('Open App Settings'),
          ),
        ],
      )
    );
  }

  _getAlbumView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double viewWidth = constraints.maxWidth;
        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scroll) {
            _handleScrollEvent(scroll);
            return true;
          },
          child: CustomScrollView(
            slivers: <Widget>[
              _getSliverActionBar(),
              _getAlbumGridView(viewWidth),
            ],
          ),
        );
      },
    );
  }

  _getSliverActionBar() {
    return SliverAppBar(
      title: Text('Shuffle Gallery'),
      floating: true,
    );
  }

  _getAlbumGridView(double viewWidth) {
    double gridWidth = (viewWidth - 20) / _rowCount;
    double gridHeight = gridWidth + 33;
    double ratio = gridWidth / gridHeight;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _rowCount,
        mainAxisSpacing: 1.0,
        crossAxisSpacing: 1.0,
        childAspectRatio: ratio,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            MediaListView(
                                _albumPathList[index],
                                _albumThumbnailList[index]
                            )
                    )),
                child: Column(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: Container(
                        color: Colors.grey[300],
                        height: gridWidth,
                        width: gridWidth,
                        child: _albumThumbnailList[index],
                      ),
                    ),
                    Container(
                      alignment: Alignment.topLeft,
                      padding: EdgeInsets.only(left: 2.0),
                      child: Text(
                        _albumPathList[index].name,
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          height: 1.2,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.topLeft,
                      padding: EdgeInsets.only(left: 2.0),
                      child: Text(
                        _albumPathList[index].assetCount.toString(),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          height: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          );
        },
        childCount: _albumThumbnailList.length,
      ),
    );
  }
}
