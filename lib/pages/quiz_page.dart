import 'package:flutter/material.dart';

/// Modèle pour une question de quiz
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
  int currentQuestionIndex = 0;
  int? selectedAnswerIndex;
  bool hasAnswered = false;
  int score = 0;
  bool quizCompleted = false;

  // TODO: Charger les questions depuis l'API selon l'id du quiz
  late List<QuizQuestion> questions;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    // TODO: Remplacer par un appel API qui charge les questions selon widget.id
    // Exemple: final response = await api.getQuizQuestions(widget.id);
    
    // Simulation de différents quiz selon l'id
    switch (widget.id) {
      case '1':
        questions = _getQuiz1Questions();
        break;
      case '2':
        questions = _getQuiz2Questions();
        break;
      default:
        // Quiz par défaut si l'id n'est pas reconnu
        questions = _getQuiz1Questions();
    }
  }

  // Quiz 1 : Les vitamines et nutriments
  List<QuizQuestion> _getQuiz1Questions() {
    return [
      QuizQuestion(
        question: 'Quel fruit contient le plus de vitamine C ?',
        options: ['Pomme', 'Orange', 'Kiwi', 'Banane'],
        correctAnswerIndex: 2,
        explanation:
            'Le kiwi contient environ 93mg de vitamine C pour 100g, soit plus que l\'orange (53mg) !',
      ),
      QuizQuestion(
        question: 'Quel nutriment est essentiel pour la santé des os ?',
        options: ['Fer', 'Calcium', 'Vitamine A', 'Sodium'],
        correctAnswerIndex: 1,
        explanation:
            'Le calcium est essentiel pour la formation et le maintien des os et des dents.',
      ),
      QuizQuestion(
        question: 'Quelle vitamine est produite par le corps grâce au soleil ?',
        options: ['Vitamine A', 'Vitamine B12', 'Vitamine C', 'Vitamine D'],
        correctAnswerIndex: 3,
        explanation:
            'La vitamine D est synthétisée par la peau sous l\'effet des rayons UV du soleil.',
      ),
      QuizQuestion(
        question: 'Quel aliment est riche en fer ?',
        options: ['Lait', 'Épinards', 'Pain blanc', 'Pomme'],
        correctAnswerIndex: 1,
        explanation:
            'Les épinards sont une excellente source de fer, surtout pour les végétariens.',
      ),
      QuizQuestion(
        question: 'La vitamine B12 se trouve principalement dans :',
        options: ['Les fruits', 'Les légumes verts', 'Les produits animaux', 'Les céréales'],
        correctAnswerIndex: 2,
        explanation:
            'La vitamine B12 se trouve naturellement dans les produits d\'origine animale (viande, poisson, œufs, lait).',
      ),
    ];
  }

  // Quiz 2 : Les fruits et leurs bienfaits
  List<QuizQuestion> _getQuiz2Questions() {
    return [
      QuizQuestion(
        question: 'Quel fruit est connu pour sa richesse en potassium ?',
        options: ['Fraise', 'Banane', 'Raisin', 'Cerise'],
        correctAnswerIndex: 1,
        explanation:
            'La banane est très riche en potassium, essentiel pour les muscles et le cœur.',
      ),
      QuizQuestion(
        question: 'Quel fruit rouge est un puissant antioxydant ?',
        options: ['Pomme', 'Poire', 'Myrtille', 'Melon'],
        correctAnswerIndex: 2,
        explanation:
            'Les myrtilles sont parmi les fruits les plus riches en antioxydants.',
      ),
      QuizQuestion(
        question: 'Quel agrume aide à renforcer le système immunitaire ?',
        options: ['Citron', 'Avocat', 'Figue', 'Datte'],
        correctAnswerIndex: 0,
        explanation:
            'Le citron, riche en vitamine C, aide à renforcer les défenses immunitaires.',
      ),
      QuizQuestion(
        question: 'Quel fruit tropical contient une enzyme digestive appelée bromélaïne ?',
        options: ['Mangue', 'Papaye', 'Ananas', 'Fruit de la passion'],
        correctAnswerIndex: 2,
        explanation:
            'L\'ananas contient de la bromélaïne, une enzyme qui facilite la digestion des protéines.',
      ),
      QuizQuestion(
        question: 'Combien de portions de fruits est-il recommandé de manger par jour ?',
        options: ['1 portion', '2-3 portions', '5-6 portions', '10 portions'],
        correctAnswerIndex: 1,
        explanation:
            'Il est recommandé de manger 2 à 3 portions de fruits par jour dans le cadre des 5 fruits et légumes.',
      ),
    ];
  }

  void _selectAnswer(int index) {
    if (hasAnswered) return;

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
          ? const Color(0xFF2F6B3F).withOpacity(0.1)
          : Colors.white;
    }

    if (index == questions[currentQuestionIndex].correctAnswerIndex) {
      return Colors.green.withOpacity(0.2);
    }

    if (index == selectedAnswerIndex) {
      return Colors.red.withOpacity(0.2);
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
      return Colors.green;
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
    if (quizCompleted) {
      return _buildResultScreen();
    }

    final question = questions[currentQuestionIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Progress bar
            _buildProgressBar(),

            // Contenu
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Numéro de question
                    Text(
                      'Question ${currentQuestionIndex + 1}/${questions.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Question
                    Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2E1F),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    ...question.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOptionCard(index, option),
                      );
                    }),

                    // Explication (après réponse)
                    if (hasAnswered && question.explanation != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F6B3F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2F6B3F).withOpacity(0.3),
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
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1F2E1F)),
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
          const SizedBox(width: 48), // Pour équilibrer le bouton close
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2F6B3F)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String option) {
    final icon = _getOptionIcon(index);

    return GestureDetector(
      onTap: () => _selectAnswer(index),
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
              color: Colors.black.withOpacity(0.05),
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
                color: const Color(0xFFF4A259).withOpacity(0.2),
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
                color: icon == Icons.check_circle ? Colors.green : Colors.red,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final percentage = (score / questions.length * 100).round();
    String message;
    Color messageColor;
    IconData messageIcon;

    if (percentage >= 80) {
      message = 'Excellent ! 🎉';
      messageColor = Colors.green;
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
      messageColor = Colors.orange;
      messageIcon = Icons.fitness_center;
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                messageIcon,
                size: 80,
                color: messageColor,
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: messageColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ton score',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
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
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
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
              Navigator.pop(context); // Fermer le dialog
              Navigator.pop(context); // Retour à l'accueil
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
