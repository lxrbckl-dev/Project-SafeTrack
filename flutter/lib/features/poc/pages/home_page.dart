import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/herzog_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('THE MARCH PROJECT'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Page header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'POC VALIDATION',
              style: HerzogText.heading(fontSize: 24),
            ),
          ),

          // KPI row
          Row(
            children: [
              _KpiCard(label: 'PASSING', value: '9', color: HerzogColors.successGreen),
              const SizedBox(width: 12),
              _KpiCard(label: 'REMAINING', value: '4', color: HerzogColors.warningAmber),
              const SizedBox(width: 12),
              _KpiCard(label: 'PLATFORMS', value: '5', color: HerzogColors.infoTeal),
            ],
          ),
          const SizedBox(height: 24),

          // Section heading
          Text(
            'INFRASTRUCTURE TESTS',
            style: HerzogText.heading(fontSize: 16, color: HerzogColors.darkGray),
          ),
          const SizedBox(height: 12),

          // Test cards
          _TestCard(
            title: 'GO_ROUTER',
            subtitle: 'Navigation works across platforms',
            icon: Icons.route,
            onTap: () {},
            status: 'PASS',
          ),
          _TestCard(
            title: 'DRIFT DATABASE',
            subtitle: 'SQLite on mobile, WASM on web + Firebase sync',
            icon: Icons.storage,
            onTap: () => context.push('/drift'),
            status: 'PASS',
          ),
          _TestCard(
            title: 'CONNECTIVITY',
            subtitle: 'Online/offline detection',
            icon: Icons.wifi,
            onTap: () => context.push('/connectivity'),
            status: 'PASS',
          ),
          _TestCard(
            title: 'OLLAMA / QWEN 2.5 7B',
            subtitle: 'Local LLM responds via REST API',
            icon: Icons.psychology,
            onTap: () => context.push('/ollama'),
            status: 'PASS',
          ),
          _TestCard(
            title: 'FIREBASE SYNC',
            subtitle: 'Drift → Firestore end-to-end',
            icon: Icons.cloud_sync,
            onTap: () => context.push('/drift'),
            status: 'PASS',
          ),
          _TestCard(
            title: 'HERZOG BRANDING',
            subtitle: 'Oswald + Roboto fonts, color system',
            icon: Icons.palette,
            onTap: () {},
            status: 'TEST',
          ),
          _TestCard(
            title: 'AGENT TEAMS',
            subtitle: 'Multi-agent Claude Code coordination',
            icon: Icons.groups,
            onTap: () {},
            status: 'PENDING',
          ),
          _TestCard(
            title: 'TESTFLIGHT',
            subtitle: 'Waiting on Apple Developer approval',
            icon: Icons.flight_takeoff,
            onTap: () {},
            status: 'WAITING',
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HerzogColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HerzogColors.borderGray),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: HerzogColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(value, style: HerzogText.heading(fontSize: 32, color: color)),
              const SizedBox(height: 4),
              Text(label, style: HerzogText.label()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String status;

  const _TestCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.status,
  });

  Color get _statusColor {
    switch (status) {
      case 'PASS':
        return HerzogColors.successGreen;
      case 'TEST':
        return HerzogColors.warningAmber;
      case 'PENDING':
        return HerzogColors.infoTeal;
      case 'WAITING':
        return HerzogColors.midGray;
      default:
        return HerzogColors.darkGray;
    }
  }

  Color get _statusBg {
    switch (status) {
      case 'PASS':
        return HerzogColors.successLight;
      case 'TEST':
        return HerzogColors.warningLight;
      case 'PENDING':
        return HerzogColors.infoLight;
      case 'WAITING':
        return HerzogColors.lightGray;
      default:
        return HerzogColors.lightGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title — $subtitle. Status: $status',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: HerzogColors.navyBlue, size: 24,
                  semanticLabel: title,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: HerzogText.heading(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: HerzogText.body(color: HerzogColors.midGray, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    status,
                    style: HerzogText.label(color: _statusColor, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
