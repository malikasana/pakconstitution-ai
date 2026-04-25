import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/theme_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../models/article_reference.dart';

// ── EXCERPT CLEANER ──────────────────────────────────────────────
String _cleanExcerpt(String raw) {
  String text = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\x20-\x7E\u00A0-\uFFFF]'), '')
      .replaceAll(RegExp(r'\(\d+\)'), '')
      .replaceAll(RegExp(r'\[\d+\]'), '')
      .trim();
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
  if (sentences.length > 2) {
    text = sentences.take(2).join(' ');
    if (!text.endsWith('.')) text += '.';
  }
  if (text.length > 220) text = '${text.substring(0, 217)}…';
  return text.trim();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const double _kDesktopBreakpoint = 720;
  bool get _isDesktop => MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _isDesktop ? null : _buildDrawer(context),
      body: _isDesktop
          ? Row(children: [
              _buildSidebarPanel(context),
              _buildSidebarEdge(context),
              Expanded(child: _buildChatShell(context)),
            ])
          : _buildChatShell(context),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      width: 260,
      backgroundColor: AppColors.sidebarBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Stack(children: [
        _buildSidebarPanel(context),
        if (isDark)
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Container(width: 1.5, color: AppColors.sidebarEdgeBorder),
          ),
      ]),
    );
  }

  Widget _buildSidebarEdge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isDark ? 1.5 : 1,
      color: isDark ? AppColors.sidebarEdgeBorder : AppColors.lightBorder,
    );
  }

  Widget _buildSidebarPanel(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final convProvider = context.watch<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();

    return Container(
      width: 260,
      color: AppColors.sidebarBg,
      child: Column(children: [
        SizedBox(height: MediaQuery.of(context).padding.top),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(child: CustomPaint(size: const Size(18, 18), painter: _ScalesPainter())),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PakConstitution AI',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.sidebarText)),
              const SizedBox(height: 1),
              Text('1973 · All Amendments',
                  style: TextStyle(fontSize: 10, color: AppColors.sidebarMuted)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: () {
              convProvider.setActive(null);
              chatProvider.clearMessages();
              if (!_isDesktop) Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(children: [
                Text('+', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.6), height: 1)),
                const SizedBox(width: 8),
                Text('New conversation', style: TextStyle(fontSize: 13, color: AppColors.sidebarText)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                color: AppColors.sidebarMuted, letterSpacing: 0.8)),
          ),
        ),
        Expanded(
          child: convProvider.conversations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No conversations yet',
                      style: TextStyle(fontSize: 12, color: AppColors.sidebarMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  itemCount: convProvider.conversations.length,
                  itemBuilder: (context, i) {
                    final conv = convProvider.conversations[i];
                    final isActive = conv.id == convProvider.activeId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.sidebarActive : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: InkWell(
                        onTap: () async {
                          convProvider.setActive(conv.id);
                          await chatProvider.loadMessages(conv.id);
                          if (!_isDesktop && mounted) Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: AppColors.sidebarText)),
                                const SizedBox(height: 2),
                                Text(_formatDate(conv.updatedAt),
                                    style: TextStyle(fontSize: 10.5, color: AppColors.sidebarMuted)),
                              ]),
                            ),
                            Builder(
                              builder: (btnCtx) => GestureDetector(
                                onTap: () => _showConvOptions(
                                    btnCtx, convProvider, chatProvider, conv.id, conv.title),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
                                  child: Icon(Icons.more_vert, size: 15, color: AppColors.sidebarMuted),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.sidebarDivider))),
          child: Row(children: [
            _SbIconBtn(icon: Icons.settings_outlined, onTap: () {
              if (!_isDesktop) Navigator.of(context).pop();
              _openSettings(context);
            }),
            const SizedBox(width: 6),
            _SbIconBtn(icon: Icons.contrast_outlined, onTap: () => themeProvider.toggleTheme()),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  Widget _buildChatShell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final text2 = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final text3 = isDark ? AppColors.darkText3 : AppColors.lightText3;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    final convProvider = context.watch<ConversationProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final title = convProvider.activeId != null
        ? (convProvider.conversations
            .where((c) => c.id == convProvider.activeId)
            .firstOrNull?.title ?? 'Constitutional Research')
        : 'Constitutional Research';

    return Column(children: [
      Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        color: surface,
        child: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (!_isDesktop) ...[
              _TopBtn(icon: Icons.menu, isDark: isDark,
                  onTap: () => _scaffoldKey.currentState?.openDrawer()),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(title, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Playfair Display', fontSize: 15,
                      color: text.withOpacity(0.85))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 5,
                    decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('${chatProvider.contextCount} / ${themeProvider.contextTurns} turns',
                    style: TextStyle(fontSize: 10.5, color: text3)),
              ]),
            ),
            const SizedBox(width: 8),
            _TopBtn(icon: Icons.tune_outlined, isDark: isDark, onTap: () => _openSettings(context)),
          ]),
        ),
      ),
      Expanded(
        child: (chatProvider.messages.isEmpty && convProvider.activeId == null)
            ? _WelcomeView(isDark: isDark, bg: bg, surface: surface, border: border,
                text: text, text2: text2, onSuggestion: (q) => _handleSend(context, q))
            : _MessageList(
                messages: chatProvider.messages,
                isLoading: chatProvider.isLoading && themeProvider.showTypingIndicator,
                isDark: isDark,
                showRefs: themeProvider.showReferenceCards,
                compact: themeProvider.compactView,
                fontSize: themeProvider.baseFontSize,
                error: chatProvider.error,
              ),
      ),
      _InputBar(
        isDark: isDark, surface: surface, border: border,
        text: text, text2: text2, text3: text3,
        isLoading: chatProvider.isLoading,
        onSend: (msg) => _handleSend(context, msg),
      ),
    ]);
  }

  Future<void> _handleSend(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();
    final themeProvider = context.read<ThemeProvider>();
    chatProvider.updateMaxContext(themeProvider.contextTurns);
    String convId = convProvider.activeId ?? '';
    if (convId.isEmpty) {
      final conv = await convProvider.createConversation(text);
      convId = conv.id;
    }
    await chatProvider.sendMessage(
      text: text,
      conversationId: convId,
      convProvider: convProvider,
      apiUrl: themeProvider.apiUrl,
    );
  }

  void _openSettings(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: convProvider),
          ChangeNotifierProvider.value(value: chatProvider),
        ],
        child: const _SettingsSheet(),
      ),
    );
  }

  // ── POPUP MENU — always dark regardless of theme ─────────────
  void _showConvOptions(BuildContext context, ConversationProvider convProvider,
      ChatProvider chatProvider, String id, String title) {
    // Always dark popup to match the always-dark sidebar
    const menuBg = Color(0xFF1C1C1E);
    const menuBorder = Color(0xFF3A3A3C);
    const menuText = Color(0xFFF5F5F5);

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: menuBg,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: menuBorder),
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          height: 42,
          child: Row(children: const [
            Icon(Icons.edit_outlined, size: 16, color: menuText),
            SizedBox(width: 10),
            Text('Rename', style: TextStyle(fontSize: 13, color: menuText)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 42,
          child: Row(children: const [
            Icon(Icons.delete_outline, size: 16, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
          ]),
        ),
      ],
    ).then((value) async {
      if (value == 'rename') {
        _renameConv(context, convProvider, id, title);
      } else if (value == 'delete') {
        // ── DELETE CONFIRMATION ───────────────────────────────
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete conversation?',
                style: TextStyle(color: Color(0xFFF5F5F5), fontSize: 16)),
            content: Text(
              '"$title"\n\nThis cannot be undone.',
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await convProvider.deleteConversation(id);
          if (convProvider.activeId == null) chatProvider.clearMessages();
        }
      }
    });
  }

  Future<void> _renameConv(BuildContext context, ConversationProvider provider,
      String id, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text('Rename', style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText, fontSize: 16)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
          decoration: InputDecoration(
            hintText: 'Conversation name',
            hintStyle: TextStyle(color: isDark ? AppColors.darkText3 : AppColors.lightText3),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await provider.renameConversation(id, newTitle);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}';
  }
}

