import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/note.dart';
import '../storage/note_storage.dart';

class NoteEditor extends StatefulWidget {
  final Note? note;

  const NoteEditor({this.note, Key? key}) : super(key: key);

  @override
  _NoteEditorState createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  List<Map<String, String>> _chatMessages = [];
  final TextEditingController _questionController = TextEditingController();
  bool _isAwaitingResponse = false;

  String? _summary;
  bool _isSummarizing = false;
  final String _googleApiKey = 'AIzaSyCzjDQ9dXCP5K08_kFpwL0D94ZkP-qtUVo';
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
    _color = widget.note?.color ?? const Color(0xFF181C20);
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

  Future<void> _summarizeNote() async {
    setState(() {
      _isSummarizing = true;
      _summary = null;
    });
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$_googleApiKey',
    );
    final prompt = _contentController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _summary = 'Note is empty, nothing to summarize.';
        _isSummarizing = false;
      });
      return;
    }
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Summarize this note: $prompt'}
              ]
            }
          ]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Gemini returns summary in data['candidates'][0]['content']['parts'][0]['text']
        final summary = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'No summary generated.';
        setState(() {
          _summary = summary;
        });
      } else {
        setState(() {
          _summary = 'Failed to summarize: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _summary = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSummarizing = false;
      });
    }
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
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    setState(() {
      _chatMessages.add({'role': 'user', 'text': question});
      _isAwaitingResponse = true;
      _questionController.clear();
    });
    final aiResponse = await _askGemini(question, context: _summary ?? _contentController.text);
    setState(() {
      _chatMessages.add({'role': 'ai', 'text': aiResponse});
      _isAwaitingResponse = false;
    });
  }

  Future<String> _askGemini(String question, {required String context}) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$_googleApiKey',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Context: $context\nQuestion: $question'}
              ]
            }
          ]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'No answer generated.';
        return answer;
      } else {
        return 'Failed to get answer: ${response.reasonPhrase}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _color,
        appBar: AppBar(
          backgroundColor: _color,
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
                  decoration: InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: _color,
                  ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: 'Note',
                    border: InputBorder.none,
                    filled: true,
                    fillColor: _color,
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
                const SizedBox(height: 24),
                if (_isSummarizing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                if (_summary != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(_summary!),
                        const SizedBox(height: 16),
                        // Chat UI
                        const Text('Ask AI:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Container(
                          height: 180,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _chatMessages.isEmpty
                              ? const Center(child: Text('No conversation yet.'))
                              : ListView(
                                  children: _chatMessages.map((msg) {
                                    final isUser = msg['role'] == 'user';
                                    return Align(
                                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isUser ? Colors.blue[200] : Colors.grey[850],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
  msg['text'] ?? '',
  style: TextStyle(color: isUser ? Colors.black : Colors.white),
),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _questionController,
                                enabled: !_isAwaitingResponse,
                                decoration: const InputDecoration(
                                  hintText: 'Ask a question...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _sendQuestion(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isAwaitingResponse ? null : _sendQuestion,
                              child: _isAwaitingResponse
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.send),
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSummarizing ? null : _summarizeNote,
          icon: const Icon(Icons.summarize),
          label: const Text('Summarize'),
        ),
      ),
    );
  }
}
