import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  _PreloadViewPagerState(List<AssetEntity> mediaPathList, int index)
      : _mediaPathList = mediaPathList,
        _index = index;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.grey,
        //backgroundColor: Colors.transparent,
      ),
      home: WillPopScope(
        onWillPop: () async {
          //TODO WillPopScope not work
          //Navigator.of(context).pop();
          developer.log('onWillPop', name: 'SG');
          setState(() {
            developer.log('onWillPop', name: 'SG');
          });
          return false;
        },
        child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
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
            body: Container(
                //child: _getPreloadPageView()
                child: _getImageView(_index)
            ),
        ),
      ),
    );
  }

  _getPreloadPageView() {
    return PreloadPageView.builder(
      preloadPagesCount: 5,
      itemCount: _mediaPathList.length,
      itemBuilder: (BuildContext context, int position) =>
          _getImageView(position),
      controller: PreloadPageController(initialPage: _index),
      onPageChanged: (int position) {
        print('page changed. current: $position');
      },
    );
  }

  _getImageView(int position) {
    final int index = position;
    developer.log('position: $position', name: 'SG');
    // return PhotoView(
    //   imageProvider:
    return FutureBuilder<File?>(
        future: _mediaPathList[index].file,
        builder: (BuildContext context, snapshot) {
          if (snapshot.hasData == false) {
            //TODO handle error
            return Image.asset('images/no_thumb.png');
          } else if (snapshot.hasError) {
            //TODO handle error
            return Image.asset('images/no_thumb.png');
          } else {
            return PhotoView(
                imageProvider: FileImage(
              snapshot.data as File,
            ));
          }
        });
  }
}