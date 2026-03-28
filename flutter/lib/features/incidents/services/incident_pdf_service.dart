import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../audit_log/data/audit_log_repository.dart';
import '../../auth/data/role.dart';
import '../../capas/data/capa_repository.dart';
import '../../investigations/data/investigation_repository.dart';
import '../data/incident_repository.dart';

/// Generates a branded PDF report for an incident with all related data.
///
/// Sections:
///  - Header with SafeTrack branding
///  - Incident summary (type, date, location, severity, description, actions)
///  - OSHA determination (result + justification)
///  - Railroad notification status
///  - Injured person details (RBAC-gated: Safety Coordinator+ only)
///  - Investigation summary (5-Why, contributing factors, witness statements)
///  - CAPAs (status, assignee, due date, completion, verification)
///  - Audit trail summary (last 20 entries)
class IncidentPdfService {
  // --- Herzog brand colors for PDF ---
  static const _gold = PdfColor.fromInt(0xFFFFD100);
  static const _richBlack = PdfColor.fromInt(0xFF000000);
  static const _navyBlue = PdfColor.fromInt(0xFF1E3A5F);
  static const _darkGray = PdfColor.fromInt(0xFF58595B);
  static const _midGray = PdfColor.fromInt(0xFF6D6E71);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _successGreen = PdfColor.fromInt(0xFF1E6B38);
  static const _errorRed = PdfColor.fromInt(0xFFAB2D24);
  static const _warningAmber = PdfColor.fromInt(0xFF8A5700);

