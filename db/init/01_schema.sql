-- 01_schema.sql
-- Student Records DB (PostgreSQL)
-- Minimal, but with 10+ tables and integrity constraints.

CREATE TABLE department (
  id            BIGSERIAL PRIMARY KEY,
  code          VARCHAR(20) NOT NULL UNIQUE,
  name          VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE program (
  id            BIGSERIAL PRIMARY KEY,
  department_id BIGINT NOT NULL REFERENCES department(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  name          VARCHAR(200) NOT NULL,
  degree_level  VARCHAR(20) NOT NULL CHECK (degree_level IN ('bachelor','master','phd')),
  UNIQUE(department_id, name, degree_level)
);

CREATE TABLE instructor (
  id            BIGSERIAL PRIMARY KEY,
  department_id BIGINT NOT NULL REFERENCES department(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE academic_group (
  id                 BIGSERIAL PRIMARY KEY,
  program_id         BIGINT NOT NULL REFERENCES program(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  name               VARCHAR(50) NOT NULL UNIQUE,
  year_start         INT NOT NULL CHECK (year_start BETWEEN 1990 AND 2100),
  curator_instructor_id BIGINT NULL REFERENCES instructor(id) ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE student (
  id            BIGSERIAL PRIMARY KEY,
  group_id      BIGINT NOT NULL REFERENCES academic_group(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  email         VARCHAR(200) NOT NULL UNIQUE,
  enrollment_year INT NOT NULL CHECK (enrollment_year BETWEEN 1990 AND 2100),
  status        VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','academic_leave','graduated','expelled'))
);

CREATE TABLE semester (
  id            BIGSERIAL PRIMARY KEY,
  year          INT NOT NULL CHECK (year BETWEEN 1990 AND 2100),
  term          VARCHAR(10) NOT NULL CHECK (term IN ('spring','fall')),
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  CHECK (end_date > start_date),
  UNIQUE(year, term)
);

CREATE TABLE course (
  id            BIGSERIAL PRIMARY KEY,
  department_id BIGINT NOT NULL REFERENCES department(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  code          VARCHAR(30) NOT NULL UNIQUE,
  name          VARCHAR(200) NOT NULL,
  credits       NUMERIC(3,1) NOT NULL CHECK (credits >= 0.5 AND credits <= 30)
);

CREATE TABLE course_offering (
  id            BIGSERIAL PRIMARY KEY,
  course_id     BIGINT NOT NULL REFERENCES course(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  semester_id   BIGINT NOT NULL REFERENCES semester(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  group_id      BIGINT NOT NULL REFERENCES academic_group(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  instructor_id BIGINT NOT NULL REFERENCES instructor(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  UNIQUE(course_id, semester_id, group_id)
);

CREATE TABLE enrollment (
  id            BIGSERIAL PRIMARY KEY,
  offering_id   BIGINT NOT NULL REFERENCES course_offering(id) ON UPDATE CASCADE ON DELETE CASCADE,
  student_id    BIGINT NOT NULL REFERENCES student(id) ON UPDATE CASCADE ON DELETE CASCADE,
  enrolled_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(offering_id, student_id)
);

CREATE TABLE assessment_component (
  id            BIGSERIAL PRIMARY KEY,
  offering_id   BIGINT NOT NULL REFERENCES course_offering(id) ON UPDATE CASCADE ON DELETE CASCADE,
  name          VARCHAR(100) NOT NULL,
  max_points    NUMERIC(6,2) NOT NULL CHECK (max_points > 0),
  weight        NUMERIC(6,4) NOT NULL CHECK (weight > 0 AND weight <= 1),
  UNIQUE(offering_id, name)
);

CREATE TABLE grade (
  id            BIGSERIAL PRIMARY KEY,
  enrollment_id BIGINT NOT NULL REFERENCES enrollment(id) ON UPDATE CASCADE ON DELETE CASCADE,
  component_id  BIGINT NOT NULL REFERENCES assessment_component(id) ON UPDATE CASCADE ON DELETE CASCADE,
  points        NUMERIC(6,2) NOT NULL CHECK (points >= 0),
  graded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(enrollment_id, component_id)
);

CREATE TABLE attendance_session (
  id            BIGSERIAL PRIMARY KEY,
  offering_id   BIGINT NOT NULL REFERENCES course_offering(id) ON UPDATE CASCADE ON DELETE CASCADE,
  session_date  DATE NOT NULL,
  topic         VARCHAR(200) NULL,
  UNIQUE(offering_id, session_date)
);

CREATE TABLE attendance_mark (
  id            BIGSERIAL PRIMARY KEY,
  session_id    BIGINT NOT NULL REFERENCES attendance_session(id) ON UPDATE CASCADE ON DELETE CASCADE,
  student_id    BIGINT NOT NULL REFERENCES student(id) ON UPDATE CASCADE ON DELETE CASCADE,
  status        VARCHAR(10) NOT NULL CHECK (status IN ('present','absent','late','excused')),
  UNIQUE(session_id, student_id)
);

CREATE TABLE role (
  id            BIGSERIAL PRIMARY KEY,
  name          VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE user_account (
  id            BIGSERIAL PRIMARY KEY,
  username      VARCHAR(60) NOT NULL UNIQUE,
  password_hash VARCHAR(200) NOT NULL,
  instructor_id BIGINT NULL REFERENCES instructor(id) ON UPDATE CASCADE ON DELETE SET NULL,
  student_id    BIGINT NULL REFERENCES student(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_role (
  user_id       BIGINT NOT NULL REFERENCES user_account(id) ON UPDATE CASCADE ON DELETE CASCADE,
  role_id       BIGINT NOT NULL REFERENCES role(id) ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE audit_log (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT NULL REFERENCES user_account(id) ON UPDATE CASCADE ON DELETE SET NULL,
  action        VARCHAR(50) NOT NULL,
  entity        VARCHAR(50) NOT NULL,
  entity_id     BIGINT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  details       JSONB NULL
);

-- Helpful indexes
CREATE INDEX idx_student_group ON student(group_id);
CREATE INDEX idx_offering_group ON course_offering(group_id);
CREATE INDEX idx_enrollment_student ON enrollment(student_id);
CREATE INDEX idx_grade_enrollment ON grade(enrollment_id);
CREATE INDEX idx_attendance_session_offering ON attendance_session(offering_id);
CREATE INDEX idx_attendance_mark_student ON attendance_mark(student_id);
