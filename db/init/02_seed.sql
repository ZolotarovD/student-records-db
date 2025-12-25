-- 02_seed.sql
-- Test data to prove everything works.

INSERT INTO department(code, name) VALUES
('CS', 'Computer Science'),
('MATH', 'Mathematics');

INSERT INTO program(department_id, name, degree_level) VALUES
((SELECT id FROM department WHERE code='CS'), 'Software Engineering', 'bachelor'),
((SELECT id FROM department WHERE code='CS'), 'Data Science', 'master');

INSERT INTO instructor(department_id, first_name, last_name, email) VALUES
((SELECT id FROM department WHERE code='CS'), 'Ihor', 'Koval', 'ihor.koval@uni.test'),
((SELECT id FROM department WHERE code='CS'), 'Oksana', 'Shevchenko', 'oksana.shevchenko@uni.test');

INSERT INTO academic_group(program_id, name, year_start, curator_instructor_id) VALUES
((SELECT id FROM program WHERE name='Software Engineering' AND degree_level='bachelor'), 'SE-21', 2021,
 (SELECT id FROM instructor WHERE email='ihor.koval@uni.test')),
((SELECT id FROM program WHERE name='Software Engineering' AND degree_level='bachelor'), 'SE-22', 2022,
 (SELECT id FROM instructor WHERE email='oksana.shevchenko@uni.test'));

INSERT INTO student(group_id, first_name, last_name, email, enrollment_year, status) VALUES
((SELECT id FROM academic_group WHERE name='SE-21'), 'Andrii', 'Melnyk', 'andrii.melnyk@student.test', 2021, 'active'),
((SELECT id FROM academic_group WHERE name='SE-21'), 'Yuliia', 'Bondar', 'yuliia.bondar@student.test', 2021, 'active'),
((SELECT id FROM academic_group WHERE name='SE-22'), 'Danylo', 'Tkachenko', 'danylo.tkachenko@student.test', 2022, 'active');

INSERT INTO semester(year, term, start_date, end_date) VALUES
(2025, 'fall', '2025-09-01', '2025-12-31');

INSERT INTO course(department_id, code, name, credits) VALUES
((SELECT id FROM department WHERE code='CS'), 'DB-101', 'Databases', 5.0),
((SELECT id FROM department WHERE code='CS'), 'PRG-201', 'Programming II', 6.0);

-- Offerings for group SE-21 in 2025 fall
INSERT INTO course_offering(course_id, semester_id, group_id, instructor_id) VALUES
((SELECT id FROM course WHERE code='DB-101'),
 (SELECT id FROM semester WHERE year=2025 AND term='fall'),
 (SELECT id FROM academic_group WHERE name='SE-21'),
 (SELECT id FROM instructor WHERE email='ihor.koval@uni.test')),
((SELECT id FROM course WHERE code='PRG-201'),
 (SELECT id FROM semester WHERE year=2025 AND term='fall'),
 (SELECT id FROM academic_group WHERE name='SE-21'),
 (SELECT id FROM instructor WHERE email='oksana.shevchenko@uni.test'));

-- Components (exam + labs) for DB-101 offering
INSERT INTO assessment_component(offering_id, name, max_points, weight) VALUES
((SELECT o.id FROM course_offering o JOIN course c ON c.id=o.course_id WHERE c.code='DB-101'), 'Labs', 60, 0.6),
((SELECT o.id FROM course_offering o JOIN course c ON c.id=o.course_id WHERE c.code='DB-101'), 'Exam', 40, 0.4);

-- Enroll two students to DB-101
INSERT INTO enrollment(offering_id, student_id) VALUES
((SELECT o.id FROM course_offering o JOIN course c ON c.id=o.course_id WHERE c.code='DB-101'),
 (SELECT id FROM student WHERE email='andrii.melnyk@student.test')),
((SELECT o.id FROM course_offering o JOIN course c ON c.id=o.course_id WHERE c.code='DB-101'),
 (SELECT id FROM student WHERE email='yuliia.bondar@student.test'));

-- Add grades
INSERT INTO grade(enrollment_id, component_id, points) VALUES
((SELECT e.id FROM enrollment e
  JOIN student s ON s.id=e.student_id
  JOIN course_offering o ON o.id=e.offering_id
  JOIN course c ON c.id=o.course_id
  WHERE s.email='andrii.melnyk@student.test' AND c.code='DB-101'),
 (SELECT ac.id FROM assessment_component ac
  JOIN course_offering o ON o.id=ac.offering_id
  JOIN course c ON c.id=o.course_id
  WHERE c.code='DB-101' AND ac.name='Labs'),
 55),
((SELECT e.id FROM enrollment e
  JOIN student s ON s.id=e.student_id
  JOIN course_offering o ON o.id=e.offering_id
  JOIN course c ON c.id=o.course_id
  WHERE s.email='andrii.melnyk@student.test' AND c.code='DB-101'),
 (SELECT ac.id FROM assessment_component ac
  JOIN course_offering o ON o.id=ac.offering_id
  JOIN course c ON c.id=o.course_id
  WHERE c.code='DB-101' AND ac.name='Exam'),
 30);

-- Attendance: one session + marks
INSERT INTO attendance_session(offering_id, session_date, topic) VALUES
((SELECT o.id FROM course_offering o JOIN course c ON c.id=o.course_id WHERE c.code='DB-101'),
 '2025-09-05', 'Intro');

INSERT INTO attendance_mark(session_id, student_id, status) VALUES
((SELECT id FROM attendance_session WHERE session_date='2025-09-05'),
 (SELECT id FROM student WHERE email='andrii.melnyk@student.test'),
 'present'),
((SELECT id FROM attendance_session WHERE session_date='2025-09-05'),
 (SELECT id FROM student WHERE email='yuliia.bondar@student.test'),
 'late');

-- Roles and users (demo only)
INSERT INTO role(name) VALUES ('admin'), ('instructor'), ('viewer');

INSERT INTO user_account(username, password_hash, instructor_id) VALUES
('admin', 'demo_hash_change_me', NULL),
('ihor', 'demo_hash_change_me', (SELECT id FROM instructor WHERE email='ihor.koval@uni.test'));

INSERT INTO user_role(user_id, role_id)
SELECT u.id, r.id FROM user_account u, role r
WHERE (u.username='admin' AND r.name='admin')
   OR (u.username='ihor' AND r.name='instructor');

INSERT INTO audit_log(user_id, action, entity, entity_id, details)
VALUES ((SELECT id FROM user_account WHERE username='admin'),
        'seed', 'database', NULL, '{"note":"initial seed loaded"}');
