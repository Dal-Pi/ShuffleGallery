import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:preload_page_view/preload_page_view.dart';

enum AlbumPageType {GRID, LIST}

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

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Album>? _albums;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();
  }

  Future<void> initAsync() async {
    if (await _promptPermissionSetting()) {
      List<Album> albums =
          await PhotoGallery.listAlbums(mediumType: MediumType.image);
      setState(() {
        _albums = [albums[0], ...shuffle(albums.sublist(1))];
        _loading = false;
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<bool> _promptPermissionSetting() async {
    if (Platform.isIOS &&
            await Permission.storage.request().isGranted &&
            await Permission.photos.request().isGranted ||
        Platform.isAndroid && await Permission.storage.request().isGranted) {
      return true;
    }
    return false;
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
        appBar: AppBar(
          title: const Text('Shuffle Gallery'),
          brightness: Brightness.light,
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : _getAlbumGridView(),
      ),
    );
  }

  _getAlbumGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double gridWidth = (constraints.maxWidth - 20) / 3;
        double gridHeight = gridWidth + 33;
        double ratio = gridWidth / gridHeight;
        return Container(
          padding: EdgeInsets.all(5),
          child: GridView.count(
            childAspectRatio: ratio,
            crossAxisCount: 3,
            mainAxisSpacing: 5.0,
            crossAxisSpacing: 5.0,
            children: <Widget>[
              ...?_albums?.map(
                (album) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => AlbumPage(album))),
                  child: Column(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          color: Colors.grey[300],
                          height: gridWidth,
                          width: gridWidth,
                          child: FadeInImage(
                            fit: BoxFit.cover,
                            placeholder: MemoryImage(kTransparentImage),
                            image: AlbumThumbnailProvider(
                              albumId: album.id,
                              mediumType: album.mediumType,
                              highQuality: true,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.topLeft,
                        padding: EdgeInsets.only(left: 2.0),
                        child: Text(
                          album.name,
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
                          album.count.toString(),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            height: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AlbumPage extends StatefulWidget {
  final Album album;

  AlbumPage(Album album) : album = album;

  @override
  State<StatefulWidget> createState() => AlbumPageState();
}

class AlbumPageState extends State<AlbumPage> {
  List<Medium>? _media;
  bool _loading = false;
  AlbumPageType _mode = AlbumPageType.GRID;

  @override
  void initState() {
    super.initState();
    _loading = true;
    initAsync();
  }

  void initAsync() async {
    MediaPage mediaPage = await widget.album.listMedia();
    setState(() {
      _media = shuffle(mediaPage.items);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: _loading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Scaffold(
              body: CustomScrollView(
              slivers: <Widget>[
                _getSliverActionBar(),
                _getAlbumPage(),
              ],
            )),
    );
    // return MaterialApp(
    //   theme: ThemeData(
    //     primaryColor: Colors.white,
    //   ),
    //   home: _loading
    //       ? Center(
    //           child: CircularProgressIndicator(),
    //         )
    //       :
    //        // _getBasicAlbumPage(),
    //   _getListAlbumPage(),
    // );
  }

  _getAlbumPage() {
    if (_mode == AlbumPageType.LIST) {
      return _getSliverGridByList();
    } else {
      return _getSliverGrid();
    }
  }

  /*
  _getBasicAlbumPage() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.album.name),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.line_weight /*Icons.grid_on_rounded*/),
              onPressed: () => {})
        ],
      ),
      body: _getImageGridView(),
    );
  }
   */

  /*
  _getListAlbumPage() {
    return Scaffold(
        body: CustomScrollView(
      slivers: <Widget>[
        _getSliverActionBar(),
        _getSliverGridByList(),
      ],
    ));
  }
   */

  _getSliverActionBar() {
    return SliverAppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(widget.album.name),
      floating: true,
      actions: <Widget>[
        IconButton(icon: _getAlbumModeIcon(),
            onPressed: () => _onAlbumModeChange()),
      ],
      //flexibleSpace: Placeholder(),
      //expandedHeight: 200,
    );
  }

  _getAlbumModeIcon() {
    if (_mode == AlbumPageType.LIST) {
      return Icon(Icons.view_comfy);
    } else {
      return Icon(Icons.line_weight);
    }
  }

  _onAlbumModeChange() {
    setState(() {
      _mode = (_mode == AlbumPageType.LIST)
          ? AlbumPageType.GRID
          : AlbumPageType.LIST;
    });
  }

  _getSliverGridByList() {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => PreloadImagePageView(_media!, index))),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
            child: Card(
              color: Colors.grey[300],
              elevation: 4.0,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: FadeInImage(
                fit: BoxFit.cover,
                placeholder: MemoryImage(kTransparentImage),
                image: PhotoProvider(mediumId: _media![index].id),
              ),
            ),
          ),
        );
      }, childCount: _media?.length),
    );
  }

  _getSliverGrid() {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 1.0,
        crossAxisSpacing: 1.0,
      ),
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

  /*
  _getImageGridView() {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 1.0,
      crossAxisSpacing: 1.0,
      children: <Widget>[
        ...?_media
            ?.asMap()
            .map((index, medium) => MapEntry(
                  index,
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            PreloadImagePageView(_media!, index))),
                    child: Container(
                      color: Colors.grey[300],
                      child: FadeInImage(
                        fit: BoxFit.cover,
                        placeholder: MemoryImage(kTransparentImage),
                        image: ThumbnailProvider(
                          mediumId: medium.id,
                          mediumType: medium.mediumType,
                          highQuality: true,
                        ),
                      ),
                    ),
                  ),
                ))
            .values
            .toList(),
      ],
    );
  }
   */
}

