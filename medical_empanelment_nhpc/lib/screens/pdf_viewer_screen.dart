import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PDFViewerScreen({super.key, required this.pdfUrl, required this.title});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  bool isLoading = true;
  bool isDownloading = false;
  String? localPdfPath;
  int currentPage = 0;
  int totalPages = 0;
  String errorMessage = '';

  // Modern Color Palette
  static const Color primaryBlue = Color(0xFF2E86AB);
  static const Color backgroundGray = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      if (widget.pdfUrl.startsWith('assets/')) {
        // Handle asset PDF
        final bytes = await rootBundle.load(widget.pdfUrl);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.pdfUrl.split('/').last}');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

        if (!mounted) return;
        setState(() {
          localPdfPath = file.path;
          isLoading = false;
        });
      } else {
        // Handle network PDF (existing logic)
        final directory = await getTemporaryDirectory();
        final fileName = widget.pdfUrl.split('/').last;
        final file = File('${directory.path}/$fileName');

        if (await file.exists()) {
          if (!mounted) return;
          setState(() {
            localPdfPath = file.path;
            isLoading = false;
          });
        } else {
          await _downloadPdf(widget.pdfUrl, file.path);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load PDF: $e';
      });
    }
  }

  Future<void> _downloadPdf(String url, String savePath) async {
    try {
      final dio = Dio();
      await dio.download(url, savePath);

      setState(() {
        localPdfPath = savePath;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to download PDF: $e';
      });
    }
  }

  Future<void> _downloadToDevice() async {
    setState(() => isDownloading = true);

    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showSnackBar('Storage permission denied');
        setState(() => isDownloading = false);
        return;
      }

      // Get downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        _showSnackBar('Could not access downloads folder');
        setState(() => isDownloading = false);
        return;
      }

      final fileName =
          '${widget.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf';
      final downloadPath = '${downloadsDir.path}/$fileName';

      // Copy file to downloads
      if (localPdfPath != null) {
        final sourceFile = File(localPdfPath!);
        await sourceFile.copy(downloadPath);

        _showSnackBar('PDF downloaded to Downloads folder');
      } else {
        // Download directly if not cached
        final dio = Dio();
        await dio.download(widget.pdfUrl, downloadPath);
        _showSnackBar('PDF downloaded successfully');
      }
    } catch (e) {
      _showSnackBar('Download failed: $e');
    } finally {
      setState(() => isDownloading = false);
    }
  }

  Future<void> _sharePdf() async {
    if (localPdfPath != null) {
      final file = XFile(localPdfPath!);
      await Share.shareXFiles([file], text: widget.title);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryBlue,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (totalPages > 0)
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
      actions: [
        if (!isLoading && localPdfPath != null) ...[
          // Share button
          IconButton(
            onPressed: _sharePdf,
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share PDF',
          ),
          // Download button
          IconButton(
            onPressed: isDownloading ? null : _downloadToDevice,
            icon:
                isDownloading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download PDF',
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (localPdfPath == null) {
      return _buildErrorState();
    }

    return PDFView(
      filePath: localPdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: currentPage,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          totalPages = pages ?? 0;
        });
      },
      onViewCreated: (PDFViewController controller) {
        // PDF controller for future enhancements
      },
      onLinkHandler: (String? uri) {
        // Handle PDF links if needed
      },
      onError: (error) {
        setState(() {
          errorMessage = 'Error rendering PDF: $error';
        });
      },
      onPageError: (page, error) {
        setState(() {
          errorMessage = 'Error on page $page: $error';
        });
      },
      onPageChanged: (int? page, int? total) {
        setState(() {
          currentPage = page ?? 0;
          totalPages = total ?? 0;
        });
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading PDF...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we prepare your document',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 24),
            Text(
              'Failed to Load PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Unable to display the PDF document',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadPdf,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (isLoading || localPdfPath == null || totalPages == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Page ${currentPage + 1} of $totalPages',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
