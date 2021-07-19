import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';

class PreloadViewPager extends StatefulWidget {
  final List<AssetEntity> _mediaPathEntityList;
  final int _initialIndex;

  final Widget _thumbnail;

  PreloadViewPager(List<AssetEntity> mediaPathEntityList, int index
      , Widget thumbnail)
      : _mediaPathEntityList = mediaPathEntityList,
        _initialIndex = index,
        _thumbnail = thumbnail {
    developer.log('index: $index', name: 'SG');
  }

  @override
  _PreloadViewPagerState createState() =>
      _PreloadViewPagerState(_mediaPathEntityList, _initialIndex, _thumbnail);
}

class _PreloadViewPagerState extends State<PreloadViewPager> {
  final List<AssetEntity> _mediaPathList;
  //int _index;
  bool isInitialSize = true;
  PreloadPageController _pageController;
  bool _isFullViewMode = true;
  //PhotoViewController _viewController = PhotoViewController();
  //PhotoViewScaleStateController _viewScaleStateController =
  //  PhotoViewScaleStateController();
  PhotoViewScaleState _currentScaleState = PhotoViewScaleState.initial;

  final Widget _thumbnail;

  _PreloadViewPagerState(List<AssetEntity> mediaPathList, int index, Widget thumbnail)
      : _mediaPathList = mediaPathList,
        //_index = index,
        _thumbnail = thumbnail,
        _pageController = PreloadPageController(initialPage: index);

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
        ),
        backgroundColor: Colors.white70,
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

  void _setSystemOverlay() {
    if (_isFullViewMode) {
      SystemChrome.setEnabledSystemUIOverlays ([]); //status and navi bar
      //SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]); //status and only
    } else {
      SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    }
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
      },
    );
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
            onTap: (){
              setState(() {
                _isFullViewMode = !_isFullViewMode;
              });
              _setSystemOverlay();
              //_pageController.jumpToPage(index + 1);
              },

              child: ClipRect(
                child: PhotoView(
                  imageProvider: FileImage(
                    snapshot.data as File,
                  ),
                  loadingBuilder: (context, event) => FittedBox(
                    child: _thumbnail,
                    fit: BoxFit.contain,
                  ),
                  backgroundDecoration: BoxDecoration(color: Colors.white,),
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