import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _equation = ""; // উপরের ছোট টেক্সট (পুরো সমীকরণ)
  String _mainDisplay = "0"; // নিচের বড় টেক্সট (লাইভ রেজাল্ট)

  double _num1 = 0.0;
  String _operand = "";
  String _currentInput = "0"; // বর্তমানে যে সংখ্যাটি টাইপ করা হচ্ছে

  // লাইভ ক্যালকুলেশন করার মেথড
  void _liveCalculate() {
    if (_operand.isEmpty) {
      if (_currentInput.isNotEmpty) _mainDisplay = _currentInput;
      return;
    }
    if (_currentInput.isEmpty) return;

    double num2 = double.parse(_currentInput);
    double res = 0;

    if (_operand == "+") res = _num1 + num2;
    if (_operand == "-") res = _num1 - num2;
    if (_operand == "×") res = _num1 * num2;
    if (_operand == "÷") {
      if (num2 == 0) {
        _mainDisplay = "Error";
        return;
      }
      res = _num1 / num2;
    }
    _mainDisplay = _formatResult(res.toString());
  }

  // সমীকরণ আপডেট করার মেথড
  void _updateEquation() {
    if (_operand.isEmpty) {
      _equation = _currentInput;
    } else {
      _equation = "${_formatResult(_num1.toString())} $_operand $_currentInput";
    }
  }

  void _buttonPressed(String btn) {
    setState(() {
      if (btn == "AC") {
        // সবকিছু রিসেট
        _equation = "";
        _mainDisplay = "0";
        _num1 = 0.0;
        _operand = "";
        _currentInput = "0";
      } else if (btn == "⌫") {
        // ব্যাকস্পেস লজিক
        if (_currentInput.isNotEmpty) {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
          if (_currentInput.isEmpty) {
            if (_operand.isEmpty) {
              _currentInput = "0";
              _mainDisplay = "0";
              _equation = "0";
            } else {
              _mainDisplay = _formatResult(_num1.toString());
              _equation = "${_formatResult(_num1.toString())} $_operand";
            }
          } else {
            if (_currentInput == "-") _currentInput = "0";
            _updateEquation();
            _liveCalculate();
          }
        } else if (_operand.isNotEmpty) {
          // অপারেটর মুছে ফেলা
          _operand = "";
          _currentInput = _formatResult(_num1.toString());
          _equation = _currentInput;
          _mainDisplay = _currentInput;
        }
      } else if (["+", "-", "×", "÷"].contains(btn)) {
        // অপারেটর লজিক (যোগ, বিয়োগ, গুণ, ভাগ)
        if (_operand.isNotEmpty && _currentInput.isNotEmpty) {
          _liveCalculate();
          _num1 = double.parse(_mainDisplay);
        } else {
          _num1 = double.parse(_mainDisplay);
        }
        _operand = btn;
        _currentInput = "";
        _equation = "${_formatResult(_num1.toString())} $_operand";
      } else if (btn == "=") {
        // ফাইনাল রেজাল্ট (যদিও অটোমেটিক হচ্ছে, তবুও হিসেব শেষ করতে)
        if (_operand.isNotEmpty && _currentInput.isNotEmpty) {
          _liveCalculate();
          _num1 = double.parse(_mainDisplay);
          _operand = "";
          _currentInput = _mainDisplay;
          _equation = _mainDisplay;
        }
      } else if (btn == "%") {
        // পার্সেন্টেজ লজিক
        if (_currentInput.isNotEmpty) {
          double val = double.parse(_currentInput) / 100;
          _currentInput = _formatResult(val.toString());
          _updateEquation();
          _liveCalculate();
        } else if (_mainDisplay != "0") {
          double val = double.parse(_mainDisplay) / 100;
          _mainDisplay = _formatResult(val.toString());
          _num1 = double.parse(_mainDisplay);
          _equation = _mainDisplay;
        }
      } else if (btn == ".") {
        // দশমিক লজিক
        if (!_currentInput.contains(".")) {
          if (_currentInput.isEmpty) {
            _currentInput = "0.";
          } else {
            _currentInput += ".";
          }
          _updateEquation();
          if (_operand.isEmpty) _mainDisplay = _currentInput;
        }
      } else {
        // নাম্বার এবং ডাবল জিরো (00) লজিক
        if (_currentInput == "0") {
          if (btn != "00") _currentInput = btn;
        } else {
          _currentInput += btn;
        }
        _updateEquation();
        _liveCalculate();
      }
    });
  }

  // দশমিকের পরের শূন্য বাদ দেওয়ার জন্য
  String _formatResult(String result) {
    if (result.contains(".")) {
      List<String> parts = result.split(".");
      if (parts[1] == "0") {
        return parts[0];
      }
    }
    // অতিরিক্ত দশমিক ফিগার কমানো
    if (result.contains(".") && result.split(".")[1].length > 6) {
      return double.parse(
        result,
      ).toStringAsFixed(6).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
    }
    return result;
  }

  // বাটন ডিজাইন
  Widget _buildButton(String buttonText, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6.0),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          elevation: 2, // হালকা শ্যাডো
          child: InkWell(
            onTap: () => _buttonPressed(buttonText),
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white24,
            child: Center(
              child: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141518), // ডার্ক প্রিমিয়াম ব্যাকগ্রাউন্ড
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          "ক্যালকুলেটর",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ডিসপ্লে সেকশন
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // হিস্ট্রি সমীকরণ
                    Text(
                      _equation,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white54,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // লাইভ রেজাল্ট
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _mainDisplay,
                        style: const TextStyle(
                          fontSize: 68,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // কিপ্যাড এর ডিভাইডার
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(color: Colors.white12, thickness: 2),
            ),

            // কিপ্যাড সেকশন
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton(
                            "AC",
                            const Color(0xFF9E9E9E),
                            Colors.black87,
                          ),
                          _buildButton(
                            "⌫",
                            const Color(0xFF9E9E9E),
                            Colors.black87,
                          ),
                          _buildButton(
                            "%",
                            const Color(0xFF9E9E9E),
                            Colors.black87,
                          ),
                          _buildButton(
                            "÷",
                            const Color(0xFFFF9F0A),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton(
                            "7",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "8",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "9",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "×",
                            const Color(0xFFFF9F0A),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton(
                            "4",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "5",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "6",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "-",
                            const Color(0xFFFF9F0A),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton(
                            "1",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "2",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "3",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "+",
                            const Color(0xFFFF9F0A),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton(
                            "00",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "0",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            ".",
                            const Color(0xFF2C2D2F),
                            Colors.white,
                          ),
                          _buildButton(
                            "=",
                            const Color(0xFFFF9F0A),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
