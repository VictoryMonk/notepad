import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NoteStorage {
  static Future<Directory> get _notesDir async {
    final directory = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${directory.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  static Future<Directory> get _binDir async {
    final directory = await getApplicationDocumentsDirectory();
    final binDir = Directory('${directory.path}/bin');
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }
    return binDir;
  }

  static Future<String> getNoteDirPath(String noteId, {bool isBin = false}) async {
    final dir = isBin ? await _binDir : await _notesDir;
    return '${dir.path}/$noteId';
  }

  static Future<List<Note>> loadNotes({bool fromBin = false}) async {
    List<Note> notes = [];
    try {
      final dir = fromBin ? await _binDir : await _notesDir;
      final noteDirs = dir.listSync().whereType<Directory>().toList();
      for (var dir in noteDirs) {
        final noteJsonFile = File('${dir.path}/note.json');
        if (noteJsonFile.existsSync()) {
          try {
            final jsonStr = noteJsonFile.readAsStringSync();
            final jsonMap = json.decode(jsonStr);
            final note = Note.fromJson(jsonMap);
            if (fromBin && note.deletedAt != null) {
              final daysSinceDeletion = DateTime.now().difference(note.deletedAt!).inDays;
              if (daysSinceDeletion >= 7) {
                await deleteNotePermanently(note.id);
                continue; // Skip adding to list as it’s permanently deleted
              }
            }
            notes.add(note);
          } catch (e) {
            print('Error reading note from ${noteJsonFile.path}: $e');
          }
        }
      }
    } catch (e) {
      print('Error accessing ${fromBin ? "bin" : "notes"} directory: $e');
    }
    return notes;
  }

  static Future<void> saveNote(Note note, {bool toBin = false}) async {
    try {
      final dir = toBin ? await _binDir : await _notesDir;
      final noteDir = Directory('${dir.path}/${note.id}')..createSync(recursive: true);
      final noteJsonFile = File('${noteDir.path}/note.json');

      List<String> updatedImagePaths = [];
      for (var path in note.imagePaths) {
        final fileName = path.split('/').last;
        final newPath = '${noteDir.path}/$fileName';
        if (File(path).existsSync() && path != newPath) {
          await File(path).copy(newPath);
        }
        updatedImagePaths.add(newPath);
      }
      note.imagePaths = updatedImagePaths;

      noteJsonFile.writeAsStringSync(json.encode(note.toJson()));
    } catch (e) {
      print('Error saving note: $e');
    }
  }

  static Future<void> moveToBin(String noteId) async {
    try {
      final notesDir = await _notesDir;
      final binDir = await _binDir;
      final noteDir = Directory('${notesDir.path}/$noteId');
      if (noteDir.existsSync()) {
        final noteJsonFile = File('${noteDir.path}/note.json');
        if (noteJsonFile.existsSync()) {
          final note = Note.fromJson(json.decode(noteJsonFile.readAsStringSync()));
          note.deletedAt = DateTime.now();
          await saveNote(note, toBin: true);
          await noteDir.delete(recursive: true); // Remove from notes dir
        }
      }
    } catch (e) {
      print('Error moving note to bin: $e');
    }
  }

  static Future<void> restoreFromBin(String noteId) async {
    try {
      final binDir = await _binDir;
      final notesDir = await _notesDir;
      final noteDir = Directory('${binDir.path}/$noteId');
      if (noteDir.existsSync()) {
        final noteJsonFile = File('${noteDir.path}/note.json');
        if (noteJsonFile.existsSync()) {
          final note = Note.fromJson(json.decode(noteJsonFile.readAsStringSync()));
          note.deletedAt = null;
          await saveNote(note, toBin: false);
          await noteDir.delete(recursive: true); // Remove from bin
        }
      }
    } catch (e) {
      print('Error restoring note: $e');
    }
  }

  static Future<void> deleteNotePermanently(String noteId) async {
    try {
      final binDir = await _binDir;
      final noteDir = Directory('${binDir.path}/$noteId');
      if (noteDir.existsSync()) {
        await noteDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error permanently deleting note: $e');
    }
  }
}