// ── MESSAGE LIST ─────────────────────────────────────────────────
class _MessageList extends StatefulWidget {
  final List<Message> messages;
  final bool isLoading, isDark, showRefs, compact;
  final double fontSize;
  final String? error;
  const _MessageList({required this.messages, required this.isLoading, required this.isDark,
      required this.showRefs, required this.compact, required this.fontSize, this.error});

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_MessageList old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length || widget.isLoading != old.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkBg : AppColors.lightBg;
    final total = widget.messages.length +
        (widget.isLoading ? 1 : 0) +
        (widget.error != null ? 1 : 0);

    return Container(
      color: bg,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.compact ? 12 : 18),
        itemCount: total,
        itemBuilder: (context, i) {
          if (i == widget.messages.length && widget.error != null) {
            return _ErrorBubble(error: widget.error!, isDark: widget.isDark);
          }
          if (i == widget.messages.length && widget.isLoading) {
            return _TypingIndicator(isDark: widget.isDark);
          }
          return _MessageBubble(
            message: widget.messages[i], isDark: widget.isDark,
            showRefs: widget.showRefs, compact: widget.compact, fontSize: widget.fontSize,
          );
        },
      ),
    );
  }
}

// ── MESSAGE BUBBLE ───────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isDark, showRefs, compact;
  final double fontSize;
  const _MessageBubble({required this.message, required this.isDark,
      required this.showRefs, required this.compact, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final textColor = isUser
        ? (isDark ? AppColors.darkUserText : AppColors.lightUserText)
        : (isDark ? AppColors.darkText : AppColors.lightText);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_Avatar(isUser: false, isDark: isDark), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 11),
                  decoration: BoxDecoration(
                    color: isUser
                        ? (isDark ? AppColors.darkUserBubble : AppColors.lightUserBubble)
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(11), topRight: const Radius.circular(11),
                      bottomLeft: Radius.circular(isUser ? 11 : 3),
                      bottomRight: Radius.circular(isUser ? 3 : 11),
                    ),
                    border: isUser ? null : Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: isUser
                      ? Text(message.content, style: TextStyle(
                          fontSize: fontSize, height: 1.65, color: textColor))
                      : MarkdownBody(
                          data: message.content,
                          shrinkWrap: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: fontSize, height: 1.65, color: textColor),
                            strong: TextStyle(fontSize: fontSize, height: 1.65,
                                fontWeight: FontWeight.w600, color: textColor),
                            em: TextStyle(fontSize: fontSize, height: 1.65,
                                fontStyle: FontStyle.italic, color: textColor),
                            listBullet: TextStyle(fontSize: fontSize, height: 1.65,
                                color: isDark ? AppColors.darkText2 : AppColors.lightText2),
                            code: TextStyle(fontSize: fontSize - 1, fontFamily: 'monospace',
                                color: textColor,
                                backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
                            codeblockDecoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                borderRadius: BorderRadius.circular(6)),
                            blockquote: TextStyle(fontSize: fontSize, height: 1.65,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkText2 : AppColors.lightText2),
                            h1: TextStyle(fontSize: fontSize + 4,
                                fontFamily: 'Playfair Display', fontWeight: FontWeight.w600,
                                color: textColor),
                            h2: TextStyle(fontSize: fontSize + 2,
                                fontFamily: 'Playfair Display', fontWeight: FontWeight.w600,
                                color: textColor),
                            h3: TextStyle(fontSize: fontSize + 1,
                                fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ),
                ),
                if (!isUser && showRefs && message.references.isNotEmpty)
                  ...message.references.map((ref) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _ReferenceCard(ref: ref, isDark: isDark),
                  )),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _Avatar(isUser: true, isDark: isDark)],
        ],
      ),
    );
  }
}

