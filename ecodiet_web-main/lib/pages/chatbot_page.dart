import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/ecodiet_api.dart';
import '../utils/responsive.dart';

/// Base URL for the ChefBot Flask API.
/// Start the server with: cd chatbot && python api.py
const String kChatbotApiUrl = 'http://localhost:5000';

// ── Data model ────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with SingleTickerProviderStateMixin {
  final EcoDietApi _api = EcoDietApi();
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Typing-dot animation
  late final AnimationController _dotController;

  String? _sessionId;
  bool _isInitializing = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initSession();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Session initialisation ────────────────────────────────────────────────

  Future<void> _initSession() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _messages.clear();
      _sessionId = null;
    });

    try {
      // Fetch user profile from Supabase in parallel
      final results = await Future.wait([
        _api.getUserRegime(),
        _api.getUserAllergenes(),
      ]);

      final regime = results[0];      // Regime?
      final allergenes = results[1] as List; // List<Allergene>
      final user = _api.currentUser;

      final profile = {
        'name': user?.prenom ?? user?.nom ?? 'Utilisateur',
        'regime': (regime as dynamic)?.libelle ?? '',
        'allergies':
            allergenes.map((a) => (a as dynamic).libelle as String).toList(),
      };

      final response = await http
          .post(
            Uri.parse('$kChatbotApiUrl/api/session/init'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'profile': profile}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final count = data['recipe_count'] as int;

        setState(() {
          _sessionId = data['session_id'] as String;
          _isInitializing = false;
          _messages.add(_ChatMessage(
            text: 'Bonjour ${profile['name']} !\n'
                "Je suis ChefBot, votre assistant culinaire.\n"
                "J'ai $count recettes adaptées à votre profil.\n\n"
                'Essayez : "propose-moi un dessert", "recette rapide",'
                ' "idée pour un barbecue", "aide"…',
            isUser: false,
          ));
        });
      } else {
        throw Exception('Serveur : ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Impossible de démarrer ChefBot.\n\n'
            'Assurez-vous que le serveur Python est lancé :\n'
            'cd chatbot && python api.py';
      });
    }
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending || _sessionId == null) return;

    _inputController.clear();

    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$kChatbotApiUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': _sessionId, 'message': text}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _isSending = false;
          _messages
              .add(_ChatMessage(text: data['response'] as String, isUser: false));
        });
      } else {
        throw Exception('${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSending = false;
        _messages.add(const _ChatMessage(
          text: 'Désolé, une erreur est survenue. Réessayez.',
          isUser: false,
        ));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildHeader(desktop),
                Expanded(child: _buildBody()),
                if (_errorMessage == null && !_isInitializing)
                  _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool desktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          desktop ? 24 : 16, 20, desktop ? 24 : 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5ECD9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD8D0C0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ChefBot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2E1F),
                ),
              ),
              Text(
                'Assistant culinaire IA',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          // Reset button
          if (_sessionId != null)
            Semantics(
              button: true,
              label: 'Nouvelle conversation',
              child: IconButton(
                onPressed: _initSession,
                tooltip: 'Nouvelle conversation',
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF2F6B3F)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2F6B3F)),
            SizedBox(height: 16),
            Text('Démarrage de ChefBot…',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.6),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6B3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        return _buildBubble(_messages[index]);
      },
    );
  }

  // ── Message bubbles ───────────────────────────────────────────────────────

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Bot avatar
            if (!isUser)
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 15),
              ),
            // Bubble
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isUser ? const Color(0xFFEA853D) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    color: isUser
                        ? Colors.white
                        : const Color(0xFF1F2E1F),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 15),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _dotController,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => _buildDot(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final delay = index / 3;
    final t = (_dotController.value - delay).clamp(0.0, 1.0);
    final opacity = (0.35 + 0.65 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.0, 1.0);
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2F6B3F).withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5ECD9),
        border: Border(
          top: BorderSide(color: Color(0xFFD8D0C0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _sendMessage(),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Demandez une recette…',
                  hintStyle:
                      TextStyle(fontSize: 14, color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Envoyer',
            child: GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _isSending
                      ? const LinearGradient(
                          colors: [Color(0xFFB0B0B0), Color(0xFF909090)])
                      : const LinearGradient(
                          colors: [Color(0xFFF4A259), Color(0xFFEA853D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _isSending
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
