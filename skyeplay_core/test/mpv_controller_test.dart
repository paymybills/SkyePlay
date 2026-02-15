import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:skyeplay_core/src/services/mpv_controller.dart';
import 'package:test/test.dart';

// Mock Process
class MockProcess implements Process {
  final StreamController<List<int>> _stdoutController = StreamController();
  final StreamController<List<int>> _stderrController = StreamController();
  final MockIOSink _stdin = MockIOSink();

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => Future.value(0);
  
  // Implement other members with dummy errors or no-ops
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
  
  @override
  int get pid => 123;
}

class MockIOSink implements IOSink {
  final List<String> writes = [];
  
  @override
  void writeln([Object? obj = ""]) {
    writes.add(obj.toString());
  }
  
  @override
  void add(List<int> data) {}
  
  @override
  void write(Object? obj) {
    writes.add(obj.toString());
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  
  @override
  void writeCharCode(int charCode) {}
  
  @override
  Future addStream(Stream<List<int>> stream) async {}
  
  @override
  Future flush() async {}
  
  @override
  Future close() async {}
  
  @override
  Encoding encoding = utf8;
  
  @override
  set done(Future voidFuture) {}
  
  @override
  Future get done => Future.value();

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MpvController', () {
    late MpvController controller;
    late MockProcess mockProcess;

    setUp(() {
      mockProcess = MockProcess();
      controller = MpvController(
        processStarter: (exe, args) async => mockProcess,
      );
    });

    test('Starts process with correct args', () async {
      bool called = false;
      controller = MpvController(
        processStarter: (exe, args) async {
          called = true;
          expect(exe, equals('mpv'));
          expect(args, contains('--idle'));
          return mockProcess;
        },
      );
      await controller.start();
      expect(called, isTrue);
    });

    test('Sends play command', () async {
      await controller.start();
      controller.play('path/to/file.mp3');
      
      final sink = mockProcess.stdin as MockIOSink;
      expect(sink.writes.first, equals('loadfile "path/to/file.mp3"'));
    });

    test('Sends pause/stop commands', () async {
      await controller.start();
      
      controller.pause();
      var sink = mockProcess.stdin as MockIOSink;
      expect(sink.writes.last, equals('cycle pause'));
      
      controller.stop();
      expect(sink.writes.last, equals('stop'));
    });

    test('Exposes stdout events', () async {
      await controller.start();
      
      final eventFuture = controller.events.first;
      
      mockProcess._stdoutController.add(utf8.encode("Test Output\n"));
      
      final event = await eventFuture;
      expect(event, equals("Test Output"));
    });
  });
}
