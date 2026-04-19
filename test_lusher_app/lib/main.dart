import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const PsychoApp());
}

class PsychoApp extends StatelessWidget {
  const PsychoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Психодиагностика',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentStep = 0;
  List<String> wordsList = [];
  int currentWordIndex = 0;
  Map<String, Map<String, int>> resultsData = {};
  List<String> _currentWordSelectionOrder = [];
  double _wordOpacity = 1.0;
  bool _isProcessingTransition = false;

  final TextEditingController _wordsController = TextEditingController();

  final Map<String, String> colorFiles = {
    "фиолетовый": "purple.png",
    "оранжевый": "orange.png",
    "желтый": "yellow.png",
    "синий": "blue.png",
    "зеленый": "green.png",
    "коричневый": "brown.png",
    "серый": "gray.png",
    "черный": "black.png",
  };

  void _startTesting() {
    final input = _wordsController.text;
    final parsedWords = input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (parsedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите хотя бы одно слово')),
      );
      return;
    }

    setState(() {
      wordsList = parsedWords;
      currentWordIndex = 0;
      _currentWordSelectionOrder.clear();
      resultsData = {for (var word in wordsList) word: {for (var color in colorFiles.keys) color: 0}};
      currentStep = 1;
    });
  }

  void _handleColorClick(String colorName) async {
    if (_isProcessingTransition || _currentWordSelectionOrder.contains(colorName)) return;

    setState(() {
      _currentWordSelectionOrder.add(colorName);
      resultsData[wordsList[currentWordIndex]]![colorName] = _currentWordSelectionOrder.length;
    });

    if (_currentWordSelectionOrder.length == colorFiles.length) {
      setState(() {
        _isProcessingTransition = true;
        _wordOpacity = 0.0;
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() {
        currentWordIndex++;
        _currentWordSelectionOrder.clear();
        if (currentWordIndex >= wordsList.length) {
          currentStep = 2;
        } else {
          _wordOpacity = 1.0;
          _isProcessingTransition = false;
        }
      });
    }
  }

  void _restart() {
    setState(() {
      _wordsController.clear();
      wordsList.clear();
      currentStep = 0;
      _currentWordSelectionOrder.clear();
      _isProcessingTransition = false;
      _wordOpacity = 1.0;
    });
  }

  Future<void> _saveExcelWithDialog() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Результаты'];
    excel.delete('Sheet1');

    List<CellValue> header = [TextCellValue('Слово')];
    header.addAll(colorFiles.keys.map((c) => TextCellValue(c)).toList());
    sheetObject.appendRow(header);

    for (var word in wordsList) {
      List<CellValue> row = [TextCellValue(word)];
      for (var color in colorFiles.keys) {
        row.add(IntCellValue(resultsData[word]![color] ?? 0));
      }
      sheetObject.appendRow(row);
    }

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Выберите место для сохранения отчета',
      fileName: 'psycho_results.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputFile != null) {
      if (!outputFile.endsWith('.xlsx')) {
        outputFile += '.xlsx';
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл успешно сохранен: $outputFile')),
        );
      }
    }
  }

  String _generateCsvText() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Слово,${colorFiles.keys.join(',')}');
    for (var word in wordsList) {
      final ranks = colorFiles.keys.map((color) => resultsData[word]![color].toString());
      buffer.writeln('$word,${ranks.join(',')}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          _buildCenterCard(),
        ],
      ),
    );
  }

  Widget _buildCenterCard() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.symmetric(vertical: 40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 30)],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: currentStep == 0
                ? _buildInputView()
                : (currentStep == 1 ? _buildAssociationView() : _buildFinishedView()),
          ),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.psychology, size: 80, color: Color(0xFF8EC5FC)),
        const SizedBox(height: 20),
        const Text('Психодиагностика', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        TextField(
          controller: _wordsController,
          decoration: InputDecoration(
            labelText: 'Список слов через запятую',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _startTesting,
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
          child: const Text('Начать'),
        ),
      ],
    );
  }

  Widget _buildAssociationView() {
    final safeIndex = currentWordIndex < wordsList.length ? currentWordIndex : wordsList.length - 1;
    final currentWord = wordsList.isNotEmpty ? wordsList[safeIndex] : "";

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Слово ${safeIndex + 1} из ${wordsList.length}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        AnimatedOpacity(
          opacity: _wordOpacity,
          duration: const Duration(milliseconds: 300),
          child: Text(currentWord, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 40),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.85,
          ),
          itemCount: colorFiles.length,
          itemBuilder: (context, index) {
            String colorName = colorFiles.keys.elementAt(index);
            String fileName = colorFiles.values.elementAt(index);
            bool isSelected = _currentWordSelectionOrder.contains(colorName);
            int rank = isSelected ? _currentWordSelectionOrder.indexOf(colorName) + 1 : 0;


            String assetPath = 'assets/$fileName';

            return GestureDetector(
              onTap: () => _handleColorClick(colorName),
              child: Opacity(
                opacity: isSelected ? 0.3 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Загружаем картинку из папки assets/
                          Image.asset(
                            assetPath,
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) {
                              debugPrint("Ошибка загрузки картинки: $assetPath");
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              );
                            },
                          ),
                          if (isSelected)
                            CircleAvatar(
                              backgroundColor: Colors.white.withAlpha(200),
                              child: Text('$rank', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(colorName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinishedView() {
    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 10),
        const Text('Тест завершен!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: _saveExcelWithDialog,
          icon: const Icon(Icons.save_alt),
          label: const Text('Сохранить Excel таблицу'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade700),
        ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 10),

        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, color: Colors.grey),
            SizedBox(width: 10),
            Text("Данные в формате CSV:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: SelectableText(
            _generateCsvText(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),

        const SizedBox(height: 40),
        OutlinedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          label: const Text('Начать заново'),
        ),
      ],
    );
  }
}