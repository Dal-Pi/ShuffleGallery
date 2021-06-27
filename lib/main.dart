import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';

enum AlbumPageType { GRID, LIST }

void main() {
  runApp(MyApp());
}

List<T> shuffle<T>(List<T> items) {
  var random = new Random();

  // Go through all elements.
  for (var i = items.length - 1; i > 0; i--) {
    // Pick a pseudorandom number according to the list length
    var n = random.nextInt(i + 1);

    var temp = items[i];
    items[i] = items[n];
    items[n] = temp;
  }

  return items;
}

Future<bool> promptPermissionSetting() async {
  if (Platform.isIOS &&
          await Permission.storage.request().isGranted &&
          await Permission.photos.request().isGranted ||
      Platform.isAndroid && await Permission.storage.request().isGranted) {
    return true;
  }
  return false;
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<AssetPathEntity> _albumPathList = [];
  int _currentPage = 0;
  int _lastPage = 0;
  List<Widget> _albumList = [];
  bool _loading = false;

  //test
  AssetPathEntity _albumPath = AssetPathEntity();
  List<AssetEntity> _mediaPathList = [];
  List<Widget> _mediaList = [];
  int _rowCount = 3;
  int _viewHeightRatio = 10;
  double _prevMaxScrollExtent = 0.0;
  double _nextLoadingScrollTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();
  }

  Future<void> initAsync() async {
    if (await promptPermissionSetting()) {
      List<AssetPathEntity> albumPaths = await PhotoManager.getAssetPathList();
      print(albumPaths);
      _albumPathList = [albumPaths[0], ...shuffle(albumPaths.sublist(1))];
      //test
      _albumPath = _albumPathList[0];
      // _mediaPathList = await _albumPathList[0]
      //     .getAssetListPaged(_currentPage, kItemCountByPage);
      // print(_mediaPathList);

      //test
      _fetchNewMedia();
      setState(() {
        //TODO index check
        _loading = false;
      });
    }
    setState(() {
      _loading = false;
    });
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
      _nextLoadingScrollTarget = _prevMaxScrollExtent + ((maxPos - _prevMaxScrollExtent) * 0.1);
      developer.log('_handleScrollEvent(), updated _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG');
    }
    //developer.log('_handleScrollEvent(), _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG');
    if (_nextLoadingScrollTarget < currentPos) {
      _nextLoadingScrollTarget = maxPos;
      developer.log('_handleScrollEvent(), updated temporary _nextLoadingScrollTarget: $_nextLoadingScrollTarget', name:'SG');
      if (_currentPage != _lastPage) {
        _fetchNewMedia();
      } else {
        developer.log('_handleScrollEvent(), current page is same with last page, _currentPage: $_currentPage, _lastPage: $_lastPage', name:'SG');
      }
    }
    _prevMaxScrollExtent = maxPos;

    ///
    // if (((currentPos / maxPos) > 0.5)) {
    //   if (_currentPage != _lastPage) {
    //     if (_nextLoadingScrollTarget < currentPos) {
    //       _fetchNewMedia();
    //     } else {
    //       developer.log('_handleScrollEvent(), scroll not updated yet, _prevMaxScrollExtent: $_prevMaxScrollExtent, maxPos: $maxPos', name:'SG');
    //     }
    //   } else {
    //     developer.log('_handleScrollEvent(), current page is same with last page, _currentPage: $_currentPage, _lastPage: $_lastPage', name:'SG');
    //   }
    // }

  }

  //test
  _fetchNewMedia() async {
    developer.log('_fetchNewMedia(), _lastPage: $_lastPage, _currentPage $_currentPage', name:'SG');
    _lastPage = _currentPage;
    if (await promptPermissionSetting()) {
      final int loadingItemCount = _rowCount * _rowCount * _viewHeightRatio;
      developer.log('_fetchNewMedia(), loadingItemCount: $loadingItemCount', name:'SG');
      _mediaPathList = await _albumPath
          .getAssetListPaged(_currentPage, loadingItemCount);
      //print(_mediaPathList);
      List<Widget> temp = [];
      for (var mediaPath in _mediaPathList) {
        temp.add(
          FutureBuilder<dynamic>(
            //TODO thumb size
            future: mediaPath.thumbDataWithSize(200, 200),
            builder: (BuildContext context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done)
                return Image.memory(
                  snapshot.data,
                  fit: BoxFit.cover,
                );
              else
                //TODO this case
                return Container();
            }
          )
        );
      }
      setState(() {
        if (temp.length > 0) {
          developer.log('_fetchNewMedia(), loaded temp.length: ${temp.length}', name:'SG');
          _mediaList.addAll(temp);
          developer.log('_fetchNewMedia(), _mediaList: ${_mediaList.length}', name:'SG');
          _currentPage++;
        } else {
          developer.log('_fetchNewMedia(), no more load item', name:'SG');
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
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: Scaffold(
        // appBar: AppBar(
        //   title: const Text('Shuffle Gallery'),
        //   brightness: Brightness.light,
        //   elevation: 0.0,
        // ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : _getAlbumView(),
      ),
    );
  }

  _getAlbumView() {
    // return LayoutBuilder(builder: (context, constraints) {
    //   //TODO arrange
    //   double gridWidth = (constraints.maxWidth - 20) / kRowCount;
    //   double gridHeight = gridWidth + 33;
    //   double ratio = gridWidth / gridHeight;
    //   developer.log('LayoutBuilder, gridWidth: $gridWidth, gridHeight: $gridHeight', name: 'SG');
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scroll) {
          _handleScrollEvent(scroll);
          return true;
        },
        child: CustomScrollView(
          slivers: <Widget>[
            _getSliverActionBar(),
            _getAlbumGridView(),
          ],
        ),
      );
    // });
  }

  _getSliverActionBar() {
    return SliverAppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(_albumPath.name),
      floating: true,
    );
  }

  _getAlbumGridView() {
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
            onTap: () {},
            child: Container(
              child: _mediaList[index],
              //child: CircularProgressIndicator(),
            ),
          );
        },
        childCount: _mediaList.length,
      ),
    );
  }
}

/*
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 1.0,
              crossAxisSpacing: 1.0,
            ),
          )

          return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 1.0,
          crossAxisSpacing: 1.0,
        )
      },
      delegate: SliverChildBuilderDelegate((context, index) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => PreloadImagePageView(_media!, index))),
          child: Container(
            //padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
            child: FadeInImage(
              fit: BoxFit.cover,
              placeholder: MemoryImage(kTransparentImage),
              image: ThumbnailProvider(
                mediumId: _media![index].id,
                mediumType: _media![index].mediumType,
                highQuality: true,
              ),
            ),
          ),
        );
      }, childCount: _media?.length),
    );
  }

}

           */
