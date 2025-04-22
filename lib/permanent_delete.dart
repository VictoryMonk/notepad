import 'package:flutter/material.dart';
import 'storage/note_storage.dart';

Future<void> permanentlyDeleteNotes(List<String> noteIds, VoidCallback onSuccess) async {
  for (final id in noteIds) {
    await NoteStorage.deleteNotePermanently(id);
  }
  onSuccess();
}
