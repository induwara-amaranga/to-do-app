import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/outlook_sign.dart';
import 'package:to_do_app/services/sync_problem.dart';

enum _Choice { signInAgain, retry }

/// Tells the user what went wrong with a Google / Outlook / Drive step and
/// what to do about it. A closed sign-in screen only gets a short snackbar;
/// everything else gets a dialog with numbered steps and one button that
/// fixes it: "Sign in again" for permission and expired-sign-in problems,
/// "Try again" for the rest.
///
/// [onRetry] re-runs the step that failed. It is called after a successful
/// "Sign in again" or when the user taps "Try again".
Future<void> showSyncProblem(
  BuildContext context,
  SyncProblem problem, {
  Future<void> Function()? onRetry,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final auth = context.read<AuthProvider>();

  if (problem.kind == SyncProblemKind.cancelled) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('${problem.service.label} sign-in was cancelled.'),
      ),
    );
    return;
  }

  final copy = _copyFor(problem);
  final choice = await showDialog<_Choice>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(copy.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.explanation),
                const SizedBox(height: 12),
                Text(
                  'What to do',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < copy.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${i + 1}. ${copy.steps[i]}'),
                  ),
                if (problem.detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Details: ${problem.detail}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                    ctx,
                    problem.needsSignIn ? _Choice.signInAgain : _Choice.retry,
                  ),
              child: Text(problem.needsSignIn ? 'Sign in again' : 'Try again'),
            ),
          ],
        ),
  );
  if (choice == null) return;

  if (choice == _Choice.retry) {
    await onRetry?.call();
    return;
  }

  final ok = await _reconnect(problem.service, auth);
  if (ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('Signed in to ${problem.service.label} again.')),
    );
    await onRetry?.call();
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Could not sign in to ${problem.service.label}. '
          'Check your connection and try again.',
        ),
      ),
    );
  }
}

/// Signs out and in again so the account screen asks for permissions anew and
/// the saved sign-in is replaced.
Future<bool> _reconnect(SyncService service, AuthProvider auth) async {
  try {
    if (service.isGoogle) {
      await GoogleAuthService.signOut();
      auth.signOutGoogle();
      final user = await GoogleAuthService.ensureSignedIn(auth: auth);
      return user != null && await GoogleAuthService.ensureApisReady();
    }
    await OutlookAuthService.init();
    await OutlookAuthService.signOut();
    auth.signOutOutlook();
    final token = await OutlookAuthService.signIn();
    if (token == null) return false;
    auth.setOutlookSignedIn(true);
    return true;
  } catch (_) {
    return false;
  }
}

class _Copy {
  final String title;
  final String explanation;
  final List<String> steps;
  const _Copy(this.title, this.explanation, this.steps);
}

_Copy _copyFor(SyncProblem p) {
  final name = p.service.label;
  final account = p.service.isGoogle ? 'Google' : 'Microsoft';
  final allow = p.service.isGoogle ? 'Allow' : 'Accept';

  switch (p.kind) {
    case SyncProblemKind.missingPermission:
      return _Copy(
        'Permission needed for $name',
        'You are signed in, but $account has not given this app permission to '
            '${p.service.permissionNeeded}. This happens when the permission '
            'screen was skipped, a box was left unticked, or the app now asks '
            'for something new.',
        [
          'Tap "Sign in again" and choose your account.',
          'On the $account screen, keep every permission ticked and tap '
              '"$allow".',
          'Your tasks stay on this device while you do this.',
        ],
      );
    case SyncProblemKind.expiredSignIn:
      return _Copy(
        'Please sign in to $name again',
        'The saved sign-in is no longer accepted. This happens after a long '
            'time without use, a password change, or when access was removed '
            'in your $account account.',
        [
          'Tap "Sign in again" and choose your account.',
          'Approve the permissions on the $account screen.',
          'Your tasks and saved events stay on this device.',
        ],
      );
    case SyncProblemKind.offline:
      return _Copy(
        'No internet connection',
        'The app could not reach $name. Nothing was lost; saved events are '
            'still shown.',
        [
          'Check that Wi-Fi or mobile data is on.',
          'Tap "Try again".',
        ],
      );
    case SyncProblemKind.cancelled:
    case SyncProblemKind.other:
      return _Copy(
        '$name did not respond as expected',
        'Something went wrong that the app could not identify. Your tasks '
            'are safe.',
        [
          'Tap "Try again".',
          'If it keeps happening, sign out of $account in the app, sign in '
              'again, and send the details below to support.',
        ],
      );
  }
}
