import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// ImageProvider that lazily fetches MediaStore artwork bytes for an audio id.
///
/// Used for `audioquery://{id}` URIs produced by `LocalFileSource`.
@immutable
class AudioQueryArtwork extends ImageProvider<AudioQueryArtwork> {
  const AudioQueryArtwork(this.audioId, {this.size = 256, this.scale = 1.0});

  final int audioId;
  final int size;
  final double scale;

  static final OnAudioQuery _q = OnAudioQuery();

  @override
  Future<AudioQueryArtwork> obtainKey(ImageConfiguration cfg) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      AudioQueryArtwork key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: 'AudioQueryArtwork($audioId)',
    );
  }

  Future<ui.Codec> _load(
      AudioQueryArtwork key, ImageDecoderCallback decode) async {
    final Uint8List? bytes = await _q.queryArtwork(
      key.audioId,
      ArtworkType.AUDIO,
      size: key.size,
      quality: 90,
    );
    if (bytes == null || bytes.isEmpty) {
      throw Exception('No artwork for audio id ${key.audioId}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is AudioQueryArtwork &&
      other.audioId == audioId &&
      other.size == size &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(audioId, size, scale);
}
