import 'package:flutter/material.dart';
import 'package:learning_digital_ink_recognition/learning_digital_ink_recognition.dart';
import 'package:learning_input_image/learning_input_image.dart';
import 'package:provider/provider.dart';

import 'painter.dart';

void main() {
  runApp(const MaterialApp(
    title: 'Navigation Basics',
    home: FirstRoute(),
  ));
}

class FirstRoute extends StatelessWidget {
  const FirstRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Route'),
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text('Open route'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyApp()),
            );
          },
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        primaryTextTheme: TextTheme(
          headline6: TextStyle(color: Colors.white),
        ),
      ),
      home: ChangeNotifierProvider(
        create: (_) => DigitalInkRecognitionState(),
        child: DigitalInkRecognitionPage(),
      ),
    );
  }
}

class DigitalInkRecognitionPage extends StatefulWidget {
  @override
  _DigitalInkRecognitionPageState createState() =>
      _DigitalInkRecognitionPageState();
}

class _DigitalInkRecognitionPageState extends State<DigitalInkRecognitionPage> {
  final String _model = 'ja';

  DigitalInkRecognitionState get state => Provider.of(context, listen: false);
  late DigitalInkRecognition _recognition;

  double get _width => MediaQuery.of(context).size.width;
  double _height = 200;

  @override
  void initState() {
    _recognition = DigitalInkRecognition(model: _model);
    super.initState();
  }

  @override
  void dispose() {
    _recognition.dispose();
    super.dispose();
  }

  // need to call start() at the first time before painting the ink
  Future<void> _init() async {
    //print('Writing Area: ($_width, $_height)');
    await _recognition.start(writingArea: Size(_width, _height));
    // always check the availability of model before being used for recognition
    await _checkModel();
  }

  // reset the ink recognition
  Future<void> _reset() async {
    state.reset();
    await _recognition.start(writingArea: Size(_width, _height));
  }

  Future<void> _checkModel() async {
    bool isDownloaded = await DigitalInkModelManager.isDownloaded(_model);

    if (!isDownloaded) {
      await DigitalInkModelManager.download(_model);
    }
  }

  Future<void> _actionDown(Offset point) async {
    state.startWriting(point);
    await _recognition.actionDown(point);
  }

  Future<void> _actionMove(Offset point) async {
    state.writePoint(point);
    await _recognition.actionMove(point);
  }

  Future<void> _actionUp() async {
    state.stopWriting();
    await _recognition.actionUp();
  }

  Future<void> _startRecognition() async {
    if (state.isNotProcessing) {
      state.startProcessing();
      // always check the availability of model before being used for recognition
      await _checkModel();
      state.data = await _recognition.process();
      state.stopProcessing();
      if (state._terms[state._termIdx] == state.toCompleteString()) {
        print("You got it!" + state.toCompleteString());
        state.termIdx += 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ML Digital Ink Recognition'),
      ),
      body: Column(
        children: [
          Center(
            child:
                Consumer<DigitalInkRecognitionState>(builder: (_, state, __) {
              return Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    state.currentTerm(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            }),
          ),
          Builder(
            builder: (_) {
              _init();

              return GestureDetector(
                onScaleStart: (details) async =>
                    await _actionDown(details.localFocalPoint),
                onScaleUpdate: (details) async =>
                    await _actionMove(details.localFocalPoint),
                onScaleEnd: (details) async => await _actionUp(),
                child: Consumer<DigitalInkRecognitionState>(
                  builder: (_, state, __) => CustomPaint(
                    painter: DigitalInkPainter(writings: state.writings),
                    child: Container(
                      width: _width,
                      height: _height,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          NormalPinkButton(
            text: 'Start Recognition',
            onPressed: _startRecognition,
          ),
          SizedBox(height: 5),
          NormalBlueButton(
            text: 'Reset Canvas',
            onPressed: _reset,
          ),
          ElevatedButton(
            child: const Text('Open route'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FirstRoute()),
              );
            },
          ),
          SizedBox(height: 15),
          Center(
            child:
                Consumer<DigitalInkRecognitionState>(builder: (_, state, __) {
              if (state.isNotProcessing && state.isNotEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      state.toCompleteString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ),
                );
              }

              if (state.isProcessing) {
                return Center(
                  child: Container(
                    width: 36,
                    height: 20,
                    color: Colors.transparent,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              return Container();
            }),
          ),
          Expanded(child: Container()),
        ],
      ),
    );
  }
}

class DigitalInkRecognitionState extends ChangeNotifier {
  List<List<Offset>> _writings = [];
  List<RecognitionCandidate> _data = [];
  bool isProcessing = false;
  int _termIdx = 0;
  List<String> _terms = ["???", "???"];

  List<List<Offset>> get writings => _writings;
  List<RecognitionCandidate> get data => _data;
  int get termIdx => _termIdx;
  bool get isNotProcessing => !isProcessing;
  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;

  List<Offset> _writing = [];

  void reset() {
    _writings = [];
    notifyListeners();
  }

  void startWriting(Offset point) {
    _writing = [point];
    _writings.add(_writing);
    notifyListeners();
  }

  void writePoint(Offset point) {
    if (_writings.isNotEmpty) {
      _writings[_writings.length - 1].add(point);
      notifyListeners();
    }
  }

  void stopWriting() {
    _writing = [];
    notifyListeners();
  }

  void startProcessing() {
    isProcessing = true;
    notifyListeners();
  }

  void stopProcessing() {
    isProcessing = false;
    notifyListeners();
  }

  set data(List<RecognitionCandidate> data) {
    _data = data;
    notifyListeners();
  }

  set termIdx(int termIdx) {
    _termIdx = termIdx;
    notifyListeners();
  }

  @override
  String toString() {
    return isNotEmpty ? _data.first.text : '';
  }

  String toCompleteString() {
    return isNotEmpty ? _data.first.text : '';
  }

  String currentTerm() {
    return "Draw this: " + _terms[_termIdx];
  }
}
