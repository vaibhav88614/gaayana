import 'package:flutter/material.dart';

import '../../core/models.dart';
import 'album_art.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    required this.track,
    this.onTap,
    this.onMore,
    this.trailing,
    this.selected = false,
    super.key,
  });

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: AlbumArt(track: track),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.primary : null,
        ),
      ),
      subtitle: Text(
        '${track.artist} • ${track.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          (onMore == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: onMore,
                )),
    );
  }
}
