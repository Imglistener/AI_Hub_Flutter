import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Represents a connected LLM/assistant provider.
class Assistant {
  const Assistant({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final String shortLabel; // used in avatar badges
  final Color color;
  final IconData icon;
}

/// Placeholder roster. Wire this up to your real provider/config list later.
const List<Assistant> kAssistants = [
  Assistant(
    id: 'claude',
    name: 'Claude',
    shortLabel: 'C',
    color: Color(0xFFD97757),
    icon: Icons.auto_awesome,
  ),
  Assistant(
    id: 'gpt',
    name: 'ChatGPT',
    shortLabel: 'G',
    color: Color(0xFF10A37F),
    icon: Icons.chat_bubble_outline,
  ),
  Assistant(
    id: 'gemini',
    name: 'Gemini',
    shortLabel: 'Ge',
    color: Color(0xFF4285F4),
    icon: Icons.diamond_outlined,
  ),
  Assistant(
    id: 'grok',
    name: 'Grok',
    shortLabel: 'Gr',
    color: AppColors.primaryVariant,
    icon: Icons.bolt_outlined,
  ),
];

class ChatMessage {
  const ChatMessage({required this.text, required this.isUser, this.isLoading = false});

  final String text;
  final bool isUser;
  final bool isLoading;
}