import "package:flutter/material.dart";
import "package:to_do_app/data/database.dart";
import "package:to_do_app/pages/import_ics_page.dart";
import "package:to_do_app/pages/settings_page.dart";
import "package:to_do_app/pages/sign_in_page.dart";
import "package:provider/provider.dart";
import "package:to_do_app/providers/auth_provider.dart";
import "package:to_do_app/themes/app_colors.dart";

class MyDrawer extends StatefulWidget {
  final VoidCallback onImported;
  final String? filePath;
  final ToDoDataBase db;
  MyDrawer({
    super.key,
    required this.filePath,
    required this.onImported,
    required this.db,
  });

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  Widget _avatar(BuildContext context, AuthProvider auth, bool signedIn) {
    if (!signedIn) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: context.appColors.accentSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 32, color: context.appColors.accent),
      );
    }
    final initial = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.appColors.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        auth.displayName[0].toUpperCase(),
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: context.appColors.onAccent,
        ),
      ),
    );
    if (auth.photoUrl.isEmpty) return initial;
    return ClipOval(
      child: Image.network(
        auth.photoUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => initial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = context.appColors;
    final cs = Theme.of(context).colorScheme;
    final signedIn = auth.isGoogleSignedIn && auth.displayName.isNotEmpty;

    return Drawer(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header — tap to sign in / manage the account
          Material(
            color: cs.secondary,
            child: InkWell(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => SignInPage(
                            onSignIn: () {
                              setState(() {});
                            },
                            db: widget.db,
                            filePath: widget.filePath,
                            onImported: widget.onImported,
                          ),
                    ),
                  ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 12,
                  16,
                  20,
                ),
                child: Row(
                  children: [
                    _avatar(context, auth, signedIn),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signedIn ? auth.displayName : 'Sign In',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            signedIn && auth.email.isNotEmpty
                                ? auth.email
                                : 'Tap to sign in',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 22, color: colors.muted),
                  ],
                ),
              ),
            ),
          ),

          // Primary items
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                _DrawerItem(
                  icon: Icons.settings,
                  title: "Settings",
                  onTap: () async {
                    Navigator.pop(context); // close drawer first

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(db: widget.db),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                _DrawerItem(
                  icon: Icons.download,
                  title: "Import (.ics)",
                  onTap: () async {
                    Navigator.pop(context); // close drawer first

                    // Push Import Page and wait for result
                    final imported = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportICSPage()),
                    );
                    //comes to this line after pop

                    // **DON'T call setState here**
                    // Instead, return the result to TaskPage
                    if (imported == true) {
                      // This can be ignored; TaskPage will handle it
                      widget.onImported();
                    }
                  },
                ),
              ],
            ),
          ),

          const Spacer(),

          // Secondary items, pinned to the bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Divider(height: 1, thickness: 1, color: colors.outline),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                _DrawerItem(
                  icon: Icons.star_rounded,
                  title: "Rate the app",
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                _DrawerItem(
                  icon: Icons.share,
                  title: "Share with friends",
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                _DrawerItem(
                  icon: Icons.mail,
                  title: "Contact the support team",
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One drawer row: amber icon tile + title.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: context.appColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
