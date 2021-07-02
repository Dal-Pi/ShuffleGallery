import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:shuffle_gallery/PreloadViewPager.dart';
import 'package:shuffle_gallery/Util.dart';

enum AlbumPageType { GRID, LIST }

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
  List<AssetEntity> _mediaPathList = [];
  List<Widget> _mediaList = [];
  int _currentPage = 0;
  int _lastPage = 0;
  int _rowCount = 4;
  int _viewHeightRatio = 10;
  double _prevMaxScrollExtent = 0.0;
  double _nextLoadingScrollTarget = 0.0;

  _MediaListViewState(AssetPathEntity albumPath) : _albumPath = albumPath;

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();
  }

  Future<void> initAsync() async {
    if (await promptPermissionSetting()) {
      developer.log(
          'initAsync(), _albumPath.assetCount: ${_albumPath.assetCount}',
          name: 'SG');
      _mediaPathList = shuffle(await _albumPath.getAssetListRange(
          start: 0, end: _albumPath.assetCount));
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
      int begin = _mediaList.length;
      int end = begin;
      if (begin + loadingItemCount > _albumPath.assetCount) {
        end = _albumPath.assetCount;
        developer.log('_fetchMoreMediaThumbnail(), end is assetCount: $end', name: 'SG');
      } else {
        end += loadingItemCount;
        developer.log('_fetchMoreMediaThumbnail(), end is added loadingItemCount: $end',
            name: 'SG');
      }

      List<Widget> temp = [];
      for (int i = begin; i < end; ++i) {
        temp.add(FutureBuilder<dynamic>(
            //TODO thumb size
            future: _mediaPathList[i].thumbDataWithSize(200, 200),
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
          _mediaList.addAll(temp);
          developer.log('_fetchMoreMediaThumbnail(), _mediaList: ${_mediaList.length}',
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
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: Scaffold(
        body: _loading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : _getAlbumView(),
      ),
    );
  }

  _getAlbumView() {
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
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                  PreloadViewPager(_mediaPathList, index),
                ));
            },
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
