import 'package:flutter/widgets.dart';

import 'add_lesson_screen.dart';
import 'lessons_admin_screen.dart';
import 'preacher_admin_screen.dart';

// The pages of the admin page's Preachers & lessons area. The router loads
// this library on demand, like the admin hub, so visitors do not download
// admin code (audit WEB-04).

Widget lessonsAdminTab(String tab) => LessonsAdminScreen(key: ValueKey('lessons-admin-$tab'), tab: tab);

Widget lessonsAdminPreacher(String id) => LessonsAdminPreacherScreen(key: ValueKey('lessons-admin-preacher-$id'), id: id);

Widget lessonsAdminAdd({String? fromLessonId, String? preacherId}) => LessonsAddScreen(
    key: ValueKey('lessons-admin-add-$fromLessonId-$preacherId'), fromLessonId: fromLessonId, preacherId: preacherId);

Widget lessonsAdminReport(String lessonId) => LessonsReportScreen(lessonId: lessonId);
