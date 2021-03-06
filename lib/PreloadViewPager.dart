import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:share_plus/share_plus.dart';

class PreloadViewPager extends StatefulWidget {
  final List<AssetEntity> _mediaPathEntityList;
  final int _initialIndex;

  final Widget _thumbnail;
  final bool _isFullscreenStart;

  PreloadViewPager(List<AssetEntity> mediaPathEntityList, int index
      , Widget thumbnail, bool fullscreen)
      : _mediaPathEntityList = mediaPathEntityList,
        _initialIndex = index,
        _thumbnail = thumbnail,
        _isFullscreenStart = fullscreen {
    developer.log('index: $index', name: 'SG');
  }

  @override
  _PreloadViewPagerState createState() =>
      _PreloadViewPagerState(
          _mediaPathEntityList,
          _initialIndex,
          _thumbnail,
          _isFullscreenStart
      );
}

class _PreloadViewPagerState extends State<PreloadViewPager> {
  final List<AssetEntity> _mediaPathList;
  //int _index;
  bool isInitialSize = true;
  PreloadPageController _pageController;
  bool _isFullViewMode = false;
  //PhotoViewController _viewController = PhotoViewController();
  //PhotoViewScaleStateController _viewScaleStateController =
  //  PhotoViewScaleStateController();
  PhotoViewScaleState _currentScaleState = PhotoViewScaleState.initial;
  int _currentIndex;

  final Widget _thumbnail;

  _PreloadViewPagerState(List<AssetEntity> mediaPathList, int index, Widget thumbnail, bool fullscreen)
      : _mediaPathList = mediaPathList,
        //_index = index,
        _thumbnail = thumbnail,
        _pageController = PreloadPageController(initialPage: index),
        _currentIndex = index,
        _isFullViewMode = fullscreen;

  @override
  void initState() {
    super.initState();
    _setSystemOverlay();
    //_viewController = PhotoViewController()
    //  ..outputStateStream.listen(_viewScaleListener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _isFullViewMode
        ? null
        : AppBar(
        leading: IconButton(
          onPressed: () {
            developer.log('onPressed', name: 'SG');
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_ios),
          tooltip: 'Back',
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.fullscreen_rounded),
            onPressed: () => _changeFullScreenMode(true),
            tooltip: 'Fullscreen',
          ),
          IconButton(
            icon: Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => _shareItem(),
          ),
        ],
        elevation: 1.0,
      ),
      body: Center(
          child: _getPreloadPageView()
        //child: _getImageView(_index),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    //_viewController.dispose();
  }

  void _changeFullScreenMode(bool enabled) {
    if (_isFullViewMode != enabled) {
      setState(() {
        _isFullViewMode = !_isFullViewMode;
      });
      _setSystemOverlay();
    }
  }

  void _setSystemOverlay() {
    if (_isFullViewMode) {
      SystemChrome.setEnabledSystemUIOverlays ([]); //status and navi bar
      //SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]); //status and only
    } else {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    }
  }

  void _shareItem() async {
    await Share.shareFiles(['${(await _mediaPathList[_currentIndex].originFile)!.path}']);
  }

  ScrollPhysics _getDefaultScrollPhysics() {
    if (_currentScaleState == PhotoViewScaleState.initial
        || _currentScaleState == PhotoViewScaleState.zoomedOut) {
      //TODO check ios
      //return BouncingScrollPhysics();
      return ClampingScrollPhysics();
    } else {
      return NeverScrollableScrollPhysics();
    }
  }

  // void _viewScaleListener(PhotoViewControllerValue value) {
  //   developer.log('value: $value', name:'SG_Log');
  // }

  void _viewScaleListener(PhotoViewScaleState value) {
    developer.log('value: $value', name:'SG_Log');
    setState(() {
      _currentScaleState = value;
    });
  }

  _getPreloadPageView() {
    return PreloadPageView.builder(
      preloadPagesCount: 5,
      itemCount: _mediaPathList.length,
      itemBuilder: (BuildContext context, int position) =>
          _getImageView(position),
      pageSnapping: true,
      reverse: false,
      //TODO check scroll
      physics: _getDefaultScrollPhysics(),
      controller: _pageController,
      onPageChanged: (int position) {
        print('page changed. current: $position');
        _currentIndex = position;
      },
    );
  }

  _getBgColorByTheme() {
    final ThemeData theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return Colors.white;
    } else {
      return Colors.black;
    }
  }

  Widget _getImageView(int position) {
    final int index = position;
    //developer.log('position: $position', name: 'SG');
    // return PhotoView(
    //   imageProvider:
    return FutureBuilder<File?>(
      future: _mediaPathList[index].file,
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData == false || snapshot.hasError) {
          //TODO handle error
          return Container(color: Colors.grey);
        } else {
          return GestureDetector(
            //TODO change action
            onTap: () =>
              _changeFullScreenMode(!_isFullViewMode),
            child: ClipRect(
              child: PhotoView(
                imageProvider: FileImage(
                  snapshot.data as File,
                ),
                loadingBuilder: (context, event) => FittedBox(
                  child: _thumbnail,
                  fit: BoxFit.contain,
                ),
                backgroundDecoration: BoxDecoration(color: _getBgColorByTheme(),),
              //controller: _viewController,
              scaleStateChangedCallback: _viewScaleListener,
              //controller: ,
              //controller: PhotoViewController(),
            ),
            // heroAttributes: PhotoViewHeroAttributes(
            //   tag: _mediaPathList[index].id.toString(),
            //   transitionOnUserGestures: true,
            // ),
              ),);
        }
      },
    );
  }
}