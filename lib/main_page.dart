import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'widgets/note_editor.dart';
import 'storage/note_storage.dart';
import 'models/note.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  // NOTE: The comment says "it should match the text field colour"
  // We'll assume a dark theme color for the TextField background.

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<Note> notes = [];
  List<Note> filteredNotes = [];
  List<Note> binNotes = [];
  bool isLoading = true;
  bool isSearching = false;
  bool isSelecting = false;
  bool isViewingBin = false;
  Set<String> selectedNoteIds = {};
  bool binSelecting = false;
  Set<String> binSelectedNoteIds = {};

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  Future<void> _loadNotes() async {
    try {
      final loadedNotes = await NoteStorage.loadNotes();
      final loadedBinNotes = await NoteStorage.loadNotes(fromBin: true);
      setState(() {
        notes = loadedNotes;
        binNotes = loadedBinNotes;
        _sortNotes();
        filteredNotes = List.from(notes);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        notes = [];
        binNotes = [];
        filteredNotes = [];
        isLoading = false;
      });
    }
  }

  void _sortNotes() {
    notes.sort((a, b) {
      // Pinned notes first, then by creation date (DESC)
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    binNotes.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
  }

  void _filterNotes() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredNotes = List.from(notes);
      } else {
        filteredNotes = notes.where((note) {
          return note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query);
        }).toList();
      }
      _sortNotes();
    });
  }

  Future<void> _openNoteEditor({Note? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditor(note: note)),
    );
    if (result != null && result is Note) {
      setState(() {
        if (note != null) {
          final index = notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            notes[index] = result;
          } else {
            notes.add(result);
          }
        } else {
          notes.add(result);
        }
        _sortNotes();
        _filterNotes();
      });
      NoteStorage.saveNote(result);
    }
  }

  Future<void> _moveToBin(List<String> noteIds) async {
    await Future.wait(noteIds.map((id) => NoteStorage.moveToBin(id)));
    setState(() {
      notes.removeWhere((note) => noteIds.contains(note.id));
      isSelecting = false;
      selectedNoteIds.clear();
    });
    await _loadNotes();
  }

  Future<void> _restoreFromBin(String noteId) async {
    await NoteStorage.restoreFromBin(noteId);
    await _loadNotes();
  }

  Future<void> _restoreMultipleFromBin(List<String> noteIds) async {
    await Future.wait(noteIds.map((id) => NoteStorage.restoreFromBin(id)));
    setState(() {
      binSelecting = false;
      binSelectedNoteIds.clear();
    });
    await _loadNotes();
  }

  void _togglePinNote(Note note) {
    setState(() {
      note.isPinned = !note.isPinned;
      _sortNotes();
      _filterNotes();
    });
    NoteStorage.saveNote(note);
  }

  void _showNoteOptions(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
              Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(note.isPinned ? 'Unpin Note' : 'Pin Note'),
              onTap: () {
                _togglePinNote(note);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Note'),
              onTap: () {
                _moveToBin([note.id]);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchController.clear();
        filteredNotes = List.from(notes);
      }
    });
  }

  void _toggleSelectMode() {
    setState(() {
      isSelecting = !isSelecting;
      if (!isSelecting) selectedNoteIds.clear();
    });
  }

  void _toggleBinView() {
    setState(() {
      isViewingBin = !isViewingBin;
      isSelecting = false;
      selectedNoteIds.clear();
      binSelecting = false;
      binSelectedNoteIds.clear();
    });
  }

  void _toggleBinSelectMode() {
    setState(() {
      binSelecting = !binSelecting;
      if (!binSelecting) binSelectedNoteIds.clear();
    });
  }

  // Tap logic: in normal view, either select or open. In bin view, either select or restore.
  void _handleNoteTap(Note note) {
    if (isViewingBin) {
      if (binSelecting) {
        setState(() {
          if (binSelectedNoteIds.contains(note.id)) {
            binSelectedNoteIds.remove(note.id);
          } else {
            binSelectedNoteIds.add(note.id);
          }
        });
      } else {
        _restoreFromBin(note.id);
      }
    } else {
      if (isSelecting) {
        setState(() {
          if (selectedNoteIds.contains(note.id)) {
            selectedNoteIds.remove(note.id);
          } else {
            selectedNoteIds.add(note.id);
          }
        });
      } else {
        _openNoteEditor(note: note);
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Note> displayNotes = isViewingBin ? binNotes : filteredNotes;

    return Scaffold(
      appBar: AppBar(
        // If searching, show a "darkish" container that matches the theme.
        title: isSearching
            ? Container(
          // Give the TextField a dark background to match the note color (e.g., #23272B).
          decoration: BoxDecoration(
            color: const Color(0xFF23272B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search notes...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white70,
          ),
        )
            : Text(isViewingBin ? 'Bin' : 'Notes'),
        actions: [
          if (!isViewingBin)
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _toggleBinView,
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("User Name"),
              accountEmail: Text("email@example.com"),
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('All Notes'),
              onTap: () {
                setState(() {
                  isViewingBin = false;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Bin'),
              onTap: () {
                setState(() {
                  isViewingBin = true;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : displayNotes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sticky_note_2, size: 80, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              isViewingBin
                  ? 'Bin is empty'
                  : 'No notes found. Tap + to add one.',
              style: TextStyle(color: Colors.grey[700], fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: displayNotes.length,
          itemBuilder: (context, index) {
            final note = displayNotes[index];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInBack,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: GestureDetector(
                key: ValueKey(note.id + (note.isPinned ? '_pinned' : '')),
                onTap: () => _handleNoteTap(note),
                onLongPress: isViewingBin
                    ? () {
                  if (!binSelecting) {
                    setState(() {
                      binSelecting = true;
                      binSelectedNoteIds.add(note.id);
                    });
                  }
                }
                    : () {
                  if (!isSelecting) {
                    setState(() {
                      isSelecting = true;
                      selectedNoteIds.add(note.id);
                    });
                  } else {
                    _showNoteOptions(context, note);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: note.color.withOpacity(
                      (isViewingBin
                          ? (binSelecting &&
                          binSelectedNoteIds.contains(note.id))
                          : (isSelecting &&
                          selectedNoteIds.contains(note.id)))
                          ? 0.7
                          : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Card(
                    color: (note.color.value == 0xFF23272B)
                        ? const Color(0xFF23272B)  // Dark background if #23272B
                        : note.color,
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                          // If there's an image, display it; else show note text.
                          note.imagePaths.isNotEmpty
                              ? Image.file(
                            File(note.imagePaths.first),
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          )
                              : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (note.title.isNotEmpty)
                                  Text(
                                    note.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (note.content.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(note.content),
                                ],
                              ],
                            ),
                          ),
                          // If image, show overlay text near bottom.
                          if (note.imagePaths.isNotEmpty)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.title.isNotEmpty)
                                    Text(
                                      note.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black
                                                .withOpacity(0.3),
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          )
                                        ],
                                      ),
                                    ),
                                  if (note.content.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      note.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black
                                                .withOpacity(0.3),
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          // Checkbox for normal note selection (not bin).
                          if (isSelecting && !isViewingBin)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Checkbox(
                                value: selectedNoteIds.contains(note.id),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedNoteIds.add(note.id);
                                    } else {
                                      selectedNoteIds.remove(note.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          // Checkbox for bin note selection.
                          if (isViewingBin && binSelecting)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Checkbox(
                                value: binSelectedNoteIds.contains(note.id),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      binSelectedNoteIds.add(note.id);
                                    } else {
                                      binSelectedNoteIds.remove(note.id);
                                    }
                                  });
                                },
                              ),
                            ),
                          // Restore button if in bin (non-selecting).
                          if (isViewingBin && !binSelecting)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.restore),
                                onPressed: () => _restoreFromBin(note.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: !isViewingBin
          ? (isSelecting && selectedNoteIds.isNotEmpty
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'delete_fab',
            onPressed: () async =>
            await _moveToBin(selectedNoteIds.toList()),
            child: const Icon(Icons.delete),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'pin_fab',
            onPressed: () {
              setState(() {
                for (var note in notes
                    .where((n) => selectedNoteIds.contains(n.id))) {
                  note.isPinned = !note.isPinned;
                  NoteStorage.saveNote(note);
                }
                isSelecting = false;
                selectedNoteIds.clear();
                _sortNotes();
                _filterNotes();
              });
            },
            child: const Icon(Icons.push_pin),
          ),
        ],
      )
          : FloatingActionButton(
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add),
      ))
          : (binSelecting && binSelectedNoteIds.isNotEmpty
          ? FloatingActionButton(
        onPressed: () async => await _restoreMultipleFromBin(
            binSelectedNoteIds.toList()),
        child: const Icon(Icons.restore),
      )
          : FloatingActionButton(
        onPressed: _toggleBinSelectMode,
        child: Icon(binSelecting ? Icons.close : Icons.select_all),
      )),
    );
  }
}