// ── AVATAR ───────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final bool isUser, isDark;
  const _Avatar({required this.isUser, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? (isDark ? AppColors.darkUserBubble : AppColors.lightUserBubble)
            : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Center(
        child: isUser
            ? Text('U', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkUserText : AppColors.lightUserText))
            : CustomPaint(size: const Size(14, 14),
                painter: _ScalesPainter(color: isDark ? AppColors.darkText2 : AppColors.lightText2)),
      ),
    );
  }
}

// ── REFERENCE CARD ───────────────────────────────────────────────
class _ReferenceCard extends StatelessWidget {
  final ArticleReference ref;
  final bool isDark;
  const _ReferenceCard({required this.ref, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.refBgDark : AppColors.refBgLight;
    final border = isDark ? AppColors.refBorderDark : AppColors.refBorderLight;
    final accent = isDark ? AppColors.refAccentDark : AppColors.refAccentLight;
    final excerptBg = isDark ? AppColors.refExcerptBgDark : AppColors.refExcerptBgLight;
    final badgeBg = isDark ? AppColors.refBadgeBgDark : AppColors.refBadgeBgLight;
    final badgeText = isDark ? AppColors.refBadgeTextDark : AppColors.refBadgeTextLight;
    final titleColor = isDark ? AppColors.darkText : AppColors.lightText;
    final excerptColor = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final footColor = isDark ? AppColors.darkText3 : AppColors.lightText3;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border)),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 3, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent, accent.withOpacity(0)]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text('Art. ${ref.articleNumber}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: badgeText)),
              ),
              if (ref.amendment != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.amendBgDark : AppColors.amendBgLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.amendBorderDark : AppColors.amendBorderLight),
                  ),
                  child: Text(ref.amendment!, style: TextStyle(fontSize: 10.5,
                      color: isDark ? AppColors.amendTextDark : AppColors.amendTextLight)),
                ),
              ],
            ]),
            const SizedBox(height: 7),
            Text(ref.title, style: TextStyle(fontFamily: 'Playfair Display',
                fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor)),
            if (ref.excerpt != null && ref.excerpt!.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
                decoration: BoxDecoration(
                  color: excerptBg, borderRadius: BorderRadius.circular(6),
                  border: Border(left: BorderSide(color: accent, width: 2)),
                ),
                child: Text(_cleanExcerpt(ref.excerpt!), style: TextStyle(fontSize: 12,
                    fontStyle: FontStyle.italic, color: excerptColor, height: 1.55)),
              ),
            ],
            const SizedBox(height: 7),
            Text('Constitution of Pakistan · 1973',
                style: TextStyle(fontSize: 10, color: footColor)),
          ]),
        ),
      ]),
    );
  }
}