  /// Generates the full incident report PDF document.
  ///
  /// [incident] — the incident to report on.
  /// [investigation] — linked investigation, if any.
  /// [capas] — CAPAs associated with this incident.
  /// [auditEntries] — recent audit log entries for this incident.
  /// [userRole] — the current user's role, used for RBAC gating of medical data.
  static Future<pw.Document> generateReport({
    required Incident incident,
    Investigation? investigation,
    List<CAPA> capas = const [],
    List<AuditLogEntry> auditEntries = const [],
    required Role userRole,
  }) async {
    final pdf = pw.Document(
      title: 'Incident Report #${incident.id}',
      author: 'SafeTrack by Herzog',
      creator: 'SafeTrack PDF Export',
    );

    final canSeeMedical = userRole.isAtLeast(Role.safetyCoordinator);
    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');
    final dateOnlyFormat = DateFormat('MM/dd/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPageHeader(incident, context),
        footer: (context) => _buildPageFooter(context),
        build: (context) => [
          // --- Incident Summary ---
          _sectionHeading('INCIDENT SUMMARY'),
          _goldAccentBar(),
          pw.SizedBox(height: 8),
          _keyValueTable([
            _kvRow('Incident ID', '#${incident.id ?? "N/A"}'),
            _kvRow('Type', incident.type),
            _kvRow(
              'Date',
              incident.date != null
                  ? dateFormat.format(incident.date!)
                  : 'Not set',
            ),
            _kvRow('Location', incident.location),
            if (incident.latitude != 0 || incident.longitude != 0)
              _kvRow(
                'Coordinates',
                '${incident.latitude.toStringAsFixed(6)}, '
                    '${incident.longitude.toStringAsFixed(6)}',
              ),
            _kvRow('Division', incident.division),
            _kvRow('Project / Job Site', incident.projectJobSite),
            _kvRow('Severity', incident.severity),
            _kvRow('Potential Severity', incident.potentialSeverity),
            _kvRow('Status', incident.status),
            _kvRow('Shift', incident.shift),
            _kvRow('Weather', incident.weather),
            _kvRow('Completion', '${incident.completionPercent}%'),
          ]),
          pw.SizedBox(height: 12),

          // Description
          _labelText('DESCRIPTION'),
          pw.SizedBox(height: 4),
          _bodyText(
            incident.description.isNotEmpty
                ? incident.description
                : 'No description provided.',
          ),
          pw.SizedBox(height: 8),

          _labelText('IMMEDIATE ACTIONS TAKEN'),
          pw.SizedBox(height: 4),
          _bodyText(
            incident.immediateActions.isNotEmpty
                ? incident.immediateActions
                : 'None recorded.',
          ),
          pw.SizedBox(height: 16),

          // --- OSHA Determination ---
          _sectionHeading('OSHA DETERMINATION'),
          _goldAccentBar(),
          pw.SizedBox(height: 8),
          _keyValueTable([
            _kvRow(
              'Recordable',
              incident.isOshaRecordable == null
                  ? 'Not determined'
                  : incident.isOshaRecordable!
                  ? 'Yes'
                  : 'No',
            ),
            _kvRow(
              'DART Case',
              incident.isDart == null
                  ? 'Not determined'
                  : incident.isDart!
                  ? 'Yes'
                  : 'No',
            ),
            if (incident.oshaOverrideJustification.isNotEmpty)
              _kvRow(
                'Override Justification',
                incident.oshaOverrideJustification,
              ),
          ]),
          pw.SizedBox(height: 16),

          // --- Railroad Notification ---
          if (incident.isRailroadProperty) ...[
            _sectionHeading('RAILROAD NOTIFICATION'),
            _goldAccentBar(),
            pw.SizedBox(height: 8),
            _keyValueTable([
              _kvRow('Railroad Client', incident.railroadClient),
              _kvRow(
                'Client Notified',
                incident.railroadNotified ? 'Yes' : 'No',
              ),
              if (incident.railroadNotified) ...[
                _kvRow(
                  'Notification Method',
                  incident.railroadNotificationMethod,
                ),
                if (incident.railroadNotificationDate != null)
                  _kvRow(
                    'Notification Date',
                    dateFormat.format(incident.railroadNotificationDate!),
                  ),
              ],
              if (incident.railroadNotificationOverdue)
                _kvRow('Status', 'OVERDUE'),
            ]),
            pw.SizedBox(height: 16),
          ],

          // --- Injured Persons ---
          if (incident.injuredPersons.isNotEmpty) ...[
            // RBAC note: the section heading and basic identity fields (name,
            // jobTitle, division) are visible to ALL roles — they are NOT
            // considered restricted PII.  Only medical fields (injuryType,
            // bodyPart, treatmentType, returnToWorkStatus) are restricted to
            // Safety Coordinator and above per the RBAC rubric.
            _sectionHeading('INJURED PERSONS'),
            _goldAccentBar(),
            pw.SizedBox(height: 8),
            ...incident.injuredPersons.asMap().entries.map((entry) {
              final idx = entry.key;
              final person = entry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelText('Person ${idx + 1}'),
                    pw.SizedBox(height: 4),
                    _keyValueTable([
                      _kvRow('Name', person.name),
                      _kvRow('Job Title', person.jobTitle),
                      _kvRow('Division', person.division),
                      _kvRow(
                        'Injury Type',
                        canSeeMedical ? person.injuryType : '[RESTRICTED]',
                      ),
                      _kvRow(
                        'Body Part',
                        canSeeMedical
                            ? '${person.bodyPart} (${person.bodyPartSide})'
                            : '[RESTRICTED]',
                      ),
                      _kvRow(
                        'Treatment Type',
                        canSeeMedical ? person.treatmentType : '[RESTRICTED]',
                      ),
                      _kvRow(
                        'Return to Work',
                        canSeeMedical
                            ? person.returnToWorkStatus
                            : '[RESTRICTED]',
                      ),
                    ]),
                  ],
                ),
              );
            }),
            if (!canSeeMedical)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: _lightGray,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: _bodyText(
                  'Medical details restricted to Safety Coordinator and above.',
                  color: _midGray,
                ),
              ),
            pw.SizedBox(height: 16),
          ],

          // --- Investigation Summary ---
          _sectionHeading('INVESTIGATION'),
          _goldAccentBar(),
          pw.SizedBox(height: 8),
          if (investigation != null) ...[
            _keyValueTable([
              _kvRow('Investigation ID', '#${investigation.id}'),
              _kvRow('Status', investigation.status),
              _kvRow('Lead Investigator', investigation.leadInvestigatorId),
              _kvRow('Team Members', investigation.teamMembers),
              if (investigation.targetCompletionDate != null)
                _kvRow(
                  'Target Completion',
                  dateOnlyFormat.format(investigation.targetCompletionDate!),
                ),
              if (investigation.actualCompletionDate != null)
                _kvRow(
                  'Actual Completion',
                  dateOnlyFormat.format(investigation.actualCompletionDate!),
                ),
              if (investigation.isOverdue)
                _kvRow(
                  'Overdue',
                  'Yes (Level ${investigation.overdueEscalationLevel})',
                ),
              if (investigation.reviewedBy.isNotEmpty)
                _kvRow('Reviewed By', investigation.reviewedBy),
              if (investigation.reviewComments.isNotEmpty)
                _kvRow('Review Comments', investigation.reviewComments),
            ]),
            pw.SizedBox(height: 12),

            // 5-Why Chain
            if (investigation.fiveWhys.isNotEmpty) ...[
              _labelText('5-WHY ROOT CAUSE ANALYSIS'),
              pw.SizedBox(height: 4),
              ..._buildFiveWhyChain(investigation.fiveWhys),
              pw.SizedBox(height: 12),
            ],

            // Contributing Factors
            if (investigation.contributingFactors.isNotEmpty) ...[
              _labelText('CONTRIBUTING FACTORS'),
              pw.SizedBox(height: 4),
              _buildFactorsTable(investigation.contributingFactors),
              pw.SizedBox(height: 12),
            ],

            // Witness Statements
            if (investigation.witnessStatements.isNotEmpty) ...[
              _labelText('WITNESS STATEMENTS'),
              pw.SizedBox(height: 4),
              ...investigation.witnessStatements.map(
                (w) => _buildWitnessBlock(w, dateOnlyFormat),
              ),
              pw.SizedBox(height: 12),
            ],
          ] else
            _bodyText('No investigation linked to this incident.'),
          pw.SizedBox(height: 16),

          // --- CAPAs ---
          _sectionHeading('CORRECTIVE & PREVENTIVE ACTIONS (CAPAs)'),
          _goldAccentBar(),
          pw.SizedBox(height: 8),
          if (capas.isNotEmpty)
            _buildCapaTable(capas, dateOnlyFormat)
          else
            _bodyText('No CAPAs associated with this incident.'),
          pw.SizedBox(height: 16),

          // --- Audit Trail ---
          _sectionHeading('AUDIT TRAIL'),
          _goldAccentBar(),
          pw.SizedBox(height: 8),
          if (auditEntries.isNotEmpty)
            _buildAuditTable(auditEntries, dateFormat)
          else
            _bodyText('No audit trail entries available.'),
        ],
      ),
    );

    return pdf;
  }

  // ===== Page Header & Footer =====

  static pw.Widget _buildPageHeader(Incident incident, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SAFETRACK',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 22,
                      color: _navyBlue,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.Text(
                    'by Herzog',
                    style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 10,
                      color: _midGray,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INCIDENT REPORT',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 16,
                      color: _richBlack,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Generated: ${DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 9,
                      color: _midGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          // Gold accent bar under header
          pw.Container(height: 3, color: _gold),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Column(
        children: [
          pw.Container(height: 1, color: _gold),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SafeTrack by Herzog - Confidential',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 8,
                  color: _midGray,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 8,
                  color: _midGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Section Building Helpers =====

  /// Section heading styled like Oswald headings (bold, uppercase).
  static pw.Widget _sectionHeading(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 14,
        color: _navyBlue,
        letterSpacing: 1.2,
      ),
    );
  }

  /// Gold accent bar used under section headings.
  static pw.Widget _goldAccentBar() {
    return pw.Container(
      height: 2,
      width: double.infinity,
      color: _gold,
      margin: const pw.EdgeInsets.only(top: 2),
    );
  }

  /// Small label text (e.g. sub-section headers).
  static pw.Widget _labelText(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 10,
        color: _midGray,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Body text.
  static pw.Widget _bodyText(String text, {PdfColor color = _darkGray}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 10,
        color: color,
      ),
    );
  }

  /// Builds a two-column key-value table from [rows].
  static pw.Widget _keyValueTable(List<pw.TableRow> rows) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(150),
        1: const pw.FlexColumnWidth(),
      },
      children: rows,
    );
  }

  /// A single key-value row for the table.
  static pw.TableRow _kvRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 9,
              color: _midGray,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 10,
              color: _darkGray,
            ),
          ),
        ),
      ],
    );
  }

  // ===== Investigation Section Helpers =====

  /// Renders the 5-Why chain as numbered question/answer pairs.
  static List<pw.Widget> _buildFiveWhyChain(List<FiveWhy> whys) {
    final sorted = [...whys]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted.map((w) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Why #${w.level}: ${w.question}',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 10,
                color: _navyBlue,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Answer: ${w.answer}',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 10,
                color: _darkGray,
              ),
            ),
            if (w.evidence.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Evidence: ${w.evidence}',
                style: pw.TextStyle(
                  font: pw.Font.helveticaOblique(),
                  fontSize: 9,
                  color: _midGray,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  /// Renders contributing factors as a table, highlighting the primary factor.
  static pw.Widget _buildFactorsTable(List<ContributingFactor> factors) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D3D4)),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(60),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyBlue),
          children: [
            _tableHeader('Type'),
            _tableHeader('Description'),
            _tableHeader('Primary'),
          ],
        ),
        // Data rows
        ...factors.map((f) {
          final bgColor = f.isPrimary
              ? const PdfColor.fromInt(0xFFFFF3CD)
              : _white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: [
              _tableCell(f.factorType),
              _tableCell(f.factorDescription),
              _tableCell(f.isPrimary ? 'YES' : 'No'),
            ],
          );
        }),
      ],
    );
  }

  /// Renders a single witness statement block.
  static pw.Widget _buildWitnessBlock(
    WitnessStatement w,
    DateFormat dateFormat,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD1D3D4)),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${w.witnessName} — ${w.witnessTitle}',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 10,
              color: _richBlack,
            ),
          ),
          if (w.witnessEmployer.isNotEmpty)
            pw.Text(
              'Employer: ${w.witnessEmployer}',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 9,
                color: _midGray,
              ),
            ),
          if (w.collectionDate != null)
            pw.Text(
              'Collected: ${dateFormat.format(w.collectionDate!)} by ${w.collectorName}',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 9,
                color: _midGray,
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            w.statementText.isNotEmpty
                ? w.statementText
                : 'No statement text recorded.',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 10,
              color: _darkGray,
            ),
          ),
        ],
      ),
    );
  }

  // ===== CAPA Section =====

  /// Renders CAPAs in a structured table.
  static pw.Widget _buildCapaTable(List<CAPA> capas, DateFormat dateFormat) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D3D4)),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(65),
        5: const pw.FixedColumnWidth(65),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyBlue),
          children: [
            _tableHeader('ID'),
            _tableHeader('Description'),
            _tableHeader('Status'),
            _tableHeader('Assignee'),
            _tableHeader('Due'),
            _tableHeader('Verified'),
          ],
        ),
        ...capas.map((c) {
          PdfColor statusColor = _darkGray;
          if (c.status == 'Verified Effective') statusColor = _successGreen;
          if (c.status == 'Overdue' || c.isOverdue) statusColor = _errorRed;
          if (c.status == 'Open') statusColor = _warningAmber;

          return pw.TableRow(
            children: [
              _tableCell('#${c.id}'),
              _tableCellWrap(c.description),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  c.status,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 8,
                    color: statusColor,
                  ),
                ),
              ),
              _tableCell(c.assignedToUserId),
              _tableCell(
                c.dueDate != null ? dateFormat.format(c.dueDate!) : '-',
              ),
              _tableCell(
                c.verificationDate != null
                    ? dateFormat.format(c.verificationDate!)
                    : '-',
              ),
            ],
          );
        }),
      ],
    );
  }

  // ===== Audit Trail Section =====

  /// Renders the last N audit entries in a compact table.
  static pw.Widget _buildAuditTable(
    List<AuditLogEntry> entries,
    DateFormat dateFormat,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D3D4)),
      columnWidths: {
        0: const pw.FixedColumnWidth(110),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyBlue),
          children: [
            _tableHeader('Timestamp'),
            _tableHeader('Action'),
            _tableHeader('User'),
            _tableHeader('Notes'),
          ],
        ),
        ...entries.map(
          (e) => pw.TableRow(
            children: [
              _tableCell(dateFormat.format(e.timestamp)),
              _tableCell(e.actionDisplay),
              _tableCell(e.userId),
              _tableCellWrap(e.notes),
            ],
          ),
        ),
      ],
    );
  }

  // ===== Generic Table Helpers =====

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 8,
          color: _white,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text.isNotEmpty ? text : '-',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8,
          color: _darkGray,
        ),
      ),
    );
  }

  static pw.Widget _tableCellWrap(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text.isNotEmpty ? text : '-',
        style: pw.TextStyle(
          font: pw.Font.helvetica(),
          fontSize: 8,
          color: _darkGray,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
