import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mdns_plugin/mdns_plugin.dart';
import 'package:nfc_in_flutter/nfc_in_flutter.dart';
import 'package:http/http.dart';

void main()  {
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NFC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter NFC'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> implements MDNSPluginDelegate {
  String _statusText;
  StreamSubscription<NDEFMessage> _stream;

  // _tags is a list of scanned tags
  NDEFMessage _tag;
  bool _supportsNFC = false;
  String host = '';
  String ledOnURL = 'http://esp8266.local/start';
  String ledOffURL = 'http://esp8266.local/stop';
  bool _ledIsOn;
  String _imageName;
  String _errorStr = 'Error!';
  String _scanStr = 'please scan';
  String _onStr = 'Led is on';
  String _offStr = 'Led is off';
  String _connStr = 'Waiting';
  String _connStr2 = 'for WiFi';
  String _connImage = 'assets/connection.png';
  String _dayImage = 'assets/day.png';
  String _nightImage = 'assets/night.png';
  String _errorImage = 'assets/error.png';
  Color _textColor;
  Color _bgColor;

  void onDiscoveryStarted() {
    print("Discovery started");
  }
  void onDiscoveryStopped() {
    print("Discovery stopped");
  }
  bool onServiceFound(MDNSService service) {
    print("Found: $service");

    // Always returns true which begins service resolution
    return true;
  }
  void onServiceResolved(MDNSService service) {
    print("Resolved: $service");
    host = service.hostName;
    ledOnURL = 'http://'+host+'/start';
    ledOffURL = 'http://'+host+'/stop';
    _callLedEndpoint();
  }
  void onServiceUpdated(MDNSService service) {
    print("Updated: $service");
  }
  void onServiceRemoved(MDNSService service) {
    print("Removed: $service");
  }

  @override
  initState()  {
    super.initState();
    NFC.isNDEFSupported.then((supported) {
      setState(() {
        _supportsNFC = true;

      });
    });
    MDNSPlugin mdns = new MDNSPlugin(this);
    mdns.startDiscovery("_http._tcp",enableUpdating: true);

    _ledIsOn = false;
    setState(() {
      _statusText = _connStr;
      _imageName = _connImage;
      _textColor = Colors.black54;
      _bgColor = Colors.white;
      _scanStr = _connStr2;
    });

  }

  @override
  void dispose() {
    super.dispose();
    _stream?.cancel();
  }

  void _callLedEndpoint() async {
    print(_ledIsOn);
    String url = ledOnURL;
    if (!_ledIsOn) {
     url = ledOffURL;
    }
    try {
      Response response = await get(url);
      // sample info available in response
      int statusCode = response.statusCode;
      if (statusCode == 200) {
        String content = response.body;
        print(content);
        setState(() {
          if (content == "led is on!") {
            _statusText = _onStr;
            _imageName = _dayImage;
            _textColor = Colors.black54;
            _bgColor = Colors.white;
            _scanStr = 'please scan';
          }
          else {
            _statusText = _offStr;
            _imageName = _nightImage;
            _textColor = Colors.white;
            _bgColor = Colors.black87;
            _scanStr = 'please scan';
          }
        });
        _ledIsOn = !_ledIsOn;
      } else {
        print('Status code is: '+statusCode.toString());
        setState(() {
          _statusText = _errorStr;
          _imageName = _errorImage;
          _textColor = Colors.white;
          _bgColor = Colors.black87;
          _scanStr = 'please scan';
        });
      }
    }
    catch(error) {
    print(error.toString());
    setState(() {
    _statusText = _errorStr;
    _imageName = _errorImage;
    _textColor = Colors.white;
    _bgColor = Colors.black87;
    _scanStr = 'please scan';
    });
    }
  }

  // _readNFC() calls `NFC.readNDEF()` and stores the subscription and scanned
  // tags in state
  void _readNFC(BuildContext context) {
    try {
      // ignore: cancel_subscriptions
      StreamSubscription<NDEFMessage> subscription = NFC.readNDEF(once: true).listen(
          (tag) {
        print('tag found!');
        // On new tag, add it to state
          print(tag.records[0].data);
          _callLedEndpoint();

      },
          // When the stream is done, remove the subscription from state
          onDone: () {
        setState(() {
          _stream = null;
        });
      },
          // Errors are unlikely to happen on Android unless the NFC tags are
          // poorly formatted or removed too soon, however on iOS at least one
          // error is likely to happen. NFCUserCanceledSessionException will
          // always happen unless you call readNDEF() with the `throwOnUserCancel`
          // argument set to false.
          // NFCSessionTimeoutException will be thrown if the session timer exceeds
          // 60 seconds (iOS only).
          // And then there are of course errors for unexpected stuff. Good fun!
          onError: (e) {
        setState(() {
          _stream = null;
        });

        if (!(e is NFCUserCanceledSessionException)) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Error!"),
              content: Text(e.toString()),
            ),
          );
        }
      });

      setState(() {
        _stream = subscription;
      });
    } catch (err) {
      print("error: $err");
    }
  }

  // _stopReading() cancels the current reading stream
  void _stopReading() {
    _stream?.cancel();
    setState(() {
      _stream = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _readNFC(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Container(
          color: _bgColor,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image(image: AssetImage(_imageName)),
                Text(_statusText, style: GoogleFonts.oswald(textStyle: Theme.of(context).textTheme.headline1, color: _textColor),),
                Text(_scanStr, style: GoogleFonts.oswald(textStyle: Theme.of(context).textTheme.headline3, color: _textColor),),]
          ),
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