// ── TYPING INDICATOR ─────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Avatar(isUser: false, isDark: widget.isDark),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: surface,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11), topRight: Radius.circular(11),
                bottomLeft: Radius.circular(3), bottomRight: Radius.circular(11)),
            border: Border.all(color: border),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.2;
                final val = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                final opacity = val < 0.4 ? val / 0.4 : val < 0.8 ? 1.0 - (val - 0.4) / 0.4 : 0.2;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: (widget.isDark ? AppColors.darkText3 : AppColors.lightText3)
                          .withOpacity(opacity.clamp(0.15, 1.0))),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── ERROR BUBBLE ─────────────────────────────────────────────────
class _ErrorBubble extends StatelessWidget {
  final String error; final bool isDark;
  const _ErrorBubble({required this.error, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Avatar(isUser: false, isDark: isDark),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11), topRight: Radius.circular(11),
                  bottomLeft: Radius.circular(3), bottomRight: Radius.circular(11)),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Text(error, style: const TextStyle(fontSize: 13, color: Colors.red)),
          ),
        ),
      ]),
    );
  }
}

// ── WELCOME VIEW ─────────────────────────────────────────────────
class _WelcomeView extends StatelessWidget {
  final bool isDark;
  final Color bg, surface, border, text, text2;
  final Function(String) onSuggestion;
  const _WelcomeView({required this.isDark, required this.bg, required this.surface,
      required this.border, required this.text, required this.text2, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'What are the Fundamental Rights in Part II?',
      'Powers of the Prime Minister under Article 90',
      'What did the 18th Amendment change?',
      'Article 25 — equality of citizens',
    ];
    return Container(
      color: bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border)),
              child: Center(child: CustomPaint(size: const Size(28, 28),
                  painter: _ScalesPainter(color: text2))),
            ),
            const SizedBox(height: 18),
            Text("Ask about Pakistan's Constitution", textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20,
                    fontWeight: FontWeight.w600, color: text)),
            const SizedBox(height: 8),
            Text('Precise answers with article references\nand amendment history from 1973 to present.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: text2, height: 1.6)),
            const SizedBox(height: 28),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 400 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  childAspectRatio: cols == 2 ? 3.2 : 5,
                ),
                itemCount: suggestions.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => onSuggestion(suggestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: border)),
                    child: Text(suggestions[i],
                        style: TextStyle(fontSize: 12, color: text2, height: 1.45)),
                  ),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }
}