class PreloadImagePageView extends StatefulWidget {
  final List<Medium> media;
  final int initialIndex;

  PreloadImagePageView(List<Medium> media, index)
      : media = media,
        initialIndex = index {
    developer.log('index: $index', name: 'SG');
  }

  @override
  _PreloadImagePageViewState createState() => _PreloadImagePageViewState();
}

class _PreloadImagePageViewState extends State<PreloadImagePageView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios),
          ),
          backgroundColor: Colors.transparent,
          elevation: 1.0,
        ),
        body: Container(child: _getPreloadPageView()));
  }

  _getPreloadPageView() {
    return PreloadPageView.builder(
      preloadPagesCount: 5,
      itemCount: widget.media.length,
      itemBuilder: (BuildContext context, int position) => _getImage(position),
      controller: PreloadPageController(initialPage: widget.initialIndex),
      onPageChanged: (int position) {
        print('page changed. current: $position');
      },
    );
  }

  _getImage(int position) {
    final int index = position;
    developer.log('position: $position', name: 'SG');
    return Container(
      alignment: Alignment.center,
      child: widget.media[index].mediumType == MediumType.image
          ? PhotoView(
              imageProvider: PhotoProvider(mediumId: widget.media[index].id),
            )
          // ? FadeInImage(
          //     fit: BoxFit.cover,
          //     placeholder: MemoryImage(kTransparentImage),
          //     image: PhotoProvider(mediumId: medium.id),
          //   )
          : VideoProvider(
              mediumId: widget.media[index].id,
            ),
    );
  }
}

class VideoProvider extends StatefulWidget {
  final String mediumId;

  const VideoProvider({
    required this.mediumId,
  });

  @override
  _VideoProviderState createState() => _VideoProviderState();
}

class _VideoProviderState extends State<VideoProvider> {
  VideoPlayerController? _controller;
  File? _file;

  @override
  void initState() {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      initAsync();
    });
    super.initState();
  }

  Future<void> initAsync() async {
    try {
      _file = await PhotoGallery.getFile(mediumId: widget.mediumId);
      _controller = VideoPlayerController.file(_file!);
      _controller?.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
    } catch (e) {
      print("Failed : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return _controller == null || !_controller!.value.isInitialized
        ? Container()
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              FlatButton(
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ],
          );
  }
}