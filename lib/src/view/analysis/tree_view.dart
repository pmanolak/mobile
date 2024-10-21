import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/opening_service.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/pgn.dart';

const kOpeningHeaderHeight = 32.0;

class AnalysisTreeView extends ConsumerWidget {
  const AnalysisTreeView(
    this.pgn,
    this.options,
    this.displayMode,
  );

  final String pgn;
  final AnalysisOptions options;
  final Orientation displayMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(pgn, options);

    final root = ref.watch(ctrlProvider.select((value) => value.root));
    final currentPath =
        ref.watch(ctrlProvider.select((value) => value.currentPath));
    final broadcastLivePath =
        ref.watch(ctrlProvider.select((value) => value.broadcastLivePath));
    final pgnRootComments =
        ref.watch(ctrlProvider.select((value) => value.pgnRootComments));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (kOpeningAllowedVariants.contains(options.variant))
          _OpeningHeader(
            ctrlProvider,
            displayMode: displayMode,
          ),
        DebouncedPgnTreeView(
          root: root,
          currentPath: currentPath,
          broadcastLivePath: broadcastLivePath,
          pgnRootComments: pgnRootComments,
          notifier: ref.read(ctrlProvider.notifier),
        ),
      ],
    );
  }
}

class _OpeningHeader extends ConsumerWidget {
  const _OpeningHeader(this.ctrlProvider, {required this.displayMode});

  final AnalysisControllerProvider ctrlProvider;
  final Orientation displayMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRootNode = ref.watch(
      ctrlProvider.select((s) => s.currentNode.isRoot),
    );
    final nodeOpening =
        ref.watch(ctrlProvider.select((s) => s.currentNode.opening));
    final branchOpening =
        ref.watch(ctrlProvider.select((s) => s.currentBranchOpening));
    final contextOpening =
        ref.watch(ctrlProvider.select((s) => s.contextOpening));
    final opening = isRootNode
        ? LightOpening(
            eco: '',
            name: context.l10n.startPosition,
          )
        : nodeOpening ?? branchOpening ?? contextOpening;

    return opening != null
        ? Container(
            height: kOpeningHeaderHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  opening.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
