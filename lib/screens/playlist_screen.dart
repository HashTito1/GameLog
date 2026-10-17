import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../services/firebase_auth_service.dart';
import '../services/igdb_service.dart';
import '../services/user_data_service.dart';
import '../widgets/app_network_image.dart';
import 'game_detail_screen.dart';

/// Square cover collage for a playlist: 2x2 covers, one cover, or a gradient
/// with an icon when the playlist is empty.
class PlaylistCover extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final double size;
  final double radius;

  const PlaylistCover({super.key, required this.playlist, required this.size, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final covers = List<Map<String, dynamic>>.from(playlist['games'] ?? const [])
        .map((g) => (g['gameCoverImage'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .take(4)
        .toList();

    Widget child;
    if (covers.isEmpty) {
      child = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary.withValues(alpha: 0.55), theme.colorScheme.secondary.withValues(alpha: 0.35)],
          ),
        ),
        child: Icon(Icons.queue_music_rounded, size: size * 0.32, color: Colors.white.withValues(alpha: 0.9)),
      );
    } else if (covers.length < 4) {
      child = AppNetworkImage(imageUrl: covers.first, fit: BoxFit.cover, width: size, height: size);
    } else {
      Widget tile(int i) => AppNetworkImage(imageUrl: covers[i], fit: BoxFit.cover, width: size / 2, height: size / 2);
      child = Column(
        children: [
          Expanded(child: Row(children: [Expanded(child: tile(0)), const SizedBox(width: 2), Expanded(child: tile(1))])),
          const SizedBox(height: 2),
          Expanded(child: Row(children: [Expanded(child: tile(2)), const SizedBox(width: 2), Expanded(child: tile(3))])),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Create (no [playlist]) or edit a playlist in a bottom sheet. Returns true
/// when something was saved.
Future<bool> showPlaylistEditor(BuildContext context, {Map<String, dynamic>? playlist}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _PlaylistEditor(playlist: playlist),
  );
  return saved == true;
}

class _PlaylistEditor extends StatefulWidget {
  final Map<String, dynamic>? playlist;
  const _PlaylistEditor({this.playlist});

  @override
  State<_PlaylistEditor> createState() => _PlaylistEditorState();
}

class _PlaylistEditorState extends State<_PlaylistEditor> {
  late final _name = TextEditingController(text: widget.playlist?['name'] ?? '');
  late final _description = TextEditingController(text: widget.playlist?['description'] ?? '');
  late bool _isPublic = widget.playlist?['isPublic'] == true;
  bool _saving = false;

  bool get _editing => widget.playlist != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final me = FirebaseAuthService().currentUser?.uid;
    if (name.isEmpty || me == null) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        final id = widget.playlist!['id'] as String;
        final updated = {
          ...widget.playlist!,
          'name': name,
          'description': _description.text.trim(),
          'isPublic': _isPublic,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
        await FirebaseFirestore.instance.collection('users').doc(me).collection('playlists').doc(id).set(updated);
        widget.playlist!
          ..['name'] = name
          ..['description'] = _description.text.trim()
          ..['isPublic'] = _isPublic;
      } else {
        await UserDataService.createPlaylistWithGames(
          userId: me,
          playlistName: name,
          description: _description.text.trim(),
          isPublic: _isPublic,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the playlist. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_editing ? 'Edit playlist' : 'New playlist', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Cozy weekend games',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            tileColor: Colors.transparent,
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            secondary: Icon(_isPublic ? Icons.public_rounded : Icons.lock_outline_rounded),
            title: Text(_isPublic ? 'Public' : 'Private', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_isPublic ? 'Shown on your profile as a recommendation' : 'Only you can see it'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                    )
                  : Text(_editing ? 'Save' : 'Create playlist'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One playlist: cover, details, privacy, and its games in a grid.
class PlaylistScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;

  /// Your library, offered as quick picks when adding games.
  final List<Map<String, dynamic>> libraryGames;

  const PlaylistScreen({super.key, required this.playlist, this.libraryGames = const []});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final Map<String, dynamic> _playlist = widget.playlist;
  bool _changed = false;

  String get _id => _playlist['id'] as String;
  String? get _me => FirebaseAuthService().currentUser?.uid;
  List<Map<String, dynamic>> get _games => List<Map<String, dynamic>>.from(_playlist['games'] ?? const []);

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _togglePrivacy() async {
    final me = _me;
    if (me == null) return;
    final next = !(_playlist['isPublic'] == true);
    setState(() => _playlist['isPublic'] = next);
    _changed = true;
    try {
      await UserDataService.updatePlaylistPrivacy(me, _id, next);
      if (mounted) _toast(next ? 'Playlist is public — shown on your profile' : 'Playlist is private');
    } catch (e) {
      if (!mounted) return;
      setState(() => _playlist['isPublic'] = !next);
      _toast('Could not change privacy. Try again.');
    }
  }

  Future<void> _edit() async {
    if (await showPlaylistEditor(context, playlist: _playlist)) {
      setState(() => _changed = true);
    }
  }

  Future<void> _delete() async {
    final me = _me;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('"${_playlist['name']}" will be deleted. The games stay in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || me == null) return;
    try {
      await UserDataService.deletePlaylist(userId: me, playlistId: _id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Could not delete the playlist. Try again.');
    }
  }

  Future<void> _removeGame(Map<String, dynamic> game) async {
    final me = _me;
    if (me == null) return;
    final before = _games;
    setState(() => _playlist['games'] = before.where((g) => g['gameId'] != game['gameId']).toList());
    _changed = true;
    try {
      await UserDataService.removeGameFromPlaylist(userId: me, playlistId: _id, gameId: game['gameId']);
      if (mounted) _toast('Removed ${game['gameTitle'] ?? 'game'}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _playlist['games'] = before);
      _toast('Could not remove it. Try again.');
    }
  }

  Future<void> _addGames() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _AddGamesSheet(playlist: _playlist, libraryGames: widget.libraryGames),
    );
    if (added == true) setState(() => _changed = true);
  }

  void _gameActions(Map<String, dynamic> game) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              tileColor: Colors.transparent,
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open game'),
              onTap: () {
                Navigator.pop(sheet);
                _openGame(game);
              },
            ),
            ListTile(
              tileColor: Colors.transparent,
              leading: Icon(Icons.playlist_remove_rounded, color: theme.colorScheme.error),
              title: Text('Remove from playlist', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(sheet);
                _removeGame(game);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openGame(Map<String, dynamic> game) {
    final id = (game['gameId'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final games = _games;
    final isPublic = _playlist['isPublic'] == true;
    final description = (_playlist['description'] ?? '').toString().trim();
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'delete' ? _delete() : _togglePrivacy(),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'privacy', child: Text(isPublic ? 'Make private' : 'Make public')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete playlist', style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlaylistCover(playlist: _playlist, size: 120, radius: 18),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_playlist['name'] ?? 'Untitled').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
                          ],
                          const SizedBox(height: 8),
                          Text('${games.length} ${games.length == 1 ? 'game' : 'games'}', style: TextStyle(color: muted)),
                          const SizedBox(height: 8),
                          ActionChip(
                            avatar: Icon(isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 16),
                            label: Text(isPublic ? 'Public' : 'Private'),
                            onPressed: _togglePrivacy,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addGames,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add games'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
            if (games.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Column(
                    children: [
                      Icon(Icons.library_add_outlined, size: 48, color: muted),
                      const SizedBox(height: 10),
                      Text('No games yet', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text('Tap Add games to start this playlist.', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1 /
                        (4 / 3 +
                            (8 + MediaQuery.textScalerOf(context).scale(13) * 1.3 * 2 + 5) /
                                ((MediaQuery.sizeOf(context).width - 32 - 24) / 3)),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final game = games[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openGame(game),
                        onLongPress: () => _gameActions(game),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 3 / 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppNetworkImage(
                                  imageUrl: (game['gameCoverImage'] ?? '').toString(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (game['gameTitle'] ?? 'Unknown game').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: games.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add games to a playlist: your library first, or search IGDB.
class _AddGamesSheet extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final List<Map<String, dynamic>> libraryGames;

  const _AddGamesSheet({required this.playlist, required this.libraryGames});

  @override
  State<_AddGamesSheet> createState() => _AddGamesSheetState();
}

class _AddGamesSheetState extends State<_AddGamesSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Game> _results = [];
  bool _searching = false;
  bool _added = false;
  final Set<String> _busy = {};

  Set<String> get _inPlaylist => List<Map<String, dynamic>>.from(widget.playlist['games'] ?? const [])
      .map((g) => (g['gameId'] ?? '').toString())
      .toSet();

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = q.trim();
      if (query.isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      try {
        final results = await IGDBService.instance.searchGames(query);
        if (mounted && _controller.text.trim() == query) {
          setState(() {
            _results = results;
            _searching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _add({
    required String id,
    required String title,
    required String cover,
    required String developer,
    required List<String> genres,
  }) async {
    final me = FirebaseAuthService().currentUser?.uid;
    if (me == null || _busy.contains(id) || _inPlaylist.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await UserDataService.addGameToPlaylist(
        userId: me,
        playlistId: widget.playlist['id'],
        gameId: id,
        gameTitle: title,
        gameCoverImage: cover,
        gameDeveloper: developer,
        gameGenres: genres,
      );
      widget.playlist['games'] = [
        ...List<Map<String, dynamic>>.from(widget.playlist['games'] ?? const []),
        {
          'gameId': id,
          'gameTitle': title,
          'gameCoverImage': cover,
          'gameDeveloper': developer,
          'gameGenres': genres,
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        },
      ];
      _added = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add it. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _row({
    required String id,
    required String title,
    required String subtitle,
    required String cover,
    required VoidCallback onAdd,
  }) {
    final theme = Theme.of(context);
    final inPlaylist = _inPlaylist.contains(id);
    return ListTile(
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AppNetworkImage(imageUrl: cover, width: 40, height: 53, fit: BoxFit.cover),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _busy.contains(id)
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : inPlaylist
              ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
              : IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Add',
                ),
      onTap: inPlaylist ? null : onAdd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();
    final library = widget.libraryGames;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _added);
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Expanded(child: Text('Add games', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  TextButton(onPressed: () => Navigator.pop(context, _added), child: const Text('Done')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search any game',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? ListView(
                      children: [
                        if (library.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Text('From your library',
                                style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ),
                        for (final g in library)
                          _row(
                            id: (g['gameId'] ?? '').toString(),
                            title: (g['gameTitle'] ?? 'Unknown game').toString(),
                            subtitle: (g['gameDeveloper'] ?? '').toString(),
                            cover: (g['gameCoverImage'] ?? '').toString(),
                            onAdd: () => _add(
                              id: (g['gameId'] ?? '').toString(),
                              title: (g['gameTitle'] ?? '').toString(),
                              cover: (g['gameCoverImage'] ?? '').toString(),
                              developer: (g['gameDeveloper'] ?? '').toString(),
                              genres: List<String>.from(g['gameGenres'] ?? const []),
                            ),
                          ),
                        if (library.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('Search for a game to add it.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                          ),
                      ],
                    )
                  : _results.isEmpty && !_searching
                      ? Center(
                          child: Text('No games found',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                        )
                      : ListView(
                          children: [
                            for (final game in _results)
                              _row(
                                id: game.id,
                                title: game.title,
                                subtitle: game.releaseDate,
                                cover: game.coverImage,
                                onAdd: () => _add(
                                  id: game.id,
                                  title: game.title,
                                  cover: game.coverImage,
                                  developer: game.developer,
                                  genres: game.genres,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
