import 'dart:io';
import 'dart:convert';
import 'dart:async';

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class MpvController {
  final String mpvPath;
  Process? _process;
  final ProcessStarter _processStarter;
  
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  MpvController({
    this.mpvPath = 'mpv', 
    ProcessStarter? processStarter
  }) : _processStarter = processStarter ?? Process.start;

  Future<void> start() async {
    // Start mpv in idle mode, no video
    _process = await _processStarter(mpvPath, [
      '--idle', 
      '--no-video', 
      '--no-terminal',
      '--input-terminal=yes' // Ensure it reads stdin
    ]);

    // Listen to output
    _process!.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
      if (line.isNotEmpty) {
        _eventController.add(line);
      }
    });
    
    _process!.stderr.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
      // print("MPV ERR: $line");
    });
  }

  void play(String path) {
    if (_process == null) return;
    // Quote the path to handle spaces
    _process!.stdin.writeln('loadfile "$path"');
  }

  void pause() {
    if (_process == null) return;
    _process!.stdin.writeln('cycle pause'); 
  }

  void stop() {
    if (_process == null) return;
    _process!.stdin.writeln('stop');
  }
  
  void setVolume(int vol) {
    if (_process == null) return;
    _process!.stdin.writeln('set volume $vol');
  }

  Future<void> dispose() async {
    _process?.kill();
    _process = null;
    await _eventController.close();
  }
}
