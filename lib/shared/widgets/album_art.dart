import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models.dart';
import 'audio_query_artwork.dart';

/// Resolves a [Track]'s album-art into an [ImageProvider].
ImageProvider? trackArtwork(Track? t, {int size = 256}) {
  final uri = t?.albumArtUri;
  if (uri == null) return null;
  if (uri.startsWith('audioquery://')) {
    final id = int.tryParse(uri.substring('audioquery://'.length));
    if (id == null) return null;
    return AudioQueryArtwork(id, size: size);
  }
  if (uri.startsWith('http')) return NetworkImage(uri);
  if (uri.startsWith('file://')) {
    return FileImage(File(uri.replaceFirst('file://', '')));
  }
  return null;
}

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    required this.track,
    this.size = 56,
    this.heroTag,
    super.key,
  });
  final Track? track;
  final double size;

  /// If non-null, wraps the art in a [Hero] for smooth shared-element
  /// transitions between mini-player and now-playing.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = trackArtwork(track, size: (size * 2).round());
    final placeholder = Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.music_note,
          size: size * 0.5, color: scheme.onPrimaryContainer),
    );
    Widget art = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: SizedBox(
        width: size,
        height: size,
        child: img != null
            ? Image(
                image: img,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => placeholder,
              )
            : placeholder,
      ),
    );
    if (heroTag != null) {
      art = Hero(tag: heroTag!, child: art);
    }
    return art;
  }
}
