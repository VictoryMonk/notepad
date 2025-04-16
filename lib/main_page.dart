import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'widgets/note_editor.dart';
import 'storage/note_storage.dart';
import 'models/note.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'permanent_delete.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  User? _user;
  bool _isSigningIn = false;

  List<Note> notes = [];
  List<Note> filteredNotes = [];
  List<Note> binNotes = [];
  bool isLoading = true;
  bool isSearching = false;
  bool isSelecting = false;
  bool isViewingBin = false;
  bool binSelecting = false;

  Set<String> selectedNoteIds = {};
  Set<String> binSelectedNoteIds = {};

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() => _user = user);
    });
    searchController.addListener(_filterNotes);
    _loadNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _user = FirebaseAuth.instance.currentUser);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  Future<void> _loadNotes() async {
    try {
      final allNotes = await NoteStorage.loadNotes();
      final trashed = await NoteStorage.loadNotes(fromBin: true);
      setState(() {
        notes = allNotes;
        binNotes = trashed;
        _sortNotes();
        filteredNotes = List.from(notes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notes: $e');
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
    final result = await Navigator.push<Note?>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditor(note: note)),
    );
    if (result != null) {
      setState(() {
        final index = notes.indexWhere((n) => n.id == result.id);
        if (index != -1)
          notes[index] = result;
        else
          notes.add(result);
        _sortNotes();
        _filterNotes();
      });
      await NoteStorage.saveNote(result);
    }
  }

  Future<void> _moveToBin(List<String> noteIds) async {
    await Future.wait(noteIds.map((id) => NoteStorage.moveToBin(id)));
    setState(() {
      notes.removeWhere((n) => noteIds.contains(n.id));
      isSelecting = false;
      selectedNoteIds.clear();
    });
    await _loadNotes();
  }

  Future<void> _restoreFromBin(String id) async {
    await NoteStorage.restoreFromBin(id);
    await _loadNotes();
  }

  Future<void> _restoreMultipleFromBin(List<String> ids) async {
    await Future.wait(ids.map((id) => NoteStorage.restoreFromBin(id)));
    setState(() {
      binSelecting = false;
      binSelectedNoteIds.clear();
    });
    await _loadNotes();
  }

  Future<void> _permanentlyDeleteMultiple(List<String> noteIds) async {
    await permanentlyDeleteNotes(noteIds, () async {
      setState(() {
        binNotes.removeWhere((n) => noteIds.contains(n.id));
        binSelectedNoteIds.clear();
        binSelecting = false;
      });
      await _loadNotes();
    });
  }

  void _togglePinNote(Note note) {
    setState(() {
      note.isPinned = !note.isPinned;
      _sortNotes();
      _filterNotes();
    });
    NoteStorage.saveNote(note);
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

  void _handleNoteTap(Note note) {
    if (isViewingBin) {
      if (binSelecting) {
        setState(() {
          if (binSelectedNoteIds.contains(note.id))
            binSelectedNoteIds.remove(note.id);
          else
            binSelectedNoteIds.add(note.id);
        });
      } else {
        _restoreFromBin(note.id);
      }
    } else {
      if (isSelecting) {
        setState(() {
          if (selectedNoteIds.contains(note.id))
            selectedNoteIds.remove(note.id);
          else
            selectedNoteIds.add(note.id);
        });
      } else {
        _openNoteEditor(note: note);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('NoteKeep - Sign In')),
        body: Center(
          child: _isSigningIn
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
            icon: Image.asset('assets/google_logo.png', height: 24),
            label: const Text('Sign in with Google'),
            onPressed: _signInWithGoogle,
          ),
        ),
      );
    }

    final displayNotes = isViewingBin ? binNotes : filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search notes...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
        )
            : Text(isViewingBin ? 'Bin' : 'NoteKeep'),
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
          if (_user!.photoURL != null)
            CircleAvatar(
              backgroundImage: NetworkImage(_user!.photoURL!),
              radius: 16,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_user!.displayName ?? ''),
              accountEmail: Text(_user!.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('All Notes'),
              onTap: () {
                setState(() => isViewingBin = false);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Bin'),
              onTap: () {
                setState(() => isViewingBin = true);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : displayNotes.isEmpty
          ? const Center(child: Text('No notes found.'))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: displayNotes.length,
          itemBuilder: (context, i) {
            final note = displayNotes[i];
            final isSelected = isViewingBin
                ? binSelectedNoteIds.contains(note.id)
                : selectedNoteIds.contains(note.id);
            return GestureDetector(
              onTap: () => _handleNoteTap(note),
              onLongPress: () => isViewingBin
                  ? _toggleBinSelectMode()
                  : _toggleSelectMode(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: note.color.withOpacity(isSelected ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.imagePaths.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(note.imagePaths.first),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (note.title.isNotEmpty)
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          note.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (note.content.isNotEmpty)
                      Text(
                        note.content,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                        if (!isViewingBin)
                          IconButton(
                            icon: Icon(
                              note.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            onPressed: () => _togglePinNote(note),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: isViewingBin
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (binSelecting)
            FloatingActionButton.extended(
              label: const Text("Restore"),
              icon: const Icon(Icons.restore),
              onPressed: () => _restoreMultipleFromBin(
                  binSelectedNoteIds.toList()),
            ),
          const SizedBox(width: 8),
          if (binSelecting)
            FloatingActionButton.extended(
              label: const Text("Delete Permanently"),
              icon: const Icon(Icons.delete_forever),
              backgroundColor: Colors.red,
              onPressed: () => _permanentlyDeleteMultiple(
                  binSelectedNoteIds.toList()),
            ),
        ],
      )
          : isSelecting
          ? FloatingActionButton.extended(
        onPressed: () => _moveToBin(selectedNoteIds.toList()),
        label: const Text("Delete"),
        icon: const Icon(Icons.delete),
      )
          : FloatingActionButton(
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
