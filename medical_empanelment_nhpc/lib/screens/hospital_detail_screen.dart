import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hospital.dart';
import 'pdf_viewer_screen.dart';
import 'report_error_screen.dart';

class HospitalDetailsPage extends StatefulWidget {
  final Hospital hospital;

  const HospitalDetailsPage({super.key, required this.hospital});

  @override
  State<HospitalDetailsPage> createState() => _HospitalDetailsPageState();
}

class _HospitalDetailsPageState extends State<HospitalDetailsPage>
    with TickerProviderStateMixin {
  bool showHindi = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Modern Color Palette (same as list screen)
  static const Color primaryBlue = Color(0xFF2E86AB);
  static const Color successOrange = Color(0xFFF18F01);
  static const Color backgroundGray = Color(0xFFF8F9FA);
  static const Color darkText = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: _buildCompactAppBar(),
      body: ScrollConfiguration(
        behavior: _NoOverscrollBehavior(),
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator();
            return true;
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildCompactHospitalHeader(),
                    const SizedBox(height: 12),
                    _buildCompactLanguageToggle(),
                    const SizedBox(height: 12),
                    _buildCompactContactSection(),
                    const SizedBox(height: 12),
                    _buildCompactDetailsSection(),
                    const SizedBox(height: 12),
                    _buildCompactValiditySection(),
                    const SizedBox(height: 12),
                    _buildCompactLinksSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: ReportErrorFAB(
        onPressed: () {
          Navigator.pushNamed(context, '/reportError');
        },
      ),
    );
  }

  // Simple AppBar
  PreferredSizeWidget _buildCompactAppBar() {
    return AppBar(
      backgroundColor: primaryBlue,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      title: Text(
        showHindi
            ? _cleanText(widget.hospital.Hosp_name_H)
            : _cleanText(widget.hospital.Hosp_name),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Compact Language Toggle
  Widget _buildCompactLanguageToggle() {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => showHindi = !showHindi),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, color: primaryBlue, size: 16),
                const SizedBox(width: 6),
                Text(
                  showHindi ? 'अंग्रेजी में देखें' : 'हिंदी में देखें',
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Compact toggle indicator
                Container(
                  height: 20,
                  width: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: showHindi ? primaryBlue : Colors.grey.shade300,
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        left: showHindi ? 16 : 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          margin: const EdgeInsets.all(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHospitalHeader() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hospital Name
            Text(
              showHindi
                  ? _cleanText(widget.hospital.Hosp_name_H)
                  : _cleanText(widget.hospital.Hosp_name),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Scheme Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.hospital.SCHEME == 'D'
                    ? 'Direct Payment'
                    : 'Indirect Payment',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Address with map launch
            InkWell(
              onTap: _launchMaps,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: primaryBlue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showHindi
                                ? _cleanText(widget.hospital.hosp_add_H)
                                : _cleanText(widget.hospital.hosp_add),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap for directions',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.directions, color: primaryBlue, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactContactSection() {
    return _buildCompactSection(
      title: showHindi ? 'संपर्क जानकारी' : 'Contact Information',
      icon: Icons.contact_phone,
      color: primaryBlue,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hospital.Cont_person.isNotEmpty)
              Expanded(
                child: _buildSideBySideContactItem(
                  icon: Icons.person,
                  label: showHindi ? 'संपर्क व्यक्ति' : 'Contact Person',
                  value: widget.hospital.Cont_person,
                ),
              ),
            if (widget.hospital.Cont_person.isNotEmpty &&
                widget.hospital.Cont_no.isNotEmpty)
              const SizedBox(width: 12),
            if (widget.hospital.Cont_no.isNotEmpty)
              Expanded(
                child: _buildSideBySideContactItem(
                  icon: Icons.phone,
                  label: showHindi ? 'संपर्क नंबर' : 'Contact Number',
                  value: widget.hospital.Cont_no,
                  isClickable: true,
                  onTap: () => _launchPhone(widget.hospital.Cont_no),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSideBySideContactItem(
                icon: Icons.business,
                label: showHindi ? 'अस्पताल आईडी' : 'Hospital ID',
                value: widget.hospital.hosp_id,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSideBySideContactItem(
                icon: Icons.location_city,
                label: showHindi ? 'स्थान कोड' : 'Location Code',
                value: widget.hospital.LOC_CODE,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSideBySideContactItem({
    required IconData icon,
    required String label,
    required String value,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isClickable ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: primaryBlue),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isClickable ? primaryBlue : darkText,
                      decoration: isClickable ? TextDecoration.underline : null,
                    ),
                  ),
                ),
                if (isClickable)
                  Icon(Icons.open_in_new, size: 14, color: primaryBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailsSection() {
    return _buildCompactSection(
      title: showHindi ? 'अतिरिक्त विवरण' : 'Additional Details',
      icon: Icons.info_outline,
      color: primaryBlue,
      children: [
        if ((showHindi ? widget.hospital.Rem_h : widget.hospital.Rem)
            .isNotEmpty)
          _buildCompactDetailRow(
            icon: Icons.note,
            label: showHindi ? 'टिप्पणी' : 'Remarks',
            value:
                showHindi
                    ? _cleanText(widget.hospital.Rem_h)
                    : _cleanText(widget.hospital.Rem),
            maxLines: 5,
          ),
        if (widget.hospital.Hosp_Offer.isNotEmpty)
          _buildCompactDetailRow(
            icon: Icons.local_offer,
            label: showHindi ? 'अस्पताल प्रस्ताव' : 'Hospital Offer',
            value: widget.hospital.Hosp_Offer,
            maxLines: 5,
          ),
      ],
    );
  }

  Widget _buildCompactValiditySection() {
    return _buildCompactSection(
      title: showHindi ? 'वैधता जानकारी' : 'Validity Information',
      icon: Icons.date_range,
      color: primaryBlue,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_arrow, size: 14, color: successOrange),
                      const SizedBox(width: 4),
                      Text(
                        showHindi ? 'से वैध' : 'Valid From',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Text(
                      _formatDate(widget.hospital.valid_from),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stop, size: 14, color: successOrange),
                      const SizedBox(width: 4),
                      Text(
                        showHindi ? 'तक वैध' : 'Valid Until',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Text(
                      _formatDate(widget.hospital.VALID_UPTO),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.hospital.RegValidUptoDt.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.assignment, size: 14, color: successOrange),
                  const SizedBox(width: 4),
                  Text(
                    showHindi ? 'पंजीकरण वैध' : 'Registration Valid Until',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  _formatDate(widget.hospital.RegValidUptoDt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCompactLinksSection() {
    return _buildCompactSection(
      title: showHindi ? 'दस्तावेज़ और लिंक' : 'Documents & Links',
      icon: Icons.link,
      color: primaryBlue,
      children: [
        _buildSimpleDocumentLink(
          icon: Icons.medical_information,
          label:
              showHindi ? 'अनुमोदन आदेश/आवास' : 'Apprv. Order/ Accomodation	',
          url:
              'https://www.nhpc.gov.in/sites/default/files/2023-04/Medical_Guidelines.pdf', // Real URL
          color: Colors.blue.shade700,
        ),
        const Divider(height: 1),
        _buildSimpleDocumentLink(
          icon: Icons.ad_units,
          label:
              showHindi ? 'अनुमोदन आदेश/आवास' : 'Request Authorisation Letter	',
          url:
              'https://www.nhpc.gov.in/sites/default/files/2023-04/Medical_Guidelines.pdf', // Real URL
          color: Colors.blue.shade700,
        ),
        const Divider(height: 1),
        _buildSimpleDocumentLink(
          icon: Icons.health_and_safety,
          label: showHindi ? 'शुल्क' : 'Tariff',
          url:
              'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          color: Colors.blue.shade700,
        ),
        const Divider(height: 1),
        _buildSimpleDocumentLink(
          icon: Icons.policy,
          label: showHindi ? 'सुविधा' : 'Facilitation',
          url: 'assets/hospital_guidelines.pdf', // Real URL
          color: Colors.blue.shade700,
        ),
      ],
    );
  }

  Widget _buildSimpleDocumentLink({
    required IconData icon,
    required String label,
    required String url,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _openPdfViewer(label, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.picture_as_pdf, size: 16, color: color),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdfViewer(String title, String url) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(title: title, pdfUrl: url),
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isClickable ? primaryBlue : darkText,
                        decoration:
                            isClickable ? TextDecoration.underline : null,
                      ),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isClickable)
                Icon(Icons.open_in_new, size: 14, color: primaryBlue),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanText(String text) {
    if (text.isEmpty) return text;
    String cleaned = text.replaceFirst(RegExp(r'^[^\w\u0900-\u097F]+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'[^\w\u0900-\u097F\s]+$'), '');
    return cleaned.trim();
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      DateTime dateTime = DateTime.parse(dateString);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      if (dateString.contains('T')) {
        return dateString.split('T')[0];
      }
      return dateString;
    }
  }

  Future<void> _launchMaps() async {
    final String lat = widget.hospital.latitude;
    final String lng = widget.hospital.longitude;

    if (lat.isNotEmpty && lng.isNotEmpty) {
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open maps');
      }
    } else {
      // Merge hospital name and address for better search accuracy
      final name =
          showHindi
              ? _cleanText(widget.hospital.Hosp_name_H)
              : _cleanText(widget.hospital.Hosp_name);
      final address =
          showHindi
              ? _cleanText(widget.hospital.hosp_add_H)
              : _cleanText(widget.hospital.hosp_add);

      final query = Uri.encodeComponent('$name $address');
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open maps');
      }
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackBar('Could not call $phoneNumber');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Custom ScrollBehavior inline to avoid import issues
class _NoOverscrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