// ── INPUT BAR ─────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final bool isDark, isLoading;
  final Color surface, border, text, text2, text3;
  final Function(String) onSend;
  const _InputBar({required this.isDark, required this.isLoading, required this.surface,
      required this.border, required this.text, required this.text2, required this.text3, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty || widget.isLoading) return;
    _ctrl.clear();
    widget.onSend(t);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: widget.surface,
          border: Border(top: BorderSide(color: widget.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.border),
            ),
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                }
              },
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                maxLines: null,
                enabled: !widget.isLoading,
                style: TextStyle(fontSize: 13.5, color: widget.text, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Ask about any article, amendment, or provision…',
                  hintStyle: TextStyle(fontSize: 13.5, color: widget.text2),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: widget.isLoading
                  ? (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder2)
                  : (widget.isDark ? AppColors.darkSurface2 : AppColors.lightText),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.arrow_upward_rounded, size: 18,
                color: widget.isLoading
                    ? (widget.isDark ? AppColors.darkText3 : AppColors.lightText3)
                    : (widget.isDark ? AppColors.darkText2 : Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ── SETTINGS SHEET ───────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late TextEditingController _apiCtrl;
  bool _apiSaved = false;

  @override
  void initState() {
    super.initState();
    final url = context.read<ThemeProvider>().apiUrl;
    _apiCtrl = TextEditingController(text: url);
  }

  @override
  void dispose() { _apiCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final text2 = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final text3 = isDark ? AppColors.darkText3 : AppColors.lightText3;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final themeProvider = context.watch<ThemeProvider>();
    final convProvider = context.read<ConversationProvider>();
    final chatProvider = context.read<ChatProvider>();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + keyboardHeight),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('Settings', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 18, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.close, size: 14, color: text2)),
            ),
          ]),
        ),
        Divider(color: border, height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── THEME ──
              _SLabel('Theme', text3),
              const SizedBox(height: 8),
              Row(children: [
                _ThemeCard(label: 'Light', isDarkCard: false, selected: !themeProvider.isDark,
                    onTap: () => themeProvider.setTheme(ThemeMode.light)),
                const SizedBox(width: 8),
                _ThemeCard(label: 'Dark', isDarkCard: true, selected: themeProvider.isDark,
                    onTap: () => themeProvider.setTheme(ThemeMode.dark)),
              ]),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),

              // ── TEXT SIZE ──
              _SLabel('Text size', text3),
              const SizedBox(height: 8),
              Row(children: [
                _FontBtn(label: 'Default', selected: themeProvider.fontSize == AppFontSize.normal,
                    surface2: surface2, border: border, text: text, text2: text2,
                    onTap: () => themeProvider.setFontSize(AppFontSize.normal)),
                const SizedBox(width: 6),
                _FontBtn(label: 'Large', selected: themeProvider.fontSize == AppFontSize.large,
                    surface2: surface2, border: border, text: text, text2: text2,
                    onTap: () => themeProvider.setFontSize(AppFontSize.large)),
                const SizedBox(width: 6),
                _FontBtn(label: 'X-Large', selected: themeProvider.fontSize == AppFontSize.xlarge,
                    surface2: surface2, border: border, text: text, text2: text2,
                    onTap: () => themeProvider.setFontSize(AppFontSize.xlarge)),
              ]),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),

              // ── CHAT TOGGLES ──
              _SLabel('Chat', text3),
              const SizedBox(height: 10),
              _ToggleRow(label: 'Reference cards', sub: 'Show article citations',
                  value: themeProvider.showReferenceCards, text: text, text2: text2,
                  onChanged: themeProvider.setShowReferenceCards),
              _ToggleRow(label: 'Compact view', sub: 'Tighter message spacing',
                  value: themeProvider.compactView, text: text, text2: text2,
                  onChanged: themeProvider.setCompactView),
              _ToggleRow(label: 'Typing indicator', sub: 'Dots while AI responds',
                  value: themeProvider.showTypingIndicator, text: text, text2: text2,
                  onChanged: themeProvider.setShowTypingIndicator),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),

              // ── CONTEXT WINDOW ──
              _SLabel('Context window', text3),
              const SizedBox(height: 8),
              Row(children: [
                Text('Turns remembered', style: TextStyle(fontSize: 13, color: text)),
                const Spacer(),
                Text('${themeProvider.contextTurns}', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.accentDark : AppColors.accentLight)),
              ]),
              Slider(
                value: themeProvider.contextTurns.toDouble(),
                min: 2, max: 8, divisions: 6,
                activeColor: isDark ? AppColors.accentDark : AppColors.accentLight,
                onChanged: (v) {
                  themeProvider.setContextTurns(v.round());
                  chatProvider.updateMaxContext(v.round());
                },
              ),
              Text('More turns = better memory, more tokens used per request',
                  style: TextStyle(fontSize: 11, color: text3)),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),

              // ── API URL ──
              _SLabel('Backend', text3),
              const SizedBox(height: 8),
              Text('API URL', style: TextStyle(fontSize: 13, color: text)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _apiSaved
                          ? (isDark ? AppColors.accentDark : AppColors.accentLight)
                          : border),
                    ),
                    child: TextField(
                      controller: _apiCtrl,
                      style: TextStyle(fontSize: 12.5, color: text, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'http://192.168.x.x:8002',
                        hintStyle: TextStyle(fontSize: 12.5, color: text3, fontFamily: 'monospace'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (_) { if (_apiSaved) setState(() => _apiSaved = false); },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final url = _apiCtrl.text.trim();
                    if (url.isEmpty) return;
                    await themeProvider.setApiUrl(url);
                    setState(() => _apiSaved = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _apiSaved
                          ? (isDark ? AppColors.accentDark : AppColors.accentLight).withOpacity(0.12)
                          : surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _apiSaved
                          ? (isDark ? AppColors.accentDark : AppColors.accentLight)
                          : border),
                    ),
                    child: Text(
                      _apiSaved ? 'Saved ✓' : 'Save',
                      style: TextStyle(
                        fontSize: 13,
                        color: _apiSaved
                            ? (isDark ? AppColors.accentDark : AppColors.accentLight)
                            : text2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('Changes apply to the next message sent.',
                  style: TextStyle(fontSize: 11, color: text3)),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),

              // ── DATA ──
              _SLabel('Data', text3),
              const SizedBox(height: 8),
              _ActionBtn(
                label: 'Clear all conversations', isDestructive: true,
                surface2: surface2, border: border, text: text2,
                onTap: () async {
                  Navigator.pop(context);
                  await convProvider.deleteAll();
                  chatProvider.clearMessages();
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── SETTINGS HELPERS ─────────────────────────────────────────────
class _SLabel extends StatelessWidget {
  final String label; final Color color;
  const _SLabel(this.label, this.color);
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.8));
}

class _ThemeCard extends StatelessWidget {
  final String label; final bool isDarkCard, selected; final VoidCallback onTap;
  const _ThemeCard({required this.label, required this.isDarkCard, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDarkCard ? const Color(0xFF1F1F23) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.accentLight : const Color(0xFFE8E6E0),
                width: selected ? 1.5 : 1),
          ),
          child: Column(children: [
            Container(height: 32, child: Row(children: [
              Container(width: 28, decoration: const BoxDecoration(color: Color(0xFF111113),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(5), bottomLeft: Radius.circular(5)))),
              Expanded(child: Container(decoration: BoxDecoration(
                  color: isDarkCard ? const Color(0xFF18181B) : const Color(0xFFF8F8F6),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(5), bottomRight: Radius.circular(5))))),
            ])),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12,
                color: selected ? const Color(0xFF18181B) : const Color(0xFF52525B),
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

class _FontBtn extends StatelessWidget {
  final String label; final bool selected;
  final Color surface2, border, text, text2; final VoidCallback onTap;
  const _FontBtn({required this.label, required this.selected, required this.surface2,
      required this.border, required this.text, required this.text2, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight.withOpacity(0.08) : surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: selected ? AppColors.accentLight : border),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12,
            color: selected ? AppColors.accentLight : text2,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400)),
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label, sub; final bool value;
  final Color text, text2; final Function(bool) onChanged;
  const _ToggleRow({required this.label, required this.sub, required this.value,
      required this.text, required this.text2, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: text)),
        Text(sub, style: TextStyle(fontSize: 11, color: text2)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: AppColors.accentLight),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label; final bool isDestructive;
  final Color surface2, border, text; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.isDestructive,
      required this.surface2, required this.border, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDestructive ? Colors.red.withOpacity(0.05) : surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDestructive ? Colors.red.withOpacity(0.3) : border),
      ),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isDestructive ? Colors.red : text)),
    ),
  );
}

