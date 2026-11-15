import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';

/// Loads a screen's data outside `build()`.
///
/// The request starts when the screen is first shown and again only when the
/// active cluster, the namespace, the connection state or [loadKey] changes,
/// or when [reload] is called (pull-to-refresh, a refresh button, after an
/// edit). Rebuilds for any other reason reuse [dataFuture].
mixin ClusterDataLoader<W extends StatefulWidget, T> on State<W> {
  /// The current request, or null while disconnected.
  Future<T>? dataFuture;
  Object? _loadedKey;

  /// Starts the request for [clusterState].
  Future<T> load(ClusterState clusterState);

  /// By default nothing is requested while disconnected (outside demo mode),
  /// so no request fails unobserved behind a "disconnected" view.
  bool canLoad(ClusterState clusterState) => clusterState.isLiveConnected || clusterState.isDemo;

  /// Another input whose change should reload the data.
  Object? get loadKey => null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clusterState = Provider.of<ClusterState>(context);
    final allowed = canLoad(clusterState);
    final key = (clusterState.client, clusterState.currentNamespace, allowed, loadKey);
    if (key == _loadedKey) return;
    _loadedKey = key;
    dataFuture = allowed ? load(clusterState) : null;
  }

  /// Starts a new request. The returned future completes (never with an
  /// error) when it finishes, which suits `RefreshIndicator.onRefresh`.
  Future<void> reload() {
    if (!mounted) return Future.value();
    final clusterState = context.read<ClusterState>();
    final future = canLoad(clusterState) ? load(clusterState) : null;
    setState(() => dataFuture = future);
    return future == null ? Future.value() : future.then<void>((_) {}, onError: (_) {});
  }
}
