import 'package:flutter/material.dart';

const double kDesktopBreakpoint = 768;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;
