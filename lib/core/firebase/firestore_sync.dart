import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// Cloud-sync layer for playlists & favorites.
/// Each user gets their own subtree: `/users/{uid}/playlists`, `/users/{uid}/favorites`.
/// Falls back to no-op when the user is signed out — local DB remains the
/// source of truth.
class FirestoreSync {
  FirestoreSync({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _userColl(String name) {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection(name);
  }

  Future<void> pushPlaylist(Playlist p) async {
    final c = _userColl('playlists');
    if (c == null) return;
    await c.doc(p.id).set({
      'name': p.name,
      'coverUri': p.coverUri,
      'trackIds': p.trackIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlaylist(String id) async {
    await _userColl('playlists')?.doc(id).delete();
  }

  Future<void> setFavorite(String trackGlobalId, bool value) async {
    final c = _userColl('favorites');
    if (c == null) return;
    if (value) {
      await c.doc(trackGlobalId).set({
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await c.doc(trackGlobalId).delete();
    }
  }

  Stream<List<String>> favoriteIds() {
    final c = _userColl('favorites');
    if (c == null) return const Stream.empty();
    return c.snapshots().map((s) => s.docs.map((d) => d.id).toList());
  }
}
