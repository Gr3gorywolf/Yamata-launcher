import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/app_provider.dart';

class ExecutionLogsDialog extends StatefulWidget {
  final String slug;

  const ExecutionLogsDialog({super.key, required this.slug});

  static Future<void> show(BuildContext context, String slug) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ExecutionLogsDialog(slug: slug),
    );
  }

  @override
  State<ExecutionLogsDialog> createState() => _ExecutionLogsDialogState();
}

class _ExecutionLogsDialogState extends State<ExecutionLogsDialog> {
  static const double _readingThreshold = 0.05;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  String _lastLogs = '';
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialLogs =
        context.read<AppProvider>().executionLogs[widget.slug] ?? '';
    _syncLogs(initialLogs, forceScroll: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      if (_isReading) {
        setState(() {
          _isReading = false;
        });
      }
      return;
    }

    final distanceToBottom =
        maxScrollExtent - _scrollController.position.pixels;
    final shouldRead = distanceToBottom > (maxScrollExtent * _readingThreshold);

    if (shouldRead != _isReading && mounted) {
      setState(() {
        _isReading = shouldRead;
      });
    }
  }

  void _syncLogs(String logs, {bool forceScroll = false}) {
    if (_lastLogs == logs) return;

    _lastLogs = logs;
    _textController.value = TextEditingValue(
      text: logs,
      selection: TextSelection.collapsed(offset: logs.length),
    );

    if (forceScroll || !_isReading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const terminalBackground = Color(0xFF050505);
    const terminalPanel = Color(0xFF101010);
    const terminalBorder = Color(0xFF1F8B4C);
    const terminalText = Color(0xFF6CFF8F);
    const terminalMutedText = Color(0xFF98CFA4);
    const readingText = Color(0xFFFFD166);

    return Selector<AppProvider, String>(
      selector: (_, appProvider) =>
          appProvider.executionLogs[widget.slug] ?? '',
      builder: (context, logs, _) {
        _syncLogs(logs);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 900,
              minWidth: 320,
              minHeight: 320,
              maxHeight: 700,
            ),
            decoration: BoxDecoration(
              color: terminalBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: terminalBorder, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: terminalPanel,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Execution logs',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: terminalText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.slug,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: terminalMutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _isReading ? readingText : terminalBorder,
                          ),
                        ),
                        child: Text(
                          _isReading ? 'READING' : 'LIVE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _isReading ? readingText : terminalText,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        color: terminalMutedText,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1A1A1A)),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: TextField(
                          controller: _textController,
                          scrollController: _scrollController,
                          readOnly: true,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            color: terminalText,
                            height: 1.35,
                            fontSize: 13,
                            fontFamilyFallback: ['Courier New', 'monospace'],
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            hintText: 'Waiting for execution logs...',
                            hintStyle: const TextStyle(
                              color: terminalMutedText,
                              fontFamilyFallback: ['Courier New', 'monospace'],
                            ),
                          ),
                          cursorColor: terminalText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
