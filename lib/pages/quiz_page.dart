import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/user.dart' as user_models;
import '../utils/responsive.dart';

/// Modèle local simplifié pour l'UI du quiz
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
  });
}

class QuizPage extends StatefulWidget {
  final String? id;
  final String? title;
  final String? description;

  const QuizPage({
    Key? key,
    this.id,
    this.title,
    this.description,
  }) : super(key: key);

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final EcoDietApi _api = EcoDietApi();

  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool hasAnswered = false;
  int score = 0;
  bool quizCompleted = false;
  bool isLoading = true;

  List<QuizQuestion> questions = [];
  user_models.Quiz? quiz;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (widget.id == null) {
      setState(() => isLoading = false);
      return;
    }

    final quizId = int.tryParse(widget.id!);
    if (quizId == null) {
      setState(() => isLoading = false);
      return;
    }

    final quizResult = await _api.getQuizById(quizId);
    final questionsResult = await _api.getQuizQuestions(quizId);

    setState(() {
      quiz = quizResult;
      questions = questionsResult
          .map((q) => QuizQuestion(
                question: q.questionText,
                options: q.options.map((o) => o.optionText).toList(),
                correctAnswerIndex: q.correctAnswerIndex ?? 0,
                explanation: q.explanation,
              ))
          .toList();
      isLoading = false;
    });
  }

  Future<void> _saveScore() async {
    if (quiz != null && quiz!.quizId != null) {
      await _api.saveQuizScore(quiz!.quizId!, score, questions.length);
    }
  }

  void _selectAnswer(int index) {
    if (hasAnswered || questions.isEmpty) return;

    setState(() {
      selectedAnswerIndex = index;
      hasAnswered = true;
      if (index == questions[currentQuestionIndex].correctAnswerIndex) {
        score++;
      }
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswerIndex = null;
        hasAnswered = false;
      });
    } else {
      _saveScore();
      setState(() {
        quizCompleted = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      selectedAnswerIndex = null;
      hasAnswered = false;
      score = 0;
      quizCompleted = false;
    });
  }

  Color _getOptionColor(int index) {
    if (!hasAnswered) {
      return selectedAnswerIndex == index
          ? const Color(0xFF2F6B3F).withValues(alpha: 0.1)
          : Colors.white;
    }

    if (index == questions[currentQuestionIndex].correctAnswerIndex) {
      return Colors.green.withValues(alpha: 0.2);
    }

    if (index == selectedAnswerIndex) {
      return Colors.red.withValues(alpha: 0.2);
    }

    return Colors.white;
  }

  Color _getOptionBorderColor(int index) {
    if (!hasAnswered) {
      return selectedAnswerIndex == index
          ? const Color(0xFF2F6B3F)
          : Colors.grey.shade300;
    }

    if (index == questions[currentQuestionIndex].correctAnswerIndex) {
      return const Color(0xFF2F6B3F);
    }

    if (index == selectedAnswerIndex) {
      return Colors.red;
    }

    return Colors.grey.shade300;
  }

  IconData? _getOptionIcon(int index) {
    if (!hasAnswered) return null;

    if (index == questions[currentQuestionIndex].correctAnswerIndex) {
      return Icons.check_circle;
    }

    if (index == selectedAnswerIndex &&
        index != questions[currentQuestionIndex].correctAnswerIndex) {
      return Icons.cancel;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Quiz'),
        ),
        body: const Center(
          child: Text('Aucune question disponible'),
        ),
      );
    }

    if (quizCompleted) {
      return _buildResultScreen();
    }

    final desktop = isDesktop(context);
    final question = questions[currentQuestionIndex];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Progress bar
                _buildProgressBar(),

                // Contenu
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 32 : 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Numéro de question
                        Semantics(
                          label:
                              'Question ${currentQuestionIndex + 1} sur ${questions.length}',
                          child: Text(
                            'Question ${currentQuestionIndex + 1}/${questions.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Question
                        Text(
                          question.question,
                          style: TextStyle(
                            fontSize: desktop ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2E1F),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Options : grille 2 colonnes sur desktop
                        if (desktop)
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 4.5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: question.options
                                .asMap()
                                .entries
                                .map((entry) =>
                                    _buildOptionCard(entry.key, entry.value))
                                .toList(),
                          )
                        else
                          ...question.options.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildOptionCard(entry.key, entry.value),
                            );
                          }),

                        // Explication (après réponse)
                        if (hasAnswered && question.explanation != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6B3F)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2F6B3F)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: Color(0xFF2F6B3F),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    question.explanation!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1F2E1F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bouton suivant
                if (hasAnswered)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 32 : 16,
                      vertical: 16,
                    ),
                    child: SizedBox(
                      width: desktop ? 300 : double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F6B3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          currentQuestionIndex < questions.length - 1
                              ? 'Question suivante'
                              : 'Voir les résultats',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2E1F)),
            tooltip: 'Quitter le quiz',
            onPressed: () => _showExitDialog(),
          ),
          Expanded(
            child: Text(
              widget.title ?? 'Quiz',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2E1F),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (currentQuestionIndex + 1) / questions.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Semantics(
            label:
                'Progression : question ${currentQuestionIndex + 1} sur ${questions.length}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF2F6B3F)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String option) {
    final icon = _getOptionIcon(index);
    String semanticsLabel = option;
    if (hasAnswered) {
      final isCorrect =
          index == questions[currentQuestionIndex].correctAnswerIndex;
      final isSelected = index == selectedAnswerIndex;
      if (isCorrect) {
        semanticsLabel += ', bonne réponse';
      } else if (isSelected) {
        semanticsLabel += ', mauvaise réponse';
      }
    }

    return Semantics(
      label: semanticsLabel,
      button: !hasAnswered,
      child: InkWell(
        onTap: () => _selectAnswer(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getOptionColor(index),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getOptionBorderColor(index),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A259).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF4A259),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2E1F),
                  ),
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  color: icon == Icons.check_circle
                      ? const Color(0xFF2F6B3F)
                      : Colors.red,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final desktop = isDesktop(context);
    final percentage = (score / questions.length * 100).round();
    String message;
    Color messageColor;
    IconData messageIcon;

    if (percentage >= 80) {
      message = 'Excellent ! 🎉';
      messageColor = const Color(0xFF63A96E);
      messageIcon = Icons.emoji_events;
    } else if (percentage >= 60) {
      message = 'Bien joué ! 👍';
      messageColor = const Color(0xFF2F6B3F);
      messageIcon = Icons.thumb_up;
    } else if (percentage >= 40) {
      message = 'Pas mal ! 📚';
      messageColor = const Color(0xFFF4A259);
      messageIcon = Icons.school;
    } else {
      message = 'Continue d\'apprendre ! 💪';
      messageColor = const Color(0xFFEA853D);
      messageIcon = Icons.fitness_center;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: EdgeInsets.all(desktop ? 48 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: messageColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      messageIcon,
                      size: desktop ? 80 : 64,
                      color: messageColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: desktop ? 32 : 28,
                      fontWeight: FontWeight.bold,
                      color: messageColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ton score',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score/${questions.length}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage% de bonnes réponses',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (desktop)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _restartQuiz,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F6B3F),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Recommencer le quiz',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2F6B3F),
                              side: const BorderSide(
                                  color: Color(0xFF2F6B3F)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Retour à l\'accueil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _restartQuiz,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F6B3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Recommencer le quiz',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2F6B3F),
                          side: const BorderSide(color: Color(0xFF2F6B3F)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Retour à l\'accueil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le quiz ?'),
        content: const Text(
          'Ta progression sera perdue si tu quittes maintenant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quitter',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
