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
  List<AssetEntity> _mediaPathEntityList;
  int _initialIndex;

  PreloadViewPager(List<AssetEntity> mediaPathEntityList, index)
      : _mediaPathEntityList = mediaPathEntityList,
        _initialIndex = index {
    developer.log('index: $index', name: 'SG');
  }

  @override
  _PreloadViewPagerState createState() =>
      _PreloadViewPagerState(_mediaPathEntityList, _initialIndex);
}

class _PreloadViewPagerState extends State<PreloadViewPager> {
  List<AssetEntity> _mediaPathList;
  int _index;
  bool isInitialSize = true;
  PreloadPageController _pageController;
  bool _isFullViewMode = false;

  _PreloadViewPagerState(List<AssetEntity> mediaPathList, int index)
      : _mediaPathList = mediaPathList,
        _index = index,
        _pageController = PreloadPageController(initialPage: index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
        backgroundColor: Colors.transparent,
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
  }

  _getPreloadPageView() {
    return PreloadPageView.builder(
      preloadPagesCount: 5,
      //scrollDirection: Axis.vertical,
      itemCount: _mediaPathList.length,
      itemBuilder: (BuildContext context, int position) =>
          _getImageView(position),
      pageSnapping: true,
      reverse: false,
      //TODO check scroll
      //physics: NeverScrollableScrollPhysics(),
      controller: _pageController,
      onPageChanged: (int position) {
        print('page changed. current: $position');
      },
    );
  }

  Widget _getImageView(int position) {
    final int index = position;
    developer.log('position: $position', name: 'SG');
    // return PhotoView(
    //   imageProvider:
    return FutureBuilder<File?>(
      future: _mediaPathList[index].file,
      builder: (BuildContext context, snapshot) {
        if (snapshot.hasData == false || snapshot.hasError) {
          //TODO handle error
          return Image.asset('images/no_thumb.png');
        } else {
          return GestureDetector(
            //TODO change action
            onTap: (){
              setState(() {
                _isFullViewMode = !_isFullViewMode;
              });
              if (_isFullViewMode) {
                SystemChrome.setEnabledSystemUIOverlays ([]);
              } else {
                SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
              }

              //_pageController.jumpToPage(index + 1);
              },

              child: ClipRect(
                child: PhotoView(
                  imageProvider: FileImage(
                    snapshot.data as File,
                  ),
                  backgroundDecoration: BoxDecoration(color: Colors.white,),
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