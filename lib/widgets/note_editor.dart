import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../storage/note_storage.dart';

class NoteEditor extends StatefulWidget {
  final Note? note;

  const NoteEditor({this.note, Key? key}) : super(key: key);

  @override
  _NoteEditorState createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late String _noteId;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late bool _isPinned;
  late Color _color;
  late List<String> _imagePaths;
  final ImagePicker _picker = ImagePicker();

  static const List<Color> colorOptions = [
    Colors.black,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _isPinned = widget.note?.isPinned ?? false;
    _color = widget.note?.color ?? Colors.grey;
    _imagePaths = List.from(widget.note?.imagePaths ?? []);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagePaths.add(image.path);
      });
    }
  }

  Future<bool> _onWillPop() async {
    _saveNote();
    return true;
  }

  void _saveNote() {
    final note = Note(
      id: _noteId,
      title: _titleController.text,
      content: _contentController.text,
      isPinned: _isPinned,
      color: _color,
      imagePaths: _imagePaths,
    );

    // Only save if the note has content (title, content, or images)
    if (note.title.isNotEmpty || note.content.isNotEmpty || note.imagePaths.isNotEmpty) {
      NoteStorage.saveNote(note);
      Navigator.pop(context, note); // Return the note only if saved
    } else {
      Navigator.pop(context); // Discard empty note
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF181C20),
        appBar: AppBar(
          backgroundColor: const Color(0xFF181C20),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveNote,
          ),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
            IconButton(
              icon: const Icon(Icons.palette),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(8.0),
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: colorOptions.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => _color = color);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _pickImage,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Color(0xFF181C20),
                  ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Note',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Color(0xFF181C20),
                  ),
                  maxLines: null,
                ),
                if (_imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _imagePaths.map((path) {
                      return Image.file(
                        File(path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}