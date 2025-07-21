import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_detection_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FaceDetector _faceDetector = FaceDetector(options: FaceDetectorOptions(
    enableClassification: true,
    enableLandmarks: true,
    enableTracking: true,
    performanceMode: FaceDetectorMode.fast,
  ));

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  bool _isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);

    _initializeCameras();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();

    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        debugPrint('No cameras found');
      }

      _selectedCameraIndex = _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.front);

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _initializeCamera(_cameras[_selectedCameraIndex]);
    }

    catch (error) {
      debugPrint('Error: $error');
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420
    );

    _controller = controller;

    _initializeControllerFuture = controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _startFaceDetection();
      });
    }).catchError((error) {
      debugPrint('Error: $error');
    });
  }

  void _toggleCamera() async {
      if (_cameras.isEmpty || _cameras.length < 2) {
        debugPrint('Can\'t toggle camera, not enough cameras available');
        return;
      }

      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

      setState(() {
        _faces = [];
      });

      await _initializeCamera(_cameras[_selectedCameraIndex]);
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    _controller!.startImageStream((CameraImage cameraImage) async {
      if (_isDetecting) {
        return;
      }

      _isDetecting = true;

      final inputImage = _convertCameraImageToInputImage(cameraImage);

      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      try {
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
          });
        }
      }

      catch (error) {
        debugPrint('Error: $error');
      }

      finally {
        _isDetecting = false;
      }
    });
  }

  InputImage? _convertCameraImageToInputImage(CameraImage cameraImage) {
    if (_controller == null) {
      return null;
    }

    try {
      final format = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: InputImageRotation.values.firstWhere((element) => element.rawValue == _controller!.description.sensorOrientation,
          orElse: () => InputImageRotation.rotation0deg),
          format: format,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      final bytes = _concatenatePlanes(cameraImage.planes);
      
      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    }

    catch (error) {
      debugPrint('Error: $error');
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();

    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Face Detection',
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: Icon(Icons.cameraswitch_outlined),
              color: Colors.blueAccent,
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: _initializeControllerFuture == null ? Center(
        child: Text('No cameras available'),
      ) : FutureBuilder<void>(future: _initializeControllerFuture, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && _controller != null && _controller!.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              CustomPaint(
                painter: FaceDetectionPainter(
                  faces: _faces,
                  imageSize: Size(
                    _controller!.value.previewSize!.height,
                    _controller!.value.previewSize!.width,
                  ),
                  cameraLensDirection: _controller!.description.lensDirection,
                ),
              ),
              Positioned(
                bottom: 75,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Faces detected: ${_faces.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error'),
          );
        }
        else {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
            ),
          );
        }
      }),
    );
  }
}