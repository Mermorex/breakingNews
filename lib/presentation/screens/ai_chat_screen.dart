import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../data/datasources/rss_remote_datasource.dart';
import '../../data/models/rss_item_model.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RssRemoteDataSource _dataSource = RssRemoteDataSource();

  final List<ChatMessage> _messages = [];
  List<RssItemModel> _rssContext = [];
  bool _isLoading = false;
  bool _isTyping = false;

  // Crypto Theme
  static const Color _bgColor = Color(0xFF0B0E14);
  static const Color _cardColor = Color(0xFF151A25);
  static const Color _accentOrange = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    // Optional: Pre-load some context if you want
    _loadNewsContext();
  }

  // 1. Fetch RSS Data to use as "Brain"
  Future<void> _loadNewsContext() async {
    setState(() => _isLoading = true);
    try {
      // Fetching from a few diverse sources as a demo context
      // You can add more URLs from your app here
      final urls = [
        'https://www.aljazeera.com/xml/rss/all.xml',
        'https://www.lemonde.fr/rss/une.xml',
        'https://www.mosaiquefm.net/ar/rss'
      ];

      List<RssItemModel> allItems = [];
      for (var url in urls) {
        try {
          final items = await _dataSource.fetchRssFeed(url, limit: 5);
          allItems.addAll(items);
        } catch (e) {
          print("Error fetching $url: $e");
        }
      }
      setState(() {
        _rssContext = allItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 2. Send Message to AI
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (text.isEmpty || apiKey.isEmpty) {
      // Shake animation or alert could go here
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // 1. Get Context
    final relevantArticles = _getRelevantArticles(text);
    final systemPrompt =
        "You are a helpful AI news assistant. Answer based on the context provided. If not found, say 'I don't have that information in the current news feed.'";
    String contextText = relevantArticles
        .map((item) => "- ${item.title}: ${item.description ?? ''}")
        .join("\n");
    final fullPrompt = "Context:\n$contextText\n\nUser Question: $text";

    try {
      // -------------------------------------------------------
      // CHANGE THIS BLOCK BASED ON YOUR PROVIDER
      // -------------------------------------------------------

      // OPTION 1: DEEPSEEK (Recommended)
      final url = Uri.parse('https://api.deepseek.com/chat/completions');
      final modelName = "deepseek-chat";

      // OPTION 2: GROQ (Original)
      // final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      // final modelName = "llama3-70b-8192";

      // -------------------------------------------------------

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": modelName,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": fullPrompt},
          ],
          "temperature": 0.7,
          "max_tokens": 512,
        }),
      );

      // DEBUG: Print the status and body to your Terminal
      print("API Status Code: ${response.statusCode}");
      print("API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Attempt to parse safely
        if (data.containsKey('choices') && data['choices'].isNotEmpty) {
          final aiResponse = data['choices'][0]['message']['content'];

          setState(() {
            _messages.add(ChatMessage(text: aiResponse, isUser: false));
            _isTyping = false;
          });
        } else {
          throw Exception("Response format unexpected: ${data}");
        }
      } else {
        throw Exception("API Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("CRITICAL ERROR: $e"); // Print error to terminal
      setState(() {
        _messages.add(ChatMessage(text: "Error: $e", isUser: false));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  // Simple Keyword Matching for RAG
  List<RssItemModel> _getRelevantArticles(String question) {
    if (_rssContext.isEmpty) return [];

    final questionWords = question.toLowerCase().split(' ');

    return _rssContext
        .where((item) {
          final content =
              (item.title + " " + (item.description ?? "")).toLowerCase();
          // Return article if it contains at least one significant word from the question
          return questionWords
              .any((word) => word.length > 3 && content.contains(word));
        })
        .take(5)
        .toList(); // Limit to top 5 relevant articles to save tokens
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: _accentOrange, size: 24),
            SizedBox(width: 10),
            Text(
              'AI News Assistant',
              style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          // API Key Button
          TextButton.icon(
            onPressed: () => _showApiKeyDialog(),
            icon: Icon(Icons.key, color: _accentOrange),
            label: Text("Set API Key", style: TextStyle(color: _accentOrange)),
          )
        ],
      ),
      body: Column(
        children: [
          // Context Indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _cardColor,
            child: Row(
              children: [
                Icon(Icons.rss_feed, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isLoading
                        ? "Loading News Context..."
                        : "Context: ${_rssContext.length} articles loaded",
                    style: GoogleFonts.montserrat(
                        fontSize: 12, color: Colors.grey),
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16, color: _accentOrange),
                    onPressed: _loadNewsContext,
                    tooltip: "Refresh Context",
                  )
              ],
            ),
          ),
          // Chat Area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.withOpacity(0.2)),
                        SizedBox(height: 16),
                        Text(
                          "Ask anything about the news",
                          style: GoogleFonts.montserrat(
                              color: Colors.white54, fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Powered by Groq (Llama 3)",
                          style: GoogleFonts.montserrat(
                              color: _accentOrange, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _isTyping
                            ? _TypingIndicator()
                            : SizedBox.shrink();
                      }
                      final message = _messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              border:
                  Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.montserrat(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Ask about recent news...",
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0xFF0B0E14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _accentOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _accentOrange.withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title:
            Text("API Key", style: GoogleFonts.montserrat(color: Colors.white)),
        content: TextField(
          controller: _apiKeyController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "gsk_...",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Save", style: TextStyle(color: _accentOrange)),
          ),
        ],
      ),
    );
  }
}

// --- Widgets ---

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFFFF8C00)
              : const Color(0xFF1C222E),
          borderRadius: BorderRadius.circular(16),
          border: message.isUser
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.montserrat(
            color: message.isUser ? Colors.white : Colors.white70,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFFF8C00)),
          ),
          SizedBox(width: 12),
          Text("Thinking...",
              style:
                  TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
