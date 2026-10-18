import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Eva, the developer's miniature schnauzer: the assistant's face in the chat, the tab bar and on the unlock screen.
const evaAsset = 'assets/icons/icon_chat.png';

class EvaAvatar extends StatelessWidget {
  const EvaAvatar({super.key, this.size = 32, this.semanticLabel});
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Image.asset(evaAsset,
            width: size, height: size, fit: BoxFit.cover, semanticLabel: semanticLabel, excludeFromSemantics: semanticLabel == null),
      );
}

IconData avatarIcon(AvatarKind kind) => switch (kind) {
      AvatarKind.woman => Icons.face_3,
      AvatarKind.man => Icons.face_6,
      AvatarKind.neutral => Icons.face,
    };

/// Background colours offered in Settings (ARGB), dark enough for a white icon.
const avatarColors = [0xFF2E7D32, 0xFF00796B, 0xFF1565C0, 0xFF3949AB, 0xFF7B1FA2, 0xFFC2185B, 0xFFD84315, 0xFF5D4037, 0xFF455A64];

String avatarKindName(AppLocalizations l, AvatarKind kind) => switch (kind) {
      AvatarKind.woman => l.avatarWoman,
      AvatarKind.man => l.avatarMan,
      AvatarKind.neutral => l.avatarNeutral,
    };

/// Woman · Man · Neutral (they/them), each drawn as it would look; the chosen one ringed.
class AvatarKindPicker extends StatelessWidget {
  const AvatarKindPicker({super.key, required this.selected, required this.onSelected, this.color});
  final AvatarKind? selected;
  final ValueChanged<AvatarKind> onSelected;
  final int? color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return Row(children: [
      for (final kind in AvatarKind.values)
        Expanded(
          child: Semantics(
            button: true,
            selected: kind == selected,
            label: avatarKindName(l, kind),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(kind),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kind == selected ? c.primary : Colors.transparent, width: 3)),
                    child: UserAvatar(radius: 26, avatar: (kind: kind, color: color, photo: null)),
                  ),
                  const SizedBox(height: 6),
                  Text(avatarKindName(l, kind),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: kind == selected ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// The user's picture: their photo, else the icon they chose on its colour.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.radius = 20, this.avatar});
  final double radius;

  /// Shown instead of the saved one (a preview while choosing).
  final Avatar? avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Avatar a = avatar ?? ref.watch(avatarProvider);
    final bg = a.color == null ? context.colors.primary : Color(a.color!);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        foregroundImage: a.photo == null ? null : FileImage(a.photo!),
        child: Icon(avatarIcon(a.kind), size: radius * 1.3,
            color: ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87),
      ),
    );
  }
}