// ── SHARED SMALL WIDGETS ─────────────────────────────────────────
class _TopBtn extends StatelessWidget {
  final IconData icon; final bool isDark; final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Icon(icon, size: 16, color: isDark ? AppColors.darkText2 : AppColors.lightText2),
    ),
  );
}

class _SbIconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _SbIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, size: 16, color: AppColors.sidebarMuted),
      ),
    ),
  );
}

// ── SCALES PAINTER ───────────────────────────────────────────────
class _ScalesPainter extends CustomPainter {
  final Color color;
  const _ScalesPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.85)..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final f = Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.fill;
    final c = Paint()..color = color.withOpacity(0.5)..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final b = Paint()..color = color.withOpacity(0.65)..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, size.height * 0.1), 2.5, f);
    canvas.drawLine(Offset(cx, size.height * 0.1), Offset(cx, size.height * 0.72), p);
    canvas.drawLine(Offset(size.width * 0.08, size.height * 0.3), Offset(size.width * 0.92, size.height * 0.3), p);
    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.3), Offset(size.width * 0.18, size.height * 0.46), c);
    canvas.drawLine(Offset(size.width * 0.82, size.height * 0.3), Offset(size.width * 0.82, size.height * 0.46), c);
    canvas.drawArc(Rect.fromCenter(center: Offset(size.width * 0.18, size.height * 0.52), width: size.width * 0.28, height: size.height * 0.18), 0, 3.14159, false, p);
    canvas.drawArc(Rect.fromCenter(center: Offset(size.width * 0.82, size.height * 0.52), width: size.width * 0.28, height: size.height * 0.18), 0, 3.14159, false, p);
    canvas.drawLine(Offset(cx, size.height * 0.72), Offset(cx, size.height * 0.85), b);
    canvas.drawLine(Offset(size.width * 0.28, size.height * 0.88), Offset(size.width * 0.72, size.height * 0.88), b);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}