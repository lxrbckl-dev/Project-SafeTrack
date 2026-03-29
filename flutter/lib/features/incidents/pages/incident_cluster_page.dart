import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/incident_link_repository.dart';

/// Cluster view showing groups of linked incidents with common threads.
///
/// Route: /incidents/clusters
///
/// Each cluster card displays the incidents in that cluster and the most
/// common similarity types (threads) that connect them.
class IncidentClusterPage extends StatefulWidget {
  const IncidentClusterPage({super.key});

  @override
  State<IncidentClusterPage> createState() => _IncidentClusterPageState();
}

class _IncidentClusterPageState extends State<IncidentClusterPage> {
  late final IncidentLinkRepository _repo;

  List<IncidentCluster> _clusters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = IncidentLinkRepository(context.read<AuthService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clusters = await _repo.getClusters();
      if (mounted) {
        setState(() {
          _clusters = clusters;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INCIDENT CLUSTERS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/incidents'),
          tooltip: 'Back to incidents',
        ),
        actions: [
          Semantics(
            label: 'Refresh clusters',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _clusters.isEmpty
          ? _buildEmpty()
          : _buildClusterList(),
    );
  }

  Widget _buildError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: HerzogColors.errorRed,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load clusters',
            style: HerzogText.heading(
              fontSize: 18,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: HerzogColors.smoke.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Text(
              'No clusters yet',
              style: HerzogText.heading(
                fontSize: 22,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            );
          }),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Text(
              'Link incidents from an incident\'s Recurrence tab to build clusters.',
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
              textAlign: TextAlign.center,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClusterList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clusters.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildClusterCard(_clusters[index], index + 1),
        );
      },
    );
  }

  Widget _buildClusterCard(IncidentCluster cluster, int clusterNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Sort threads by count descending for display.
    final threads = [...cluster.commonThreads]
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cluster header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: HerzogColors.navyBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$clusterNumber',
                      style: HerzogText.heading(
                        fontSize: 16,
                        color: HerzogColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cluster $clusterNumber',
                        style: HerzogText.heading(
                          fontSize: 16,
                          color: isDark ? Colors.white : HerzogColors.richBlack,
                        ),
                      ),
                      Text(
                        '${cluster.incidents.length} incident${cluster.incidents.length == 1 ? '' : 's'}',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: isDark ? Colors.white : HerzogColors.midGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Common threads
            if (threads.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'COMMON THREADS',
                style: HerzogText.label(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : HerzogColors.midGray,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: threads
                    .map(
                      (t) => Semantics(
                        label: '${t.similarityType}: ${t.count} occurrences',
                        child: Chip(
                          label: Text(
                            '${t.similarityType} (${t.count})',
                            style: HerzogText.label(
                              fontSize: 11,
                              color: HerzogColors.navyBlue,
                            ),
                          ),
                          backgroundColor: HerzogColors.navyBlue.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: HerzogColors.navyBlue.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            // Incidents in this cluster
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'INCIDENTS',
              style: HerzogText.label(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cluster.incidents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final inc = cluster.incidents[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.go('/incidents/${inc.id}'),
                  child: Semantics(
                    label:
                        'Incident ${inc.id}: ${inc.type} at ${inc.location}, status ${inc.status}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? HerzogDarkColors.surfaceVariant : HerzogColors.lightGray,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? HerzogDarkColors.inputBorder : HerzogColors.borderGray),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: HerzogColors.navyBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${inc.id}  •  ${inc.type}',
                                  style: HerzogText.body(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : HerzogColors.richBlack,
                                  ),
                                ),
                                Text(
                                  '${inc.location}  •  ${inc.division}',
                                  style: HerzogText.body(
                                    fontSize: 11,
                                    color: isDark ? Colors.white : HerzogColors.midGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _statusChip(inc.status),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'closed':
        bg = HerzogColors.successLight;
        fg = HerzogColors.successGreen;
        break;
      case 'under investigation':
      case 'investigation complete':
        bg = HerzogColors.infoLight;
        fg = HerzogColors.infoTeal;
        break;
      case 'capa assigned':
      case 'capa in progress':
        bg = HerzogColors.warningLight;
        fg = HerzogColors.warningAmber;
        break;
      case 'reported':
        bg = HerzogColors.lightGray;
        fg = HerzogColors.darkGray;
        break;
      default:
        bg = HerzogColors.lightGray;
        fg = HerzogColors.midGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status, style: HerzogText.label(fontSize: 10, color: fg)),
    );
  }
}
